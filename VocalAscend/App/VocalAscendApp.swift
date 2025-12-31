import SwiftUI
import SwiftData

@main
struct VocalAscendApp: App {
    let modelContainer: ModelContainer

    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var openAIService = OpenAIService()

    init() {
        // Configure notification delegate
        NotificationDelegate.shared.configure()

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
                .environmentObject(openAIService)
                .onAppear {
                    // Clear notification badge on app launch
                    Task {
                        await NotificationService.shared.clearBadge()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
