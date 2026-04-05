import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    // MARK: - SwiftData container
    //
    // Lifted out of the Scene's `.modelContainer(for:)` shorthand so we can
    // measure how long SwiftData's store open + schema migration take on
    // cold launch. On free-tier Debug / real-device runs this has been the
    // biggest unknown in the 0ms → ContentView.init gap.
    private static let sharedModelContainer: ModelContainer = {
        LaunchTrace.mark("ModelContainer build begin")
        let schema = Schema([
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
        ])
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
            LaunchTrace.mark("ModelContainer build end")
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        // Force LaunchTrace.start to capture as early as possible.
        _ = LaunchTrace.start
        LaunchTrace.mark("FutureEgoApp.init")
    }

    var body: some Scene {
        WindowGroup {
            let _ = LaunchTrace.mark("WindowGroup body eval begin")
            Group {
                if onboardingCompleted {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .onAppear {
                LaunchTrace.mark("root .onAppear")
                // Defer the notification permission request so the first
                // frame has time to render before the system dialog appears.
                // On cold launches this was adding a perceived ~5 seconds
                // while the user read + dismissed the "允许通知" alert.
                // The permission is only needed when reminders actually
                // fire, so a 2s delay is imperceptible and UX-safer.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    LaunchTrace.mark("ReminderService.requestPermission fire (deferred)")
                    ReminderService.shared.requestPermission()
                }
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
