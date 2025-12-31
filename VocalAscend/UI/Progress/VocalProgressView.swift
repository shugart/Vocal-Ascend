import SwiftUI
import Charts

struct ProgressView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Range map
                    RangeMapView()

                    // Milestones
                    MilestonesView()

                    // Charts section
                    ProgressChartsSection()

                    // Session history
                    SessionHistorySection()
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
}

// MARK: - Range Map

struct RangeMapView: View {
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
        // TODO: Derive from VoiceProfile
        switch note {
        case .A2, .AS2, .B2, .C3, .CS3, .D3, .DS3, .E3, .F3, .FS3, .G3, .GS3, .A3, .AS3, .B3, .C4, .CS4, .D4, .DS4, .E4, .F4:
            return .comfortable
        case .FS4, .G4, .GS4, .A4:
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
                    value: "G#4",
                    subtitle: "on 'Uh' vowel"
                )
                MilestoneCard(
                    icon: "flame.fill",
                    title: "Training Streak",
                    value: "7",
                    subtitle: "days"
                )
                MilestoneCard(
                    icon: "clock.fill",
                    title: "Longest Hold",
                    value: "4.2s",
                    subtitle: "at A4"
                )
                MilestoneCard(
                    icon: "checkmark.seal.fill",
                    title: "Sessions Complete",
                    value: "23",
                    subtitle: "this month"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)

            // Placeholder chart
            Chart {
                ForEach(sampleData, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Stability", point.stability)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 150)
            .chartYScale(domain: 0...100)
            .chartXAxisLabel("Days")
            .chartYAxisLabel("Stability %")
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sampleData: [(day: Int, stability: Double)] {
        [
            (1, 45), (2, 52), (3, 48), (4, 55), (5, 62),
            (6, 58), (7, 65), (8, 70), (9, 68), (10, 75)
        ]
    }
}

// MARK: - Session History

struct SessionHistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            ForEach(0..<3) { index in
                SessionHistoryRow(
                    date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                    duration: 18 + index * 2,
                    exerciseCount: 5 - index
                )
            }

            Button("View All Sessions") {
                // TODO: Navigate to full history
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionHistoryRow: View {
    let date: Date
    let duration: Int
    let exerciseCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(exerciseCount) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(duration) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProgressView()
}
