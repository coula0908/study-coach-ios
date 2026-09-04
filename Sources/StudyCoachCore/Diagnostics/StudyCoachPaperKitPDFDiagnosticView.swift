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
/// completed high-resolution PDF tiles remain anchored to page coordinates
/// during fixed-scale pan, while transient pinch scales do not render.
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
    /// Used only while UIKit reports that inertial scrolling or zoom bouncing
    /// is still active. There is no permanent viewport polling task.
    private static let motionCheckNanoseconds: UInt64 = 16_000_000

    private let documentID: String
    private let pageIndex: Int
    private weak var proxy: PaperKitPDFDiagnosticProxy?
    private let paperController: PaperMarkupViewController
    private let backgroundView: PaperKitPDFPageBackgroundView
    private let toolPicker: PKToolPicker
    private var navigationCompletionTask: Task<Void, Never>?
    private var lastSubmittedVisibleFrame = CGRect.null
    private var lastViewportSize = CGSize.zero
    private var observedNavigationRecognizers: [UIGestureRecognizer] = []
    private var activeNavigationRecognizerIDs: Set<ObjectIdentifier> = []
    private var activePinchRecognizerIDs: Set<ObjectIdentifier> = []

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
            self.lastSubmittedVisibleFrame = .null
            self.updateCurrentViewportTiles()
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
        installNavigationObservationIfNeeded()
        updateCurrentViewportTiles()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installNavigationObservationIfNeeded()

        let viewportSize = paperController.view.bounds.size
        guard viewportSize != lastViewportSize else { return }
        lastViewportSize = viewportSize
        lastSubmittedVisibleFrame = .null
        updateCurrentViewportTiles()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationCompletionTask?.cancel()
        navigationCompletionTask = nil
        removeNavigationObservation()
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

    private func updateCurrentViewportTiles() {
        guard !isPinchActive else { return }

        let visibleFrame = paperController.contentVisibleFrame.standardized
            .intersection(backgroundView.bounds)
        guard visibleFrame.isUsableViewport else { return }

        guard !visibleFrame.isApproximatelyEqual(to: lastSubmittedVisibleFrame) else {
            return
        }
        lastSubmittedVisibleFrame = visibleFrame

        backgroundView.updateDetailTiles(
            for: visibleFrame,
            viewportSize: paperController.view.bounds.size
        )
    }

    private func installNavigationObservationIfNeeded() {
        let installedIDs = Set(observedNavigationRecognizers.map(ObjectIdentifier.init))
        let discoveredRecognizers = paperController.view
            .descendantNavigationGestureRecognizers

        for recognizer in discoveredRecognizers
            where !installedIDs.contains(ObjectIdentifier(recognizer)) {
            recognizer.addTarget(
                self,
                action: #selector(observedNavigationGestureChanged(_:))
            )
            observedNavigationRecognizers.append(recognizer)
        }
    }

    private func removeNavigationObservation() {
        for recognizer in observedNavigationRecognizers {
            recognizer.removeTarget(
                self,
                action: #selector(observedNavigationGestureChanged(_:))
            )
        }
        observedNavigationRecognizers.removeAll()
        activeNavigationRecognizerIDs.removeAll()
        activePinchRecognizerIDs.removeAll()
    }

    @objc
    private func observedNavigationGestureChanged(_ recognizer: UIGestureRecognizer) {
        let recognizerID = ObjectIdentifier(recognizer)
        switch recognizer.state {
        case .began, .changed:
            navigationCompletionTask?.cancel()
            navigationCompletionTask = nil
            let becameActive = activeNavigationRecognizerIDs.insert(recognizerID).inserted

            if recognizer is UIPinchGestureRecognizer {
                let pinchBecameActive = activePinchRecognizerIDs
                    .insert(recognizerID)
                    .inserted
                if pinchBecameActive {
                    // Keep completed tiles visible and scaled by PaperKit, but
                    // cancel requests for transient pinch scales.
                    backgroundView.suspendDetailTileRequests()
                }
                lastSubmittedVisibleFrame = .null
            } else if recognizer is UIPanGestureRecognizer,
                      !isPinchActive {
                // At a fixed scale, keep sharp tiles and request only missing
                // coverage as the page moves.
                if becameActive {
                    lastSubmittedVisibleFrame = .null
                }
                updateCurrentViewportTiles()
            }
        case .ended, .cancelled:
            activeNavigationRecognizerIDs.remove(recognizerID)
            activePinchRecognizerIDs.remove(recognizerID)
            if activeNavigationRecognizerIDs.isEmpty {
                renderAfterNavigationSettles(in: recognizer.owningScrollView)
            }
        case .failed:
            activeNavigationRecognizerIDs.remove(recognizerID)
            activePinchRecognizerIDs.remove(recognizerID)
        case .possible:
            break
        @unknown default:
            activeNavigationRecognizerIDs.remove(recognizerID)
            activePinchRecognizerIDs.remove(recognizerID)
        }
    }

    private var isPinchActive: Bool {
        if !activePinchRecognizerIDs.isEmpty {
            return true
        }
        if observedNavigationRecognizers.contains(where: { recognizer in
            guard recognizer is UIPinchGestureRecognizer else { return false }
            return recognizer.state == .began || recognizer.state == .changed
        }) {
            return true
        }
        return observedNavigationRecognizers.contains { recognizer in
            guard let scrollView = recognizer.owningScrollView else { return false }
            return scrollView.isZooming || scrollView.isZoomBouncing
        }
    }

    private func renderAfterNavigationSettles(in scrollView: UIScrollView?) {
        navigationCompletionTask?.cancel()
        navigationCompletionTask = Task { @MainActor [weak self, weak scrollView] in
            // Let UIScrollView enter deceleration or zoom-bounce state after
            // the recognizer's ended callback before checking motion.
            await Task.yield()

            while !Task.isCancelled {
                guard let self else { return }
                guard self.activeNavigationRecognizerIDs.isEmpty else { return }

                let isScaleStillChanging = scrollView.map {
                    $0.isZooming || $0.isZoomBouncing
                } ?? false
                let isTranslationStillMoving = scrollView.map {
                    $0.isTracking || $0.isDragging || $0.isDecelerating
                } ?? false

                // Deceleration changes only position, so cached tiles stay
                // valid and missing coverage can be requested as it appears.
                if !isScaleStillChanging {
                    self.updateCurrentViewportTiles()
                }

                let isStillMoving = isScaleStillChanging || isTranslationStillMoving
                guard isStillMoving else {
                    self.navigationCompletionTask = nil
                    self.lastSubmittedVisibleFrame = .null
                    self.updateCurrentViewportTiles()
                    return
                }

                try? await Task.sleep(nanoseconds: Self.motionCheckNanoseconds)
            }
        }
    }
}

