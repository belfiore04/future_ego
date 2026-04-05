import SwiftUI

/// A page that can be displayed inside a SwipeableCard.
struct CardPage: Identifiable {
    let id = UUID()
    let title: String
    let content: AnyView

    init<Content: View>(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = AnyView(content())
    }
}

/// A multi-page swipeable card with a custom dot indicator at the top.
/// Current page = green elongated pill (width 20); others = small gray dots (width 6).
struct SwipeableCard<Content: View>: View {
    let pages: [CardPage]
    @State private var currentPage: Int = 0

    // MARK: - Design tokens
    private let accentGreen = Color.brandGreen
    private let dotInactive = Color.black.opacity(0.12)
    private let activeDotWidth: CGFloat = 20
    private let inactiveDotWidth: CGFloat = 6
    private let dotHeight: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom page indicator
            if pages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                        Capsule()
                            .fill(index == currentPage ? accentGreen : dotInactive)
                            .frame(
                                width: index == currentPage ? activeDotWidth : inactiveDotWidth,
                                height: dotHeight
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    currentPage = index
                                }
                            }
                    }
                }
                .padding(.bottom, 12)
            }

            // Page content via TabView
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.title)
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.3))

                        page.content
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Convenience initializer with ViewBuilder-based pages

extension SwipeableCard where Content == EmptyView {
    /// Create a SwipeableCard from an array of CardPage.
    init(pages: [CardPage]) {
        self.pages = pages
    }
}

// MARK: - Preview

#Preview {
    SwipeableCard<EmptyView>(pages: [
        CardPage(title: "待办清单") {
            VStack(alignment: .leading) {
                Text("1. 完成作业")
                Text("2. 购买食材")
            }
        },
        CardPage(title: "学习步骤") {
            VStack(alignment: .leading) {
                Text("Step 1: 预习")
                Text("Step 2: 听课")
            }
        },
        CardPage(title: "笔记") {
            Text("今天学到了很多...")
        }
    ])
    .frame(height: 200)
}
