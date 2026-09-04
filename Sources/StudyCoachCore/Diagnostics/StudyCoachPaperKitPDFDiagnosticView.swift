import SwiftUI

#if canImport(PaperKit)
import CryptoKit
import PDFKit
import PaperKit
import PencilKit
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
    @State private var isShowingPDFImporter = false
    @State private var isShowingImageImporter = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingTextEditor = false
    @State private var draftText = ""

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
                        isShowingPDFImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingPDFImporter,
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
            documentBar

            if model.document != nil {
                compactToolbox
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .animation(.snappy(duration: 0.2), value: proxy.paletteState.selectedTool)
    }

    private var documentBar: some View {
        HStack(spacing: 5) {
            Button {
                isShowingPDFImporter = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(model.document == nil ? "PDF" : model.documentName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("PDF 열기")
            .frame(maxWidth: 250, alignment: .leading)

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                compactIconButton("chevron.left", label: "이전 페이지") {
                    proxy.save()
                    model.goToPreviousPage()
                }
                .disabled(model.pageIndex <= 0)

                Text(model.document == nil ? "– / –" : "\(model.pageIndex + 1) / \(model.pageCount)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .frame(minWidth: 62)

                compactIconButton("chevron.right", label: "다음 페이지") {
                    proxy.save()
                    model.goToNextPage()
                }
                .disabled(model.pageIndex + 1 >= model.pageCount)
            }

            compactIconButton("arrow.uturn.backward", label: "실행 취소") { proxy.undo() }
            compactIconButton("arrow.uturn.forward", label: "다시 실행") { proxy.redo() }
            compactIconButton("square.and.arrow.down", label: "저장") { proxy.save() }
                .disabled(model.document == nil)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: 920)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var compactToolbox: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(StudyCoachPaletteTool.allCases) { tool in
                    toolButton(tool)
                }

                Divider()
                    .frame(height: 26)
                    .padding(.horizontal, 3)

                activeToolControls
            }
        }
        .contentMargins(.horizontal, 5, for: .scrollContent)
        .frame(maxWidth: 920, minHeight: 44, maxHeight: 44)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
                    ForEach(StudyCoachPaletteEraserMode.allCases) { mode in
                        compactChoiceIconButton(
                            mode.systemImage,
                            label: mode.title,
                            isSelected: proxy.paletteState.eraserMode == mode
                        ) { proxy.setEraserMode(mode) }
                    }
                    toolDivider
                    inlineWidthSelector(
                        widths: StudyCoachToolPaletteState.eraserWidths,
                        selectedLevel: proxy.paletteState.eraserWidthLevel,
                        color: .primary,
                        select: proxy.setEraserWidthLevel
                    )
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
            AnyView(
                HStack(spacing: 4) {
                    compactChoiceIconButton(
                        "photo",
                        label: "사진에서 이미지 추가",
                        isSelected: true
                    ) { isShowingPhotoPicker = true }
                    compactChoiceIconButton(
                        "folder",
                        label: "파일에서 이미지 추가",
                        isSelected: false
                    ) { isShowingImageImporter = true }
                }
            )
        }
    }

    private func toolButton(_ tool: StudyCoachPaletteTool) -> some View {
        let isSelected = proxy.paletteState.selectedTool == tool

        return compactChoiceIconButton(
            tool.systemImage,
            label: tool.title,
            isSelected: isSelected
        ) { proxy.selectTool(tool) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            inlineWidthSelector(
                widths: widths,
                selectedLevel: selectedWidthLevel,
                color: Color(color),
                select: selectWidth
            )
            toolDivider
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
        }
    }

    private func inlineWidthSelector(
        widths: [Double],
        selectedLevel: Int,
        color: Color,
        select: @escaping (Int) -> Void
    ) -> some View {
        ForEach(Array(widths.indices), id: \.self) { index in
            Button { select(index) } label: {
                Circle()
                    .fill(color)
                    .frame(
                        width: widthPreviewDiameter(index: index, count: widths.count),
                        height: widthPreviewDiameter(index: index, count: widths.count)
                    )
                    .frame(width: 27, height: 34)
                    .background(
                        selectedLevel == index ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: Circle()
                    )
                    .overlay {
                        if selectedLevel == index {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("굵기 \(index + 1)")
            .accessibilityValue(
                widths[index].formatted(.number.precision(.fractionLength(0...1)))
            )
        }
    }

    private func widthPreviewDiameter(index: Int, count: Int) -> CGFloat {
        3 + (CGFloat(index) / CGFloat(max(count - 1, 1))) * 14
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 36, height: 34)
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
        case .stroke: "획"
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
        let uiColor = UIColor(color)
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
private final class PaperKitPDFDiagnosticProxy: ObservableObject {
    private static let palettePreferencesKey = "StudyCoachCore.PaperKitPDFAdaptive.ToolPalette.v1"

    @Published var statusMessage = "준비됨"
    @Published var statusIsError = false
    @Published private(set) var paletteState = StudyCoachToolPaletteState()
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

    func applyPaletteState(_ state: StudyCoachToolPaletteState) {
        guard isPaletteActivationReady,
              isViewLoaded,
              view.window != nil,
              state != lastAppliedPaletteState else { return }

        switch state.selectedTool {
        case .pen:
            let type = PKInkingTool.InkType.pen
            let width = CGFloat(state.penWidth).clamped(to: type.validWidthRange)
            paperController.drawingTool = PKInkingTool(
                type,
                color: UIColor(state.penColor),
                width: width
            )
        case .highlighter:
            let type = PKInkingTool.InkType.marker
            let width = CGFloat(state.highlighterWidth).clamped(to: type.validWidthRange)
            var tool = PKInkingTool(
                type,
                color: UIColor(state.highlighterColor).withAlphaComponent(
                    CGFloat(state.highlighterOpacity)
                ),
                width: width
            )
            tool.azimuth = CGFloat(state.highlighterAzimuth)
            paperController.drawingTool = tool
        case .eraser:
            let type: PKEraserTool.EraserType = switch state.eraserMode {
            case .precision: .fixedWidthBitmap
            case .partial: .bitmap
            case .stroke: .vector
            }
            let width = CGFloat(state.eraserWidth).clamped(to: type.validWidthRange)
            paperController.drawingTool = PKEraserTool(type, width: width)
        case .lasso, .text, .image:
            paperController.drawingTool = PKLassoTool()
        }
        lastAppliedPaletteState = state
        paperController.becomeFirstResponder()
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
