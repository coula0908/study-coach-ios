# PaperKit diagnostic spike

## Scope

This spike answers one question before the production annotation engine changes:
can iPadOS 26 Swift Playgrounds import PaperKit, display an editable
`PaperMarkupViewController`, use the system drawing and insertion tools, and
round-trip `PaperMarkup` data?

The spike is intentionally isolated from `StudyCoachRootView`, PDFKit,
`PencilPageCanvasView`, and production drawing persistence. It does not prove
that PaperKit can be used as a PDF page overlay. That requires a separate
second spike after this standalone test passes on the target iPad.

The implementation uses Apple PaperKit and PencilKit APIs directly. No source
was copied from the unlicensed PaperKit SwiftUI demo.

## Temporary Swift Playgrounds entry point

Change only the root view in the app playground's `ContentView.swift`:

```swift
import SwiftUI
import StudyCoachCore

struct ContentView: View {
    var body: some View {
        StudyCoachPaperKitDiagnosticView()
    }
}
```

The production entry point remains available and unchanged. Restore it after
the test:

```swift
import SwiftUI
import StudyCoachCore

struct ContentView: View {
    var body: some View {
        StudyCoachRootView()
    }
}
```

If the diagnostic shows `PaperKit unavailable`, record that exact result. It
means the Swift Playgrounds toolchain compiling the package does not expose the
PaperKit module, even if the device itself runs iPadOS 26.

## Controls

- **도구 표시**: makes the `PKToolPicker` active for the PaperKit controller.
- **요소 +**: presents PaperKit's `MarkupEditViewController` for shapes, lines,
  text, images, and other supported elements.
- **실행 취소 / 다시 실행**: calls the PaperKit controller's undo manager.
- **저장**: serializes the current `PaperMarkup` using
  `dataRepresentation()` and writes it atomically under Application Support.
- **저장본 열기**: creates a new `PaperMarkup` from the saved representation
  and assigns it back to the live controller.

The diagnostic uses a lined white background and allows a zoom range from
0.25x to 8x so resolution and coordinate behavior are easy to inspect.

## Physical iPadOS 26 checklist

Record pass, fail, or unavailable for every item:

1. Package version containing the diagnostic imports successfully.
2. `StudyCoachPaperKitDiagnosticView` compiles in the app playground.
3. A lined PaperKit canvas appears instead of the unavailable message.
4. The system tool picker appears.
5. Apple Pencil pen drawing works.
6. Highlighter drawing works.
7. Stroke eraser works.
8. Partial eraser is available and works, if exposed by the system picker.
9. Undo and redo work from both the system UI and diagnostic buttons.
10. Lasso selection works.
11. A selected item can move, resize, and rotate.
12. **요소 +** can insert a line or shape.
13. **요소 +** can insert a text box and edit its text.
14. **요소 +** can insert an image from an allowed system source.
15. Apple Pencil double-tap performs the configured system action on a
    supported Pencil model.
16. Pinch zoom reaches a clearly enlarged view.
17. Completed ink remains sharp at high zoom.
18. A freehand stroke does not visibly change shape when Pencil lifts.
19. **저장** reports success.
20. **저장본 열기** restores all drawings and inserted elements.
21. Restored drawings and elements remain editable.
22. Switching temporarily back to `StudyCoachRootView` still launches the
    existing PDF app unchanged.

For failures, capture a screenshot and the exact tool or gesture used. For the
zoom check, compare the same thin diagonal pen stroke at fit scale and maximum
zoom, after waiting one second for rendering to settle.

## Validation boundary

- Windows static validation can verify conditional compilation guards, public
  API shape, repository structure, and absence of secrets.
- The `macos-15` GitHub job compiles the fallback path with Xcode 16.4, where
  PaperKit is unavailable.
- The `macos-26` GitHub job compiles the actual PaperKit path with an Xcode 26
  SDK and runs the PaperKit construction smoke test on an available iPad
  Simulator.
- Simulator success still does not validate Apple Pencil hardware gestures,
  tool-picker behavior in Swift Playgrounds, or visual zoom quality.
- Only the physical iPadOS 26 checklist can accept this standalone spike.

## Decision after this spike

- Standalone PaperKit succeeds: proceed to a separate PDF-page overlay spike.
- Standalone succeeds but the later PDF overlay fails: retain PencilKit for PDF
  ink and consider PaperKit only for blank notes or structured elements.
- Import or standalone behavior fails: stop investing in PaperKit and improve
  the current PencilKit engine using the documented public-source references.
