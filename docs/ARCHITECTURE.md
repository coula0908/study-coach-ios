# StudyCoachCore architecture

## Status

This document fixes the design boundaries for the first PDF-annotation MVP. The viewer, page overlay, tool state, and persistence layers are implemented. Apple-toolchain compilation and interaction testing on the target iPadOS 26 device remain required.

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
4. PencilKit's internal overlay drawing recognizer is disabled because it did
   not activate reliably on the target iPadOS 26 device.
5. A Pencil-only `UIGestureRecognizer`, adapted from the MIT-licensed Pumice
   app's iPadOS 26-tested implementation, collects coalesced Pencil samples.
   Finger touches are rejected and remain available to PDFKit.
6. The recognizer converts completed strokes into `PKStroke` values, while
   `PKCanvasView` remains responsible for rendering and `PKDrawing` storage.
7. When PDFKit displays an overlay, interaction is enabled on the canvas, its
   page-container ancestors, and the document view.
8. Changes are autosaved with a short debounce.
9. When the overlay is about to be discarded, pending drawing data is saved immediately.
10. The canvas is released so large PDFs do not create a canvas for every page.

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

The first supported tools are pen, translucent highlighter, stroke eraser, undo, redo, width, and color.

## Delivery stages

1. Package import smoke test in Swift Playgrounds.
2. PDF picker and read-only PDF navigation.
3. One page-bound PencilKit overlay with correct gesture separation.
4. Per-page overlay lifecycle and page navigation retention.
5. Atomic persistence and relaunch restoration.
6. Toolbar completion and large-PDF memory checks.
7. iPad acceptance pass documented in `VALIDATION.md`.
