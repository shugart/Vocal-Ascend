import SwiftUI

struct PitchView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var isMonitoring = false
    @State private var targetNote: Note = .A4

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Current pitch display
                PitchDisplayView(
                    currentPitch: audioEngine.currentPitch,
                    targetNote: targetNote
                )

                // Pitch indicator (cents offset visualization)
                PitchIndicatorView(
                    centsOffset: audioEngine.currentPitch?.centsOffTarget ?? 0,
                    tolerance: 25
                )

                // Stability and volume meters
                HStack(spacing: 40) {
                    StabilityMeterView(
                        stability: audioEngine.stabilityScore
                    )
                    VolumeMeterView(
                        dbfs: audioEngine.currentPitch?.dbfs ?? -60
                    )
                }
                .padding(.vertical)

                // Target note picker
                TargetNotePickerView(selectedNote: $targetNote)

                Spacer()

                // Monitor toggle
                Button(action: toggleMonitoring) {
                    HStack {
                        Image(systemName: isMonitoring ? "stop.fill" : "mic.fill")
                        Text(isMonitoring ? "Stop" : "Start Monitoring")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMonitoring ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
            }
            .padding()
            .navigationTitle("Pitch")
        }
    }

    private func toggleMonitoring() {
        if isMonitoring {
            audioEngine.stop()
        } else {
            audioEngine.start()
        }
        isMonitoring.toggle()
    }
}

// MARK: - Pitch Display View

struct PitchDisplayView: View {
    let currentPitch: PitchFrame?
    let targetNote: Note

    var body: some View {
        VStack(spacing: 8) {
            // Note name
            Text(currentPitch?.noteName ?? "—")
                .font(.system(size: 72, weight: .bold, design: .rounded))

            // Frequency
            if let pitch = currentPitch, let freq = pitch.f0Hz {
                Text(String(format: "%.1f Hz", freq))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text("— Hz")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Cents offset
            if let pitch = currentPitch, let cents = pitch.centsOffNearest {
                let sign = cents >= 0 ? "+" : ""
                Text("\(sign)\(Int(cents)) cents")
                    .font(.headline)
                    .foregroundStyle(abs(cents) <= 25 ? .green : .orange)
            } else {
                Text("— cents")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 160)
    }
}

#Preview {
    PitchView()
        .environmentObject(AudioEngine())
}
