import SwiftUI

// MARK: - ExercisingDetailPage
//
// Redesigned detail page for `.exercising` schedule items, per Figma
// node `21:1824` and spec `/home/jun/.pm/2026-04-06/task-5/spec.md`.
//
// Structure (top to bottom, inside `ActivityPageScaffold`):
//   1. `LocationHeader` — exerciseType as title, venueName as subtitle
//   2. `HeroImageBlock` — 200pt placeholder rect with two floating green
//      progress badges in the top-trailing corner (unique to this page)
//   3. `InspirationQuoteBlock` — `detail.inspirationQuote` with fallback
//   4. "记得要带" section — `CheckItemRow` per item in `userEquipment`
//
// The hero image is intentionally a placeholder for now. A later task
// will swap it for a real photo pipeline; the placeholder holds the
// layout's vertical rhythm stable until then.

struct ExercisingDetailPage: View {
    let detail: ExercisingDetail

    /// Per-item check state for the "记得要带" list. Keyed by index so
    /// duplicate item names still get independent toggles. Initialized
    /// from the detail on first body evaluation via `.onAppear`.
    @State private var checkedStates: [Bool] = []

    /// Fallback copy used when the detail has no AI-provided inspiration
    /// quote. Taken from the spec's sample text.
    private static let fallbackQuote =
        "想象你已经做完了胸部力量训练,那种充实的感觉!"

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: detail.exerciseType,
                subtitle: detail.venueName
            )

            HeroImageBlock(
                systemPlaceholder: "figure.strengthtraining.traditional"
            )
            .overlay(alignment: .topTrailing) {
                badgeStack
                    .padding(16)
            }

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? Self.fallbackQuote
            )

            if !detail.userEquipment.isEmpty {
                equipmentSection
            }
        }
        .onAppear {
            // Lazily size the checked-state array to match the current
            // equipment list. Re-running this on every appear is cheap
            // and keeps state fresh if the detail is swapped out.
            if checkedStates.count != detail.userEquipment.count {
                checkedStates = Array(
                    repeating: false,
                    count: detail.userEquipment.count
                )
            }
        }
    }

    // MARK: - Badge stack (hero overlay)

    private var badgeStack: some View {
        VStack(spacing: 8) {
            progressBadge(emoji: "💪")
            progressBadge(emoji: "🔥")
        }
    }

    @ViewBuilder
    private func progressBadge(emoji: String) -> some View {
        Circle()
            .fill(Color.brandGreen)
            .frame(width: 58, height: 58)
            .overlay(
                Text(emoji)
                    .font(.system(size: 24))
            )
    }

    // MARK: - Equipment section

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记得要带")
                .font(.sectionTitle)
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(
                    Array(detail.userEquipment.enumerated()),
                    id: \.offset
                ) { index, item in
                    CheckItemRow(
                        text: item,
                        isChecked: binding(for: index)
                    )
                }
            }
        }
    }

    /// Safe binding helper: if `checkedStates` hasn't been sized yet (the
    /// first render before `onAppear`), return a no-op binding so the
    /// checkbox still renders in its unchecked state without crashing.
    private func binding(for index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard index < checkedStates.count else { return false }
                return checkedStates[index]
            },
            set: { newValue in
                guard index < checkedStates.count else { return }
                checkedStates[index] = newValue
            }
        )
    }
}

// MARK: - HeroImageBlock (private helper)
//
// Flat 200pt-tall rounded rectangle with a large SF Symbol glyph in the
// center. Used here as a photo placeholder. Kept `fileprivate` so later
// detail pages that need their own hero styles don't accidentally
// collide on the type name.

private struct HeroImageBlock: View {
    let systemPlaceholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceSubtle)

            Image(systemName: systemPlaceholder)
                .font(.system(size: 64))
                .foregroundStyle(Color.brandGreen.opacity(0.3))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("ExercisingDetailPage · with equipment") {
    // `SampleData.schedule[5]` is the upcoming swim with userEquipment
    // ["泳镜", "泳帽"] — exercises the full page including the list.
    if case .exercising(let d) = SampleData.schedule[5].detail {
        ExercisingDetailPage(detail: d)
    }
}

#Preview("ExercisingDetailPage · no equipment") {
    // `SampleData.schedule[0]` is the morning run with empty
    // userEquipment — verifies the "记得要带" section hides cleanly.
    if case .exercising(let d) = SampleData.schedule[0].detail {
        ExercisingDetailPage(detail: d)
    }
}
