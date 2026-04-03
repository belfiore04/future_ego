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

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var activeTab: TabId
    var animationNamespace: Namespace.ID

    // Design tokens
    private let activeColor = Color(red: 52/255, green: 199/255, blue: 89/255)   // #34C759
    private let inactiveColor = Color(red: 142/255, green: 142/255, blue: 147/255) // #8E8E93

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabId.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 2)
                .overlay(
                    Capsule()
                        .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for tab: TabId) -> some View {
        let isActive = activeTab == tab

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))

                Text(tab.label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
            }
            .foregroundColor(isActive ? activeColor : inactiveColor)
            .frame(width: 72, height: 44)
            .background {
                if isActive {
                    Capsule()
                        .fill(activeColor.opacity(0.12))
                        .matchedGeometryEffect(id: "tab-indicator", in: animationNamespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @Namespace var ns
    @Previewable @State var tab: TabId = .current

    FloatingTabBar(activeTab: $tab, animationNamespace: ns)
        .padding()
        .background(Color(.systemGroupedBackground))
}
