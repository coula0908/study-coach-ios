import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudyCoachWorkspaceView: View {
    @ObservedObject var session: StudyCoachSessionModel
    @State private var isShowingImporter = false

    var body: some View {
        Group {
            if session.isLoading {
                ProgressView("PDF를 준비하는 중…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = session.document,
                      let documentID = session.documentID {
                PDFWorkspaceView(
                    document: document,
                    documentID: documentID,
                    documentName: session.documentName ?? "PDF",
                    currentPageIndex: $session.currentPageIndex,
                    store: session.store,
                    openDocument: { isShowingImporter = true },
                    closeDocument: session.closeDocument
                )
            } else {
                welcomeView
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
                Task { await session.importDocument(from: url) }
            case .failure(let error):
                let cocoaError = error as NSError
                if cocoaError.code != NSUserCancelledError {
                    session.errorMessage = "파일 선택에 실패했습니다. \(error.localizedDescription)"
                }
            }
        }
        .alert(
            "Study Coach",
            isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {
                session.errorMessage = nil
            }
        } message: {
            Text(session.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 22) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Study Coach")
                    .font(.largeTitle.bold())

                Text("PDF를 불러오고 Apple Pencil로 바로 필기하세요.\n필기는 문서와 페이지별로 자동 저장됩니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                isShowingImporter = true
            } label: {
                Label("PDF 열기", systemImage: "folder")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
