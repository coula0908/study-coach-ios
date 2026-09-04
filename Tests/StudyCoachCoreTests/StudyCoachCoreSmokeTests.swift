import PDFKit
import PencilKit
import UIKit
import XCTest
@testable import StudyCoachCore

#if canImport(PaperKit)
import PaperKit
#endif

@MainActor
final class StudyCoachCoreSmokeTests: XCTestCase {
    func testRootViewCanBeCreated() {
        _ = StudyCoachRootView()
    }

    func testPaperKitDiagnosticViewCanBeCreatedWithoutChangingProductionRoot() {
        _ = StudyCoachPaperKitDiagnosticView()
        _ = StudyCoachPaperKitPDFDiagnosticView()
        _ = StudyCoachRootView()
    }

#if canImport(PaperKit)
    @available(iOS 26.0, *)
    func testPaperKitRuntimeTypesCanBeConstructed() {
        let markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 800, height: 1_000))
        let controller = PaperMarkupViewController(
            markup: markup,
            supportedFeatureSet: .latest
        )
        XCTAssertNotNil(controller.markup)
        XCTAssertEqual(controller.supportedFeatureSet, .latest)
    }

    @available(iOS 26.0, *)
    func testAdaptivePaperKitPDFRasterizerRendersFullPageAndVisibleRegion() throws {
        let sourceBounds = CGRect(x: 0, y: 0, width: 100, height: 200)
        let pdfData = UIGraphicsPDFRenderer(bounds: sourceBounds).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(sourceBounds)
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 10, y: 10, width: 30, height: 30))
        }
        let document = try XCTUnwrap(PDFDocument(data: pdfData))
        let page = try XCTUnwrap(document.page(at: 0))
        let rasterizer = PaperKitPDFPageRasterizer(
            pageData: try XCTUnwrap(page.dataRepresentation),
            pageBounds: page.bounds(for: .cropBox),
            logicalScale: 2
        )

        XCTAssertEqual(rasterizer.logicalBounds.width, 200, accuracy: 0.01)
        XCTAssertEqual(rasterizer.logicalBounds.height, 400, accuracy: 0.01)

        let baseImage = try XCTUnwrap(
            rasterizer.render(
                logicalRect: rasterizer.logicalBounds,
                pixelsPerLogicalPoint: 2,
                maximumPixelDimension: 4_096,
                maximumPixelCount: 14_000_000
            )
        )
        XCTAssertEqual(baseImage.size.width, 400, accuracy: 0.01)
        XCTAssertEqual(baseImage.size.height, 800, accuracy: 0.01)

        let detailImage = try XCTUnwrap(
            rasterizer.render(
                logicalRect: CGRect(x: 40, y: 80, width: 50, height: 60),
                pixelsPerLogicalPoint: 3,
                maximumPixelDimension: 4_096,
                maximumPixelCount: 14_000_000
            )
        )
        XCTAssertEqual(detailImage.size.width, 150, accuracy: 0.01)
        XCTAssertEqual(detailImage.size.height, 180, accuracy: 0.01)
    }

    @available(iOS 26.0, *)
    func testDetailTilePlanReusesLevelAndCoverageDuringFixedScalePan() throws {
        let logicalBounds = CGRect(x: 0, y: 0, width: 1_200, height: 1_600)
        let firstVisibleFrame = CGRect(x: 300, y: 400, width: 300, height: 400)
        let secondVisibleFrame = firstVisibleFrame.offsetBy(dx: 90, dy: 0)
        let viewportSize = CGSize(width: 1_200, height: 1_600)

        let firstPlan = try XCTUnwrap(
            PaperKitPDFDetailTilePlanner.plan(
                logicalBounds: logicalBounds,
                visibleFrame: firstVisibleFrame,
                viewportSize: viewportSize,
                screenScale: 2,
                basePixelsPerLogicalPoint: 2,
                supersampling: 1.2,
                tilePixelDimension: 512,
                prefetchTileRings: 2,
                maximumTileCount: 96
            )
        )
        let secondPlan = try XCTUnwrap(
            PaperKitPDFDetailTilePlanner.plan(
                logicalBounds: logicalBounds,
                visibleFrame: secondVisibleFrame,
                viewportSize: viewportSize,
                screenScale: 2,
                basePixelsPerLogicalPoint: 2,
                supersampling: 1.2,
                tilePixelDimension: 512,
                prefetchTileRings: 2,
                maximumTileCount: 96
            )
        )

        XCTAssertEqual(firstPlan.level, secondPlan.level)
        XCTAssertEqual(
            firstPlan.pixelsPerLogicalPoint,
            secondPlan.pixelsPerLogicalPoint,
            accuracy: 0.001
        )

        let firstKeys = Set(firstPlan.tiles.map(\.key))
        let secondKeys = Set(secondPlan.tiles.map(\.key))
        XCTAssertLessThanOrEqual(firstPlan.tiles.count, 96)
        XCTAssertLessThanOrEqual(secondPlan.tiles.count, 96)
        XCTAssertFalse(firstKeys.intersection(secondKeys).isEmpty)
        XCTAssertFalse(secondKeys.subtracting(firstKeys).isEmpty)
        let firstVisibleCount = firstPlan.tiles.filter(\.isVisible).count
        let secondVisibleCount = secondPlan.tiles.filter(\.isVisible).count
        XCTAssertTrue(firstPlan.tiles.prefix(firstVisibleCount).allSatisfy(\.isVisible))
        XCTAssertTrue(firstPlan.tiles.dropFirst(firstVisibleCount).allSatisfy { !$0.isVisible })
        XCTAssertTrue(secondPlan.tiles.prefix(secondVisibleCount).allSatisfy(\.isVisible))
        XCTAssertTrue(secondPlan.tiles.dropFirst(secondVisibleCount).allSatisfy { !$0.isVisible })
    }

    @available(iOS 26.0, *)
    func testDetailTilePlanUsesBaseImageWhenItsDensityIsEnough() {
        let plan = PaperKitPDFDetailTilePlanner.plan(
            logicalBounds: CGRect(x: 0, y: 0, width: 1_200, height: 1_600),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600),
            viewportSize: CGSize(width: 1_000, height: 1_300),
            screenScale: 2,
            basePixelsPerLogicalPoint: 2,
            supersampling: 1,
            tilePixelDimension: 512,
            prefetchTileRings: 2,
            maximumTileCount: 96
        )

        XCTAssertNil(plan)
    }
