import SwiftUI

#if canImport(PaperKit)
import CryptoKit
import PDFKit
import PaperKit
import PencilKit
import Observation
@preconcurrency import Photos
import PhotosUI
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
private struct PaperKitPDFDocumentTab: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitPDFDiagnosticModel: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var documentID = ""
    @Published private(set) var documentName = "PDF"
    @Published private(set) var openDocuments: [PaperKitPDFDocumentTab] = []
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
            let tab = PaperKitPDFDocumentTab(id: identity, name: documentName)
            openDocuments.removeAll { $0.id == identity }
            openDocuments.append(tab)
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
            persistOpenDocuments()
        } catch {
            errorMessage = "PDF를 열 수 없습니다. \(error.localizedDescription)"
        }
    }

    func selectDocument(_ identity: String) {
        guard identity != documentID,
              let tab = openDocuments.first(where: { $0.id == identity }) else { return }
        let url = PaperKitPDFDiagnosticStorage.documentDirectory(for: identity)
            .appendingPathComponent("document.pdf")
        guard let pdfDocument = PDFDocument(url: url), pdfDocument.pageCount > 0 else {
            openDocuments.removeAll { $0.id == identity }
            persistOpenDocuments()
            errorMessage = "저장된 PDF를 다시 열 수 없습니다."
            return
        }

        document = pdfDocument
        documentID = identity
        documentName = tab.name
        pageIndex = min(
            UserDefaults.standard.integer(
                forKey: PaperKitPDFDiagnosticStorage.lastPageKey(for: identity)
            ),
            max(pdfDocument.pageCount - 1, 0)
        )
        UserDefaults.standard.set(identity, forKey: PaperKitPDFDiagnosticStorage.lastDocumentKey)
        UserDefaults.standard.set(
            documentName,
            forKey: PaperKitPDFDiagnosticStorage.lastDocumentNameKey
        )
    }

    func goToPreviousPage() {
        pageIndex = max(pageIndex - 1, 0)
    }

    func goToNextPage() {
        pageIndex = min(pageIndex + 1, max(pageCount - 1, 0))
    }

    private func restoreLastDocument() {
        restoreOpenDocuments()
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
        if !openDocuments.contains(where: { $0.id == identity }) {
            openDocuments.append(PaperKitPDFDocumentTab(id: identity, name: documentName))
            persistOpenDocuments()
        }
        pageIndex = min(
            UserDefaults.standard.integer(
                forKey: PaperKitPDFDiagnosticStorage.lastPageKey(for: identity)
            ),
            max(pdfDocument.pageCount - 1, 0)
        )
    }

    private func restoreOpenDocuments() {
        guard let data = UserDefaults.standard.data(
            forKey: PaperKitPDFDiagnosticStorage.openDocumentsKey
        ), let tabs = try? JSONDecoder().decode([PaperKitPDFDocumentTab].self, from: data)
        else { return }

        openDocuments = tabs.filter { tab in
            FileManager.default.fileExists(
                atPath: PaperKitPDFDiagnosticStorage.documentDirectory(for: tab.id)
                    .appendingPathComponent("document.pdf").path
            )
        }
        if openDocuments != tabs {
            persistOpenDocuments()
        }
    }

    private func persistOpenDocuments() {
        guard let data = try? JSONEncoder().encode(openDocuments) else { return }
        UserDefaults.standard.set(data, forKey: PaperKitPDFDiagnosticStorage.openDocumentsKey)
    }
}

@available(iOS 26.0, *)
enum PaperKitPDFDiagnosticStorage {
    static let lastDocumentKey = "StudyCoachCore.PaperKitPDFAdaptive.lastDocumentID"
    static let lastDocumentNameKey = "StudyCoachCore.PaperKitPDFAdaptive.lastDocumentName"
    static let openDocumentsKey = "StudyCoachCore.PaperKitPDFAdaptive.openDocuments.v1"

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
private struct PaperKitRecentPhotoItem: Identifiable {
    let id: String
    var thumbnail: UIImage?
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitRecentPhotoLibrary: ObservableObject {
    enum AccessState: Equatable {
        case idle
        case loading
        case ready
        case capabilityMissing
        case denied
    }

    @Published private(set) var items: [PaperKitRecentPhotoItem] = []
    @Published private(set) var accessState: AccessState = .idle
    private let imageManager = PHCachingImageManager()

    func load() {
        guard Bundle.main.object(
            forInfoDictionaryKey: "NSPhotoLibraryUsageDescription"
        ) != nil else {
            accessState = .capabilityMissing
            items = []
            return
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            accessState = .loading
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                Task { @MainActor in
                    self?.reload(for: status)
                }
            }
        } else {
            reload(for: status)
        }
    }

    func loadOriginalData(
        for identifier: String,
        completion: @escaping @MainActor (Result<Data, Error>) -> Void
    ) {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        guard let asset = result.firstObject else {
            completion(.failure(PaperKitRecentPhotoError.assetUnavailable))
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, _, _, info in
            let error = info?[PHImageErrorKey] as? Error
            Task { @MainActor in
                if let data {
                    completion(.success(data))
                } else {
                    completion(.failure(error ?? PaperKitRecentPhotoError.assetUnavailable))
                }
            }
        }
    }

    private func reload(for status: PHAuthorizationStatus) {
        guard status == .authorized || status == .limited else {
            accessState = .denied
            items = []
            return
        }

        accessState = .loading
        let options = PHFetchOptions()
        options.fetchLimit = 18
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false),
        ]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var nextItems: [PaperKitRecentPhotoItem] = []
        result.enumerateObjects { asset, _, _ in
            nextItems.append(
                PaperKitRecentPhotoItem(
                    id: asset.localIdentifier,
                    thumbnail: nil
                )
            )
        }
        items = nextItems
        accessState = .ready

        let pixelSize = CGSize(width: 120, height: 120)
        for asset in result.objects(at: IndexSet(integersIn: 0..<result.count)) {
            imageManager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: nil
            ) { [weak self] image, _ in
                guard let image else { return }
                Task { @MainActor in
                    self?.setThumbnail(image, for: asset.localIdentifier)
                }
            }
        }
    }

    private func setThumbnail(_ image: UIImage, for identifier: String) {
        guard let index = items.firstIndex(where: { $0.id == identifier }) else { return }
        items[index].thumbnail = image
    }
}

@available(iOS 26.0, *)
private enum PaperKitRecentPhotoError: LocalizedError {
    case assetUnavailable

    var errorDescription: String? {
        "사진 원본을 불러오지 못했습니다."
    }
}

@available(iOS 26.0, *)
private struct PaperKitPDFDiagnosticWorkspace: View {
    @StateObject private var model = PaperKitPDFDiagnosticModel()
    @StateObject private var proxy = PaperKitPDFDiagnosticProxy()
    @StateObject private var recentPhotos = PaperKitRecentPhotoLibrary()
    @State private var isShowingPDFImporter = false
    @State private var isShowingImageImporter = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingTextEditor = false
    @State private var draftText = ""
    @AppStorage("StudyCoach.pageScrollHorizontal") private var horizontalPages = false
    @State private var exportedPDF: URL?
    @State private var isExporting = false
    @State private var showingExport = false
    @State private var switchingPage = false

