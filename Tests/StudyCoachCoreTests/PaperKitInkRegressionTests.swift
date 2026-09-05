#if canImport(PaperKit)
import XCTest
import PaperKit
import PDFKit
import PencilKit
import UIKit
@testable import StudyCoachCore

@available(iOS 26.0, *)
@MainActor
final class PaperKitInkRegressionTests: XCTestCase {
    private func editor() throws -> PaperKitPDFPageViewController {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
            .pdfData { context in context.beginPage() }
        let page = try XCTUnwrap(PDFDocument(data: data)?.page(at: 0))
        return PaperKitPDFPageViewController(page: page, documentID: "regression",
                                             pageIndex: 0, proxy: PaperKitPDFDiagnosticProxy())
    }

    private var samples: [PaperKitPencilSample] {
        (0..<20).map { index in
            PaperKitPencilSample(location: CGPoint(x: 20 + index * 4, y: 50),
                                timestamp: Double(index) / 120, force: 1,
                                altitude: .pi / 2, azimuth: 0)
        }
    }

    func testDottedInkRemainsVisibleAfterPaperMarkupSerialization() async throws {
        let strokes = try editor().makeDottedStrokes(samples: samples, color: .black, width: 6)
        let drawing = PKDrawing(strokes: strokes)
        XCTAssertGreaterThan(strokes.count, 3)
        let restoredDrawing = try PKDrawing(data: drawing.dataRepresentation())
        XCTAssertGreaterThan(try alphaSum(restoredDrawing.image(
            from: CGRect(x: 0, y: 0, width: 200, height: 100), scale: 1)), 3000)
        var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 200, height: 100))
        markup.append(contentsOf: restoredDrawing)
        let data = try await markup.dataRepresentation()
        let restored = try PaperMarkup(dataRepresentation: data)
        let image = try await render(restored)
        XCTAssertGreaterThan(try alphaSum(image), 3000)
    }

    func testRoundedHighlighterUsesOneOpacityFactorAtBothAngles() throws {
        let controller = try editor()
        for angle in [CGFloat(0), .pi / 2] {
            let stroke = controller.makeFixedHighlighterStroke(
                samples: samples, color: .yellow, width: 8, opacity: 0.35, azimuth: angle)
            XCTAssertEqual(stroke.ink.color.cgColor.alpha, 0.35, accuracy: 0.01)
            XCTAssertEqual(stroke.path.first?.opacity, 2)
            let drawing = PKDrawing(strokes: [stroke])
            let copy = try PKDrawing(data: drawing.dataRepresentation())
            let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
            let before = try alphaSum(drawing.image(from: bounds, scale: 1))
            let after = try alphaSum(copy.image(from: bounds, scale: 1))
            XCTAssertGreaterThan(after, 3000)
            XCTAssertEqual(Double(before), Double(after), accuracy: max(100, Double(before) * 0.02))
        }
    }

    private func render(_ markup: PaperMarkup) async throws -> UIImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 200, height: 100,
            bitsPerComponent: 8, bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        await markup.draw(in: context, frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        return UIImage(cgImage: try XCTUnwrap(context.makeImage()))
    }

    func testOrderedSaveAndAnnotatedPDFExport() async throws {
        let identity = "test-\(UUID().uuidString)"
        let url = PaperKitPDFDiagnosticStorage.markupURL(for: identity, pageIndex: 0)
        let source = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
            .pdfData { context in
                context.beginPage()
                UIColor.blue.setFill()
                context.fill(CGRect(x: 10, y: 10, width: 10, height: 10))
                context.beginPage()
            }
        let document = try XCTUnwrap(PDFDocument(data: source))
        let empty = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        var latest = empty
        latest.append(contentsOf: PKDrawing(strokes: try editor().makeDottedStrokes(
            samples: samples, color: .black, width: 6)))
        _ = PaperKitOrderedSave.enqueue(empty, to: url)
        _ = PaperKitOrderedSave.enqueue(latest, to: url)
        try await PaperKitOrderedSave.flush()
        let saved = try PaperMarkup(dataRepresentation: Data(contentsOf: url))
        let savedImage = try await render(saved)
        XCTAssertGreaterThan(try alphaSum(savedImage), 3000)
        let output = try await PaperKitAnnotatedExport.make(
            document: document, documentID: identity, name: "test.pdf")
        let exported = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(exported.pageCount, 2)
        XCTAssertEqual(exported.page(at: 0)?.bounds(for: .mediaBox).size,
                       CGSize(width: 100, height: 100))
        let page = try XCTUnwrap(exported.page(at: 0))
        let image = page.thumbnail(of: CGSize(width: 200, height: 200), for: .mediaBox)
        XCTAssertNotNil(image.cgImage)
    }

    private func alphaSum(_ image: UIImage) throws -> Int {
        let image = try XCTUnwrap(image.cgImage)
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return stride(from: 3, to: image.width * image.height * 4, by: 4)
            .reduce(0) { $0 + Int(bytes[$1]) }
    }
}
#endif
