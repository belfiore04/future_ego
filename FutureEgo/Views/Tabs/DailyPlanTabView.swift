import SwiftUI

// MARK: - DailyPlanTabView

struct DailyPlanTabView: View {
    @ObservedObject private var scheduleManager = ScheduleManager.shared

    @State private var selectedItem: ScheduleItem?
    @State private var appeared = false

    private var schedule: [ScheduleItem] { scheduleManager.schedule }

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
            .spring(response: 0.35, dampingFraction: 0.7).delay(Double(index) * 0.04),
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
//
// NOTE: Task #1 ported this to the new `Activity` enum. The per-case
// formatting is intentionally minimal — Task #4 (detail views) and Task #5
// (timeline polish) will refine the look.

private struct SubInfo: View {
    let detail: Activity

    var body: some View {
        switch detail {
        case .outing(let out):
            HStack(spacing: 4) {
                Text("◎")
                Text(out.destination)
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "8E8E93"))
            .padding(.top, 6)

        case .eating(let eating):
            eatingSubInfo(eating)

        case .concentrating(let conc):
            HStack(spacing: 6) {
                Text("⏰")
                    .foregroundColor(Color(hex: "FF9500"))
                Text(conc.taskName)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .font(.system(size: 14))
            .padding(.top, 6)

        case .exercising(let ex):
            HStack(spacing: 4) {
                Text("🏃")
                Text("\(ex.exerciseType) · \(ex.venueName)")
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "8E8E93"))
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func eatingSubInfo(_ eating: EatingDetail) -> some View {
        switch eating {
        case .delivery(let del):
            Text("\(del.shopName)（¥\(del.estimatedTotalPrice.description)）")
                .font(.system(size: 14).italic())
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.top, 6)

        case .eatOut(let eo):
            Text("\(eo.restaurantName) · \(eo.restaurantType)")
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

            // Sheet content — the Activity card itself, rendered via the
            // shared `ActivityCardView` dispatcher. This is the single place
            // (alongside `CurrentEventView`) where the 6 cards are wired up.
            ScrollView(.vertical, showsIndicators: false) {
                ActivityCardView(activity: item.detail, status: item.status)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Preview

#Preview {
    DailyPlanTabView()
}
