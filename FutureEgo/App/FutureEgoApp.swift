import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    // TODO: Wave 2 will replace ContentView with the main tab navigation
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
        ])
    }
}
