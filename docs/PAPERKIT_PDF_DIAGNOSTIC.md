# PaperKit PDF-page diagnostic

## Purpose and boundary

The standalone PaperKit canvas passed on the physical iPadOS 26 device. This
second isolated diagnostic checks whether a real PDF page and PaperKit ink stay
aligned and sharp through pan, zoom, page navigation, save, and relaunch. It
now uses the selected PaperKit-first rendering design: a complete bounded page
image is always present, and only the visible region is rerendered after pan or
pinch updates. There is no fixed post-gesture waiting period.

It does not change `StudyCoachRootView`, the production `PDFKitContainerView`,
or existing `.drawing` files. Adaptive diagnostic PDFs and PaperMarkup data
live under `Application Support/StudyCoachCore/Diagnostics/PaperKitPDFAdaptive`.
The earlier `PaperKitPDF` diagnostic directory is left untouched.

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
7. The PDF page first appears as one complete page, never as successively
   appearing white or blank rectangular tiles.
8. While pinching, the complete base page remains visible and no new detail
   render starts, even when the fingers pause without lifting. When the pinch
   ends, the final visible region begins rendering immediately with no
   additional 0.3-second wait.
9. The PDF text and lines become sharp again after that rerender completes.
10. Ink remains anchored to the same printed word or line while zooming and panning.
11. Draw on page 1, move to page 2, draw there, and return to page 1.
12. Both pages restore only their own drawings.
13. Tap **저장**, stop the app, run it again, and verify the PDF and current page restore.
14. Verify saved ink restores and remains editable after relaunch.
15. Try one rotated or landscape PDF page if available.
16. Test the added thin pen and thin highlighter, Apple's default tools,
    eraser modes, undo/redo, Pencil double-tap, and line hold.
17. Confirm the original `StudyCoachRootView()` still opens the existing app unchanged.

For a failure, capture the full screen at fit scale and high zoom, identify the
page number, and state whether the problem affects the PDF background, the ink,
or their alignment.

## Rendering and persistence notes

- `PaperMarkupViewController` owns pan, zoom, Pencil input, and markup rendering.
- No `PDFView` participates in the diagnostic. `PDFDocument` and `PDFPage` are
  retained only to decode and rasterize the PDF background.
- PaperKit uses a logical page twice the crop-box width and height, closely
  matching the coordinate density of the accepted `0.1.4` standalone test.
- A complete page image is rendered at four pixels per original PDF point. The
  longest side is capped at 4096 pixels and total output at 14 million pixels.
- A main-actor task samples `contentVisibleFrame` about every 33 milliseconds.
  It tracks the newest frame during a pinch without rendering it. Outside an
  active pinch, changed frames remain eligible for immediate detail rendering.
- The diagnostic observes PaperKit's existing UIKit pinch recognizer with an
  added target-action callback. It does not replace a gesture delegate, add a
  competing recognizer, or change Pencil and finger routing.
- When the existing recognizer reaches `.ended` or `.cancelled`, an 18-percent
  overscanned final visible region is requested once at 1.2 times the physical
  presentation density, subject to the same allocation bounds.
- The diagnostic deliberately does not conform to
  `PaperMarkupViewController.Delegate`: the physical Swift Playgrounds SDK
  rejects that conformance even though Xcode 26 accepts it.
- Detail work is bounded to one active render and one replaceable pending
  request. During a gesture, stale results are discarded and only the latest
  viewport waits to render, so work cannot accumulate in an unbounded queue.
- Base and detail images are created on one background rendering queue and
  installed only after a complete image is ready. No `CATiledLayer` is used.
- The same PaperKit transform applies to the PDF content view and its ink.
- Page data uses the PDF file's SHA-256 identity and zero-based page index.
- Writes use `PaperMarkup.dataRepresentation()` and atomic local file writes.
