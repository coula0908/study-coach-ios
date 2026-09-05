# Editor workflow and persisted-ink repair — 0.1.26

## User scope and physical evidence

The 0.1.25 user test reported that dotted preview disappears after Pencil lift,
0/90-degree highlighter becomes too faint on lift, and vector eraser has no
contact cursor. Requested workflow: automatic saving, annotated PDF export,
left document tabs and right actions on one top row, and vertical/horizontal
page scrolling in the top-right More menu. Both marker ends should be rounded.

## Implemented behavior

- Observe `paperController.markup` with Apple's Observation tracking. Changes
  enqueue atomic snapshots, serialized per file across page controllers. Page
  and document switches await pending saves; failed saves leave the page open.
  Background entry obtains a UIKit background task while queued saves finish.
- Export waits for pending saves and creates a new PDF through a file-backed
  Core Graphics PDF context. Each source PDF page is drawn, then its saved
  PaperMarkup is drawn with `RenderingOptions(darkUserInterfaceStyle: false)`.
  UIActivityViewController offers Files/sharing. Source PDFs are untouched.
- Top row: left-aligned open documents; right-aligned page arrows/count,
  undo/redo, share/export icon, and More. Drawing palettes remain floating.
- More chooses vertical/horizontal page-edge navigation, persisted in defaults.
  PaperKit remains the only pan/zoom owner. A one-finger outward swipe beginning
  at the current page boundary turns one page on release; zoomed interior drags
  remain pans. This is paginated navigation, not a continuous multi-page strip.
  Continuous simultaneous page visibility is still future layout work.
- Dots use a nondegenerate four-control-point spline clipped by a circular mask,
  instead of a near-zero-length two-point pen path. Preview and commit both use
  the same PencilKit drawing construction. Coordinate conversion uses the actual
  content view's UIView transform, rather than estimated viewport ratios.
- For explicit 0/90-degree markers, round pen ink gets alpha once (on PKInk),
  with point opacity 2. A fixed affine ellipse transform shapes both rounded
  ends; inverse-transformed centreline points keep the stroke on the user's
  path. Native solid pen and accepted 45-degree marker remain native.
- Whole-stroke eraser receives a nonpreventing, noncancelling Pencil-contact
  observer, so its circle appears during contact as well as supported hover.
  It represents the requested hit width; native whole-stroke semantics still
  remove a complete touched stroke. Dotted gestures contain individual dots.

## Public implementation evidence

Reviewed 2026-09-05. No third-party code copied and no dependencies added.

- Apple PaperMarkupViewController: observable markup and official autosave
  observation pattern: https://developer.apple.com/documentation/paperkit/papermarkupviewcontroller
- Apple PaperMarkup rendering: https://developer.apple.com/documentation/paperkit/papermarkup/draw(in:frame:options:)
- Apple PKStrokePoint opacity is 0–2 and multiplies ink opacity:
  https://developer.apple.com/documentation/pencilkit/pkstrokepoint-swift.struct/opacity
- Apple UIGestureRecognizer canPrevent/canBePrevented support passive observation:
  https://developer.apple.com/documentation/uikit/uigesturerecognizer/canprevent(_:)
- Goodnotes More → Scrolling Direction:
  https://support.goodnotes.com/hc/en-us/articles/7353695996559-Change-the-scrolling-direction-in-Goodnotes
- Pumice, MIT, revision `a688aae2e6bce069ee256063c2a53afdcfe7de21`:
  https://github.com/theagitist/Pumice/blob/a688aae2e6bce069ee256063c2a53afdcfe7de21/Packages/PumiceCore/Sources/PumiceCore/InkSerialization/StrokeGeometry.swift
  Studied page-coordinate stroke geometry, stable endpoint treatment, and
  README's autosave workflow. Its manual PDF annotation engine is not imported
  into the accepted PaperKit renderer.

## Acceptance boundary

Automated tests render dots, serialize/reload PaperMarkup, verify surviving
black pixels, compare marker density before/after PKDrawing serialization,
check 0/90-degree geometric extents, verify ordered saves, and open the exported
two-page PDF with checks for both original blue content and black annotations.
Physical Pencil routing, end-cap appearance, save-on-background, export
alignment, and the swipe-at-edge experience still require the user's iPad.
No arbitrary PDF geometry/rotation correction is claimed in this version.
