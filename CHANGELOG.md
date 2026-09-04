# Changelog

## 0.1.17 — Render once after pinch ends

- Observe PaperKit's existing UIKit pinch recognizer through target-action
  without replacing its delegate or adding a competing gesture recognizer.
- During `.began` and `.changed`, discard obsolete detail output and track the
  newest visible frame without starting a new high-resolution PDF render.
- When the pinch reaches `.ended` or `.cancelled`, immediately render the final
  visible region once.
- Keep the 33-millisecond frame sampler as a compatibility fallback and for
  non-pinch viewport changes, while suppressing its render requests for the
  entire active pinch.
- Preserve the one-active plus one-latest-pending render bound and the removal
  of the old 0.3-second debounce.

## 0.1.16 — Swift Playgrounds viewport compatibility

- Remove the `PaperMarkupViewController.Delegate` conformance because the
  physical iPad Swift Playgrounds SDK rejects it even though Xcode 26 accepts
  the same source.
- Restore viewport sampling through a main-actor task, using an approximately
  33-millisecond interval only to detect changes and no post-gesture debounce.
- Start high-resolution rendering immediately when a changed frame is detected,
  while retaining the one-active plus one-latest-pending work bound from
  `0.1.14`.
- Preserve the removal of the former fixed 0.3-second delay.

## 0.1.15 — Swift Playgrounds delegate compatibility

- Mark the main-actor PaperKit viewport delegate conformance as
  `@preconcurrency`, matching Swift's documented interoperability path for a
  UI delegate protocol whose requirement lacks actor isolation.
- Fix the Swift Playgrounds Swift 6 error that reported
  `PaperKitPDFViewportObserver` did not conform to
  `PaperMarkupViewController.Delegate`.
- Add a strict Swift 6 concurrency build for the PaperKit path to the Xcode 26
  CI job so the package's default Swift 5 language mode cannot hide this class
  of device-side compiler error again.
- Explicitly isolate the UIKit-only `PencilPageInkPresentation` helper to the
  main actor after the new strict build exposed its previously implicit UI
  isolation requirement.
- Keep tool application on the main actor, replace the non-Sendable block
  notification token with UIKit's selector observer, and capture raster limits
  before entering background rendering closures for Swift 6 safety.

## 0.1.14 — Immediate adaptive PDF detail rendering

- Remove the fixed 0.3-second settle delay and the 0.1-second viewport polling
  timer from the adaptive PaperKit PDF diagnostic.
- Observe PaperKit's official visible-frame delegate callback and request the
  high-resolution PDF region as soon as the visible content frame changes.
- Bound detail work to one active render and one replaceable pending request,
  so repeated pan and pinch updates cannot build an unbounded rendering queue.
- Keep only the latest pending viewport and discard completed images that no
  longer match it.
- Leave PaperKit handwriting correction and the system tool-picker contents
  unchanged; those remain separate physical-device follow-ups.

## 0.1.13 — Adaptive PaperKit PDF diagnostic

- Keep the accepted PaperKit writing, erasing, zoom, undo, persistence, and
  system `PKToolPicker` path while removing `PDFView` from the PDF diagnostic.
- Replace the visible `CATiledLayer` PDF background with a complete page image
  that appears atomically, so pages no longer fill in as rectangular tiles.
- Render the base page at four pixels per PDF point with bounded dimensions and
  pixel count instead of allocating an unbounded maximum-zoom bitmap.
- Observe PaperKit's visible content frame and, after pan or pinch settles,
  rerender only that expanded visible region from the original PDF at 1.2 times
  the device presentation density. The completed region replaces the prior
  detail image atomically.
- Double the PaperKit logical page coordinates to approximately match the
  physically accepted `0.1.4` standalone canvas density.
- Add thin pen and highlighter presets to the system tool picker while keeping
  Apple's default tool items available.
- Store the adaptive diagnostic PDF and `PaperMarkup` files separately from
  the earlier tiled experiment, preserving all previous test data.

## Unreleased — Native PDFKit/PencilKit production editor

- Move the noninteractive sharp renderer out of PDFKit's private page
  hierarchy and inside the returned `PKCanvasView`. This preserves the exact
  top-level overlay topology that accepted Pencil input in `0.1.8` while
  retaining the zoom-aware display that sharpened restored ink in `0.1.9`.
- Add `VERSION.md` so the exact source version resolved by Swift Playgrounds is
  visible directly in the package navigator.
- Restore the verified physical-device input topology by returning the native
  `PKCanvasView` itself from `PDFPageOverlayViewProvider`. Attach the sharp
  renderer as a noninteractive sibling in the same page container instead of
  wrapping the canvas in a generic overlay view.
- Keep the resting native canvas layer at one-percent opacity instead of fully
  transparent so PencilKit continues to begin pen, highlighter, and eraser
  input sequences while the sharp tiled drawing remains visually dominant.
- Add a page-local, zoom-aware `CATiledLayer` display for resting PencilKit
  drawings. It renders bounded tiles from the original `PKDrawing` strokes at
  the requested presentation scale instead of magnifying the live canvas's
  cached surface.
- Keep the native `PKCanvasView` visible while a tool is active, then switch
  back to the high-resolution display after the Pencil is lifted. Input,
  erasers, undo, persistence, and PDF page coordinates remain owned by the
  existing PencilKit canvas.
- Use PencilKit's supported `.pencilOnly` drawing policy so a finger navigates
  the PDF instead of producing ink, and stop mutating the native drawing
  recognizer's `allowedTouchTypes`.
- Remove the page canvas's forced one-times zoom and disabled-scroll settings,
  which could leave PencilKit's rendered surface magnified by PDFKit without a
  corresponding native rendering update at high zoom.
- Fix a physical iPadOS 26 stack-overflow crash at the beginning of the first
  Pencil stroke by moving `PKCanvasViewDelegate` callbacks to a separate,
  retained observer instead of making the `PKCanvasView` subclass its own
  delegate.
- Keep `PDFView` as the only owner of PDF layout, scrolling, zooming, page
  rotation, and crop-box transforms.
- Replace the Pumice-derived manual touch sampler, `CAShapeLayer` preview, and
  synthesized `PKStroke` path with PencilKit's native drawing recognizer and
  renderer.
- Match Apple's overlay example with `.anyInput`, restrict the recognizer to
  Apple Pencil, and make PDFKit's pan gesture wait for native drawing input.
- Add native PencilKit stroke and partial erasers.
- Add Apple Pencil double-tap switching between eraser and the most recently
  used pen or highlighter.
- Lower the custom ink-width range to 0.25 points and remove the forced
  eight-point highlighter minimum.
- Retire the tiled PaperKit PDF experiment from the production direction; its
  public diagnostic remains available only for comparison.

## Unreleased — PaperKit PDF-page diagnostic

- Add public `StudyCoachPaperKitPDFDiagnosticView` without changing the
  production root or PencilKit PDF overlays.
- Import and locally retain a diagnostic PDF by SHA-256 content identity.
- Render each crop-box-sized PDF page through a tiled view beneath PaperKit so
  background and ink share PaperKit's pan and zoom transform.
- Persist one atomic `PaperMarkup` per diagnostic document and page, including
  page navigation and relaunch restoration.
- Remove the redundant custom tool-display control from this second diagnostic;
  the system PaperKit/PencilKit tool UI remains authoritative.

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
