import SwiftUI
import Charts

// MARK: - ReviewTabView

struct ReviewTabView: View {
    @State private var selectedCategory: CategoryCard?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("回顾过去，优化未来")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    // Single-column card list
                    VStack(spacing: 12) {
                        ForEach(Array(ReviewSampleData.categoryCards.enumerated()), id: \.element.id) { index, card in
                            Button {
                                selectedCategory = card
                            } label: {
                                CategoryCardView(card: card)
                            }
                            .buttonStyle(CardPressStyle())
                            .opacity(appeared ? 1.0 : 0.0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.08),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("复盘")
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
        }
    }
}

// MARK: - CategoryCardView

private struct CategoryCardView: View {
    let card: CategoryCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: icon + title/summary + chevron
            HStack(spacing: 12) {
                // Icon badge
                Text(card.icon)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(card.color.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.label)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(card.summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(card.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }

            // Mini chart preview
            MiniChartPreview(categoryId: card.id)
                .frame(height: 100)
                .clipped()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.02))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Description
            Text(card.description)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8E93"))
                .lineSpacing(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - MiniChartPreview

private struct MiniChartPreview: View {
    let categoryId: CategoryType

    private var dayData: TimeRangeData? {
        ReviewSampleData.timeRangeData[.day]
    }

    var body: some View {
        switch categoryId {
        case .diet:
            dietMini
        case .outing:
            outingMini
        case .focus:
            focusMini
        case .exercise:
            exerciseMini
        case .memory:
            memoryMini
        }
    }

    // Diet: stacked bar chart
    private var dietMini: some View {
        Chart(dayData?.diet.chartData ?? []) { entry in
            BarMark(
                x: .value("时段", entry.day),
                y: .value("自炊", entry.home)
            )
            .foregroundStyle(Color(hex: "34C759"))
            .cornerRadius(3)

            BarMark(
                x: .value("时段", entry.day),
                y: .value("外食", entry.out)
            )
            .foregroundStyle(Color(hex: "FF9500"))
            .cornerRadius(3)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(8)
    }

    // Outing: single bar chart
    private var outingMini: some View {
        Chart(dayData?.outing.chartData ?? []) { entry in
            BarMark(
                x: .value("时段", entry.day),
                y: .value("地点", entry.places)
            )
            .foregroundStyle(Color(hex: "007AFF"))
            .cornerRadius(3)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(8)
    }

    // Focus: line chart
    private var focusMini: some View {
        Chart(dayData?.focus.chartData ?? []) { entry in
            LineMark(
                x: .value("时段", entry.day),
                y: .value("小时", entry.hours)
            )
            .foregroundStyle(Color(hex: "5856D6"))
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("时段", entry.day),
                y: .value("小时", entry.hours)
            )
            .foregroundStyle(Color(hex: "5856D6"))
            .symbolSize(20)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(8)
    }

    // Exercise: donut chart
    private var exerciseMini: some View {
        Chart(dayData?.exercise.chartData ?? []) { entry in
            SectorMark(
                angle: .value("分钟", entry.value),
                innerRadius: .ratio(0.55),
                outerRadius: .ratio(0.95)
            )
            .foregroundStyle(entry.color)
        }
        .chartLegend(.hidden)
        .padding(8)
    }

    // Memory: photo collage
    private var memoryMini: some View {
        let items = (dayData?.memory.items ?? []).filter { $0.image != nil }.prefix(4)
        return GeometryReader { geo in
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    if let url = item.image {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(Color.black.opacity(0.06))
                            }
                        }
                        .frame(
                            width: i == 0 ? geo.size.width * 0.45 : geo.size.width * 0.30,
                            height: i == 0 ? geo.size.height * 0.65 : geo.size.height * 0.42
                        )
                        .clipped()
                        .cornerRadius(6)
                        .rotationEffect(.degrees(item.rotate ?? 0))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .position(
                            x: photoX(index: i, size: geo.size),
                            y: photoY(index: i, size: geo.size)
                        )
                    }
                }
            }
        }
        .clipped()
    }

    private func photoX(index: Int, size: CGSize) -> CGFloat {
        switch index {
        case 0: return size.width * 0.28
        case 1: return size.width * 0.72
        case 2: return size.width * 0.20
        case 3: return size.width * 0.72
        default: return size.width * 0.5
        }
    }

    private func photoY(index: Int, size: CGSize) -> CGFloat {
        switch index {
        case 0: return size.height * 0.38
        case 1: return size.height * 0.28
        case 2: return size.height * 0.72
        case 3: return size.height * 0.72
        default: return size.height * 0.5
        }
    }
}

// MARK: - CardPressStyle

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ReviewTabView()
}
