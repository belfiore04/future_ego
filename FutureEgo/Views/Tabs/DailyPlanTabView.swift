import SwiftUI

// MARK: - DailyPlanTabView

struct DailyPlanTabView: View {
    @State private var selectedItem: ScheduleItem?
    @State private var appeared = false

    private let schedule = SampleData.schedule

    private var doneCount: Int {
        schedule.filter { $0.status == .done }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            VStack(alignment: .leading, spacing: 6) {
                Text("全天日程")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("共 \(schedule.count) 项 · \(doneCount) 项已完成")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // MARK: Timeline
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(schedule.enumerated()), id: \.element.id) { index, item in
                        TimelineRow(
                            item: item,
                            index: index,
                            isLast: index == schedule.count - 1,
                            appeared: appeared
                        ) {
                            selectedItem = item
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item) {
                selectedItem = nil
            }
        }
    }
}

// MARK: - TimelineRow

private struct TimelineRow: View {
    let item: ScheduleItem
    let index: Int
    let isLast: Bool
    let appeared: Bool
    var onTap: (() -> Void)?

    private var isDone: Bool { item.status == .done }
    private var isActive: Bool { item.status == .active }
    private var isUpcoming: Bool { item.status == .upcoming }

    var body: some View {
        let content = rowContent

        Group {
            if isActive {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "34C759").opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "34C759").opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, -4)
            } else if isUpcoming {
                Button(action: { onTap?() }) {
                    content
                }
                .buttonStyle(TimelineTapStyle())
            } else {
                // Done
                content
                    .opacity(0.6)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(
            .spring(stiffness: 400, damping: 28).delay(Double(index) * 0.04),
            value: appeared
        )
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot + line
            VStack(spacing: 4) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: isActive ? Color(hex: "34C759").opacity(0.4) : .clear,
                        radius: isActive ? 4 : 0
                    )

                if !isLast {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 6)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.scheduleTime)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundColor(
                                isDone ? Color(hex: "C7C7CC")
                                : isActive ? Color(hex: "3A3A3C")
                                : Color(hex: "8E8E93")
                            )

                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isDone ? Color(hex: "C7C7CC") : .black)
                            .strikethrough(isDone, color: Color(hex: "C7C7CC"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    StatusBadge(item: item)
                }

                if !isDone {
                    SubInfo(detail: item.detail)
                }
            }
            .padding(.bottom, isLast ? 8 : 20)
        }
    }

    private var dotColor: Color {
        if isActive { return Color(hex: "34C759") }
        if isDone { return Color(hex: "C7C7CC") }
        return Color(hex: "D1D1D6")
    }
}

// MARK: - TimelineTapStyle

private struct TimelineTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let item: ScheduleItem

    var body: some View {
        if item.status == .done {
            badgeCapsule(text: "已完成", textColor: Color(hex: "C7C7CC"), bgColor: Color.black.opacity(0.03))
        } else if item.status == .active {
            badgeCapsule(text: "进行中", textColor: Color(hex: "34C759"), bgColor: Color(hex: "34C759").opacity(0.1))
        } else if let tag = item.tag, let tagColor = item.tagColor {
            badgeCapsule(text: tag, textColor: tagColor, bgColor: tagColor.opacity(0.09))
        }
    }

    private func badgeCapsule(text: String, textColor: Color, bgColor: Color) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(bgColor))
    }
}

// MARK: - SubInfo

private struct SubInfo: View {
    let detail: CurrentEventData

    var body: some View {
        switch detail {
        case .location(let loc):
            HStack(spacing: 4) {
                Text("◎")
                Text(loc.address)
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "8E8E93"))
            .padding(.top, 6)

        case .delivery(let del):
            Text("\(del.shop)（\(del.totalPrice)）")
                .font(.system(size: 14).italic())
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.top, 6)

        case .eatOut(let eo):
            Text("\(eo.restaurant) · \(eo.cuisine)")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.top, 6)

        case .cook(let ck):
            HStack(spacing: 8) {
                ForEach(ck.dishes) { dish in
                    Text(dish.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "3A3A3C"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 8)

        case .todo(let td):
            HStack(spacing: 6) {
                Text("⏰")
                    .foregroundColor(Color(hex: "FF9500"))
                Text(td.deadline)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .font(.system(size: 14))
            .padding(.top, 6)
        }
    }
}

