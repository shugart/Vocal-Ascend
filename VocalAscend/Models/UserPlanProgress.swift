import Foundation
import SwiftData

@Model
final class UserPlanProgress {
    var id: UUID

    /// The plan ID (e.g., "plan_12wk_asharp4")
    var planId: String

    /// When the user started this plan
    var startDate: Date

    /// Current week number (1-12)
    var currentWeek: Int

    /// Current phase (1, 2, or 3)
    var currentPhase: Int

    /// Number of training days completed
    var trainingDaysCompleted: Int

    /// Current day index within the week (1-5)
    var currentDayIndex: Int

    /// Whether the user has unlocked A4 attempts
    var a4Unlocked: Bool

    /// Whether the user has unlocked A#4 attempts
    var aSharp4Unlocked: Bool

    /// Number of A#4 attempts today
    var aSharp4AttemptsToday: Int

    /// Last training date
    var lastTrainingDate: Date?

    /// Current streak (consecutive training days)
    var currentStreak: Int

    /// Best streak ever
    var bestStreak: Int

    /// Notes or adjustments
    var notes: String?

    init(planId: String, startDate: Date = Date()) {
        self.id = UUID()
        self.planId = planId
        self.startDate = startDate
        self.currentWeek = 1
        self.currentPhase = 1
        self.trainingDaysCompleted = 0
        self.currentDayIndex = 1
        self.a4Unlocked = false
        self.aSharp4Unlocked = false
        self.aSharp4AttemptsToday = 0
        self.currentStreak = 0
        self.bestStreak = 0
    }

    // MARK: - Computed Properties

    /// Target note for current phase
    var phaseTargetNote: Note {
        switch currentPhase {
        case 1: return .G4
        case 2: return .A4
        case 3: return .AS4
        default: return .G4
        }
    }

    /// Secondary target note for current phase
    var phaseSecondaryNote: Note {
        switch currentPhase {
        case 1: return .GS4
        case 2: return .GS4
        case 3: return .A4
        default: return .G4
        }
    }

    /// Top note cap for current phase
    var phaseTopNoteCap: Note {
        switch currentPhase {
        case 1: return .GS4
        case 2: return .A4
        case 3: return .AS4
        default: return .GS4
        }
    }

    /// Preferred vowels for high notes in current phase
    var phasePreferredVowels: [Vowel] {
        [.UH, .OH, .EH]
    }

    /// Daily A#4 attempt cap (only applies in Phase 3)
    var dailyASharp4Cap: Int {
        currentPhase == 3 ? 8 : 0
    }

    /// Whether user can attempt A#4 today
    var canAttemptASharp4: Bool {
        aSharp4Unlocked && aSharp4AttemptsToday < dailyASharp4Cap
    }

    /// Weeks remaining in the plan
    var weeksRemaining: Int {
        max(0, 12 - currentWeek)
    }

    /// Overall progress percentage
    var overallProgress: Float {
        Float(trainingDaysCompleted) / Float(12 * 5) * 100 // 12 weeks * 5 days
    }

    // MARK: - Methods

    func advanceDay() {
        trainingDaysCompleted += 1
        lastTrainingDate = Date()

        // Update streak
        currentStreak += 1
        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }

        // Advance day index
        currentDayIndex += 1
        if currentDayIndex > 5 {
            currentDayIndex = 1
            advanceWeek()
        }

        // Reset daily counters
        aSharp4AttemptsToday = 0
    }

    func advanceWeek() {
        currentWeek += 1

        // Update phase based on week
        if currentWeek >= 9 {
            currentPhase = 3
        } else if currentWeek >= 5 {
            currentPhase = 2
        } else {
            currentPhase = 1
        }
    }

    func recordASharp4Attempt() {
        aSharp4AttemptsToday += 1
    }

    func unlockA4() {
        a4Unlocked = true
    }

    func unlockASharp4() {
        aSharp4Unlocked = true
    }

    func resetStreak() {
        currentStreak = 0
    }

    /// Check if streak should be reset (more than 1 day since last training)
    func checkStreakContinuity() {
        guard let lastDate = lastTrainingDate else { return }

        let calendar = Calendar.current
        let daysSinceLastTraining = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0

        if daysSinceLastTraining > 1 {
            resetStreak()
        }
    }

    /// Get day type for today based on current day index
    func todaysDayType() -> DayType {
        switch currentDayIndex {
        case 1, 2, 4: return .build
        case 3: return .light
        case 5: return .assessment
        default: return .build
        }
    }
}
