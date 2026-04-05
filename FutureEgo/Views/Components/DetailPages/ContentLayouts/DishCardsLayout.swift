import SwiftUI

// MARK: - DishCardsLayout
//
// Content-card layout for the two "eating out" detail pages:
//   • EatOutDetailPage  (22:2034 "eating-outside")  — no price column
//   • DeliveryDetailPage (22:2154 "eating-delivery") — with price column
//
// Structure per `.pm/2026-04-06/ground-truth.md` §1 + §2 (Figma 22:2034
// and 22:2154). Each page draws:
//
//   1. A 14pt `#8E8E93` section title ("推荐菜品" / "点这几道吧")
//   2. A 1pt divider in the page palette color
//   3. A vertical stack of dish cards (Group 9 / 10 / 11)
//
// Each dish card is a fixed 37pt pill, 10pt corner radius, with a
// hard-coded `#FF8248` light-orange fill. The fill is intentionally NOT
// routed through `DetailPagePalette` — it is the eating-series identity
// color and stays constant even if the shell palette changes, per
// ground-truth §"关键结构决策候选 #5 菜品卡背景色与容器背景色区分".
//
// The layout is designed to be dropped into `DetailPageShell`'s content
// slot. The shell already paints the giant time / activity name /
// location-line header absolutely on top of the content card; this
// layout only fills the body area beneath that header.

/// One dish displayed inside `DishCardsLayout`. `price == nil` hides the
/// trailing price column and is how EatOutDetailPage opts out of the
/// delivery-page price layout.
struct DishCardItem: Hashable {
    let emoji: String
    let name: String
    let price: String?

    init(emoji: String, name: String, price: String? = nil) {
        self.emoji = emoji
        self.name = name
        self.price = price
    }
}

struct DishCardsLayout: View {
    let palette: DetailPagePalette
    let title: String
    let dishes: [DishCardItem]

    // Fixed eating-series identity color (#FF8248). Not palette-driven
    // on purpose — see header comment.
    private let dishCardFill = Color(hex: "FF8248")

    // Section-title gray from ground-truth (#8E8E93).
    private let sectionTitleGray = Color(hex: "8E8E93")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(sectionTitleGray)

            Rectangle()
                .fill(palette.primary)
                .frame(height: 1)
                .padding(.vertical, 4)

            VStack(spacing: 12) {
                ForEach(dishes.indices, id: \.self) { i in
                    DishCardRow(
                        emoji: dishes[i].emoji,
                        name: dishes[i].name,
                        price: dishes[i].price,
                        fill: dishCardFill
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - DishCardRow
//
// A single 37pt pill row: leading emoji (24pt) + dish name (15pt white
// SF Pro medium) + optional trailing price column (15pt white medium,
// right-aligned). Sizing matches ground-truth Group 9/10/11 from the
// Figma 22:2034 node (292 × 37 rounded 10).

private struct DishCardRow: View {
    let emoji: String
    let name: String
    let price: String?
    let fill: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(emoji)
                .font(.system(size: 24))
                .padding(.leading, 9)

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.leading, 12)

            Spacer(minLength: 8)

            if let price {
                Text(price)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 37)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
        )
    }
}

// MARK: - Previews

#Preview("DishCardsLayout — eating-outside (no price)") {
    DishCardsLayout(
        palette: .orange,
        title: "推荐菜品",
        dishes: [
            DishCardItem(emoji: "🍗", name: "芝士年糕鸡"),
            DishCardItem(emoji: "🍙", name: "饭团"),
            DishCardItem(emoji: "🍛", name: "韩式汤咖哩")
        ]
    )
    .frame(width: 340, height: 459)
    .background(Color.white)
    .padding()
    .background(Color(hex: "F2F2F7"))
}

#Preview("DishCardsLayout — eating-delivery (with price)") {
    DishCardsLayout(
        palette: .orange,
        title: "点这几道吧",
        dishes: [
            DishCardItem(emoji: "🍣", name: "三文鱼拼金枪鱼寿司拼盘", price: "¥35"),
            DishCardItem(emoji: "🧂", name: "寿司酱油&现磨山葵酱", price: "¥3"),
            DishCardItem(emoji: "💴", name: "预计价格", price: "¥38")
        ]
    )
    .frame(width: 340, height: 459)
    .background(Color.white)
    .padding()
    .background(Color(hex: "F2F2F7"))
}
