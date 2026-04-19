import SwiftUI
import SwiftData

@main
struct FutureEgoApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    /// Installs `UNUserNotificationCenterDelegate`. Without this, scheduled
    /// morning/evening call notifications fire but the app never receives
    /// the tap/willPresent callbacks — so the overlay never opens.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
            PersistedSchedule.self,
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
                // Request notification permission immediately — the 2s defer
                // we used to have created a window where the AI could be
                // asked to schedule reminders before permission existed, and
                // all those notifications would be silently dropped. The
                // system dialog is async and non-blocking; the first SwiftUI
                // frame renders underneath it.
                LaunchTrace.mark("ReminderService.requestPermission fire")
                ReminderService.shared.requestPermission()
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
