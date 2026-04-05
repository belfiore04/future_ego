import SwiftUI

// MARK: - CategoryDetailView

struct CategoryDetailView: View {
    let category: CategoryCard
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: TimeRange = .week
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    // MARK: - Design Tokens

    private let backButtonColor = Color.brandGreen
    private let subtitleColor = Color(hex: "8E8E93")
    private let bodyTextColor = Color(hex: "3A3A3C")
    private let cardBorder = Color.black.opacity(0.05)
    private let separatorColor = Color.black.opacity(0.06)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Title area
                    titleSection

                    // Time range picker
                    timeRangePicker

                    chartCard
                    highlightsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("\(category.icon) \(category.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(backButtonColor)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheetView(items: [image])
                }
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeRangeLabel)
                .font(.system(size: 15))
                .foregroundColor(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Time Range Label

    private var timeRangeLabel: String {
        let now = Date()
        let cal = Calendar.current

        switch timeRange {
        case .month:
            let month = cal.component(.month, from: now)
            return "\(month)月份"
        case .week:
            // Calendar.weekday: Sunday=1, Monday=2, …, Saturday=7
            // We want Monday as start-of-week.
            let weekday = cal.component(.weekday, from: now)
            let daysFromMonday = (weekday + 5) % 7  // Mon=0, Tue=1, …, Sun=6
            let startOfWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: now)!
            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek)!
            let sm = cal.component(.month, from: startOfWeek)
            let sd = cal.component(.day, from: startOfWeek)
            let em = cal.component(.month, from: endOfWeek)
            let ed = cal.component(.day, from: endOfWeek)
            return "本周 \(sm).\(sd) — \(em).\(ed)"
        case .day:
            let m = cal.component(.month, from: now)
            let d = cal.component(.day, from: now)
            return "今日 \(m).\(d)"
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        timeRange = range
                    }
                } label: {
                    Text(range.label)
                        .font(.system(size: 15, weight: timeRange == range ? .semibold : .regular))
                        .foregroundColor(timeRange == range ? category.color : subtitleColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if timeRange == range {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.04))
        )
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(category.icon)
                        .font(.system(size: 16))

                    Text("\(category.label)数据")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }

                Spacer()

                // Share button
                Button {
                    captureAndShare()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("分享")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(category.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            // Chart content with animation
            chartContent
                .animation(.easeInOut(duration: 0.3), value: timeRange)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Chart Content (dispatches to the correct chart)

    @ViewBuilder
    private var chartContent: some View {
        if let data = ReviewSampleData.timeRangeData[timeRange] {
            switch category.id {
            case .diet:
                DietChartView(data: data.diet)
            case .outing:
                OutingChartView(data: data.outing)
            case .focus:
                FocusChartView(data: data.focus)
            case .exercise:
                ExerciseChartView(data: data.exercise)
            case .memory:
                MemoryChartView(data: data.memory, timeRange: timeRange)
            }
        }
    }

    // MARK: - Highlights Card

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title (outside the card, matching React source)
            Text("提要")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 4)

            // Highlights list card
            VStack(spacing: 0) {
                let highlights = currentHighlights
                ForEach(Array(highlights.enumerated()), id: \.offset) { index, text in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(text)
                                .font(.system(size: 15))
                                .foregroundColor(bodyTextColor)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        // Separator (except after last item)
                        if index < highlights.count - 1 {
                            Rectangle()
                                .fill(separatorColor)
                                .frame(height: 0.5)
                                .padding(.leading, 34)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeInOut(duration: 0.3), value: timeRange)
        }
    }

    // MARK: - Share

    @MainActor
    private func captureAndShare() {
        let renderer = ImageRenderer(content: shareableContent)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }

    @ViewBuilder
    private var shareableContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Text(category.icon)
                    .font(.system(size: 20))
                Text("\(category.label)数据")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timeRangeLabel)
                .font(.system(size: 15))
                .foregroundColor(subtitleColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Chart
            chartContent

            // Highlights
            VStack(alignment: .leading, spacing: 8) {
                Text("提要")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)

                ForEach(Array(currentHighlights.enumerated()), id: \.offset) { _, text in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(text)
                            .font(.system(size: 15))
                            .foregroundColor(bodyTextColor)
                            .lineSpacing(4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Branding
            Text("交联 FutureEgo")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(subtitleColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
        .padding(20)
        .background(Color.white)
        .frame(width: 375)
    }

    // MARK: - Helpers

    private var currentHighlights: [String] {
        guard let data = ReviewSampleData.timeRangeData[timeRange] else { return [] }
        switch category.id {
        case .diet: return data.diet.highlights
        case .outing: return data.outing.highlights
        case .focus: return data.focus.highlights
        case .exercise: return data.exercise.highlights
        case .memory: return data.memory.highlights
        }
    }
}

// MARK: - Preview

#Preview("Diet Detail") {
    NavigationStack {
        CategoryDetailView(
            category: ReviewSampleData.categoryCards.first { $0.id == .diet }!
        )
    }
}

#Preview("Memory Detail") {
    NavigationStack {
        CategoryDetailView(
            category: ReviewSampleData.categoryCards.first { $0.id == .memory }!
        )
    }
}

#Preview("Exercise Detail") {
    NavigationStack {
        CategoryDetailView(
            category: ReviewSampleData.categoryCards.first { $0.id == .exercise }!
        )
    }
}
