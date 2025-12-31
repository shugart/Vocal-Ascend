import SwiftUI

struct SessionSummaryView: View {
    let sessionLog: SessionLog?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celebration header
                headerView

                // Session stats
                if let log = sessionLog {
                    statsCard(log)

                    // Exercise breakdown
                    if let attempts = log.attempts, !attempts.isEmpty {
                        exerciseBreakdown(attempts)
                    }

                    // Safety notes if applicable
                    if log.endedEarlyForSafety {
                        safetyNote
                    }
                }

                // Motivational message
                motivationalMessage

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            if let log = sessionLog {
                Text(log.formattedDuration)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Stats Card

    private func statsCard(_ log: SessionLog) -> some View {
        VStack(spacing: 16) {
            Text("Session Stats")
                .font(.headline)

            HStack(spacing: 24) {
                StatItem(
                    value: "\(log.completedExerciseCount)",
                    label: "Exercises",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatItem(
                    value: log.formattedDuration,
                    label: "Duration",
                    icon: "clock.fill",
                    color: .blue
                )

                StatItem(
                    value: log.maxStrainLevelEnum.displayName,
                    label: "Max Strain",
                    icon: "heart.fill",
                    color: strainColor(log.maxStrainLevelEnum)
                )
            }

            if log.skippedExerciseCount > 0 {
                Text("\(log.skippedExerciseCount) exercise(s) skipped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exercise Breakdown

    private func exerciseBreakdown(_ attempts: [ExerciseAttempt]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Breakdown")
                .font(.headline)

            ForEach(attempts, id: \.id) { attempt in
                ExerciseResultRow(attempt: attempt)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Safety Note

    private var safetyNote: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Session Ended Early")
                    .font(.headline)
            }

            Text("This session was cut short due to strain detection. Remember to rest your voice and come back tomorrow for a recovery session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Motivational Message

    private var motivationalMessage: some View {
        VStack(spacing: 8) {
            Text(randomMotivation)
                .font(.subheadline)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var randomMotivation: String {
        let messages = [
            "Every session brings you closer to your goal!",
            "Consistency is key. Great job showing up today!",
            "Your voice is getting stronger every day.",
            "Progress happens one note at a time.",
            "Rest well and come back ready to sing!"
        ]
        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Helpers

    private func strainColor(_ level: StrainLevel) -> Color {
        switch level {
        case .none: return .green
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Exercise Result Row

struct ExerciseResultRow: View {
    let attempt: ExerciseAttempt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(attempt.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    if let targetNote = attempt.targetNote {
                        Text(targetNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Stability: \(Int(attempt.stabilityScore))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Rating indicator
            if let rating = attempt.userRating {
                ratingEmoji(rating)
            }

            // Success indicator
            Image(systemName: attempt.isSuccessful ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(attempt.isSuccessful ? .green : .secondary)
        }
        .padding(.vertical, 8)
    }

    private func ratingEmoji(_ rating: Int) -> some View {
        Text(rating == 1 ? "😊" : (rating == 2 ? "😐" : "😓"))
            .font(.title3)
    }
}

#Preview {
    let log = SessionLog(dayType: "build", trainingPhase: 1, trainingWeek: 2)
    log.totalDurationSeconds = 1245
    log.completedExerciseCount = 8

    return SessionSummaryView(sessionLog: log, onDone: {})
}
