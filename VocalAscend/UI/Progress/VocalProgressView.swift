import SwiftUI
import SwiftData
import Charts

struct VocalProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voiceProfiles: [VoiceProfile]
    @Query private var planProgress: [UserPlanProgress]
    @Query(sort: \SessionLog.date, order: .reverse) private var sessions: [SessionLog]
    @Query(sort: \ExerciseAttempt.createdAt, order: .reverse) private var attempts: [ExerciseAttempt]

    private var voiceProfile: VoiceProfile? { voiceProfiles.first }
    private var progress: UserPlanProgress? { planProgress.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Range map
                    RangeMapView(voiceProfile: voiceProfile)

                    // Milestones
                    MilestonesView(
                        attempts: attempts,
                        sessions: sessions,
                        progress: progress
                    )

                    // Charts section
                    if !attempts.isEmpty {
                        ProgressChartsSection(attempts: attempts)
                    }

                    // Session history
                    SessionHistorySection(sessions: Array(sessions.prefix(5)))
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
}

// MARK: - Range Map

struct RangeMapView: View {
    let voiceProfile: VoiceProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vocal Range")
                .font(.headline)

            HStack(spacing: 2) {
                ForEach(Note.supportedRange, id: \.self) { note in
                    RangeNoteIndicator(
                        note: note,
                        zone: zoneFor(note)
                    )
                }
            }
            .frame(height: 40)

            // Note labels
            HStack {
                Text("A2")
                    .font(.caption2)
                Spacer()
                Text("C5")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "Comfortable")
                LegendItem(color: .yellow, label: "Developing")
                LegendItem(color: .red.opacity(0.5), label: "Strain Zone")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func zoneFor(_ note: Note) -> RangeZone {
        guard let profile = voiceProfile else {
            return defaultZone(for: note)
        }
        return profile.rangeZone(for: note)
    }

    private func defaultZone(for note: Note) -> RangeZone {
        switch note.midiNote {
        case 45...60: // A2-C4
            return .comfortable
        case 61...67: // C#4-G4
            return .comfortable
        case 68...69: // G#4-A4
            return .developing
        default:
            return .strain
        }
    }
}

enum RangeZone {
    case comfortable, developing, strain

    var color: Color {
        switch self {
        case .comfortable: return .green
        case .developing: return .yellow
        case .strain: return .red.opacity(0.5)
        }
    }
}

struct RangeNoteIndicator: View {
    let note: Note
    let zone: RangeZone

