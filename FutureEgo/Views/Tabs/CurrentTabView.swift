import SwiftUI

// MARK: - CurrentTabView

/// The "此刻" (Now) tab — shows the current event detail with a header,
/// scrollable event content, and a native bottom toolbar.
struct CurrentTabView: View {
    let schedule: [ScheduleItem]
    let currentIndex: Int
    /// Called when the user taps the "AI Coach" toolbar button.
    var onStartCalling: (() -> Void)? = nil

    // MARK: - Weather
    @StateObject private var weather = WeatherService.shared

    // MARK: - Camera & stickers state
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var stickers: [StickerItem] = []
    @State private var isProcessing = false

    // Pulsing coach-mark around phone button on first empty state.
    @State private var hintPulse = false

    // MARK: - Design tokens
    private let accentGreen = Color(hex: "34C759")
    private let grayText = Color(hex: "8E8E93")

    /// Current event derived from the schedule (nil when schedule is empty).
    private var currentEvent: Activity? {
        guard !schedule.isEmpty, currentIndex < schedule.count else { return nil }
        return schedule[currentIndex].detail
    }

    /// Current event status, for the card's three-state visual treatment.
    private var currentStatus: EventStatus {
        guard !schedule.isEmpty, currentIndex < schedule.count else { return .active }
        return schedule[currentIndex].status
    }

    /// Event progress (fraction of completed items before the current one).
    private var eventProgress: Double {
        guard schedule.count > 1 else { return 0 }
        return Double(currentIndex) / Double(schedule.count - 1)
    }

    /// Day progress: simple fraction based on the current hour (8am–23pm range).
    private var dayProgress: Double {
        let hour = Calendar.current.component(.hour, from: Date())
        let clamped = min(max(Double(hour) - 8.0, 0), 15.0)
        return clamped / 15.0
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ──
                headerView

                // ── Event content ──
                if let currentEvent {
                    CurrentEventView(event: currentEvent, status: currentStatus)
                } else {
                    emptySchedulePlaceholder
                }
            }
        }
        .overlay {
            StickerOverlay(stickers: $stickers)
        }
        .overlay(alignment: .center) {
            if isProcessing {
                ProgressView("抠图中...")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            floatingButtons
                .padding(.trailing, 20)
                .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let img = newImage else { return }
            processImage(img)
        }
        .onAppear {
            LaunchTrace.mark("CurrentTabView .onAppear (first frame visible)")
            weather.requestLocation()
            loadPersistedStickers()
            hintPulse = true
            LaunchTrace.mark("CurrentTabView .onAppear end")
        }
    }

    // MARK: - Empty Schedule Placeholder

    private var emptySchedulePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(accentGreen.opacity(0.5))
            Text("还没有日程")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text("点右下角的电话键\n跟 AI Coach 说说今天打算做什么")
                .font(.system(size: 14))
                .foregroundColor(grayText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Floating Liquid Glass Buttons

    private var floatingButtons: some View {
        VStack(spacing: 16) {
            glassButton(systemImage: "camera") {
                showCamera = true
            }
            glassButton(systemImage: "phone") {
                onStartCalling?()
            }
            .overlay {
                // Pulsing ring coach mark: only when there are no scheduled
                // items yet, to draw the user to the primary first action.
                if schedule.isEmpty {
                    Circle()
                        .stroke(accentGreen.opacity(0.6), lineWidth: 2)
                        .scaleEffect(hintPulse ? 1.6 : 1.0)
                        .opacity(hintPulse ? 0.0 : 0.9)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: hintPulse
                        )
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func glassButton(systemImage: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .frame(width: 47, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
        }
    }

    // MARK: - Image segmentation

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task {
            do {
                let segmented = try await ImageSegmentationService.segmentForeground(from: image)
                await MainActor.run {
                    let _ = PersistenceService.shared.saveSticker(image: segmented)
                    stickers.append(StickerItem(image: segmented))
                    isProcessing = false
                    capturedImage = nil
                }
            } catch {
                await MainActor.run {
                    // Fallback: use the original image when segmentation fails.
                    let _ = PersistenceService.shared.saveSticker(image: image)
                    stickers.append(StickerItem(image: image))
                    isProcessing = false
                    capturedImage = nil
                }
            }
        }
    }

    // MARK: - Sticker persistence

    private func loadPersistedStickers() {
        let persisted = PersistenceService.shared.loadStickers()
        stickers = persisted.compactMap { p in
            guard let img = PersistenceService.shared.loadStickerImage(p) else { return nil }
            return StickerItem(image: img)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .tracking(0.4)

                Text(formattedSubtitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }

            Spacer()

            ProgressRing(
                eventProgress: eventProgress,
                dayProgress: dayProgress
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Date helpers

    private var formattedDate: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)
        return "\(y)/\(m)/\(d)"
    }

    private var formattedSubtitle: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: now)
        return "\(weekday) \u{00B7} \(weather.cityName) \u{00B7} \(weather.weatherDescription)"
    }
}

// MARK: - Preview

#Preview {
    CurrentTabView(
        schedule: SampleData.schedule,
        currentIndex: SampleData.currentIndex
    )
}
