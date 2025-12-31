import Foundation
import SwiftData
import Combine

/// Plans daily training sessions based on voice profile, plan progress, and safety rules
final class SessionPlanner: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var todaysSession: PlannedSession?
    @Published private(set) var isLoading = false
    @Published private(set) var safetyOverrideApplied: SafetyOverride?

    // MARK: - Types

    struct PlannedSession {
        let id: UUID
        let dayType: DayType
        let phase: Int
        let week: Int
        let dayIndex: Int
        let exercises: [PlannedExercise]
        let estimatedMinutes: Int
        let topNoteCap: Note
        let preferredVowels: [Vowel]
        let focusNote: Note
        let sessionGoal: String
        let warnings: [String]
        let generatedAt: Date
    }

    struct PlannedExercise {
        let definition: ExerciseDefinition
        let sequence: Int
        let adjustedTargetNotes: [Note]
        let suggestedVowel: Vowel?
        let isOptional: Bool
        let notes: String?
    }

    enum SafetyOverride: Equatable {
        case strainRedRecovery
        case userFatigueReduction
        case dailyLimitReached
    }

    // MARK: - Dependencies

    private let exerciseLoader = ExerciseLoader.shared
    private let gateEvaluator: ProgressionGateEvaluator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cached Data

    private var exercises: [ExerciseDefinition] { exerciseLoader.exercises }
    private var templates: [SessionTemplate] { exerciseLoader.templates }
    private var plan: TrainingPlan? { exerciseLoader.defaultPlan }

    // MARK: - Initialization

    init() {
        self.gateEvaluator = ProgressionGateEvaluator()
    }

    // MARK: - Public Methods

    /// Generate today's session plan
    func planSession(
        voiceProfile: VoiceProfile,
        planProgress: UserPlanProgress,
        recentAttempts: [ExerciseAttempt],
        recentSessions: [SessionLog],
        userReportedFatigue: Bool = false
    ) -> PlannedSession {
        isLoading = true
        defer { isLoading = false }

        print("[SessionPlanner] Planning session...")
        print("[SessionPlanner] Exercises loaded: \(exercises.count)")
        print("[SessionPlanner] Templates loaded: \(templates.count)")
        print("[SessionPlanner] Plan: \(plan?.id ?? "none")")

        // 1. Check safety overrides first
        let override = checkSafetyOverrides(
            voiceProfile: voiceProfile,
            recentSessions: recentSessions,
            userReportedFatigue: userReportedFatigue
        )
        safetyOverrideApplied = override

        // 2. Get current phase and day info
        let phase = determinePhase(planProgress: planProgress)
        let dayIndex = planProgress.currentDayIndex
        let week = planProgress.currentWeek

        // 3. Evaluate progression gates
        let a4Gate = gateEvaluator.evaluateA4Gate(
            attempts: recentAttempts,
            voiceProfile: voiceProfile
        )
        let aSharp4Gate = gateEvaluator.evaluateASharp4Gate(
            attempts: recentAttempts,
            voiceProfile: voiceProfile
        )

        // Update unlock status
        if a4Gate.isMet && !planProgress.a4Unlocked {
            planProgress.unlockA4()
        }
        if aSharp4Gate.isMet && !planProgress.aSharp4Unlocked {
            planProgress.unlockASharp4()
        }

        // 4. Determine day type and templates
        let dayType = determineDayType(override: override, dayIndex: dayIndex, phase: phase)
        let templateIds = getTemplateIds(for: dayType, phase: phase, dayIndex: dayIndex, override: override)

        // 5. Build exercise list from templates
        var plannedExercises: [PlannedExercise] = []
        var sequence = 0

        for templateId in templateIds {
            guard let template = templates.first(where: { $0.id == templateId }) else { continue }

            for step in template.steps {
                guard let exercise = exercises.first(where: { $0.id == step.exerciseId }) else { continue }

                // Skip belt exercises if fatigue override is active
                if override == .userFatigueReduction && exercise.categoryEnum == .belt {
                    continue
                }

                sequence += 1
                let plannedExercise = buildPlannedExercise(
                    exercise: exercise,
                    sequence: sequence,
                    phase: phase,
                    planProgress: planProgress,
                    voiceProfile: voiceProfile
                )
                plannedExercises.append(plannedExercise)
            }
        }

        // 6. Calculate estimated duration
        let estimatedMinutes = plannedExercises.reduce(0) { total, ex in
            total + (ex.definition.durationSeconds + ex.definition.restSeconds) / 60
        }

        // 7. Determine top note cap and focus
        let topNoteCap = determineTopNoteCap(phase: phase, planProgress: planProgress)
        let focusNote = determineFocusNote(phase: phase)
        let preferredVowels = determinePreferredVowels(phase: phase)

        // 8. Build warnings list
        var warnings: [String] = []

        if !a4Gate.isMet && phase >= 2 {
            warnings.append(contentsOf: a4Gate.blockers)
        }
        if !aSharp4Gate.isMet && phase >= 3 {
            warnings.append(contentsOf: aSharp4Gate.blockers)
        }
        if override == .strainRedRecovery {
            warnings.append("Recovery session due to recent high strain")
        }
        if override == .userFatigueReduction {
            warnings.append("Reduced intensity due to reported fatigue")
        }

        // 9. Build session goal message
        let sessionGoal = buildSessionGoal(dayType: dayType, phase: phase, focusNote: focusNote)

        let session = PlannedSession(
            id: UUID(),
            dayType: dayType,
            phase: phase,
            week: week,
            dayIndex: dayIndex,
            exercises: plannedExercises,
            estimatedMinutes: estimatedMinutes,
            topNoteCap: topNoteCap,
            preferredVowels: preferredVowels,
            focusNote: focusNote,
            sessionGoal: sessionGoal,
            warnings: warnings,
            generatedAt: Date()
        )

        todaysSession = session
        return session
    }

    /// Check if the session plan should be regenerated
    func shouldRegenerate(lastPlan: PlannedSession?) -> Bool {
        guard let plan = lastPlan else { return true }

        // Regenerate if it's a new day
        let calendar = Calendar.current
        return !calendar.isDateInToday(plan.generatedAt)
    }

    // MARK: - Safety Override Checks

    private func checkSafetyOverrides(
        voiceProfile: VoiceProfile,
        recentSessions: [SessionLog],
        userReportedFatigue: Bool
    ) -> SafetyOverride? {
        // Check for strain red in last 24 hours
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()

        if let lastStrain = voiceProfile.lastHighStrainDate, lastStrain >= yesterday {
            return .strainRedRecovery
        }

        // Check recent sessions for high strain
        let recentHighStrain = recentSessions.first { session in
            session.date >= yesterday && session.maxStrainLevelEnum == .high
        }
        if recentHighStrain != nil {
            return .strainRedRecovery
        }

        // Check user fatigue
        if userReportedFatigue {
            return .userFatigueReduction
        }

        // Check daily time limit
        let todaysSessions = recentSessions.filter { session in
            Calendar.current.isDateInToday(session.date)
        }
        let todaysMinutes = todaysSessions.reduce(0) { $0 + $1.totalDurationSeconds / 60 }
        if todaysMinutes >= 25 {
            return .dailyLimitReached
        }

        return nil
    }

    // MARK: - Phase and Day Type Determination

    private func determinePhase(planProgress: UserPlanProgress) -> Int {
        let week = planProgress.currentWeek
        if week >= 9 {
            return 3
        } else if week >= 5 {
            return 2
        } else {
            return 1
        }
    }

    private func determineDayType(override: SafetyOverride?, dayIndex: Int, phase: Int) -> DayType {
        // Safety override takes precedence
        if override == .strainRedRecovery || override == .dailyLimitReached {
            return .light
        }

        // Normal day type based on day index
        switch dayIndex {
        case 1, 2, 4:
            return .build
        case 3:
            return .light
        case 5:
            return .assessment
        default:
            // Phase 3, day 4 is performance
            if phase == 3 && dayIndex == 4 {
                return .performance
            }
            return .build
        }
    }

    private func getTemplateIds(
        for dayType: DayType,
        phase: Int,
        dayIndex: Int,
        override: SafetyOverride?
    ) -> [String] {
        // Force recovery template for safety overrides
        if override == .strainRedRecovery || override == .dailyLimitReached {
            return ["tpl_warmup_standard_6min", "tpl_recovery_cooldown_only"]
        }

        // Get templates from plan if available
        if let plan = plan,
           let phaseData = plan.phases.first(where: { $0.weeks.contains(phase <= 4 ? phase : (phase <= 8 ? phase : phase)) }),
           let dayPlan = phaseData.weeklyStructure.plan(for: dayIndex) {
            return dayPlan.sessionTemplateIds
        }

        // Fallback templates based on day type and phase
        switch dayType {
        case .build:
            if phase == 1 {
                return [
                    "tpl_warmup_standard_6min",
                    "tpl_mix_builder_8min",
                    "tpl_high_note_skill_6min",
                    "tpl_recovery_cooldown_only"
                ]
            } else if phase == 2 {
                return [
                    "tpl_warmup_standard_6min",
                    "tpl_mix_builder_8min",
                    "tpl_belt_extension_8min",
                    "tpl_recovery_cooldown_only"
                ]
            } else {
                return [
                    "tpl_warmup_standard_6min",
                    "tpl_belt_extension_8min",
                    "tpl_high_note_skill_6min",
                    "tpl_recovery_cooldown_only"
                ]
            }

        case .light:
            return [
                "tpl_warmup_standard_6min",
                "tpl_mix_builder_8min",
                "tpl_recovery_cooldown_only"
            ]

        case .assessment:
            return [
                "tpl_warmup_standard_6min",
                "tpl_high_note_skill_6min",
                "tpl_recovery_cooldown_only"
            ]

        case .performance:
            return [
                "tpl_warmup_standard_6min",
                "tpl_belt_phrase_6min",
                "tpl_high_note_skill_6min",
                "tpl_recovery_cooldown_only"
            ]
        }
    }

    // MARK: - Exercise Planning

    private func buildPlannedExercise(
        exercise: ExerciseDefinition,
        sequence: Int,
        phase: Int,
        planProgress: UserPlanProgress,
        voiceProfile: VoiceProfile
    ) -> PlannedExercise {
        // Adjust target notes based on top note cap
        let topNoteCap = determineTopNoteCap(phase: phase, planProgress: planProgress)
        let adjustedNotes = adjustTargetNotes(
            original: exercise.targetNotesEnum,
            cap: topNoteCap,
            voiceProfile: voiceProfile
        )

        // Suggest a vowel based on profile and phase
        let suggestedVowel = suggestVowel(
            for: exercise,
            phase: phase,
            voiceProfile: voiceProfile
        )

        // Determine if exercise is optional (e.g., belt exercises in Phase 1)
        let isOptional = exercise.categoryEnum == .belt && phase == 1

        // Build notes
        var notes: String? = nil
        if isOptional {
            notes = "Optional - focus on mix coordination first"
        }

        return PlannedExercise(
            definition: exercise,
            sequence: sequence,
            adjustedTargetNotes: adjustedNotes,
            suggestedVowel: suggestedVowel,
            isOptional: isOptional,
            notes: notes
        )
    }

    private func adjustTargetNotes(
        original: [Note],
        cap: Note,
        voiceProfile: VoiceProfile
    ) -> [Note] {
        return original.compactMap { note in
            if note.midiNote > cap.midiNote {
                // Cap at the maximum allowed note
                return cap
            }
            return note
        }
    }

    private func suggestVowel(
        for exercise: ExerciseDefinition,
        phase: Int,
        voiceProfile: VoiceProfile
    ) -> Vowel? {
        // If exercise has specific vowels, pick the narrowest one for high notes
        let exerciseVowels = exercise.targetVowelsEnum
        if !exerciseVowels.isEmpty {
            // Prefer narrow vowels for safety
            return exerciseVowels.first { $0.isNarrow } ?? exerciseVowels.first
        }

        // Phase-based suggestions
        switch phase {
        case 1: return .UH
        case 2: return .UH
        case 3: return .EH
        default: return .UH
        }
    }

    // MARK: - Note Caps and Focus

    private func determineTopNoteCap(phase: Int, planProgress: UserPlanProgress) -> Note {
        switch phase {
        case 1:
            return .GS4
        case 2:
            return planProgress.a4Unlocked ? .A4 : .GS4
        case 3:
            if planProgress.aSharp4Unlocked && planProgress.canAttemptASharp4 {
                return .AS4
            }
            return planProgress.a4Unlocked ? .A4 : .GS4
        default:
            return .GS4
        }
    }

    private func determineFocusNote(phase: Int) -> Note {
        switch phase {
        case 1: return .G4
        case 2: return .A4
        case 3: return .AS4
        default: return .G4
        }
    }

    private func determinePreferredVowels(phase: Int) -> [Vowel] {
        // All phases prefer narrow vowels for high notes
        return [.UH, .OH, .EH]
    }

    private func buildSessionGoal(dayType: DayType, phase: Int, focusNote: Note) -> String {
        switch dayType {
        case .build:
            return "Build strength and coordination towards \(focusNote.fullName)"
        case .light:
            return "Light maintenance - focus on technique, not pushing"
        case .assessment:
            return "Test your progress - clean, sustained holds"
        case .performance:
            return "Apply your skills - controlled belt phrases"
        }
    }
}
