import SwiftUI

// MARK: - ActivityPageScaffold
//
// The shared page chrome for every redesigned activity detail page
// (Outing / Exercising / Concentrating / EatOut / Delivery / Cook).
// Wave 2 and Wave 3 detail pages wrap their content in this scaffold;
// Wave 4 `CurrentTabView` then routes the right scaffolded page.
//
// Responsibilities:
//   - vertical `ScrollView`
//   - white background that bleeds to the safe-area edges
//   - horizontal content padding of 24pt (matching the global spec)
//   - bottom safe-area inset reservation so floating action buttons and
//     the app-level `TabBar` never cover the last row of content. We
//     deliberately do NOT draw those ourselves — the hosting
//     `CurrentTabView` / TabView owns them.
//
// The scaffold intentionally does not supply any horizontal padding to
// `LocationHeader` specifically, because `LocationHeader` already bakes
// in its own 24pt horizontal padding. Callers can interleave
// `LocationHeader` with other content without worrying about double
// padding — the scaffold only pads direct non-header content via the
// outer `padding(.horizontal, 24)` wrapper on the content `VStack`.
//
// If this ever becomes a problem (e.g. header is visually inset twice
// because a caller puts it inside another padded container), we'll
// revisit by having the scaffold pad nothing and pushing the
// responsibility entirely onto callers.

struct ActivityPageScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            // Reserve room for the floating action button + the app
            // TabBar without actually drawing them here.
            Color.clear.frame(height: 96)
        }
    }
}

// MARK: - Preview

#Preview("ActivityPageScaffold") {
    ActivityPageScaffold {
        Text("hello")
            .font(.pageTitle)

        InspirationQuoteBlock(
            text: "做了那么久的营销方案一定没问题的,相信自己,放轻松。"
        )

        Text("第一段正文")
            .font(.bodyRegular)

        Text("第二段正文,用来验证 scaffold 的纵向滚动和 padding 是否正确。")
            .font(.bodyRegular)
    }
}
