import Foundation
import Combine

/// Evaluates strain risk based on real-time vocal metrics
/// Non-medical; technique risk indicator only
final class StrainRiskEvaluator: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentStrainLevel: StrainLevel = .none
    @Published private(set) var shouldTriggerHardStop = false
    @Published private(set) var strainFactors: [StrainFactor] = []

    // MARK: - Configuration

    struct Config {
        /// dBFS threshold above baseline that indicates pushing
        var loudnessThresholdAboveBaseline: Float = 6.0

        /// Stability below this with high loudness = strain
        var unstableWithLoudnessThreshold: Float = 50.0

        /// Loudness level considered "high"
        var highLoudnessDBFS: Float = -12.0

        /// Maximum safe sustained duration at high notes (seconds)
        var maxHighNoteDuration: Float = 8.0

        /// Pitch jump threshold (semitones) for scooping detection
        var pitchJumpThreshold: Float = 3.0

        /// Notes considered "high" for duration limits
        var highNoteThreshold: Note = .G4

        /// Hard stop enabled
        var hardStopEnabled: Bool = true
    }

    var config = Config()

    // MARK: - Private Properties

    private var baselineLoudness: Float = -30.0
    private var recentPitchFrames: [PitchFrame] = []
    private let maxRecentFrames = 60 // ~2 seconds at 30fps

    private var highNoteDurationAccumulator: Float = 0
    private var lastFrameTimestamp: Date?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Set baseline loudness from calibration
    func setBaselineLoudness(_ dbfs: Float) {
        baselineLoudness = dbfs
    }

    /// Evaluate a new pitch frame and update strain level
    func evaluate(frame: PitchFrame, targetNote: Note?) -> StrainLevel {
        // Add to recent frames
        recentPitchFrames.append(frame)
        if recentPitchFrames.count > maxRecentFrames {
            recentPitchFrames.removeFirst()
        }

        // Calculate time delta
        let now = frame.timestamp
        let deltaSeconds: Float
        if let lastTime = lastFrameTimestamp {
            deltaSeconds = Float(now.timeIntervalSince(lastTime))
        } else {
            deltaSeconds = 0.033 // ~30fps default
        }
        lastFrameTimestamp = now

        // Clear previous factors
        var factors: [StrainFactor] = []

        // Check each strain signal
        if let loudnessFactor = checkExcessiveLoudness(frame: frame) {
            factors.append(loudnessFactor)
        }

        if let instabilityFactor = checkInstabilityWithLoudness(frame: frame) {
            factors.append(instabilityFactor)
        }

        if let scoopingFactor = checkPitchScooping() {
            factors.append(scoopingFactor)
        }

        if let durationFactor = checkHighNoteDuration(frame: frame, targetNote: targetNote, delta: deltaSeconds) {
            factors.append(durationFactor)
        }

        // Update strain factors
        strainFactors = factors

        // Calculate overall strain level
        let level = calculateOverallStrainLevel(factors: factors)
        currentStrainLevel = level

        // Check for hard stop
        if config.hardStopEnabled && level == .high {
            shouldTriggerHardStop = true
        }

        return level
    }

    /// Reset the evaluator state (e.g., between exercises)
    func reset() {
        recentPitchFrames.removeAll()
        highNoteDurationAccumulator = 0
        lastFrameTimestamp = nil
        currentStrainLevel = .none
        shouldTriggerHardStop = false
        strainFactors.removeAll()
    }

    /// Acknowledge and reset hard stop trigger
    func acknowledgeHardStop() {
        shouldTriggerHardStop = false
    }

    // MARK: - Strain Signal Checks

    /// Check for excessive loudness relative to baseline
    private func checkExcessiveLoudness(frame: PitchFrame) -> StrainFactor? {
        let loudnessAboveBaseline = frame.dbfs - baselineLoudness

        if loudnessAboveBaseline > config.loudnessThresholdAboveBaseline + 6 {
            return StrainFactor(
                type: .excessiveLoudness,
                severity: .high,
                message: "Volume is much louder than baseline - ease off"
            )
        } else if loudnessAboveBaseline > config.loudnessThresholdAboveBaseline {
            return StrainFactor(
                type: .excessiveLoudness,
                severity: .medium,
                message: "Volume increasing - try to keep it lighter"
            )
        }

        return nil
    }

    /// Check for pitch instability combined with high loudness
    private func checkInstabilityWithLoudness(frame: PitchFrame) -> StrainFactor? {
        guard recentPitchFrames.count >= 10 else { return nil }

        // Calculate recent stability
        let recentFreqs = recentPitchFrames.suffix(10).compactMap { $0.f0Hz }
        guard recentFreqs.count >= 5 else { return nil }

        let stability = DSPUtils.calculatePitchStability(recentFreqs)

        // High loudness + low stability = strain
        if stability < config.unstableWithLoudnessThreshold && frame.dbfs > config.highLoudnessDBFS {
            return StrainFactor(
                type: .instabilityWithLoudness,
                severity: .medium,
                message: "Pitch unstable while loud - reduce volume"
            )
        }

        return nil
    }

    /// Check for sudden pitch jumps (scooping)
    private func checkPitchScooping() -> StrainFactor? {
        guard recentPitchFrames.count >= 5 else { return nil }

        let recentFreqs = recentPitchFrames.suffix(5).compactMap { $0.f0Hz }
        guard recentFreqs.count >= 3 else { return nil }

        // Check for large jumps between consecutive frames
        for i in 1..<recentFreqs.count {
            let semitones = abs(12 * log2(recentFreqs[i] / recentFreqs[i-1]))
            if semitones > config.pitchJumpThreshold {
                return StrainFactor(
                    type: .pitchScooping,
                    severity: .low,
                    message: "Pitch jumping - aim for smoother transitions"
                )
            }
        }

        return nil
    }

    /// Check for sustained high note duration
    private func checkHighNoteDuration(frame: PitchFrame, targetNote: Note?, delta: Float) -> StrainFactor? {
        guard let freq = frame.f0Hz, frame.confidence >= 0.6 else {
            // Not singing - reset accumulator
            highNoteDurationAccumulator = max(0, highNoteDurationAccumulator - delta * 2) // Decay
            return nil
        }

        // Check if current note is "high"
        guard let (currentNote, _) = Note.nearest(to: freq) else { return nil }

        if currentNote.midiNote >= config.highNoteThreshold.midiNote {
            highNoteDurationAccumulator += delta

            if highNoteDurationAccumulator > config.maxHighNoteDuration {
                return StrainFactor(
                    type: .sustainedHighNote,
                    severity: .high,
                    message: "Extended time on high notes - take a break"
                )
            } else if highNoteDurationAccumulator > config.maxHighNoteDuration * 0.7 {
                return StrainFactor(
                    type: .sustainedHighNote,
                    severity: .medium,
                    message: "Approaching high note time limit"
                )
            }
        } else {
            // Lower note - slowly decrease accumulator
            highNoteDurationAccumulator = max(0, highNoteDurationAccumulator - delta * 0.5)
        }

        return nil
    }

    // MARK: - Overall Level Calculation

    private func calculateOverallStrainLevel(factors: [StrainFactor]) -> StrainLevel {
        if factors.isEmpty {
            return .none
        }

        // Check for any high severity factors
        if factors.contains(where: { $0.severity == .high }) {
            return .high
        }

        // Count medium factors
        let mediumCount = factors.filter { $0.severity == .medium }.count
        if mediumCount >= 2 {
            return .high
        } else if mediumCount == 1 {
            return .medium
        }

        // Only low severity factors
        return .low
    }
}

// MARK: - Strain Factor

struct StrainFactor: Identifiable {
    let id = UUID()
    let type: StrainFactorType
    let severity: StrainSeverity
    let message: String
}

enum StrainFactorType: String {
    case excessiveLoudness
    case instabilityWithLoudness
    case pitchScooping
    case sustainedHighNote
}

enum StrainSeverity: Comparable {
    case low
    case medium
    case high
}
