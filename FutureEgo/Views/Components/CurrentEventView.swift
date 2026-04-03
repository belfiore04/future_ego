import SwiftUI

// MARK: - CurrentEventView

/// Dispatches to the appropriate sub-view based on the CurrentEventData kind.
struct CurrentEventView: View {
    let event: CurrentEventData

    var body: some View {
        switch event {
        case .location(let data):
            LocationView(event: data)
        case .todo(let data):
            TodoView(event: data)
        case .eatOut(let data):
            EatOutView(event: data)
        case .cook(let data):
            CookView(event: data)
        case .delivery(let data):
            DeliveryView(event: data)
        }
    }
}

// MARK: - Design Tokens

private let accentGreen = Color(hex: "34C759")
private let grayText = Color(hex: "8E8E93")
private let dividerColor = Color(hex: "E5E5EA")
private let cardBg = Color.black.opacity(0.025)
private let cardBorder = Color.black.opacity(0.05)

// MARK: - LocationView

private struct LocationView: View {
    let event: LocationEvent
    @State private var checks: [Bool]

    init(event: LocationEvent) {
        self.event = event
        _checks = State(initialValue: Array(repeating: false, count: event.items.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 0) {
                Text("当前正在进行")
                    .font(.system(size: 15))
                    .foregroundColor(grayText)
                    .padding(.bottom, 8)

                Text(event.time)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(accentGreen)
                    .tracking(-0.5)
                    .lineSpacing(0)

                Text(event.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("\u{25CE}")
                        .foregroundColor(accentGreen)
                    Text(event.address)
                        .font(.system(size: 15))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Divider
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 24)

            // Check items section
            VStack(alignment: .leading, spacing: 0) {
                Text(event.cardTitle)
                    .font(.system(size: 14))
                    .foregroundColor(grayText)
                    .padding(.bottom, 12)

                ForEach(Array(event.items.enumerated()), id: \.offset) { index, item in
                    CheckItem(text: item, isChecked: $checks[index])
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.06),
                            value: true
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - TodoView

private struct TodoView: View {
    let event: TodoEvent
    @State private var countdown: String = ""
    @State private var isActive: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 0) {
                Text(isActive ? "距离结束还剩" : "计划进行时间")
                    .font(.system(size: 15))
                    .foregroundColor(grayText)
                    .padding(.bottom, 8)

                Text(isActive ? countdown : event.time)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(accentGreen)
                    .tracking(-0.5)

                Text(event.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("\u{23F0}")
                        .font(.system(size: 15))
                    Text(event.deadline)
                        .font(.system(size: 15))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Divider
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 24)

            // Steps section
            VStack(alignment: .leading, spacing: 0) {
                Text("任务拆解")
                    .font(.system(size: 14))
                    .foregroundColor(grayText)
                    .padding(.bottom, 12)

                StepFlow(steps: event.steps)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
    }

    private func updateCountdown() {
        let now = Date()
        let calendar = Calendar.current
        let nowMin = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let startParts = event.time.split(separator: ":").compactMap { Int($0) }
        let endParts = event.endTime.split(separator: ":").compactMap { Int($0) }

        guard startParts.count >= 2, endParts.count >= 2 else { return }

        let startMin = startParts[0] * 60 + startParts[1]
        let endMin = endParts[0] * 60 + endParts[1]

        isActive = nowMin >= startMin && nowMin < endMin

        if isActive {
            var endDate = calendar.startOfDay(for: now)
            endDate = calendar.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: endDate)!
            let diff = endDate.timeIntervalSince(now)

            if diff <= 0 {
                countdown = "已结束"
            } else {
                let hrs = Int(diff) / 3600
                let mins = (Int(diff) % 3600) / 60
                let secs = Int(diff) % 60
                if hrs > 0 {
                    countdown = String(format: "%d:%02d:%02d", hrs, mins, secs)
                } else {
                    countdown = String(format: "%02d:%02d", mins, secs)
                }
            }
        }
    }
}

// MARK: - EatOutView

private struct EatOutView: View {
    let event: EatOutEvent
    private let dishEmojis = ["\u{1F35C}", "\u{1F35A}", "\u{1F957}", "\u{1F35B}"] // noodles, rice, salad, curry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 0) {
                Text("约定时间")
                    .font(.system(size: 15))
                    .foregroundColor(grayText)
                    .padding(.bottom, 8)

                Text(event.time)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(accentGreen)
                    .tracking(-0.5)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(event.guest) \u{00B7} \(event.restaurant)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                    Text(" \(event.cuisine)")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("\u{25CE}")
                        .foregroundColor(accentGreen)
                    Text(event.address)
                        .font(.system(size: 15))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Divider
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 24)

            // Recommended dishes section
            VStack(alignment: .leading, spacing: 8) {
                Text("用餐愉快 :)")
                    .font(.system(size: 14))
                    .foregroundColor(grayText)
                    .padding(.bottom, 4)

                ForEach(Array(event.recommendedDishes.enumerated()), id: \.element.id) { index, dish in
                    HStack {
                        HStack(spacing: 12) {
                            Text(dishEmojis[index % dishEmojis.count])
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dish.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black.opacity(0.8))
                                Text(dish.desc)
                                    .font(.system(size: 12))
                                    .foregroundColor(grayText)
                            }
                        }

                        Spacer()

                        Text("推荐")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentGreen)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - CookView

private struct CookView: View {
    let event: CookEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 0) {
                Text("开始做饭")
                    .font(.system(size: 15))
                    .foregroundColor(grayText)
                    .padding(.bottom, 8)

                Text(event.time)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(accentGreen)
                    .tracking(-0.5)

                Text(event.dishes.map(\.name).joined(separator: " \u{00B7} "))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("\u{1F373}")
                        .font(.system(size: 15))
                    Text(event.cookTime)
                        .font(.system(size: 15))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Divider
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 24)

            // Swipeable card
            SwipeableCard<EmptyView>(pages: buildPages())
        }
    }

    private func buildPages() -> [CardPage] {
        // First page: ingredients list
        let ingredientsPage = CardPage(title: "要买的菜") {
            VStack(spacing: 8) {
                ForEach(event.ingredients) { ingredient in
                    HStack {
                        Text(ingredient.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                        Spacer()
                        Text(ingredient.amount)
                            .font(.system(size: 14))
                            .foregroundColor(grayText)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorder, lineWidth: 1)
                    )
                }
            }
        }

        // Subsequent pages: recipe steps for each dish
        let recipePages = event.dishes.map { dish in
            CardPage(title: dish.name) {
                StepFlow(steps: dish.steps)
            }
        }

        return [ingredientsPage] + recipePages
    }
}

// MARK: - DeliveryView

private struct DeliveryView: View {
    let event: DeliveryEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 0) {
                Text("吃饭时间")
                    .font(.system(size: 15))
                    .foregroundColor(grayText)
                    .padding(.bottom, 8)

                Text(event.time)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(accentGreen)
                    .tracking(-0.5)

                Text(event.shop)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Text("\u{1F6F5}")
                        .font(.system(size: 15))
                    Text(event.deliveryTime)
                        .font(.system(size: 15))
                        .foregroundColor(grayText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Divider
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 24)

            // Menu items section
            VStack(alignment: .leading, spacing: 8) {
                Text("点这几道菜")
                    .font(.system(size: 14))
                    .foregroundColor(grayText)
                    .padding(.bottom, 4)

                ForEach(Array(event.items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                        Spacer()
                        Text(item.price)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentGreen)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorder, lineWidth: 1)
                    )
                }

                // Total price
                Divider()
                    .background(dividerColor)
                    .padding(.top, 4)

                HStack {
                    Text("预估总价")
                        .font(.system(size: 14))
                        .foregroundColor(grayText)
                    Spacer()
                    Text(event.totalPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accentGreen)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Preview

#Preview("Location") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[1].detail)
    }
}

#Preview("Todo") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[0].detail)
    }
}

#Preview("Delivery") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[2].detail)
    }
}

#Preview("EatOut") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[3].detail)
    }
}

#Preview("Cook") {
    ScrollView {
        CurrentEventView(event: SampleData.schedule[5].detail)
    }
}
