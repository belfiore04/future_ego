import SwiftUI

// MARK: - Data model

struct StickerItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Draggable sticker

struct DraggableSticker: View {
    let image: UIImage

    @State private var position: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 150 * scale, height: 150 * scale)
            .offset(
                x: position.width + dragOffset.width,
                y: position.height + dragOffset.height
            )
            .gesture(dragGesture)
            .gesture(magnificationGesture)
    }

    // Drag gesture: uses `@GestureState` so it auto-resets on cancel.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                position.width += value.translation.width
                position.height += value.translation.height
            }
    }

    // Pinch-to-resize.
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { value in
                lastScale *= value
                scale = lastScale
            }
    }
}

// MARK: - Overlay container

/// Renders every sticker in `stickers` as a draggable overlay.
/// Place this as an `.overlay` on top of the main content so stickers
/// float above the scroll view without intercepting its scroll gestures.
struct StickerOverlay: View {
    @Binding var stickers: [StickerItem]

    var body: some View {
        ZStack {
            // Transparent layer that does NOT capture taps in empty space,
            // allowing the scroll view underneath to remain interactive.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(false)

            ForEach(stickers) { sticker in
                DraggableSticker(image: sticker.image)
            }
        }
    }
}
