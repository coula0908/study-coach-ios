# Validation log

## Current status

- Repository structure: passed `scripts/validate-repository.ps1` on 2026-09-02
- Apple toolchain compilation: passed on GitHub Actions with Xcode 16.4 on 2026-09-01
- iPad Simulator unit tests: 4 passed, 0 failed on 2026-09-01
- Swift Playgrounds package import: passed on physical iPadOS 26 with tag `0.1.0`
- PDF display and navigation: passed on physical iPadOS 26; no stutter reported
- PencilKit behavior: Apple Pencil writing passed on physical iPadOS 26 with `0.1.2`; the user reported that the app launched and handwriting worked correctly
- PaperKit standalone diagnostic: Xcode 16.4 and Xcode 26.6 CI passed; physical iPadOS 26 launch, writing feel, and high-zoom ink quality passed with `0.1.4`
- Native PDFKit/PencilKit revision: Xcode 16.4 and Xcode 26.6 builds and iPad
  Simulator tests passed on 2026-09-02; the `0.1.7` physical iPadOS 26 retest
  confirmed the delegate crash is fixed and Apple Pencil writing works, but
  also found that fingers produce ink and PencilKit ink appears pixelated at
  high PDF zoom

Do not mark the MVP complete until the native Pencil input path and the
remaining acceptance checks pass in Swift Playgrounds on the target iPad.

## Pinch-end-only detail rendering: 0.1.17

- Date: 2026-09-04
- Required behavior: no high-resolution PDF detail render while a two-finger
  pinch is `.began` or `.changed`, including when both fingers pause on-screen
- Completion behavior: submit the final visible frame once when the observed
  existing PaperKit pinch recognizer reaches `.ended` or `.cancelled`
- Gesture ownership: unchanged; no delegate replacement and no added competing
  recognizer, only an additional target on recognizers already owned by PaperKit
- Compatibility fallback: the 33-millisecond main-actor sampler remains, but
  only records and invalidates detail while any observed pinch is active
- Fixed post-gesture delay: none
- Windows repository validation: passed (`scripts/validate-repository.ps1` and
  `git diff --check`)
- Apple validation commit: `3e54f39e517e8d5fc50dfaa697472e051e265974`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33854682210>
- Xcode 16.4 fallback build and iPad Simulator tests: passed
- Xcode 26 normal build, strict Swift 6 concurrency build, and iPad Simulator
  tests: passed
- Physical iPadOS 26 acceptance: pending

## Swift Playgrounds viewport compatibility: 0.1.16

- Date: 2026-09-03
- Physical-device compiler result for 0.1.15: failed before launch with the same
  `PaperKitPDFViewportObserver` protocol-conformance error; `@preconcurrency`
  did not make the iPad Swift Playgrounds SDK accept the conformance
- Compatibility decision: remove
  `PaperMarkupViewController.Delegate` from this diagnostic entirely
- Viewport monitoring: main-actor task samples `contentVisibleFrame` about every
  33 milliseconds and immediately submits a changed frame
- Fixed post-gesture delay: none; the former 0.3-second debounce remains removed
- Render-work bound: unchanged at one active render and one replaceable latest
  pending request
- Windows repository validation: passed (`scripts/validate-repository.ps1` and
  `git diff --check`)
- Apple validation commit: `03feb6c097094ab15dd23b0eb8348ea18cb304db`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33726509583>
- Xcode 16.4 fallback build and iPad Simulator tests: passed
- Xcode 26 normal build, strict Swift 6 concurrency build, and iPad Simulator
  tests: passed
- Physical iPadOS 26 acceptance: pending

## Swift Playgrounds delegate compatibility: 0.1.15

- Date: 2026-09-03
- Physical-device compiler result for 0.1.14: failed before launch because the
  main-actor `PaperKitPDFViewportObserver` conformance crossed into the
  nonisolated `PaperMarkupViewController.Delegate` protocol in Swift 6 mode
- Fix: mark that conformance `@preconcurrency`; PaperKit is a UIKit controller
  and delivers this UI delegate callback on the main actor, while Swift inserts
  the corresponding runtime isolation check
- CI regression coverage: add an Xcode 26 build with `SWIFT_VERSION=6` and
  `SWIFT_STRICT_CONCURRENCY=complete`
- First strict-build follow-up: the viewport delegate error no longer appeared;
  the build instead exposed an existing UIKit default-value isolation error in
  `PencilPageInkPresentation`, which is now explicitly `@MainActor`
- Second strict-build follow-up: remove the non-Sendable notification token
  from controller deinitialization, isolate PencilKit tool mutation to the main
  actor, and capture immutable raster limits before background queue work
