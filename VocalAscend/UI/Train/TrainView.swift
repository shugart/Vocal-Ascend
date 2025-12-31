import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var planProgress: [UserPlanProgress]
    @Query(sort: \SessionLog.date, order: .reverse) private var recentSessions: [SessionLog]
    @Query(sort: \ExerciseAttempt.createdAt, order: .reverse) private var recentAttempts: [ExerciseAttempt]

    @StateObject private var sessionPlanner = SessionPlanner()
    @StateObject private var exerciseEngine = ExerciseEngine()

    @State private var sessionState: SessionState = .idle
    @State private var currentExerciseIndex = 0
    @State private var showingExerciseRating = false
    @State private var lastCompletedMetrics: AttemptMetrics?
    @State private var sessionLog: SessionLog?
    @State private var sessionStartTime: Date?
    @State private var showFatiguePrompt = false
    @State private var userReportedFatigue = false

    enum SessionState {
        case idle
        case overview
        case active
        case exerciseComplete
        case sessionComplete
    }

    private var voiceProfile: VoiceProfile? {
        voiceProfiles.first
    }

    private var currentPlanProgress: UserPlanProgress? {
        planProgress.first
    }

    var body: some View {
        NavigationStack {
            Group {
                switch sessionState {
                case .idle:
                    idleView
                case .overview:
                    sessionOverviewView
                case .active:
                    activeExerciseView
                case .exerciseComplete:
                    exerciseCompleteView
                case .sessionComplete:
                    sessionSummaryView
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                if sessionState == .active || sessionState == .exerciseComplete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End Session") {
                            endSession()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            generatePlanIfNeeded()
        }
        .onChange(of: voiceProfiles.count) { _, _ in
            // Regenerate plan when voice profiles change (e.g., after calibration)
            if voiceProfile != nil && sessionPlanner.todaysSession == nil {
                generatePlanIfNeeded()
            }
        }
    }

    private var navigationTitle: String {
        switch sessionState {
        case .idle: return "Train"
        case .overview: return "Today's Session"
        case .active, .exerciseComplete: return sessionPlanner.todaysSession?.dayType.displayName ?? "Training"
        case .sessionComplete: return "Session Complete"
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            if voiceProfile == nil {
                noProfileView
            } else if sessionPlanner.todaysSession != nil {
                sessionReadyView
            } else {
                loadingView
            }

            Spacer()
        }
        .padding()
    }

    private var noProfileView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Calibration Needed")
                .font(.title2)
                .fontWeight(.bold)

            Text("Before you start training, we need to learn about your voice.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            NavigationLink {
                CalibrationView()
            } label: {
                Text("Start Calibration")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
    }

    private var sessionReadyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Ready to Train")
                .font(.title2)
                .fontWeight(.bold)

            if let session = sessionPlanner.todaysSession {
                VStack(spacing: 8) {
                    HStack {
                        Label("\(session.estimatedMinutes) min", systemImage: "clock")
                        Spacer()
                        Label("\(session.exercises.count) exercises", systemImage: "list.bullet")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(session.sessionGoal)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: { sessionState = .overview }) {
                Text("View Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Preparing your session...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Overview View

    private var sessionOverviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let session = sessionPlanner.todaysSession {
                    // Session header
                    SessionHeaderView(session: session)

                    // Warnings if any
                    if !session.warnings.isEmpty {
                        WarningsView(warnings: session.warnings)
                    }

                    // Exercise list
                    VStack(spacing: 12) {
                        ForEach(Array(session.exercises.enumerated()), id: \.offset) { index, exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                index: index + 1,
                                isNext: index == 0
                            )
                        }
                    }

                    // Start button
                    Button(action: startSession) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .alert("Feeling Fatigued?", isPresented: $showFatiguePrompt) {
            Button("Yes, I'm tired") {
                userReportedFatigue = true
                regeneratePlan()
            }
            Button("No, I'm fine", role: .cancel) {
                userReportedFatigue = false
            }
        } message: {
            Text("If you're feeling vocally fatigued, we can adjust today's session to be easier.")
        }
    }

    // MARK: - Active Exercise View

    private var activeExerciseView: some View {
        VStack {
            if let session = sessionPlanner.todaysSession,
               currentExerciseIndex < session.exercises.count {
                let exercise = session.exercises[currentExerciseIndex]

                ActiveExerciseView(
                    exercise: exercise,
                    exerciseEngine: exerciseEngine,
                    exerciseNumber: currentExerciseIndex + 1,
                    totalExercises: session.exercises.count,
                    onComplete: handleExerciseComplete,
                    onSkip: handleExerciseSkip,
                    onHardStop: handleHardStop
                )
            }
        }
    }

    // MARK: - Exercise Complete View

    private var exerciseCompleteView: some View {
        ExerciseRatingView(
            metrics: lastCompletedMetrics,
            onRate: handleExerciseRating
        )
    }

    // MARK: - Session Summary View

    private var sessionSummaryView: some View {
        SessionSummaryView(
            sessionLog: sessionLog,
            onDone: {
                sessionState = .idle
                resetSession()
            }
        )
    }

    // MARK: - Actions

    private func generatePlanIfNeeded() {
        print("[TrainView] generatePlanIfNeeded called")
        print("[TrainView] voiceProfile: \(voiceProfile != nil ? "exists" : "nil")")
        print("[TrainView] todaysSession: \(sessionPlanner.todaysSession != nil ? "exists" : "nil")")

        guard let profile = voiceProfile else {
            print("[TrainView] No voice profile, returning early")
            return
        }

        // Create default plan progress if needed
        let progress = currentPlanProgress ?? createDefaultPlanProgress()
        print("[TrainView] Using plan progress: \(progress.planId)")

        let session = sessionPlanner.planSession(
            voiceProfile: profile,
            planProgress: progress,
            recentAttempts: Array(recentAttempts.prefix(100)),
            recentSessions: Array(recentSessions.prefix(14)),
            userReportedFatigue: userReportedFatigue
        )

        print("[TrainView] Session generated with \(session.exercises.count) exercises")
        print("[TrainView] todaysSession after planning: \(sessionPlanner.todaysSession != nil ? "exists" : "nil")")
    }

    private func regeneratePlan() {
        guard let profile = voiceProfile,
              let progress = currentPlanProgress else { return }

        let _ = sessionPlanner.planSession(
            voiceProfile: profile,
            planProgress: progress,
            recentAttempts: Array(recentAttempts.prefix(100)),
            recentSessions: Array(recentSessions.prefix(14)),
            userReportedFatigue: userReportedFatigue
        )
    }

    private func createDefaultPlanProgress() -> UserPlanProgress {
        let progress = UserPlanProgress(planId: "plan_12wk_asharp4")
        modelContext.insert(progress)
        return progress
    }

    private func startSession() {
        guard let session = sessionPlanner.todaysSession else { return }

        // Create session log
        let log = SessionLog(
            dayType: session.dayType.rawValue,
            trainingPhase: session.phase,
            trainingWeek: session.week
        )
        modelContext.insert(log)
        sessionLog = log
        sessionStartTime = Date()

        // Start first exercise
        currentExerciseIndex = 0
        startCurrentExercise()
        sessionState = .active
    }

    private func startCurrentExercise() {
        guard let session = sessionPlanner.todaysSession,
              currentExerciseIndex < session.exercises.count else {
            completeSession()
            return
        }

        let exercise = session.exercises[currentExerciseIndex]
        exerciseEngine.start(
            exercise: exercise.definition,
            targetNote: exercise.adjustedTargetNotes.first,
            targetVowel: exercise.suggestedVowel
        )
    }

    private func handleExerciseComplete() {
        lastCompletedMetrics = exerciseEngine.generateAttemptResult()
        sessionState = .exerciseComplete
    }

    private func handleExerciseSkip() {
        sessionLog?.recordSkip()
        moveToNextExercise()
    }

    private func handleHardStop() {
        // Record the attempt with high strain
        if let metrics = exerciseEngine.generateAttemptResult() {
            recordAttempt(metrics: metrics, rating: 3)
        }

        sessionLog?.endedEarlyForSafety = true
        voiceProfile?.recordHighStrain()
        completeSession()
    }

    private func handleExerciseRating(rating: Int, notes: String?) {
        if let metrics = lastCompletedMetrics {
            recordAttempt(metrics: metrics, rating: rating, notes: notes)
        }
        moveToNextExercise()
    }

    private func recordAttempt(metrics: AttemptMetrics, rating: Int, notes: String? = nil) {
        guard let exercise = sessionPlanner.todaysSession?.exercises[safe: currentExerciseIndex] else { return }

        let attempt = ExerciseAttempt(
            exerciseId: exercise.definition.id,
            exerciseName: exercise.definition.name,
            category: exercise.definition.category,
            targetNote: metrics.targetNote,
            targetVowel: metrics.targetVowel
        )
        attempt.update(with: metrics)
        attempt.setRating(rating, notes: notes)
        attempt.session = sessionLog

        modelContext.insert(attempt)
        sessionLog?.addAttempt(attempt)
    }

    private func moveToNextExercise() {
        currentExerciseIndex += 1
        exerciseEngine.reset()

        if let session = sessionPlanner.todaysSession,
           currentExerciseIndex < session.exercises.count {
            startCurrentExercise()
            sessionState = .active
        } else {
            completeSession()
        }
    }

    private func endSession() {
        exerciseEngine.stop()
        completeSession()
    }

    private func completeSession() {
        // Finalize session log
        if let startTime = sessionStartTime {
            let duration = Int(Date().timeIntervalSince(startTime))
            sessionLog?.finalize(duration: duration)
        }

        // Update plan progress
        currentPlanProgress?.advanceDay()

        sessionState = .sessionComplete
    }

    private func resetSession() {
        sessionLog = nil
        sessionStartTime = nil
        currentExerciseIndex = 0
        lastCompletedMetrics = nil
        userReportedFatigue = false
        generatePlanIfNeeded()
    }
}

// MARK: - Session Header View

struct SessionHeaderView: View {
    let session: SessionPlanner.PlannedSession

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Phase \(session.phase) - Week \(session.week)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(session.dayType.displayName + " Day")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("~\(session.estimatedMinutes) min")
                        .font(.headline)
                    Text("Focus: \(session.focusNote.fullName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(session.sessionGoal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Warnings View

struct WarningsView: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "info.circle")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.orange)

            ForEach(warnings, id: \.self) { warning in
                Text("• \(warning)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise Card View

struct ExerciseCardView: View {
    let exercise: SessionPlanner.PlannedExercise
    let index: Int
    let isNext: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Index circle
            ZStack {
                Circle()
                    .fill(isNext ? Color.accentColor : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(isNext ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.definition.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if exercise.isOptional {
                        Text("Optional")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if !exercise.adjustedTargetNotes.isEmpty {
                        Label(
                            exercise.adjustedTargetNotes.map { $0.fullName }.joined(separator: "-"),
                            systemImage: "music.note"
                        )
                    }
                    if let vowel = exercise.suggestedVowel {
                        Label(vowel.label, systemImage: "mouth")
                    }
                    Label(exercise.definition.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Intensity indicator
            IntensityIndicator(level: exercise.definition.intensityLevel)
        }
        .padding()
        .background(isNext ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Intensity Indicator

struct IntensityIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { i in
                Rectangle()
                    .fill(i <= level ? intensityColor : Color(.systemGray4))
                    .frame(width: 4, height: 8 + CGFloat(i * 2))
            }
        }
    }

    private var intensityColor: Color {
        switch level {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    TrainView()
}
