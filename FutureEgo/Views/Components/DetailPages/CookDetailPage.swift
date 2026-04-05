import SwiftUI

// MARK: - CookDetailPage
//
// Redesigned detail page for an `.eating(.cook(…))` activity. Implements
// Figma nodes `22:2258` (cook_list) and `22:2395` (cook_step). Renders
// on top of the shared `ActivityPageScaffold`, composing the Wave 1
// primitives (`LocationHeader`, `InspirationQuoteBlock`, `CheckItemRow`).
//
// Unique wrinkle vs. the other detail pages: there are TWO logically
// separate sub-views — a shopping list and a cook-steps checklist — and
// the user toggles between them with a segmented `Picker` at the top of
// the page. Both are scrollable via the outer scaffold.
//
// Layout (top → bottom, inside `ActivityPageScaffold`):
//   1. `LocationHeader` with all dish names joined by " · "
//   2. `InspirationQuoteBlock` with `detail.inspirationQuote` or a
//      fallback string (matches the Figma sample text)
//   3. `Picker(.segmented)` with "🛒 购物" / "🔪 步骤" tags
//   4. One of `ShoppingListView` or `CookStepsView` depending on tab
//
// Default tab selection:
//   - `.steps` when `detail.ingredients.isEmpty` (no shopping to do)
//   - `.shopping` otherwise
//
// Step check state is kept per-dish in `@State checkedSteps: [String: Set<Int>]`
// keyed by dish name. Using the dish name (rather than an Int or UUID)
// keeps the key stable across re-renders and matches the sectioned
// layout the user sees. State is local-only and is NOT persisted back
// onto `CookDetail` — matching the convention established by task-4 /
// task-5 / task-6 detail pages.
//
// Spec: `/home/jun/.pm/2026-04-06/task-9/spec.md`.

struct CookDetailPage: View {
    let detail: CookDetail

    @State private var selectedTab: CookTab
    @State private var checkedSteps: [String: Set<Int>] = [:]

    // Placeholder fallback quote when the model has not been populated
    // by AI post-processing yet. Matches the Figma sample copy.
    private static let fallbackQuote =
        "给自己做一顿饭,享受一下烹饪的乐趣!"

