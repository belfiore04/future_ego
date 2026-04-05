import SwiftUI

// MARK: - OutingDetailPage
//
// Full-screen redesigned detail page for an `.outing` activity. Implements
// Figma node `22:1928` (page name "outing"). Renders on top of the shared
// `ActivityPageScaffold`, composing the Wave 1 primitives
// (`LocationHeader`, `InspirationQuoteBlock`, `CheckItemRow`).
//
// Layout (top → bottom):
//   - `LocationHeader` with the activity name + destination line
//   - `InspirationQuoteBlock` with either the model-supplied quote or a
//     hard-coded fallback string (spec-approved placeholder)
//   - "记得要带的东西" section: a section title followed by one
//     `CheckItemRow` per entry in `detail.itemsToBring`. The whole section
//     (title included) is hidden when `itemsToBring` is empty.
//
// Checkbox state is kept in local `@State` (`checkedItems`) and is NOT
// persisted back to the model. Wiring up persistence is explicitly out of
// scope for this task — see TODO below.
//
// Spec: `/home/jun/.pm/2026-04-06/task-4/spec.md`.

struct OutingDetailPage: View {
    let detail: OutingDetail

    // Local-only checkbox state. Keyed by item string (matches the row
    // label) because `itemsToBring` is `[String]` without stable ids.
    // TODO(wave-later): persist checked state back onto `OutingDetail`
    // (or a sibling per-schedule-item store) so it survives navigation.
    @State private var checkedItems: Set<String> = []

    // Placeholder fallback quote when the model has not been populated
    // yet (AI post-processing runs out-of-band). Matches the string the
    // Figma mock uses so designers can eyeball the layout.
    private static let fallbackQuote =
        "做了那么久的营销方案一定没问题的,好好表现吧!"

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: detail.activityName,
                subtitle: detail.destination
            )

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? Self.fallbackQuote
            )

            if !detail.itemsToBring.isEmpty {
                itemsToBringSection
            }
        }
    }

    // MARK: - Items-to-bring section

    private var itemsToBringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记得要带的东西")
                .font(.sectionTitle)
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail.itemsToBring, id: \.self) { item in
                    CheckItemRow(
                        text: item,
                        isChecked: binding(for: item)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Produces a `Binding<Bool>` backed by `checkedItems` for a given
    /// row. Reads return whether the item is in the set; writes insert
    /// or remove as appropriate. Using a derived binding (instead of a
    /// `[String: Bool]` dictionary) keeps the state compact and avoids
    /// rendering a default `false` entry for every row on first appear.
    private func binding(for item: String) -> Binding<Bool> {
        Binding(
            get: { checkedItems.contains(item) },
            set: { newValue in
                if newValue {
                    checkedItems.insert(item)
                } else {
                    checkedItems.remove(item)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview("OutingDetailPage · SampleData") {
    // Pull the one `.outing` sample out of `SampleData.schedule`
    // (index 1 — "广告组营销会"). Fall back to an inline fixture if the
    // sample ever gets re-ordered so the preview never crashes Canvas.
    if case .outing(let d) = SampleData.schedule[1].detail {
        OutingDetailPage(detail: d)
    } else {
        OutingDetailPage(detail: OutingDetail(
            arrivalTime: Date(),
            destination: "慧多港商场 5F · 朝阳区798艺术区 A1座",
            activityName: "创意品牌营销会议",
            itemsToBring: [
                "Laptop & charger",
                "Marketing proposal printouts ×5",
                "Noise-canceling headphones",
            ]
        ))
    }
}

#Preview("OutingDetailPage · empty items") {
    OutingDetailPage(detail: OutingDetail(
        arrivalTime: Date(),
        destination: "家附近的咖啡馆",
        activityName: "随便坐坐",
        itemsToBring: []
    ))
}
