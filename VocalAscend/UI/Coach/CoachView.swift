import SwiftUI

struct CoachView: View {
    @State private var isOnline = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Last attempt summary
                    LastAttemptSummaryView()

                    // Offline feedback section
                    OfflineFeedbackSection()

                    // AI Coach section
                    if isOnline {
                        AICoachSection()
                    } else {
                        OfflineCoachPlaceholder()
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
        }
    }
}

// MARK: - Last Attempt Summary

struct LastAttemptSummaryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Attempt")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Target: A4")
                    Text("Achieved: G#4")
                    Text("Stability: 72%")
                }
                .font(.subheadline)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("-15 cents")
                        .foregroundStyle(.orange)
                    Text("3.2 sec")
                    Text("No strain")
                        .foregroundStyle(.green)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Offline Feedback Section

struct OfflineFeedbackSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Quick Tips")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                FeedbackBullet(text: "Your pitch is slightly flat - try lifting your soft palate")
                FeedbackBullet(text: "Good stability! Keep the breath support consistent")
                FeedbackBullet(text: "Consider narrowing the vowel as you approach A4")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FeedbackBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - AI Coach Section

struct AICoachSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Coach")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "waveform.badge.magnifyingglass")
                        Text("Analyze Last Attempt")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: {}) {
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
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Offline Placeholder

struct OfflineCoachPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Connect to use AI Coach")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CoachView()
}