- Third strict-build follow-up: application sources passed; update the storage
  test fixture so it transfers a fresh `UserDefaults` instance into the store
  actor instead of retaining the same non-Sendable reference on both sides
- Windows repository validation: passed (`scripts/validate-repository.ps1` and
  `git diff --check` on 2026-09-03)
- Apple validation commit: `da7b228051387f6bb32b7c95cec674ae7c91b9fe`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33725498818>
- Xcode 16.4 fallback build and iPad Simulator tests: passed
- Xcode 26 normal build, strict Swift 6 concurrency build, and iPad Simulator
  tests: passed
- Physical iPadOS 26 result: failed before launch; Swift Playgrounds continued
  to reject `PaperKitPDFViewportObserver` as
  `PaperMarkupViewController.Delegate`

## Immediate adaptive detail candidate: 0.1.14

- Date: 2026-09-03
- Fixed delay: removed; there is no 0.3-second settle sleep and no 0.1-second
  polling timer
- Viewport signal: official
  `paperMarkupViewControllerDidChangeContentVisibleFrame(_:)` delegate callback
- Work bound: at most one active detail render and one replaceable latest
  request; stale completed images are discarded
- Production entry point: unchanged `StudyCoachRootView()`; physical testing
  continues through `StudyCoachPaperKitPDFDiagnosticView()`
- Windows repository validation: passed (`scripts/validate-repository.ps1` and
  `git diff --check` on 2026-09-03)
- Apple validation commit: `a4ef1259e062194ab7d3549b1bdf1821844234a8`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33723091067>
- Xcode 16.4 fallback build and iPad Simulator tests: passed
- Xcode 26 PaperKit build and iPad Simulator tests: passed, including assignment
  of the retained visible-frame delegate observer
- Physical iPadOS 26 acceptance: pending

## Adaptive PaperKit PDF candidate: 0.1.13

- Date: 2026-09-03
- Production entry point: unchanged `StudyCoachRootView()` at implementation
  time; the adaptive candidate remains `StudyCoachPaperKitPDFDiagnosticView()`
  until physical acceptance
- Interaction owner: `PaperMarkupViewController`; `PDFView` is not constructed
- Coordinate design: PaperKit bounds are two times the PDF crop-box dimensions
- Base background: complete page rendered at four pixels per PDF point, capped
  at a 4096-pixel side and 14 million pixels, then installed atomically
- Detail background: after a 0.3-second stable viewport, the visible frame plus
  18-percent overscan is rendered at 1.2 times device presentation density and
  installed atomically
- Tile behavior: no `CATiledLayer`; the complete base page remains visible
  during pan, pinch, and detail rendering
- System tools: native `PKToolPicker`, with thin pen and highlighter presets
  prepended and all Apple default items retained
- Persistence: new `PaperKitPDFAdaptive` diagnostic directory; prior PaperKit
  diagnostics and production `.drawing` files remain unchanged
- Windows repository validation: passed (`scripts/validate-repository.ps1` and
  `git diff --check` on 2026-09-03)
- Apple validation commit: `61e5c4a6dca2513b34fd89d5d50d8e3ad653a937`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33696309896>
- Xcode 16.4 fallback build and iPad Simulator tests: passed
- Xcode 26 PaperKit build and iPad Simulator tests: passed, including creation
  of a PDF fixture and execution of both full-page and visible-region rasterizers
- Physical iPadOS 26 result reported on 2026-09-03: the page appeared complete,
  with no inversion, clipping, or stretching. The user marked checklist items
  1 through 12 and 15 through 17 as passed.
- Remaining physical issue: handwriting correction felt identical to the
  earlier standalone PaperKit diagnostic; the PDF background design did not
  improve it.
- Remaining physical issue: the added thin pen did not appear. The visible
  picker contained Apple's default tools, so the custom preset is not accepted
  as working.

## Pencil-only and canvas-scaling A/B revision

- Date: 2026-09-02
- GitHub commit: `88296723dc8064374ca607c09f6aacaff0eee12b`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33643581703>
- Xcode 16.4 runner (`macos-15`): build and iPad Simulator tests passed
- Xcode 26 runner (`macos-26`): build and iPad Simulator tests passed
- Windows repository validation: passed
- Input change: `.pencilOnly` is now the sole PencilKit input classifier; the
  native drawing recognizer's `allowedTouchTypes` is no longer mutated
- Rendering A/B change: the page canvas is no longer forced back to one-times
  zoom with scrolling disabled during layout
- Physical iPadOS 26 acceptance: pending; verify finger navigation, Pencil
  writing, high-zoom ink sharpness, and PDF/ink coordinate alignment together

### Physical-device result: 0.1.8

