import SwiftUI

struct DeliveryDetailPage: View {
    let detail: DeliveryDetail

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.mealTime)
    }

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
            dailyProgress: 0.6,
            activityProgress: 0.15
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timeString, palette: .orange)

                Text(detail.shopName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DetailPagePalette.orange.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    Text("◎").foregroundStyle(DetailPagePalette.orange.primary)
                    Text("配送约需\(detail.estimatedDeliveryMinutes)min，记得提前点单")
                        .foregroundStyle(.black)
                }
                .font(.system(size: 15))
            }
        } interactiveSection: {
            DishCardsLayout(
                palette: .orange,
                title: "点这几道吧",
                dishes: dishItems
            )
        }
    }
}

#Preview("DeliveryDetailPage") {
    DeliveryDetailPage(
        detail: DeliveryDetail(
            mealTime: {
                var c = DateComponents()
                c.hour = 19; c.minute = 0
                return Calendar.current.date(from: c) ?? Date()
            }(),
            shopName: "町田寿司店（朝阳大厦店）",
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
