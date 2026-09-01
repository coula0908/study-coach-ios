import PencilKit
import UIKit

/// A page-local PencilKit drawing store and renderer whose input is supplied
/// by a deterministic Pencil-only recognizer.
final class PencilPageCanvasView: PKCanvasView {
    var documentID = ""
    var pageIndex = 0
    var onDrawingChanged: (() -> Void)?

    private var selectedTool: AnnotationTool = .pen
    private var selectedColor: UIColor = .systemBlue
    private var selectedWidth: CGFloat = 4
    private var undoDrawings: [PKDrawing] = []
    private var redoDrawings: [PKDrawing] = []
    private var eraserBaseline: PKDrawing?
    private var eraserLastPoint: CGPoint?

    private let liveLayer = CAShapeLayer()
    private let eraserRadius: CGFloat = 12
    private let maximumUndoDepth = 50

    private lazy var pencilGesture: PencilStrokeGestureRecognizer = {
        let gesture = PencilStrokeGestureRecognizer()
        gesture.pencilDelegate = self
        return gesture
    }()

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
        liveLayer.frame = bounds
    }

    func apply(_ configuration: AnnotationToolConfiguration) {
        selectedTool = configuration.tool
        selectedColor = configuration.color
        selectedWidth = configuration.width
        applyLiveStyle()
    }

    func performUndo() {
        guard let previous = undoDrawings.popLast() else { return }
        redoDrawings.append(drawing)
        drawing = previous
        notifyDrawingChanged()
    }

    func performRedo() {
        guard let next = redoDrawings.popLast() else { return }
        undoDrawings.append(drawing)
        drawing = next
        notifyDrawingChanged()
    }

    private func configureCanvas() {
        backgroundColor = .clear
        isOpaque = false
        // Pumice's iPadOS 26 device testing found that PencilKit's own
        // recognizer can fall through to PDFView inside page overlays. Keep
        // PencilKit for PKDrawing rendering/persistence, but route input with
        // the proven Pencil-only recognizer instead.
        drawingPolicy = .pencilOnly
        drawingGestureRecognizer.isEnabled = false
        isUserInteractionEnabled = true
        isScrollEnabled = false
        bounces = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false

        liveLayer.fillColor = nil
        liveLayer.lineCap = .round
        liveLayer.lineJoin = .round
        layer.addSublayer(liveLayer)
        addGestureRecognizer(pencilGesture)
        applyLiveStyle()
    }

    private func applyLiveStyle() {
        switch selectedTool {
        case .pen:
            liveLayer.strokeColor = selectedColor.cgColor
            liveLayer.lineWidth = selectedWidth
        case .highlighter:
            liveLayer.strokeColor = selectedColor.withAlphaComponent(0.35).cgColor
            liveLayer.lineWidth = max(selectedWidth * 2.5, 8)
        case .eraser:
            liveLayer.strokeColor = UIColor.clear.cgColor
            liveLayer.lineWidth = 0
        }
    }

    private func appendStroke(from path: UIBezierPath) {
        let points = controlPoints(from: path)
        guard points.count >= 2 else { return }

        let previous = drawing
        let width: CGFloat
        let ink: PKInk
        switch selectedTool {
        case .pen:
            width = selectedWidth
            ink = PKInk(.pen, color: selectedColor)
        case .highlighter:
            width = max(selectedWidth * 2.5, 8)
            ink = PKInk(.marker, color: selectedColor.withAlphaComponent(0.45))
        case .eraser:
            return
        }

        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) / 120,
                size: CGSize(width: width, height: width),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let stroke = PKStroke(ink: ink, path: strokePath)
        recordUndo(previous)
        drawing = PKDrawing(strokes: previous.strokes + [stroke])
        notifyDrawingChanged()
    }

    private func erase(from start: CGPoint, to end: CGPoint) {
        let kept = drawing.strokes.filter { candidate in
            !intersectsEraser(candidate, from: start, to: end)
        }
        if kept.count != drawing.strokes.count {
            drawing = PKDrawing(strokes: kept)
        }
    }

    private func intersectsEraser(
        _ stroke: PKStroke,
        from start: CGPoint,
        to end: CGPoint
    ) -> Bool {
        guard stroke.path.count > 0 else { return false }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let steps = max(1, Int(distance / 4))

        for index in 0..<stroke.path.count {
            let point = stroke.path[index].location.applying(stroke.transform)
            let strokeRadius = max(stroke.path[index].size.width / 2, 1)
            let hitRadius = eraserRadius + strokeRadius
            for step in 0...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                let sample = CGPoint(
                    x: start.x + dx * progress,
                    y: start.y + dy * progress
                )
                if hypot(point.x - sample.x, point.y - sample.y) <= hitRadius {
                    return true
                }
            }
        }
        return false
    }

    private func controlPoints(from path: UIBezierPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.points[0])
            default:
                break
            }
        }
        return points
    }

    private func recordUndo(_ previous: PKDrawing) {
        undoDrawings.append(previous)
        if undoDrawings.count > maximumUndoDepth {
            undoDrawings.removeFirst(undoDrawings.count - maximumUndoDepth)
        }
        redoDrawings.removeAll()
    }

    private func notifyDrawingChanged() {
        onDrawingChanged?()
    }
}

extension PencilPageCanvasView: PencilStrokeGestureDelegate {
    func pencilStrokeDidUpdate(path: UIBezierPath) {
        switch selectedTool {
        case .pen, .highlighter:
            liveLayer.path = path.cgPath
        case .eraser:
            liveLayer.path = nil
            if eraserBaseline == nil {
                eraserBaseline = drawing
            }
            let current = path.currentPoint
            let previous = eraserLastPoint ?? current
            erase(from: previous, to: current)
            eraserLastPoint = current
        }
    }

    func pencilStrokeDidFinish(path: UIBezierPath) {
        liveLayer.path = nil
        switch selectedTool {
        case .pen, .highlighter:
            appendStroke(from: path)
        case .eraser:
            let current = path.currentPoint
            if let previous = eraserLastPoint {
                erase(from: previous, to: current)
            }
            if let baseline = eraserBaseline,
               baseline.dataRepresentation() != drawing.dataRepresentation() {
                recordUndo(baseline)
                notifyDrawingChanged()
            }
            eraserBaseline = nil
            eraserLastPoint = nil
        }
    }

    func pencilStrokeDidCancel() {
        liveLayer.path = nil
        if let baseline = eraserBaseline {
            drawing = baseline
        }
        eraserBaseline = nil
        eraserLastPoint = nil
    }
}

