import SwiftUI

#if canImport(PaperKit)
import CryptoKit
import PDFKit
import PaperKit
import PencilKit
import UIKit
import UniformTypeIdentifiers
#endif

/// An isolated iPadOS 26 diagnostic that renders one PDF page as PaperKit
/// content and persists one `PaperMarkup` per document and page.
///
/// PDFView is intentionally absent. PaperKit owns scrolling, zooming, tools,
/// and Pencil input. A complete base image prevents tile-shaped page loading;
/// visible-frame changes immediately request an atomic rerender from the
/// original PDF at the device's presentation resolution.
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
    static let lastDocumentKey = "StudyCoachCore.PaperKitPDFAdaptive.lastDocumentID"
    static let lastDocumentNameKey = "StudyCoachCore.PaperKitPDFAdaptive.lastDocumentName"

    static var rootURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return support
            .appendingPathComponent("StudyCoachCore", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("PaperKitPDFAdaptive", isDirectory: true)
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
        "StudyCoachCore.PaperKitPDFAdaptive.lastPage.\(documentID)"
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
    /// Matching the coordinate density of the physically accepted 0.1.4
    /// standalone canvas makes system tool widths useful on PDF-sized pages.
    private static let logicalPageScale: CGFloat = 2
    /// About one display frame at 30 Hz. This samples for viewport changes; it
    /// is not a post-gesture debounce and never delays a detected render.
    private static let viewportSampleNanoseconds: UInt64 = 33_000_000

    private let documentID: String
    private let pageIndex: Int
    private weak var proxy: PaperKitPDFDiagnosticProxy?
    private let paperController: PaperMarkupViewController
    private let backgroundView: PaperKitPDFPageBackgroundView
    private let toolPicker: PKToolPicker
    private var viewportMonitoringTask: Task<Void, Never>?
    private var lastObservedVisibleFrame = CGRect.null

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
        let markupBounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: pageBounds.width * Self.logicalPageScale,
                height: pageBounds.height * Self.logicalPageScale
            )
        )
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

        let configuredBackgroundView = PaperKitPDFPageBackgroundView(
            page: page,
            logicalScale: Self.logicalPageScale,
            frame: markupBounds
        )
        let configuredPaperController = PaperMarkupViewController(
            markup: markup,
            supportedFeatureSet: .latest
        )
        configuredPaperController.contentView = configuredBackgroundView
        backgroundView = configuredBackgroundView
        paperController = configuredPaperController

        let thinPen = PKToolPickerInkingItem(
            type: .pen,
            color: .label,
            width: 0.5,
            identifier: "com.studycoach.paperkit.thin-pen"
        )
        let thinHighlighter = PKToolPickerInkingItem(
            type: .marker,
            color: .systemYellow,
            width: 2,
            identifier: "com.studycoach.paperkit.thin-highlighter"
        )
        toolPicker = PKToolPicker(
            toolItems: [thinPen, thinHighlighter] + PKToolPicker().toolItems
        )
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
        toolPicker.showsDrawingPolicyControls = false
        toolPicker.stateAutosaveName = "StudyCoachCore.PaperKitPDFAdaptive.Tools"
        toolPicker.addObserver(paperController)
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible

        backgroundView.onStatusChange = { [weak self] message, isError in
            self?.proxy?.statusMessage = message
            self?.proxy?.statusIsError = isError
        }
        backgroundView.onBaseImageReady = { [weak self] in
            guard let self else { return }
            self.lastObservedVisibleFrame = .null
            self.sampleViewport()
        }
        backgroundView.prepareBaseImage()

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible
        paperController.becomeFirstResponder()
        startViewportMonitoring()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopViewportMonitoring()
    }

    @objc
    private func applicationDidEnterBackground() {
        saveMarkup()
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

    private func startViewportMonitoring() {
        guard viewportMonitoringTask == nil else { return }
        sampleViewport()

        viewportMonitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let self {
                    self.sampleViewport()
                } else {
                    return
                }
                try? await Task.sleep(nanoseconds: Self.viewportSampleNanoseconds)
            }
        }
    }

    private func stopViewportMonitoring() {
        viewportMonitoringTask?.cancel()
        viewportMonitoringTask = nil
    }

    private func sampleViewport() {
        let visibleFrame = paperController.contentVisibleFrame.standardized
            .intersection(backgroundView.bounds)
        guard visibleFrame.isUsableViewport else { return }

        guard !visibleFrame.isApproximatelyEqual(to: lastObservedVisibleFrame) else {
            return
        }
        lastObservedVisibleFrame = visibleFrame

        backgroundView.requestDetailImage(
            for: visibleFrame,
            viewportSize: paperController.view.bounds.size
        )
    }
}

