import SwiftUI

// MARK: - OutingCard
//
// Renders an `OutingDetail` payload inside the shared Activity card container.
// - Big title: activityName
// - Subtitle: destination · HH:mm 到达
// - Hero element: the two commute badges (🚇 transit / 🚗 driving)
// - Latest-departure hint
// - Horizontally scrollable chip list of itemsToBring
// - Tapping destination opens `LocationMapSheet` (MapKit sheet).

struct OutingCard: View {
    let detail: OutingDetail
    let status: EventStatus

    @State private var showMap = false

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let accentGreen = Color.brandGreen

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            commuteBadges
            if let depart = detail.latestDepartureTime {
                latestDepartureHint(depart)
            }
            if !detail.itemsToBring.isEmpty {
                itemsChips
            }
        }
        .activityCardContainer(status: status)
        .sheet(isPresented: $showMap) {
            LocationMapSheet(
                title: detail.destination,
                address: detail.destination,
                coordinate: detail.destinationCoordinate,
                onClose: { showMap = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.activityName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)

            Button {
                showMap = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(accentGreen)
                    Text(detail.destination)
                        .font(.system(size: 14))
                        .foregroundColor(darkText)
                        .underline()
                    Text(" · \(hhmm(detail.arrivalTime)) 到达")
                        .font(.system(size: 14))
                        .foregroundColor(grayText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Commute badges (hero element)

    private var commuteBadges: some View {
        HStack(spacing: 10) {
            if let transit = detail.transitDurationMinutes {
                commuteBadge(icon: "🚇", label: "\(transit) 分钟")
            }
            if let driving = detail.drivingDurationMinutes {
                commuteBadge(icon: "🚗", label: "\(driving) 分钟")
            }
        }
    }

    private func commuteBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 14))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(darkText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Latest-departure hint

    private func latestDepartureHint(_ depart: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF9500"))
            Text("\(hhmm(depart)) 前出发")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "FF9500"))
        }
    }

    // MARK: - Items chips

    private var itemsChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("携带清单")
                .font(.system(size: 12))
                .foregroundColor(grayText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(detail.itemsToBring, id: \.self) { item in
                        ActivityChip(text: item, emphasis: .solid)
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

#Preview("Outing · done") {
    if case .outing(let d) = SampleData.schedule[1].detail {
        OutingCard(detail: d, status: .done)
            .padding()
    }
}
