import SwiftUI

enum CookMode: String, CaseIterable, Identifiable {
    case list = "购物清单"
    case step = "烹饪步骤"
    var id: String { rawValue }
}

struct CookDetailPage: View {
    let detail: CookDetail
    @State private var cookMode: CookMode

    init(detail: CookDetail) {
        self.detail = detail
        self._cookMode = State(initialValue: .list)
    }

    fileprivate init(detail: CookDetail, initialMode: CookMode) {
        self.detail = detail
        self._cookMode = State(initialValue: initialMode)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.startTime)
    }

    private var activityName: String {
        let joined = detail.dishes.map(\.name).joined(separator: " + ")
        return joined.isEmpty ? "今天做饭" : joined
    }

    private var ingredientItems: [IngredientItem] {
        detail.ingredients.map {
            IngredientItem(name: $0.name, quantity: "\($0.quantity)")
        }
    }

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

    var body: some View {
        DetailPageShell(
            palette: .orange,
            dailyProgress: 0.5,
            activityProgress: 0.1
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timeString, palette: .orange)

                Text(activityName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DetailPagePalette.orange.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("厨房 · 预计 \(detail.cookDurationMinutes) 分钟")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
            }
        } interactiveSection: {
            VStack(spacing: 0) {
                Picker("模式", selection: $cookMode) {
                    ForEach(CookMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 16)

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

private func cookPreviewFixture() -> CookDetail {
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

#Preview("CookDetailPage — list") {
    CookDetailPage(detail: cookPreviewFixture())
}

#Preview("CookDetailPage — step") {
    CookDetailPage(detail: cookPreviewFixture(), initialMode: .step)
}
