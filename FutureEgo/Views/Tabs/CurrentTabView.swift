import SwiftUI

// MARK: - CurrentTabView

/// The "此刻" (Now) tab — renders the currently focused activity via the
/// Wave 2/3 redesigned detail pages (dispatched through
/// `ActivityDetailPageRouter`) or an empty-state placeholder when the
/// schedule is empty. The legacy header (date + weather + DualProgressRing)
/// was removed in Wave 4 (task-10) now that each detail page renders its
/// own header.
///
/// Floating camera + phone buttons, sticker overlay, background
/// segmentation, and the phone-button pulse coach-mark all remain here
/// because they belong to the tab chrome rather than to any individual
/// activity page.
struct CurrentTabView: View {
    let schedule: [ScheduleItem]
    let currentIndex: Int
    /// Called when the user taps the "AI Coach" toolbar button.
    var onStartCalling: (() -> Void)? = nil

    // MARK: - Camera & stickers state
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var stickers: [StickerItem] = []
    @State private var isProcessing = false

    // Pulsing coach-mark around phone button on first empty state.
    @State private var hintPulse = false

    // Developer: mock-data mode toggle for the "next activity" button.
    @AppStorage("use_mock_data") private var useMockData = false

    /// Current activity derived from the schedule (nil when empty / out of
    /// bounds). Drives the router dispatch below.
    private var currentActivity: Activity? {
        guard !schedule.isEmpty, currentIndex < schedule.count else { return nil }
        return schedule[currentIndex].detail
    }

    var body: some View {
        Group {
            if let activity = currentActivity {
                ActivityDetailPageRouter(activity: activity)
            } else {
                emptySchedulePlaceholder
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
        .overlay(alignment: .topTrailing) {
            if useMockData {
                nextActivityButton
                    .padding(.trailing, 20)
                    .padding(.top, 56)
            }
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
                .foregroundStyle(Color.brandGreen.opacity(0.5))
            Text("还没有日程")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text("点右下角的电话键\n跟 AI Coach 说说今天打算做什么")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Next Activity Button (Developer)

    /// Small pill that cycles through mock schedule items.
    /// Only rendered when `use_mock_data` is true.
    private var nextActivityButton: some View {
        Button {
            ScheduleManager.shared.advanceToNextActivity()
        } label: {
            HStack(spacing: 4) {
                Text("下一个")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "forward.fill")
                    .font(.system(size: 11))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange, in: Capsule())
        }
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
                        .stroke(Color.brandGreen.opacity(0.6), lineWidth: 2)
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
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)

            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .frame(width: 60, height: 60)
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
}

// MARK: - Preview

#Preview {
    CurrentTabView(
        schedule: SampleData.schedule,
        currentIndex: SampleData.currentIndex
    )
}
