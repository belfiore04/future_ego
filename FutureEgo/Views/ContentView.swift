import SwiftUI

struct ContentView: View {
    @State private var activeTab: TabId = .current
    @Namespace private var tabAnimation

    /// Track the previous tab index to determine slide direction
    @State private var previousTabIndex: Int = 0

    /// Whether the AI Coach calling overlay is active.
    @State private var isCalling = false

    private var currentTabIndex: Int {
        TabId.allCases.firstIndex(of: activeTab) ?? 0
    }

    /// Slide direction: positive = slide from right, negative = slide from left
    private var slideDirection: CGFloat {
        currentTabIndex >= previousTabIndex ? 1 : -1
    }

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
        .onChange(of: activeTab) { oldValue, _ in
            previousTabIndex = TabId.allCases.firstIndex(of: oldValue) ?? 0
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
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
                    .transition(makeSlideTransition())
            case .daily:
                DailyPlanTabView()
                    .transition(makeSlideTransition())
            case .review:
                ReviewTabView()
                    .transition(makeSlideTransition())
            case .profile:
                ProfileTabView()
                    .transition(makeSlideTransition())
            }
        }
        .id(activeTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeTab)
    }

    // MARK: - Transition

    private func makeSlideTransition() -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 20 * slideDirection)),
            removal: .opacity.combined(with: .offset(x: -20 * slideDirection))
        )
    }
}

#Preview {
    ContentView()
}
