import PencilKit
import UIKit

/// A page-local PencilKit canvas that lets non-Pencil touches reach PDFKit.
final class PencilPageCanvasView: PKCanvasView {
    var documentID = ""
    var pageIndex = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCanvas()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCanvas()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let touches = event?.allTouches,
           !touches.contains(where: { $0.type == .pencil }) {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentInset = .zero
        contentSize = bounds.size
        minimumZoomScale = 1
        maximumZoomScale = 1
        zoomScale = 1
    }

    private func configureCanvas() {
        backgroundColor = .clear
        isOpaque = false
        drawingPolicy = .pencilOnly
        isScrollEnabled = false
        bounces = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
    }
}
