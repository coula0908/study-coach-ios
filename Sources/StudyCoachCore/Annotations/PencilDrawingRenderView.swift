import PencilKit
import QuartzCore
import UIKit

/// Displays a `PKDrawing` with zoom-aware tiles while PencilKit remains the
/// authoritative editor and persistence format.
///
/// PDFKit transforms page overlays as the document zooms. A live
/// `PKCanvasView` can leave its existing render surface magnified instead of
/// producing a new level of detail. `CATiledLayer` asks for tiles at the
/// current presentation scale, and `PKDrawing.image(from:scale:)` renders only
/// the requested tile from the original stroke data.
final class PencilDrawingRenderView: UIView {
    private let drawingLock = NSLock()
    private var currentDrawing = PKDrawing()
    private let baseDisplayScale: CGFloat

    override class var layerClass: AnyClass {
        PencilDrawingTiledLayer.self
    }

    override init(frame: CGRect) {
        baseDisplayScale = UIScreen.main.scale
        super.init(frame: frame)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        baseDisplayScale = UIScreen.main.scale
        super.init(coder: coder)
        configureLayer()
    }

    func display(_ drawing: PKDrawing) {
        drawingLock.lock()
        currentDrawing = drawing
        drawingLock.unlock()
        layer.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let drawing = drawingSnapshot()
        guard !drawing.strokes.isEmpty,
              let context = UIGraphicsGetCurrentContext() else { return }

        // Include neighboring stroke pixels so wide ink does not produce seams
        // where independently rendered tiles meet.
        let sourceRect = rect.insetBy(dx: -32, dy: -32)
        let transform = context.ctm
        let horizontalScale = hypot(transform.a, transform.c)
        let verticalScale = hypot(transform.b, transform.d)
        let requestedScale = max(baseDisplayScale, max(horizontalScale, verticalScale))
        let boundedScale = min(max(requestedScale, 1), 16)
        let image = drawing.image(from: sourceRect, scale: boundedScale)
        image.draw(in: sourceRect)
    }

    private func configureLayer() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw

        guard let tiledLayer = layer as? CATiledLayer else { return }
        tiledLayer.tileSize = CGSize(width: 512, height: 512)
        tiledLayer.levelsOfDetail = 1
        tiledLayer.levelsOfDetailBias = 4
        tiledLayer.drawsAsynchronously = true
    }

    private func drawingSnapshot() -> PKDrawing {
        drawingLock.lock()
        defer { drawingLock.unlock() }
        return currentDrawing
    }
}

private final class PencilDrawingTiledLayer: CATiledLayer {
    override class func fadeDuration() -> CFTimeInterval {
        0
    }
}
