import SwiftUI

// MARK: - CurrentTabView
//
// The "此刻" (Now) tab. Renders the currently focused activity through
// `ActivityDetailPageRouter` (or an empty-state placeholder when the
// schedule is empty), plus the floating camera/phone buttons and the
// camera → segment → edit → fly-onto-card sticker pipeline.
//
// Sticker pipeline:
//   1. Tap camera → `CameraPickerView` sheet captures a photo.
//   2. `processImage` runs Vision foreground segmentation in the
//      background, then presents `StickerEditView` with both the
//      original and the auto-cutout.
//   3. User refines the cutout (brush add / erase) and confirms.
//   4. The confirmed image is briefly shown at screen center, then
//      flies onto the back card's left region via
//      `matchedGeometryEffect`. Persistence happens at the moment we
//      drop it into `StickerStore`, so the badge stack picks it up
//      automatically.
//   5. `StickerStore` purges any stickers from previous days at app
//      launch, foreground, and `significantTimeChange`, satisfying
//      the "reset at midnight" rule.

struct CurrentTabView: View {
    let schedule: [ScheduleItem]
    let currentIndex: Int
    /// Called when the user taps the "AI Coach" toolbar button.
    var onStartCalling: (() -> Void)? = nil

    // MARK: - Camera & sticker pipeline state
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessing = false

    // Edit sheet inputs.
    @State private var editOriginal: UIImage? = nil
    @State private var editSegmented: UIImage? = nil
    @State private var showEditor = false

    // Mid-flight sticker shown briefly at screen center before it flies
    // onto the back card. Cleared once the matched-geometry transition
    // commits.
    @State private var flyingSticker: UIImage? = nil
    @Namespace private var stickerNS
    private let stickerFlightID = "sticker-flight"

    // Pulsing coach-mark around phone button on first empty state.
    @State private var hintPulse = false

    // Developer: mock-data mode toggle for the "next activity" button.
    @AppStorage("use_mock_data") private var useMockData = false

    @StateObject private var stickerStore = StickerStore.shared

    /// Current activity derived from the schedule (nil when empty / out of
    /// bounds). Drives the router dispatch below.
    private var currentActivity: Activity? {
        guard !schedule.isEmpty, currentIndex < schedule.count else { return nil }
        return schedule[currentIndex].detail
    }

    private var currentPalette: DetailPagePalette {
        guard let activity = currentActivity else { return .green }
        switch activity {
        case .exercising: return .green
        case .outing: return .blue
        case .concentrating: return .purple
        case .eating: return .orange
        }
    }

    var body: some View {
        Group {
            if let activity = currentActivity {
                ActivityDetailPageRouter(activity: activity)
            } else {
                emptySchedulePlaceholder
            }
        }
        .overlay(alignment: .center) {
            if isProcessing {
                ProgressView("抠图中...")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay {
            // Mid-flight sticker source view. matchedGeometryEffect on
            // both this and the destination (StickerBadgeStack) makes
            // SwiftUI animate the size/position transition in one shot.
            if let img = flyingSticker {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2),
                                    radius: 12, y: 6)
                    )
                    .padding(10)
                    .matchedGeometryEffect(id: stickerFlightID, in: stickerNS,
                                           isSource: true)
                    .allowsHitTesting(false)
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
        .fullScreenCover(isPresented: $showEditor) {
            if let original = editOriginal, let segmented = editSegmented {
                StickerEditView(
                    originalImage: original,
                    segmentedImage: segmented,
                    palette: currentPalette,
                    onConfirm: { final in
                        showEditor = false
                        commitSticker(final)
                    },
                    onCancel: {
                        showEditor = false
                        editOriginal = nil
                        editSegmented = nil
                    }
                )
            }
        }
        .environment(\.stickerFlightNamespace, stickerNS)
        .onChange(of: capturedImage) { _, newImage in
            guard let img = newImage else { return }
            processImage(img)
        }
        .onAppear {
            LaunchTrace.mark("CurrentTabView .onAppear (first frame visible)")
            stickerStore.refresh()
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
            .buttonStyle(.glassProminent).tint(currentPalette.primary)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(currentPalette.primary)
                    .frame(width: 60, height: 60)
                    .background(
                        currentPalette.light.opacity(0.25),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(currentPalette.primary.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
        }
    }

    // MARK: - Image segmentation (camera → editor)

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task {
            do {
                let segmented = try await ImageSegmentationService.segmentForeground(from: image)
                await MainActor.run {
                    isProcessing = false
                    capturedImage = nil
                    editOriginal = image
                    editSegmented = segmented
                    showEditor = true
                }
            } catch {
                // Segmentation failed → still let the user keep the
                // photo by skipping straight to commit with the
                // original image. Editor would be useless without an
                // initial mask.
                await MainActor.run {
                    isProcessing = false
                    capturedImage = nil
                    commitSticker(image)
                }
            }
        }
    }

    // MARK: - Sticker commit (bake + fly onto card)

    /// Three-phase animation:
    ///   1. Show a large floating sticker at screen center (source of
    ///      `matchedGeometryEffect`).
    ///   2. After a beat, persist + append the badge. The new badge in
    ///      `StickerBadgeStack` carries the same flight id (non-source),
    ///      so it locks onto the source's center geometry the moment it
    ///      appears — invisible to the user, since it sits behind the
    ///      floating overlay.
    ///   3. After another beat, drop the floating overlay inside a
    ///      `withAnimation` block. The badge un-matches and springs to
    ///      its natural pile position on the back card. That spring is
    ///      the "贴过去" feel.
    private func commitSticker(_ image: UIImage) {
        editOriginal = nil
        editSegmented = nil

        flyingSticker = image

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            stickerStore.append(image: image)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    flyingSticker = nil
                }
            }
        }
    }
}

// MARK: - Environment plumbing for the flight namespace
//
// `StickerBadgeStack` is rendered deep inside `DetailPageShell`
// (several view layers below `CurrentTabView`). Passing the namespace
// through every detail-page initializer would be noisy; an
// EnvironmentKey lets the stack opt in without changing public APIs.

private struct StickerFlightNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var stickerFlightNamespace: Namespace.ID? {
        get { self[StickerFlightNamespaceKey.self] }
        set { self[StickerFlightNamespaceKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    CurrentTabView(
        schedule: SampleData.schedule,
        currentIndex: SampleData.currentIndex
    )
}
