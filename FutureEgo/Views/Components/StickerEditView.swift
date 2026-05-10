import SwiftUI

// MARK: - StickerEditView
//
// Brush-based mask editor presented after auto-segmentation. The user
// sees the cutout on top of a faded reference of the original photo,
// and can:
//
//   • Tap "加" then drag → paint pixels from the original image BACK
//     into the cutout (extends the mask).
//   • Tap "减" then drag → erase pixels from the cutout (shrinks the
//     mask).
//
// The preview is a SwiftUI composition that re-renders on every stroke
// change. On confirm we bake the same composition into a UIImage via
// `ImageRenderer` and hand it back to the caller.
//
// Strokes are stored as image-space points (not view-space), so
// resizing the view doesn't drift the mask. We do this by asking the
// drag gesture for `value.location` inside a fixed-frame display, then
// converting to the rendered image's pixel coordinates at bake time.

struct StickerEditView: View {
    let originalImage: UIImage
    let segmentedImage: UIImage
    let palette: DetailPagePalette
    var onConfirm: (UIImage) -> Void
    var onCancel: () -> Void

    enum BrushMode {
        case add, erase
    }

    @State private var mode: BrushMode = .erase
    @State private var brushSize: CGFloat = 28
    @State private var addStrokes: [BrushStroke] = []
    @State private var eraseStrokes: [BrushStroke] = []
    @State private var currentStroke: BrushStroke? = nil

