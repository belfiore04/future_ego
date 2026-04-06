import SwiftUI

struct EatOutDetailPage: View {
    let detail: EatOutDetail

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.appointmentTime)
    }

    private var dishItems: [DishCardItem] {
        let emojis = ["🍗", "🍙", "🍛", "🍜", "🍱", "🥗"]
        return detail.recommendedDishes.enumerated().map { idx, name in
            DishCardItem(emoji: emojis[idx % emojis.count], name: name)
        }
    }

    var body: some View {
        DetailPageShell(
            palette: .orange,
            dailyProgress: 0.7,
            activityProgress: 0.2
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timeString, palette: .orange)

                // companion · restaurantName（restaurantType）
                (Text("\(detail.companion) · \(detail.restaurantName)")
                    .font(.system(size: 20, weight: .bold))
                 + Text("（\(detail.restaurantType)）")
                    .font(.system(size: 14)))
                    .foregroundStyle(DetailPagePalette.orange.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 4) {
                    Text("◎").foregroundStyle(DetailPagePalette.orange.primary)
                    Text(detail.restaurantAddress).foregroundStyle(.black)
                }
                .font(.system(size: 15))
            }
        } interactiveSection: {
            DishCardsLayout(
                palette: .orange,
                title: "推荐菜品",
                dishes: dishItems
            )
        }
    }
}

#Preview("EatOutDetailPage") {
    EatOutDetailPage(
        detail: EatOutDetail(
            appointmentTime: {
                var c = DateComponents()
                c.hour = 12; c.minute = 0
                return Calendar.current.date(from: c) ?? Date()
            }(),
            companion: "朋友",
            restaurantName: "Diaz·Need韩国创意料理",
            restaurantType: "韩餐",
            restaurantAddress: "朝阳区三里屯南区 3F",
            recommendedDishes: ["芝士年糕鸡", "饭团", "韩式汤咖哩"]
        )
    )
}