// MARK: - EventDetailSheet

private struct EventDetailSheet: View {
    let item: ScheduleItem
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Sheet header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.scheduleTime)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "3A3A3C"))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.black.opacity(0.06)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            // Sheet content — inline event detail
            ScrollView(.vertical, showsIndicators: false) {
                InlineEventDetail(detail: item.detail)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - InlineEventDetail

/// Inline event detail view for the sheet.
/// This provides a self-contained detail rendering so DailyPlanTabView
/// does not depend on CurrentEventView (which may be created by another task).
private struct InlineEventDetail: View {
    let detail: CurrentEventData

    var body: some View {
        switch detail {
        case .location(let loc):
            locationDetail(loc)
        case .delivery(let del):
            deliveryDetail(del)
        case .eatOut(let eo):
            eatOutDetail(eo)
        case .cook(let ck):
            cookDetail(ck)
        case .todo(let td):
            todoDetail(td)
        }
    }

    // MARK: Location
    @ViewBuilder
    private func locationDetail(_ loc: LocationEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "mappin.circle.fill", iconColor: Color(hex: "FF3B30"), label: "地点", value: loc.address)
            detailRow(icon: "clock.fill", iconColor: Color(hex: "007AFF"), label: "时间", value: "\(loc.time) - \(loc.endTime ?? "")")

            if !loc.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc.cardTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    ForEach(Array(loc.items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: "34C759"))
                                .frame(width: 6, height: 6)
                            Text(item)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "3A3A3C"))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
            }
        }
    }

    // MARK: Delivery
    @ViewBuilder
    private func deliveryDetail(_ del: DeliveryEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "bag.fill", iconColor: Color(hex: "FF9500"), label: "店铺", value: del.shop)
            detailRow(icon: "bicycle", iconColor: Color(hex: "007AFF"), label: "预计送达", value: del.deliveryTime)

            VStack(alignment: .leading, spacing: 10) {
                Text("订单详情")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)

                ForEach(del.items) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "3A3A3C"))
                        Spacer()
                        Text(item.price)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }

                Divider()

                HStack {
                    Text("合计")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(del.totalPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "FF9500"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
        }
    }

    // MARK: Eat Out
    @ViewBuilder
    private func eatOutDetail(_ eo: EatOutEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "fork.knife", iconColor: Color(hex: "FF9500"), label: "餐厅", value: "\(eo.restaurant) · \(eo.cuisine)")
            detailRow(icon: "person.2.fill", iconColor: Color(hex: "5856D6"), label: "同行", value: eo.guest)
            detailRow(icon: "mappin.circle.fill", iconColor: Color(hex: "FF3B30"), label: "地址", value: eo.address)

            if !eo.recommendedDishes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("推荐菜品")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    ForEach(eo.recommendedDishes) { dish in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(Color(hex: "FF9500"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dish.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "3A3A3C"))
                                Text(dish.desc)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
            }
        }
    }

    // MARK: Cook
    @ViewBuilder
    private func cookDetail(_ ck: CookEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "flame.fill", iconColor: Color(hex: "FF9500"), label: "烹饪时间", value: ck.cookTime)

            // Dishes
            ForEach(ck.dishes) { dish in
                VStack(alignment: .leading, spacing: 10) {
                    Text(dish.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    ForEach(Array(dish.steps.enumerated()), id: \.offset) { stepIndex, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(stepIndex + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(hex: "34C759")))

                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "3A3A3C"))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
            }

            // Ingredients
            if !ck.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("食材清单")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    ForEach(ck.ingredients) { ing in
                        HStack {
                            Text(ing.name)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "3A3A3C"))
                            Spacer()
                            Text(ing.amount)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
            }
        }
    }

    // MARK: Todo
    @ViewBuilder
    private func todoDetail(_ td: TodoEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "clock.fill", iconColor: Color(hex: "007AFF"), label: "时间", value: "\(td.time) - \(td.endTime)")
            detailRow(icon: "alarm.fill", iconColor: Color(hex: "FF9500"), label: "截止", value: td.deadline)

            if !td.steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("步骤")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    ForEach(Array(td.steps.enumerated()), id: \.offset) { stepIndex, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(stepIndex + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(hex: "5856D6")))

                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "3A3A3C"))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.03)))
            }
        }
    }

    // MARK: Detail Row Helper
    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "3A3A3C"))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyPlanTabView()
}