- Date: 2026-09-02
- Finger scrolling: passed
- Two-finger zoom: passed
- Apple Pencil writing: passed
- PDF/ink coordinate alignment: passed
- High-zoom ink quality: failed; removing the canvas's forced one-times state
  did not improve the pixelated appearance
- Conclusion: the live `PKCanvasView` render surface is being magnified by the
  PDF page transform without generating a matching high-resolution level of
  detail. Input policy and page geometry are no longer part of this defect.
- Next experiment: keep the canvas as the authoritative editor, but display
  the resting `PKDrawing` through bounded, zoom-aware `CATiledLayer` tiles

### Zoom-aware ink display revision

- Date: 2026-09-03
- GitHub commit: `9494e54b030ff2e86e51d4ef207ff8a9c04f0711`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33645826515>
- Xcode 16.4 runner (`macos-15`): build and iPad Simulator tests passed
- Xcode 26 runner (`macos-26`): build and iPad Simulator tests passed
- Windows repository validation: passed
- Rendering design: native PencilKit remains visible while a tool is active;
  at rest, bounded `CATiledLayer` regions are generated from the same
  `PKDrawing` using `image(from:scale:)` with magnified levels of detail
- Full-page high-resolution bitmap allocation: not used
- Existing drawing persistence migration: not required
- Physical iPadOS 26 acceptance: pending; inspect high-zoom pen and highlighter
  sharpness, the live-to-resting transition, tile seams or flashing, finger
  navigation, coordinate alignment, erasers, undo, and restored drawings

### Physical-device result: 0.1.9

- Date: 2026-09-03
- Previously saved ink high-zoom quality: passed; user reported PaperKit-like
  sharpness from the zoom-aware tiled display
- Pen input: failed
- Highlighter input: failed
- Eraser input: failed
- Diagnosis: the resting transition set the authoritative `PKCanvasView`
  backing layer to zero opacity. Although its view remained interactive,
  PencilKit did not begin a native tool sequence on the physical device.
- Follow-up: retain the successful tiled display but keep the live canvas layer
  at one-percent opacity while resting, returning it to full opacity as soon as
  PencilKit begins a tool sequence

### Physical-device result: 0.1.10

- Date: 2026-09-03
- Pen input: failed
- Highlighter input: failed
- Eraser input: failed
- Conclusion: retaining one-percent canvas layer opacity did not restore any
  PencilKit tool. The zero-opacity diagnosis was disproved.
- Revised diagnosis: `0.1.8` returned `PKCanvasView` itself as PDFKit's page
  overlay and all three tools worked. `0.1.9` and `0.1.10` returned a generic
  wrapper containing the canvas and all three tools failed. The wrapper is the
  changed input boundary.
- Follow-up: return the native canvas as the top-level PDFKit overlay again and
  attach the already successful sharp renderer as a noninteractive sibling in
  the same PDF page container

### Physical-device result: 0.1.11

- Date: 2026-09-03
- Confirmed source version: `0.1.11`
- Pen input: failed
- Highlighter input: failed
- Eraser input: failed
- Conclusion: returning `PKCanvasView` as the top-level overlay was not enough
  while a separate sharp renderer remained in PDFKit's private page-container
  hierarchy. The added sibling still changed the physical input behavior.
- Follow-up: keep PDFKit's page hierarchy identical to the accepted `0.1.8`
  path and attach the noninteractive sharp renderer only inside the returned
  canvas. Do not dim the canvas or add another page-container sibling.
- Version visibility follow-up: add root `VERSION.md`, starting with `0.1.12`,
  so Swift Playgrounds can show the resolved source version directly

## Native PDFKit/PencilKit revision

- Date: 2026-09-02
- Basis: Apple's WWDC22 `PDFPageOverlayViewProvider` and `PKCanvasView` sample
- PDF renderer: native `PDFView`; the PaperKit `CATiledLayer` diagnostic is not
  part of `StudyCoachRootView`
- Ink input and rendering: native enabled PencilKit drawing recognizer; no
  production `UIBezierPath` sampler, live `CAShapeLayer`, or hand-built normal
  handwriting stroke
- Input separation: drawing recognizer accepts Apple Pencil touch types;
  PDFKit's pan gesture waits for that recognizer to fail
- Added tool behavior: stroke eraser, partial eraser, 0.25-point minimum width,
  and Apple Pencil double-tap pen/eraser toggle
- Windows static repository validation: passed
- GitHub commit: `2ed62ad54601134d56d217081f9d014d1c07a4bc`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33620229231>
- Xcode 16.4 / iOS 18.5 Simulator: build passed; 6 tests, 0 failures
- Xcode 26.6 / iOS 26.5 Simulator: build passed; 7 tests, 0 failures
- Physical iPadOS 26 acceptance: pending

### Physical-device pass: 0.1.7

