# StudyCoachCore development contract

## Product constraints

- The consumer is an app playground running in Swift Playgrounds on iPad.
- Do not require a Mac, Xcode project, CocoaPods, or a generated `.xcodeproj`.
- Keep the repository usable as a Swift Package dependency from its public GitHub URL.
- Prefer Apple frameworks: Swift, SwiftUI, PDFKit, PencilKit, UniformTypeIdentifiers, and Foundation.
- Do not add an external dependency unless the user explicitly approves it and the package cannot reasonably be built with Apple frameworks.
- Never add API keys, tokens, credentials, personal PDFs, or user drawings to the repository.
- AI functionality is outside the first PDF-annotation MVP. Do not add it until the PDF and Pencil workflow is stable on iPad.

## Public API

- The package product and importable module are both named `StudyCoachCore`.
- Keep `StudyCoachRootView` public with a public parameterless initializer.
- The consuming playground should remain as small as:

  ```swift
  import SwiftUI
  import StudyCoachCore

  struct ContentView: View {
      var body: some View {
          StudyCoachRootView()
      }
  }
  ```

## PDF and drawing invariants

- PDFKit owns page layout, scrolling, zooming, and page transforms.
- Never place one screen-fixed `PKCanvasView` over the entire `PDFView`.
- Use page-bound overlays and create canvases lazily for visible pages.
- Persist one `PKDrawing` per document identity and page index.
- Treat page rotation and crop-box transforms as first-class cases.
- Pencil input draws; finger input scrolls and zooms by default.
- Save a page drawing before releasing its overlay and restore it whenever the page becomes visible again.
- PDF source files remain unchanged. Store drawings separately and write them atomically.

See `docs/ARCHITECTURE.md` before changing the viewer or persistence design.

## Source organization

- `Sources/StudyCoachCore/App`: root composition and app-level state.
- `Sources/StudyCoachCore/PDF`: PDF import, viewer integration, navigation, and page overlays.
- `Sources/StudyCoachCore/Annotations`: PencilKit tools, page drawings, undo, and redo.
- `Sources/StudyCoachCore/Persistence`: document identity and local drawing storage.
- `Sources/StudyCoachCore/Support`: small shared utilities only.
- `Tests/StudyCoachCoreTests`: unit tests for coordinate, identity, and persistence behavior.

Create these feature folders as implementation files are added; do not keep empty placeholder folders.

## Validation

- This Windows host does not currently have the Swift toolchain or Apple SDKs. Do not claim that SwiftUI, PDFKit, or PencilKit code compiled here.
- Run repository-level static checks on Windows.
- Run package compilation and unit tests on an Apple toolchain when one becomes available.
- Treat a successful load and interaction test in Swift Playgrounds on the user's iPad as required acceptance evidence.
- Record device/iPadOS/Swift Playgrounds versions and the exact tested behavior in `VALIDATION.md`.
