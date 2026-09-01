# Study Coach for iPad

`StudyCoachCore` is a Swift Package for a personal iPad study app. It is designed to be imported into an app playground in Swift Playgrounds without requiring an Xcode project.

The first MVP focuses only on a stable PDF and Apple Pencil workflow. AI coaching will be added only after PDF display, page-bound drawing, gesture separation, and local restoration have been verified on iPad.

## Current stage

The first PDF-and-Pencil MVP is implemented and passes Apple-toolchain compilation and unit tests. On physical iPadOS 26 hardware, package import, app launch, PDF display, navigation, and performance passed. Device testing showed that PencilKit's overlay drawing recognizer still failed in `0.1.1`; `0.1.2` adopts the Pencil-only recognizer path from the MIT-licensed, App-Store-shipped Pumice app and awaits physical-device retesting.

- Swift Package manifest and public `StudyCoachRootView`
- Files-app PDF importer
- Continuous PDFKit viewer with page navigation, direct page jump, zoom controls, and finger pan/zoom
- Page-bound, lazily created PencilKit canvases
- Pen, translucent highlighter, vector eraser, undo, redo, color, and width controls
- Pumice-derived Pencil-only gesture routing so Pencil reaches the page canvas while finger gestures remain available to PDFKit
- SHA-256 document identity
- Atomic, per-page `PKDrawing` persistence outside the source PDF
- Last document and last page restoration after relaunch
- GitHub macOS workflow that compiles the package and tests for an iOS Simulator target

Runtime behavior still needs to be checked in Swift Playgrounds on the user's iPadOS 26 device. Until that pass is recorded, coordinate alignment and gesture behavior are implemented but not device-verified.

## Package structure

```text
Package.swift
Sources/
  StudyCoachCore/
    App/
    Annotations/
    PDF/
    Persistence/
Tests/
  StudyCoachCoreTests/
docs/
  ARCHITECTURE.md
AGENTS.md
VALIDATION.md
```

The package intentionally has no external dependencies.

The Pencil-only recognizer is source-adapted from the MIT-licensed Pumice app;
see [third-party notices](THIRD_PARTY_NOTICES.md). Keeping this small component
in source form avoids an Xcode-only binary dependency and remains compatible
with Swift Playgrounds.

## Add the package in Swift Playgrounds

After these files are committed and pushed to GitHub:

1. Create or open an app playground on the iPad.
2. In the project navigator, tap the add-document button (`+`).
3. Choose **Swift Package**.
4. Enter this package URL:

   ```text
   https://github.com/coula0908/study-coach-ios
   ```

5. Select the latest `0.1.x` release. Use the `main` branch only when intentionally testing unreleased development changes.
6. Enable the `StudyCoachCore` product and add it to the project.

Use this minimal `ContentView`:

```swift
import SwiftUI
import StudyCoachCore

struct ContentView: View {
    var body: some View {
        StudyCoachRootView()
    }
}
```

## Development rules

- The minimum deployment target is currently iOS/iPadOS 17.
- Do not create an `.xcodeproj` as the source of truth.
- Keep `StudyCoachRootView` as the public, parameterless package entry point.
- Use SwiftUI, PDFKit, PencilKit, UniformTypeIdentifiers, and Foundation where appropriate.
- Use page-bound, lazily created drawing overlays. Never place one fixed canvas over the entire PDF viewport.
- Store drawings separately from the original PDF and persist one drawing per document and page.
- Never commit API keys, tokens, personal PDFs, drawings, or other private study data.

Read [the architecture contract](docs/ARCHITECTURE.md) before implementing the viewer or storage layer. Record all device verification in [the validation log](VALIDATION.md).

## Host limitation

The current development host is Windows and does not have the Swift toolchain or Apple platform SDKs installed. Repository structure is checked locally, while GitHub Actions compiles the package and runs its unit tests with Xcode on an iPad Simulator. A successful package import and interaction pass in Swift Playgrounds on the target iPadOS 26 device is the next required runtime checkpoint.

Run the local static validation with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-repository.ps1
```

## Design references

- Apple documents adding a public GitHub Swift Package directly to an app playground: <https://developer.apple.com/documentation/swift-playgrounds/add-a-swift-package>
- Apple introduced `PDFPageOverlayViewProvider` specifically for page-bound views such as PencilKit canvases: <https://developer.apple.com/videos/play/wwdc2022/10089/>
- Apple's PencilKit guidance defines `.pencilOnly` for Pencil drawing while finger input remains available for scrolling and selection: <https://developer.apple.com/videos/play/wwdc2020/10107/>
- Pumice is an MIT-licensed iPad PDF annotation app whose iPadOS 26-tested Pencil-only recognizer is adapted for this package: <https://github.com/theagitist/Pumice>
- Goodnotes' public toolbar documentation was used only as an interaction reference for keeping writing tools and controls quickly accessible: <https://support.goodnotes.com/hc/en-us/articles/8900755183631-Customize-the-toolbar>
