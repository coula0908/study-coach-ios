# Changelog

## 0.1.24 — Document tabs and contextual tool controls

- Move open PDF names into a persistent, horizontally scrollable document-tab
  bar at the top; tapping a tab saves the outgoing page and loads only the
  selected PDF document into memory.
- Allow selecting multiple PDFs in one import and retain their tab metadata
  across launches without retaining every `PDFDocument` in memory.
- Put the six large, centered tool icons in the primary tool row and move page,
  undo, redo, and save actions to a separate compact page overlay.
- Show the selected tool's controls in a second horizontally scrollable row;
  tapping the already-selected tool toggles this row without changing its
  native PaperKit tool.
- Replace ten permanently visible width targets with one 180-point step slider
  and the current exact width number for pen, marker, and eraser.
- Order pen and marker controls as quick colors then width, and eraser controls
  as width then whole-stroke, partial, and precision modes.
- Construct the native marker with its selected azimuth instead of mutating a
  finished tool, and keep the selected nonzero width when constructing the
  vector whole-stroke eraser.
- Preserve the accepted PaperKit handwriting engine, PDF geometry,
  renderer/tile cache, first-frame activation, and PaperMarkup files.

## 0.1.23 — Compact scrollable toolbox and readable marker

- Replace the tall labeled tool dock plus separate settings tray with two
  narrow centered capsules: one document/navigation row and one icon-first,
  horizontally scrollable tool/style row.
- Keep Korean text out of the visible tool row while retaining Korean
  accessibility labels for VoiceOver.
- Keep every setting in the single scrollable row so narrow layouts reveal
  additional widths, colors, marker opacity, marker angle, and eraser modes by
  swiping instead of consuming more PDF height.
- Add a persistent 10–80% highlighter opacity control with a readable 35%
  default and apply that alpha directly to the native marker color.
- Replace sub-minimum ink choices that could clamp to nearly identical native
  widths with visibly separated ten-step pen and highlighter ranges.
- Preserve previously saved palette JSON by defaulting only the newly absent
  opacity field during decoding.
- Preserve the accepted PaperKit handwriting engine, Pencil interaction,
  first-frame activation hotfix, PDF geometry, renderer, tile cache, and
  PaperMarkup persistence unchanged.

## 0.1.22 — Swift Playgrounds first-frame hotfix

- Fix the physical `0.1.21` launch regression where Swift Playgrounds showed a
  black screen and stopped the preview after an update exceeded five seconds.
- Do not assign `PaperMarkupViewController.drawingTool` while SwiftUI is still
  creating or updating the controller representable.
- Return the first visible frame, then activate the current tool on the next
  main-actor turn.
- Cache the last applied palette state so renderer status and unrelated SwiftUI
  updates cannot repeatedly reassign the same PaperKit tool or first responder.
- Preserve the `0.1.21` toolbar, all stored PDF/PaperMarkup data, the accepted
  renderer, and every approved tool setting. Physical iPad confirmation passed;
  the user also noted a longer launch time than before.

## 0.1.21 — Precise note-app toolbar and structured content

- Replace the isolated diagnostic's rough StudyCoach/Apple A/B toolbar with a
  polished document bar, note-tool dock, and tool-specific settings tray.
- Make StudyCoach own native PaperKit tool values directly instead of keeping a
  hidden `PKToolPicker` as the parameter or hardware-event authority.
- Add independent 10-step pen, highlighter, and eraser widths; six editable
  quick-color slots per ink tool; three marker azimuth choices; and persistent
  tool preferences.
- Add fixed-width precision, touched-part bitmap, and whole-stroke erasers plus
  the native PencilKit lasso.
- Handle Apple Pencil double tap and squeeze through `UIPencilInteraction` and
  the user's system-preferred Pencil actions.
- Add PaperKit-native text boxes and image elements. Image insertion preserves
  the source pixel dimensions, including large originals, while fitting only
  the initial on-page frame to the visible page area.
- Keep the accepted `0.1.19` PDF base/tile renderer, PaperKit viewport,
  page-coordinate transform, gestures, and per-page PaperMarkup format
  unchanged.
- Defer audio until the document persistence format is stable. Patterned
  freehand ink remains an isolated future experiment because native
  `PKInkingTool` has no public dash-pattern control.

## 0.1.20 — Isolated StudyCoach toolbar bridge

- Keep `PaperMarkupViewController` and the accepted `0.1.19` PDF renderer,
  viewport, page coordinates, gestures, and persistence format unchanged.
- Add a minimal StudyCoach toolbar for pen, highlighter, eraser, undo, and
  redo above the isolated PaperKit PDF editor.
- Keep the configured `PKToolPicker` active while its system palette is hidden,
  following Apple's PaperKit guidance so Pencil double tap and squeeze can
  continue to participate in the system tool state.
- Add an Apple/StudyCoach segmented control for immediate A/B testing and a
  safe return to the visible system palette.
- Synchronize app-selected tools into `PKToolPicker.selectedToolItem` and
  reflect system selection changes back through `PKToolPickerObserver` without
  constructing Pencil strokes or installing a competing gesture recognizer.
- Preserve tool selection when PaperKit recreates the controller for a page.
- Add focused tests for the default selection, app/system selection reflection,
  and palette visibility independent of the selected tool.

## 0.1.19 — Stable high-resolution tiles during fixed-scale pan

- Replace the single adaptive detail bitmap with a page-coordinate tile cache
  modeled on established `CATiledLayer` and mature PDF-viewer rendering
  patterns.
- Separate scale changes from translation: suspend transient render requests
  during pinch, while retaining already completed tiles on screen.
- During one-finger pan and inertial scrolling, keep existing sharp tiles and
  request only missing visible and neighboring tiles at the unchanged level of
  detail.
- Use 512-pixel tiles, half-octave detail levels, visible-first ordering, a
  two-tile prefetch ring, and LRU-bounded reuse of up to 96 completed tiles.
- Keep the complete bounded page image underneath every tile so an unfinished
  region never appears white or blank; publish completed tiles without an
  appearance animation.
- Remove normal per-render progress/completion messages so background tile
  work cannot make the reading UI flash during navigation.
- Add planner tests proving that fixed-scale pans reuse the same detail level
  and overlapping tile keys and that the base image remains authoritative when
  its density is sufficient.

## 0.1.18 — Render once after pan and inertial scrolling end

- Remove the permanent 33-millisecond viewport sampler that made every
  one-finger pan position eligible for a new high-resolution render.
- Observe the existing UIKit pan and pinch recognizers in PaperKit's view
  hierarchy without replacing delegates or adding competing recognizers.
- Keep the complete base page visible throughout finger movement, a stationary
  finger hold, inertial scrolling, and zoom bouncing.
- Submit one final visible region only after the last gesture ends and UIKit
  reports that navigation motion has stopped; no fixed post-gesture delay is
  added.
- Prevent base/detail image replacement from repeatedly making PaperKit ink
  appear to shake during one-finger panning.

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
