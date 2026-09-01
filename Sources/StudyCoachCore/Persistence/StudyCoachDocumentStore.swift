import CryptoKit
import Foundation

struct StoredStudyDocument: Sendable {
    let id: String
    let url: URL
    let originalFilename: String
    let lastPageIndex: Int
}

enum StudyCoachStorageError: LocalizedError {
    case cannotCreateStorage
    case cannotReadPDF
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .cannotCreateStorage:
            "앱의 저장 폴더를 만들 수 없습니다."
        case .cannotReadPDF:
            "선택한 PDF를 읽을 수 없습니다."
        case .invalidPDF:
            "선택한 파일이 유효한 PDF가 아닙니다."
        }
    }
}

actor StudyCoachDocumentStore {
    static let shared = StudyCoachDocumentStore()

    private struct Metadata: Codable {
        var schemaVersion: Int
        var documentID: String
        var originalFilename: String
        var importedAt: Date
        var pageCount: Int?
        var lastPageIndex: Int?
    }

    private let fileManager: FileManager
    private let rootURL: URL
    private let defaults: UserDefaults
    private let lastDocumentKey = "StudyCoachCore.lastDocumentID"

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults

        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.rootURL = supportURL
            .appendingPathComponent("StudyCoachCore", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }

    init(rootURL: URL, fileManager: FileManager = .default, defaults: UserDefaults) {
        self.fileManager = fileManager
        self.defaults = defaults
        self.rootURL = rootURL
    }

    func importPDF(from sourceURL: URL) throws -> StoredStudyDocument {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw StudyCoachStorageError.cannotReadPDF
        }

        let documentID = try sha256(of: sourceURL)
        let documentDirectory = directory(for: documentID)
        let storedPDFURL = documentDirectory.appendingPathComponent("document.pdf")
        let drawingsURL = documentDirectory.appendingPathComponent("drawings", isDirectory: true)
        var restoredLastPageIndex = 0

        do {
            try fileManager.createDirectory(at: drawingsURL, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: storedPDFURL.path) {
                try fileManager.copyItem(at: sourceURL, to: storedPDFURL)
            }

            let previousMetadata = readMetadata(for: documentID)
            let metadata = Metadata(
                schemaVersion: 1,
                documentID: documentID,
                originalFilename: sourceURL.lastPathComponent,
                importedAt: previousMetadata?.importedAt ?? Date(),
                pageCount: previousMetadata?.pageCount,
                lastPageIndex: previousMetadata?.lastPageIndex
            )
            restoredLastPageIndex = metadata.lastPageIndex ?? 0
            try writeMetadata(metadata, for: documentID)
            defaults.set(documentID, forKey: lastDocumentKey)
        } catch {
            throw StudyCoachStorageError.cannotCreateStorage
        }

        return StoredStudyDocument(
            id: documentID,
            url: storedPDFURL,
            originalFilename: sourceURL.lastPathComponent,
            lastPageIndex: restoredLastPageIndex
        )
    }

    func lastDocument() -> StoredStudyDocument? {
        guard let documentID = defaults.string(forKey: lastDocumentKey) else { return nil }
        let storedPDFURL = directory(for: documentID).appendingPathComponent("document.pdf")
        guard fileManager.fileExists(atPath: storedPDFURL.path) else { return nil }

        let metadata = readMetadata(for: documentID)
        return StoredStudyDocument(
            id: documentID,
            url: storedPDFURL,
            originalFilename: metadata?.originalFilename ?? "PDF",
            lastPageIndex: metadata?.lastPageIndex ?? 0
        )
    }

    func clearLastDocumentIfMissing(_ documentID: String) {
        guard defaults.string(forKey: lastDocumentKey) == documentID else { return }
        defaults.removeObject(forKey: lastDocumentKey)
    }

    func updatePageCount(_ pageCount: Int, for documentID: String) {
        guard var metadata = readMetadata(for: documentID) else { return }
        metadata.pageCount = pageCount
        try? writeMetadata(metadata, for: documentID)
    }

    func updateLastPageIndex(_ pageIndex: Int, for documentID: String) {
        guard var metadata = readMetadata(for: documentID) else { return }
        metadata.lastPageIndex = pageIndex
        try? writeMetadata(metadata, for: documentID)
    }

    func drawingData(for documentID: String, pageIndex: Int) -> Data? {
        try? Data(contentsOf: drawingURL(for: documentID, pageIndex: pageIndex))
    }

    func saveDrawingData(_ data: Data, for documentID: String, pageIndex: Int) throws {
        let drawingsURL = directory(for: documentID).appendingPathComponent("drawings", isDirectory: true)
        try fileManager.createDirectory(at: drawingsURL, withIntermediateDirectories: true)
        try data.write(to: drawingURL(for: documentID, pageIndex: pageIndex), options: .atomic)
    }

    private func directory(for documentID: String) -> URL {
        rootURL.appendingPathComponent(documentID, isDirectory: true)
    }

    private func drawingURL(for documentID: String, pageIndex: Int) -> URL {
        directory(for: documentID)
            .appendingPathComponent("drawings", isDirectory: true)
            .appendingPathComponent("\(pageIndex).drawing")
    }

    private func metadataURL(for documentID: String) -> URL {
        directory(for: documentID).appendingPathComponent("metadata.json")
    }

    private func readMetadata(for documentID: String) -> Metadata? {
        guard let data = try? Data(contentsOf: metadataURL(for: documentID)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Metadata.self, from: data)
    }

    private func writeMetadata(_ metadata: Metadata, for documentID: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL(for: documentID), options: .atomic)
    }

    private func sha256(of url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw StudyCoachStorageError.cannotReadPDF
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