@available(iOS 26.0, *)
private final class PaperKitPDFPageBackgroundView: UIView {
    private struct DetailRenderRequest {
        let generation: Int
        let tile: PaperKitPDFDetailTilePlan.Tile
    }

    private struct CachedTile {
        let imageView: UIImageView
        var lastAccess: Int
    }

    private static let renderQueue = DispatchQueue(
        label: "com.studycoach.paperkit.pdf-rendering",
        qos: .userInitiated
    )
    private static let basePixelsPerPDFPoint: CGFloat = 4
    private static let detailSupersampling: CGFloat = 1.2
    private static let detailTilePixelDimension: CGFloat = 512
    private static let detailPrefetchTileRings = 2
    private static let maximumCachedDetailTiles = 96
    private static let maximumPixelDimension: CGFloat = 4_096
    private static let maximumPixelCount: CGFloat = 14_000_000

    var onStatusChange: ((String, Bool) -> Void)?
    var onBaseImageReady: (() -> Void)?

    private let logicalScale: CGFloat
    private let rasterizer: PaperKitPDFPageRasterizer
    private let baseImageView = UIImageView()
    private let detailTileContainerView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var detailRenderGeneration = 0
    private var activeDetailRequest: DetailRenderRequest?
    private var pendingDetailRequests: [DetailRenderRequest] = []
    private var cachedDetailTiles: [PaperKitPDFDetailTileKey: CachedTile] = [:]
    private var currentWantedTileKeys: Set<PaperKitPDFDetailTileKey> = []
    private var currentVisibleTileKeys: Set<PaperKitPDFDetailTileKey> = []
    private var targetDetailLevel: Int?
    private var targetDetailLevelIsPublished = false
    private var tileAccessCounter = 0
    private var hasReportedTileFailure = false
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

