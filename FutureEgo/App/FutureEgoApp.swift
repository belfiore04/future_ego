import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            if onboardingCompleted {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
        ])
    }
}
