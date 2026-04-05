import SwiftUI

// MARK: - DeliveryDetailPage
//
// Full-screen redesigned detail page for an `.eating(.delivery)` activity.
// Implements Figma node `22:2154` (page name "eating(delivery)"). Renders
// on top of the shared `ActivityPageScaffold`, composing the Wave 1
// primitives (`LocationHeader`, `InspirationQuoteBlock`) together with a
// file-local `MenuItemRow` for the "点这几道吧" section.
//
// Layout (top → bottom):
//   - `LocationHeader` showing the shop name. Delivery has no concrete
//     address to display so `subtitle` is intentionally `nil`.
//   - `InspirationQuoteBlock` with either the model-supplied quote or a
//     hard-coded fallback string (spec-approved placeholder).
//   - "点这几道吧" section: a 19pt section title followed by one
//     `MenuItemRow` per `OrderItem` (emoji + name + price), a divider,
//     and an estimated-total summary row.
//
// Price handling: `DeliveryDetail.estimatedTotalPrice` is a `Decimal`.
// When the stored total is zero we recompute from the item list so the
// preview and hand-rolled fixtures don't surface as "¥0". Formatting
// drops fractional digits unless the amount has a non-zero fraction, so
// `Decimal(38)` renders as `¥38`, `Decimal(38.5)` renders as `¥38.5`.
//
// Spec: `/home/jun/.pm/2026-04-06/task-8/spec.md`.

struct DeliveryDetailPage: View {
    let detail: DeliveryDetail

    // Placeholder fallback quote when the model has not been populated
    // yet (AI post-processing runs out-of-band). Matches the string the
    // Figma mock uses so designers can eyeball the layout.
    private static let fallbackQuote = "再忙也要好好吃饭哦!"

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: detail.shopName,
                subtitle: nil
            )

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? Self.fallbackQuote
            )

            menuSection
        }
    }

    // MARK: - Menu section

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("点这几道吧")
                .font(.sectionTitle)
                .foregroundColor(.black)

            VStack(spacing: 12) {
                ForEach(detail.orderItems) { item in
                    MenuItemRow(
                        name: item.name,
                        emoji: Self.emojiForDish(item.name),
                        price: item.price
                    )
                }

                Divider()
                    .background(Color.divider)

                HStack {
                    Text("预计价格")
                        .font(.bodyRegular)
                        .foregroundColor(.black)
                    Spacer()
                    Text("¥\(Self.formatPrice(totalPrice))")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(12)
            }
        }
    }

    // MARK: - Total

    /// Uses `detail.estimatedTotalPrice` when present and greater than
    /// zero, otherwise falls back to summing `orderItems` so the UI never
    /// shows a misleading "¥0" when only the line items are populated.
    private var totalPrice: Decimal {
        if detail.estimatedTotalPrice > 0 {
            return detail.estimatedTotalPrice
        }
        return detail.orderItems.reduce(Decimal(0)) { $0 + $1.price }
    }

    // MARK: - Formatting helpers

    /// Formats a `Decimal` price as an integer when it has no fractional
    /// component (`38 → "38"`), and with up to 2 fractional digits
    /// otherwise (`38.5 → "38.5"`). Grouping separator is disabled so the
    /// Figma look matches in zh-CN locales.
    fileprivate static func formatPrice(_ price: Decimal) -> String {
        let number = NSDecimalNumber(decimal: price)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "\(price)"
    }

    /// Maps a Chinese dish name to a representative emoji. Matches the
    /// logic used by task-7's `EatOutDetailPage` — we duplicate it here
    /// because task #7 is being built in parallel and we must not take a
    /// compile-time dependency on a symbol that may not yet exist when
    /// the two branches merge.
    fileprivate static func emojiForDish(_ name: String) -> String {
        if name.contains("寿司") { return "🍣" }
        if name.contains("酱")   { return "🧂" }
        if name.contains("鸡")   { return "🍗" }
        if name.contains("饭团") { return "🍙" }
        if name.contains("咖哩") { return "🍛" }
        if name.contains("面")   { return "🍜" }
        if name.contains("汤")   { return "🍲" }
        return "🍽️"
    }
}

// MARK: - MenuItemRow (file-local)

/// A single row inside the "点这几道吧" section. Fixed 64pt height,
/// 8pt corner radius, `surfaceSubtle` fill, 12pt inner padding.
/// Layout: `emoji (20pt)` · `name (17 regular)` · `spacer` · `price
/// (19 semibold)`. Declared `fileprivate` so it doesn't collide with any
/// sibling detail page that might want its own `MenuItemRow`.
private struct MenuItemRow: View {
    let name: String
    let emoji: String
    let price: Decimal

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 20))

            Text(name)
                .font(.bodyRegular)
                .foregroundColor(.black)

            Spacer(minLength: 8)

            Text("¥\(DeliveryDetailPage.formatPrice(price))")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(12)
        .frame(height: 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceSubtle)
        )
    }
}

// MARK: - Preview

#Preview("DeliveryDetailPage · SampleData") {
    // Walk `SampleData.schedule` for the first `.eating(.delivery)` entry
    // instead of hard-coding an index, so later reorderings of the
    // sample fixture don't silently break this preview.
    let sampleDetail: DeliveryDetail? = {
        for item in SampleData.schedule {
            if case .eating(.delivery(let d)) = item.detail {
                return d
            }
        }
        return nil
    }()

    if let d = sampleDetail {
        DeliveryDetailPage(detail: d)
    } else {
        // Inline fallback fixture so Xcode Canvas never crashes if the
        // sample data ever stops containing a delivery item.
        DeliveryDetailPage(detail: DeliveryDetail(
            mealTime: Date(),
            shopName: "町田寿司店(朝阳大厦店)",
            estimatedDeliveryMinutes: 30,
            orderItems: [
                OrderItem(name: "三文鱼拼金枪鱼寿司拼盘", price: Decimal(35)),
                OrderItem(name: "寿司酱油&现磨山葵酱", price: Decimal(3)),
            ],
            estimatedTotalPrice: Decimal(38)
        ))
    }
}

#Preview("DeliveryDetailPage · empty total fallback") {
    // Exercises the `estimatedTotalPrice == 0` branch where the view
    // re-sums `orderItems` on the fly.
    DeliveryDetailPage(detail: DeliveryDetail(
        mealTime: Date(),
        shopName: "咖哩小馆",
        estimatedDeliveryMinutes: 25,
        orderItems: [
            OrderItem(name: "招牌咖哩鸡饭", price: Decimal(32)),
            OrderItem(name: "味噌汤", price: Decimal(6)),
            OrderItem(name: "乌龙面", price: Decimal(18)),
        ],
        estimatedTotalPrice: Decimal(0)
    ))
}
