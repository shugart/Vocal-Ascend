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

// MARK: - Calibration View

struct CalibrationView: View {
    @EnvironmentObject private var audioEngine: AudioEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var calibrationFlow = CalibrationFlow()
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            if hasStarted && calibrationFlow.currentStep != .complete {
                ProgressView(value: Double(calibrationFlow.currentStep.rawValue), total: Double(CalibrationFlow.CalibrationStep.allCases.count - 1))
                    .tint(Color.accentColor)
                    .padding()
            }

            ScrollView {
                VStack(spacing: 24) {
                    if !hasStarted {
                        welcomeContent
                    } else {
                        stepContent
                    }
                }
                .padding()
            }

            // Bottom action area
            if hasStarted {
                bottomActions
            }
        }
        .navigationTitle("Calibrate")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calibrationFlow.setAudioEngine(audioEngine)
        }
        .onDisappear {
            calibrationFlow.stopListening()
        }
        .alert("Error", isPresented: .init(
            get: { calibrationFlow.error != nil },
            set: { if !$0 { calibrationFlow.clearError() } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(calibrationFlow.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            Spacer()

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

            VStack(alignment: .leading, spacing: 12) {
                CalibrationStepPreview(icon: "mic.fill", text: "Check your microphone")
                CalibrationStepPreview(icon: "speaker.wave.2.fill", text: "Measure room noise")
                CalibrationStepPreview(icon: "waveform", text: "Find your baseline")
                CalibrationStepPreview(icon: "arrow.up.right", text: "Discover your range")
                CalibrationStepPreview(icon: "textformat", text: "Test vowels")
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Start Calibration") {
                hasStarted = true
                calibrationFlow.startStep(.microphoneCheck)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                dismiss()
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 24) {
            // Step title
            Text(calibrationFlow.currentStep.title)
                .font(.title2)
                .fontWeight(.bold)

            // Instructions
            Text(calibrationFlow.currentStep.instructions)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Step-specific content
            switch calibrationFlow.currentStep {
            case .welcome:
                EmptyView()

            case .microphoneCheck:
                microphoneCheckContent

            case .roomNoiseCheck:
                roomNoiseContent

            case .baselineLoudness:
                baselineLoudnessContent

            case .findTopNote:
                findTopNoteContent

            case .vowelTest:
                vowelTestContent

            case .complete:
                completeContent
            }

            // Feedback message
            if !calibrationFlow.feedbackMessage.isEmpty {
                Text(calibrationFlow.feedbackMessage)
                    .font(.subheadline)
                    .foregroundStyle(calibrationFlow.canProceed ? .green : .orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Step-Specific Views

    private var microphoneCheckContent: some View {
        VStack(spacing: 16) {
            LevelMeter(level: calibrationFlow.detectedLevel, threshold: -50)
                .frame(height: 40)

            if calibrationFlow.isListening {
                Text("Listening...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var roomNoiseContent: some View {
        VStack(spacing: 16) {
            LevelMeter(level: calibrationFlow.ambientNoiseLevel, threshold: -40, inverted: true)
                .frame(height: 40)

            Text("Stay quiet...")
                .foregroundStyle(.secondary)
        }
    }

    private var baselineLoudnessContent: some View {
        VStack(spacing: 16) {
            LevelMeter(level: calibrationFlow.detectedLevel, threshold: calibrationFlow.baselineLoudness)
                .frame(height: 40)

            if let note = calibrationFlow.detectedNote {
                Text(note.fullName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var findTopNoteContent: some View {
        VStack(spacing: 16) {
            // Show detected note prominently
            if let note = calibrationFlow.detectedNote {
                Text(note.fullName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Text("—")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            // Cents offset indicator
            Text("\(calibrationFlow.detectedCentsOff >= 0 ? "+" : "")\(Int(calibrationFlow.detectedCentsOff)) cents")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Highest note so far
            Text("Highest comfortable: \(calibrationFlow.highestComfortableNote.fullName)")
                .font(.headline)
                .padding(.top)

            Button("This is my limit") {
                calibrationFlow.confirmTopNote()
            }
            .buttonStyle(.bordered)
        }
    }

    private var vowelTestContent: some View {
        VStack(spacing: 16) {
            // Current vowel to test
            let currentVowel = calibrationFlow.config.testVowels.first { calibrationFlow.testedVowels[$0] == nil }

            if let vowel = currentVowel {
                Text("Sing \(calibrationFlow.config.vowelTestNote.fullName) on:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("'\(vowel.label)'")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            // Results so far
            if !calibrationFlow.testedVowels.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(calibrationFlow.testedVowels.keys), id: \.self) { vowel in
                        if let result = calibrationFlow.testedVowels[vowel] {
                            HStack {
                                Text("'\(vowel.label)'")
                                Spacer()
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .orange)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var completeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Calibration Complete!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Highest Comfortable Note:")
                    Spacer()
                    Text(calibrationFlow.highestComfortableNote.fullName)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Baseline Volume:")
                    Spacer()
                    Text("\(Int(calibrationFlow.baselineLoudness)) dB")
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Save Profile") {
                saveProfile()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack {
            if calibrationFlow.currentStep != .welcome && calibrationFlow.currentStep != .complete {
                if calibrationFlow.isListening {
                    Button("Stop") {
                        calibrationFlow.stopListening()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Listen") {
                        calibrationFlow.startListening()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()

            if calibrationFlow.canProceed {
                Button("Next") {
                    calibrationFlow.advanceToNextStep()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func saveProfile() {
        if let profile = calibrationFlow.generateVoiceProfile() {
            modelContext.insert(profile)
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct CalibrationStepPreview: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(text)
            Spacer()
        }
    }
}

struct LevelMeter: View {
    let level: Float
    var threshold: Float = -30
    var inverted: Bool = false

    private var normalizedLevel: Double {
        // Convert dBFS (-60 to 0) to 0-1 range
        let clamped = max(-60, min(0, level))
        return Double((clamped + 60) / 60)
    }

    private var color: Color {
        if inverted {
            return level < threshold ? .green : .orange
        } else {
            return level > threshold ? .green : .orange
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))

                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: geometry.size.width * normalizedLevel)
            }
        }
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
