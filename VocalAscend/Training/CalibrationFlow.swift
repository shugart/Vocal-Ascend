import Foundation
import Combine
import SwiftUI

/// Guides the user through voice calibration to create their VoiceProfile
final class CalibrationFlow: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentStep: CalibrationStep = .welcome
    @Published private(set) var stepProgress: Float = 0
    @Published private(set) var isListening = false
    @Published private(set) var currentInstruction: String = ""
    @Published private(set) var feedbackMessage: String = ""
    @Published private(set) var canProceed = false
    @Published private(set) var error: CalibrationError?

    // Measurements
    @Published private(set) var detectedLevel: Float = -60
    @Published private(set) var ambientNoiseLevel: Float = -60
    @Published private(set) var baselineLoudness: Float = -30
    @Published private(set) var detectedNote: Note?
    @Published private(set) var detectedCentsOff: Float = 0
    @Published private(set) var highestComfortableNote: Note = .E4
    @Published private(set) var testedVowels: [Vowel: VowelTestResult] = [:]

    // MARK: - Types

    enum CalibrationStep: Int, CaseIterable {
        case welcome = 0
        case microphoneCheck = 1
        case roomNoiseCheck = 2
        case baselineLoudness = 3
        case findTopNote = 4
        case vowelTest = 5
        case complete = 6

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .microphoneCheck: return "Microphone Check"
            case .roomNoiseCheck: return "Room Noise"
            case .baselineLoudness: return "Baseline Volume"
            case .findTopNote: return "Find Your Range"
            case .vowelTest: return "Vowel Test"
            case .complete: return "Complete"
            }
        }

        var instructions: String {
            switch self {
            case .welcome:
                return "Let's set up your voice profile. This will help us personalize your training."
            case .microphoneCheck:
                return "Speak or hum to make sure your microphone is working."
            case .roomNoiseCheck:
                return "Stay quiet for a moment so we can measure the background noise."
            case .baselineLoudness:
                return "Sing a comfortable note (like C4 or D4) at your normal volume."
            case .findTopNote:
                return "Slide up from a comfortable note until you feel strain. Stop when it gets uncomfortable."
            case .vowelTest:
                return "Sing the target note on each vowel we show you."
            case .complete:
                return "Your voice profile is ready!"
            }
        }
    }

    struct VowelTestResult {
        let vowel: Vowel
        let stability: Float
        let avgCentsOff: Float
        let success: Bool
    }

    enum CalibrationError: LocalizedError {
        case microphoneNotDetected
        case roomTooNoisy
        case noPitchDetected
        case calibrationFailed(String)

        var errorDescription: String? {
            switch self {
            case .microphoneNotDetected:
                return "Could not detect microphone input. Please check your microphone permissions."
            case .roomTooNoisy:
                return "The room is too noisy. Please find a quieter space."
            case .noPitchDetected:
                return "Could not detect a clear pitch. Please try singing more clearly."
            case .calibrationFailed(let reason):
                return "Calibration failed: \(reason)"
            }
        }
    }

    // MARK: - Configuration

    struct Config {
        /// Minimum level to consider microphone working (dBFS)
        var minMicLevel: Float = -50

        /// Maximum ambient noise level allowed (dBFS)
        var maxAmbientNoise: Float = -40

        /// Duration to listen for each step (seconds)
        var listenDuration: TimeInterval = 3.0

        /// Minimum confidence for pitch detection
        var minPitchConfidence: Float = 0.6

        /// Vowels to test during calibration
        var testVowels: [Vowel] = [.UH, .OH, .EH]

        /// Test note for vowel testing
        var vowelTestNote: Note = .F4
    }

    var config = Config()

    // MARK: - Private Properties

    private var pitchFrames: [PitchFrame] = []
    private var listenTimer: Timer?
    private var currentVowelIndex = 0
    private var cancellables = Set<AnyCancellable>()

    // Dependencies (injected or created)
    private weak var audioEngine: AudioEngine?

    // MARK: - Initialization

    init(audioEngine: AudioEngine? = nil) {
        self.audioEngine = audioEngine
        updateInstructions()
    }

    // MARK: - Public Methods

    /// Set the audio engine reference
    func setAudioEngine(_ engine: AudioEngine) {
        self.audioEngine = engine
        setupBindings()
    }

    /// Start the calibration flow
    func start() {
        currentStep = .welcome
        error = nil
        updateInstructions()
    }

    /// Move to the next step
    func nextStep() {
        guard let nextIndex = CalibrationStep.allCases.firstIndex(where: { $0.rawValue == currentStep.rawValue + 1 }),
              nextIndex < CalibrationStep.allCases.count else {
            return
        }

        currentStep = CalibrationStep.allCases[nextIndex]
        canProceed = false
        error = nil
        pitchFrames.removeAll()
        updateInstructions()
        updateProgress()

        // Auto-start listening for certain steps
        if currentStep == .microphoneCheck ||
           currentStep == .roomNoiseCheck ||
           currentStep == .baselineLoudness {
            startListening()
        }
    }

    /// Go back to the previous step
    func previousStep() {
        guard currentStep.rawValue > 0 else { return }

        stopListening()
        currentStep = CalibrationStep.allCases[currentStep.rawValue - 1]
        canProceed = false
        error = nil
        updateInstructions()
        updateProgress()
    }

    /// Start listening for audio input
    func startListening() {
        guard !isListening else { return }

        // Make sure audio engine is running
        if audioEngine?.isRunning != true {
            audioEngine?.start()
            print("[CalibrationFlow] Starting audio engine...")
        }

        isListening = true
        pitchFrames.removeAll()
        feedbackMessage = "Listening... (speak or hum)"

        print("[CalibrationFlow] Started listening for step: \(currentStep.title)")

        // Start a timer to evaluate after the listen duration
        listenTimer = Timer.scheduledTimer(withTimeInterval: config.listenDuration, repeats: false) { [weak self] _ in
            print("[CalibrationFlow] Timer fired, evaluating step...")
            self?.evaluateCurrentStep()
        }
    }

    /// Stop listening
    func stopListening() {
        isListening = false
        listenTimer?.invalidate()
        listenTimer = nil
    }

    /// Record user's highest comfortable note during siren
    func recordHighestNote(_ note: Note) {
        highestComfortableNote = note
        canProceed = true
        feedbackMessage = "Top note recorded: \(note.fullName)"
    }

    /// Start vowel test for next vowel
    func startNextVowelTest() {
        guard currentVowelIndex < config.testVowels.count else {
            canProceed = true
            return
        }

        let vowel = config.testVowels[currentVowelIndex]
        feedbackMessage = "Sing \(config.vowelTestNote.fullName) on '\(vowel.label)'"
        startListening()
    }

    /// Build the final voice profile from calibration data
    func buildVoiceProfile() -> VoiceProfile {
        let profile = VoiceProfile(
            comfortableLowNote: Note.C3.midiNote,
            comfortableHighNote: highestComfortableNote.midiNote,
            stableCentsTolerance: 25,
            minConfidence: config.minPitchConfidence
        )

        // Set baseline loudness
        profile.baselineLoudnessDBFS = baselineLoudness

        // Add developing notes (one semitone above comfortable)
        if let developingNote = highestComfortableNote.transposed(by: 1) {
            profile.addDevelopingNote(developingNote)
        }
        if let developingNote2 = highestComfortableNote.transposed(by: 2) {
            profile.addDevelopingNote(developingNote2)
        }

        return profile
    }

    /// Skip calibration (use defaults)
    func skip() -> VoiceProfile {
        return VoiceProfile()
    }

    /// Start at a specific step
    func startStep(_ step: CalibrationStep) {
        currentStep = step
        canProceed = false
        error = nil
        pitchFrames.removeAll()
        updateInstructions()
        updateProgress()

        // Start the audio engine if needed
        audioEngine?.start()

        // Auto-start listening for certain steps
        if step == .microphoneCheck ||
           step == .roomNoiseCheck ||
           step == .baselineLoudness ||
           step == .findTopNote {
            startListening()
        }
    }

    /// Advance to the next step (alias for nextStep)
    func advanceToNextStep() {
        nextStep()
    }

    /// Confirm the user's top note during the siren step
    func confirmTopNote() {
        guard currentStep == .findTopNote else { return }

        // Record the highest note detected so far
        if let note = detectedNote {
            highestComfortableNote = note
        }

        canProceed = true
        feedbackMessage = "Top note confirmed: \(highestComfortableNote.fullName)"
        stopListening()
    }

    /// Clear the current error
    func clearError() {
        error = nil
    }

    /// Generate the voice profile (returns nil if not complete)
    func generateVoiceProfile() -> VoiceProfile? {
        // Allow generating at complete step or if we have enough data
        if currentStep == .complete || highestComfortableNote.midiNote > Note.E4.midiNote {
            return buildVoiceProfile()
        }
        return nil
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Clear any existing bindings
        cancellables.removeAll()

        guard let engine = audioEngine else {
            print("[CalibrationFlow] No audio engine available for bindings")
            return
        }

        print("[CalibrationFlow] Setting up bindings with audio engine")

        // Listen to pitch frames from audio engine
        engine.$currentPitch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                if let frame = frame {
                    self?.handlePitchFrame(frame)
                }
            }
            .store(in: &cancellables)

        // Also observe the audio engine's running state
        engine.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                print("[CalibrationFlow] Audio engine running: \(isRunning)")
                if isRunning {
                    self?.feedbackMessage = "Audio ready - listening..."
                }
            }
            .store(in: &cancellables)
    }

    private func handlePitchFrame(_ frame: PitchFrame) {
        // Always update the detected level for visual feedback
        detectedLevel = frame.dbfs

        guard isListening else { return }

        pitchFrames.append(frame)

        // Print occasionally for debugging
        if pitchFrames.count % 30 == 1 {
            print("[CalibrationFlow] Received \(pitchFrames.count) frames, level: \(frame.dbfs) dBFS")
        }

        // Update detected note if pitch is reliable
        if let freq = frame.f0Hz, frame.confidence >= config.minPitchConfidence {
            if let (note, cents) = Note.nearest(to: freq) {
                detectedNote = note
                detectedCentsOff = cents
            }
        }
    }

    private func evaluateCurrentStep() {
        stopListening()

        switch currentStep {
        case .microphoneCheck:
            evaluateMicrophoneCheck()
        case .roomNoiseCheck:
            evaluateRoomNoiseCheck()
        case .baselineLoudness:
            evaluateBaselineLoudness()
        case .vowelTest:
            evaluateVowelTest()
        default:
            break
        }
    }

    private func evaluateMicrophoneCheck() {
        print("[CalibrationFlow] Evaluating mic check with \(pitchFrames.count) frames")

        if pitchFrames.isEmpty {
            // No frames received at all - audio engine might not be working
            error = .microphoneNotDetected
            feedbackMessage = "No audio data received. Check that Simulator has microphone access in System Settings."
            print("[CalibrationFlow] No frames received!")
            return
        }

        // Filter out invalid values (NaN, infinity) and get max level
        let validLevels = pitchFrames.map { $0.dbfs }.filter { $0.isFinite }
        let maxLevel = validLevels.max() ?? -60
        let displayLevel = maxLevel.isFinite ? Int(maxLevel) : -60

        print("[CalibrationFlow] Max level detected: \(maxLevel) dBFS (threshold: \(config.minMicLevel))")

        if maxLevel > config.minMicLevel {
            canProceed = true
            feedbackMessage = "Microphone working! (peak: \(displayLevel) dBFS)"
        } else {
            error = .microphoneNotDetected
            feedbackMessage = "Audio too quiet (peak: \(displayLevel) dBFS). Speak louder or move closer to the mic."
        }
    }

    private func evaluateRoomNoiseCheck() {
        let avgLevel = pitchFrames.isEmpty ? -60 :
            pitchFrames.map { $0.dbfs }.reduce(0, +) / Float(pitchFrames.count)

        ambientNoiseLevel = avgLevel

        if avgLevel < config.maxAmbientNoise {
            canProceed = true
            feedbackMessage = "Room noise is acceptable."
        } else {
            error = .roomTooNoisy
            feedbackMessage = "Room is too noisy (avg: \(Int(avgLevel)) dBFS)"
        }
    }

    private func evaluateBaselineLoudness() {
        // Filter frames with reliable pitch
        let reliableFrames = pitchFrames.filter { $0.confidence >= config.minPitchConfidence && $0.f0Hz != nil }

        guard !reliableFrames.isEmpty else {
            error = .noPitchDetected
            feedbackMessage = "Could not detect a clear pitch. Please try again."
            return
        }

        // Calculate average loudness
        let avgLoudness = reliableFrames.map { $0.dbfs }.reduce(0, +) / Float(reliableFrames.count)
        baselineLoudness = avgLoudness

        // Find most common note
        let noteGroups = Dictionary(grouping: reliableFrames.compactMap { frame -> Note? in
            guard let freq = frame.f0Hz else { return nil }
            return Note.nearest(to: freq)?.note
        }) { $0 }

        if let mostCommonNote = noteGroups.max(by: { $0.value.count < $1.value.count })?.key {
            detectedNote = mostCommonNote
            canProceed = true
            feedbackMessage = "Baseline recorded at \(mostCommonNote.fullName)"
        } else {
            error = .noPitchDetected
            feedbackMessage = "Could not identify the note. Please try again."
        }
    }

    private func evaluateVowelTest() {
        guard currentVowelIndex < config.testVowels.count else { return }

        let vowel = config.testVowels[currentVowelIndex]
        let reliableFrames = pitchFrames.filter { $0.confidence >= config.minPitchConfidence && $0.f0Hz != nil }

        let stability: Float
        let avgCentsOff: Float
        let success: Bool

        if reliableFrames.count >= 5 {
            let frequencies = reliableFrames.compactMap { $0.f0Hz }
            stability = DSPUtils.calculatePitchStability(frequencies)

            let centsOffsets = reliableFrames.compactMap { frame -> Float? in
                guard let freq = frame.f0Hz else { return nil }
                return config.vowelTestNote.centsOffset(from: freq)
            }
            avgCentsOff = centsOffsets.isEmpty ? 0 :
                centsOffsets.reduce(0, +) / Float(centsOffsets.count)

            success = stability >= 60 && abs(avgCentsOff) <= 50
        } else {
            stability = 0
            avgCentsOff = 0
            success = false
        }

        let result = VowelTestResult(
            vowel: vowel,
            stability: stability,
            avgCentsOff: avgCentsOff,
            success: success
        )

        testedVowels[vowel] = result
        currentVowelIndex += 1

        if currentVowelIndex < config.testVowels.count {
            feedbackMessage = "\(vowel.label): \(success ? "Good!" : "Try again")"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startNextVowelTest()
            }
        } else {
            canProceed = true
            feedbackMessage = "Vowel tests complete!"
        }
    }

    private func updateInstructions() {
        currentInstruction = currentStep.instructions
    }

    private func updateProgress() {
        let total = Float(CalibrationStep.allCases.count - 1) // Exclude welcome
        let current = Float(currentStep.rawValue)
        stepProgress = current / total
    }
}

// MARK: - Calibration View Extension

extension CalibrationFlow {
    /// Check if we should show the skip button
    var canSkip: Bool {
        currentStep != .complete
    }

    /// Check if we should show the back button
    var canGoBack: Bool {
        currentStep.rawValue > 0 && currentStep != .complete
    }

    /// Get button title for current step
    var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Begin"
        case .findTopNote:
            return "I Found My Limit"
        case .complete:
            return "Start Training"
        default:
            return canProceed ? "Continue" : "Listening..."
        }
    }
}
