import SwiftUI

// MARK: - Tab Definition

enum TabId: String, CaseIterable {
    case current
    case daily
    case review
    case profile

    var label: String {
        switch self {
        case .current: return "此刻"
        case .daily:   return "日程"
        case .review:  return "复盘"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .current: return "clock"
        case .daily:   return "calendar"
        case .review:  return "doc.text"
        case .profile: return "person"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var activeTab: TabId = .current

    /// CallKit-backed calling service (replaces plain @State isCalling).
    @StateObject private var callService = CallService.shared

    /// Shared schedule state, mutated by AI function calls.
    @StateObject private var scheduleManager = ScheduleManager.shared

    /// Global dynamic tint driven by the currently focused activity.
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        LaunchTrace.mark("ContentView.init")
    }

    /// Resolve the `Activity` that should currently drive the tint.
    /// Returns `nil` when the schedule is empty or the index is out of bounds,
    /// letting `ThemeManager` fall back to the brand-green default.
    private var activeActivity: Activity? {
        let items = scheduleManager.schedule
        guard !items.isEmpty else { return nil }
        let idx = scheduleManager.currentIndex
        guard items.indices.contains(idx) else { return nil }
        return items[idx].detail
    }

    var body: some View {
        let _ = LaunchTrace.mark("ContentView.body eval")
        TabView(selection: $activeTab) {
            CurrentTabView(
                schedule: scheduleManager.schedule,
                currentIndex: scheduleManager.currentIndex,
                onStartCalling: {
                    callService.startCall()
                }
            )
            .tabItem {
                Label("此刻", systemImage: "clock")
            }
            .tag(TabId.current)

            DailyPlanTabView()
                .tabItem {
                    Label("日程", systemImage: "calendar")
                }
                .tag(TabId.daily)

            ReviewTabView()
                .tabItem {
                    Label("复盘", systemImage: "doc.text")
                }
                .tag(TabId.review)

            ProfileTabView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(TabId.profile)
        }
        .tint(themeManager.tint)
        .onAppear {
            themeManager.update(for: activeActivity)
        }
        // Per spec: react to `currentIndex` moves and to schedule mutations.
        // We observe `schedule.map(\.detail)` rather than `schedule` directly
        // because `ScheduleItem` is not `Equatable` (and modifying that model
        // is out of scope for this task); `Activity` is already `Hashable`,
        // so the projected array satisfies `onChange(of:)`'s requirements
        // while still firing on any detail-level change.
        .onChange(of: scheduleManager.currentIndex) { _, _ in
            themeManager.update(for: activeActivity)
        }
        .onChange(of: scheduleManager.schedule.map(\.detail)) { _, _ in
            themeManager.update(for: activeActivity)
        }
        .fullScreenCover(isPresented: $callService.isCallActive) {
            CallingOverlay {
                callService.endCall()
            }
        }
    }
}

#Preview {
    ContentView()
}
