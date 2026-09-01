import PDFKit
import PencilKit

@MainActor
final class PDFViewerProxy: ObservableObject {
    weak var pdfView: PDFView?
    weak var activeCanvas: PencilPageCanvasView?

    func go(to pageIndex: Int) {
        guard let document = pdfView?.document,
              pageIndex >= 0,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else { return }
        pdfView?.go(to: page)
    }

    func zoomIn() {
        guard let pdfView else { return }
        pdfView.autoScales = false
        pdfView.scaleFactor = min(pdfView.scaleFactor * 1.25, pdfView.maxScaleFactor)
    }

    func zoomOut() {
        guard let pdfView else { return }
        pdfView.autoScales = false
        pdfView.scaleFactor = max(pdfView.scaleFactor / 1.25, pdfView.minScaleFactor)
    }

    func fitToWidth() {
        guard let pdfView else { return }
        pdfView.autoScales = true
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
    }

    func undo() {
        activeCanvas?.performUndo()
    }

    func redo() {
        activeCanvas?.performRedo()
    }
}
