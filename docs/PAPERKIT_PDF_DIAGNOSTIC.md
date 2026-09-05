# PaperKit PDF-page diagnostic

## Purpose and boundary

The standalone PaperKit canvas passed on the physical iPadOS 26 device. This
second isolated diagnostic checks whether a real PDF page and PaperKit ink stay
aligned and sharp through pan, zoom, page navigation, save, and relaunch. It
now uses the selected PaperKit-first rendering design: a complete bounded page
image is always present underneath a bounded high-resolution tile cache. A
pinch does not render transient scale values. At a fixed scale, completed tiles
remain sharp while pan and inertia request only newly exposed neighboring
coverage. There is no permanent idle sampler and no fixed post-gesture wait.

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

Use the **PDF 열기** button to choose a study PDF. In `0.1.25`, document tabs
and two independently scrollable StudyCoach tool rows float over the PDF.
Selecting the current tool toggles its setting row without changing the PDF
viewport. The system picker is not the source of tool values.

For the recent-image strip, open the playground's **App Settings →
Capabilities**, add **Photo Library**, and run again. If that host capability
is absent, tapping Image shows an inline permission-setting notice; tapping it
still opens Apple's system Photos picker, and **파일에서 불러오기** remains
available below it.

## Physical iPadOS 26 checklist

1. The diagnostic compiles and opens in Swift Playgrounds.
2. A selected PDF page is upright, uncropped, and not mirrored.
3. Pen and highlighter draw over the intended PDF location.
4. Finger pan and pinch zoom work without drawing.
5. Apple Pencil drawing does not scroll the page.
6. A thin diagonal stroke stays sharp at maximum zoom.
7. The PDF page first appears as one complete page, never as successively
   appearing white or blank rectangular tiles.
8. During a two-finger pinch, no new transient-scale tile render starts, even
   when the fingers pause without lifting. Completed content remains visible;
   the final level is selected only after the pinch and zoom bounce end.
9. During one-finger pan and inertial scrolling, already sharp PDF text stays
   sharp. Newly exposed regions use the complete base page until their
   high-resolution tiles arrive without a white rectangle or fade.
10. Ink remains anchored to the same printed word or line while zooming and panning.
11. Draw on page 1, move to page 2, draw there, and return to page 1.
12. Both pages restore only their own drawings.
13. Tap **저장**, stop the app, run it again, and verify the PDF and current page restore.
14. Verify saved ink restores and remains editable after relaunch.
15. Try one rotated or landscape PDF page if available.
16. Test the added thin pen and thin highlighter, Apple's default tools,
    eraser modes, undo/redo, Pencil double-tap, and line hold.
17. Confirm the original `StudyCoachRootView()` still opens the existing app unchanged.

## Version 0.1.25 advanced-tool checklist

1. Open/close the second row repeatedly and confirm the PDF never changes
   position, fit, zoom, or visible area.
2. Confirm the first and second rows are nearly the same length, their short
   contents are centered, and both can scroll horizontally when needed.
3. Edit a pen slot to black, white, red, and blue. The swatch and new ink must
   match on the white PDF in both light and dark system appearance.
4. Write a solid line and a dotted line at fit scale and maximum zoom. Solid
   input should retain the accepted PaperKit feel; dotted output must align to
   the same page coordinates and remain sharp.
5. Undo/redo a dotted gesture, change pages, relaunch, and erase its dots with
   all three eraser modes. Record if whole-stroke erasing removes one dot or the
   complete dotted gesture.
6. Compare highlighter 0°, 45°, and 90°. Verify 0° and 90° now visibly differ,
   and report whether their latency or stroke correction differs from native
   45°.
7. Move the eraser width slider in **전체/획**, **부분**, and **정밀**. On an
   Apple Pencil hover-capable iPad, verify the whole-stroke hit circle appears;
   on other hardware, use the toolbar size sample and actual hit behavior.
8. Open Image. Verify recent gallery images are newest first, tapping one
   inserts the original, and **파일에서 불러오기** still works.
9. Confirm one-finger pan and two-finger pinch never create ink in any mode.

## Version 0.1.20 custom-toolbar A/B checklist

Physical result on 2026-09-04: the user reported that all 13 supplied
`0.1.20` checks passed. Treat the minimal custom-toolbar bridge as accepted;
the fine-grained widths, quick colors, marker azimuth, three eraser modes,
lasso, text, image, patterned ink, and audio remain separate unimplemented
capabilities described in `TOOLBAR_ARCHITECTURE.md`.

1. Start in **StudyCoach** mode and confirm the Apple palette is not persistently
   visible.
2. Write with the StudyCoach pen and highlighter and erase with the StudyCoach
   eraser.
3. Confirm undo and redo change the current page markup.
4. Switch to **Apple** mode. Its palette should appear without recreating or
   clearing the page.
5. Choose pen, marker, and eraser in the Apple palette. The matching StudyCoach
   button should follow the system selection.
6. Switch back to **StudyCoach**. The Apple palette should move offscreen while
   the selected tool continues working.
7. Double-tap Apple Pencil while the picker is hidden. Confirm the system tool
   changes and the StudyCoach selection highlight follows it.
8. Compare the same strokes in both modes at normal and maximum zoom. There
   must be no change in latency, pressure, correction, sharpness, or alignment.
9. Confirm one-finger pan, two-finger pinch, page changes, save, and relaunch
   still behave as in `0.1.19`.

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
- There is no permanent idle timer or polling task. The diagnostic observes
  existing UIKit pan and pinch recognizers in PaperKit's view hierarchy through
  target-action callbacks. It does not replace a gesture delegate, add a
  competing recognizer, or change Pencil and finger routing.
- Pinch invalidates pending transient-scale requests without clearing completed
  tiles. The final scale uses a discrete half-octave level of detail after the
  pinch and zoom bounce end.
- At fixed scale, pan callbacks update a stable page-coordinate grid. A short
  task continues this update only while UIKit reports actual deceleration.
- Each tile is at most 512 by 512 pixels. Visible tiles are rendered first,
  followed by two neighboring rings. Completed tiles are retained with LRU
  eviction outside the current wanted set after a 96-tile bound is exceeded.
- The diagnostic deliberately does not conform to
  `PaperMarkupViewController.Delegate`: the physical Swift Playgrounds SDK
  rejects that conformance even though Xcode 26 accepts it.
- Detail work is bounded to one active render. The pending list is recomputed
  from the newest wanted grid, so obsolete pan requests do not accumulate.
- Base and tile images are created on one background rendering queue. A tile is
  installed only after its complete image is ready and without animation. No
  `CATiledLayer` is used directly because the diagnostic must suppress
  transient pinch-scale work explicitly.
- Normal tile creation does not change the user-facing status message; only an
  initial base-page result or the first tile failure is reported.
- The same PaperKit transform applies to the PDF content view and its ink.
- Page data uses the PDF file's SHA-256 identity and zero-based page index.
- Writes use `PaperMarkup.dataRepresentation()` and atomic local file writes.
