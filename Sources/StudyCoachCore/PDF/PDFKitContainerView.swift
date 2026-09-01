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
        pdfView.document = document
        pdfView.pageOverlayViewProvider = context.coordinator

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
    final class Coordinator: NSObject, @preconcurrency PDFPageOverlayViewProvider, PKCanvasViewDelegate {
        var parent: PDFKitContainerView

        private weak var pdfView: PDFView?
        private var pageObserver: NSObjectProtocol?
        private var backgroundObserver: NSObjectProtocol?
        private var canvases: [DrawingKey: WeakCanvas] = [:]
        private var drawingCache: [DrawingKey: Data] = [:]
        private var saveTasks: [DrawingKey: Task<Void, Never>] = [:]

        init(parent: PDFKitContainerView) {
            self.parent = parent
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
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

            let canvas = PencilPageCanvasView(frame: .zero)
            canvas.documentID = parent.documentID
            canvas.pageIndex = pageIndex
            canvas.isUserInteractionEnabled = false
            parent.toolConfiguration.apply(to: canvas)
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: pageIndex)
            canvases[key] = WeakCanvas(canvas)

            if let cachedData = drawingCache[key] {
                if let drawing = try? PKDrawing(data: cachedData) {
                    canvas.drawing = drawing
                }
                canvas.delegate = self
                canvas.isUserInteractionEnabled = true
                updateActiveCanvas()
                return canvas
            }

            let documentID = parent.documentID
            let store = parent.store
            Task { [weak self, weak canvas] in
                let data = await store.drawingData(for: documentID, pageIndex: pageIndex)
                guard let self, let canvas else { return }
                guard self.canvases[key]?.value === canvas else { return }

                if let data, let drawing = try? PKDrawing(data: data) {
                    canvas.drawing = drawing
                }
                canvas.delegate = self
                canvas.isUserInteractionEnabled = true
                self.updateActiveCanvas()
            }

            return canvas
        }

        func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PencilPageCanvasView else { return }
            parent.toolConfiguration.apply(to: canvas)
            updateActiveCanvas()
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PencilPageCanvasView else { return }
            saveImmediately(canvas)
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: canvas.pageIndex)
            if canvases[key]?.value === canvas {
                canvases[key] = nil
            }
            if parent.proxy.activeCanvas === canvas {
                parent.proxy.activeCanvas = nil
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? PencilPageCanvasView else { return }
            scheduleSave(canvas)
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

        private func scheduleSave(_ canvas: PencilPageCanvasView) {
            let key = DrawingKey(documentID: canvas.documentID, pageIndex: canvas.pageIndex)
            let data = canvas.drawing.dataRepresentation()
            let store = parent.store
            drawingCache[key] = data

            saveTasks[key]?.cancel()
            saveTasks[key] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
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
