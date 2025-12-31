import SwiftUI
import SwiftData

struct CoachView: View {
    @EnvironmentObject private var openAIService: OpenAIService
    @Environment(\.modelContext) private var modelContext

    @Query private var voiceProfiles: [VoiceProfile]
    @Query(sort: \ExerciseAttempt.createdAt, order: .reverse) private var attempts: [ExerciseAttempt]
    @Query(sort: \AICoachMessage.createdAt, order: .reverse) private var messages: [AICoachMessage]

    @State private var isAnalyzing = false
    @State private var aiResponse: AIResponseParser.CoachResponse?
    @State private var offlineFeedback: OfflineFeedback?
    @State private var showError = false
    @State private var errorMessage = ""

    private var voiceProfile: VoiceProfile? { voiceProfiles.first }
    private var lastAttempt: ExerciseAttempt? { attempts.first }

    private var isOnline: Bool {
        openAIService.isConfigured && openAIService.isOnline
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Last attempt summary
                    if let attempt = lastAttempt {
                        LastAttemptSummaryView(attempt: attempt)
                    } else {
                        NoAttemptsPlaceholder()
                    }

                    // Offline feedback section (always available)
                    if let feedback = offlineFeedback {
                        OfflineFeedbackSection(feedback: feedback)
                    } else if let attempt = lastAttempt {
                        let feedback = OfflineFeedbackGenerator.generateFeedback(
                            for: attempt.toAttemptMetrics(),
                            voiceProfile: voiceProfile
                        )
                        OfflineFeedbackSection(feedback: feedback)
                    }

                    // AI Coach section
                    AICoachSection(
                        isOnline: isOnline,
                        isAnalyzing: isAnalyzing,
                        response: aiResponse,
                        onAnalyze: analyzeLastAttempt,
                        onSuggestPlan: suggestPlan
                    )

                    // Recent messages
                    if !messages.isEmpty {
                        RecentMessagesSection(messages: Array(messages.prefix(3)))
                    }
                }
                .padding()
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                generateOfflineFeedback()
            }
        }
    }

    // MARK: - Actions

    private func generateOfflineFeedback() {
        guard let attempt = lastAttempt else { return }
        offlineFeedback = OfflineFeedbackGenerator.generateFeedback(
            for: attempt.toAttemptMetrics(),
            voiceProfile: voiceProfile
        )
    }

    private func analyzeLastAttempt() {
        guard let attempt = lastAttempt,
              let profile = voiceProfile else { return }

        isAnalyzing = true

        Task {
            do {
                let response = try await openAIService.analyzeAttempt(
                    voiceProfile: profile,
                    attempt: attempt.toAttemptMetrics(),
                    exerciseName: attempt.exerciseName
                )

                await MainActor.run {
                    aiResponse = response
                    isAnalyzing = false
                    saveMessage(response: response, type: "attempt_analysis")
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func suggestPlan() {
        // For now, show offline feedback
        guard let profile = voiceProfile else { return }

        let feedback = OfflineFeedbackGenerator.generateSessionSummary(
            attempts: attempts.prefix(10).map { $0.toAttemptMetrics() },
            duration: 1200
        )

        offlineFeedback = feedback
    }

    private func saveMessage(response: AIResponseParser.CoachResponse, type: String) {
        let message = AICoachMessage(
            role: "assistant",
            content: "[\(type)] " + response.headline + "\n\n" +
                "What went well: " + response.whatWentWell.joined(separator: ", ") + "\n" +
                "Next steps: " + response.fixNext.joined(separator: ", ")
        )
        modelContext.insert(message)
    }
}

// MARK: - Last Attempt Summary

struct LastAttemptSummaryView: View {
    let attempt: ExerciseAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Attempt")
                    .font(.headline)
                Spacer()
                Text(attempt.exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let target = attempt.targetNote {
                        Label("Target: \(target)", systemImage: "target")
                    }
                    if let achieved = attempt.achievedNote {
                        Label("Achieved: \(achieved)", systemImage: "music.note")
                    }
                    Label("Stability: \(Int(attempt.stabilityScore))%", systemImage: "waveform")
                }
                .font(.subheadline)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(attempt.avgCentsOff >= 0 ? "+" : "")\(Int(attempt.avgCentsOff)) cents")
                        .foregroundStyle(centsColor)
                    Text("\(String(format: "%.1f", attempt.durationSeconds)) sec")
                    Text(attempt.strainLevelEnum.displayName)
                        .foregroundStyle(strainColor)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var centsColor: Color {
        let absCents = abs(attempt.avgCentsOff)
        if absCents <= 15 { return .green }
        else if absCents <= 25 { return .yellow }
        else { return .orange }
    }

    private var strainColor: Color {
        switch attempt.strainLevelEnum {
        case .none: return .green
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - No Attempts Placeholder

struct NoAttemptsPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No attempts yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Complete an exercise to get feedback")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Offline Feedback Section

struct OfflineFeedbackSection: View {
    let feedback: OfflineFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(feedback.headline)
                    .font(.headline)
            }

            if !feedback.positives.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What went well:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)

                    ForEach(feedback.positives, id: \.self) { positive in
                        FeedbackBullet(text: positive, color: .green)
                    }
                }
            }

            if !feedback.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus on:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)

                    ForEach(feedback.improvements, id: \.self) { improvement in
                        FeedbackBullet(text: improvement, color: .orange)
                    }
                }
            }

            if !feedback.tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(feedback.tips, id: \.self) { tip in
                        FeedbackBullet(text: tip, color: .secondary)
                    }
                }
            }

            if let safety = feedback.safetyNote {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(safety)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FeedbackBullet: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - AI Coach Section

struct AICoachSection: View {
    let isOnline: Bool
    let isAnalyzing: Bool
    let response: AIResponseParser.CoachResponse?
    let onAnalyze: () -> Void
    let onSuggestPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Coach")
                    .font(.headline)

                Spacer()

                if !isOnline {
                    Text("Configure in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let response = response {
                AIResponseView(response: response)
            }

            if isOnline {
                VStack(spacing: 12) {
                    Button(action: onAnalyze) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "waveform.badge.magnifyingglass")
                            }
                            Text(isAnalyzing ? "Analyzing..." : "Analyze Last Attempt")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isAnalyzing)

                    Button(action: onSuggestPlan) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Suggest Tomorrow's Plan")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                OfflineCoachPlaceholder()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AI Response View

struct AIResponseView: View {
    let response: AIResponseParser.CoachResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(response.headline)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.purple)

            if !response.whatWentWell.isEmpty {
                ForEach(response.whatWentWell, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(item)
                            .font(.caption)
                    }
                }
            }

            if !response.fixNext.isEmpty {
                ForEach(response.fixNext, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(item)
                            .font(.caption)
                    }
                }
            }

            if let drill = response.nextDrill, let cue = drill.cue {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(.purple)
                    Text("Try: \(cue)")
                        .font(.caption)
                        .italic()
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Offline Placeholder

struct OfflineCoachPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Add API Key in Settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Recent Messages Section

struct RecentMessagesSection: View {
    let messages: [AICoachMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Coaching")
                .font(.headline)

            ForEach(messages, id: \.id) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.caption)
                        .lineLimit(2)

                    Text(message.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CoachView()
        .environmentObject(OpenAIService())
}
