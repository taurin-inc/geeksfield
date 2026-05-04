import SwiftUI
import Observation

struct InpaintStroke: Hashable, Sendable {
    var points: [CGPoint]
    var brushSize: CGFloat
    var isErasing: Bool = false
}

enum InpaintTool: String, CaseIterable, Identifiable, Sendable {
    case brush
    case eraser

    var id: Self { self }
}

@Observable
@MainActor
final class InpaintEditorState {
    var strokes: [InpaintStroke] = []
    var redoStack: [InpaintStroke] = []
    var brushSize: CGFloat = 40
    var tool: InpaintTool = .brush
    var prompt: String = ""
    var zoom: CGFloat = 1.0
    var isSubmitting: Bool = false

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasMask: Bool { !strokes.isEmpty }

    func beginStroke(at p: CGPoint, brushSize: CGFloat) {
        strokes.append(InpaintStroke(points: [p], brushSize: brushSize, isErasing: tool == .eraser))
        redoStack.removeAll()
    }

    func extendStroke(to p: CGPoint) {
        guard !strokes.isEmpty else { return }
        strokes[strokes.count - 1].points.append(p)
    }

    func undo() {
        if let last = strokes.popLast() { redoStack.append(last) }
    }

    func redo() {
        if let last = redoStack.popLast() { strokes.append(last) }
    }

    func clear() {
        strokes.removeAll()
        redoStack.removeAll()
    }
}

/// A simple mask canvas: shows the underlying image and lets the user paint
/// strokes over it. Strokes are stored in the editor state; the actual PNG mask
/// is generated at submit time by `InpaintMaskEncoder`.
struct InpaintCanvas: View {
    let imageURL: URL
    let imageSize: CGSize
    @Bindable var state: InpaintEditorState

    var body: some View {
        GeometryReader { geo in
            let imageFrame = InpaintMaskEncoder.fittedImageFrame(imageSize: imageSize, containerSize: geo.size)
            ZStack {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView()
                    }
                }

                Canvas { ctx, _ in
                    for stroke in state.strokes {
                        guard let first = stroke.points.first else { continue }
                        ctx.blendMode = stroke.isErasing ? .destinationOut : .normal
                        let color = Color.red.opacity(0.5)
                        let displayBrushSize = brushSizeInView(stroke.brushSize, imageFrame: imageFrame)
                        let firstPoint = pointInView(first, imageFrame: imageFrame)
                        if stroke.points.count == 1 {
                            let radius = displayBrushSize / 2
                            ctx.fill(
                                Path(ellipseIn: CGRect(
                                    x: firstPoint.x - radius,
                                    y: firstPoint.y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )),
                                with: .color(color)
                            )
                            continue
                        }
                        var path = Path()
                        path.move(to: firstPoint)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: pointInView(point, imageFrame: imageFrame))
                        }
                        ctx.stroke(
                            path,
                            with: .color(color),
                            style: StrokeStyle(
                                lineWidth: displayBrushSize,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let imagePoint = imagePoint(from: value.location, imageFrame: imageFrame) else {
                                return
                            }
                            if value.translation == .zero {
                                state.beginStroke(
                                    at: imagePoint,
                                    brushSize: brushSizeInImagePixels(state.brushSize, imageFrame: imageFrame)
                                )
                            } else {
                                state.extendStroke(to: imagePoint)
                            }
                        }
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func imagePoint(from point: CGPoint, imageFrame: CGRect) -> CGPoint? {
        guard imageFrame.contains(point), imageFrame.width > 0, imageFrame.height > 0 else {
            return nil
        }
        return CGPoint(
            x: ((point.x - imageFrame.minX) / imageFrame.width) * imageSize.width,
            y: ((point.y - imageFrame.minY) / imageFrame.height) * imageSize.height
        )
    }

    private func pointInView(_ point: CGPoint, imageFrame: CGRect) -> CGPoint {
        CGPoint(
            x: imageFrame.minX + (point.x / imageSize.width) * imageFrame.width,
            y: imageFrame.minY + (point.y / imageSize.height) * imageFrame.height
        )
    }

    private func brushSizeInImagePixels(_ brushSize: CGFloat, imageFrame: CGRect) -> CGFloat {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return brushSize }
        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height
        return brushSize * ((scaleX + scaleY) / 2)
    }

    private func brushSizeInView(_ brushSize: CGFloat, imageFrame: CGRect) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return brushSize }
        let scaleX = imageFrame.width / imageSize.width
        let scaleY = imageFrame.height / imageSize.height
        return brushSize * ((scaleX + scaleY) / 2)
    }
}
