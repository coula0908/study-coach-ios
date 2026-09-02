import PencilKit
import UIKit

/// A page-local, native PencilKit editor installed by PDFKit's overlay provider.
/// PDFKit owns page geometry and viewport transforms; PencilKit owns sampling,
/// prediction, rendering, erasing, and undo registration.
final class PencilPageCanvasView: PKCanvasView, PKCanvasViewDelegate {
    var documentID = ""
    var pageIndex = 0
    var onDrawingChanged: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCanvas()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCanvas()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentInset = .zero
        contentSize = bounds.size
        minimumZoomScale = 1
        maximumZoomScale = 1
        zoomScale = 1
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
        delegate = self

        // Apple's PDFKit overlay example uses `.anyInput`. Restricting the
        // native recognizer itself to Pencil touches preserves that tested
        // PencilKit path while leaving finger pan and pinch to PDFKit.
        drawingPolicy = .anyInput
        drawingGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.pencil.rawValue),
        ]
        drawingGestureRecognizer.isEnabled = true
        isUserInteractionEnabled = true
        isScrollEnabled = false
        bounces = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onDrawingChanged?()
    }
}

