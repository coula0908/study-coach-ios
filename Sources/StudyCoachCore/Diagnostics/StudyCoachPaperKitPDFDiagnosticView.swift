import SwiftUI

#if canImport(PaperKit)
import CryptoKit
import PDFKit
import PaperKit
import PencilKit
import QuartzCore
import UIKit
import UniformTypeIdentifiers
#endif

/// An isolated iPadOS 26 diagnostic that renders one PDF page as PaperKit
/// content and persists one `PaperMarkup` per document and page.
///
/// The production `StudyCoachRootView` and its PencilKit overlays are not used
/// or modified by this diagnostic.
public struct StudyCoachPaperKitPDFDiagnosticView: View {
    public init() {}

    @ViewBuilder
    public var body: some View {
#if canImport(PaperKit)
        if #available(iOS 26.0, *) {
            PaperKitPDFDiagnosticWorkspace()
        } else {
            PaperKitPDFUnavailableView(
                detail: "PaperKit PDF 진단에는 iPadOS 26 이상이 필요합니다."
            )
        }
#else
        PaperKitPDFUnavailableView(
            detail: "현재 Swift 도구체인에는 PaperKit 모듈이 없습니다."
        )
#endif
    }
}

private struct PaperKitPDFUnavailableView: View {
    let detail: String

    var body: some View {
        ContentUnavailableView(
            "PaperKit PDF unavailable",
            systemImage: "doc.badge.gearshape",
            description: Text(detail)
        )
    }
}

#if canImport(PaperKit)
@available(iOS 26.0, *)
@MainActor
private final class PaperKitPDFDiagnosticModel: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var documentID = ""
    @Published private(set) var documentName = "PDF"
    @Published var pageIndex = 0 {
        didSet {
            guard pageIndex != oldValue, !documentID.isEmpty else { return }
            UserDefaults.standard.set(
                pageIndex,
                forKey: PaperKitPDFDiagnosticStorage.lastPageKey(for: documentID)
            )
        }
    }
    @Published var errorMessage: String?

    init() {
        restoreLastDocument()
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    var currentPage: PDFPage? {
        document?.page(at: pageIndex)
    }

    func importPDF(from sourceURL: URL) {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            guard let pdfDocument = PDFDocument(data: data), pdfDocument.pageCount > 0 else {
                throw StudyCoachStorageError.invalidPDF
            }

            let identity = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            let directory = PaperKitPDFDiagnosticStorage.documentDirectory(for: identity)
            let storedPDFURL = directory.appendingPathComponent("document.pdf")
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: storedPDFURL.path) {
                try data.write(to: storedPDFURL, options: .atomic)
            }

            document = pdfDocument
            documentID = identity
            documentName = sourceURL.lastPathComponent
            pageIndex = min(
                UserDefaults.standard.integer(
                    forKey: PaperKitPDFDiagnosticStorage.lastPageKey(for: identity)
                ),
                max(pdfDocument.pageCount - 1, 0)
            )
            UserDefaults.standard.set(
                identity,
                forKey: PaperKitPDFDiagnosticStorage.lastDocumentKey
            )
            UserDefaults.standard.set(
                documentName,
                forKey: PaperKitPDFDiagnosticStorage.lastDocumentNameKey
            )
        } catch {
            errorMessage = "PDF를 열 수 없습니다. \(error.localizedDescription)"
        }
    }

    func goToPreviousPage() {
        pageIndex = max(pageIndex - 1, 0)
    }

    func goToNextPage() {
        pageIndex = min(pageIndex + 1, max(pageCount - 1, 0))
    }

    private func restoreLastDocument() {
        guard let identity = UserDefaults.standard.string(
            forKey: PaperKitPDFDiagnosticStorage.lastDocumentKey
        ) else { return }

        let url = PaperKitPDFDiagnosticStorage.documentDirectory(for: identity)
            .appendingPathComponent("document.pdf")
        guard let pdfDocument = PDFDocument(url: url), pdfDocument.pageCount > 0 else {
            return
        }

        document = pdfDocument
        documentID = identity
        documentName = UserDefaults.standard.string(
            forKey: PaperKitPDFDiagnosticStorage.lastDocumentNameKey
        ) ?? "PDF"
        pageIndex = min(
            UserDefaults.standard.integer(
                forKey: PaperKitPDFDiagnosticStorage.lastPageKey(for: identity)
            ),
            max(pdfDocument.pageCount - 1, 0)
        )
    }
}

