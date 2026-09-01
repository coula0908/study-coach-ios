import XCTest
@testable import StudyCoachCore

@MainActor
final class StudyCoachCoreSmokeTests: XCTestCase {
    func testRootViewCanBeCreated() {
        _ = StudyCoachRootView()
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
    let defaults: UserDefaults
    let suiteName: String

    init() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyCoachCoreTests-\(UUID().uuidString)", isDirectory: true)
        let temporarySuiteName = "StudyCoachCoreTests.\(UUID().uuidString)"

        rootURL = temporaryRoot
        suiteName = temporarySuiteName
        defaults = UserDefaults(suiteName: temporarySuiteName)!
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    func makeStore() -> StudyCoachDocumentStore {
        StudyCoachDocumentStore(rootURL: rootURL, defaults: defaults)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
