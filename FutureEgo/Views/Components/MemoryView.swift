import SwiftUI

// MARK: - MemoryChartView

/// Dispatches to day / week / month sub-views based on `timeRange`.
struct MemoryChartView: View {
    let data: MemoryDetail
    let timeRange: TimeRange

    var body: some View {
        switch timeRange {
        case .day:
            DayTimelineView(items: data.items)
        case .week:
            WeekColumnsView(items: data.items)
        case .month:
            MonthCalendarView(items: data.items)
        }
    }
}

// MARK: - Design Tokens

private let memoryAccent = Color(hex: "FF2D55")
private let memoryAccentLight = Color(hex: "FF2D55").opacity(0.03)
private let memoryAccentBorder = Color(hex: "FF2D55").opacity(0.08)
private let memoryConnectorLine = Color(hex: "FF2D55").opacity(0.2)
private let grayLabel = Color(hex: "8E8E93")
private let inactiveDate = Color(hex: "C7C7CC")
private let bodyText = Color(hex: "3A3A3C")

// MARK: - Day Timeline View

/// Vertical timeline with red dots, connector lines, optional photos, and handwriting-style text.
private struct DayTimelineView: View {
    let items: [MemoryItem]
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    // Left column: dot + connector line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(memoryAccent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)

                        if index < items.count - 1 {
                            Rectangle()
                                .fill(memoryConnectorLine)
                                .frame(width: 2)
                                .frame(minHeight: 80)
                                .padding(.top, 4)
                        }
                    }

                    // Right column: time, image, text
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.time)
                            .font(.system(size: 12))
                            .foregroundColor(grayLabel)

                        if let imageURL = item.image {
                            MemoryAsyncImage(url: imageURL)
                                .aspectRatio(4 / 3, contentMode: .fill)
                                .clipped()
                                .cornerRadius(8)
                                .rotationEffect(.degrees(item.rotate ?? 0))
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                .padding(.bottom, 2)
                        }

                        Text(item.text)
                            .font(.system(size: 15, design: .serif))
                            .italic()
                            .foregroundColor(bodyText)
                            .lineSpacing(4)
                    }
                    .padding(.bottom, 16)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -10)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * 0.05),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 8)
        .onAppear { appeared = true }
    }
}

// MARK: - Week Columns View

/// Seven equal-width columns, each representing a weekday, with absolutely-positioned photos.
private struct WeekColumnsView: View {
    let items: [MemoryItem]
    @State private var appeared = false

    private let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Hardcoded photo positions per column, matching the React source.
    private struct PhotoPlacement: Identifiable {
        let id = UUID()
        let imageIndex: Int
        let text: String
        let rotate: Double
        let topFraction: CGFloat
        let leftFraction: CGFloat
        let sizeFraction: CGFloat
    }

