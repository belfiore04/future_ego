import SwiftUI

// MARK: - EatOutDetailPage
//
// Wave 2 concrete detail page for `.eating(.eatOut(EatOutDetail))`,
// mapping to the Figma 22:2034 "eating-outside" node. Renders the shared
// `DetailPageShell` with the orange palette and fills the content slot
// with a `DishCardsLayout` listing 3 recommended dishes (no price).
//
// Source materials:
//   - `.pm/2026-04-06/task-7/spec.md`
//   - `.pm/2026-04-06/ground-truth.md` §1 + §2 + §4 + §重要分歧
//
// IMPORTANT — activity name color:
//   Figma shows the restaurant name ("Diaz · Need韩国创意料理（韩餐）")
//   in blue #3986FE. This is a confirmed Figma bug (Phase 2b gate,
//   2026-04-06): every brand-color touchpoint on eating-outside is
//   supposed to be orange #F85509, matching the rest of the eating
//   series. The fix is enforced purely via palette selection — passing
//   `.orange` into `DetailPageShell` makes the shell render the
//   activity name through `palette.primary`, which resolves to orange.
//   DO NOT override the activity name color here; palette is the
//   single source of truth for brand-color routing.
//
// Emoji fallback:
//   `EatOutDetail.recommendedDishes` is `[String]` and carries no emoji
//   metadata. A cycling fallback array is used so the dish card row has
//   *some* leading glyph. This is a known shortcut — the real fix is
//   to add an emoji field to the model, tracked as a follow-up in
//   `.pm/2026-04-06/task-7/report.md` under "待改进".

struct EatOutDetailPage: View {
    let detail: EatOutDetail

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: detail.appointmentTime)
    }

    private var activityName: String {
        detail.restaurantName
    }

    private var motivationalText: String {
        detail.inspirationQuote ?? "这周辛苦了，好好享受这顿饭吧！"
    }

    /// Cycled emoji fallback — see header comment. Kept local so it is
    /// obvious this is page-level cosmetic data, not model data.
    private var dishItems: [DishCardItem] {
        let emojis = ["🍗", "🍙", "🍛", "🍜", "🍱", "🥗"]
        return detail.recommendedDishes.enumerated().map { idx, name in
            DishCardItem(
                emoji: emojis[idx % emojis.count],
                name: name,
                price: nil
            )
        }
    }

    var body: some View {
        DetailPageShell(
            palette: .orange,
            timeString: timeString,
            activityName: activityName,
            locationLine: detail.restaurantAddress,
            motivationalText: motivationalText,
            heroSymbolName: "fork.knife"
        ) {
            DishCardsLayout(
                palette: .orange,
                title: "推荐菜品",
                dishes: dishItems
            )
        }
    }
}

// MARK: - Preview

#Preview("EatOutDetailPage — eating-outside") {
    EatOutDetailPage(
        detail: EatOutDetail(
            appointmentTime: {
                var c = DateComponents()
                c.hour = 12
                c.minute = 0
                return Calendar.current.date(from: c) ?? Date()
            }(),
            companion: "朋友",
            restaurantName: "Diaz · Need韩国创意料理（韩餐）",
            restaurantType: "韩餐",
            restaurantAddress: "慧多港商场 5F",
            recommendedDishes: [
                "芝士年糕鸡",
                "饭团",
                "韩式汤咖哩"
            ]
        )
    )
}
