import UIKit

// Pencil-only input routing adapted from Pumice by Adri M.
// Source: https://github.com/theagitist/Pumice
// License: MIT; see THIRD_PARTY_NOTICES.md.
protocol PencilStrokeGestureDelegate: AnyObject {
    func pencilStrokeDidUpdate(path: UIBezierPath)
    func pencilStrokeDidFinish(path: UIBezierPath)
    func pencilStrokeDidCancel()
}

/// A deterministic Pencil-only recognizer. Finger touches are rejected so
/// PDFKit's pan and pinch recognizers continue to receive them.
final class PencilStrokeGestureRecognizer: UIGestureRecognizer {
    weak var pencilDelegate: PencilStrokeGestureDelegate?
    private var currentPath: UIBezierPath?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first,
              touch.type == .pencil,
              event.allTouches?.count == 1 else {
            state = .failed
            return
        }

        let path = UIBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.move(to: touch.location(in: view))
        currentPath = path
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let path = currentPath,
              let touch = touches.first,
              touch.type == .pencil else { return }

        for sample in event.coalescedTouches(for: touch) ?? [touch] {
            path.addLine(to: sample.location(in: view))
        }
        pencilDelegate?.pencilStrokeDidUpdate(path: path)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let path = currentPath,
              let touch = touches.first,
              touch.type == .pencil else {
            currentPath = nil
            state = .ended
            return
        }

        for sample in event.coalescedTouches(for: touch) ?? [touch] {
            path.addLine(to: sample.location(in: view))
        }
        pencilDelegate?.pencilStrokeDidFinish(path: path)
        currentPath = nil
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        currentPath = nil
        pencilDelegate?.pencilStrokeDidCancel()
        state = .cancelled
    }
}