#endif

    func testNativePencilKitCanvasUsesPencilOnlyDrawingPolicy() {
        let canvas = PencilPageCanvasView(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        XCTAssertTrue(canvas.drawingGestureRecognizer.isEnabled)
        XCTAssertEqual(canvas.drawingPolicy, .pencilOnly)
        XCTAssertTrue(canvas.isScrollEnabled)
        XCTAssertNotNil(canvas.delegate)
        XCTAssertFalse(canvas.delegate === canvas)
    }

    func testHighResolutionPresentationStaysInsideTheInteractiveCanvas() {
        let canvas = PencilPageCanvasView(
            frame: CGRect(x: 0, y: 0, width: 500, height: 700)
        )
        let presentation = PencilPageInkPresentation(canvasView: canvas)

        presentation.installInsideCanvas()
        presentation.showRenderedDrawing()
        XCTAssertTrue(presentation.isInstalledInsideCanvas)
        XCTAssertEqual(canvas.drawingPolicy, .pencilOnly)
        XCTAssertEqual(canvas.layer.opacity, 1)
    }

    func testNativeToolsExposeStrokeAndPartialErasers() {
        let canvas = PencilPageCanvasView(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        AnnotationToolConfiguration(
            tool: .eraser,
            color: .black,
            width: 0.25,
            eraserMode: .stroke
        ).apply(to: canvas)
        XCTAssertEqual((canvas.tool as? PKEraserTool)?.eraserType, .vector)

        AnnotationToolConfiguration(
            tool: .eraser,
            color: .black,
            width: 0.25,
            eraserMode: .partial
        ).apply(to: canvas)
        XCTAssertEqual((canvas.tool as? PKEraserTool)?.eraserType, .bitmap)
    }

    func testDrawingDataRoundTripsByDocumentAndPage() async throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let expected = Data([0x01, 0x02, 0x03, 0x04])

        try await store.saveDrawingData(expected, for: "document-a", pageIndex: 7)
        let restored = await store.drawingData(for: "document-a", pageIndex: 7)
        let otherPage = await store.drawingData(for: "document-a", pageIndex: 8)
        let otherDocument = await store.drawingData(for: "document-b", pageIndex: 7)

        XCTAssertEqual(restored, expected)
        XCTAssertNil(otherPage)
        XCTAssertNil(otherDocument)
    }

    func testImportUsesStableContentIdentityAndRestoresLastPage() async throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanUp() }
        let store = fixture.makeStore()
        let sourceURL = fixture.rootURL.appendingPathComponent("fixture.pdf")
        try Data("stable-pdf-fixture".utf8).write(to: sourceURL)

        let firstImport = try await store.importPDF(from: sourceURL)
        await store.updateLastPageIndex(12, for: firstImport.id)
        let secondImport = try await store.importPDF(from: sourceURL)
        let restored = await store.lastDocument()

        XCTAssertEqual(firstImport.id, secondImport.id)
        XCTAssertEqual(firstImport.id.count, 64)
        XCTAssertEqual(secondImport.lastPageIndex, 12)
        XCTAssertEqual(restored?.id, firstImport.id)
        XCTAssertEqual(restored?.lastPageIndex, 12)
    }
}

private struct StoreFixture {
    let rootURL: URL
    let suiteName: String

    init() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyCoachCoreTests-\(UUID().uuidString)", isDirectory: true)
        let temporarySuiteName = "StudyCoachCoreTests.\(UUID().uuidString)"

        rootURL = temporaryRoot
        suiteName = temporarySuiteName
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    func makeStore() -> StudyCoachDocumentStore {
        let storeDefaults = UserDefaults(suiteName: suiteName)!
        return StudyCoachDocumentStore(rootURL: rootURL, defaults: storeDefaults)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}
