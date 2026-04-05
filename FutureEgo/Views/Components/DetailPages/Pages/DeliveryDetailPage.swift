import SwiftUI

// MARK: - DeliveryDetailPage
//
// Wave 2 concrete detail page for `.eating(.delivery(DeliveryDetail))`,
// mapping to the Figma 22:2154 "eating-delivery" node. Renders the
// shared `DetailPageShell` with the orange palette and fills the content
// slot with a `DishCardsLayout` listing order items *with* prices
// (`¥35` / `¥3` / `¥38` in the reference design).
//
// Source materials:
//   - `.pm/2026-04-06/task-7/spec.md`
//   - `.pm/2026-04-06/ground-truth.md` §1 + §2 + §4
//
// Orange palette is the eating-series identity color (#F85509). Unlike
// eating-outside, the Figma reference is already orange here — no bug
// to work around, the palette just matches.
//
// Emoji fallback:
//   `DeliveryDetail.orderItems` has no emoji field, so a cycling
//   fallback array is used. Known shortcut, tracked as "待改进" in
//   `.pm/2026-04-06/task-7/report.md`.
//
// Price formatting:
//   `OrderItem.price` is `Decimal`. Using string interpolation renders
//   it as a bare number ("35"), which we prefix with "¥" to match the
//   Figma price column style.

struct DeliveryDetailPage: View {
    let detail: DeliveryDetail

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: detail.mealTime)
    }

    private var activityName: String {
        detail.shopName
    }

    private var motivationalText: String {
        detail.inspirationQuote ?? "饿了就点这些，今天你值得！"
    }

    /// Cycled emoji fallback — see header comment.
    private var dishItems: [DishCardItem] {
        let emojis = ["🍔", "🍟", "🥤", "🍕", "🍗", "🌮"]
        return detail.orderItems.enumerated().map { idx, item in
            DishCardItem(
                emoji: emojis[idx % emojis.count],
                name: "\(item.name) ×\(item.quantity)",
                price: "¥\(item.price)"
            )
        }
    }

    var body: some View {
        DetailPageShell(
            palette: .orange,
            timeString: timeString,
            activityName: activityName,
            locationLine: "外卖配送约 \(detail.estimatedDeliveryMinutes) 分钟",
            motivationalText: motivationalText,
            heroSymbolName: "bag.fill"
        ) {
            DishCardsLayout(
                palette: .orange,
                title: "点这几道吧",
                dishes: dishItems
            )
        }
    }
}

// MARK: - Preview

#Preview("DeliveryDetailPage — eating-delivery") {
    DeliveryDetailPage(
        detail: DeliveryDetail(
            mealTime: {
                var c = DateComponents()
                c.hour = 19
                c.minute = 0
                return Calendar.current.date(from: c) ?? Date()
            }(),
            shopName: "元気寿司",
            estimatedDeliveryMinutes: 35,
            orderItems: [
                OrderItem(name: "三文鱼拼金枪鱼寿司拼盘", quantity: 1, price: 35),
                OrderItem(name: "寿司酱油&现磨山葵酱", quantity: 1, price: 3),
                OrderItem(name: "预计价格", quantity: 1, price: 38)
            ],
            estimatedTotalPrice: 76
        )
    )
}
