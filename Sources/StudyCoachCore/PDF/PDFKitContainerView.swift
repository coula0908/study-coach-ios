import PDFKit
import PencilKit
import SwiftUI
import UIKit

struct PDFKitContainerView: UIViewRepresentable {
    let document: PDFDocument
    let documentID: String
    @Binding var currentPageIndex: Int
    let toolConfiguration: AnnotationToolConfiguration
    let store: StudyCoachDocumentStore
    @ObservedObject var proxy: PDFViewerProxy
    let onPencilDoubleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 6
        pdfView.pageOverlayViewProvider = context.coordinator
        pdfView.isInMarkupMode = true
        pdfView.document = document

        context.coordinator.attach(to: pdfView)
        proxy.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        let documentChanged = pdfView.document !== document
        if documentChanged {
            context.coordinator.flushAllDrawings()
        }

        context.coordinator.parent = self
        context.coordinator.updateTool(toolConfiguration)
        proxy.pdfView = pdfView

        if documentChanged {
            pdfView.document = document
            pdfView.autoScales = true
        }

        if let currentPage = pdfView.currentPage,
           document.index(for: currentPage) != currentPageIndex,
           let targetPage = document.page(at: currentPageIndex) {
            pdfView.go(to: targetPage)
        }
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.flushAllDrawings()
        coordinator.detach()
        pdfView.pageOverlayViewProvider = nil
        pdfView.document = nil
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency PDFPageOverlayViewProvider {
        var parent: PDFKitContainerView

        private weak var pdfView: PDFView?
        private var pageObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?
        private var canvases: [DrawingKey: WeakCanvas] = [:]
        private var drawingCache: [DrawingKey: Data] = [:]
        private var saveTasks: [DrawingKey: Task<Void, Never>] = [:]
        private var pencilInteraction: UIPencilInteraction?

        init(parent: PDFKitContainerView) {
            self.parent = parent
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = self
            pdfView.addInteraction(pencilInteraction)
            self.pencilInteraction = pencilInteraction
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                Task { @MainActor [weak self, weak pdfView] in
                    guard let self, let pdfView else { return }
                    self.synchronizeCurrentPage(from: pdfView)
                }
            }
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.flushAllDrawings()
                }
            }
            synchronizeCurrentPage(from: pdfView)
        }

        func detach() {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
            if let backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            pageObserver = nil
            backgroundObserver = nil
            if let pencilInteraction, let pdfView {
                pdfView.removeInteraction(pencilInteraction)
            }
            pencilInteraction = nil
            saveTasks.removeAll()
            canvases.removeAll()
            parent.proxy.activeCanvas = nil
            parent.proxy.pdfView = nil
            pdfView = nil
        }

        func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let document = pdfView.document else { return nil }
            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return nil }

            let overlay = PencilPageOverlayView(frame: .zero)
            let canvas = overlay.canvasView
            canvas.documentID = parent.documentID
            canvas.pageIndex = pageIndex
            canvas.onDrawingChanged = { [weak self, weak overlay, weak canvas] in
                guard let self, let overlay, let canvas else { return }
                overlay.drawingDidChange()
                self.scheduleSave(canvas)
            }
            parent.toolConfiguration.apply(to: canvas)
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: pageIndex)
            canvases[key] = WeakCanvas(canvas)

            if let cachedData = drawingCache[key] {
                if let drawing = try? PKDrawing(data: cachedData) {
                    canvas.drawing = drawing
                }
                overlay.showRenderedDrawing()
                updateActiveCanvas()
                return overlay
            }

            let documentID = parent.documentID
            let store = parent.store
            Task { [weak self, weak overlay, weak canvas] in
                let data = await store.drawingData(for: documentID, pageIndex: pageIndex)
                guard let self, let overlay, let canvas else { return }
                guard self.canvases[key]?.value === canvas else { return }

                if let data, let drawing = try? PKDrawing(data: data) {
                    let liveDrawing = canvas.drawing
                    if liveDrawing.strokes.isEmpty {
                        canvas.drawing = drawing
                    } else if !drawing.strokes.isEmpty {
                        canvas.drawing = PKDrawing(
                            strokes: drawing.strokes + liveDrawing.strokes
                        )
                    }
                }
                overlay.showRenderedDrawing()
                self.updateActiveCanvas()
            }

            overlay.showRenderedDrawing()
            return overlay
        }

        func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            guard let overlay = overlayView as? PencilPageOverlayView else { return }
            let canvas = overlay.canvasView
            enablePageOverlayInteraction(overlay, in: pdfView)
            prioritizePencilKitInput(canvas, in: pdfView)
            parent.toolConfiguration.apply(to: canvas)
            overlay.showRenderedDrawing()
            updateActiveCanvas()

            DispatchQueue.main.async { [weak canvas] in
                guard let canvas, canvas.window != nil else { return }
                canvas.becomeFirstResponder()
            }
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let overlay = overlayView as? PencilPageOverlayView else { return }
            let canvas = overlay.canvasView
            saveImmediately(canvas)
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: canvas.pageIndex)
            if canvases[key]?.value === canvas {
                canvases[key] = nil
            }
            if parent.proxy.activeCanvas === canvas {
                parent.proxy.activeCanvas = nil
            }
        }

        func updateTool(_ configuration: AnnotationToolConfiguration) {
            removeReleasedCanvases()
            for weakCanvas in canvases.values {
                if let canvas = weakCanvas.value {
                    configuration.apply(to: canvas)
                }
            }
        }

        func flushAllDrawings() {
            removeReleasedCanvases()
            for weakCanvas in canvases.values {
                if let canvas = weakCanvas.value {
                    saveImmediately(canvas)
                }
            }
        }

        private func synchronizeCurrentPage(from pdfView: PDFView) {
            guard let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            let pageIndex = document.index(for: currentPage)
            guard pageIndex != NSNotFound else { return }

            if parent.currentPageIndex != pageIndex {
                parent.currentPageIndex = pageIndex
            }
            updateActiveCanvas()
        }

        private func updateActiveCanvas() {
            removeReleasedCanvases()
            let key = DrawingKey(
                documentID: parent.documentID,
                pageIndex: parent.currentPageIndex
            )
            parent.proxy.activeCanvas = canvases[key]?.value
        }

        private func enablePageOverlayInteraction(_ overlayView: UIView, in pdfView: PDFView) {
            pdfView.isUserInteractionEnabled = true
            pdfView.documentView?.isUserInteractionEnabled = true

            // PDFKit may create page container views with interaction disabled.
            // Enable the visible page containers as well as the overlay's exact
            // ancestor chain without depending on PDFKit's private class names.
            pdfView.documentView?.subviews.forEach {
                $0.isUserInteractionEnabled = true
            }

            overlayView.isUserInteractionEnabled = true
            var ancestor = overlayView.superview
            while let view = ancestor, view !== pdfView {
                view.isUserInteractionEnabled = true
                ancestor = view.superview
            }
        }

        private func prioritizePencilKitInput(_ canvas: PencilPageCanvasView, in pdfView: PDFView) {
            guard let scrollView = findScrollView(in: pdfView) else { return }
            scrollView.panGestureRecognizer.require(toFail: canvas.drawingGestureRecognizer)
        }

        private func findScrollView(in view: UIView) -> UIScrollView? {
            for subview in view.subviews {
                if let scrollView = subview as? UIScrollView {
                    return scrollView
                }
                if let nested = findScrollView(in: subview) {
                    return nested
                }
            }
            return nil
        }

        private func scheduleSave(_ canvas: PencilPageCanvasView) {
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: canvas.pageIndex)
            let data = canvas.drawing.dataRepresentation()
            let store = parent.store
            drawingCache[key] = data

            saveTasks[key]?.cancel()
            saveTasks[key] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled,
                      self?.drawingCache[key] == data else { return }
                do {
                    try await store.saveDrawingData(
                        data,
                        for: key.documentID,
                        pageIndex: key.pageIndex
                    )
                    if self?.drawingCache[key] == data {
                        self?.drawingCache[key] = nil
                    }
                } catch {
                    // Keep the latest data in memory so a rapid revisit still restores it.
                }
            }
        }

        private func saveImmediately(_ canvas: PencilPageCanvasView) {
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: canvas.pageIndex)
            let data = canvas.drawing.dataRepresentation()
            let store = parent.store
            drawingCache[key] = data

            saveTasks[key]?.cancel()
            saveTasks[key] = Task { [weak self] in
                guard !Task.isCancelled,
                      self?.drawingCache[key] == data else { return }
                do {
                    try await store.saveDrawingData(
                        data,
                        for: key.documentID,
                        pageIndex: key.pageIndex
                    )
                    if self?.drawingCache[key] == data {
                        self?.drawingCache[key] = nil
                    }
                } catch {
                    // Keep the latest data in memory so it can be retried on the next flush.
                }
            }
        }

        private func removeReleasedCanvases() {
            canvases = canvases.filter { $0.value.value != nil }
        }
    }
}

extension PDFKitContainerView.Coordinator: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        parent.onPencilDoubleTap()
    }
}

private struct DrawingKey: Hashable {
    let documentID: String
    let pageIndex: Int
}

private final class WeakCanvas {
    weak var value: PencilPageCanvasView?

    init(_ value: PencilPageCanvasView) {
        self.value = value
    }
}
