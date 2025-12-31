import Foundation

/// Loads and provides access to exercise definitions, templates, and training plans
final class ExerciseLoader {
    static let shared = ExerciseLoader()

    private(set) var exercises: [ExerciseDefinition] = []
    private(set) var templates: [SessionTemplate] = []
    private(set) var plans: [TrainingPlan] = []

    private var exerciseById: [String: ExerciseDefinition] = [:]
    private var templateById: [String: SessionTemplate] = [:]
    private var planById: [String: TrainingPlan] = [:]

    private init() {
        print("[ExerciseLoader] Initializing singleton...")
        loadAllResources()
        print("[ExerciseLoader] Initialization complete: \(exercises.count) exercises, \(templates.count) templates, \(plans.count) plans")
    }

    // MARK: - Loading

    private func loadAllResources() {
        loadExercises()
        loadTemplates()
        loadPlans()
    }

    private func loadExercises() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[ExerciseLoader] Failed to load exercises.json")
            return
        }

        do {
            let container = try JSONDecoder().decode(ExercisesContainer.self, from: data)
            exercises = container.exercises
            exerciseById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            print("[ExerciseLoader] Loaded \(exercises.count) exercises")
        } catch {
            print("[ExerciseLoader] Failed to decode exercises: \(error)")
        }
    }

    private func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[ExerciseLoader] Failed to load templates.json")
            return
        }

        do {
            let container = try JSONDecoder().decode(TemplatesContainer.self, from: data)
            templates = container.templates
            templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
            print("[ExerciseLoader] Loaded \(templates.count) templates")
        } catch {
            print("[ExerciseLoader] Failed to decode templates: \(error)")
        }
    }

    private func loadPlans() {
        guard let url = Bundle.main.url(forResource: "plans", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[ExerciseLoader] Failed to load plans.json")
            return
        }

        do {
            let container = try JSONDecoder().decode(PlansContainer.self, from: data)
            plans = container.plans
            planById = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
            print("[ExerciseLoader] Loaded \(plans.count) plans")
        } catch {
            print("[ExerciseLoader] Failed to decode plans: \(error)")
        }
    }

    // MARK: - Access Methods

    func exercise(id: String) -> ExerciseDefinition? {
        exerciseById[id]
    }

    func template(id: String) -> SessionTemplate? {
        templateById[id]
    }

    func plan(id: String) -> TrainingPlan? {
        planById[id]
    }

    func exercises(for category: ExerciseCategory) -> [ExerciseDefinition] {
        exercises.filter { $0.category == category.rawValue }
    }

    func exercises(for template: SessionTemplate) -> [ExerciseDefinition] {
        template.steps.compactMap { step in
            exercise(id: step.exerciseId)
        }
    }

    /// Get the default training plan (12-week A#4)
    var defaultPlan: TrainingPlan? {
        plan(id: "plan_12wk_asharp4")
    }

    /// Get recovery template (used when strain is high)
    var recoveryTemplate: SessionTemplate? {
        template(id: "tpl_recovery_cooldown_only")
    }

    // MARK: - Session Building

    /// Build a list of exercises from template IDs
    func buildExerciseList(from templateIds: [String]) -> [ExerciseDefinition] {
        var result: [ExerciseDefinition] = []

        for templateId in templateIds {
            guard let template = template(id: templateId) else { continue }
            for step in template.steps {
                if let exercise = exercise(id: step.exerciseId) {
                    result.append(exercise)
                }
            }
        }

        return result
    }

    /// Get the total estimated duration for a list of templates
    func estimatedDuration(for templateIds: [String]) -> Int {
        templateIds.compactMap { template(id: $0)?.estimatedMinutes }.reduce(0, +)
    }

    /// Get exercises targeting a specific note
    func exercises(targeting note: Note) -> [ExerciseDefinition] {
        exercises.filter { exercise in
            exercise.targetNotesEnum.contains(note)
        }
    }

    /// Get exercises by intensity level
    func exercises(intensityLevel: Int) -> [ExerciseDefinition] {
        exercises.filter { $0.intensityLevel == intensityLevel }
    }

    /// Get exercises suitable for high notes (intensity <= 2)
    var safeHighNoteExercises: [ExerciseDefinition] {
        exercises.filter { $0.intensityLevel <= 2 }
    }
}
