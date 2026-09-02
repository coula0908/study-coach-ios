import PencilKit
import QuartzCore
import UIKit

/// Keeps native PencilKit interaction and zoom-aware resting display separate.
/// The live canvas is visible while a tool is in use. After the sequence ends,
/// the same `PKDrawing` is presented by `PencilDrawingRenderView` so PDFKit can
/// request higher-resolution tiles as the page is enlarged.
final class PencilPageOverlayView: UIView {
    let canvasView = PencilPageCanvasView(frame: .zero)

    private let drawingRenderView = PencilDrawingRenderView(frame: .zero)
    private var renderTransition: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureOverlay()
    }

    deinit {
        renderTransition?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawingRenderView.frame = bounds
        canvasView.frame = bounds
    }

    func drawingDidChange() {
        drawingRenderView.display(canvasView.drawing)
    }

    func showRenderedDrawing() {
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        scheduleCanvasHide()
    }

    func beginUsingTool() {
        renderTransition?.cancel()
        drawingRenderView.isHidden = true
        setCanvasLayerVisible(true)
    }

    func endUsingTool() {
        drawingRenderView.display(canvasView.drawing)
        drawingRenderView.isHidden = false
        scheduleCanvasHide()
    }

    private func configureOverlay() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = true

        drawingRenderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(drawingRenderView)
        addSubview(canvasView)

        canvasView.onToolUseBegan = { [weak self] in
            self?.beginUsingTool()
        }
        canvasView.onToolUseEnded = { [weak self] in
            self?.endUsingTool()
        }
    }

    private func scheduleCanvasHide() {
        renderTransition?.cancel()
        let transition = DispatchWorkItem { [weak self] in
            self?.setCanvasLayerVisible(false)
        }
        renderTransition = transition

        // Keep the native renderer visible briefly while the asynchronous
        // tiled layer produces the newly changed visible tiles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: transition)
    }

    private func setCanvasLayerVisible(_ visible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Keep a minimally visible render surface. A fully transparent backing
        // layer can make PencilKit stop beginning tool sequences even though
        // UIKit hit testing still reaches the PKCanvasView.
        canvasView.layer.opacity = visible ? 1 : 0.01
        CATransaction.commit()
    }
}
