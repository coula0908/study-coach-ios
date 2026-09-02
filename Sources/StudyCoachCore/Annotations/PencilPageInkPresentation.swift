import UIKit

/// Adds a noninteractive, zoom-aware ink display inside the native page canvas
/// without wrapping it or adding a sibling to PDFKit's private page hierarchy.
/// PDFKit still receives `PKCanvasView` itself as the complete page overlay.
final class PencilPageInkPresentation {
    private weak var canvasView: PencilPageCanvasView?
    private let drawingRenderView = PencilDrawingRenderView(frame: .zero)

    var isInstalledInsideCanvas: Bool {
        drawingRenderView.superview === canvasView
    }

    init(canvasView: PencilPageCanvasView) {
        self.canvasView = canvasView
        drawingRenderView.isUserInteractionEnabled = false

        canvasView.onToolUseBegan = { [weak self] in
            self?.beginUsingTool()
        }
        canvasView.onToolUseEnded = { [weak self] in
            self?.endUsingTool()
        }
    }

    func installInsideCanvas() {
        guard let canvasView else { return }
        if drawingRenderView.superview === canvasView {
            canvasView.bringSubviewToFront(drawingRenderView)
            return
        }

        detach()
        drawingRenderView.frame = canvasView.bounds
        drawingRenderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.addSubview(drawingRenderView)
        canvasView.bringSubviewToFront(drawingRenderView)
    }

    func detach() {
        drawingRenderView.removeFromSuperview()
    }

    func drawingDidChange() {
        guard let canvasView else { return }
        drawingRenderView.display(canvasView.drawing)
    }

    func showRenderedDrawing() {
        guard let canvasView else { return }
        drawingRenderView.frame = canvasView.bounds
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        canvasView.bringSubviewToFront(drawingRenderView)
    }

    private func beginUsingTool() {
        drawingRenderView.isHidden = true
    }

    private func endUsingTool() {
        guard let canvasView else { return }
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        canvasView.bringSubviewToFront(drawingRenderView)
    }
}
