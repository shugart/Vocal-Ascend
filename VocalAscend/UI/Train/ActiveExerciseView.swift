import SwiftUI

struct ActiveExerciseView: View {
    let exercise: SessionPlanner.PlannedExercise
    @ObservedObject var exerciseEngine: ExerciseEngine
    let exerciseNumber: Int
    let totalExercises: Int
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onHardStop: () -> Void

    @State private var showSkipConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(exerciseNumber), total: Double(totalExercises))
                .tint(Color.accentColor)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 24) {
                    // Exercise info header
                    exerciseHeader

                    // State-dependent content
                    switch exerciseEngine.state {
                    case .countdown(let seconds):
                        countdownView(seconds: seconds)
                    case .active:
                        activeView
                    case .rest:
                        restView
                    case .complete:
                        completeView
                    case .hardStopped:
                        hardStoppedView
                    case .idle:
                        EmptyView()
                    }

                    // Instructions
                    instructionsView
                }
                .padding()
            }

            // Bottom controls
            bottomControls
        }
        .onChange(of: exerciseEngine.state) { oldState, newState in
            if newState == .complete {
                onComplete()
            } else if newState == .hardStopped {
                onHardStop()
            }
        }
        .alert("Skip Exercise?", isPresented: $showSkipConfirm) {
            Button("Skip", role: .destructive) { onSkip() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This exercise will be marked as skipped in your session log.")
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            Text("\(exerciseNumber) of \(totalExercises)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(exercise.definition.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let targetNote = exercise.adjustedTargetNotes.first {
                    Label(targetNote.fullName, systemImage: "music.note")
                }
                if let vowel = exercise.suggestedVowel {
                    Label(vowel.label, systemImage: "mouth")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Countdown View

    private func countdownView(seconds: Int) -> some View {
        VStack(spacing: 16) {
            Text("Get Ready")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(seconds)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)

            if let vowel = exercise.suggestedVowel {
                Text("Prepare '\(vowel.label)'")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(spacing: 24) {
            // Timer
            timerView

            // Real-time pitch display
            pitchDisplayView

            // Hold indicator (if applicable)
            if exercise.definition.metrics.trackHoldSeconds == true {
                holdIndicatorView
            }

            // Strain indicator
            strainIndicatorView
        }
    }

    private var timerView: some View {
        VStack(spacing: 4) {
            Text(formatTime(exerciseEngine.remainingSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var pitchDisplayView: some View {
        VStack(spacing: 12) {
            if let frame = exerciseEngine.currentPitchFrame,
               let freq = frame.f0Hz,
               frame.confidence >= 0.6,
               let (note, cents) = Note.nearest(to: freq) {

                Text(note.fullName)
                    .font(.system(size: 36, weight: .bold))

                // Cents offset indicator
                HStack {
                    Rectangle()
                        .fill(centsColor(cents))
                        .frame(width: centsBarWidth(cents), height: 8)
                        .clipShape(Capsule())
                }
                .frame(width: 200, height: 8)
                .background(Color(.systemGray5))
                .clipShape(Capsule())

                Text("\(cents >= 0 ? "+" : "")\(Int(cents)) cents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Sing to see your pitch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var holdIndicatorView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: exerciseEngine.isHoldingTarget ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(exerciseEngine.isHoldingTarget ? .green : .secondary)
                Text("Hold: \(String(format: "%.1f", exerciseEngine.holdSeconds))s")
                    .font(.headline)
                Spacer()
                Text("Best: \(String(format: "%.1f", exerciseEngine.bestHoldSeconds))s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(min(exerciseEngine.holdSeconds, 3.0)), total: 3.0)
                .tint(exerciseEngine.holdSeconds >= 3.0 ? .green : Color.accentColor)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var strainIndicatorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(strainColor)
            Text("Strain: \(exerciseEngine.currentStrainLevel.displayName)")
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(strainColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var strainColor: Color {
        switch exerciseEngine.currentStrainLevel {
        case .none: return .green
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }

    // MARK: - Rest View

    private var restView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Rest")
                .font(.title2)
                .fontWeight(.bold)

            Text(formatTime(exerciseEngine.remainingSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("Take a breath, relax your voice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Exercise Complete!")
                .font(.title2)
                .fontWeight(.bold)

            if let metrics = exerciseEngine.accumulatedMetrics {
                VStack(spacing: 8) {
                    MetricRow(label: "Stability", value: "\(Int(metrics.avgStability))%")
                    MetricRow(label: "Best Hold", value: "\(String(format: "%.1f", exerciseEngine.bestHoldSeconds))s")
                    MetricRow(label: "Avg Cents", value: "\(Int(abs(metrics.avgCentsOff)))")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - Hard Stopped View

    private var hardStoppedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Session Stopped")
                .font(.title2)
                .fontWeight(.bold)

            Text("High strain detected. Take a break and rest your voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.headline)

            Text(exercise.definition.instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !exercise.definition.coachCues.isEmpty {
                Divider()
                Text("Tips")
                    .font(.headline)
                ForEach(exercise.definition.coachCues, id: \.self) { cue in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(cue)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            Button(action: { showSkipConfirm = true }) {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if exerciseEngine.state == .active {
                Button(action: { exerciseEngine.skipToRest() }) {
                    Text("End Early")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Float) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func centsColor(_ cents: Float) -> Color {
        let absCents = abs(cents)
        if absCents <= 10 {
            return .green
        } else if absCents <= 25 {
            return .yellow
        } else {
            return .red
        }
    }

    private func centsBarWidth(_ cents: Float) -> CGFloat {
        let normalized = min(abs(cents), 50) / 50
        let offset = cents >= 0 ? normalized : -normalized
        return CGFloat(100 + offset * 100)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    ActiveExerciseView(
        exercise: SessionPlanner.PlannedExercise(
            definition: ExerciseDefinition(
                id: "test",
                name: "Test Exercise",
                category: "warmup",
                durationSeconds: 120,
                restSeconds: 30,
                intensityLevel: 2,
                targetNotes: ["G4"],
                targetVowels: ["UH"],
                instructions: "Sing the target note and hold it steady.",
                coachCues: ["Keep your jaw relaxed", "Breathe from your diaphragm"],
                metrics: ExerciseMetricsConfig(
                    trackPitch: true,
                    trackLoudness: true,
                    trackStability: true,
                    trackHoldSeconds: true
                )
            ),
            sequence: 1,
            adjustedTargetNotes: [.G4],
            suggestedVowel: .UH,
            isOptional: false,
            notes: nil
        ),
        exerciseEngine: ExerciseEngine(),
        exerciseNumber: 1,
        totalExercises: 5,
        onComplete: {},
        onSkip: {},
        onHardStop: {}
    )
}
