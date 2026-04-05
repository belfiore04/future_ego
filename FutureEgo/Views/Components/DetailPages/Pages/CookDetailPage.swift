import SwiftUI

// MARK: - CookDetailPage
//
// Concrete detail page for `.eating(.cook(CookDetail))`. This is the
// only Wave 2 page that owns a two-mode UI inside a single file: the
// Figma source ships cook_list (22:2258) and cook_step (22:2395) as
// two independent frames, but the Swift model has exactly one
// `Activity.eating(.cook)` case. Rather than spinning up a second
// top-level page or a second `Activity` case, the page keeps an
// internal `@State cookMode: CookMode` and flips between
// `ShoppingListLayout` and `StepListLayout` in place.
//
// ── Source material ─────────────────────────────────────────────────
// Spec:          `.pm/2026-04-06/task-8/spec.md`
// Ground truth:  `.pm/2026-04-06/ground-truth.md` §1/§2/§4 — the
//                eating(cook_list) + eating(cook_step) rows
// Figma renders: `.pm/2026-04-06/figma-renders/eating-cook-list.png`
//                `.pm/2026-04-06/figma-renders/eating-cook-step.png`
// Model:         `FutureEgo/Models/Activity.swift` — CookDetail +
//                CookDish + Ingredient
//
// ── iOS-side addition (NOT in Figma) ────────────────────────────────
// The Segmented Picker at the top of the content slot is a deliberate
// non-Figma addition. The two Figma frames are independent pages with
// no visible transition affordance between them; on iOS we need a
// single deterministic way for the user to move from "what to buy" to
// "how to cook it", so a two-segment Picker (`购物清单` / `烹饪步骤`)
// is the minimum viable switch. Flagged in report.md per task-8 spec.
//
// ── Height budget ───────────────────────────────────────────────────
// `DetailPageShell` pads its content closure with `.padding(.top, 201)`
// already, leaving ≈ 258pt of usable area inside the 340×459 content
// card. Segmented picker (~32pt) + top padding (16) + VStack spacing
// (16) eats ~64pt → layout gets ~194pt. ShoppingList overflows for 4+
// ingredients; previews cap at 3 to stay inside the card.

// MARK: - CookMode

/// Internal two-mode state for `CookDetailPage`. Raw values double as
/// the Segmented Picker labels so the enum stays the single source of
/// truth for both state and UI copy.
enum CookMode: String, CaseIterable, Identifiable {
    case list = "购物清单"
    case step = "烹饪步骤"

    var id: String { rawValue }
}

// MARK: - CookDetailPage

struct CookDetailPage: View {
    let detail: CookDetail

    /// Defaults to `.list` — user starts at "what to buy", switches to
    /// `.step` once they are in the kitchen.
    @State private var cookMode: CookMode

    /// Primary init — always starts in `.list` mode. This is the only
    /// init the router uses in production.
    init(detail: CookDetail) {
        self.detail = detail
        self._cookMode = State(initialValue: .list)
    }

    /// Preview-only init that seeds the `@State` so previews can
    /// demonstrate the `.step` branch without tapping the Segmented
    /// Picker. Not used by the router.
    fileprivate init(detail: CookDetail, initialMode: CookMode) {
        self.detail = detail
        self._cookMode = State(initialValue: initialMode)
    }

    // MARK: Derived header values

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: detail.startTime)
    }

    /// Activity-name slot in the Shell header. Joins all dish names
    /// with " + " so a multi-dish session like "番茄炒蛋 + 青菜汤"
    /// renders in one line. The Shell already clamps with
    /// `lineLimit(1)` + `minimumScaleFactor(0.6)`, so overlong joins
    /// shrink rather than wrap.
    private var activityName: String {
        let joined = detail.dishes.map(\.name).joined(separator: " + ")
        return joined.isEmpty ? "今天做饭" : joined
    }

    private var motivationalText: String {
        detail.inspirationQuote ?? "自己做的饭最香，今天也要好好吃饭！"
    }

    // MARK: Derived content values

    /// Maps `CookDetail.ingredients` into the layout DTO. `Ingredient
    /// .quantity` is already a `String`, so the interpolation here is
    /// a no-op that keeps the call site aligned with the spec's
    /// `"\($0.quantity)"` literal.
    private var ingredientItems: [IngredientItem] {
        detail.ingredients.map {
            IngredientItem(name: $0.name, quantity: "\($0.quantity)")
        }
    }

    /// Flattens every `CookDish.steps` array into one `[StepItem]`
    /// sequence. All steps start `.notStarted`, then the first step
    /// (if any) is promoted to `.inProgress` as the "currently doing"
    /// demo state. This is a placeholder — the real state machine
    /// (tap-to-check, timer advance, cross-dish stepping) is tracked
    /// in the Phase 2c follow-up notes and not part of task-8.
    private var flatSteps: [StepItem] {
        var items: [StepItem] = []
        for dish in detail.dishes {
            for step in dish.steps {
                items.append(StepItem(label: step, state: .notStarted))
            }
        }
        if !items.isEmpty {
            items[0] = StepItem(label: items[0].label, state: .inProgress)
        }
        return items
    }

    // MARK: Body

    var body: some View {
        DetailPageShell(
            palette: .orange,
            timeString: timeString,
            activityName: activityName,
            locationLine: "厨房 · 预计 \(detail.cookDurationMinutes) 分钟",
            motivationalText: motivationalText,
            heroSymbolName: "fork.knife.circle.fill"
        ) {
            VStack(spacing: 0) {
                Picker("模式", selection: $cookMode) {
                    ForEach(CookMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                switch cookMode {
                case .list:
                    ShoppingListLayout(
                        palette: .orange,
                        title: "购物清单",
                        ingredients: ingredientItems
                    )
                case .step:
                    StepListLayout(
                        palette: .orange,
                        title: "烹饪步骤",
                        steps: flatSteps
                    )
                }
            }
        }
    }
}

// MARK: - Previews
//
// Two previews exercise both modes. The ingredient / step counts are
// kept deliberately small (≤ 3 ingredients, ≤ 4 steps) so the content
// fits in the ~194pt the Shell gives the layout after the Segmented
// Picker eats its share of the 258pt content-card interior.

private func cookDetailPreviewFixture() -> CookDetail {
    CookDetail(
        startTime: Calendar.current.date(
            bySettingHour: 18, minute: 30, second: 0, of: Date()
        ) ?? Date(),
        dishes: [
            CookDish(
                name: "平菇炒肉",
                steps: [
                    "腌肉 20min（生抽 + 蚝油）",
                    "平菇撕条过水",
                    "起锅烧油炒肉"
                ]
            )
        ],
        cookDurationMinutes: 40,
        ingredients: [
            Ingredient(name: "平菇", quantity: "1朵"),
            Ingredient(name: "瘦猪肉丝", quantity: "200g"),
            Ingredient(name: "生抽", quantity: "1勺")
        ]
    )
}

#Preview("CookDetailPage — list mode") {
    CookDetailPage(detail: cookDetailPreviewFixture())
}

#Preview("CookDetailPage — step mode") {
    // Uses the fileprivate preview-only init to seed `@State` with
    // `.step` so Xcode's canvas renders the `StepListLayout` branch
    // directly. Production callers still go through `init(detail:)`
    // and always start in `.list`.
    CookDetailPage(
        detail: cookDetailPreviewFixture(),
        initialMode: .step
    )
}
