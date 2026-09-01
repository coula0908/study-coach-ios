import Foundation
import PDFKit

@MainActor
final class StudyCoachSessionModel: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var documentID: String?
    @Published private(set) var documentName: String?
    @Published private(set) var isLoading = false
    @Published var currentPageIndex = 0 {
        didSet {
            guard currentPageIndex != oldValue, let documentID else { return }
            let pageIndex = currentPageIndex
            Task {
                await store.updateLastPageIndex(pageIndex, for: documentID)
            }
        }
    }
    @Published var errorMessage: String?

    let store: StudyCoachDocumentStore
    private var attemptedRestore = false

    init(store: StudyCoachDocumentStore = .shared) {
        self.store = store
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    func importDocument(from sourceURL: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storedDocument = try await store.importPDF(from: sourceURL)
            try await load(storedDocument)
        } catch {
            errorMessage = "PDF를 열 수 없습니다. \(error.localizedDescription)"
        }
    }

    func restoreLastDocumentIfAvailable() async {
        guard !attemptedRestore else { return }
        attemptedRestore = true

        guard let storedDocument = await store.lastDocument() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await load(storedDocument)
        } catch {
            await store.clearLastDocumentIfMissing(storedDocument.id)
            errorMessage = "마지막 PDF를 복원하지 못했습니다. 다시 선택해 주세요."
        }
    }

    func closeDocument() {
        document = nil
        documentID = nil
        documentName = nil
        currentPageIndex = 0
    }

    private func load(_ storedDocument: StoredStudyDocument) async throws {
        guard let pdfDocument = PDFDocument(url: storedDocument.url) else {
            throw StudyCoachStorageError.invalidPDF
        }

        document = pdfDocument
        documentID = storedDocument.id
        documentName = storedDocument.originalFilename
        currentPageIndex = min(
            max(storedDocument.lastPageIndex, 0),
            max(pdfDocument.pageCount - 1, 0)
        )
        await store.updatePageCount(pdfDocument.pageCount, for: storedDocument.id)
    }
}
