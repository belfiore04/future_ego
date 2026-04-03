import SwiftUI

struct ContentView: View {
    @State private var activeTab: TabId = .current
    @Namespace private var tabAnimation

    /// Whether the AI Coach calling overlay is active.
    @State private var isCalling = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // Tab content with slide transition
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating tab bar overlay — hidden during a call
            if !isCalling {
                FloatingTabBar(activeTab: $activeTab, animationNamespace: tabAnimation)
                    .padding(.bottom, 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Calling overlay
            if isCalling {
                CallingOverlay {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isCalling = false
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isCalling)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .current:
            CurrentTabView(
                schedule: SampleData.schedule,
                currentIndex: SampleData.currentIndex,
                onStartCalling: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isCalling = true
                    }
                }
            )
        case .daily:
            DailyPlanTabView()
        case .review:
            ReviewTabView()
        case .profile:
            ProfileTabView()
        }
    }
}

#Preview {
    ContentView()
}
