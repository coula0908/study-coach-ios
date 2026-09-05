#if canImport(PaperKit)
import Foundation
import PaperKit
import PDFKit
import SwiftUI
import UIKit

/// Serialize writes for each destination so an older slow snapshot cannot
/// overwrite a newer page. A new controller for that page uses the same queue.
@available(iOS 26.0, *)
@MainActor
enum PaperKitOrderedSave {
    private static var pending: [URL: Task<Void, Error>] = [:]

    static func enqueue(_ markup: PaperMarkup, to url: URL) -> Task<Void, Error> {
        let previous = pending[url]
        let task = Task { @MainActor in
            _ = await previous?.result
            let data = try await markup.dataRepresentation()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        }
        pending[url] = task
        return task
    }

    static func flush() async throws {
        let tasks = Array(pending.values)
        for task in tasks { try await task.value }
    }
}

@available(iOS 26.0, *)
@MainActor
enum PaperKitAnnotatedExport {
    static func make(document: PDFDocument, documentID: String, name: String) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyCoach-Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let output = directory.appendingPathComponent("\(stem)-필기포함.pdf")
        guard let consumer = CGDataConsumer(url: output as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let source = page.bounds(for: .cropBox)
            let size = source.size
            let bounds = CGRect(origin: .zero, size: size)
            context.beginPDFPage([kCGPDFContextMediaBox as String: NSData(
                bytes: [bounds], length: MemoryLayout<CGRect>.size
            )] as CFDictionary)
            context.saveGState()
            context.setFillColor(UIColor.white.cgColor)
            context.fill(bounds)
            context.translateBy(x: -source.minX, y: -source.minY)
            page.draw(with: .cropBox, to: context)
            context.restoreGState()
            let url = PaperKitPDFDiagnosticStorage.markupURL(for: documentID, pageIndex: index)
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let markup = try PaperMarkup(dataRepresentation: data)
                context.saveGState()
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
                await markup.draw(in: context, frame: bounds,
                                  options: RenderingOptions(darkUserInterfaceStyle: false))
                context.restoreGState()
            }
            context.endPDFPage()
            await Task.yield()
        }
        context.closePDF()
        return output
    }
}

@available(iOS 26.0, *)
struct PaperKitShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
