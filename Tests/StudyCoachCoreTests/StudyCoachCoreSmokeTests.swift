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
    func testCustomToolPaletteDefaultsToPrecisePenSettings() {
        let state = StudyCoachToolPaletteState()

        XCTAssertEqual(state.selectedTool, .pen)
        XCTAssertEqual(state.penWidthLevel, 2)
        XCTAssertEqual(state.penWidth, 2.2)
        XCTAssertEqual(state.penColor, .black)
        XCTAssertEqual(state.highlighterOpacity, 0.35)
        XCTAssertTrue(state.isContextPanelExpanded)
    }

    func testCustomToolPaletteKeepsIndependentInkSettings() {
        var state = StudyCoachToolPaletteState()

        state.setPenWidthLevel(8)
        state.select(.highlighter)
        state.setHighlighterWidthLevel(1)
        state.selectHighlighterColor(slot: 3)
        state.setHighlighterAzimuthIndex(2)
        state.select(.pen)

        XCTAssertEqual(state.penWidth, 17)
        XCTAssertEqual(state.highlighterWidth, 2)
        XCTAssertEqual(state.highlighterColor, .mint)
        XCTAssertEqual(state.highlighterAzimuth, .pi / 2)
    }

    func testInkWidthPresetsSpanClearlyDifferentNativeValues() {
        XCTAssertEqual(Set(StudyCoachToolPaletteState.penWidths).count, 10)
        XCTAssertEqual(Set(StudyCoachToolPaletteState.highlighterWidths).count, 10)
        XCTAssertGreaterThan(
            StudyCoachToolPaletteState.penWidths.last! /
                StudyCoachToolPaletteState.penWidths.first!,
            20
        )
        XCTAssertGreaterThan(
            StudyCoachToolPaletteState.highlighterWidths.last! /
                StudyCoachToolPaletteState.highlighterWidths.first!,
            40
        )
    }

    func testHighlighterOpacityClampsToReadableControlRange() {
        var state = StudyCoachToolPaletteState()

        state.setHighlighterOpacity(5)
        XCTAssertEqual(state.highlighterOpacity, 0.80)
        state.setHighlighterOpacity(0)
        XCTAssertEqual(state.highlighterOpacity, 0.10)
        state.setHighlighterOpacity(0.42)
        XCTAssertEqual(state.highlighterOpacity, 0.42)
    }

    func testOlderPaletteJSONRestoresWithDefaultHighlighterOpacity() throws {
        let oldJSON = """
        {
          "selectedTool": "pen",
          "previousTool": "pen",
          "lastInkingTool": "pen",
          "penWidthLevel": 4,
          "highlighterWidthLevel": 2,
          "eraserWidthLevel": 4,
          "selectedPenColorSlot": 0,
          "selectedHighlighterColorSlot": 0,
          "penColors": [{"red":0.08,"green":0.08,"blue":0.09,"alpha":1}],
          "highlighterColors": [{"red":1,"green":0.84,"blue":0.12,"alpha":1}],
          "highlighterAzimuthIndex": 0,
          "eraserMode": "precision",
          "isContextPanelExpanded": true
        }
        """

        let restored = try JSONDecoder().decode(
            StudyCoachToolPaletteState.self,
            from: try XCTUnwrap(oldJSON.data(using: .utf8))
        )

        XCTAssertEqual(restored.penWidthLevel, 4)
        XCTAssertEqual(restored.highlighterOpacity, 0.35)
    }

    func testPencilEraserToggleReturnsToLastInkingTool() {
        var state = StudyCoachToolPaletteState()

        state.select(.highlighter)
        state.toggleEraser()
        XCTAssertEqual(state.selectedTool, .eraser)
        state.toggleEraser()
        XCTAssertEqual(state.selectedTool, .highlighter)
    }

    func testPaletteClampsControlLevelsAndUpdatesQuickColorSlot() {
        var state = StudyCoachToolPaletteState()

        state.setPenWidthLevel(200)
        state.setHighlighterWidthLevel(-8)
        state.setEraserWidthLevel(200)
        state.selectPenColor(slot: 2)
        let replacement = StudyCoachRGBAColor(red: 0.2, green: 0.3, blue: 0.4)
        state.replaceSelectedPenColor(with: replacement)

        XCTAssertEqual(state.penWidthLevel, 9)
        XCTAssertEqual(state.highlighterWidthLevel, 0)
        XCTAssertEqual(state.eraserWidthLevel, 9)
        XCTAssertEqual(state.penColor, replacement)
    }

    func testSwitchPreviousToolRoundTripsWithoutApplePickerState() {
        var state = StudyCoachToolPaletteState()

        state.select(.lasso)
        state.switchToPreviousTool()
        XCTAssertEqual(state.selectedTool, .pen)
        state.switchToPreviousTool()
        XCTAssertEqual(state.selectedTool, .lasso)
    }

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

        var marker = PKInkingTool(.marker, color: .systemYellow, width: 2)
        marker.azimuth = .pi / 4
        controller.drawingTool = marker
        XCTAssertEqual(marker.azimuth, .pi / 4, accuracy: 0.001)

        controller.drawingTool = PKEraserTool(.fixedWidthBitmap, width: 12)
        controller.drawingTool = PKEraserTool(.bitmap, width: 12)
        controller.drawingTool = PKEraserTool(.vector, width: 12)
        controller.drawingTool = PKLassoTool()
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
