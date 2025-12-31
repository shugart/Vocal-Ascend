import Foundation
import Combine
import AVFoundation

/// Manages the execution of individual vocal exercises
final class ExerciseEngine: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: ExerciseState = .idle
    @Published private(set) var currentExercise: ExerciseDefinition?
    @Published private(set) var targetNote: Note?
    @Published private(set) var targetVowel: Vowel?
    @Published private(set) var elapsedSeconds: Float = 0
    @Published private(set) var remainingSeconds: Float = 0
    @Published private(set) var isInRestPeriod = false

    // Real-time metrics
    @Published private(set) var currentPitchFrame: PitchFrame?
    @Published private(set) var currentStrainLevel: StrainLevel = .none
    @Published private(set) var accumulatedMetrics: AccumulatedMetrics?

    // Hold tracking
    @Published private(set) var holdSeconds: Float = 0
    @Published private(set) var isHoldingTarget = false
    @Published private(set) var bestHoldSeconds: Float = 0

    // MARK: - Types

    enum ExerciseState: Equatable {
        case idle
        case countdown(Int)
        case active
        case rest
        case complete
        case hardStopped
    }

    struct AccumulatedMetrics {
        var pitchFrames: [PitchFrame] = []
        var peakDBFS: Float = -60
        var totalHoldSeconds: Float = 0
        var strainEvents: [StrainLevel] = []

        var avgStability: Float {
            let frequencies = pitchFrames.compactMap { $0.f0Hz }
            return frequencies.count >= 2 ? DSPUtils.calculatePitchStability(frequencies) : 0
        }

        var avgCentsOff: Float {
            let centsValues = pitchFrames.compactMap { $0.centsOffTarget }
            return centsValues.isEmpty ? 0 : centsValues.reduce(0, +) / Float(centsValues.count)
        }

        var avgLoudness: Float {
            pitchFrames.isEmpty ? -60 :
                pitchFrames.map { $0.dbfs }.reduce(0, +) / Float(pitchFrames.count)
        }

        var avgConfidence: Float {
            pitchFrames.isEmpty ? 0 :
                pitchFrames.map { $0.confidence }.reduce(0, +) / Float(pitchFrames.count)
        }

        var maxStrainLevel: StrainLevel {
            strainEvents.max() ?? .none
        }

        var holdSuccessful: Bool {
            totalHoldSeconds >= 3.0
        }
    }

    // MARK: - Configuration

    struct Config {
        /// Seconds of countdown before exercise starts
        var countdownSeconds: Int = 3

        /// Cents tolerance for "on target"
        var targetCentsTolerance: Float = 25

        /// Minimum confidence to count as valid pitch
        var minConfidence: Float = 0.6

        /// Minimum seconds to count as a hold
        var minHoldSeconds: Float = 0.5

        /// Whether to play reference tones
        var playReferenceTone: Bool = false
    }

    var config = Config()

    // MARK: - Private Properties

    private var exerciseTimer: Timer?
    private var frameTimer: Timer?
    private var countdownValue = 0
    private var holdStartTime: Date?
    private var lastFrameTime: Date?
    private var metrics = AccumulatedMetrics()

    private let strainEvaluator = StrainRiskEvaluator()
    private var cancellables = Set<AnyCancellable>()

    // Audio engine reference
    private weak var audioEngine: AudioEngine?

    // Reference tone player
    private var tonePlayer: AVAudioPlayer?

    // MARK: - Initialization

    init(audioEngine: AudioEngine? = nil) {
        self.audioEngine = audioEngine
    }

    // MARK: - Public Methods

    /// Set the audio engine reference
    func setAudioEngine(_ engine: AudioEngine) {
        self.audioEngine = engine
        setupBindings()
    }

    /// Set baseline loudness for strain detection
    func setBaselineLoudness(_ dbfs: Float) {
        strainEvaluator.setBaselineLoudness(dbfs)
    }

    /// Start an exercise
    func start(
        exercise: ExerciseDefinition,
        targetNote: Note?,
        targetVowel: Vowel?
    ) {
        // Reset state
        reset()

        currentExercise = exercise
        self.targetNote = targetNote
        self.targetVowel = targetVowel
        remainingSeconds = Float(exercise.durationSeconds)

        // Start countdown
        countdownValue = config.countdownSeconds
        state = .countdown(countdownValue)

        startCountdown()
    }

    /// Pause the exercise
    func pause() {
        guard state == .active else { return }
        stopTimers()
    }

    /// Resume the exercise
    func resume() {
        guard currentExercise != nil else { return }
        startExerciseTimer()
    }

    /// Stop the exercise early
    func stop() {
        stopTimers()
        state = .complete
    }

    /// Hard stop due to safety
    func hardStop() {
        stopTimers()
        state = .hardStopped
    }

    /// Skip to rest period
    func skipToRest() {
        guard let exercise = currentExercise else { return }
        stopTimers()
        startRestPeriod(duration: exercise.restSeconds)
    }

    /// Reset the engine for a new exercise
    func reset() {
        stopTimers()
        state = .idle
        currentExercise = nil
        targetNote = nil
        targetVowel = nil
        elapsedSeconds = 0
        remainingSeconds = 0
        isInRestPeriod = false
        holdSeconds = 0
        isHoldingTarget = false
        bestHoldSeconds = 0
        metrics = AccumulatedMetrics()
        accumulatedMetrics = nil
        currentStrainLevel = .none
        strainEvaluator.reset()
    }

    /// Generate attempt result from accumulated metrics
    func generateAttemptResult() -> AttemptMetrics? {
        guard currentExercise != nil else { return nil }

        let targetNoteString = targetNote?.fullName ?? ""
        let targetVowelString = targetVowel?.rawValue

        // Find achieved note (most frequent)
        let frequencies = metrics.pitchFrames.compactMap { $0.f0Hz }
        let achievedNote: String?
        if !frequencies.isEmpty {
            let avgFreq = frequencies.reduce(0, +) / Float(frequencies.count)
            achievedNote = Note.nearest(to: avgFreq)?.note.fullName
        } else {
            achievedNote = nil
        }

        return AttemptMetrics(
            targetNote: targetNoteString,
            targetVowel: targetVowelString,
            achievedNote: achievedNote,
            avgCentsOff: metrics.avgCentsOff,
            stabilityScore: metrics.avgStability,
            avgLoudness: metrics.avgLoudness,
            peakDBFS: metrics.peakDBFS,
            durationSeconds: elapsedSeconds,
            holdSuccessful: metrics.holdSuccessful,
            strainLevel: metrics.maxStrainLevel,
            confidence: metrics.avgConfidence
        )
    }

    // MARK: - Private Methods

    private func setupBindings() {
        audioEngine?.$currentPitch
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.handlePitchFrame(frame)
            }
            .store(in: &cancellables)
    }

    private func handlePitchFrame(_ frame: PitchFrame) {
        guard state == .active else { return }

        currentPitchFrame = frame

        // Store frame with target cents offset
        var adjustedFrame = frame
        if let target = targetNote {
            let centsOff = frame.f0Hz.map { target.centsOffset(from: $0) }
            adjustedFrame = PitchFrame(
                timestamp: frame.timestamp,
                f0Hz: frame.f0Hz,
                noteName: frame.noteName,
                octave: frame.octave,
                centsOffNearest: frame.centsOffNearest,
                centsOffTarget: centsOff,
                confidence: frame.confidence,
                rms: frame.rms,
                dbfs: frame.dbfs
            )
        }
        metrics.pitchFrames.append(adjustedFrame)

        // Update peak dBFS
        if frame.dbfs > metrics.peakDBFS {
            metrics.peakDBFS = frame.dbfs
        }

        // Evaluate strain
        let strain = strainEvaluator.evaluate(frame: frame, targetNote: targetNote)
        currentStrainLevel = strain
        metrics.strainEvents.append(strain)

        // Check for hard stop
        if strainEvaluator.shouldTriggerHardStop {
            hardStop()
            return
        }

        // Update hold tracking
        updateHoldTracking(frame: frame)

        // Update accumulated metrics for UI
        accumulatedMetrics = metrics
    }

    private func updateHoldTracking(frame: PitchFrame) {
        guard let target = targetNote,
              let freq = frame.f0Hz,
              frame.confidence >= config.minConfidence else {
            // Not holding target
            if isHoldingTarget {
                finishHold()
            }
            return
        }

        let centsOff = target.centsOffset(from: freq)

        if abs(centsOff) <= config.targetCentsTolerance {
            // On target
            if !isHoldingTarget {
                // Start hold
                isHoldingTarget = true
                holdStartTime = Date()
            } else {
                // Continue hold
                if let start = holdStartTime {
                    holdSeconds = Float(Date().timeIntervalSince(start))
                }
            }
        } else {
            // Off target
            if isHoldingTarget {
                finishHold()
            }
        }
    }

    private func finishHold() {
        if holdSeconds > bestHoldSeconds {
            bestHoldSeconds = holdSeconds
        }
        if holdSeconds >= config.minHoldSeconds {
            metrics.totalHoldSeconds += holdSeconds
        }
        isHoldingTarget = false
        holdSeconds = 0
        holdStartTime = nil
    }

    private func startCountdown() {
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.countdownValue -= 1

            if self.countdownValue > 0 {
                self.state = .countdown(self.countdownValue)
            } else {
                self.exerciseTimer?.invalidate()
                self.startExercise()
            }
        }
    }

    private func startExercise() {
        state = .active

        // Play reference tone if enabled
        if config.playReferenceTone, let note = targetNote {
            playReferenceTone(for: note)
        }

        // Start exercise timer
        startExerciseTimer()

        // Start frame processing (30fps)
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            // Frame processing happens in handlePitchFrame via Combine binding
        }
    }

    private func startExerciseTimer() {
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.elapsedSeconds += 0.1
            self.remainingSeconds = max(0, self.remainingSeconds - 0.1)

            if self.remainingSeconds <= 0 {
                self.exerciseTimer?.invalidate()
                self.completeExercise()
            }
        }
    }

    private func completeExercise() {
        finishHold() // Capture any ongoing hold
        stopTimers()

        guard let exercise = currentExercise else {
            state = .complete
            return
        }

        // Start rest period if there is one
        if exercise.restSeconds > 0 {
            startRestPeriod(duration: exercise.restSeconds)
        } else {
            state = .complete
        }
    }

    private func startRestPeriod(duration: Int) {
        isInRestPeriod = true
        state = .rest
        remainingSeconds = Float(duration)

        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.remainingSeconds = max(0, self.remainingSeconds - 0.1)

            if self.remainingSeconds <= 0 {
                self.stopTimers()
                self.isInRestPeriod = false
                self.state = .complete
            }
        }
    }

    private func stopTimers() {
        exerciseTimer?.invalidate()
        exerciseTimer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        stopReferenceTone()
    }

    // MARK: - Reference Tone

    private func playReferenceTone(for note: Note) {
        // Simple sine wave generation would go here
        // For now, this is a placeholder
    }

    private func stopReferenceTone() {
        tonePlayer?.stop()
        tonePlayer = nil
    }
}

// MARK: - Exercise Engine Delegate Protocol

protocol ExerciseEngineDelegate: AnyObject {
    func exerciseEngine(_ engine: ExerciseEngine, didStartExercise exercise: ExerciseDefinition)
    func exerciseEngine(_ engine: ExerciseEngine, didComplete exercise: ExerciseDefinition, metrics: AttemptMetrics?)
    func exerciseEngine(_ engine: ExerciseEngine, didHardStop exercise: ExerciseDefinition, reason: String)
    func exerciseEngine(_ engine: ExerciseEngine, strainLevelChanged strain: StrainLevel)
}
