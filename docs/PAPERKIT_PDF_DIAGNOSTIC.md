# PaperKit PDF-page diagnostic

## Purpose and boundary

The standalone PaperKit canvas passed on the physical iPadOS 26 device. This
second isolated diagnostic checks whether a real PDF page and PaperKit ink stay
aligned and sharp through pan, zoom, page navigation, save, and relaunch.

It does not change `StudyCoachRootView`, the production `PDFKitContainerView`,
or existing `.drawing` files. Diagnostic PDFs and PaperMarkup data live under
`Application Support/StudyCoachCore/Diagnostics/PaperKitPDF`.

## Temporary Swift Playgrounds entry point

Update the package to the version containing this diagnostic, then use:

```swift
import SwiftUI
import StudyCoachCore

struct ContentView: View {
    var body: some View {
        StudyCoachPaperKitPDFDiagnosticView()
    }
}
```

Use the **PDF 열기** button to choose a study PDF. The system drawing tools
remain at the bottom. The custom `도구 표시` button from the standalone spike
is intentionally absent because it had no visible effect when the picker was
already displayed.

## Physical iPadOS 26 checklist

1. The diagnostic compiles and opens in Swift Playgrounds.
2. A selected PDF page is upright, uncropped, and not mirrored.
3. Pen and highlighter draw over the intended PDF location.
4. Finger pan and pinch zoom work without drawing.
5. Apple Pencil drawing does not scroll the page.
6. A thin diagonal stroke stays sharp at maximum zoom.
7. The PDF text and lines also settle sharp after maximum zoom.
8. Ink remains anchored to the same printed word or line while zooming and panning.
9. Draw on page 1, move to page 2, draw there, and return to page 1.
10. Both pages restore only their own drawings.
11. Tap **저장**, stop the app, run it again, and verify the PDF and current page restore.
12. Verify saved ink restores and remains editable after relaunch.
13. Try one rotated or landscape PDF page if available.
14. Test pen, highlighter, eraser modes, undo/redo, Pencil double-tap, and line hold.
15. Confirm the original `StudyCoachRootView()` still opens the existing app unchanged.

For a failure, capture the full screen at fit scale and high zoom, identify the
page number, and state whether the problem affects the PDF background, the ink,
or their alignment.

## Rendering and persistence notes

- `PaperMarkupViewController` owns pan, zoom, Pencil input, and markup rendering.
- A crop-box-sized `UIView` backed by `CATiledLayer` draws the `PDFPage` beneath
  the markup so high-zoom background tiles can be redrawn at higher resolution.
- The same PaperKit transform applies to the PDF content view and its ink.
- Page data uses the PDF file's SHA-256 identity and zero-based page index.
- Writes use `PaperMarkup.dataRepresentation()` and atomic local file writes.
