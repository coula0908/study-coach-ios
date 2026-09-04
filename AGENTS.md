# StudyCoachCore development contract

## Product constraints

- The consumer is an app playground running in Swift Playgrounds on iPad.
- The objective is a dependable study tool the user can start using quickly,
  not a novel or bespoke PDF engine. Optimize for time-to-study and reliability
  rather than originality or architectural ownership.
- Do not require a Mac, Xcode project, CocoaPods, or a generated `.xcodeproj`.
- Keep the repository usable as a Swift Package dependency from its public GitHub URL.
- Prefer Apple frameworks: Swift, SwiftUI, PDFKit, PencilKit, UniformTypeIdentifiers, and Foundation.
- Do not add an external dependency unless the user explicitly approves it and the package cannot reasonably be built with Apple frameworks.
- Never add API keys, tokens, credentials, personal PDFs, or user drawings to the repository.
- AI functionality is outside the first PDF-annotation MVP. Do not add it until the PDF and Pencil workflow is stable on iPad.

## Research and reuse policy

- Before designing or replacing a PDF viewer, renderer, annotation engine,
  gesture router, toolbar, eraser, or persistence layer, inspect Apple's current
  documentation and samples plus relevant maintained open-source PDF or note
  apps. Mature commercial SDK documentation may be used as architectural
  evidence even when its code cannot be copied.
- Prefer a proven Apple API, compatible open-source component, or a small
  adaptation of a verified implementation over original trial-and-error code.
  Do not reimplement a solved subsystem merely to keep the app custom.
- Commercial apps such as Goodnotes and Notability are valid UX and acceptance
  references, but do not claim knowledge of their private internals. Use public
  code or technical documentation for implementation claims.
- Before adopting code, record its exact repository/page, relevant revision or
  version, license, the part being reused, and why it is compatible with Swift
  Playgrounds. Update `THIRD_PARTY_NOTICES.md` when code is copied or adapted.
- An external package dependency still requires explicit user approval. This
  does not prevent studying external source and adapting a small,
  license-compatible part when that is safer than adding the whole dependency.
- Record rejected alternatives and physical-device evidence in `HANDOFF.md`
  and `VALIDATION.md` so a later AI does not repeat failed experiments.

## Viewport rendering policy

- Treat scale changes and translation as different operations. Never use one
  generic "viewport changed" rule for both pinch zoom and fixed-scale pan.
- During an active pinch, keep a stable already-rendered level on screen and do
  not launch high-resolution work for intermediate scales. Select and render
  the final level of detail after the pinch ends.
- During fixed-scale panning, keep existing sharp pixels or tiles alive and
  translate them with the page. Reuse cached coverage and asynchronously
  prefetch newly exposed neighboring regions; do not clear and replace the
  entire detail image for every content-offset change.
- A complete bounded page image may remain underneath as a no-blank fallback,
  but it must not repeatedly replace sharp foreground content during movement.
- Do not render a full page at maximum zoom resolution without first proving
  its peak memory cost is safe. Prefer bounded tiles, level-of-detail caches,
  viewport priority, and LRU eviction for large PDFs.
- Tile work must not appear as blank or flashing rectangles. Keep the fallback
  image visible, publish completed tiles without a fade, retain overlapping
  sharp tiles, and avoid user-facing status changes for every tile.
- PaperKit or PDFKit must be the sole owner of a given editor's pan, zoom, and
  page-coordinate transform. Do not stack two independent scroll/zoom systems.

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

- These PDFKit invariants govern the production `StudyCoachRootView`. An
  isolated PaperKit candidate may instead let `PaperMarkupViewController` own
  the viewport, but it must preserve the same page-coordinate and persistence
  guarantees and must not also embed an independently scrolling `PDFView`.
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
- Read `HANDOFF.md` before resuming work. Update it after each meaningful design
  or implementation change and before stopping because of context, time, or
  usage limits, so another AI can continue without reconstructing the history.
