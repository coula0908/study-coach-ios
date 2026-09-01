import SwiftUI

#if canImport(PaperKit)
import PaperKit
import PencilKit
import UIKit
#endif

/// An isolated PaperKit capability spike for iPad Swift Playgrounds.
///
/// This view does not participate in the production PDF or annotation path.
/// Use it temporarily as the app playground's root view, then switch back to
/// `StudyCoachRootView` after recording the diagnostic result.
public struct StudyCoachPaperKitDiagnosticView: View {
    public init() {}

    @ViewBuilder
    public var body: some View {
#if canImport(PaperKit)
        if #available(iOS 26.0, *) {
            StudyCoachPaperKitDiagnosticContainer()
        } else {
            PaperKitUnavailableView(
                detail: "PaperKit 진단에는 iPadOS 26 이상이 필요합니다."
            )
        }
#else
        PaperKitUnavailableView(
            detail: "현재 Swift 도구체인에는 PaperKit 모듈이 없습니다."
        )
#endif
    }
}

private struct PaperKitUnavailableView: View {
    let detail: String

    var body: some View {
        ContentUnavailableView(
            "PaperKit unavailable",
            systemImage: "doc.badge.gearshape",
            description: Text(detail)
        )
    }
}

#if canImport(PaperKit)
@available(iOS 26.0, *)
private struct StudyCoachPaperKitDiagnosticContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PaperKitDiagnosticViewController {
        PaperKitDiagnosticViewController()
    }

    func updateUIViewController(
        _ uiViewController: PaperKitDiagnosticViewController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ uiViewController: PaperKitDiagnosticViewController,
        coordinator: Void
    ) {
        uiViewController.saveDiagnosticMarkup()
    }
}

@available(iOS 26.0, *)
@MainActor
private final class PaperKitDiagnosticViewController: UIViewController {
    private static let diagnosticBounds = CGRect(x: 0, y: 0, width: 1_200, height: 1_600)

    private static var storageURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport
            .appendingPathComponent("StudyCoachCore", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("paperkit-diagnostic.paperkit", isDirectory: false)
    }

    private let paperController: PaperMarkupViewController
    private let toolPicker = PKToolPicker()
    private let statusLabel = UILabel()
    private let restoredOnLaunch: Bool

