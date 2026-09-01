# Validation log

## Current status

- Repository structure: passed `scripts/validate-repository.ps1` on 2026-09-01
- Apple toolchain compilation: passed on GitHub Actions with Xcode 16.4 on 2026-09-01
- iPad Simulator unit tests: 4 passed, 0 failed on 2026-09-01
- Swift Playgrounds package import: passed on physical iPadOS 26 with tag `0.1.0`
- PDF display and navigation: passed on physical iPadOS 26; no stutter reported
- PencilKit behavior: Apple Pencil writing passed on physical iPadOS 26 with `0.1.2`; the user reported that the app launched and handwriting worked correctly
- PaperKit diagnostic: implemented independently from the production root; Apple CI and physical Swift Playgrounds testing pending

Do not mark the MVP complete until the Pencil input fix and the remaining acceptance checks pass in Swift Playgrounds on the target iPad.

## Apple toolchain record

### Pumice-derived Pencil input path

- Date: 2026-09-01
- GitHub commit: `6e1e0f05e5614ae855aeb938135ead9af2461b9d`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33482554143>
- Toolchain: Xcode 16.4 (build 16F6), iOS Simulator SDK 18.5
- Build result: `StudyCoachCore` and `StudyCoachCoreTests` compiled successfully for iOS Simulator
- Test result: 4 tests executed, 0 failures
- Added coverage: the Pumice-derived Pencil-only path creates a `PKStroke`, survives a `PKDrawing` data round trip, and supports undo and redo
- Not covered by CI: physical Apple Pencil event delivery through PDFKit on iPadOS 26; this remains the required `0.1.2` device acceptance test

### Earlier package baseline

- Date: 2026-09-01
- GitHub commit: `9497e1d594be1b16de2bb82919c5eeb8752f1d9c`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33478587399>
- Toolchain: Xcode 16.4 (build 16F6), iOS Simulator SDK 18.5
- Build result: `StudyCoachCore` and `StudyCoachCoreTests` compiled successfully for iOS Simulator
- Test destination: an available iPad Simulator selected dynamically by the workflow
- Test result: 3 tests executed, 0 failures
- Covered behavior: public root-view creation, per-document/per-page drawing-data separation and round trip, stable content identity, last-page restoration
- Not covered by CI: Swift Playgrounds package import, Apple Pencil/finger interaction, visual PDF coordinate alignment, background/relaunch behavior on physical iPadOS 26 hardware

## iPad acceptance record

### Physical-device pass: 0.1.2

- Date: 2026-09-01
- iPadOS version: 26
- Git tag: `0.1.2`
- Package import and app launch: passed
- Apple Pencil writing: passed; the user reported that writing works correctly
- Production root preserved: yes
- Not yet reported for this pass: highlighter, both eraser behaviors, relaunch restoration, rotated/cropped pages, and maximum-zoom coordinate alignment

This confirms the Pumice-derived Pencil input route reached the physical Pencil.
It does not accept the later straight-line, partial-eraser, double-tap, or
high-resolution rendering requirements.

### Physical-device pass: 0.1.0

- Date: 2026-09-01
- iPadOS version: 26
- Git tag: `0.1.0`
- Package import result: passed after adding the semantic-version tag
- App launch and PDF display: passed
- PDF navigation and performance: passed; the user reported no stutter
- Pencil/finger separation result: failed
- Observed issue: pen and highlighter did not draw; Apple Pencil gestures moved the PDF instead
- Root cause: `PencilPageCanvasView.hitTest` attempted to identify Pencil touches before PencilKit's drawing recognizer received them and could return `nil` for real Pencil input
- Fix: remove the custom `hitTest` override and use PencilKit's `.pencilOnly` drawing policy
- Fix status: implemented after the `0.1.0` device pass; physical retest required

### Physical-device pass: 0.1.1

- Date: 2026-09-01
- iPadOS version: 26
- Git tag: `0.1.1`
- Package update result: passed; the `0.1.1` package was explicitly selected and added
- App launch and PDF display: passed
- Pencil/finger separation result: failed
- Observed issue: pen, highlighter, and eraser did not act on the canvas; Apple Pencil input continued to move the PDF
- Root cause: removing the custom canvas `hitTest` override was insufficient; on iPadOS 26, PencilKit's drawing recognizer can still fail to activate inside a PDFKit page overlay and let Pencil input fall through to PDF scrolling
- Follow-up implementation: adopt the MIT-licensed, App-Store-shipped Pumice Pencil-only `UIGestureRecognizer` input path; disable PencilKit's failing internal drawing recognizer while retaining `PKCanvasView` for rendering and `PKDrawing` persistence
- Additional setup: install the overlay provider before loading the PDF, enable markup mode, and enable the visible PDF page containers
- Follow-up fix status: implemented for `0.1.2`; physical retest required

### Next physical-device pass

- Date:
- iPad model:
- iPadOS version: 26
- Swift Playgrounds version:
- Git commit/tag:
- Package import result:
- PDF import result:
- Pencil/finger separation result:
- Zoom and coordinate-alignment result:
- Page navigation restoration result:
- Relaunch restoration result:
- Large-PDF observation:
- Known issues:

## PaperKit standalone diagnostic

- Production entry point: unchanged `StudyCoachRootView()`
- Diagnostic entry point: `StudyCoachPaperKitDiagnosticView()`
- PDFKit integration: intentionally not implemented in this spike
- Windows validation: passed (`scripts/validate-repository.ps1` and `git diff --check`) on 2026-09-01
- Xcode 16 fallback compilation: pending
- Xcode 26 PaperKit compilation: pending
- iPad Simulator construction smoke test: pending
- Physical iPadOS 26 Swift Playgrounds import and interaction checklist: pending
- Procedure: `docs/PAPERKIT_DIAGNOSTIC.md`