@available(iOS 26.0, *)
private final class PaperKitPDFPageBackgroundView: UIView {
    private struct DetailRenderRequest {
        let generation: Int
        let rect: CGRect
        let pixelsPerLogicalPoint: CGFloat
    }

    private static let renderQueue = DispatchQueue(
        label: "com.studycoach.paperkit.pdf-rendering",
        qos: .userInitiated
    )
    private static let basePixelsPerPDFPoint: CGFloat = 4
    private static let detailOverscanRatio: CGFloat = 0.18
    private static let detailSupersampling: CGFloat = 1.2
    private static let maximumPixelDimension: CGFloat = 4_096
    private static let maximumPixelCount: CGFloat = 14_000_000

    var onStatusChange: ((String, Bool) -> Void)?
    var onBaseImageReady: (() -> Void)?

    private let logicalScale: CGFloat
    private let rasterizer: PaperKitPDFPageRasterizer
    private let baseImageView = UIImageView()
    private let detailImageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var detailRenderGeneration = 0
    private var detailRenderIsInFlight = false
    private var pendingDetailRequest: DetailRenderRequest?
    private var baseRenderStarted = false
    private var baseImageIsReady = false

    init(page: PDFPage, logicalScale: CGFloat, frame: CGRect) {
        self.logicalScale = logicalScale
        rasterizer = PaperKitPDFPageRasterizer(
            pageData: page.dataRepresentation ?? Data(),
            pageBounds: page.bounds(for: .cropBox),
            logicalScale: logicalScale
        )
        super.init(frame: frame)
        backgroundColor = .white
        isOpaque = true

        baseImageView.frame = bounds
        baseImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        baseImageView.backgroundColor = .white
        baseImageView.contentMode = .scaleToFill
        baseImageView.isOpaque = true
        addSubview(baseImageView)

        detailImageView.backgroundColor = .clear
        detailImageView.contentMode = .scaleToFill
        detailImageView.isHidden = true
        detailImageView.isUserInteractionEnabled = false
        addSubview(detailImageView)

        activityIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
        activityIndicator.autoresizingMask = [
            .flexibleLeftMargin,
            .flexibleRightMargin,
            .flexibleTopMargin,
            .flexibleBottomMargin,
        ]
        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func prepareBaseImage() {
        guard !baseRenderStarted else { return }
        baseRenderStarted = true
        activityIndicator.startAnimating()
        onStatusChange?("PDF 전체 페이지를 준비하는 중…", false)

        let rasterizer = rasterizer
        let pixelsPerLogicalPoint = Self.basePixelsPerPDFPoint / logicalScale
        let maximumPixelDimension = Self.maximumPixelDimension
        let maximumPixelCount = Self.maximumPixelCount
        Self.renderQueue.async { [weak self] in
            let image = rasterizer.render(
                logicalRect: rasterizer.logicalBounds,
                pixelsPerLogicalPoint: pixelsPerLogicalPoint,
                maximumPixelDimension: maximumPixelDimension,
                maximumPixelCount: maximumPixelCount
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.activityIndicator.stopAnimating()
                guard let image else {
                    self.onStatusChange?("PDF 페이지 이미지를 만들 수 없습니다.", true)
                    return
                }

                self.baseImageView.image = image
                self.baseImageIsReady = true
                self.onStatusChange?(
                    "전체 페이지 준비 완료 · 확대 영역은 즉시 고해상도로 갱신됩니다.",
                    false
                )
                self.onBaseImageReady?()
            }
        }
    }

    func requestDetailImage(for visibleFrame: CGRect, viewportSize: CGSize) {
        detailRenderGeneration += 1
        pendingDetailRequest = nil
        detailImageView.isHidden = true
        detailImageView.image = nil
        guard baseImageIsReady,
              visibleFrame.isUsableViewport,
              viewportSize.width > 0,
              viewportSize.height > 0 else { return }

        let horizontalPresentationScale = viewportSize.width / visibleFrame.width
        let verticalPresentationScale = viewportSize.height / visibleFrame.height
        let presentationScale = max(horizontalPresentationScale, verticalPresentationScale)
        let desiredPixelsPerLogicalPoint = presentationScale
            * UIScreen.main.scale
            * Self.detailSupersampling
        let basePixelsPerLogicalPoint = Self.basePixelsPerPDFPoint / logicalScale

        guard desiredPixelsPerLogicalPoint > basePixelsPerLogicalPoint * 1.1 else {
            onStatusChange?("기본 페이지 해상도로 선명하게 표시 중", false)
            return
        }

        let horizontalOverscan = visibleFrame.width * Self.detailOverscanRatio
        let verticalOverscan = visibleFrame.height * Self.detailOverscanRatio
        let detailRect = visibleFrame
            .insetBy(dx: -horizontalOverscan, dy: -verticalOverscan)
            .intersection(bounds)
        guard detailRect.isUsableViewport else { return }

        onStatusChange?("확대 영역을 원본 PDF에서 선명하게 만드는 중…", false)
        pendingDetailRequest = DetailRenderRequest(
            generation: detailRenderGeneration,
            rect: detailRect,
            pixelsPerLogicalPoint: desiredPixelsPerLogicalPoint
        )
        startNextDetailRenderIfNeeded()
    }

    private func startNextDetailRenderIfNeeded() {
        guard !detailRenderIsInFlight, let request = pendingDetailRequest else { return }
        pendingDetailRequest = nil
        detailRenderIsInFlight = true

        let rasterizer = rasterizer
        let maximumPixelDimension = Self.maximumPixelDimension
        let maximumPixelCount = Self.maximumPixelCount
        Self.renderQueue.async { [weak self] in
            let image = rasterizer.render(
                logicalRect: request.rect,
                pixelsPerLogicalPoint: request.pixelsPerLogicalPoint,
                maximumPixelDimension: maximumPixelDimension,
                maximumPixelCount: maximumPixelCount
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.detailRenderIsInFlight = false

                if request.generation == self.detailRenderGeneration {
                    if let image {
                        UIView.performWithoutAnimation {
                            self.detailImageView.frame = request.rect
                            self.detailImageView.image = image
                            self.detailImageView.isHidden = false
                        }
                        self.onStatusChange?("확대 영역 고해상도 표시 완료", false)
                    } else {
                        self.onStatusChange?(
                            "확대 영역 렌더링에 실패했습니다. 기본 페이지를 유지합니다.",
                            true
                        )
                    }
                }

                // A gesture can change the viewport many times while one render is
                // running. Only the newest pending request is retained and starts now.
                self.startNextDetailRenderIfNeeded()
            }
        }
    }
}

@available(iOS 26.0, *)
final class PaperKitPDFPageRasterizer: @unchecked Sendable {
    let logicalBounds: CGRect

