import SwiftUI

// MARK: - ReviewTabView

struct ReviewTabView: View {
    // MARK: - State

    @State private var selectedCategory: CategoryCard?
    @State private var appeared = false

    // MARK: - Layout

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Subtitle ──
                    Text("回顾过去，优化未来")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    // ── Category Grid ──
                    categoryGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // room for tab bar
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("复盘")
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        let cards = ReviewSampleData.categoryCards
        return LazyVGrid(columns: columns, spacing: 12) {
            // First card spans full width
            if let first = cards.first {
                CategoryCardView(
                    card: first,
                    index: 0,
                    appeared: appeared
                ) {
                    selectedCategory = first
                }
                .frame(maxWidth: .infinity)
                .gridCellColumns(2)
            }

            // Remaining cards in 2-column grid
            ForEach(Array(cards.dropFirst().enumerated()), id: \.element.id) { offset, card in
                CategoryCardView(
                    card: card,
                    index: offset + 1,
                    appeared: appeared
                ) {
                    selectedCategory = card
                }
            }
        }
    }
}

// MARK: - CategoryCardView

private struct CategoryCardView: View {
    let card: CategoryCard
    let index: Int
    let appeared: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 0) {
                // Left color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(card.color)
                    .frame(width: 3)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 6) {
                    // Emoji icon
                    Text(card.icon)
                        .font(.system(size: 28))

                    // Category name
                    Text(card.label)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)

                    // Summary
                    Text(card.summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(card.color)
                        .lineLimit(1)

                    // Description
                    Text(card.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .padding(.vertical, 14)

                Spacer(minLength: 0)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "C7C7CC"))
                    .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CardPressStyle())
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : 16)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.75)
                .delay(Double(index) * 0.05),
            value: appeared
        )
    }
}

// MARK: - CardPressStyle

/// A button style that applies a subtle scale-down when pressed.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ReviewTabView()
}
