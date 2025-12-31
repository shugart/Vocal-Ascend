import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        TabView {
            TrainView()
                .tabItem {
                    Label("Train", systemImage: "figure.run")
                }

            PitchView()
                .tabItem {
                    Label("Pitch", systemImage: "waveform")
                }

            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "message")
                }

            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AudioEngine())
}
