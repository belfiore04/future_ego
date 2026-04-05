import SwiftUI

// MARK: - CookCard
//
// Renders a `CookDetail` (eating.cook) payload.
// - Big title: either the first dish name, or a compact summary when there
//   are multiple dishes ("菜1、菜2")
// - Subtitle: HH:mm 开始 · 耗时 XX 分钟 · 共 N 道 (when > 1 dish)
// - Two sections:
//     · 食材 — chip list of Ingredient (name + quantity)
//     · 做菜步骤 — grouped by dish, each step numbered
// - Hero element: the steps section.

struct CookCard: View {
    let detail: CookDetail
    let status: EventStatus

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let eatingColor = Color(hex: "FF9500")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !detail.ingredients.isEmpty {
                ingredientsSection
            }
            if !detail.dishes.isEmpty {
                stepsSection
            }
        }
        .activityCardContainer(status: status)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(2)

            Text(subtitleText)
                .font(.system(size: 13))
                .foregroundColor(grayText)
        }
    }

    private var titleText: String {
        let names = detail.dishes.map(\.name)
        if names.isEmpty { return "自己做饭" }
        if names.count == 1 { return names[0] }
        return names.joined(separator: "、")
    }

    private var subtitleText: String {
        var parts: [String] = []
        parts.append("\(hhmm(detail.startTime)) 开始")
        parts.append("耗时 \(detail.cookDurationMinutes) 分钟")
        if detail.dishes.count > 1 {
            parts.append("共 \(detail.dishes.count) 道")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("食材")
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(detail.ingredients) { ing in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(eatingColor.opacity(0.5))
                            .frame(width: 4, height: 4)
                        Text(ing.name)
                            .font(.system(size: 13))
                            .foregroundColor(darkText)
                        Spacer(minLength: 4)
                        Text(ing.quantity)
                            .font(.system(size: 12))
                            .foregroundColor(grayText)
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("做菜步骤")
            ForEach(detail.dishes) { dish in
                VStack(alignment: .leading, spacing: 6) {
                    Text(dish.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(darkText)
                    ForEach(Array(dish.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(eatingColor)
                                .frame(width: 16, height: 16)
                                .background(
                                    Circle().fill(eatingColor.opacity(0.12))
                                )
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundColor(darkText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(grayText)
            .textCase(.uppercase)
    }

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview("Cook · upcoming") {
    if case .eating(.cook(let c)) = SampleData.schedule[6].detail {
        ScrollView {
            CookCard(detail: c, status: .upcoming)
                .padding()
        }
    }
}
