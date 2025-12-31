import SwiftUI

struct SettingsView: View {
    @AppStorage("toleranceCents") private var toleranceCents: Double = 25
    @AppStorage("a4Reference") private var a4Reference: Double = 440
    @AppStorage("hardStopEnabled") private var hardStopEnabled = true
    @AppStorage("maxDailyMinutes") private var maxDailyMinutes: Double = 25
    @AppStorage("aiCoachEnabled") private var aiCoachEnabled = true
    @AppStorage("sendAudioToAI") private var sendAudioToAI = false
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 9

    var body: some View {
        NavigationStack {
            Form {
                // Calibration
                Section {
                    NavigationLink {
                        CalibrationView()
                    } label: {
                        Label("Calibrate Voice", systemImage: "waveform.badge.mic")
                    }
                } header: {
                    Text("Calibration")
                }

                // Tuner Settings
                Section {
                    VStack(alignment: .leading) {
                        Text("Tolerance: ±\(Int(toleranceCents)) cents")
                        Slider(value: $toleranceCents, in: 10...50, step: 5)
                    }

                    VStack(alignment: .leading) {
                        Text("A4 Reference: \(Int(a4Reference)) Hz")
                        Slider(value: $a4Reference, in: 430...450, step: 1)
                    }
                } header: {
                    Text("Tuner")
                }

                // Safety Settings
                Section {
                    Toggle("Hard Stop on High Strain", isOn: $hardStopEnabled)

                    VStack(alignment: .leading) {
                        Text("Max Daily Training: \(Int(maxDailyMinutes)) min")
                        Slider(value: $maxDailyMinutes, in: 10...45, step: 5)
                    }
                } header: {
                    Text("Safety")
                } footer: {
                    Text("Hard stop will automatically end exercises when strain risk becomes high. Recommended to keep this enabled.")
                }

                // Reminders
                Section {
                    Toggle("Daily Reminder", isOn: $dailyReminderEnabled)

                    if dailyReminderEnabled {
                        Picker("Reminder Time", selection: $dailyReminderHour) {
                            ForEach(5..<23) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                }

                // AI Settings
                Section {
                    Toggle("Enable AI Coach", isOn: $aiCoachEnabled)

                    if aiCoachEnabled {
                        Toggle("Send Audio Clips", isOn: $sendAudioToAI)

                        NavigationLink {
                            AISettingsView()
                        } label: {
                            Text("API Configuration")
                        }
                    }
                } header: {
                    Text("AI Coach")
                } footer: {
                    if aiCoachEnabled && !sendAudioToAI {
                        Text("Only extracted features (pitch, stability, etc.) will be sent to the AI. No audio recordings.")
                    }
                }

                // Data
                Section {
                    Button("Export Session Data (JSON)") {
                        exportData(format: .json)
                    }

                    Button("Export Session Data (CSV)") {
                        exportData(format: .csv)
                    }

                    Button("Delete All Data", role: .destructive) {
                        // TODO: Show confirmation
                    }
                } header: {
                    Text("Data")
                }

                // About
                Section {
                    NavigationLink {
                        DisclaimerView()
                    } label: {
                        Text("Disclaimer")
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }

    private func exportData(format: ExportFormat) {
        // TODO: Implement export
    }
}

enum ExportFormat {
    case json, csv
}

// MARK: - Calibration View Placeholder

struct CalibrationView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Voice Calibration")
                .font(.title)
                .fontWeight(.bold)

            Text("This guided process will help us understand your voice and create a personalized training plan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button("Start Calibration") {
                // TODO: Start calibration flow
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationTitle("Calibrate")
    }
}

// MARK: - AI Settings View

struct AISettingsView: View {
    @AppStorage("openAIKey") private var openAIKey = ""

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $openAIKey)
            } header: {
                Text("OpenAI Configuration")
            } footer: {
                Text("Your API key is stored securely on your device and is only used to communicate with OpenAI for coaching feedback.")
            }
        }
        .navigationTitle("AI Settings")
    }
}

// MARK: - Disclaimer View

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Important Disclaimer")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("""
                Vocal Ascend is designed to help you practice vocal techniques safely. However, please note:

                • This app is NOT a substitute for professional vocal instruction
                • This app does NOT provide medical advice
                • If you experience pain, hoarseness, or discomfort, STOP immediately and consult a medical professional
                • The "strain risk" indicators are heuristic-based estimates, not medical diagnoses
                • Always warm up properly before attempting high notes
                • Progress gradually and respect your body's limits

                By using this app, you acknowledge that you use it at your own risk and that the developers are not responsible for any injury or damage that may result from its use.
                """)
                .font(.body)

                Text("Recommended Practices")
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Stay hydrated during practice")
                    BulletPoint("Take breaks every 20-25 minutes")
                    BulletPoint("Never push through pain")
                    BulletPoint("Work with a qualified vocal coach")
                    BulletPoint("Get adequate rest between sessions")
                }
            }
            .padding()
        }
        .navigationTitle("Disclaimer")
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
}
