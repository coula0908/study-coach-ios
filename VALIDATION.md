# Validation log

## Current status

- Repository structure: passed `scripts/validate-repository.ps1` on 2026-09-01
- Apple toolchain compilation: passed on GitHub Actions with Xcode 16.4 on 2026-09-01
- iPad Simulator unit tests: 3 passed, 0 failed on 2026-09-01
- Swift Playgrounds package import: passed on physical iPadOS 26 with tag `0.1.0`
- PDF display and navigation: passed on physical iPadOS 26; no stutter reported
- PencilKit behavior: pen and highlighter failed in `0.1.0`; input-routing fix implemented and awaiting retest

Do not mark the MVP complete until the Pencil input fix and the remaining acceptance checks pass in Swift Playgrounds on the target iPad.

## Apple toolchain record

- Date: 2026-09-01
- GitHub commit: `a24a5352209039f0abb1c564090e5b1560397f2a`
- Workflow run: <https://github.com/coula0908/study-coach-ios/actions/runs/33469467319>
- Toolchain: Xcode 16.4 (build 16F6), iOS Simulator SDK 18.5
- Build result: `StudyCoachCore` and `StudyCoachCoreTests` compiled successfully for iOS Simulator
- Test destination: an available iPad Simulator selected dynamically by the workflow
- Test result: 3 tests executed, 0 failures
- Covered behavior: public root-view creation, per-document/per-page drawing-data separation and round trip, stable content identity, last-page restoration
- Not covered by CI: Swift Playgrounds package import, Apple Pencil/finger interaction, visual PDF coordinate alignment, background/relaunch behavior on physical iPadOS 26 hardware

## iPad acceptance record

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
