import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    init() {
        // Force LaunchTrace.start to capture as early as possible.
        _ = LaunchTrace.start
        LaunchTrace.mark("FutureEgoApp.init")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .onAppear {
                LaunchTrace.mark("root .onAppear")
                ReminderService.shared.requestPermission()
                LaunchTrace.mark("ReminderService.requestPermission returned")
            }
        }
        .modelContainer(for: [
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
        ])
    }
}