    private let pageData: Data
    private let pageBounds: CGRect
    private let logicalScale: CGFloat

    init(pageData: Data, pageBounds: CGRect, logicalScale: CGFloat) {
        self.pageData = pageData
        self.pageBounds = pageBounds
        self.logicalScale = logicalScale
        logicalBounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: pageBounds.width * logicalScale,
                height: pageBounds.height * logicalScale
            )
        )
    }

    func render(
        logicalRect requestedRect: CGRect,
        pixelsPerLogicalPoint requestedPixelsPerLogicalPoint: CGFloat,
        maximumPixelDimension: CGFloat,
        maximumPixelCount: CGFloat
    ) -> UIImage? {
        let logicalRect = requestedRect.standardized.intersection(logicalBounds)
        guard logicalRect.isUsableViewport,
              requestedPixelsPerLogicalPoint.isFinite,
              requestedPixelsPerLogicalPoint > 0,
              let document = PDFDocument(data: pageData),
              let page = document.page(at: 0) else { return nil }

        let rawPixelSize = CGSize(
            width: logicalRect.width * requestedPixelsPerLogicalPoint,
            height: logicalRect.height * requestedPixelsPerLogicalPoint
        )
        let dimensionLimitScale = min(
            1,
            maximumPixelDimension / max(rawPixelSize.width, rawPixelSize.height)
        )
        let rawPixelCount = rawPixelSize.width * rawPixelSize.height
        let pixelCountLimitScale = min(
            1,
            sqrt(maximumPixelCount / max(rawPixelCount, 1))
        )
        let limitScale = min(dimensionLimitScale, pixelCountLimitScale)
        let pixelSize = CGSize(
            width: max(1, floor(rawPixelSize.width * limitScale)),
            height: max(1, floor(rawPixelSize.height * limitScale))
        )
        let horizontalScale = pixelSize.width / logicalRect.width
        let verticalScale = pixelSize.height / logicalRect.height

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return autoreleasepool {
            renderer.image { rendererContext in
                let context = rendererContext.cgContext
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: pixelSize))
                context.interpolationQuality = .high
                context.saveGState()

                // First map the requested logical PaperKit region to this
                // bitmap, then use the same top-left to PDF-space conversion
                // as the physically verified page diagnostic.
                context.scaleBy(x: horizontalScale, y: verticalScale)
                context.translateBy(x: -logicalRect.minX, y: -logicalRect.minY)
                context.translateBy(x: 0, y: logicalBounds.height)
                context.scaleBy(x: logicalScale, y: -logicalScale)
                context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
                page.draw(with: .cropBox, to: context)
                context.restoreGState()
            }
        }
    }
}

private extension CGRect {
    var isUsableViewport: Bool {
        !isNull && !isInfinite && width.isFinite && height.isFinite && width > 1 && height > 1
    }

    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.75) -> Bool {
        guard isUsableViewport, other.isUsableViewport else { return false }
        return abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
#endif