        detailTileContainerView.frame = bounds
        detailTileContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        detailTileContainerView.backgroundColor = .clear
        detailTileContainerView.isUserInteractionEnabled = false
        detailTileContainerView.clipsToBounds = true
        addSubview(detailTileContainerView)

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
                    "전체 페이지 준비 완료 · 확대와 이동 선명도를 자동으로 유지합니다.",
                    false
                )
                self.onBaseImageReady?()
            }
        }
    }

    func updateDetailTiles(for visibleFrame: CGRect, viewportSize: CGSize) {
        guard baseImageIsReady,
              visibleFrame.isUsableViewport,
              viewportSize.width > 0,
              viewportSize.height > 0 else { return }

        let basePixelsPerLogicalPoint = Self.basePixelsPerPDFPoint / logicalScale
        guard let plan = PaperKitPDFDetailTilePlanner.plan(
            logicalBounds: bounds,
            visibleFrame: visibleFrame,
            viewportSize: viewportSize,
            screenScale: UIScreen.main.scale,
            basePixelsPerLogicalPoint: basePixelsPerLogicalPoint,
            supersampling: Self.detailSupersampling,
            tilePixelDimension: Self.detailTilePixelDimension,
            prefetchTileRings: Self.detailPrefetchTileRings,
            maximumTileCount: Self.maximumCachedDetailTiles
        ) else {
            showBaseResolutionOnly()
            return
        }

        if targetDetailLevel != plan.level {
            detailRenderGeneration += 1
            targetDetailLevel = plan.level
            targetDetailLevelIsPublished = false
            pendingDetailRequests.removeAll()
            hasReportedTileFailure = false
            for (key, cachedTile) in cachedDetailTiles where key.level == plan.level {
                cachedTile.imageView.isHidden = true
            }
        }

        currentWantedTileKeys = Set(plan.tiles.map(\.key))
        currentVisibleTileKeys = Set(
            plan.tiles.lazy.filter(\.isVisible).map(\.key)
        )
        tileAccessCounter += 1
        let access = tileAccessCounter
        for key in currentWantedTileKeys {
            guard var cachedTile = cachedDetailTiles[key] else { continue }
            cachedTile.lastAccess = access
            cachedDetailTiles[key] = cachedTile
            // Cached tiles from a level revisited after zooming must sit above
            // obsolete levels, while still leaving gaps backed by the base page.
            detailTileContainerView.bringSubviewToFront(cachedTile.imageView)
        }

        let activeKey: PaperKitPDFDetailTileKey?
        if activeDetailRequest?.generation == detailRenderGeneration {
            activeKey = activeDetailRequest?.tile.key
        } else {
            activeKey = nil
        }

        pendingDetailRequests = plan.tiles.compactMap { tile in
            guard cachedDetailTiles[tile.key] == nil,
                  tile.key != activeKey else { return nil }
            return DetailRenderRequest(
                generation: detailRenderGeneration,
                tile: tile
            )
        }

        publishTargetLevelIfReady()
        evictCachedTilesIfNeeded()
        startNextDetailRenderIfNeeded()
    }

    /// Stop work for transient pinch scales without removing completed tiles.
    /// PaperKit keeps transforming those stable tiles until the final scale is
    /// known and a new level can be selected.
    func suspendDetailTileRequests() {
        detailRenderGeneration += 1
        targetDetailLevel = nil
        targetDetailLevelIsPublished = false
        pendingDetailRequests.removeAll()
        currentWantedTileKeys.removeAll()
        currentVisibleTileKeys.removeAll()
    }

    private func showBaseResolutionOnly() {
        detailRenderGeneration += 1
        targetDetailLevel = nil
        targetDetailLevelIsPublished = false
        pendingDetailRequests.removeAll()
        currentWantedTileKeys.removeAll()
        currentVisibleTileKeys.removeAll()
        removeAllCachedDetailTiles()
    }

    private func startNextDetailRenderIfNeeded() {
        guard activeDetailRequest == nil,
              !pendingDetailRequests.isEmpty else { return }
        let request = pendingDetailRequests.removeFirst()
        activeDetailRequest = request

        let rasterizer = rasterizer
        let tilePixelDimension = Self.detailTilePixelDimension
        Self.renderQueue.async { [weak self] in
            let image = rasterizer.render(
                logicalRect: request.tile.rect,
                pixelsPerLogicalPoint: request.tile.pixelsPerLogicalPoint,
                maximumPixelDimension: tilePixelDimension,
                maximumPixelCount: tilePixelDimension * tilePixelDimension
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeDetailRequest = nil

                if request.generation == self.detailRenderGeneration,
                   request.tile.key.level == self.targetDetailLevel {
                    if let image {
                        self.install(image, for: request.tile)
                    } else if !self.hasReportedTileFailure {
                        self.hasReportedTileFailure = true
                        self.onStatusChange?(
                            "일부 고해상도 영역을 만들지 못해 기본 페이지를 유지합니다.",
                            true
                        )
                    }
                }

                self.publishTargetLevelIfReady()
                self.evictCachedTilesIfNeeded()
                self.startNextDetailRenderIfNeeded()
            }
        }
    }

    private func install(_ image: UIImage, for tile: PaperKitPDFDetailTilePlan.Tile) {
        guard cachedDetailTiles[tile.key] == nil else { return }

        let imageView = UIImageView(frame: tile.rect)
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleToFill
        imageView.isOpaque = true
        imageView.isUserInteractionEnabled = false
        imageView.layer.magnificationFilter = .linear
        imageView.layer.minificationFilter = .linear
        imageView.image = image
        imageView.isHidden = !targetDetailLevelIsPublished

        tileAccessCounter += 1
        cachedDetailTiles[tile.key] = CachedTile(
            imageView: imageView,
            lastAccess: tileAccessCounter
        )
        UIView.performWithoutAnimation {
            detailTileContainerView.addSubview(imageView)
        }
    }

    private func publishTargetLevelIfReady() {
        guard !targetDetailLevelIsPublished,
              let targetDetailLevel,
              !currentVisibleTileKeys.isEmpty,
              currentVisibleTileKeys.allSatisfy({ cachedDetailTiles[$0] != nil }) else {
            return
        }

        targetDetailLevelIsPublished = true
        UIView.performWithoutAnimation {
            for (key, cachedTile) in cachedDetailTiles
                where key.level == targetDetailLevel {
                cachedTile.imageView.isHidden = false
                detailTileContainerView.bringSubviewToFront(cachedTile.imageView)
            }
        }
    }

    private func evictCachedTilesIfNeeded() {
        while cachedDetailTiles.count > Self.maximumCachedDetailTiles {
            let evictionCandidate = cachedDetailTiles
                .filter { !currentWantedTileKeys.contains($0.key) }
                .min { $0.value.lastAccess < $1.value.lastAccess }
            guard let evictionCandidate else { return }
            evictionCandidate.value.imageView.removeFromSuperview()
            cachedDetailTiles.removeValue(forKey: evictionCandidate.key)
        }
    }

    private func removeAllCachedDetailTiles() {
        for cachedTile in cachedDetailTiles.values {
            cachedTile.imageView.removeFromSuperview()
        }
        cachedDetailTiles.removeAll()
    }
}