    init() {
        let restoredMarkup: PaperMarkup?
        if let data = try? Data(contentsOf: Self.storageURL),
           let decoded = try? PaperMarkup(dataRepresentation: data) {
            restoredMarkup = decoded
            restoredOnLaunch = true
        } else {
            restoredMarkup = nil
            restoredOnLaunch = false
        }

        let markup = restoredMarkup ?? PaperMarkup(bounds: Self.diagnosticBounds)
        paperController = PaperMarkupViewController(
            markup: markup,
            supportedFeatureSet: .latest
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
        configurePaperController()
        configureHeader()
        installPaperController()

        statusLabel.text = restoredOnLaunch
            ? "저장된 PaperMarkup을 복원했습니다. 필기와 요소가 다시 편집되는지 확인하세요."
            : "새 PaperMarkup입니다. 도구 선택기와 요소 + 메뉴를 순서대로 시험하세요."
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showToolPicker()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveDiagnosticMarkup()
    }

    func saveDiagnosticMarkup() {
        guard let markup = paperController.markup else {
            setStatus("저장할 PaperMarkup이 없습니다.", isError: true)
            return
        }

        let storageURL = Self.storageURL
        Task { [weak self] in
            do {
                let data = try await markup.dataRepresentation()
                try FileManager.default.createDirectory(
                    at: storageURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: storageURL, options: .atomic)
                self?.setStatus(
                    "PaperMarkup 저장 완료 (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))",
                    isError: false
                )
            } catch {
                self?.setStatus("PaperMarkup 저장 실패: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func configurePaperController() {
        paperController.isEditable = true
        paperController.directTouchMode = .selection
        paperController.directTouchAutomaticallyDraws = false
        paperController.zoomRange = 0.25...8

        let background = DiagnosticPaperBackgroundView(frame: Self.diagnosticBounds)
        background.backgroundColor = .white
        paperController.contentView = background

        toolPicker.addObserver(paperController)
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible
    }

    private func configureHeader() {
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 2
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let buttonStack = UIStackView(arrangedSubviews: [
            makeButton(title: "도구 표시", image: "pencil.tip", action: #selector(showToolPickerAction)),
            makeButton(title: "요소 +", image: "plus.square.on.square", action: #selector(showInsertMenuAction(_:))),
            makeButton(title: "실행 취소", image: "arrow.uturn.backward", action: #selector(undoAction)),
            makeButton(title: "다시 실행", image: "arrow.uturn.forward", action: #selector(redoAction)),
            makeButton(title: "저장", image: "square.and.arrow.down", action: #selector(saveAction)),
            makeButton(title: "저장본 열기", image: "arrow.clockwise", action: #selector(reloadAction)),
        ])
        buttonStack.axis = .horizontal
        buttonStack.alignment = .center
        buttonStack.distribution = .fillProportionally
        buttonStack.spacing = 8

        let header = UIStackView(arrangedSubviews: [statusLabel, buttonStack])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .vertical
        header.spacing = 8
        header.isLayoutMarginsRelativeArrangement = true
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: 12,
            bottom: 8,
            trailing: 12
        )
        header.backgroundColor = .systemBackground
        view.addSubview(header)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func installPaperController() {
        addChild(paperController)
        paperController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(paperController.view)
        paperController.didMove(toParent: self)

        guard let header = statusLabel.superview else { return }
        NSLayoutConstraint.activate([
            paperController.view.topAnchor.constraint(equalTo: header.bottomAnchor),
            paperController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paperController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            paperController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeButton(title: String, image: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePadding = 5
        configuration.buttonSize = .small
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func showToolPicker() {
        paperController.pencilKitResponderState.activeToolPicker = toolPicker
        paperController.pencilKitResponderState.toolPickerVisibility = .visible
        paperController.becomeFirstResponder()
        setStatus("도구 선택기를 표시했습니다. 펜·형광펜·지우개·Lasso를 확인하세요.", isError: false)
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabel
    }

    @objc private func showToolPickerAction() {
        showToolPicker()
    }

    @objc private func showInsertMenuAction(_ sender: UIButton) {
        guard let editDelegate = (paperController as AnyObject)
            as? any MarkupEditViewController.Delegate else {
            setStatus(
                "이 Swift Playgrounds 버전은 PaperKit 요소 삽입 delegate를 노출하지 않습니다. 필기 도구 진단은 계속 사용할 수 있습니다.",
                isError: true
            )
            return
        }

        let editor = MarkupEditViewController(
            supportedFeatureSet: .latest,
            additionalActions: []
        )
        editor.delegate = editDelegate
        editor.modalPresentationStyle = .popover
        editor.popoverPresentationController?.sourceView = sender
        editor.popoverPresentationController?.sourceRect = sender.bounds
        present(editor, animated: true)
        setStatus("요소 메뉴에서 선·도형·텍스트 상자·이미지를 시험하세요.", isError: false)
    }

    @objc private func undoAction() {
        guard paperController.undoManager?.canUndo == true else {
            setStatus("실행 취소할 변경이 없습니다.", isError: false)
            return
        }
        paperController.undoManager?.undo()
        setStatus("PaperKit Undo를 실행했습니다.", isError: false)
    }

    @objc private func redoAction() {
        guard paperController.undoManager?.canRedo == true else {
            setStatus("다시 실행할 변경이 없습니다.", isError: false)
            return
        }
        paperController.undoManager?.redo()
        setStatus("PaperKit Redo를 실행했습니다.", isError: false)
    }

    @objc private func saveAction() {
        saveDiagnosticMarkup()
    }

    @objc private func reloadAction() {
        do {
            let data = try Data(contentsOf: Self.storageURL)
            paperController.markup = try PaperMarkup(dataRepresentation: data)
            showToolPicker()
            setStatus("저장된 PaperMarkup을 다시 열었습니다. 모든 요소의 재편집을 확인하세요.", isError: false)
        } catch {
            setStatus("저장본 열기 실패: 먼저 저장을 누르세요. (\(error.localizedDescription))", isError: true)
        }
    }
}

@available(iOS 26.0, *)
private final class DiagnosticPaperBackgroundView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(1)

        let spacing: CGFloat = 40
        var y: CGFloat = spacing
        while y < bounds.maxY {
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
            y += spacing
        }
        context.strokePath()
    }
}
#endif
