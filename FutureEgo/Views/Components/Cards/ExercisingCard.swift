import SwiftUI

// MARK: - ExercisingCard
//
// Renders an `ExercisingDetail` payload.
// - Big title: exerciseType
// - Subtitle: `{exerciseType} · {venueName}` + HH:mm
// - Tapping the venue name opens `LocationMapSheet`
// - Hero element: two equipment chip rows:
//     · "你要带的" — userEquipment (solid / dark chips)
//     · "您也可以携带" — aiSuggestedEquipment (subtle / light chips).

struct ExercisingCard: View {
    let detail: ExercisingDetail
    let status: EventStatus

    @State private var showMap = false

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let pink = Color(hex: "FF2D55")
    private let accentGreen = Color.brandGreen

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !detail.userEquipment.isEmpty {
                equipmentSection(
                    title: "你要带的",
                    items: detail.userEquipment,
                    emphasis: .solid
                )
            }
            if !detail.aiSuggestedEquipment.isEmpty {
                equipmentSection(
                    title: "您也可以携带",
                    items: detail.aiSuggestedEquipment,
                    emphasis: .subtle,
                    showAIBadge: true
                )
            }
        }
        .activityCardContainer(status: status)
        .sheet(isPresented: $showMap) {
            LocationMapSheet(
                title: detail.venueName,
                address: detail.venueAddress,
                coordinate: detail.venueCoordinate,
                onClose: { showMap = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.exerciseType)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)

            Button {
                showMap = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(accentGreen)
                    Text(detail.venueName)
                        .font(.system(size: 14))
                        .foregroundColor(darkText)
                        .underline()
                    Text(" · \(hhmm(detail.time))")
                        .font(.system(size: 14))
                        .foregroundColor(grayText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Equipment section

    @ViewBuilder
    private func equipmentSection(
        title: String,
        items: [String],
        emphasis: ActivityChip.Emphasis,
        showAIBadge: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(grayText)
                if showAIBadge {
                    AIInferredBadge()
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        ActivityChip(text: item, emphasis: emphasis)
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

#Preview("Exercising · done · no equipment") {
    if case .exercising(let d) = SampleData.schedule[0].detail {
        ExercisingCard(detail: d, status: .done)
            .padding()
    }
}

#Preview("Exercising · upcoming · with equipment") {
    if case .exercising(let d) = SampleData.schedule[5].detail {
        ExercisingCard(detail: d, status: .upcoming)
            .padding()
    }
}
