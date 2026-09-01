import PDFKit
import SwiftUI
import UIKit

struct PDFWorkspaceView: View {
    let document: PDFDocument
    let documentID: String
    let documentName: String
    @Binding var currentPageIndex: Int
    let store: StudyCoachDocumentStore
    let openDocument: () -> Void
    let closeDocument: () -> Void

    @StateObject private var proxy = PDFViewerProxy()
    @State private var selectedTool: AnnotationTool = .pen
    @State private var inkColor = Color.blue
    @State private var strokeWidth = 4.0
    @State private var pageInput = "1"

    var body: some View {
        VStack(spacing: 0) {
            documentBar
            Divider()
            annotationBar
            Divider()

            PDFKitContainerView(
                document: document,
                documentID: documentID,
                currentPageIndex: $currentPageIndex,
                toolConfiguration: AnnotationToolConfiguration(
                    tool: selectedTool,
                    color: UIColor(inkColor),
                    width: strokeWidth
                ),
                store: store,
                proxy: proxy
            )
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            pageInput = String(currentPageIndex + 1)
        }
        .onChange(of: currentPageIndex) { _, newValue in
            pageInput = String(newValue + 1)
        }
    }

    private var documentBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("다른 PDF 열기", action: openDocument)
                Button("시작 화면으로", action: closeDocument)
            } label: {
                Label(documentName, systemImage: "doc.text")
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                proxy.go(to: currentPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPageIndex <= 0)

            TextField("페이지", text: $pageInput)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)

            Text("/ \(document.pageCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button("이동") {
                goToEnteredPage()
            }
            .buttonStyle(.bordered)

            Button {
                proxy.go(to: currentPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPageIndex + 1 >= document.pageCount)

            Divider().frame(height: 22)

            Button(action: proxy.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            Button(action: proxy.fitToWidth) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("화면에 맞추기")
            Button(action: proxy.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var annotationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AnnotationTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedTool == tool ? .accentColor : .gray.opacity(0.55))
                }

                Divider().frame(height: 26)

                Button(action: proxy.undo) {
                    Label("실행 취소", systemImage: "arrow.uturn.backward")
                }
                Button(action: proxy.redo) {
                    Label("다시 실행", systemImage: "arrow.uturn.forward")
                }

                Divider().frame(height: 26)

                ColorPicker("색상", selection: $inkColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 36)
                    .disabled(selectedTool == .eraser)

                Text("두께")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Slider(value: $strokeWidth, in: 1...20, step: 1)
                    .frame(width: 150)
                    .disabled(selectedTool == .eraser)

                Text("\(Int(strokeWidth))")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func goToEnteredPage() {
        guard let enteredPage = Int(pageInput) else {
            pageInput = String(currentPageIndex + 1)
            return
        }
        let targetIndex = min(max(enteredPage - 1, 0), max(document.pageCount - 1, 0))
        pageInput = String(targetIndex + 1)
        proxy.go(to: targetIndex)
    }
}