- Date: 2026-09-02
- Device OS: iPadOS 26
- Package launch and PDF import: passed
- First Apple Pencil stroke: passed; the recursive delegate crash did not recur
- Apple Pencil writing: passed
- Finger/Pencil separation: failed; finger touches produced ink
- High-zoom ink quality: failed; ink looked pixelated instead of being
  rerendered with the earlier vector-like appearance
- Follow-up: use the supported `.pencilOnly` policy without overriding the
  native recognizer's touch types, and remove the canvas's forced one-times
  zoom and disabled-scroll configuration for a physical A/B retest

### Physical-device crash diagnosis

- Date: 2026-09-02
- Device: iPad13,8
- OS recorded by the crash report: iPadOS 26.6.1 (23G83)
- App process lifetime: approximately 2.18 seconds
- Exception: `EXC_BAD_ACCESS (SIGSEGV)`, `KERN_PROTECTION_FAILURE` in the main
  thread's stack guard
- Trigger: PencilKit handling `touchesBegan` for the first drawing sequence
- Decisive backtrace: 3,518 recursive frames of
  `-[PKCanvasView _canvasViewWillBeginDrawing:]`, reached through
  `-[UIScrollView delegate]`
- Root cause in package code: `PencilPageCanvasView` conformed to
  `PKCanvasViewDelegate` and assigned `delegate = self`
- Fix: retain a separate `PencilPageCanvasDelegate` observer and add source and
  Apple-toolchain regression checks preventing self-delegation
- Fix commit: `d2babb5a3d1566cfa6408b29c3aaf7cfbe8edeb8`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33627266823>
- Xcode 16.4 / iOS 18.5 Simulator: build and tests passed
- Xcode 26.6 / iOS 26.5 Simulator: build and tests passed
- Physical retest: pending

The next device test must check the corrected `.pencilOnly` policy with the
existing overlay interaction and gesture-priority setup. It must also check
maximum-zoom ink sharpness after removing the page canvas's forced one-times
zoom state because public reports indicate that a naively transformed
`PKCanvasView` overlay can still rasterize softly.

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
- Xcode 16 fallback compilation: passed with Xcode 16.4 (build 16F6), workflow run 12 on 2026-09-01
- Xcode 26 PaperKit compilation: passed with Xcode 26.6 (build 17F113), workflow run 12 on 2026-09-01
- iPad Simulator construction smoke test: passed; 5 tests on Xcode 16.4 and 6 tests on Xcode 26.6, 0 failures, including `testPaperKitRuntimeTypesCanBeConstructed`
- Physical iPadOS 26 Swift Playgrounds import and interaction checklist: pending
- Procedure: `docs/PAPERKIT_DIAGNOSTIC.md`

### Physical Swift Playgrounds compatibility result: 0.1.3

- Date: 2026-09-01
- Device OS: iPadOS 26
- Result: package compilation failed before launch
- Exact error: `Cannot assign value of type 'PaperMarkupViewController' to type '(any MarkupEditViewController.Delegate)?'`
- Difference from CI: Xcode 26.6 exposes this conformance, while the target
  Swift Playgrounds toolchain did not expose it to the package compiler
- Follow-up: replace the unconditional delegate assignment with a guarded
  runtime compatibility cast so the core PaperKit drawing diagnostic can launch

### Physical PaperKit standalone pass: 0.1.4

- Date: 2026-09-01
- Device OS: iPadOS 26
- Swift Playgrounds package version: `0.1.4`
- Package compilation and diagnostic launch: passed
- Apple Pencil writing feel: passed; user reported it is the desired feel
- High-zoom ink quality: passed; user reported no problem while enlarging
- System drawing tools: visible at the bottom and usable
- `도구 표시` button: no visible effect because the system tool picker was
  already shown; omit this redundant control from later app UI
- Standalone PaperKit decision: passed; proceed to the isolated PDF-page test

## PaperKit PDF-page diagnostic

- Production entry point: unchanged `StudyCoachRootView()`
- Diagnostic entry point: `StudyCoachPaperKitPDFDiagnosticView()`
- Rendering design: a crop-box-sized PDF page view backed by `CATiledLayer` is
  PaperKit's content; PaperKit applies the same zoom transform to content and ink
- Persistence: one diagnostic `PaperMarkup` per PDF content identity and page
- Original PDF and production `.drawing` files: unchanged
- Windows validation: passed (`scripts/validate-repository.ps1` and `git diff --check`) on 2026-09-01
- Xcode 16 fallback and Xcode 26 PaperKit compilation: passed in pull-request workflow run 17 on 2026-09-01
- Physical iPadOS 26 PDF alignment and page restoration: pending
- Procedure: `docs/PAPERKIT_PDF_DIAGNOSTIC.md`