@available(iOS 26.0, *)
private enum PaperKitPDFDiagnosticStorage {
    static let lastDocumentKey = "StudyCoachCore.PaperKitPDFDiagnostic.lastDocumentID"
    static let lastDocumentNameKey = "StudyCoachCore.PaperKitPDFDiagnostic.lastDocumentName"

    static var rootURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return support
            .appendingPathComponent("StudyCoachCore", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("PaperKitPDF", isDirectory: true)
    }

    static func documentDirectory(for documentID: String) -> URL {
        rootURL.appendingPathComponent(documentID, isDirectory: true)
    }

    static func markupURL(for documentID: String, pageIndex: Int) -> URL {
        documentDirectory(for: documentID)
            .appendingPathComponent("markups", isDirectory: true)
            .appendingPathComponent("\(pageIndex).paperkit")
    }

    static func lastPageKey(for documentID: String) -> String {
        "StudyCoachCore.PaperKitPDFDiagnostic.lastPage.\(documentID)"
    }
}

@available(iOS 26.0, *)
private struct PaperKitPDFDiagnosticWorkspace: View {
    @StateObject private var model = PaperKitPDFDiagnosticModel()
    @StateObject private var proxy = PaperKitPDFDiagnosticProxy()
    @State private var isShowingImporter = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let page = model.currentPage {
                PaperKitPDFPageContainer(
                    page: page,
                    documentID: model.documentID,
                    pageIndex: model.pageIndex,
                    proxy: proxy
                )
                .id("\(model.documentID)-\(model.pageIndex)")
            } else {
                ContentUnavailableView {
                    Label("PDF를 선택하세요", systemImage: "doc.text")
                } description: {
                    Text("PDF 페이지와 PaperKit 필기의 확대·좌표·저장을 독립적으로 확인합니다.")
                } actions: {
                    Button("PDF 열기") {
                        isShowingImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                model.importPDF(from: url)
            case .failure(let error):
                let cocoaError = error as NSError
                if cocoaError.code != NSUserCancelledError {
                    model.errorMessage = "파일 선택에 실패했습니다. \(error.localizedDescription)"
                }
            }
        }
        .alert(
            "PaperKit PDF 진단",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }

    private var toolbar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    isShowingImporter = true
                } label: {
                    Label(model.document == nil ? "PDF 열기" : model.documentName, systemImage: "folder")
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    proxy.save()
                    model.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(model.pageIndex <= 0)

                Text(model.document == nil ? "- / -" : "\(model.pageIndex + 1) / \(model.pageCount)")
                    .monospacedDigit()

                Button {
                    proxy.save()
                    model.goToNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(model.pageIndex + 1 >= model.pageCount)

                Button {
                    proxy.save()
                } label: {
                    Label("저장", systemImage: "square.and.arrow.down")
                }
                .disabled(model.document == nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(proxy.statusMessage)
                .font(.footnote)
                .foregroundStyle(proxy.statusIsError ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitPDFDiagnosticProxy: ObservableObject {
    @Published var statusMessage = "PDF를 열고 시스템 필기 도구로 페이지 위에 써 보세요."
    @Published var statusIsError = false
    weak var controller: PaperKitPDFPageViewController?

    func save() {
        controller?.saveMarkup()
    }
}

@available(iOS 26.0, *)
private struct PaperKitPDFPageContainer: UIViewControllerRepresentable {
    let page: PDFPage
    let documentID: String
    let pageIndex: Int
    @ObservedObject var proxy: PaperKitPDFDiagnosticProxy

    func makeUIViewController(context: Context) -> PaperKitPDFPageViewController {
        let controller = PaperKitPDFPageViewController(
            page: page,
            documentID: documentID,
            pageIndex: pageIndex,
            proxy: proxy
        )
        proxy.controller = controller
        return controller
    }

    func updateUIViewController(
        _ uiViewController: PaperKitPDFPageViewController,
        context: Context
    ) {
        proxy.controller = uiViewController
    }

    static func dismantleUIViewController(
        _ uiViewController: PaperKitPDFPageViewController,
        coordinator: Void
    ) {
        uiViewController.saveMarkup()
    }
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitPDFPageViewController: UIViewController {
    private let documentID: String
    private let pageIndex: Int
    private weak var proxy: PaperKitPDFDiagnosticProxy?
    private let paperController: PaperMarkupViewController
    private let toolPicker = PKToolPicker()
    private var backgroundObserver: NSObjectProtocol?

    init(
        page: PDFPage,
        documentID: String,
        pageIndex: Int,
        proxy: PaperKitPDFDiagnosticProxy
    ) {
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.proxy = proxy

        let pageBounds = page.bounds(for: .cropBox)
        let markupBounds = CGRect(origin: .zero, size: pageBounds.size)
        let markupURL = PaperKitPDFDiagnosticStorage.markupURL(
            for: documentID,
            pageIndex: pageIndex
        )
        let markup: PaperMarkup
        if let data = try? Data(contentsOf: markupURL),
           let restored = try? PaperMarkup(dataRepresentation: data) {
            markup = restored
        } else {
            markup = PaperMarkup(bounds: markupBounds)
        }

        let configuredPaperController = PaperMarkupViewController(
            markup: markup,
            supportedFeatureSet: .latest
        )
        configuredPaperController.contentView = PaperKitPDFPageBackgroundView(
            page: page,
            frame: markupBounds
        )
        paperController = configuredPaperController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground

        paperController.isEditable = true
        paperController.directTouchMode = .selection
        paperController.directTouchAutomaticallyDraws = false
        paperController.zoomRange = 0.25...8
        toolPicker.addObserver(paperController)
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible

        addChild(paperController)
        paperController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(paperController.view)
        NSLayoutConstraint.activate([
            paperController.view.topAnchor.constraint(equalTo: view.topAnchor),
            paperController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paperController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            paperController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        paperController.didMove(toParent: self)

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveMarkup()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible
        paperController.becomeFirstResponder()
        proxy?.statusMessage = "\(pageIndex + 1)페이지: 확대 후 필기 정렬과 페이지 이동 복원을 확인하세요."
        proxy?.statusIsError = false
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    func saveMarkup() {
        guard let markup = paperController.markup else { return }
        let url = PaperKitPDFDiagnosticStorage.markupURL(
            for: documentID,
            pageIndex: pageIndex
        )
        let proxy = proxy

        Task {
            do {
                let data = try await markup.dataRepresentation()
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                proxy?.statusMessage = "\(pageIndex + 1)페이지 PaperMarkup 저장 완료"
                proxy?.statusIsError = false
            } catch {
                proxy?.statusMessage = "\(pageIndex + 1)페이지 저장 실패: \(error.localizedDescription)"
                proxy?.statusIsError = true
            }
        }
    }
}

@available(iOS 26.0, *)
private final class PaperKitPDFPageBackgroundView: UIView {
    private let page: PDFPage

    override class var layerClass: AnyClass {
        CATiledLayer.self
    }

    init(page: PDFPage, frame: CGRect) {
        self.page = page
        super.init(frame: frame)
        backgroundColor = .white
        isOpaque = true
        contentScaleFactor = UIScreen.main.scale

        if let tiledLayer = layer as? CATiledLayer {
            tiledLayer.tileSize = CGSize(width: 512, height: 512)
            tiledLayer.levelsOfDetail = 4
            tiledLayer.levelsOfDetailBias = 4
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        let pageBounds = page.bounds(for: .cropBox)
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .cropBox, to: context)
        context.restoreGState()
    }
}
#endif