    var body: some View {
        ZStack(alignment: .top) {
            if let page = model.currentPage {
                ZStack {
                    PaperKitPDFPageContainer(
                        page: page,
                        documentID: model.documentID,
                        pageIndex: model.pageIndex,
                        proxy: proxy
                    )
                    .id("\(model.documentID)-\(model.pageIndex)")
                }
            } else {
                ContentUnavailableView {
                    Label("PDF를 선택하세요", systemImage: "doc.text")
                } description: {
                    Text("PDF 페이지와 PaperKit 필기의 확대·좌표·저장을 독립적으로 확인합니다.")
                } actions: {
                    Button("PDF 열기") {
                        isShowingPDFImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            toolbar
        }
        .onAppear { configurePageNavigation() }
        .onChange(of: horizontalPages) { _, _ in configurePageNavigation() }
        .sheet(isPresented: $showingExport) {
            if let exportedPDF { PaperKitShareSheet(url: exportedPDF) }
        }
        .fileImporter(
            isPresented: $isShowingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    model.importPDF(from: url)
                }
            case .failure(let error):
                let cocoaError = error as NSError
                if cocoaError.code != NSUserCancelledError {
                    model.errorMessage = "파일 선택에 실패했습니다. \(error.localizedDescription)"
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingImageImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                proxy.insertImage(from: url)
            case .failure(let error):
                let cocoaError = error as NSError
                if cocoaError.code != NSUserCancelledError {
                    proxy.reportError("이미지를 선택하지 못했습니다. \(error.localizedDescription)")
                }
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        proxy.reportError("선택한 사진 데이터를 읽지 못했습니다.")
                        return
                    }
                    proxy.insertImage(data: data)
                } catch {
                    proxy.reportError("사진을 불러오지 못했습니다. \(error.localizedDescription)")
                }
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $isShowingTextEditor) {
            textEditorSheet
        }
        .alert(
            "StudyCoach",
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
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                documentTabsBar
                if model.document != nil { documentActionsOverlay }
            }

            if model.document != nil {
                primaryToolBar
                if proxy.paletteState.isContextPanelExpanded {
                    secondaryToolBar
                }
            }

            if proxy.statusIsError {
                Label(proxy.statusMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .animation(.snappy(duration: 0.2), value: proxy.paletteState.selectedTool)
        .animation(.snappy(duration: 0.2), value: proxy.paletteState.isContextPanelExpanded)
    }

    private var documentTabsBar: some View {
        HStack(spacing: 6) {
            Button {
                isShowingPDFImporter = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 38, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("PDF 열기")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(model.openDocuments) { tab in
                        documentTab(tab)
                    }
                }
            }
            .contentMargins(.horizontal, 2, for: .scrollContent)
        }
        .frame(maxWidth: 760, minHeight: 38, maxHeight: 38)
        .padding(.horizontal, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func documentTab(_ tab: PaperKitPDFDocumentTab) -> some View {
        let isSelected = model.documentID == tab.id
        return Button {
            afterSaving { model.selectDocument(tab.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: 220, minHeight: 34)
            .background(
                isSelected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.name) 문서")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryToolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                ForEach(StudyCoachPaletteTool.allCases) { tool in
                    toolButton(tool)
                }
                Spacer(minLength: 0)
            }
            .frame(minWidth: 500)
        }
        .contentMargins(.horizontal, 7, for: .scrollContent)
        .frame(width: 520)
        .frame(minHeight: 48, maxHeight: 48)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var secondaryToolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                activeToolControls
                Spacer(minLength: 0)
            }
            .frame(minWidth: 488)
        }
        .contentMargins(.horizontal, 6, for: .scrollContent)
        .frame(width: 500)
        .frame(
            minHeight: proxy.paletteState.selectedTool == .image ? 116 : 46,
            maxHeight: proxy.paletteState.selectedTool == .image ? 116 : 46
        )
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var documentActionsOverlay: some View {
        HStack(spacing: 3) {
            compactIconButton("chevron.left", label: "이전 페이지") {
                afterSaving { model.goToPreviousPage() }
            }
            .disabled(model.pageIndex <= 0)

            Text("\(model.pageIndex + 1) / \(model.pageCount)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(minWidth: 48)

            compactIconButton("chevron.right", label: "다음 페이지") {
                afterSaving { model.goToNextPage() }
            }
            .disabled(model.pageIndex + 1 >= model.pageCount)

            Divider().frame(height: 20)
            compactIconButton("arrow.uturn.backward", label: "실행 취소") { proxy.undo() }
            compactIconButton("arrow.uturn.forward", label: "다시 실행") { proxy.redo() }
            compactIconButton("square.and.arrow.up", label: "필기 포함 PDF 내보내기") {
                exportPDF()
            }
            .disabled(isExporting)
            if isExporting { ProgressView().scaleEffect(0.7) }
            Menu {
                Picker("페이지 스크롤 방향", selection: $horizontalPages) {
                    Label("수직", systemImage: "arrow.up.arrow.down").tag(false)
                    Label("수평", systemImage: "arrow.left.arrow.right").tag(true)
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 36, height: 36)
            }
            .accessibilityLabel("더 보기")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().stroke(Color.primary.opacity(0.08)) }
    }

    private func configurePageNavigation() {
        proxy.horizontalPages = horizontalPages
        proxy.turnPage = { delta in
            afterSaving {
                if delta > 0 { model.goToNextPage() } else { model.goToPreviousPage() }
            }
        }
    }

    private func afterSaving(_ action: @escaping @MainActor () -> Void) {
        guard !switchingPage else { return }
        switchingPage = true
        proxy.save()
        Task { @MainActor in
            do {
                try await PaperKitOrderedSave.flush()
                action()
            } catch { proxy.reportError("저장하지 못해 페이지를 유지합니다: \(error.localizedDescription)") }
            switchingPage = false
        }
    }

    private func exportPDF() {
        guard !isExporting, let document = model.document else { return }
        isExporting = true
        let documentID = model.documentID
        let name = model.documentName
        proxy.save()
        Task { @MainActor in
            do {
                try await PaperKitOrderedSave.flush()
                exportedPDF = try await PaperKitAnnotatedExport.make(
                    document: document, documentID: documentID, name: name
                )
                showingExport = true
            } catch { proxy.reportError("내보내기 실패: \(error.localizedDescription)") }
            isExporting = false
        }
    }

    private var activeToolControls: AnyView {
        switch proxy.paletteState.selectedTool {
        case .pen:
            AnyView(
                HStack(spacing: 4) {
                    inlineInkControls(
                        color: proxy.paletteState.penColor,
                        colors: proxy.paletteState.penColors,
                        selectedColorSlot: proxy.paletteState.selectedPenColorSlot,
                        widths: StudyCoachToolPaletteState.penWidths,
                        selectedWidthLevel: proxy.paletteState.penWidthLevel,
                        selectWidth: proxy.setPenWidthLevel,
                        selectColor: proxy.selectPenColor,
                        replaceColor: proxy.replaceSelectedPenColor
                    )
                    toolDivider
                    penPatternButton(.solid)
                    penPatternButton(.dotted)
                }
            )
        case .highlighter:
            AnyView(
                HStack(spacing: 4) {
                    inlineInkControls(
                        color: proxy.paletteState.highlighterColor,
                        colors: proxy.paletteState.highlighterColors,
                        selectedColorSlot: proxy.paletteState.selectedHighlighterColorSlot,
                        widths: StudyCoachToolPaletteState.highlighterWidths,
                        selectedWidthLevel: proxy.paletteState.highlighterWidthLevel,
                        selectWidth: proxy.setHighlighterWidthLevel,
                        selectColor: proxy.selectHighlighterColor,
                        replaceColor: proxy.replaceSelectedHighlighterColor
                    )
                    toolDivider
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Slider(
                        value: Binding(
                            get: { proxy.paletteState.highlighterOpacity },
                            set: { proxy.setHighlighterOpacity($0) }
                        ),
                        in: 0.10...0.80,
                        step: 0.05
                    )
                    .frame(width: 96)
                    .tint(Color(proxy.paletteState.highlighterColor))
                    .accessibilityLabel("형광펜 투명도")
                    .accessibilityValue(
                        "\(Int((proxy.paletteState.highlighterOpacity * 100).rounded()))퍼센트"
                    )
                    toolDivider
                    ForEach(
                        Array(StudyCoachToolPaletteState.highlighterAzimuths.indices),
                        id: \.self
                    ) { index in
                        angleButton(index)
                    }
                }
            )
        case .eraser:
            AnyView(
                HStack(spacing: 4) {
                    eraserSizePreview
                    widthSlider(
                        widths: StudyCoachToolPaletteState.eraserWidths,
                        selectedLevel: proxy.paletteState.eraserWidthLevel,
                        color: .primary,
                        select: proxy.setEraserWidthLevel
                    )
                    toolDivider
                    ForEach(
                        [
                            StudyCoachPaletteEraserMode.stroke,
                            .partial,
                            .precision,
                        ]
                    ) { mode in
                        eraserModeButton(mode)
                    }
                }
            )
        case .lasso:
            AnyView(EmptyView())
        case .text:
            AnyView(
                compactChoiceIconButton(
                    "plus",
                    label: "텍스트 상자 추가",
                    isSelected: true
                ) {
                    draftText = ""
                    isShowingTextEditor = true
                }
            )
        case .image:
            AnyView(recentPhotoControls)
        }
    }

    private func toolButton(_ tool: StudyCoachPaletteTool) -> some View {
        let isSelected = proxy.paletteState.selectedTool == tool

        return compactChoiceIconButton(
            tool.systemImage,
            label: tool.title,
            isSelected: isSelected
        ) {
            if tool == .image {
                recentPhotos.load()
            }
            proxy.selectTool(tool)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var recentPhotoControls: some View {
        VStack(spacing: 5) {
            Group {
                if recentPhotos.items.isEmpty {
                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label(recentPhotoStatusTitle, systemImage: "photo.on.rectangle")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(recentPhotos.items) { item in
                                Button {
                                    insertRecentPhoto(item.id)
                                } label: {
                                    Group {
                                        if let thumbnail = item.thumbnail {
                                            Image(uiImage: thumbnail)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 54, height: 54)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("최근 사진 삽입")
                            }
                        }
                    }
                }
            }
            .frame(width: 472, height: 58)

            Button {
                isShowingImageImporter = true
            } label: {
                Label("파일에서 불러오기", systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var recentPhotoStatusTitle: String {
        switch recentPhotos.accessState {
        case .idle, .loading:
            "최근 사진 불러오는 중"
        case .ready:
            "사진 선택"
        case .capabilityMissing:
            "사진 보관함 권한 설정 필요"
        case .denied:
            "사진 접근이 허용되지 않음"
        }
    }

    private func insertRecentPhoto(_ identifier: String) {
        recentPhotos.loadOriginalData(for: identifier) { result in
            switch result {
            case .success(let data):
                proxy.insertImage(data: data)
            case .failure(let error):
                proxy.reportError(error.localizedDescription)
            }
        }
    }

    private func penPatternButton(_ pattern: StudyCoachPenPattern) -> some View {
        let isSelected = proxy.paletteState.penPattern == pattern
        let image = pattern == .solid ? "line.diagonal" : "ellipsis"
        let label = pattern == .solid ? "실선" : "점선"
        return compactChoiceIconButton(
            image,
            label: label,
            isSelected: isSelected
        ) { proxy.setPenPattern(pattern) }
    }

    private func eraserModeButton(_ mode: StudyCoachPaletteEraserMode) -> some View {
        let isSelected = proxy.paletteState.eraserMode == mode
        return Button {
            proxy.setEraserMode(mode)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(mode.title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var eraserSizePreview: some View {
        let widths = StudyCoachToolPaletteState.eraserWidths
        let width = proxy.paletteState.eraserWidth
        let maximum = widths.last ?? width
        let diameter = 8 + 22 * CGFloat(width / max(maximum, 1))
        return Circle()
            .fill(Color.secondary.opacity(0.10))
            .overlay { Circle().stroke(Color.secondary, lineWidth: 1.2) }
            .frame(width: diameter, height: diameter)
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var toolDivider: some View {
        Divider()
            .frame(height: 26)
            .padding(.horizontal, 3)
    }

    private func inlineInkControls(
        color: StudyCoachRGBAColor,
        colors: [StudyCoachRGBAColor],
        selectedColorSlot: Int,
        widths: [Double],
        selectedWidthLevel: Int,
        selectWidth: @escaping (Int) -> Void,
        selectColor: @escaping (Int) -> Void,
        replaceColor: @escaping (StudyCoachRGBAColor) -> Void
    ) -> some View {
        Group {
            ForEach(Array(colors.indices), id: \.self) { index in
                Button { selectColor(index) } label: {
                    Circle()
                        .fill(Color(colors[index]))
                        .frame(width: 21, height: 21)
                        .overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 1.5) }
                        .overlay {
                            Circle().stroke(
                                selectedColorSlot == index
                                    ? Color.accentColor
                                    : Color.primary.opacity(0.12),
                                lineWidth: selectedColorSlot == index ? 2.5 : 1
                            )
                            .padding(-3)
                        }
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("빠른 색상 \(index + 1)")
            }
            ColorPicker(
                "색상 편집",
                selection: Binding(
                    get: { Color(color) },
                    set: { replaceColor(StudyCoachRGBAColor($0)) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 30, height: 34)
            .accessibilityLabel("선택 색상 편집")
            toolDivider
            widthSlider(
                widths: widths,
                selectedLevel: selectedWidthLevel,
                color: Color(color),
                select: selectWidth
            )
        }
    }

    private func widthSlider(
        widths: [Double],
        selectedLevel: Int,
        color: Color,
        select: @escaping (Int) -> Void
    ) -> some View {
        let safeLevel = min(max(selectedLevel, 0), max(widths.count - 1, 0))
        let value = widths.isEmpty ? 0 : widths[safeLevel]

        return HStack(spacing: 8) {
            Image(systemName: "lineweight")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Slider(
                value: Binding(
                    get: { Double(safeLevel) },
                    set: { select(Int($0.rounded())) }
                ),
                in: 0...Double(max(widths.count - 1, 1)),
                step: 1
            )
            .frame(width: 180)
            .tint(color)

            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("굵기")
        .accessibilityValue(
            value.formatted(.number.precision(.fractionLength(0...1)))
        )
    }

    private func angleButton(_ index: Int) -> some View {
        let labels = ["0°", "45°", "90°"]
        let isSelected = proxy.paletteState.highlighterAzimuthIndex == index

        return Button { proxy.setHighlighterAzimuthIndex(index) } label: {
            Text(labels[index])
                .font(.caption2.weight(.semibold))
                .frame(width: 34, height: 30)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .background(
                    isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("형광펜 각도 \(labels[index])")
    }

    private func compactChoiceIconButton(
        _ systemImage: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 42, height: 42)
                .background(
                    isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func compactIconButton(
        _ systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var textEditorSheet: some View {
        NavigationStack {
            TextEditor(text: $draftText)
                .font(.title3)
                .padding()
                .navigationTitle("텍스트 상자")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { isShowingTextEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("추가") {
                            proxy.insertText(draftText)
                            isShowingTextEditor = false
                        }
                        .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

@available(iOS 26.0, *)
private extension StudyCoachPaletteTool {
    var title: String {
        switch self {
        case .pen: "펜"
        case .highlighter: "형광펜"
        case .eraser: "지우개"
        case .lasso: "올가미"
        case .text: "텍스트"
        case .image: "이미지"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser.fill"
        case .lasso: "lasso"
        case .text: "character.cursor.ibeam"
        case .image: "photo.on.rectangle.angled"
        }
    }
}

@available(iOS 26.0, *)
private extension StudyCoachPaletteEraserMode {
    var title: String {
        switch self {
        case .precision: "정밀"
        case .partial: "부분"
        case .stroke: "전체/획"
        }
    }

    var systemImage: String {
        switch self {
        case .precision: "eraser.fill"
        case .partial: "eraser"
        case .stroke: "scribble"
        }
    }
}

@available(iOS 26.0, *)
private extension Color {
    init(_ color: StudyCoachRGBAColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

@available(iOS 26.0, *)
private extension StudyCoachRGBAColor {
    init(_ color: Color) {
        // Ink is rendered over a fixed white PDF page. Resolve ColorPicker
        // output in a light trait environment so PencilKit never persists a
        // dark-mode semantic inverse of the color shown in the swatch.
        let uiColor = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )
        } else {
            self = .black
        }
    }
}

@available(iOS 26.0, *)
@MainActor
final class PaperKitPDFDiagnosticProxy: ObservableObject {
    private static let palettePreferencesKey = "StudyCoachCore.PaperKitPDFAdaptive.ToolPalette.v1"

    @Published var statusMessage = "준비됨"
    @Published var statusIsError = false
    @Published private(set) var paletteState = StudyCoachToolPaletteState()
    var horizontalPages = false
    var turnPage: ((Int) -> Void)?
    private weak var controller: PaperKitPDFPageViewController?

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.palettePreferencesKey),
              let restored = try? JSONDecoder().decode(
                  StudyCoachToolPaletteState.self,
                  from: data
              ) else { return }
        paletteState = restored
    }

    func attach(_ controller: PaperKitPDFPageViewController) {
        self.controller = controller
        controller.applyPaletteState(paletteState)
    }

    func save() {
        controller?.saveMarkup()
    }

    func selectTool(_ tool: StudyCoachPaletteTool) {
        updatePalette { $0.select(tool) }
    }

    func setPenWidthLevel(_ level: Int) {
        updatePalette { $0.setPenWidthLevel(level) }
    }

    func setHighlighterWidthLevel(_ level: Int) {
        updatePalette { $0.setHighlighterWidthLevel(level) }
    }

    func setEraserWidthLevel(_ level: Int) {
        updatePalette { $0.setEraserWidthLevel(level) }
    }

    func setHighlighterAzimuthIndex(_ index: Int) {
        updatePalette { $0.setHighlighterAzimuthIndex(index) }
    }

    func setHighlighterOpacity(_ opacity: Double) {
        updatePalette { $0.setHighlighterOpacity(opacity) }
    }

    func setEraserMode(_ mode: StudyCoachPaletteEraserMode) {
        updatePalette { $0.setEraserMode(mode) }
    }

    func setPenPattern(_ pattern: StudyCoachPenPattern) {
        updatePalette { $0.setPenPattern(pattern) }
    }

    func selectPenColor(_ slot: Int) {
        updatePalette { $0.selectPenColor(slot: slot) }
    }

    func selectHighlighterColor(_ slot: Int) {
        updatePalette { $0.selectHighlighterColor(slot: slot) }
    }

    func replaceSelectedPenColor(_ color: StudyCoachRGBAColor) {
        updatePalette { $0.replaceSelectedPenColor(with: color) }
    }

    func replaceSelectedHighlighterColor(_ color: StudyCoachRGBAColor) {
        updatePalette { $0.replaceSelectedHighlighterColor(with: color) }
    }

    func setContextPanelExpanded(_ isExpanded: Bool) {
        updatePalette(applyTool: false) { $0.setContextPanelExpanded(isExpanded) }
    }

    func undo() {
        controller?.undoMarkup()
    }

    func redo() {
        controller?.redoMarkup()
    }

    func insertText(_ text: String) {
        guard controller?.insertText(text) == true else { return }
        updatePalette { $0.select(.lasso) }
        statusMessage = "텍스트 상자를 추가했습니다."
        statusIsError = false
    }

    func insertImage(data: Data) {
        guard controller?.insertImage(data: data) == true else { return }
        updatePalette { $0.select(.lasso) }
        statusMessage = "원본 해상도 이미지를 추가했습니다."
        statusIsError = false
    }

    func insertImage(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            insertImage(data: try Data(contentsOf: url))
        } catch {
            reportError("이미지를 읽지 못했습니다. \(error.localizedDescription)")
        }
    }

    func reportError(_ message: String) {
        statusMessage = message
        statusIsError = true
    }

    func handlePencilPreferredAction(_ action: UIPencilPreferredAction) {
        switch action {
        case .switchEraser:
            updatePalette { $0.toggleEraser() }
        case .switchPrevious:
            updatePalette { $0.switchToPreviousTool() }
        case .showColorPalette, .showInkAttributes, .showContextualPalette:
            updatePalette(applyTool: false) { $0.setContextPanelExpanded(true) }
        case .ignore, .runSystemShortcut:
            break
        @unknown default:
            break
        }
    }

    private func updatePalette(
        applyTool: Bool = true,
        _ update: (inout StudyCoachToolPaletteState) -> Void
    ) {
        var nextState = paletteState
        update(&nextState)
        guard nextState != paletteState else { return }
        paletteState = nextState
        if let data = try? JSONEncoder().encode(nextState) {
            UserDefaults.standard.set(data, forKey: Self.palettePreferencesKey)
        }
        if applyTool {
            controller?.applyPaletteState(nextState)
        }
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
        proxy.attach(controller)
        return controller
    }

    func updateUIViewController(
        _ uiViewController: PaperKitPDFPageViewController,
        context: Context
    ) {
        proxy.attach(uiViewController)
    }

    static func dismantleUIViewController(
        _ uiViewController: PaperKitPDFPageViewController,
        coordinator: Void
    ) {
        uiViewController.saveMarkup()
    }
}

@available(iOS 26.0, *)
struct PaperKitPencilSample {
    let location: CGPoint
    let timestamp: TimeInterval
    let force: CGFloat
    let altitude: CGFloat
    let azimuth: CGFloat
}

/// A Pencil-only recognizer used only for ink features that PencilKit doesn't
/// expose as a native drawing tool on iPadOS 26 (dotted ink and a genuinely
/// fixed marker tip). It deliberately ignores fingers, leaving PaperKit as the
/// sole owner of pan and zoom.
@available(iOS 26.0, *)
@MainActor
private final class PaperKitPencilStrokeRecognizer: UIGestureRecognizer {
    private(set) var samples: [PaperKitPencilSample] = []

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view, let pencil = touches.first(where: { $0.type == .pencil }) else {
            state = .failed
            return
        }
        samples.removeAll(keepingCapacity: true)
        appendSamples(for: pencil, event: event, in: view)
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view, let pencil = touches.first(where: { $0.type == .pencil }) else { return }
        appendSamples(for: pencil, event: event, in: view)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let view, let pencil = touches.first(where: { $0.type == .pencil }) {
            appendSamples(for: pencil, event: event, in: view)
        }
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    override func reset() {
        super.reset()
        samples.removeAll(keepingCapacity: true)
    }

    private func appendSamples(for touch: UITouch, event: UIEvent, in view: UIView) {
        let touches = event.coalescedTouches(for: touch) ?? [touch]
        for sample in touches {
            let location = sample.location(in: view)
            if let previous = samples.last,
               hypot(
                   location.x - previous.location.x,
                   location.y - previous.location.y
               ) < 0.15 {
                continue
            }
            samples.append(
                PaperKitPencilSample(
                    location: location,
                    timestamp: sample.timestamp,
                    force: max(sample.force, 0.01),
                    altitude: sample.altitudeAngle,
                    azimuth: sample.azimuthAngle(in: view)
                )
            )
        }
    }
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitPencilContactObserver: UIGestureRecognizer {
    var contact: ((CGPoint?) -> Void)?
    override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first(where: { $0.type == .pencil }) {
            contact?(touch.location(in: view))
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        touchesBegan(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        contact?(nil)
        state = .failed
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        contact?(nil)
        state = .failed
    }
}

@available(iOS 26.0, *)
@MainActor
final class PaperKitPDFPageViewController: UIViewController {
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
    private var pencilInteraction: UIPencilInteraction?
    private var paletteActivationTask: Task<Void, Never>?
    private var isPaletteActivationReady = false
    private var lastAppliedPaletteState: StudyCoachToolPaletteState?
    private var navigationCompletionTask: Task<Void, Never>?
    private var lastSubmittedVisibleFrame = CGRect.null
    private var lastViewportSize = CGSize.zero
    private var observedNavigationRecognizers: [UIGestureRecognizer] = []
    private var activeNavigationRecognizerIDs: Set<ObjectIdentifier> = []
    private var activePinchRecognizerIDs: Set<ObjectIdentifier> = []
    private var customInkRecognizer: PaperKitPencilStrokeRecognizer?
    private let customInkPreviewLayer = CAShapeLayer()
    private let inkPreviewImage = UIImageView()
    private var customInkPreviewState: StudyCoachToolPaletteState?
    private var eraserHoverRecognizer: UIHoverGestureRecognizer?
    private let eraserCursorLayer = CAShapeLayer()
    private var eraserCursorDiameter: CGFloat = 24
    private var showsStrokeEraserCursor = false
    private var pageTurnRecognizerID: ObjectIdentifier?
    private var pagePanStart = CGRect.null

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
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // PDF paper is permanently white. PencilKit otherwise adapts some ink
        // colors to dark appearance, which makes a black ColorPicker choice
        // render as white (and vice versa) on the page.
        overrideUserInterfaceStyle = .light
        paperController.overrideUserInterfaceStyle = .light
        paperController.view.overrideUserInterfaceStyle = .light
        view.backgroundColor = .secondarySystemBackground

        paperController.isEditable = true
        paperController.directTouchMode = .selection
        paperController.directTouchAutomaticallyDraws = false
        paperController.zoomRange = 0.25...8

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

        installCustomInkCapture()
        installEraserHoverCursor()
        observeMarkupChanges()

        let pencilInteraction = UIPencilInteraction(delegate: self)
        paperController.view.addInteraction(pencilInteraction)
        self.pencilInteraction = pencilInteraction

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        proxy?.attach(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installNavigationObservationIfNeeded()
        updateCurrentViewportTiles()

        paletteActivationTask?.cancel()
        paletteActivationTask = Task { @MainActor [weak self] in
            // Returning the first visible frame before changing PaperKit's
            // drawing tool avoids doing responder/editor activation inside a
            // SwiftUI representable update transaction.
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.isPaletteActivationReady = true
            self.applyPaletteState(
                self.proxy?.paletteState ?? StudyCoachToolPaletteState()
            )
            self.paperController.becomeFirstResponder()
            self.paletteActivationTask = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        customInkPreviewLayer.frame = paperController.view.bounds
        eraserCursorLayer.frame = paperController.view.bounds
        installNavigationObservationIfNeeded()

        let viewportSize = paperController.view.bounds.size
        guard viewportSize != lastViewportSize else { return }
        lastViewportSize = viewportSize
        lastSubmittedVisibleFrame = .null
        updateCurrentViewportTiles()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPaletteActivationReady = false
        paletteActivationTask?.cancel()
        paletteActivationTask = nil
        navigationCompletionTask?.cancel()
        navigationCompletionTask = nil
        removeNavigationObservation()
    }

    @objc
    private func applicationDidEnterBackground() {
        saveMarkup()
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save notes")
        Task { @MainActor in
            _ = try? await PaperKitOrderedSave.flush()
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
    }

    func saveMarkup() {
        guard let markup = paperController.markup else { return }
        let url = PaperKitPDFDiagnosticStorage.markupURL(
            for: documentID,
            pageIndex: pageIndex
        )
        let proxy = proxy

        let saving = PaperKitOrderedSave.enqueue(markup, to: url)
        Task {
            do {
                try await saving.value
            } catch {
                proxy?.statusMessage = "\(pageIndex + 1)페이지 저장 실패: \(error.localizedDescription)"
                proxy?.statusIsError = true
            }
        }
    }

    private func observeMarkupChanges() {
        withObservationTracking {
            _ = paperController.markup
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeMarkupChanges()
                self.saveMarkup()
            }
        }
    }

    func applyPaletteState(_ state: StudyCoachToolPaletteState) {
        guard isPaletteActivationReady,
              isViewLoaded,
              view.window != nil,
              state != lastAppliedPaletteState else { return }

        let usesCustomInkCapture = state.selectedTool == .pen && state.penPattern == .dotted
            || state.selectedTool == .highlighter && state.highlighterAzimuthIndex != 1
        customInkPreviewState = usesCustomInkCapture ? state : nil
        customInkRecognizer?.isEnabled = usesCustomInkCapture
        paperController.isEditable = !usesCustomInkCapture
        if !usesCustomInkCapture {
            clearCustomInkPreview()
        }

        showsStrokeEraserCursor = state.selectedTool == .eraser
            && state.eraserMode == .stroke
        eraserCursorDiameter = eraserCursorDisplayDiameter(for: state.eraserWidth)
        if !showsStrokeEraserCursor {
            eraserCursorLayer.isHidden = true
        }

        switch state.selectedTool {
        case .pen:
            if usesCustomInkCapture {
                paperController.drawingTool = PKLassoTool()
            } else {
                let type = PKInkingTool.InkType.pen
                let width = CGFloat(state.penWidth).clamped(to: type.validWidthRange)
                paperController.drawingTool = PKInkingTool(
                    type,
                    color: UIColor(state.penColor),
                    width: width
                )
            }
        case .highlighter:
            if usesCustomInkCapture {
                paperController.drawingTool = PKLassoTool()
            } else {
                let type = PKInkingTool.InkType.marker
                let width = CGFloat(state.highlighterWidth).clamped(to: type.validWidthRange)
                paperController.drawingTool = PKInkingTool(
                    type,
                    color: UIColor(state.highlighterColor).withAlphaComponent(
                        CGFloat(state.highlighterOpacity)
                    ),
                    width: width,
                    azimuth: CGFloat(state.highlighterAzimuth)
                )
            }
        case .eraser:
            let type: PKEraserTool.EraserType = switch state.eraserMode {
            case .precision: .fixedWidthBitmap
            case .partial: .fixedWidthBitmap
            case .stroke: .vector
            }
            // Both partial modes use fixedWidthBitmap so the selected slider
            // value has a predictable physical diameter. Precision is the
            // deliberately smaller version of the same controllable eraser.
            let requestedWidth = state.eraserMode == .precision
                ? CGFloat(state.eraserWidth) * 0.35
                : CGFloat(state.eraserWidth)
            let width = type == .vector
                ? requestedWidth
                : requestedWidth.clamped(to: type.validWidthRange)
            paperController.drawingTool = PKEraserTool(type, width: width)
        case .lasso, .text, .image:
            paperController.drawingTool = PKLassoTool()
        }
        lastAppliedPaletteState = state
        paperController.becomeFirstResponder()
    }

    private func installCustomInkCapture() {
        inkPreviewImage.isUserInteractionEnabled = false
        paperController.view.addSubview(inkPreviewImage)
        customInkPreviewLayer.fillColor = UIColor.clear.cgColor
        customInkPreviewLayer.lineJoin = .round
        customInkPreviewLayer.isHidden = true
        customInkPreviewLayer.zPosition = 10_000
        paperController.view.layer.addSublayer(customInkPreviewLayer)

        let recognizer = PaperKitPencilStrokeRecognizer(
            target: self,
            action: #selector(customInkGestureChanged(_:))
        )
        recognizer.isEnabled = false
        paperController.view.addGestureRecognizer(recognizer)
        customInkRecognizer = recognizer
    }

    private func installEraserHoverCursor() {
        eraserCursorLayer.fillColor = UIColor.systemGray.withAlphaComponent(0.10).cgColor
        eraserCursorLayer.strokeColor = UIColor.systemGray.cgColor
        eraserCursorLayer.lineWidth = 1.25
        eraserCursorLayer.isHidden = true
        eraserCursorLayer.zPosition = 10_001
        paperController.view.layer.addSublayer(eraserCursorLayer)

        let recognizer = UIHoverGestureRecognizer(
            target: self,
            action: #selector(eraserHoverChanged(_:))
        )
        recognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.pencil.rawValue),
        ]
        paperController.view.addGestureRecognizer(recognizer)
        eraserHoverRecognizer = recognizer
        let contact = PaperKitPencilContactObserver(target: nil, action: nil)
        contact.cancelsTouchesInView = false
        contact.delaysTouchesBegan = false
        contact.delaysTouchesEnded = false
        contact.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        contact.contact = { [weak self] location in self?.showEraserCursor(at: location) }
        paperController.view.addGestureRecognizer(contact)
    }

    private func showEraserCursor(at location: CGPoint?) {
        guard showsStrokeEraserCursor, let location else {
            eraserCursorLayer.isHidden = true
            return
        }
        eraserCursorDiameter = eraserCursorDisplayDiameter(for: proxy?.paletteState.eraserWidth ?? 16)
        let radius = eraserCursorDiameter / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eraserCursorLayer.path = UIBezierPath(ovalIn: CGRect(
            x: location.x - radius, y: location.y - radius,
            width: radius * 2, height: radius * 2
        )).cgPath
        eraserCursorLayer.isHidden = false
        CATransaction.commit()
    }

    @objc
    private func customInkGestureChanged(_ recognizer: PaperKitPencilStrokeRecognizer) {
        guard let state = customInkPreviewState else {
            clearCustomInkPreview()
            return
        }

        switch recognizer.state {
        case .began, .changed:
            drawCustomInkPreview(samples: recognizer.samples, state: state)
        case .ended:
            let samples = recognizer.samples
            appendCustomInk(samples: samples, state: state)
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.clearCustomInkPreview()
            }
        case .cancelled, .failed:
            clearCustomInkPreview()
        case .possible:
            break
        @unknown default:
            clearCustomInkPreview()
        }
    }

    @objc
    private func eraserHoverChanged(_ recognizer: UIHoverGestureRecognizer) {
        guard showsStrokeEraserCursor else {
            eraserCursorLayer.isHidden = true
            return
        }

        switch recognizer.state {
        case .began, .changed:
            let location = recognizer.location(in: paperController.view)
            let radius = eraserCursorDiameter / 2
            eraserCursorLayer.path = UIBezierPath(
                ovalIn: CGRect(
                    x: location.x - radius,
                    y: location.y - radius,
                    width: eraserCursorDiameter,
                    height: eraserCursorDiameter
                )
            ).cgPath
            eraserCursorLayer.isHidden = false
        case .ended, .cancelled, .failed:
            eraserCursorLayer.isHidden = true
        case .possible:
            break
        @unknown default:
            eraserCursorLayer.isHidden = true
        }
    }

    private func drawCustomInkPreview(
        samples: [PaperKitPencilSample],
        state: StudyCoachToolPaletteState
    ) {
        guard !samples.isEmpty else {
            clearCustomInkPreview()
            return
        }

        let drawing = customDrawing(samples: samples, state: state)
        let bounds = drawing.bounds.insetBy(dx: -2, dy: -2)
        guard !bounds.isEmpty, !bounds.isInfinite else { return }
        let scale = min(max(currentPresentationScale * 2, 0.1),
                        2048 / max(bounds.width, bounds.height),
                        sqrt(1_500_000 / max(bounds.width * bounds.height, 1)))
        inkPreviewImage.image = drawing.image(from: bounds, scale: scale)
        inkPreviewImage.frame = backgroundView.convert(bounds, to: paperController.view)
        inkPreviewImage.isHidden = false
        paperController.view.bringSubviewToFront(inkPreviewImage)
    }

    private func clearCustomInkPreview() {
        inkPreviewImage.image = nil
        inkPreviewImage.isHidden = true
        customInkPreviewLayer.path = nil
        customInkPreviewLayer.lineDashPattern = nil
        customInkPreviewLayer.isHidden = true
    }

    private func appendCustomInk(
        samples: [PaperKitPencilSample],
        state: StudyCoachToolPaletteState
    ) {
        let drawing = customDrawing(samples: samples, state: state)
        guard !drawing.strokes.isEmpty, var markup = paperController.markup else { return }
        markup.append(contentsOf: drawing)
        replaceMarkupUndoably(markup)
        saveMarkup()
    }

    private func replaceMarkupUndoably(_ markup: PaperMarkup) {
        guard let previous = paperController.markup else { return }
        paperController.undoManager?.registerUndo(withTarget: self) { target in
            target.replaceMarkupUndoably(previous)
        }
        paperController.markup = markup
    }

    private func customDrawing(samples: [PaperKitPencilSample],
                               state: StudyCoachToolPaletteState) -> PKDrawing {
        let contentSamples = samples.compactMap { contentSample(from: $0) }
        guard !contentSamples.isEmpty else { return PKDrawing() }

        let strokes: [PKStroke]
        if state.selectedTool == .pen && state.penPattern == .dotted {
            strokes = makeDottedStrokes(
                samples: contentSamples,
                color: UIColor(state.penColor),
                width: CGFloat(state.penWidth)
            )
        } else if state.selectedTool == .highlighter {
            strokes = [
                makeFixedHighlighterStroke(
                    samples: contentSamples,
                    color: UIColor(state.highlighterColor),
                    width: CGFloat(state.highlighterWidth),
                    opacity: CGFloat(state.highlighterOpacity),
                    azimuth: CGFloat(state.highlighterAzimuth)
                ),
            ]
        } else {
            return PKDrawing()
        }
        return PKDrawing(strokes: strokes)
    }

    private func contentSample(
        from sample: PaperKitPencilSample
    ) -> PaperKitPencilSample? {
        let viewportBounds = paperController.view.bounds.standardized
        let visibleFrame = paperController.contentVisibleFrame.standardized
        guard viewportBounds.isUsableViewport, visibleFrame.isUsableViewport else { return nil }

        return PaperKitPencilSample(
            location: backgroundView.convert(sample.location, from: paperController.view),
            timestamp: sample.timestamp,
            force: sample.force,
            altitude: sample.altitude,
            azimuth: sample.azimuth
        )
    }

    func makeDottedStrokes(
        samples: [PaperKitPencilSample],
        color: UIColor,
        width: CGFloat
    ) -> [PKStroke] {
        let locations = evenlySpacedLocations(
            samples.map(\.location),
            spacing: max(width * 2.8, 3)
        )
        let ink = PKInk(.pen, color: color)
        let pointSize = CGSize(width: width, height: width)

        return locations.map { location in
            // A substantial spline clipped to a circle survives PencilKit's
            // path simplification, unlike the former near-zero-length stroke.
            let points = (0..<4).map { index in
                PKStrokePoint(
                    location: CGPoint(x: location.x + (CGFloat(index) / 3 - 0.5) * width,
                                      y: location.y),
                    timeOffset: Double(index) / 120,
                    size: pointSize, opacity: 2, force: 1,
                    azimuth: 0, altitude: .pi / 2
                )
            }
            let path = PKStrokePath(
                controlPoints: points,
                creationDate: Date()
            )
            return PKStroke(ink: ink, path: path, mask: UIBezierPath(ovalIn: CGRect(
                x: location.x - width / 2, y: location.y - width / 2,
                width: width, height: width
            )))
        }
    }

    func makeFixedHighlighterStroke(
        samples: [PaperKitPencilSample],
        color: UIColor,
        width: CGFloat,
        opacity: CGFloat,
        azimuth: CGFloat
    ) -> PKStroke {
        let startTime = samples.first?.timestamp ?? 0
        var points = samples.map { sample in
            PKStrokePoint(
                location: sample.location,
                timeOffset: max(0, sample.timestamp - startTime),
                size: CGSize(width: width * 2.8, height: max(width * 0.62, 1)),
                opacity: 2,
                force: 1,
                azimuth: azimuth,
                altitude: .pi / 2
            )
        }
        if points.count == 1, let point = points.first {
            points.append(
                PKStrokePoint(
                    location: CGPoint(x: point.location.x + 0.02, y: point.location.y),
                    timeOffset: 0.001,
                    size: point.size,
                    opacity: point.opacity,
                    force: point.force,
                    azimuth: azimuth,
                    altitude: .pi / 2
                )
            )
        }
        // Repeat end controls to anchor the cubic spline. The pen ink has a
        // rounded footprint; alpha is applied once on PKInk, never multiplied
        // into an already translucent native marker.
        if let first = points.first, let last = points.last {
            points.insert(first, at: 0)
            points.append(last)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: color.withAlphaComponent(opacity)), path: path)
    }

    private func evenlySpacedLocations(
        _ locations: [CGPoint],
        spacing: CGFloat
    ) -> [CGPoint] {
        guard let first = locations.first else { return [] }
        guard locations.count > 1 else { return [first] }

        var result = [first]
        var cumulativeDistance: CGFloat = 0
        var nextDotDistance = spacing

        for (start, end) in zip(locations, locations.dropFirst()) {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = hypot(dx, dy)
            guard segmentLength > 0 else { continue }

            while nextDotDistance <= cumulativeDistance + segmentLength {
                let fraction = (nextDotDistance - cumulativeDistance) / segmentLength
                result.append(
                    CGPoint(
                        x: start.x + dx * fraction,
                        y: start.y + dy * fraction
                    )
                )
                nextDotDistance += spacing
            }
            cumulativeDistance += segmentLength
        }
        return result
    }

    private func previewLineWidth(for state: StudyCoachToolPaletteState) -> CGFloat {
        let contentWidth = state.selectedTool == .pen
            ? CGFloat(state.penWidth)
            : CGFloat(state.highlighterWidth)
        return max(contentWidth * currentPresentationScale, 1)
    }

    private func eraserCursorDisplayDiameter(for width: Double) -> CGFloat {
        (CGFloat(width).clamped(to: 4...96) * currentPresentationScale)
            .clamped(to: 12...160)
    }

    private var currentPresentationScale: CGFloat {
        let viewport = paperController.view.bounds.standardized
        let visible = paperController.contentVisibleFrame.standardized
        guard viewport.isUsableViewport, visible.isUsableViewport else { return 1 }
        return min(viewport.width / visible.width, viewport.height / visible.height)
    }

    func undoMarkup() {
        guard paperController.undoManager?.canUndo == true else { return }
        paperController.undoManager?.undo()
    }

    func redoMarkup() {
        guard paperController.undoManager?.canRedo == true else { return }
        paperController.undoManager?.redo()
    }

    func insertText(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, var markup = paperController.markup else { return false }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph,
            ]
        )
        markup.insertNewTextbox(
            attributedText: attributedText,
            frame: insertionFrame(aspectRatio: 3.2, maximumWidthFraction: 0.72),
            rotation: 0
        )
        paperController.markup = markup
        saveMarkup()
        return true
    }

    func insertImage(data: Data) -> Bool {
        guard let image = UIImage(data: data),
              let cgImage = image.studyCoachOrientedCGImage(),
              var markup = paperController.markup else {
            proxy?.reportError("지원되는 이미지 형식이 아니거나 이미지가 손상되었습니다.")
            return false
        }

        let aspectRatio = CGFloat(cgImage.width) / max(CGFloat(cgImage.height), 1)
        markup.insertNewImage(
            cgImage,
            frame: insertionFrame(aspectRatio: aspectRatio, maximumWidthFraction: 0.68),
            rotation: 0
        )
        paperController.markup = markup
        saveMarkup()
        return true
    }

    private func insertionFrame(
        aspectRatio: CGFloat,
        maximumWidthFraction: CGFloat
    ) -> CGRect {
        let pageBounds = backgroundView.bounds.standardized
        let visible = paperController.contentVisibleFrame.standardized
            .intersection(pageBounds)
        let available = visible.isUsableViewport ? visible : pageBounds
        let safeAspectRatio = max(aspectRatio, 0.1)
        let maximumSize = CGSize(
            width: max(available.width * maximumWidthFraction, 120),
            height: max(available.height * 0.58, 80)
        )

        var size = CGSize(width: maximumSize.width, height: maximumSize.width / safeAspectRatio)
        if size.height > maximumSize.height {
            size.height = maximumSize.height
            size.width = maximumSize.height * safeAspectRatio
        }
        size.width = min(size.width, pageBounds.width)
        size.height = min(size.height, pageBounds.height)

        let center = CGPoint(x: available.midX, y: available.midY)
        let origin = CGPoint(
            x: min(max(center.x - size.width / 2, pageBounds.minX), pageBounds.maxX - size.width),
            y: min(max(center.y - size.height / 2, pageBounds.minY), pageBounds.maxY - size.height)
        )
        return CGRect(origin: origin, size: size)
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
        observePageBoundary(recognizer)
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

    private func observePageBoundary(_ recognizer: UIGestureRecognizer) {
        guard let pan = recognizer as? UIPanGestureRecognizer,
              pan.view is UIScrollView else { return }
        let id = ObjectIdentifier(pan)
        if pan.state == .began, pan.numberOfTouches == 1, !isPinchActive {
            pageTurnRecognizerID = id
            pagePanStart = paperController.contentVisibleFrame
        }
        if pan.state == .changed, pan.numberOfTouches != 1 || isPinchActive {
            pageTurnRecognizerID = nil
        }
        guard pan.state == .ended, pageTurnRecognizerID == id, !isPinchActive else { return }
        pageTurnRecognizerID = nil
        let motion = pan.translation(in: paperController.view)
        let horizontal = proxy?.horizontalPages == true
        let delta = horizontal ? motion.x : motion.y
        let cross = horizontal ? motion.y : motion.x
        guard abs(delta) > 80, abs(delta) > abs(cross) * 1.3 else { return }
        let page = backgroundView.bounds
        let scale = max(currentPresentationScale, 0.01)
        let tolerance: CGFloat = 18 / scale
        let atStart = horizontal ? pagePanStart.minX <= page.minX + tolerance
                                 : pagePanStart.minY <= page.minY + tolerance
        let atEnd = horizontal ? pagePanStart.maxX >= page.maxX - tolerance
                               : pagePanStart.maxY >= page.maxY - tolerance
        guard delta > 0 ? atStart : atEnd else { return }
        saveMarkup()
        proxy?.turnPage?(delta < 0 ? 1 : -1)
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
extension PaperKitPDFPageViewController: UIPencilInteractionDelegate {
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveTap tap: UIPencilInteraction.Tap
    ) {
        proxy?.handlePencilPreferredAction(UIPencilInteraction.preferredTapAction)
    }

    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        guard squeeze.phase == .ended else { return }
        proxy?.handlePencilPreferredAction(UIPencilInteraction.preferredSqueezeAction)
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

@available(iOS 26.0, *)
private extension UIColor {
    convenience init(_ color: StudyCoachRGBAColor) {
        self.init(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
    }
}

@available(iOS 26.0, *)
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

@available(iOS 26.0, *)
private extension UIImage {
    /// Returns a correctly oriented CGImage without reducing the source pixel
    /// dimensions. Rotated camera images are redrawn once at their full pixel
    /// size because PaperMarkup stores the CGImage rather than UIImage metadata.
    func studyCoachOrientedCGImage() -> CGImage? {
        guard imageOrientation != .up else { return cgImage }

        let sourceWidth = cgImage?.width ?? Int(size.width * scale)
        let sourceHeight = cgImage?.height ?? Int(size.height * scale)
        let swapsAxes: Bool = switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored: true
        default: false
        }
        let pixelSize = CGSize(
            width: swapsAxes ? sourceHeight : sourceWidth,
            height: swapsAxes ? sourceWidth : sourceHeight
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: pixelSize, format: format)
            .image { _ in draw(in: CGRect(origin: .zero, size: pixelSize)) }
            .cgImage
    }
}
#endif
