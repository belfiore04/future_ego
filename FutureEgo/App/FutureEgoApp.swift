import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

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
                ReminderService.shared.requestPermission()
            }
        }
        .modelContainer(for: [
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
        ])
    }
}
