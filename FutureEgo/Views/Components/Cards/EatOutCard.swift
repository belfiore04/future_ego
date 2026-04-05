import SwiftUI

// MARK: - EatOutCard
//
// Renders an `EatOutDetail` (eating.eatOut) payload.
// - Big title: restaurantName
// - Subtitle: `{companion} · {restaurantName}（{restaurantType}）` plus HH:mm
// - Tapping the restaurant name opens `LocationMapSheet`
// - Hero element: the recommended-dishes chip strip, labeled "AI 推测".

struct EatOutCard: View {
    let detail: EatOutDetail
    let status: EventStatus

    @State private var showMap = false

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let eatingColor = Color(hex: "FF9500")
    private let accentGreen = Color(hex: "34C759")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !detail.recommendedDishes.isEmpty {
                recommendedSection
            }
        }
        .activityCardContainer(status: status)
        .sheet(isPresented: $showMap) {
            LocationMapSheet(
                title: detail.restaurantName,
                address: detail.restaurantAddress,
                coordinate: detail.restaurantCoordinate,
                onClose: { showMap = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showMap = true
            } label: {
                HStack(spacing: 6) {
                    Text(detail.restaurantName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                        .underline()
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentGreen)
                }
            }
            .buttonStyle(.plain)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(grayText)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !detail.companion.isEmpty {
            parts.append(detail.companion)
        }
        parts.append("\(detail.restaurantName)（\(detail.restaurantType)）")
        parts.append(hhmm(detail.appointmentTime))
        return parts.joined(separator: " · ")
    }

    // MARK: - Recommended dishes

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("推荐菜")
                    .font(.system(size: 12))
                    .foregroundColor(grayText)
                AIInferredBadge()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(detail.recommendedDishes, id: \.self) { dish in
                        ActivityChip(text: dish, emphasis: .solid)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview("EatOut · upcoming") {
    if case .eating(.eatOut(let e)) = SampleData.schedule[7].detail {
        EatOutCard(detail: e, status: .upcoming)
            .padding()
    }
}
