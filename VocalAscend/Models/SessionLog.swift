import Foundation
import SwiftData

@Model
final class SessionLog {
    var id: UUID
    var date: Date
    var totalDurationSeconds: Int
    var completedExerciseCount: Int
    var skippedExerciseCount: Int

    /// Day type from the training plan (build, light, assessment, performance)
    var dayType: String?

    /// Current phase in the training plan (1, 2, or 3)
    var trainingPhase: Int?

    /// Week number in the training plan
    var trainingWeek: Int?

    /// Whether the user reported fatigue
    var fatigueReported: Bool

    /// User notes for the session
    var notes: String?

    /// Highest strain level encountered during session
    var maxStrainLevel: String

    /// Whether session was cut short due to safety
    var endedEarlyForSafety: Bool

    /// Relationship to exercise attempts
    @Relationship(deleteRule: .cascade, inverse: \ExerciseAttempt.session)
    var attempts: [ExerciseAttempt]?

    init(dayType: String? = nil, trainingPhase: Int? = nil, trainingWeek: Int? = nil) {
        self.id = UUID()
        self.date = Date()
        self.totalDurationSeconds = 0
        self.completedExerciseCount = 0
        self.skippedExerciseCount = 0
        self.dayType = dayType
        self.trainingPhase = trainingPhase
        self.trainingWeek = trainingWeek
        self.fatigueReported = false
        self.maxStrainLevel = StrainLevel.none.rawValue
        self.endedEarlyForSafety = false
        self.attempts = []
    }

    // MARK: - Computed Properties

    var dayTypeEnum: DayType? {
        guard let dayType else { return nil }
        return DayType(rawValue: dayType)
    }

    var maxStrainLevelEnum: StrainLevel {
        StrainLevel(rawValue: maxStrainLevel) ?? .none
    }

    var formattedDuration: String {
        let minutes = totalDurationSeconds / 60
        let seconds = totalDurationSeconds % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    var attemptsList: [ExerciseAttempt] {
        attempts ?? []
    }

    // MARK: - Methods

    func addAttempt(_ attempt: ExerciseAttempt) {
        if attempts == nil {
            attempts = []
        }
        attempts?.append(attempt)
        completedExerciseCount += 1

        // Update max strain level
        if let attemptStrain = StrainLevel(rawValue: attempt.strainLevel),
           attemptStrain > maxStrainLevelEnum {
            maxStrainLevel = attemptStrain.rawValue
        }
    }

    func recordSkip() {
        skippedExerciseCount += 1
    }

    func finalize(duration: Int) {
        totalDurationSeconds = duration
    }
}
