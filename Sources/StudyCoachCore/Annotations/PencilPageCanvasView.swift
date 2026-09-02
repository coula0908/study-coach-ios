import PencilKit
import UIKit

/// A page-local, native PencilKit editor installed by PDFKit's overlay provider.
/// PDFKit owns page geometry and viewport transforms; PencilKit owns sampling,
/// prediction, rendering, erasing, and undo registration.
final class PencilPageCanvasView: PKCanvasView {
    var documentID = ""
    var pageIndex = 0
    var onDrawingChanged: (() -> Void)?
    var onToolUseBegan: (() -> Void)?
    var onToolUseEnded: (() -> Void)?
    private let drawingDelegate = PencilPageCanvasDelegate()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCanvas()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCanvas()
    }

    func performUndo() {
        undoManager?.undo()
    }

    func performRedo() {
        undoManager?.redo()
    }

    private func configureCanvas() {
        backgroundColor = .clear
        isOpaque = false
        drawingDelegate.canvas = self
        delegate = drawingDelegate

        // PencilKit owns input classification. Apple specifically recommends
        // setting the drawing policy instead of mutating the native drawing
        // recognizer's allowed touch types.
        drawingPolicy = .pencilOnly
        drawingGestureRecognizer.isEnabled = true
        isUserInteractionEnabled = true
        bounces = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
    }

}

/// Keep the PencilKit delegate separate from the canvas. `PKCanvasView` is a
/// `UIScrollView`; making a `PKCanvasView` subclass its own delegate causes an
/// iPadOS 26 PencilKit callback to re-enter `_canvasViewWillBeginDrawing:` until
/// the main-thread stack overflows when the first Pencil stroke begins.
private final class PencilPageCanvasDelegate: NSObject, PKCanvasViewDelegate {
    weak var canvas: PencilPageCanvasView?

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        canvas?.onDrawingChanged?()
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        canvas?.onToolUseBegan?()
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        canvas?.onToolUseEnded?()
    }
}

