import SwiftUI
import Observation

struct InpaintStroke: Hashable, Sendable {
    var points: [CGPoint]
    var brushSize: CGFloat
}

@Observable
@MainActor
final class InpaintEditorState {
    var strokes: [InpaintStroke] = []
    var redoStack: [InpaintStroke] = []
    var brushSize: CGFloat = 40
    var prompt: String = ""
    var zoom: CGFloat = 1.0
    var isSubmitting: Bool = false

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasMask: Bool { !strokes.isEmpty }

    func beginStroke(at p: CGPoint) {
        strokes.append(InpaintStroke(points: [p], brushSize: brushSize))
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
                        var path = Path()
                        path.move(to: first)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        ctx.stroke(
                            path,
                            with: .color(.red.opacity(0.5)),
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
