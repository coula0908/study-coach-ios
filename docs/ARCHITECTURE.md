# StudyCoachCore architecture

## Status

This document fixes the design boundaries for the first PDF-annotation MVP. The viewer, page overlay, tool state, and persistence layers are implemented. Apple-toolchain compilation and interaction testing on the target iPadOS 26 device remain required.

The standalone `StudyCoachPaperKitDiagnosticView` passed on the target iPadOS
26 device. The later PDF diagnostic exposed avoidable custom-renderer costs:
PDF tiles became visible while pages loaded, the minimum ink width was too
large, and maximum-zoom input did not preserve the accepted handwriting feel.
PaperKit therefore remains an isolated comparison diagnostic, not the PDF
renderer or production annotation engine.

The production viewer follows Apple's WWDC22 design: one `PDFView` owns PDF
layout, scrolling, zoom, crop-box transforms, and rotation, while
`PDFPageOverlayViewProvider` supplies one native `PKCanvasView` per visible
page. The small SwiftUI/provider plumbing is also cross-checked against the
MIT-licensed `DannyBehar/PDFViewer` package. No source dependency is required.

## Module boundary

`StudyCoachCore` is a single Swift Package library product. The app playground owns only its app lifecycle and imports the library. The package owns the study UI, PDF workflow, annotations, and local persistence.

The package must not depend on an Xcode project or on app-target-only generated files.

## Planned composition

```text
StudyCoachRootView
└── StudyCoachWorkspaceView
    ├── DocumentPicker
    ├── PDFWorkspaceController
    │   ├── PDFView
    │   └── page-bound PencilKit overlays
    └── AnnotationToolbar
```

The UIKit components should be wrapped in SwiftUI with `UIViewControllerRepresentable` or `UIViewRepresentable`. SwiftUI remains responsible for composition; PDFKit remains responsible for page geometry and viewport interaction.

## Coordinate contract

The viewer must not persist screen pixels or coordinates relative to the outer SwiftUI layout.

1. Each annotation belongs to a stable document identity and a zero-based PDF page index.
2. Each live PencilKit canvas belongs to exactly one PDF page overlay.
3. PDFKit supplies the transform between a page and the viewport, including crop box, page rotation, zoom, and scroll offset.
4. The drawing is serialized from the page-bound canvas as `PKDrawing.dataRepresentation()`.
5. When PDFKit recreates an overlay, the saved drawing is restored into a canvas bound to that same page.
6. Any export or hit-testing feature must explicitly convert through PDFKit page APIs; it must not reproduce zoom math independently.

Before the first MVP is declared complete, verify at minimum portrait and landscape pages, a rotated page, zoom before drawing, zoom after drawing, page navigation, and app relaunch.

## Overlay lifecycle

Use a page-overlay provider supported by PDFKit rather than a global canvas. The intended lifecycle is:

1. PDFKit asks for an overlay for a visible page.
2. The package creates or reuses a lightweight page canvas.
3. The package restores that page's `PKDrawing`.
4. The canvas uses PencilKit's native enabled drawing recognizer with the
   supported `.pencilOnly` drawing policy. Production code must not mutate the
   recognizer's `allowedTouchTypes`; fingers remain available for navigation.
5. In `willDisplayOverlayView`, PDFKit's pan gesture is required to wait for
   the active canvas drawing gesture to fail. This is the failure relationship
   hook Apple documents for interactive overlays.
6. PencilKit owns raw Pencil sampling, prediction, pressure/tilt handling,
   rendering, erasing, and undo registration. Production code must not build
   ordinary handwritten `PKStroke` values from a `UIBezierPath`.
7. A separate delegate object observes each canvas. A `PKCanvasView` subclass
   must never assign itself as its own delegate: on the target iPadOS 26 build,
   PencilKit recursively enters `_canvasViewWillBeginDrawing:` when the first
   Pencil stroke begins and overflows the main-thread stack.