@available(iOS 26.0, *)
struct PaperKitPDFDetailTileKey: Hashable {
    let level: Int
    let column: Int
    let row: Int
}

@available(iOS 26.0, *)
struct PaperKitPDFDetailTilePlan {
    struct Tile {
        let key: PaperKitPDFDetailTileKey
        let rect: CGRect
        let pixelsPerLogicalPoint: CGFloat
        let isVisible: Bool
        let distanceFromViewportCenterSquared: CGFloat
    }

    let level: Int
    let pixelsPerLogicalPoint: CGFloat
    let tiles: [Tile]
}

@available(iOS 26.0, *)
enum PaperKitPDFDetailTilePlanner {
    /// Build a stable, discrete level-of-detail grid. A half-octave step keeps
    /// pixel density within about 1.414× of the requested density while making
    /// nearby zoom results share the same reusable tile coordinates.
    static func plan(
        logicalBounds: CGRect,
        visibleFrame: CGRect,
        viewportSize: CGSize,
        screenScale: CGFloat,
        basePixelsPerLogicalPoint: CGFloat,
        supersampling: CGFloat,
        tilePixelDimension: CGFloat,
        prefetchTileRings: Int,
        maximumTileCount: Int
    ) -> PaperKitPDFDetailTilePlan? {
        let bounds = logicalBounds.standardized
        let visibleFrame = visibleFrame.standardized.intersection(bounds)
        guard bounds.isUsableViewport,
              visibleFrame.isUsableViewport,
              viewportSize.width > 0,
              viewportSize.height > 0,
              screenScale > 0,
              basePixelsPerLogicalPoint > 0,
              supersampling > 0,
              tilePixelDimension > 0,
              maximumTileCount > 0 else { return nil }

        let horizontalPresentationScale = viewportSize.width / visibleFrame.width
        let verticalPresentationScale = viewportSize.height / visibleFrame.height
        let presentationScale = max(horizontalPresentationScale, verticalPresentationScale)
        let desiredPixelsPerLogicalPoint = presentationScale
            * screenScale
            * supersampling

        guard desiredPixelsPerLogicalPoint > basePixelsPerLogicalPoint * 1.1 else {
            return nil
        }

        let levelStep = sqrt(2.0)
        let densityRatio = desiredPixelsPerLogicalPoint / basePixelsPerLogicalPoint
        let level = max(
            1,
            Int(ceil(log(Double(densityRatio)) / log(levelStep)))
        )
        let pixelsPerLogicalPoint = basePixelsPerLogicalPoint
            * CGFloat(pow(levelStep, Double(level)))
        let tileLogicalDimension = tilePixelDimension / pixelsPerLogicalPoint
        guard tileLogicalDimension.isFinite, tileLogicalDimension > 0 else { return nil }

        let prefetchDistance = tileLogicalDimension * CGFloat(max(0, prefetchTileRings))
        let coverage = visibleFrame
            .insetBy(dx: -prefetchDistance, dy: -prefetchDistance)
            .intersection(bounds)
        guard coverage.isUsableViewport else { return nil }

        let minimumColumn = max(0, Int(floor(coverage.minX / tileLogicalDimension)))
        let maximumColumn = max(
            minimumColumn,
            Int(ceil(coverage.maxX / tileLogicalDimension)) - 1
        )
        let minimumRow = max(0, Int(floor(coverage.minY / tileLogicalDimension)))
        let maximumRow = max(
            minimumRow,
            Int(ceil(coverage.maxY / tileLogicalDimension)) - 1
        )
        let viewportCenter = CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)

