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

    func beginStroke(at p: CGPoint) {
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
    @Bindable var state: InpaintEditorState

    var body: some View {
        GeometryReader { geo in
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
                        if stroke.points.count == 1 {
                            let radius = stroke.brushSize / 2
                            ctx.fill(
                                Path(ellipseIn: CGRect(
                                    x: first.x - radius,
                                    y: first.y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )),
                                with: .color(color)
                            )
                            continue
                        }
                        var path = Path()
                        path.move(to: first)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        ctx.stroke(
                            path,
                            with: .color(color),
                            style: StrokeStyle(
                                lineWidth: stroke.brushSize,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if value.translation == .zero {
                                state.beginStroke(at: value.location)
                            } else {
                                state.extendStroke(to: value.location)
                            }
                        }
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
