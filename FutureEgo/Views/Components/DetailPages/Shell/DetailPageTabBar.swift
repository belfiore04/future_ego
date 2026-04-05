import SwiftUI

// MARK: - DetailPageTabBar
//
// Purely-presentational bottom tab bar that is baked into every detail
// page's Figma source. The real tab-switching for the app still lives
// in `CurrentTabView`; this view only draws the 4-tab look defined by
// the Figma design so the full Figma shell renders 1:1.
//
// Ground truth (`.pm/2026-04-06/ground-truth.md` §3 TabBar + §4 共享
// shell TabBar):
//   - Outer container: 390 × 64
//   - Inner capsule:   304 × 56, rgba(255,255,255,0.72) + soft shadow
//   - Tabs:            此刻 / 日程 / 复盘 / 我的
//   - Active tab:      palette.primary (icon + label)
//                      backing pill palette.primary.opacity(0.12)
//   - Inactive tabs:   #8E8E93 gray
//   - Label font:      SF Pro Display 10pt (active 600 / inactive 400)

struct DetailPageTabBar: View {
    let palette: DetailPagePalette

    private let inactiveColor = Color(
        red: 0x8E / 255.0,
        green: 0x8E / 255.0,
        blue: 0x93 / 255.0
    )

    var body: some View {
        HStack(spacing: 0) {
            tabItem(icon: "clock.fill", label: "此刻", active: true)
            tabItem(icon: "calendar", label: "日程", active: false)
            tabItem(icon: "chart.line.uptrend.xyaxis", label: "复盘", active: false)
            tabItem(icon: "person.crop.circle", label: "我的", active: false)
        }
        .padding(.horizontal, 8)
        .frame(width: 304, height: 56)
        .background(Color.white.opacity(0.72), in: Capsule())
        .shadow(color: Color.black.opacity(0.06), radius: 0.25, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 2)
        .frame(width: 390, height: 64)
    }

    @ViewBuilder
    private func tabItem(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: active ? .semibold : .regular))
            Text(label)
                .font(.custom(
                    "SF Pro Display",
                    size: 10,
                    relativeTo: .caption2
                ))
                .fontWeight(active ? .semibold : .regular)
        }
        .foregroundStyle(active ? palette.primary : inactiveColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if active {
                    Capsule()
                        .fill(palette.primary.opacity(0.12))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
            }
        )
    }
}

#Preview("DetailPageTabBar") {
    ZStack {
        Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
            .ignoresSafeArea()
        VStack(spacing: 24) {
            DetailPageTabBar(palette: .green)
            DetailPageTabBar(palette: .blue)
            DetailPageTabBar(palette: .orange)
            DetailPageTabBar(palette: .purple)
        }
    }
}
