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

    /// Whether the AI Coach calling overlay is active.
    @State private var isCalling = false

    var body: some View {
        TabView(selection: $activeTab) {
            CurrentTabView(
                schedule: SampleData.schedule,
                currentIndex: SampleData.currentIndex,
                onStartCalling: {
                    isCalling = true
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
        .tint(Color(hex: "34C759"))
        .fullScreenCover(isPresented: $isCalling) {
            CallingOverlay {
                isCalling = false
            }
        }
    }
}

#Preview {
    ContentView()
}