8. When PDFKit displays an overlay, interaction is enabled on the canvas, its
   page-container ancestors, and the document view.
9. Do not pin the page canvas's internal scroll and zoom state to one on every
   layout pass. PDFKit may resize or transform the page overlay while zooming,
   and PencilKit must remain able to update its native rendering state.
10. The live `PKCanvasView` remains authoritative for tool interaction, undo,
    erasing, and persisted `PKDrawing` data. While a tool is active it is the
    visible renderer, preserving PencilKit's native low-latency input path.
    PDFKit receives this canvas itself as the top-level page overlay; wrapping
    it in a generic view prevents every PencilKit tool from receiving input on
    the physical iPadOS 26 device.
11. At rest, a noninteractive `CATiledLayer` view inside the returned canvas
    renders bounded regions from the
    same `PKDrawing` using `image(from:scale:)`. This lets Core Animation ask
    for magnified levels of detail without creating a full-page high-resolution
    bitmap or changing page coordinates.
12. Do not add the renderer as a sibling in PDFKit's private page-container
    hierarchy and do not change the canvas layer opacity. Both the wrapper and
    sibling experiments prevented native tools on the physical device. The
    canvas and its internal noninteractive renderer must remain the only
    package-owned page-overlay subtree.
13. Changes are autosaved with a short debounce.
14. When the overlay is about to be discarded, pending drawing data is saved immediately.
15. The internal presentation and canvas are released so large PDFs do not create an editor
    or tiled ink renderer for every page.

If iPad testing shows that a specific PDFKit overlay API does not preserve PencilKit geometry correctly, keep the page-bound invariant and document the replacement design before implementing it.

## Document identity and storage

The first implementation should derive a stable identifier from the PDF file contents, preferably SHA-256. This allows the same PDF selected from the Files app again to recover its drawings even if its security-scoped URL changes.

Planned local layout:

```text
Application Support/StudyCoachCore/
└── Documents/
    └── <document-id>/
        ├── metadata.json
        └── drawings/
            ├── 0.drawing
            ├── 1.drawing
            └── ...
```

Writes must be atomic. Metadata should include a schema version so stored drawings can be migrated later. The source PDF is not rewritten for the first MVP.

## Tool state

The toolbar owns the selected tool, color, and width. A newly created page canvas receives the current tool state. Undo and redo apply to the currently visible page canvas and must mark that page dirty for persistence.

The first supported tools are pen, translucent highlighter, stroke eraser,
partial eraser, undo, redo, width, and color. Apple Pencil double tap toggles
between the most recently used inking tool and the eraser. The custom width
control exposes values down to 0.25 page points and does not impose an
additional highlighter minimum.

## External references

- Apple, ["What's new in PDFKit" (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10089/):
  the authoritative `PDFPageOverlayViewProvider` plus `PKCanvasView` lifecycle.
- [`DannyBehar/PDFViewer`](https://github.com/DannyBehar/PDFViewer) (MIT): a small SwiftUI wrapper confirming the same
  provider boundary; referenced but not added as a package because its current
  Swift toolchain requirement is newer than this package's 5.9 manifest.
- [`theagitist/Pumice`](https://github.com/theagitist/Pumice) (MIT): retained as a fallback reference for iPadOS 26
  Pencil routing and PDF Ink export, but its manual stroke path is no longer
  used by the production editor.
- [`TheProductArchitect/cecilias-notes`](https://github.com/TheProductArchitect/cecilias-notes) (MIT): retained as a reference for
  advanced PencilKit tools and bounded lazy canvas mounting.

## Delivery stages

1. Package import smoke test in Swift Playgrounds.
2. PDF picker and read-only PDF navigation.
3. One page-bound PencilKit overlay with correct gesture separation.
4. Per-page overlay lifecycle and page navigation retention.
5. Atomic persistence and relaunch restoration.
6. Toolbar completion and large-PDF memory checks.
7. iPad acceptance pass documented in `VALIDATION.md`.
