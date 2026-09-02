import QuartzCore
import UIKit

/// Adds a noninteractive, zoom-aware ink display beside the native page
/// canvas without wrapping it. PDFKit must receive `PKCanvasView` itself as the
/// page overlay for reliable Pencil routing on the target iPadOS 26 device.
final class PencilPageInkPresentation {
    private weak var canvasView: PencilPageCanvasView?
    private weak var hostView: UIView?
    private let drawingRenderView = PencilDrawingRenderView(frame: .zero)
    private var renderConstraints: [NSLayoutConstraint] = []
    private var renderTransition: DispatchWorkItem?

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

    deinit {
        renderTransition?.cancel()
        detach()
    }

    func installAboveCanvas() {
        guard let canvasView, let host = canvasView.superview else { return }
        if drawingRenderView.superview === host {
            host.bringSubviewToFront(drawingRenderView)
            return
        }

        detach()
        hostView = host
        drawingRenderView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(drawingRenderView)
        renderConstraints = [
            drawingRenderView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor),
            drawingRenderView.trailingAnchor.constraint(equalTo: canvasView.trailingAnchor),
            drawingRenderView.topAnchor.constraint(equalTo: canvasView.topAnchor),
            drawingRenderView.bottomAnchor.constraint(equalTo: canvasView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(renderConstraints)
        host.bringSubviewToFront(drawingRenderView)
    }

    func detach() {
        renderTransition?.cancel()
        NSLayoutConstraint.deactivate(renderConstraints)
        renderConstraints.removeAll()
        drawingRenderView.removeFromSuperview()
        hostView = nil
    }

    func drawingDidChange() {
        guard let canvasView else { return }
        drawingRenderView.display(canvasView.drawing)
    }

    func showRenderedDrawing() {
        guard let canvasView else { return }
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        scheduleCanvasDim()
    }

    private func beginUsingTool() {
        renderTransition?.cancel()
        drawingRenderView.isHidden = true
        setCanvasLayerFullyVisible(true)
    }

    private func endUsingTool() {
        guard let canvasView else { return }
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        scheduleCanvasDim()
    }

    private func scheduleCanvasDim() {
        renderTransition?.cancel()
        let transition = DispatchWorkItem { [weak self] in
            self?.setCanvasLayerFullyVisible(false)
        }
        renderTransition = transition

        // Keep the native renderer visible briefly while the asynchronous
        // tiled layer produces the newly changed visible tiles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: transition)
    }

    private func setCanvasLayerFullyVisible(_ fullyVisible: Bool) {
        guard let canvasView else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canvasView.layer.opacity = fullyVisible ? 1 : 0.01
        CATransaction.commit()
    }
}
