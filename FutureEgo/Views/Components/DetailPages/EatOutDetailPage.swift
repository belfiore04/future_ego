import SwiftUI

// MARK: - EatOutDetailPage
//
// Full-screen redesigned detail page for an `.eating(.eatOut)` activity.
// Implements Figma node `22:2034` (page name "eating（outside）"). Renders
// on top of the shared `ActivityPageScaffold`, composing the Wave 1
// primitives (`LocationHeader`, `InspirationQuoteBlock`).
//
// Layout (top → bottom):
//   - `LocationHeader` with `restaurantName` + `restaurantAddress`
//   - `InspirationQuoteBlock` with either the model-supplied quote or a
//     hard-coded fallback string (spec-approved placeholder)
//   - "推荐菜品" section: a section title followed by one
//     `RecommendedDishCard` per entry in `detail.recommendedDishes`.
//     The whole section (title included) is hidden when the list is
//     empty.
//
// `RecommendedDishCard` is a private nested view that renders a single
// full-width row with a SF Symbol placeholder on the left, the dish name
// in the middle, and an emoji on the right derived from the name via
// `emojiForDish(_:)`.
//
// Spec: `/home/jun/.pm/2026-04-06/task-7/spec.md`.

struct EatOutDetailPage: View {
    let detail: EatOutDetail

    // Placeholder fallback quote when the model has not been populated
    // yet (AI post-processing runs out-of-band). Matches the string the
    // Figma mock uses so designers can eyeball the layout.
    private static let fallbackQuote =
        "这周健身了6次!快去和好朋友叙叙旧!"

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: detail.restaurantName,
                subtitle: detail.restaurantAddress
            )

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? Self.fallbackQuote
            )

            if !detail.recommendedDishes.isEmpty {
                recommendedDishesSection
            }
        }
    }

    // MARK: - Recommended dishes section

    private var recommendedDishesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐菜品")
                .font(.sectionTitle)
                .foregroundColor(.black)

            VStack(spacing: 12) {
                ForEach(detail.recommendedDishes, id: \.self) { dish in
                    RecommendedDishCard(name: dish)
                }
            }
        }
    }
}

// MARK: - RecommendedDishCard
//
// Single row in the "推荐菜品" list. Full-width, fixed 80pt tall, 8pt
// corner radius, filled with `surfaceSubtle`. Contains a 64x64 SF Symbol
// placeholder (orange), the dish name (17 semibold), and a right-aligned
// emoji derived from the name.
private struct RecommendedDishCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.orange)
                )

            Text(name)
                .font(.bodyEmphasis)
                .foregroundColor(.black)
                .lineLimit(2)

            Spacer(minLength: 8)

            Text(emojiForDish(name))
                .font(.system(size: 36))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceSubtle)
        )
    }
}

// MARK: - Emoji mapping
//
// Naive heuristic that picks a food emoji for a dish name. Chinese
// keyword matching only — good enough for the Figma sample and for the
// handful of strings we see in `SampleData`. Falls back to a generic
// plate emoji when nothing matches.
private func emojiForDish(_ name: String) -> String {
    if name.contains("鸡") { return "🍗" }
    if name.contains("饭团") || name.contains("寿司") { return "🍙" }
    if name.contains("咖哩") || name.contains("咖喱") { return "🍛" }
    if name.contains("面") || name.contains("拉面") { return "🍜" }
    if name.contains("汤") { return "🍲" }
    return "🍽️"
}

// MARK: - Preview

#Preview("EatOutDetailPage · SampleData") {
    // Pull the first `.eating(.eatOut)` sample out of `SampleData.schedule`
    // by looping instead of hard-coding an index, so the preview keeps
    // working if the sample list ever gets re-ordered.
    let eatOut: EatOutDetail? = {
        for item in SampleData.schedule {
            if case .eating(.eatOut(let d)) = item.detail {
                return d
            }
        }
        return nil
    }()

    if let eatOut {
        EatOutDetailPage(detail: eatOut)
    } else {
        Text("No eatOut sample found in SampleData.schedule")
            .font(.bodyRegular)
    }
}
