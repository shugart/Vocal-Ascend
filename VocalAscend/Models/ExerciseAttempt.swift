import Foundation
import SwiftData

@Model
final class ExerciseAttempt {
    var id: UUID
    var createdAt: Date

    /// Reference to the exercise definition ID
    var exerciseId: String

    /// Exercise name (denormalized for convenience)
    var exerciseName: String

    /// Exercise category
    var category: String

    /// Target note for this attempt
    var targetNote: String?

    /// Target vowel for this attempt
    var targetVowel: String?

    /// Achieved note (most frequently detected)
    var achievedNote: String?

    /// Average cents offset from target
    var avgCentsOff: Float

    /// Stability score (0-100)
    var stabilityScore: Float

    /// Average RMS loudness
    var avgLoudness: Float

    /// Peak dBFS during attempt
    var peakDBFS: Float

    /// Duration in seconds
    var durationSeconds: Float

    /// Whether the hold threshold was met (for hold exercises)
    var holdSuccessful: Bool

    /// Detected strain level
    var strainLevel: String

    /// Average pitch confidence (0-1)
    var avgConfidence: Float

    /// User rating (1 = Easy, 2 = OK, 3 = Hard)
    var userRating: Int?

    /// User notes for this attempt
    var userNotes: String?

    /// Raw metrics JSON (for detailed analysis)
    var metricsJSON: String?

    /// Parent session
    var session: SessionLog?

    init(
        exerciseId: String,
        exerciseName: String,
        category: String,
        targetNote: String? = nil,
        targetVowel: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.category = category
        self.targetNote = targetNote
        self.targetVowel = targetVowel
        self.avgCentsOff = 0
        self.stabilityScore = 0
        self.avgLoudness = 0
        self.peakDBFS = -60
        self.durationSeconds = 0
        self.holdSuccessful = false
        self.strainLevel = StrainLevel.none.rawValue
        self.avgConfidence = 0
    }

    // MARK: - Computed Properties

    var strainLevelEnum: StrainLevel {
        StrainLevel(rawValue: strainLevel) ?? .none
    }

    var categoryEnum: ExerciseCategory? {
        ExerciseCategory(rawValue: category)
    }

    var targetNoteEnum: Note? {
        guard let targetNote else { return nil }
        return Note.allCases.first { $0.fullName == targetNote || $0.rawValue == targetNote }
    }

    var achievedNoteEnum: Note? {
        guard let achievedNote else { return nil }
        return Note.allCases.first { $0.fullName == achievedNote || $0.rawValue == achievedNote }
    }

    var ratingDescription: String? {
        switch userRating {
        case 1: return "Easy"
        case 2: return "OK"
        case 3: return "Hard"
        default: return nil
        }
    }

    var isSuccessful: Bool {
        // An attempt is successful if:
        // - Stability is at least 70
        // - Average cents off is within tolerance (25)
        // - No high strain
        // - Confidence is at least 0.6
        return stabilityScore >= 70 &&
               abs(avgCentsOff) <= 25 &&
               strainLevelEnum != .high &&
               avgConfidence >= 0.6
    }

    // MARK: - Methods

    func update(with metrics: AttemptMetrics) {
        self.achievedNote = metrics.achievedNote
        self.avgCentsOff = metrics.avgCentsOff
        self.stabilityScore = metrics.stabilityScore
        self.avgLoudness = metrics.avgLoudness
        self.peakDBFS = metrics.peakDBFS
        self.durationSeconds = metrics.durationSeconds
        self.holdSuccessful = metrics.holdSuccessful
        self.strainLevel = metrics.strainLevel.rawValue
        self.avgConfidence = metrics.confidence
    }

    func setRating(_ rating: Int, notes: String? = nil) {
        self.userRating = rating
        self.userNotes = notes
    }

    func toAttemptMetrics() -> AttemptMetrics {
        AttemptMetrics(
            targetNote: targetNote ?? "",
            targetVowel: targetVowel,
            achievedNote: achievedNote,
            avgCentsOff: avgCentsOff,
            stabilityScore: stabilityScore,
            avgLoudness: avgLoudness,
            peakDBFS: peakDBFS,
            durationSeconds: durationSeconds,
            holdSuccessful: holdSuccessful,
            strainLevel: strainLevelEnum,
            confidence: avgConfidence
        )
    }
}