    private var weekData: [[PhotoPlacement]] {
        [
            // Sunday
            [
                PhotoPlacement(imageIndex: 0, text: "早餐", rotate: -3, topFraction: 0.08, leftFraction: 0.10, sizeFraction: 0.45),
                PhotoPlacement(imageIndex: 1, text: "咖啡", rotate: 5, topFraction: 0.48, leftFraction: 0.25, sizeFraction: 0.38),
            ],
            // Monday
            [
                PhotoPlacement(imageIndex: 2, text: "专注", rotate: 2, topFraction: 0.15, leftFraction: 0.05, sizeFraction: 0.50),
                PhotoPlacement(imageIndex: 3, text: "跑步", rotate: -4, topFraction: 0.55, leftFraction: 0.20, sizeFraction: 0.42),
            ],
            // Tuesday
            [
                PhotoPlacement(imageIndex: 4, text: "晚餐", rotate: 3, topFraction: 0.05, leftFraction: 0.15, sizeFraction: 0.48),
            ],
            // Wednesday
            [
                PhotoPlacement(imageIndex: 5, text: "散步", rotate: -2, topFraction: 0.20, leftFraction: 0.10, sizeFraction: 0.44),
                PhotoPlacement(imageIndex: 6, text: "阅读", rotate: 4, topFraction: 0.60, leftFraction: 0.08, sizeFraction: 0.40),
            ],
            // Thursday
            [
                PhotoPlacement(imageIndex: 7, text: "瑜伽", rotate: -5, topFraction: 0.12, leftFraction: 0.18, sizeFraction: 0.46),
            ],
            // Friday
            [
                PhotoPlacement(imageIndex: 0, text: "美食", rotate: 3, topFraction: 0.08, leftFraction: 0.12, sizeFraction: 0.50),
                PhotoPlacement(imageIndex: 1, text: "聚会", rotate: -3, topFraction: 0.52, leftFraction: 0.15, sizeFraction: 0.42),
            ],
            // Saturday
            [
                PhotoPlacement(imageIndex: 2, text: "运动", rotate: 2, topFraction: 0.18, leftFraction: 0.08, sizeFraction: 0.48),
            ],
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            // Week header
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(grayLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week columns
            HStack(spacing: 4) {
                ForEach(Array(weekData.enumerated()), id: \.offset) { colIndex, dayItems in
                    GeometryReader { geo in
                        ZStack {
                            ForEach(Array(dayItems.enumerated()), id: \.element.id) { itemIndex, placement in
                                let safeIndex = placement.imageIndex % max(items.count, 1)
                                if items.indices.contains(safeIndex),
                                   let url = items[safeIndex].image {
                                    weekPhotoView(
                                        url: url,
                                        text: placement.text,
                                        rotate: placement.rotate,
                                        placement: placement,
                                        containerSize: geo.size
                                    )
                                    .opacity(appeared ? 1 : 0)
                                    .scaleEffect(appeared ? 1 : 0.8)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.7)
                                            .delay(Double(colIndex) * 0.1 + Double(itemIndex) * 0.05),
                                        value: appeared
                                    )
                                }
                            }
                        }
                    }
                    .frame(height: 240)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(memoryAccentLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(memoryAccentBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func weekPhotoView(
        url: URL,
        text: String,
        rotate: Double,
        placement: PhotoPlacement,
        containerSize: CGSize
    ) -> some View {
        let photoWidth = containerSize.width * placement.sizeFraction
        VStack(spacing: 4) {
            MemoryAsyncImage(url: url)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: photoWidth, height: photoWidth)
                .clipped()
                .cornerRadius(4)
                .padding(2)
                .background(Color.white)
                .cornerRadius(6)
                .rotationEffect(.degrees(rotate))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .italic()
                .foregroundColor(memoryAccent)
        }
        .position(
            x: containerSize.width * placement.leftFraction + photoWidth / 2,
            y: containerSize.height * placement.topFraction + photoWidth / 2
        )
    }
}

// MARK: - Month Calendar View

/// A 4-week calendar grid with thumbnail images on days that have memories.
private struct MonthCalendarView: View {
    let items: [MemoryItem]
    @State private var appeared = false

    private let weekDayHeaders = ["日", "一", "二", "三", "四", "五", "六"]

    private struct DayCell: Identifiable {
        let id = UUID()
        let date: String          // "" for blank cells
        let hasMemory: Bool
        let imageIndices: [Int]    // indices into items array
        let text: String
    }

    /// Mock calendar data for April — 4 weeks, matching the React source.
    private var monthData: [[DayCell]] {
        [
            // Week 1
            [
                DayCell(date: "", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "1", hasMemory: true, imageIndices: [0], text: "新的开始"),
                DayCell(date: "2", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "3", hasMemory: true, imageIndices: [1], text: "咖啡时光"),
                DayCell(date: "4", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "5", hasMemory: true, imageIndices: [2, 3], text: "充实的一天"),
                DayCell(date: "6", hasMemory: false, imageIndices: [], text: ""),
            ],
            // Week 2
            [
                DayCell(date: "7", hasMemory: true, imageIndices: [4], text: "健康饮食"),
                DayCell(date: "8", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "9", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "10", hasMemory: true, imageIndices: [5], text: "散步"),
                DayCell(date: "11", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "12", hasMemory: true, imageIndices: [6, 7], text: "周末阅读"),
                DayCell(date: "13", hasMemory: false, imageIndices: [], text: ""),
            ],
            // Week 3
            [
                DayCell(date: "14", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "15", hasMemory: true, imageIndices: [0], text: "瑜伽"),
                DayCell(date: "16", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "17", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "18", hasMemory: true, imageIndices: [1], text: "美味下午茶"),
                DayCell(date: "19", hasMemory: true, imageIndices: [2], text: "专注工作"),
                DayCell(date: "20", hasMemory: false, imageIndices: [], text: ""),
            ],
            // Week 4
            [
                DayCell(date: "21", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "22", hasMemory: true, imageIndices: [3, 4], text: "运动日"),
                DayCell(date: "23", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "24", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "25", hasMemory: true, imageIndices: [5], text: "晚餐"),
                DayCell(date: "26", hasMemory: false, imageIndices: [], text: ""),
                DayCell(date: "27", hasMemory: true, imageIndices: [6], text: "读书"),
            ],
        ]
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            // Weekday header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekDayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(grayLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthData.joined().enumerated()), id: \.offset) { index, day in
                    calendarCell(day: day, index: index)
                }
            }
        }
        .padding(.horizontal, 8)
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func calendarCell(day: DayCell, index: Int) -> some View {
        let hasDate = !day.date.isEmpty

        GeometryReader { geo in
            ZStack {
                if hasDate {
                    // Date number — top-left
                    Text(day.date)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(day.hasMemory ? memoryAccent : inactiveDate)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(3)
                        .zIndex(10)

                    if day.hasMemory {
                        // Photos
                        memoryCellPhotos(day: day, size: geo.size)

                        // Bottom text label
                        Text(day.text)
                            .font(.system(size: 8, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundColor(memoryAccent)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.horizontal, 3)
                            .padding(.bottom, 2)
                            .zIndex(10)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            Group {
                if hasDate {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "FF2D55").opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(hex: "FF2D55").opacity(0.1), lineWidth: 1)
                        )
                }
            }
        )
        .opacity(appeared ? 1 : 0)
        .animation(
            .easeOut(duration: 0.3).delay(Double(index) * 0.02),
            value: appeared
        )
    }

    @ViewBuilder
    private func memoryCellPhotos(day: DayCell, size: CGSize) -> some View {
        let urls = day.imageIndices.compactMap { idx -> URL? in
            guard items.indices.contains(idx % items.count) else { return nil }
            return items[idx % items.count].image
        }

        if urls.count == 1, let url = urls.first {
            // Single image — centered, slight rotation
            MemoryAsyncImage(url: url)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: size.width * 0.7, height: size.height * 0.7)
                .clipped()
                .cornerRadius(3)
                .padding(1)
                .background(Color.white)
                .cornerRadius(4)
                .rotationEffect(.degrees(-2))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        } else if urls.count >= 2 {
            // Two images — offset placement
            ZStack {
                MemoryAsyncImage(url: urls[0])
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: size.width * 0.45, height: size.height * 0.45)
                    .clipped()
                    .cornerRadius(2)
                    .padding(1)
                    .background(Color.white)
                    .cornerRadius(3)
                    .rotationEffect(.degrees(5))
                    .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                    .position(
                        x: size.width * 0.08 + size.width * 0.45 / 2,
                        y: size.height * 0.15 + size.height * 0.45 / 2
                    )

                MemoryAsyncImage(url: urls[1])
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: size.width * 0.45, height: size.height * 0.45)
                    .clipped()
                    .cornerRadius(2)
                    .padding(1)
                    .background(Color.white)
                    .cornerRadius(3)
                    .rotationEffect(.degrees(-8))
                    .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                    .position(
                        x: size.width * 0.92 - size.width * 0.45 / 2,
                        y: size.height * 0.85 - size.height * 0.45 / 2
                    )
            }
        }
    }
}

// MARK: - Shared Async Image

/// Loads an image from a URL with a gray placeholder while loading.
private struct MemoryAsyncImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundColor(Color.black.opacity(0.15))
            }
    }
}

// MARK: - Preview

#Preview("Day View") {
    ScrollView {
        MemoryChartView(
            data: ReviewSampleData.timeRangeData[.day]!.memory,
            timeRange: .day
        )
        .padding()
    }
}

#Preview("Week View") {
    ScrollView {
        MemoryChartView(
            data: ReviewSampleData.timeRangeData[.day]!.memory,
            timeRange: .week
        )
        .padding()
    }
}

#Preview("Month View") {
    ScrollView {
        MemoryChartView(
            data: ReviewSampleData.timeRangeData[.day]!.memory,
            timeRange: .month
        )
        .padding()
    }
}