    // The display canvas size is recorded once geometry resolves so
    // strokes can be replayed at bake time.
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                editingCanvas
                    .padding(.horizontal, 16)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Top bar (cancel / title / confirm)

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text("调整抠图")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button {
                if let baked = bakeFinalImage() {
                    onConfirm(baked)
                }
            } label: {
                Text("完成")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.primary)
            }
        }
    }

    // MARK: - Canvas

    private var editingCanvas: some View {
        GeometryReader { geo in
            ZStack {
                // Faded reference of the full original photo so the user
                // can see where the cutout lost pixels.
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.25)

                // Cutout layer with mask reflecting erase strokes.
                Image(uiImage: segmentedImage)
                    .resizable()
                    .scaledToFit()
                    .mask(
                        Canvas { ctx, size in
                            ctx.fill(
                                Path(CGRect(origin: .zero, size: size)),
                                with: .color(.white)
                            )
                            for stroke in liveEraseStrokes {
                                ctx.stroke(
                                    stroke.path,
                                    with: .color(.black),
                                    style: StrokeStyle(
                                        lineWidth: stroke.size,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }
                        }
                    )

                // "Add back" layer: original photo masked to the add strokes.
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .mask(
                        Canvas { ctx, size in
                            ctx.fill(
                                Path(CGRect(origin: .zero, size: size)),
                                with: .color(.clear)
                            )
                            for stroke in liveAddStrokes {
                                ctx.stroke(
                                    stroke.path,
                                    with: .color(.white),
                                    style: StrokeStyle(
                                        lineWidth: stroke.size,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }
                        }
                    )

                // Brush cursor: subtle ring at the most recent stroke
                // point so the user knows the brush size before painting.
                if let p = currentStroke?.points.last {
                    Circle()
                        .stroke(palette.primary, lineWidth: 2)
                        .frame(width: brushSize, height: brushSize)
                        .position(p)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        appendPoint(value.location)
                    }
                    .onEnded { _ in
                        commitStroke()
                    }
            )
            .onAppear {
                canvasSize = geo.size
            }
            .onChange(of: geo.size) { _, new in
                canvasSize = new
            }
        }
        .aspectRatio(originalImage.size.width / originalImage.size.height,
                     contentMode: .fit)
    }

    // MARK: - Bottom bar (mode + brush size + reset)

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                modeButton(label: "减", systemImage: "minus.circle", value: .erase)
                modeButton(label: "加", systemImage: "plus.circle", value: .add)
                Spacer()
                Button {
                    addStrokes.removeAll()
                    eraseStrokes.removeAll()
                    currentStroke = nil
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.7))
                Slider(value: $brushSize, in: 8 ... 80)
                    .tint(palette.primary)
                Image(systemName: "circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private func modeButton(label: String, systemImage: String, value: BrushMode) -> some View {
        let active = (mode == value)
        Button {
            mode = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(active ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(active ? palette.primary : Color.white.opacity(0.1))
            )
        }
    }

    // MARK: - Stroke handling

    private var liveAddStrokes: [BrushStroke] {
        guard mode == .add, let s = currentStroke else { return addStrokes }
        return addStrokes + [s]
    }

    private var liveEraseStrokes: [BrushStroke] {
        guard mode == .erase, let s = currentStroke else { return eraseStrokes }
        return eraseStrokes + [s]
    }

    private func appendPoint(_ p: CGPoint) {
        if currentStroke == nil {
            currentStroke = BrushStroke(points: [p], size: brushSize)
        } else {
            currentStroke?.points.append(p)
        }
    }

    private func commitStroke() {
        guard let s = currentStroke else { return }
        switch mode {
        case .add:   addStrokes.append(s)
        case .erase: eraseStrokes.append(s)
        }
        currentStroke = nil
    }

    // MARK: - Bake to UIImage

    /// Render the same SwiftUI composition shown on screen into a
    /// final UIImage at the original image's pixel dimensions. This
    /// keeps the exported sticker resolution-faithful even if the on-
    /// screen canvas was smaller.
    @MainActor
    private func bakeFinalImage() -> UIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return segmentedImage
        }

        // Scale strokes from canvas-space to image-space.
        let imgSize = segmentedImage.size
        let sx = imgSize.width / canvasSize.width
        let sy = imgSize.height / canvasSize.height
        let scale = min(sx, sy)

        // Scaling is uniform because the image is `.scaledToFit`. We
        // also need the letterbox offset so points map correctly when
        // the canvas aspect doesn't match the image aspect.
        let drawnW = imgSize.width / scale
        let drawnH = imgSize.height / scale
        let offsetX = (canvasSize.width  - drawnW) / 2
        let offsetY = (canvasSize.height - drawnH) / 2

        let mappedAdd = addStrokes.map { stroke in
            stroke.scaled(offset: CGPoint(x: -offsetX, y: -offsetY), scale: scale)
        }
        let mappedErase = eraseStrokes.map { stroke in
            stroke.scaled(offset: CGPoint(x: -offsetX, y: -offsetY), scale: scale)
        }

        let view = BakeComposite(
            originalImage: originalImage,
            segmentedImage: segmentedImage,
            addStrokes: mappedAdd,
            eraseStrokes: mappedErase,
            renderSize: imgSize
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - BrushStroke value type

struct BrushStroke {
    var points: [CGPoint]
    var size: CGFloat

    var path: Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() {
            p.addLine(to: pt)
        }
        return p
    }

    func scaled(offset: CGPoint, scale: CGFloat) -> BrushStroke {
        BrushStroke(
            points: points.map {
                CGPoint(x: ($0.x + offset.x) * scale,
                        y: ($0.y + offset.y) * scale)
            },
            size: size * scale
        )
    }
}

// MARK: - Off-screen composite used by `ImageRenderer`

private struct BakeComposite: View {
    let originalImage: UIImage
    let segmentedImage: UIImage
    let addStrokes: [BrushStroke]
    let eraseStrokes: [BrushStroke]
    let renderSize: CGSize

    var body: some View {
        ZStack {
            Image(uiImage: segmentedImage)
                .resizable()
                .frame(width: renderSize.width, height: renderSize.height)
                .mask(
                    Canvas { ctx, size in
                        ctx.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.white)
                        )
                        for s in eraseStrokes {
                            ctx.stroke(
                                s.path,
                                with: .color(.black),
                                style: StrokeStyle(
                                    lineWidth: s.size,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }
                    .frame(width: renderSize.width, height: renderSize.height)
                )

            Image(uiImage: originalImage)
                .resizable()
                .frame(width: renderSize.width, height: renderSize.height)
                .mask(
                    Canvas { ctx, size in
                        ctx.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.clear)
                        )
                        for s in addStrokes {
                            ctx.stroke(
                                s.path,
                                with: .color(.white),
                                style: StrokeStyle(
                                    lineWidth: s.size,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }
                    .frame(width: renderSize.width, height: renderSize.height)
                )
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }
}
