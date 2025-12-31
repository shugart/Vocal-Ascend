import Foundation

// MARK: - Exercise Definition

/// Defines a vocal exercise that can be performed
struct ExerciseDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let durationSeconds: Int
    let restSeconds: Int
    let intensityLevel: Int
    let targetNotes: [String]
    let targetVowels: [String]
    let instructions: String
    let coachCues: [String]
    let metrics: ExerciseMetricsConfig

    enum CodingKeys: String, CodingKey {
        case id, name, category, instructions, metrics
        case durationSeconds = "duration_seconds"
        case restSeconds = "rest_seconds"
        case intensityLevel = "intensity_level"
        case targetNotes = "target_notes"
        case targetVowels = "target_vowels"
        case coachCues = "coach_cues"
    }

    var categoryEnum: ExerciseCategory? {
        ExerciseCategory(rawValue: category)
    }

    var targetNotesEnum: [Note] {
        targetNotes.compactMap { noteString in
            // Handle both formats: "C4" and "CS4" (for C#4)
            let normalized = noteString.replacingOccurrences(of: "#", with: "S")
            return Note(rawValue: normalized)
        }
    }

    var targetVowelsEnum: [Vowel] {
        targetVowels.compactMap { Vowel(rawValue: $0) }
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds)s"
        }
    }

    var intensityDescription: String {
        switch intensityLevel {
        case 1: return "Light"
        case 2: return "Moderate"
        case 3: return "Challenging"
        case 4: return "Intense"
        default: return "Unknown"
        }
    }
}

struct ExerciseMetricsConfig: Codable, Hashable {
    let trackPitch: Bool
    let trackLoudness: Bool
    let trackStability: Bool
    let trackHoldSeconds: Bool?

    enum CodingKeys: String, CodingKey {
        case trackPitch = "track_pitch"
        case trackLoudness = "track_loudness"
        case trackStability = "track_stability"
        case trackHoldSeconds = "track_hold_seconds"
    }
}

// MARK: - Session Template

/// Defines a template for a portion of a training session
struct SessionTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let estimatedMinutes: Int
    let steps: [TemplateStep]

    enum CodingKeys: String, CodingKey {
        case id, name, steps
        case estimatedMinutes = "estimated_minutes"
    }
}

struct TemplateStep: Codable, Hashable {
    let exerciseId: String

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
    }
}

// MARK: - Training Plan

/// Defines a multi-week training plan
struct TrainingPlan: Codable, Identifiable {
    let id: String
    let name: String
    let goalNote: String
    let recommendedDaysPerWeek: Int
    let maxSessionMinutes: Int
    let phases: [TrainingPhase]

    enum CodingKeys: String, CodingKey {
        case id, name, phases
        case goalNote = "goal_note"
        case recommendedDaysPerWeek = "recommended_days_per_week"
        case maxSessionMinutes = "max_session_minutes"
    }
}

struct TrainingPhase: Codable, Identifiable {
    let phaseId: String
    let name: String
    let goal: String
    let weeks: [Int]
    let weeklyStructure: WeeklyStructure
    let targets: PhaseTargets

    var id: String { phaseId }

    enum CodingKeys: String, CodingKey {
        case name, goal, weeks, targets
        case phaseId = "phase_id"
        case weeklyStructure = "weekly_structure"
    }
}

struct WeeklyStructure: Codable {
    let day1: DayPlan
    let day2: DayPlan
    let day3: DayPlan
    let day4: DayPlan
    let day5: DayPlan

    func plan(for dayIndex: Int) -> DayPlan? {
        switch dayIndex {
        case 1: return day1
        case 2: return day2
        case 3: return day3
        case 4: return day4
        case 5: return day5
        default: return nil
        }
    }
}

struct DayPlan: Codable {
    let type: String
    let sessionTemplateIds: [String]

    var dayType: DayType? {
        DayType(rawValue: type)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sessionTemplateIds = "session_template_ids"
    }
}

struct PhaseTargets: Codable {
    let primaryNote: String
    let secondaryNote: String
    let allowedTopNoteCap: String
    let preferredVowelsHigh: [String]
    let dailyAsharpAttemptCap: Int?

    enum CodingKeys: String, CodingKey {
        case primaryNote = "primary_note"
        case secondaryNote = "secondary_note"
        case allowedTopNoteCap = "allowed_top_note_cap"
        case preferredVowelsHigh = "preferred_vowels_high"
        case dailyAsharpAttemptCap = "daily_asharp_attempt_cap"
    }

    var primaryNoteEnum: Note? {
        let normalized = primaryNote.replacingOccurrences(of: "#", with: "S")
        return Note(rawValue: normalized)
    }

    var topNoteCapEnum: Note? {
        let normalized = allowedTopNoteCap.replacingOccurrences(of: "#", with: "S")
        return Note(rawValue: normalized)
    }
}

// MARK: - JSON Root Containers

struct ExercisesContainer: Codable {
    let schemaVersion: String
    let exercises: [ExerciseDefinition]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exercises
    }
}

struct TemplatesContainer: Codable {
    let schemaVersion: String
    let templates: [SessionTemplate]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case templates
    }
}

struct PlansContainer: Codable {
    let schemaVersion: String
    let plans: [TrainingPlan]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case plans
    }
}
