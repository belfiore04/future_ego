import SwiftUI
import Charts

// MARK: - Shared Design Tokens

private enum ChartTokens {
    static let chartHeight: CGFloat = 180
    static let labelColor = Color(hex: "8E8E93")
    static let labelFont: Font = .system(size: 12)
    static let valueFont: Font = .system(size: 18, weight: .bold)
    static let unitFont: Font = .system(size: 12, weight: .regular)
    static let statLabelFont: Font = .system(size: 11)
    static let cardBackground = Color.black.opacity(0.025)
    static let cardBorder = Color.black.opacity(0.05)
    static let cardCornerRadius: CGFloat = 12
}

// MARK: - StatCard

/// A single stat card showing a value with optional unit and a label below.
struct StatCard: View {
    let label: String
    let value: String
    let unit: String?

    init(label: String, value: String, unit: String? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(ChartTokens.valueFont)
                    .foregroundColor(.black)

                if let unit {
                    Text(unit)
                        .font(ChartTokens.unitFont)
                        .foregroundColor(ChartTokens.labelColor)
                }
            }

            Text(label)
                .font(ChartTokens.statLabelFont)
                .foregroundColor(ChartTokens.labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: ChartTokens.cardCornerRadius)
                .fill(ChartTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChartTokens.cardCornerRadius)
                .stroke(ChartTokens.cardBorder, lineWidth: 1)
        )
    }
}

/// A horizontal row of stat cards.
struct StatRow: View {
    let stats: [(label: String, value: String, unit: String?)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                StatCard(label: stat.label, value: stat.value, unit: stat.unit)
            }
        }
    }
}

// MARK: - 1. DietChartView

/// Stacked bar chart for diet data: home cooking vs eating out.
struct DietChartView: View {
    let data: DietDetail

    // MARK: - Design tokens
    private let homeCookColor = Color.brandGreen
    private let eatOutColor = Color(hex: "FF9500")

    var body: some View {
        VStack(spacing: 0) {
            // Chart
            Chart(data.chartData) { item in
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Meals", item.home)
                )
                .foregroundStyle(by: .value("Type", "自炊"))

                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Meals", item.out)
                )
                .foregroundStyle(by: .value("Type", "外食/外卖"))
            }
            .chartForegroundStyleScale([
                "自炊": homeCookColor,
                "外食/外卖": eatOutColor
            ])
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.black.opacity(0.05))
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .frame(height: ChartTokens.chartHeight)

            // Legend
            HStack(spacing: 20) {
                legendDot(color: homeCookColor, text: "自炊")
                legendDot(color: eatOutColor, text: "外食/外卖")
            }
            .padding(.top, 8)

            // Stats row
            StatRow(stats: [
                (label: "总餐数", value: "\(data.totalMeals)", unit: "餐"),
                (label: "自炊", value: "\(data.homeCook)", unit: "次"),
                (label: "外食", value: "\(data.eatOut)", unit: "次"),
                (label: "外卖", value: "\(data.delivery)", unit: "次"),
            ])
            .padding(.top, 16)
        }
        .padding(.horizontal, 8)
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(ChartTokens.labelFont)
                .foregroundColor(ChartTokens.labelColor)
        }
    }
}

// MARK: - 2. OutingChartView

/// Single-series bar chart for outing data with top places tags.
struct OutingChartView: View {
    let data: OutingReviewDetail

    // MARK: - Design tokens
    private let barColor = Color(hex: "007AFF")

