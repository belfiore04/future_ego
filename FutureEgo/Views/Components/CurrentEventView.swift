import SwiftUI

// MARK: - CurrentEventView
//
// Thin wrapper that renders the `ActivityCardView` dispatcher for the
// currently-active schedule item on the "此刻" tab. The rich per-case layouts
// live inside the individual card files under `Views/Components/Cards/`.

struct CurrentEventView: View {
    let event: Activity
    var status: EventStatus = .active

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headerText)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8E8E93"))

            Text(event.displayTimeRange)
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(Color.brandGreen)

            ActivityCardView(activity: event, status: status)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var headerText: String {
        switch event {
        case .outing:        return "前往目的地"
        case .eating:        return "用餐时间"
        case .concentrating: return "专注时间"
        case .exercising:    return "运动时间"
        }
    }
}

// MARK: - Preview

#Preview("Outing") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[1].detail, status: .done)
    }
}

#Preview("Concentrating · active") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[2].detail, status: .active)
    }
}

#Preview("Delivery") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[3].detail, status: .upcoming)
    }
}

#Preview("Cook") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[6].detail, status: .upcoming)
    }
}