    var body: some View {
        Rectangle()
            .fill(zone.color)
            .frame(maxWidth: .infinity)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Milestones

struct MilestonesView: View {
    let attempts: [ExerciseAttempt]
    let sessions: [SessionLog]
    let progress: UserPlanProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MilestoneCard(
                    icon: "arrow.up",
                    title: "Highest Clean Note",
                    value: highestCleanNote,
                    subtitle: highestCleanVowel
                )
                MilestoneCard(
                    icon: "flame.fill",
                    title: "Training Streak",
                    value: "\(progress?.currentStreak ?? 0)",
                    subtitle: "days"
                )
                MilestoneCard(
                    icon: "clock.fill",
                    title: "Longest Hold",
                    value: longestHold,
                    subtitle: longestHoldNote
                )
                MilestoneCard(
                    icon: "checkmark.seal.fill",
                    title: "Sessions Complete",
                    value: "\(sessionsThisMonth)",
                    subtitle: "this month"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var highestCleanNote: String {
        let successful = attempts.filter { $0.isSuccessful }
        let highNote = successful.compactMap { $0.targetNoteEnum }.max { $0.midiNote < $1.midiNote }
        return highNote?.fullName ?? "—"
    }

    private var highestCleanVowel: String {
        let successful = attempts.filter { $0.isSuccessful && $0.targetNoteEnum?.midiNote == attempts.compactMap { $0.targetNoteEnum }.max { $0.midiNote < $1.midiNote }?.midiNote }
        if let vowel = successful.first?.targetVowel {
            return "on '\(vowel)'"
        }
        return ""
    }

    private var longestHold: String {
        let maxHold = attempts.map { $0.durationSeconds }.max() ?? 0
        return String(format: "%.1fs", maxHold)
    }

    private var longestHoldNote: String {
        if let bestAttempt = attempts.max(by: { $0.durationSeconds < $1.durationSeconds }),
           let note = bestAttempt.targetNote {
            return "at \(note)"
        }
        return ""
    }

    private var sessionsThisMonth: Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return sessions.filter { $0.date >= startOfMonth }.count
    }
}

struct MilestoneCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Charts Section

struct ProgressChartsSection: View {
    let attempts: [ExerciseAttempt]
    @State private var selectedChart: ChartType = .stability

    enum ChartType: String, CaseIterable {
        case stability = "Stability"
        case accuracy = "Accuracy"
        case duration = "Duration"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)

            Picker("Chart", selection: $selectedChart) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            chartView
                .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var chartView: some View {
        let chartData = buildChartData()

        if chartData.isEmpty {
            Text("Not enough data yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(chartData) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxisLabel("Days Ago")
            .chartYAxisLabel(yAxisLabel)
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        switch selectedChart {
        case .stability, .accuracy:
            return 0...100
        case .duration:
            return 0...10
        }
    }

    private var yAxisLabel: String {
        switch selectedChart {
        case .stability:
            return "Stability %"
        case .accuracy:
            return "Accuracy"
        case .duration:
            return "Seconds"
        }
    }

    private func buildChartData() -> [ChartPoint] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let recentAttempts = attempts.filter { $0.createdAt >= sevenDaysAgo }

        // Group by day
        let grouped = Dictionary(grouping: recentAttempts) { attempt in
            calendar.startOfDay(for: attempt.createdAt)
        }

        // Calculate averages for each day
        var points: [ChartPoint] = []
        for (date, dayAttempts) in grouped.sorted(by: { $0.key < $1.key }) {
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0

            let value: Double
            switch selectedChart {
            case .stability:
                value = Double(dayAttempts.map { $0.stabilityScore }.reduce(0, +)) / Double(dayAttempts.count)
            case .accuracy:
                let avgCents = dayAttempts.map { abs($0.avgCentsOff) }.reduce(0, +) / Float(dayAttempts.count)
                value = max(0, 100 - Double(avgCents) * 2) // Convert cents off to accuracy %
            case .duration:
                value = Double(dayAttempts.map { $0.durationSeconds }.max() ?? 0)
            }

            points.append(ChartPoint(day: 7 - daysAgo, value: value))
        }

        return points
    }
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let day: Int
    let value: Double
}

// MARK: - Session History

struct SessionHistorySection: View {
    let sessions: [SessionLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if sessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            } else {
                ForEach(sessions, id: \.id) { session in
                    SessionHistoryRow(session: session)
                }

                if sessions.count >= 5 {
                    NavigationLink {
                        AllSessionsView()
                    } label: {
                        Text("View All Sessions")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionHistoryRow: View {
    let session: SessionLog

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(session.completedExerciseCount) exercises")
                    if let dayType = session.dayTypeEnum {
                        Text("•")
                        Text(dayType.displayName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Strain indicator
                Circle()
                    .fill(strainColor(session.maxStrainLevelEnum))
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private func strainColor(_ level: StrainLevel) -> Color {
        switch level {
        case .none: return .green
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - All Sessions View

struct AllSessionsView: View {
    @Query(sort: \SessionLog.date, order: .reverse) private var sessions: [SessionLog]

    var body: some View {
        List(sessions, id: \.id) { session in
            NavigationLink {
                SessionDetailView(session: session)
            } label: {
                SessionHistoryRow(session: session)
            }
        }
        .navigationTitle("All Sessions")
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: SessionLog

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: session.formattedDuration)
                if let dayType = session.dayTypeEnum {
                    LabeledContent("Day Type", value: dayType.displayName)
                }
                if let phase = session.trainingPhase {
                    LabeledContent("Phase", value: "\(phase)")
                }
                LabeledContent("Exercises", value: "\(session.completedExerciseCount)")
                LabeledContent("Max Strain", value: session.maxStrainLevelEnum.displayName)
            }

            if let attempts = session.attempts, !attempts.isEmpty {
                Section("Exercises") {
                    ForEach(attempts, id: \.id) { attempt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attempt.exerciseName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 16) {
                                if let note = attempt.targetNote {
                                    Label(note, systemImage: "music.note")
                                }
                                Label("\(Int(attempt.stabilityScore))%", systemImage: "waveform")
                                if attempt.isSuccessful {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if session.endedEarlyForSafety {
                Section {
                    Label("Session ended early due to strain detection", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Session Details")
    }
}

#Preview {
    VocalProgressView()
}
