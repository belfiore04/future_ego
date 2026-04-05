import SwiftUI

// MARK: - ShoppingListLayout
//
// Content layout used exclusively by CookDetailPage in its `.list` mode
// to render the ingredient "购物清单" (shopping list) block. Owns no
// state — the caller passes title + ingredients and the view draws a
// section title, palette-tinted divider, and an orange container of
// white ingredient rows.
//
// ── Source material ─────────────────────────────────────────────────
// Ground truth: `.pm/2026-04-06/ground-truth.md` §1 Leaf 22:2258
// eating(cook_list), §2 Container 22:2258, §4 "shopping-list 风格" row.
// Figma render: `.pm/2026-04-06/figma-renders/eating-cook-list.png`.
//
// Visual recipe lifted from the PNG + container spec:
//   • Section title "购物清单" — 14pt, #8E8E93 gray
//   • 1pt divider in palette.primary color
//   • Outer container: #FF8248 light-orange fill, 26pt corner radius
//   • Inner rows: white fill, 20pt corner radius, 44pt tall
//       – Left:  ingredient name    (15pt medium, #000 @ 85 %)
//       – Right: quantity / unit   (15pt medium, #000 @ 50 %)
//
// ── Phase 2b gate decision #8 (MUST READ before editing) ────────────
// Figma places this block at absolute (5, 401) — it visually breaks
// OUT of the 340×459 content card at (25, 176). The 2026-04-06 Phase
// 2b gate explicitly overrode that with Q4 = B: every detail page's
// content MUST stay inside the 340×459 content card. This file
// therefore lays out as a plain vertical section with card-interior
// padding and DOES NOT use .offset / absolute positioning / overlay
// tricks to escape the parent card. Any future editor: preserve this
// invariant — the consistency of "all content lives in the 340×459
// card" is load-bearing across the whole detail-page rewrite.

/// A single ingredient displayed by `ShoppingListLayout`.
///
/// The layout is agnostic to where the data comes from; `CookDetail`
/// will map its `ingredients: [Ingredient]` into this flat DTO.
public struct IngredientItem: Hashable {
    public let name: String
    public let quantity: String

    public init(name: String, quantity: String) {
        self.name = name
        self.quantity = quantity
    }
}

// MARK: - ShoppingListLayout

struct ShoppingListLayout: View {
    let palette: DetailPagePalette
    let title: String
    let ingredients: [IngredientItem]

    // Hex constants from ground-truth §1 22:2258. Kept local so the
    // layout is self-contained and does not depend on the project-wide
    // `Color(hex: String)` extension being available (it IS, but local
    // definitions isolate this component from upstream churn).
    private static let sectionTitleGray = Color(
        red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0
    )
    private static let shoppingBoxOrange = Color(
        red: 0xFF / 255.0, green: 0x82 / 255.0, blue: 0x48 / 255.0
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Self.sectionTitleGray)

            Rectangle()
                .fill(palette.primary)
                .frame(height: 1)
                .padding(.vertical, 4)

            VStack(spacing: 10) {
                ForEach(ingredients, id: \.self) { item in
                    IngredientRow(name: item.name, quantity: item.quantity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Self.shoppingBoxOrange)
            )

            Spacer(minLength: 0)
        }
        // Horizontal padding matches the sibling ContentLayouts so the
        // block sits flush with the content-card's interior gutter and
        // stays inside the 340-wide card (Phase 2b #8).
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

// MARK: - IngredientRow
//
// Private row primitive — white card, name on the left, quantity
// right-aligned. Kept fileprivate because it has no reuse outside the
// shopping-list block; if a second caller appears it should be lifted
// into its own file.

private struct IngredientRow: View {
    let name: String
    let quantity: String

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.85))
            Spacer(minLength: 8)
            Text(quantity)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
    }
}

// MARK: - Preview

#Preview("ShoppingListLayout — orange (cook_list)") {
    ShoppingListLayout(
        palette: .orange,
        title: "购物清单",
        ingredients: [
            IngredientItem(name: "西兰花", quantity: "1颗"),
            IngredientItem(name: "平菇", quantity: "1朵"),
            IngredientItem(name: "瘦猪肉丝", quantity: "200g"),
            IngredientItem(name: "蒜", quantity: "3瓣"),
            IngredientItem(name: "生抽", quantity: "1勺"),
            IngredientItem(name: "米饭", quantity: "2碗")
        ]
    )
    .padding(.horizontal, 25)
    .frame(width: 390, height: 560)
    .background(Color.white)
}
