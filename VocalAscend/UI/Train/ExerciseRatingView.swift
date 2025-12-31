import SwiftUI

struct ExerciseRatingView: View {
    let metrics: AttemptMetrics?
    let onRate: (Int, String?) -> Void

    @State private var selectedRating: Int?
    @State private var notes: String = ""
    @State private var showNotesField = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("How did that feel?")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                // Metrics summary
                if let metrics = metrics {
                    metricsCard(metrics)
                }

                // Rating buttons
                ratingButtons

                // Notes section
                if showNotesField {
                    notesSection
                }

                // Continue button
                Button(action: submitRating) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedRating != nil ? Color.accentColor : Color(.systemGray4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedRating == nil)
            }
            .padding()
        }
    }

    // MARK: - Metrics Card

    private func metricsCard(_ metrics: AttemptMetrics) -> some View {
        VStack(spacing: 16) {
            Text("Your Performance")
                .font(.headline)

            HStack(spacing: 24) {
                MetricCircle(
                    value: Int(metrics.stabilityScore),
                    label: "Stability",
                    color: stabilityColor(metrics.stabilityScore)
                )

                MetricCircle(
                    value: Int(abs(metrics.avgCentsOff)),
                    label: "Cents Off",
                    color: centsColor(metrics.avgCentsOff),
                    suffix: "c"
                )

                if metrics.holdSuccessful {
                    VStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        Text("Hold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Strain indicator if any
            if metrics.strainLevel != .none {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(strainColor(metrics.strainLevel))
                    Text("Strain level: \(metrics.strainLevel.displayName)")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(strainColor(metrics.strainLevel).opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("Rate this exercise")
                .font(.headline)

            HStack(spacing: 16) {
                RatingButton(
                    label: "Easy",
                    emoji: "😊",
                    value: 1,
                    isSelected: selectedRating == 1,
                    action: { selectRating(1) }
                )

                RatingButton(
                    label: "OK",
                    emoji: "😐",
                    value: 2,
                    isSelected: selectedRating == 2,
                    action: { selectRating(2) }
                )

                RatingButton(
                    label: "Hard",
                    emoji: "😓",
                    value: 3,
                    isSelected: selectedRating == 3,
                    action: { selectRating(3) }
                )
            }

            Button(action: { showNotesField.toggle() }) {
                Label(showNotesField ? "Hide Notes" : "Add Notes", systemImage: "note.text")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            TextField("How did it feel? Any pain or discomfort?", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
    }

    // MARK: - Helpers

    private func selectRating(_ rating: Int) {
        selectedRating = rating
    }

    private func submitRating() {
        guard let rating = selectedRating else { return }
        onRate(rating, notes.isEmpty ? nil : notes)
    }

    private func stabilityColor(_ value: Float) -> Color {
        if value >= 80 { return .green }
        else if value >= 60 { return .yellow }
        else { return .orange }
    }

    private func centsColor(_ value: Float) -> Color {
        let absCents = abs(value)
        if absCents <= 15 { return .green }
        else if absCents <= 25 { return .yellow }
        else { return .orange }
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

// MARK: - Metric Circle

struct MetricCircle: View {
    let value: Int
    let label: String
    let color: Color
    var suffix: String = ""

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: CGFloat(min(value, 100)) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(value)\(suffix)")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rating Button

struct RatingButton: View {
    let label: String
    let emoji: String
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExerciseRatingView(
        metrics: AttemptMetrics(
            targetNote: "G4",
            targetVowel: "UH",
            achievedNote: "G4",
            avgCentsOff: 12,
            stabilityScore: 78,
            avgLoudness: -18,
            peakDBFS: -12,
            durationSeconds: 45,
            holdSuccessful: true,
            strainLevel: .low,
            confidence: 0.85
        ),
        onRate: { _, _ in }
    )
}