        var tiles: [PaperKitPDFDetailTilePlan.Tile] = []
        for row in minimumRow...maximumRow {
            for column in minimumColumn...maximumColumn {
                let rawRect = CGRect(
                    x: CGFloat(column) * tileLogicalDimension,
                    y: CGFloat(row) * tileLogicalDimension,
                    width: tileLogicalDimension,
                    height: tileLogicalDimension
                )
                let rect = rawRect.intersection(bounds)
                guard rect.isUsableViewport else { continue }

                let horizontalDistance = rect.midX - viewportCenter.x
                let verticalDistance = rect.midY - viewportCenter.y
                tiles.append(
                    PaperKitPDFDetailTilePlan.Tile(
                        key: PaperKitPDFDetailTileKey(
                            level: level,
                            column: column,
                            row: row
                        ),
                        rect: rect,
                        pixelsPerLogicalPoint: pixelsPerLogicalPoint,
                        isVisible: rect.intersects(visibleFrame),
                        distanceFromViewportCenterSquared:
                            horizontalDistance * horizontalDistance
                            + verticalDistance * verticalDistance
                    )
                )
            }
        }

        tiles.sort { lhs, rhs in
            if lhs.isVisible != rhs.isVisible {
                return lhs.isVisible
            }
            if lhs.distanceFromViewportCenterSquared
                != rhs.distanceFromViewportCenterSquared {
                return lhs.distanceFromViewportCenterSquared
                    < rhs.distanceFromViewportCenterSquared
            }
            if lhs.key.row != rhs.key.row {
                return lhs.key.row < rhs.key.row
            }
            return lhs.key.column < rhs.key.column
        }

        if tiles.count > maximumTileCount {
            tiles = Array(tiles.prefix(maximumTileCount))
        }

        return PaperKitPDFDetailTilePlan(
            level: level,
            pixelsPerLogicalPoint: pixelsPerLogicalPoint,
            tiles: tiles
        )
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

private extension UIView {
    var descendantNavigationGestureRecognizers: [UIGestureRecognizer] {
        let localRecognizers = gestureRecognizers?.filter {
            $0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer
        } ?? []
        return localRecognizers
            + subviews.flatMap(\.descendantNavigationGestureRecognizers)
    }
}

private extension UIGestureRecognizer {
    var owningScrollView: UIScrollView? {
        var candidate = view
        while let currentView = candidate {
            if let scrollView = currentView as? UIScrollView {
                return scrollView
            }
            candidate = currentView.superview
        }
        return nil
    }
}
#endif
