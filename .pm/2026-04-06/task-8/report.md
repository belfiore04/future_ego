# Task-8 Report — CookDetailPage (Wave 2)

## Summary

Added `FutureEgo/Views/Components/DetailPages/Pages/CookDetailPage.swift`
as a single-file page for `.eating(.cook(CookDetail))`. The page owns
an internal `@State cookMode: CookMode` (`.list` / `.step`) and flips
between `ShoppingListLayout` and `StepListLayout` inside the
`DetailPageShell` content slot via a two-segment Picker. Orange
palette throughout, Hero symbol `fork.knife.circle.fill`, header time
formatted `HH:mm` from `detail.startTime`, activity-name slot joins
`detail.dishes[].name` with `" + "` (fallback `"今天做饭"`),
location-line is `"厨房 · 预计 X 分钟"`.

Single file, no existing-file modifications. Branched from main
(`2427b21`) as `feat/detail-pages-rewrite-wave2-cook-page`.

## Commit

- Branch: `feat/detail-pages-rewrite-wave2-cook-page`
- Hash: see `git log feat/detail-pages-rewrite-wave2-cook-page -1`
  (self-referential hash cannot be embedded in its own commit; prior
  pre-amend value was `08e406e`)
- Message: `feat(detail-pages): add CookDetailPage with list/step segmented switch per task-8 spec`

## Segmented Picker — iOS-side addition NOT in Figma

**Flag per spec.** Figma ships `eating-cook-list` (22:2258) and
`eating-cook-step` (22:2395) as two independent frames with no visible
affordance connecting them. The Swift data model collapses both into
a single `Activity.eating(.cook(CookDetail))` case, so on iOS we need
one deterministic in-page switch between "what to buy" and "how to
cook it". Chose a two-segment `Picker(.segmented)` at the top of the
content slot (`购物清单` / `烹饪步骤`) — minimum viable control, no
extra visual chrome, matches iOS platform convention. Not present in
any Figma frame. Confirmed as the spec-recommended approach
(spec §"模式切换 UI").

## Flat-step demo state decision

`flatSteps` flattens every `CookDish.steps` into one `[StepItem]`
sequence in iteration order, marks all as `.notStarted`, then promotes
`items[0]` to `.inProgress` so the `.step` branch lands on a visible
"currently doing" row rather than an all-gray stack. This mirrors the
spec's demo-state instruction. Real tri-state advance (tap-to-check,
timer, cross-dish stepping) is explicitly deferred and noted in the
file comment as a Phase 2c follow-up.

## Deviations from spec brief

1. **`locationLine` drops the leading `"◎ "`.** Spec brief shows
   `"◎ 厨房 · 预计 X 分钟"`, but `DetailPageShell` already prepends
   `"◎"` via a hard-coded `HStack { Text("◎"); Text(locationLine) }`
   (see `DetailPageShell.swift:165-171` + header comment "The '◎'
   prefix is prepended automatically"). Passing the spec string
   verbatim would render `"◎ ◎ 厨房..."`. Used `"厨房 · 预计 \(detail
   .cookDurationMinutes) 分钟"` to respect the Shell contract.
2. **`VStack(spacing: 0)` + `.padding(.top, 8)` on the Picker**
   instead of the brief's `VStack(spacing: 16)` + `.padding(.top, 16)`.
   The 258pt content budget is tight once the Segmented Picker (~32pt)
   and the inner layouts' own `.padding(.top, 20)` are accounted for;
   shaved ~24pt of vertical padding to keep 3 ingredients inside the
   card. Still within the "small `.padding(.top, 8)` between Picker
   and the layout" allowance in the task constraints.
3. **Added `fileprivate init(detail:, initialMode:)` for previews.**
   Canonical `init(detail:)` is unchanged and is the only init the
   router will call. Preview-only init seeds `@State` so the second
   `#Preview` can render the `.step` branch directly without tapping
   the picker — satisfies the "preview must demonstrate both modes"
   deliverable.

## Previews

- `#Preview("CookDetailPage — list mode")` — default `.list` branch,
  3 ingredients (`平菇` / `瘦猪肉丝` / `生抽`) to stay inside the
  ~194pt budget left after the Picker.
- `#Preview("CookDetailPage — step mode")` — forces `.step` via the
  fileprivate init, 3 flat steps from one `CookDish`, first step
  `.inProgress`.

## Files

- NEW: `FutureEgo/Views/Components/DetailPages/Pages/CookDetailPage.swift`
- Modified: none
