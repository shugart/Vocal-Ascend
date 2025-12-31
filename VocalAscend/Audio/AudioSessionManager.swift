import AVFoundation
import Combine

/// Manages AVAudioSession configuration for low-latency microphone input
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    @Published private(set) var isConfigured = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var isInterrupted = false
    @Published private(set) var currentRoute: String = ""

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotifications()
    }

    // MARK: - Permission

    /// Check and request microphone permission
    func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            await MainActor.run { hasMicrophonePermission = true }
            return true

        case .denied:
            await MainActor.run { hasMicrophonePermission = false }
            return false

        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run { hasMicrophonePermission = granted }
            return granted

        @unknown default:
            return false
        }
    }

    // MARK: - Configuration

    /// Configure audio session for low-latency pitch detection
    func configure() throws {
        let session = AVAudioSession.sharedInstance()

        do {
            // Use measurement mode for accurate pitch detection
            // This disables automatic gain control and other processing
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            // Request low buffer duration for lower latency
            // 0.005 = 5ms, though system may not honor exact value
            try session.setPreferredIOBufferDuration(0.005)

            // Set preferred sample rate (44.1kHz is standard)
            try session.setPreferredSampleRate(44100)

            // Activate the session
            try session.setActive(true)

            isConfigured = true
            updateCurrentRoute()

            print("[AudioSession] Configured successfully")
            print("[AudioSession] Sample rate: \(session.sampleRate)")
            print("[AudioSession] Buffer duration: \(session.ioBufferDuration)")
            print("[AudioSession] Input latency: \(session.inputLatency)")

        } catch {
            isConfigured = false
            throw AudioSessionError.configurationFailed(error)
        }
    }

    /// Deactivate the audio session
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
        } catch {
            print("[AudioSession] Failed to deactivate: \(error)")
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let nc = NotificationCenter.default

        // Audio interruption (phone call, alarm, etc.)
        nc.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)

        // Route change (headphones plugged/unplugged, etc.)
        nc.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)

        // Media services reset (rare, but need to handle)
        nc.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                self?.handleMediaServicesReset()
            }
            .store(in: &cancellables)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioSession] Interruption began")
            isInterrupted = true

        case .ended:
            print("[AudioSession] Interruption ended")
            isInterrupted = false

            // Check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Post notification to resume audio
                    NotificationCenter.default.post(name: .audioSessionShouldResume, object: nil)
                }
            }

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("[AudioSession] Route changed: \(reason)")
        updateCurrentRoute()

        switch reason {
        case .newDeviceAvailable:
            // New device (e.g., headphones) plugged in
            break

        case .oldDeviceUnavailable:
            // Device (e.g., headphones) unplugged
            // May want to pause/stop recording
            NotificationCenter.default.post(name: .audioRouteChanged, object: nil)

        case .categoryChange:
            // Audio category changed by another app
            break

        default:
            break
        }
    }

    private func handleMediaServicesReset() {
        print("[AudioSession] Media services were reset")
        isConfigured = false

        // Attempt to reconfigure
        try? configure()
    }

    private func updateCurrentRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        let inputName = route.inputs.first?.portName ?? "Unknown"
        currentRoute = inputName
    }

    // MARK: - Info

    var sampleRate: Double {
        AVAudioSession.sharedInstance().sampleRate
    }

    var bufferDuration: TimeInterval {
        AVAudioSession.sharedInstance().ioBufferDuration
    }

    var inputLatency: TimeInterval {
        AVAudioSession.sharedInstance().inputLatency
    }
}

// MARK: - Errors

enum AudioSessionError: LocalizedError {
    case configurationFailed(Error)
    case noMicrophonePermission

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .noMicrophonePermission:
            return "Microphone permission is required for pitch detection"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let audioSessionShouldResume = Notification.Name("audioSessionShouldResume")
    static let audioRouteChanged = Notification.Name("audioRouteChanged")
}
