import AVFoundation
import Combine

/// Audio engine for real-time pitch detection
final class AudioEngine: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isRunning = false
    @Published private(set) var currentPitch: PitchFrame?
    @Published private(set) var stabilityScore: Float = 0

    /// Target note for cents offset calculation
    @Published var targetNote: Note = .A4

    // MARK: - Private Properties

    private let engine = AVAudioEngine()
    private let pitchDetector = PitchDetector()
    private let sessionManager = AudioSessionManager.shared

    private let processingQueue = DispatchQueue(
        label: "com.vocalascend.audio.processing",
        qos: .userInteractive
    )

    private var cancellables = Set<AnyCancellable>()

    /// Buffer for stability calculation (rolling window)
    private var recentPitches: [Float] = []
    private let stabilityWindowSize = 30 // ~1 second at 30fps

    /// UI update throttling
    private var lastUIUpdate = Date()
    private let minUIUpdateInterval: TimeInterval = 1.0 / 30.0 // 30fps max

    // MARK: - Initialization

    init() {
        setupNotifications()
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Track if we're in the process of starting
    private var isStarting = false

    /// Start audio capture and pitch detection
    func start() {
        guard !isRunning && !isStarting else {
            print("[AudioEngine] Already running or starting")
            return
        }

        isStarting = true

        Task {
            // Request microphone permission
            guard await sessionManager.requestMicrophonePermission() else {
                print("[AudioEngine] No microphone permission")
                await MainActor.run { isStarting = false }
                return
            }

            // Configure audio session
            do {
                try sessionManager.configure()
            } catch {
                print("[AudioEngine] Failed to configure session: \(error)")
                await MainActor.run { isStarting = false }
                return
            }

            // Start engine on main thread
            await MainActor.run {
                startEngine()
                isStarting = false
            }
        }
    }

    /// Stop audio capture
    func stop() {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        currentPitch = nil
        recentPitches.removeAll()
    }

    // MARK: - Private Methods

    private func startEngine() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate format
        guard inputFormat.sampleRate > 0 else {
            print("[AudioEngine] Invalid input format")
            return
        }

        print("[AudioEngine] Input format: \(inputFormat)")

        // Remove any existing tap before installing a new one
        inputNode.removeTap(onBus: 0)

        // Calculate buffer size for ~30fps updates
        // 44100 / 30 ≈ 1470 samples per buffer
        let bufferSize: AVAudioFrameCount = 2048

        // Install tap on input node
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }

        // Prepare and start engine
        engine.prepare()

        do {
            try engine.start()
            isRunning = true
            print("[AudioEngine] Started successfully")
        } catch {
            print("[AudioEngine] Failed to start: \(error)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Get audio samples
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

            // Calculate RMS and dBFS
            let rms = DSPUtils.calculateRMS(samples)
            let dbfs = DSPUtils.rmsToDBFS(rms)

            // Detect pitch
            let sampleRate = Float(buffer.format.sampleRate)
            let (frequency, confidence) = self.pitchDetector.detectPitch(
                samples: samples,
                sampleRate: sampleRate
            )

            // Create pitch frame
            let frame = self.createPitchFrame(
                frequency: frequency,
                confidence: confidence,
                rms: rms,
                dbfs: dbfs
            )

            // Update stability score
            self.updateStability(frequency: frequency, confidence: confidence)

            // Throttle UI updates
            let now = Date()
            guard now.timeIntervalSince(self.lastUIUpdate) >= self.minUIUpdateInterval else {
                return
            }
            self.lastUIUpdate = now

            // Update UI on main thread
            DispatchQueue.main.async {
                self.currentPitch = frame
            }
        }
    }

    private func createPitchFrame(
        frequency: Float?,
        confidence: Float,
        rms: Float,
        dbfs: Float
    ) -> PitchFrame {
        var noteName: String?
        var octave: Int?
        var centsOffNearest: Float?
        var centsOffTarget: Float?

        if let freq = frequency, confidence >= 0.6 {
            if let (note, cents) = Note.nearest(to: freq) {
                noteName = note.displayName
                octave = note.octave
                centsOffNearest = cents
                centsOffTarget = targetNote.centsOffset(from: freq)
            }
        }

        return PitchFrame(
            timestamp: Date(),
            f0Hz: frequency,
            noteName: noteName,
            octave: octave,
            centsOffNearest: centsOffNearest,
            centsOffTarget: centsOffTarget,
            confidence: confidence,
            rms: rms,
            dbfs: dbfs
        )
    }

    private func updateStability(frequency: Float?, confidence: Float) {
        guard let freq = frequency, confidence >= 0.6 else {
            // Low confidence - don't update stability
            return
        }

        recentPitches.append(freq)

        // Keep only recent samples
        if recentPitches.count > stabilityWindowSize {
            recentPitches.removeFirst()
        }

        // Calculate stability (inverse of variance, normalized to 0-100)
        if recentPitches.count >= 10 {
            let stability = DSPUtils.calculatePitchStability(recentPitches)
            DispatchQueue.main.async {
                self.stabilityScore = stability
            }
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .audioSessionShouldResume)
            .sink { [weak self] _ in
                if self?.isRunning == true {
                    self?.stop()
                    self?.start()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .audioRouteChanged)
            .sink { [weak self] _ in
                // Restart engine when route changes
                if self?.isRunning == true {
                    self?.stop()
                    self?.start()
                }
            }
            .store(in: &cancellables)
    }
}
