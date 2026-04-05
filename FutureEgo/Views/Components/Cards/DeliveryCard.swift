import SwiftUI

// MARK: - DeliveryCard
//
// Renders a `DeliveryDetail` (eating.delivery) payload.
// - Big title: shopName
// - Subtitle: 用餐 HH:mm · 配送约 XX 分钟
// - Hero element: order list with totals
// - "AI 推测" badge in corner (shown when `isAIInferred` is true)
// - "换一家" placeholder button — taps show a "功能开发中" alert.

struct DeliveryCard: View {
    let detail: DeliveryDetail
    let status: EventStatus

    @State private var showPlaceholderAlert = false

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let eatingColor = Color(hex: "FF9500")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            orderList
            totalAndSwap
        }
        .activityCardContainer(status: status)
        .placeholderFeatureAlert(isPresented: $showPlaceholderAlert)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(detail.shopName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                Text("用餐 \(hhmm(detail.mealTime)) · 配送约 \(detail.estimatedDeliveryMinutes) 分钟")
                    .font(.system(size: 13))
                    .foregroundColor(grayText)
            }
            Spacer()
            if detail.isAIInferred {
                AIInferredBadge()
            }
        }
    }

    // MARK: - Order list

    private var orderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(detail.orderItems) { item in
                HStack {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundColor(darkText)
                    Text("× \(item.quantity)")
                        .font(.system(size: 12))
                        .foregroundColor(grayText)
                    Spacer()
                    Text("¥\(priceString(item.price))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(darkText)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.025))
        )
    }

    // MARK: - Total + 换一家

    private var totalAndSwap: some View {
        HStack {
            Text("合计 ¥\(priceString(detail.estimatedTotalPrice))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(eatingColor)
            Spacer()
            Button {
                showPlaceholderAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("换一家")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(eatingColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(eatingColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func priceString(_ price: Decimal) -> String {
        // Avoid "38" vs "38.00" drift. Use NSDecimalNumber for a compact fallback.
        let n = NSDecimalNumber(decimal: price)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: n) ?? "\(price)"
    }
}

// MARK: - Preview

#Preview("Delivery · upcoming") {
    if case .eating(.delivery(let d)) = SampleData.schedule[3].detail {
        DeliveryCard(detail: d, status: .upcoming)
            .padding()
    }
}
