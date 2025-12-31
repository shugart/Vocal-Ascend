import SwiftUI
import SwiftData

@main
struct VocalAscendApp: App {
    let modelContainer: ModelContainer

    @StateObject private var audioEngine = AudioEngine()

    init() {
        do {
            let schema = Schema([
                VoiceProfile.self,
                SessionLog.self,
                ExerciseAttempt.self,
                AICoachMessage.self,
                UserPlanProgress.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(audioEngine)
        }
        .modelContainer(modelContainer)
    }
}
