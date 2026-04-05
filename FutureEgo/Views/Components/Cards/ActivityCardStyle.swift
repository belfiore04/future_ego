import SwiftUI

// MARK: - ActivityCardStyle
//
// Shared visual container for all 6 Activity cards
// (OutingCard / DeliveryCard / CookCard / EatOutCard / ConcentratingCard /
// ExercisingCard). Applies rounded background, subtle border, and the
// three-state (done / active / upcoming) visual treatment.

extension View {
    /// Wraps a card body in the shared Activity-card container.
    func activityCardContainer(status: EventStatus) -> some View {
        modifier(ActivityCardContainerModifier(status: status))
    }
}

private struct ActivityCardContainerModifier: ViewModifier {
    let status: EventStatus

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: status == .active ? 1.2 : 1)
            )
            .opacity(status == .done ? 0.6 : 1)
    }

    private var backgroundFill: Color {
        switch status {
        case .active:
            return Color(hex: "34C759").opacity(0.06)
        case .done:
            return Color.black.opacity(0.02)
        case .upcoming:
            return Color.white
        }
    }

    private var borderColor: Color {
        switch status {
        case .active:
            return Color(hex: "34C759").opacity(0.2)
        case .done:
            return Color.black.opacity(0.06)
        case .upcoming:
            return Color.black.opacity(0.08)
        }
    }
}

// MARK: - Placeholder Alert Modifier
//
// Shared "功能开发中" alert used by the AI-推测 / 换一家 / 延后 placeholder
// buttons. Toggle the binding; the modifier takes care of presenting.

extension View {
    func placeholderFeatureAlert(isPresented: Binding<Bool>) -> some View {
        alert("功能开发中", isPresented: isPresented) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("该功能尚未实现,敬请期待。")
        }
    }
}

// MARK: - Shared chip / label helpers

/// A compact chip used for itemsToBring, ingredients, dishes, equipment, etc.
struct ActivityChip: View {
    let text: String
    var emphasis: Emphasis = .solid

    enum Emphasis {
        case solid   // dark chip (user-chosen / primary)
        case subtle  // light chip (AI-suggested / secondary)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch emphasis {
        case .solid:  return Color(hex: "3A3A3C")
        case .subtle: return Color(hex: "8E8E93")
        }
    }

    private var background: Color {
        switch emphasis {
        case .solid:  return Color.black.opacity(0.05)
        case .subtle: return Color.black.opacity(0.02)
        }
    }
}

/// Small "AI 推测" badge shown in the corner of cards that contain
/// AI-inferred content.
struct AIInferredBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
            Text("AI 推测")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Color(hex: "5856D6"))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color(hex: "5856D6").opacity(0.1))
        )
    }
}