    init(detail: CookDetail) {
        self.detail = detail
        // Default to the shopping tab unless there is nothing to buy,
        // in which case the steps tab is the more useful landing page.
        let initial: CookTab = detail.ingredients.isEmpty ? .steps : .shopping
        self._selectedTab = State(initialValue: initial)
    }

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: titleText,
                subtitle: nil
            )

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? Self.fallbackQuote
            )

            Picker("", selection: $selectedTab) {
                Text("🛒 购物").tag(CookTab.shopping)
                Text("🔪 步骤").tag(CookTab.steps)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 8)

            Group {
                if selectedTab == .shopping {
                    ShoppingListView(ingredients: detail.ingredients)
                } else {
                    CookStepsView(
                        dishes: detail.dishes,
                        bindingFor: { dishName, index in
                            self.binding(forDish: dishName, stepIndex: index)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Title

    /// Joins every dish name with the Figma-mandated " · " separator.
    /// Falls back to "自己做饭" if `dishes` is empty so the header is
    /// never blank.
    private var titleText: String {
        let names = detail.dishes.map(\.name)
        if names.isEmpty { return "自己做饭" }
        return names.joined(separator: " · ")
    }

    // MARK: - Per-dish step binding

    /// Produces a `Binding<Bool>` for a given `(dishName, stepIndex)` pair
    /// backed by `checkedSteps`. Reads return whether the index is in the
    /// dish's `Set<Int>`; writes lazily create the set on first insert
    /// and remove the key entirely when its set becomes empty (keeps the
    /// dictionary compact).
    private func binding(forDish dishName: String, stepIndex: Int) -> Binding<Bool> {
        Binding(
            get: {
                checkedSteps[dishName]?.contains(stepIndex) ?? false
            },
            set: { newValue in
                var set = checkedSteps[dishName] ?? []
                if newValue {
                    set.insert(stepIndex)
                } else {
                    set.remove(stepIndex)
                }
                if set.isEmpty {
                    checkedSteps.removeValue(forKey: dishName)
                } else {
                    checkedSteps[dishName] = set
                }
            }
        )
    }
}

// MARK: - CookTab

/// Which sub-view is currently visible. Kept private to the file so no
/// other call site accidentally depends on the internal tab shape.
private enum CookTab: Hashable {
    case shopping
    case steps
}

// MARK: - ShoppingListView

/// Renders `detail.ingredients` as a vertical list of rounded cards,
/// each showing the ingredient name (bodyEmphasis) on the leading side
/// and the quantity (captionRegular, muted) on the trailing side.
private struct ShoppingListView: View {
    let ingredients: [Ingredient]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("购物清单")
                .font(.sectionTitle)
                .foregroundColor(.black)

            ForEach(ingredients) { ing in
                HStack {
                    Text(ing.name)
                        .font(.bodyEmphasis)
                        .foregroundColor(.black)
                    Spacer()
                    Text(ing.quantity)
                        .font(.captionRegular)
                        .foregroundStyle(Color.mutedTextGreen)
                }
                .padding(12)
                .background(
                    Color.surfaceSubtle,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
    }
}

// MARK: - CookStepsView

/// Renders one section per dish in `dishes`. When there is more than one
/// dish, each section is preceded by a `sectionTitle`-styled dish name;
/// when there is only one dish the header is omitted because the page
/// title already identifies the dish.
///
/// The view is stateless — parent owns the checked state and hands us
/// a closure that returns a `Binding<Bool>` for a given (dishName,
/// stepIndex) pair. This keeps `@State` co-located with the page so it
/// survives tab switches.
private struct CookStepsView: View {
    let dishes: [CookDish]
    let bindingFor: (String, Int) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(dishes) { dish in
                VStack(alignment: .leading, spacing: 4) {
                    if dishes.count > 1 {
                        Text(dish.name)
                            .font(.sectionTitle)
                            .foregroundColor(.black)
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(dish.steps.enumerated()), id: \.offset) { index, step in
                        CheckItemRow(
                            text: step,
                            isChecked: bindingFor(dish.name, index)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

/// Pulls the first `.eating(.cook(…))` payload out of `SampleData.schedule`.
/// Falls back to an inline fixture so the Canvas never crashes if the
/// sample set is ever reordered.
private func previewCookDetail() -> CookDetail {
    for item in SampleData.schedule {
        if case .eating(.cook(let d)) = item.detail {
            return d
        }
    }
    return CookDetail(
        startTime: Date(),
        dishes: [
            CookDish(name: "番茄炒蛋", steps: [
                "番茄切块,鸡蛋打散加少许盐",
                "热锅冷油,倒入蛋液炒至七分熟盛出",
                "底油爆香葱花,下番茄炒出沙",
            ]),
        ],
        cookDurationMinutes: 30,
        ingredients: [
            Ingredient(name: "番茄", quantity: "3个"),
            Ingredient(name: "鸡蛋", quantity: "4颗"),
        ]
    )
}

#Preview("CookDetailPage · SampleData (default tab)") {
    CookDetailPage(detail: previewCookDetail())
}

#Preview("CookDetailPage · single dish (no dish header)") {
    CookDetailPage(detail: CookDetail(
        startTime: Date(),
        dishes: [
            CookDish(name: "平菇炒肉", steps: [
                "腌肉:一勺生抽,一勺蚝油,20分钟",
                "平菇撕成小条,焯水沥干",
                "起锅烧油,先下肉丝炒散",
                "加入平菇丝翻炒,调味出锅",
            ]),
        ],
        cookDurationMinutes: 25,
        ingredients: [
            Ingredient(name: "瘦猪肉丝", quantity: "200g"),
            Ingredient(name: "平菇", quantity: "1朵"),
        ]
    ))
}

#Preview("CookDetailPage · empty ingredients (defaults to steps)") {
    CookDetailPage(detail: CookDetail(
        startTime: Date(),
        dishes: [
            CookDish(name: "蛋炒饭", steps: [
                "隔夜米饭打散",
                "鸡蛋打散倒入,快速翻炒",
                "下葱花和米饭一起翻炒",
                "加盐调味出锅",
            ]),
        ],
        cookDurationMinutes: 15,
        ingredients: []
    ))
}
