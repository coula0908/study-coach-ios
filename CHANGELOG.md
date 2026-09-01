# Changelog

## Unreleased — Swift Playgrounds PaperKit compatibility

- Avoid requiring compile-time exposure of `PaperMarkupViewController` as a
  `MarkupEditViewController.Delegate`, which differs between Xcode 26.6 and the
  iPad Swift Playgrounds toolchain.
- Keep the PaperKit drawing, eraser, zoom, undo/redo, and persistence diagnostic
  available when structured-element insertion delegation is unavailable.

## Unreleased — PaperKit diagnostic spike

- Add a public, opt-in `StudyCoachPaperKitDiagnosticView` without changing
  `StudyCoachRootView` or the production PDF annotation engine.
- Use Apple PaperKit APIs directly behind `canImport(PaperKit)` and iOS 26
  availability guards, with a readable unavailable screen on older toolchains.
- Exercise `PaperMarkupViewController`, `PKToolPicker`, PaperKit's insertion UI,
  undo/redo, 8x zoom, and atomic `PaperMarkup` save/reload.
- Compile both the fallback path on Xcode 16 and the real PaperKit path on an
  Xcode 26 GitHub Actions runner.

This spike must pass in Swift Playgrounds on the physical iPadOS 26 device
before any PDFKit/PaperKit integration or production engine replacement.

## 0.1.2

- Replace PencilKit's failing overlay input recognizer with the Pencil-only
  gesture path proven by the MIT-licensed Pumice app on iPadOS 26.
- Keep PencilKit for page-local rendering and `PKDrawing` persistence.
- Preserve finger pan and pinch by rejecting non-Pencil touches before they
  compete with PDFKit.
- Configure the overlay provider before loading the PDF, enable markup mode,
  and enable PDFKit's visible page containers.
- Add repository checks and third-party attribution for the adopted input path.

Physical iPadOS 26 retesting is required before this fix is considered accepted.

## 0.1.1

- Fix Apple Pencil input being routed to PDF scrolling instead of the page canvas.
- Keep PencilKit's `.pencilOnly` drawing policy as the single input classifier.
- Add a repository check that prevents reintroducing the custom canvas `hitTest` override.

Physical iPadOS 26 testing confirmed that this change alone was insufficient:
pen, highlighter, and eraser input still reached PDFView instead of the canvas.

## 0.1.0

- Initial PDF and Apple Pencil MVP.
- Add PDF import, viewing, navigation, zoom, page-bound PencilKit overlays, drawing tools, and local per-page persistence.
