import SwiftUI

// MARK: - InspirationQuoteBlock
//
// Renders the "灵感金句" block used near the top of every redesigned
// activity detail page. It is a flat `surfaceSubtle` card with centered
// multi-line body text, no icon, no author — deliberately minimal so it
// reads as a quiet aside rather than a UI control.
//
// Spec: `/home/jun/.pm/2026-04-06/task-2/spec.md` (Wave 1, task #2).

struct InspirationQuoteBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.bodyRegular)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surfaceSubtle)
            )
    }
}

// MARK: - Preview

#Preview("InspirationQuoteBlock") {
    VStack(spacing: 16) {
        InspirationQuoteBlock(
            text: "做了那么久的营销方案一定没问题的,相信自己,放轻松。"
        )

        InspirationQuoteBlock(
            text: "短句也能正常渲染。"
        )
    }
    .padding(24)
}