    var body: some View {
        VStack(spacing: 0) {
            // Chart
            Chart(data.chartData) { item in
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Places", item.places)
                )
                .foregroundStyle(barColor)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 4
                ))
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.black.opacity(0.05))
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .frame(height: ChartTokens.chartHeight)

            // Stats row
            StatRow(stats: [
                (label: "地点", value: "\(data.totalPlaces)", unit: "个"),
                (label: "步行距离", value: data.totalDistance, unit: nil),
            ])
            .padding(.top, 16)

            // Top places
            VStack(alignment: .leading, spacing: 8) {
                Text("常去地点")
                    .font(.system(size: 13))
                    .foregroundColor(ChartTokens.labelColor)

                FlowLayout(spacing: 8) {
                    ForEach(data.topPlaces, id: \.self) { place in
                        Text(place)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(barColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(barColor.opacity(0.08))
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - FlowLayout

/// A simple flow layout that wraps items to new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                          proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - 3. FocusChartView

/// Line chart for focus/deep work hours.
struct FocusChartView: View {
    let data: FocusDetail

    // MARK: - Design tokens
    private let lineColor = Color(hex: "5856D6")

    var body: some View {
        VStack(spacing: 0) {
            // Chart
            Chart(data.chartData) { item in
                LineMark(
                    x: .value("Day", item.day),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", item.day),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(lineColor)
                .symbolSize(50)
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.black.opacity(0.05))
                    AxisValueLabel()
                        .font(ChartTokens.labelFont)
                        .foregroundStyle(ChartTokens.labelColor)
                }
            }
            .frame(height: ChartTokens.chartHeight)

            // Stats row
            StatRow(stats: [
                (label: "总时长", value: "\(data.totalHours)h", unit: nil),
                (label: "日均", value: data.avgPerDay, unit: nil),
                (label: "最佳", value: data.longestStreak, unit: nil),
            ])
            .padding(.top, 16)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - 4. ExerciseChartView

/// Donut (pie) chart for exercise breakdown by activity type.
struct ExerciseChartView: View {
    let data: ExerciseDetail

    var body: some View {
        VStack(spacing: 0) {
            // Donut chart + legend row
            HStack(alignment: .center, spacing: 16) {
                // Donut chart
                Chart(data.chartData) { item in
                    SectorMark(
                        angle: .value("Minutes", item.value),
                        innerRadius: .fixed(36),
                        outerRadius: .fixed(62),
                        angularInset: 2
                    )
                    .cornerRadius(3)
                    .foregroundStyle(item.color)
                }
                .chartLegend(.hidden)
                .frame(width: 140, height: 140)

                // Legend list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.chartData) { item in
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)

                                Text(item.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "3A3A3C"))
                            }

                            Spacer()

                            Text("\(item.value)min")
                                .font(.system(size: 13))
                                .foregroundColor(ChartTokens.labelColor)
                        }
                    }
                }
            }

            // Stats row
            StatRow(stats: [
                (label: "总时长", value: "\(data.totalMinutes)", unit: "分钟"),
                (label: "活动天数", value: "\(data.activeDays)", unit: "天"),
                (label: "消耗", value: data.calories, unit: "kcal"),
            ])
            .padding(.top, 16)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Previews

#Preview("Diet Chart") {
    ScrollView {
        DietChartView(data: DietDetail(
            chartData: [
                DietChartEntry(day: "Mon", home: 2, out: 1),
                DietChartEntry(day: "Tue", home: 3, out: 0),
                DietChartEntry(day: "Wed", home: 1, out: 2),
                DietChartEntry(day: "Thu", home: 2, out: 1),
                DietChartEntry(day: "Fri", home: 3, out: 0),
                DietChartEntry(day: "Sat", home: 1, out: 2),
                DietChartEntry(day: "Sun", home: 2, out: 1),
            ],
            totalMeals: 21,
            homeCook: 14,
            eatOut: 5,
            delivery: 2,
            highlights: ["自炊比例提升"]
        ))
        .padding()
    }
}

#Preview("Outing Chart") {
    ScrollView {
        OutingChartView(data: OutingReviewDetail(
            chartData: [
                OutingChartEntry(day: "Mon", places: 3),
                OutingChartEntry(day: "Tue", places: 1),
                OutingChartEntry(day: "Wed", places: 4),
                OutingChartEntry(day: "Thu", places: 2),
                OutingChartEntry(day: "Fri", places: 5),
            ],
            totalPlaces: 15,
            totalDistance: "12.3km",
            topPlaces: ["星巴克", "健身房", "公司", "超市", "公园"],
            highlights: ["走了不少"]
        ))
        .padding()
    }
}

#Preview("Focus Chart") {
    ScrollView {
        FocusChartView(data: FocusDetail(
            chartData: [
                FocusChartEntry(day: "Mon", hours: 4.5),
                FocusChartEntry(day: "Tue", hours: 3.2),
                FocusChartEntry(day: "Wed", hours: 5.0),
                FocusChartEntry(day: "Thu", hours: 2.8),
                FocusChartEntry(day: "Fri", hours: 6.1),
            ],
            totalHours: 21,
            avgPerDay: "4.2h",
            longestStreak: "3天",
            highlights: ["专注力提升"]
        ))
        .padding()
    }
}

#Preview("Exercise Chart") {
    ScrollView {
        ExerciseChartView(data: ExerciseDetail(
            chartData: [
                ExerciseChartEntry(name: "跑步", value: 120, color: Color(hex: "FF2D55")),
                ExerciseChartEntry(name: "游泳", value: 90, color: Color(hex: "007AFF")),
                ExerciseChartEntry(name: "瑜伽", value: 60, color: Color(hex: "5856D6")),
                ExerciseChartEntry(name: "骑行", value: 45, color: Color.brandGreen),
            ],
            totalMinutes: 315,
            activeDays: 5,
            calories: "1,280",
            highlights: ["运动量不错"]
        ))
        .padding()
    }
}
