import SwiftUI

/// The single public entry point used by the Swift Playgrounds app.
public struct StudyCoachRootView: View {
    @StateObject private var session = StudyCoachSessionModel()

    public init() {}

    public var body: some View {
        StudyCoachWorkspaceView(session: session)
            .task {
                await session.restoreLastDocumentIfAvailable()
            }
    }
}
