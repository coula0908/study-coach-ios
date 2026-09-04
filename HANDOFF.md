# StudyCoachCore handoff

Last updated: 2026-09-04

Read `AGENTS.md`, this file, `docs/ARCHITECTURE.md`, and the newest sections of
`VALIDATION.md` before changing the viewer. This project is intended to become
a dependable study tool quickly. It is not an exercise in building a unique PDF
engine. Prefer verified Apple APIs, public implementations, and mature renderer
patterns over new trial-and-error code.

## Handoff maintenance protocol

This is the shared current-state document for Codex, Antigravity, and future
agents. It must be enough to resume work without a prior conversation. Actual
working-tree files and Git state are authoritative, followed by current CI,
this file, validation/version/changelog documents, and only then old agent
summaries.

Update this file continuously when an implementation starts, a design is
accepted or rejected, a physical-device result arrives, a root cause is found,
or a commit, push, CI run, version, tag, validation state, or next step changes.
Do not defer all updates until the end of the session. Keep it concise and
current rather than turning it into a transcript, but retain failures that a
later agent might otherwise repeat.

The continuity protocol was originally maintained in an earlier local
study-coach workspace. Its last project snapshot ended at `0.1.16` and is now
historical. Its continuity rules have been incorporated into the actual Swift
package repository; current code, Git, CI, and the state below supersede its
old version and tag values.

## Repository state

- Repository: `https://github.com/coula0908/study-coach-ios`
- Active local branch: `codex/paperkit-adaptive-background`
- Remote development branch: `main`
- Latest installable package tag: `0.1.19` (the `0.1.20` tag is not created yet)
- Latest runtime implementation commit: `9dfe5e5` — isolated custom-toolbar
  bridge over the accepted PaperKit editor
- `0.1.19` annotated tag target commit: `8ebf8bc` — Apple validation record
- Package/module: `StudyCoachCore`
- Production entry point: `StudyCoachRootView()`
- Current isolated candidate entry point:
  `StudyCoachPaperKitPDFDiagnosticView()` on iPadOS 26 or later
- Source version `0.1.20` adds the isolated StudyCoach/Apple toolbar A/B bridge
  in `9dfe5e5` and is pushed to `origin/main`. GitHub Actions run `33879002800`
  passed the Xcode 16 fallback build, Xcode 26 normal build, strict Swift 6
  build, and both iPad Simulator jobs. The `0.1.20` documentation/tag commit
  and physical iPadOS 26 test are still pending. The accepted `0.1.19`
  renderer and its slower-than-Notability tradeoff are unchanged.

## In Progress

- `0.1.20` custom-toolbar bridge implementation and Apple CI are complete;
  source/version documentation is being finalized before the installable tag
  is created. Physical Swift Playgrounds compilation and the A/B checklist are
  not yet complete. Keep the accepted `0.1.19` renderer, PDF geometry,
  PaperMarkup storage format, gesture observation, and production
  `StudyCoachRootView()` unchanged. The experiment keeps
  `PKToolPicker` active while switching its responder visibility between
  `.hidden` and `.visible`, following Apple's documented PaperKit pattern, so
  Pencil double tap and squeeze can continue to use the system picker state.
- `docs/GOODNOTES_NOTABILITY_FEATURE_MATRIX.md` is the 2026-09-04 public-feature
  baseline for Goodnotes, Notability, and the actual `0.1.19` state. It
  deliberately distinguishes physical-device confirmation from code-only,
  older-root-only, buggy, and missing behavior. The user postponed reviewing
  toolbar state design, PDF geometry design, and implementation ordering to a
  later turn. `docs/TOOLBAR_ARCHITECTURE.md` and
  `docs/PDF_PAGE_GEOMETRY.md` are retained only as explicitly marked,
  unapproved working drafts; do not implement from them before that review.
- `docs/DEVELOPMENT_SEQUENCE.md` records the decided implementation order:
  `0.1.20` minimal custom-tool bridge, `0.1.21` complete note-style toolbar,
  `0.1.22` PDF geometry normalization, `0.1.23` autosave/recovery, and only
  then `0.2.0` promotion into `StudyCoachRootView()`. Later phases add the
  library/page model, editing/export, study/OCR, audio/sync, and AI. Keep one
  risky subsystem per physical-device test version.
- Renderer work is frozen at `0.1.19`: do not resume zoom/pan rendering
  optimization unless a new correctness, crash, or clearly unusable problem is
  reported. The accepted tradeoff is that sharpening is slower than Notability
  but usable.
- The working PaperKit PDF path is still an isolated diagnostic entry point,
  while `StudyCoachRootView()` still opens the older PDFKit/PencilKit editor.
  The next architectural task is to productize the accepted PaperKit path and
  make it the real app flow without reviving the rejected dual-viewport design.
- Before promotion, close the data-safety and core-tool gaps: dependable
  automatic PaperMarkup saving, verified page/relaunch restoration, thin-tool
  availability, eraser modes, Pencil double-tap, line hold, and a representative
  large-document/page-navigation check on the physical device.
- AI coaching, document-library polish, search/thumbnails, and annotated-PDF
  export remain after the dependable PDF-and-Pencil study loop.

## Confirmed physical-device history

- `0.1.4` standalone PaperKit produced the user's preferred handwriting feel
  and sharp ink at high zoom.
- The first PaperKit PDF experiment kept PaperKit input quality but showed
  visibly arriving rectangular PDF tiles.
- The PDFKit/PencilKit path restored a sharp PDF background but had several
  physical-device input and ink-presentation regressions. See `VALIDATION.md`
  for exact version-by-version results rather than retrying those structures.
- The complete-page-image PaperKit candidate preserves PDF orientation,
  alignment, tools, scrolling, zooming, persistence, and a tile-free initial
  page appearance on the physical iPad.
- `0.1.17` stopped intermediate detail rendering during pinch zoom, but its
  permanent 33 ms viewport sampler still started a render for each one-finger
  pan update. Status messages alternated rapidly and base/detail image swaps
  made the writing appear to shake.
- `0.1.18` removes permanent viewport polling and renders once only after pan,
  inertial scrolling, pinch, and zoom bounce finish. This fixes repeated swaps
  by intentionally showing the bounded base image throughout a pan, but the
  user correctly identified that a sufficiently zoomed base image can be
  blurry and uncomfortable to read while moving.

## Current design decision — renderer accepted, editor promotion pending

Zoom and pan require separate rendering policies:

1. **Pinch/scale change:** do not render intermediate zoom scales. Keep the
   existing stable representation during the gesture, then choose the final
   level of detail and prioritize its visible tiles when the fingers lift.
2. **Pan at a fixed scale:** do not discard all detail and wait until scrolling
   ends. Existing high-resolution regions must move with the page unchanged.
   Reuse cached tiles and render/prefetch only newly exposed neighboring tiles
   at the same scale.

Rendering only the current viewport as one bitmap is not sufficient: as soon
as the page moves it exposes an area outside that bitmap, makes the new region
blurry, and rerenders overlapping pixels. Rendering the entire PDF page at the
maximum zoom resolution avoids that seam but can require hundreds of megabytes
for a single ordinary page, so it is not a safe general solution.

The `0.1.19` implementation candidate is therefore:

- PaperKit remains the sole owner of scrolling, zooming, Pencil input, markup,
  and coordinates.
- Keep the current complete, bounded page image as an always-present fallback.
- Add a fixed-grid or `CATiledLayer`-style PDF detail renderer above that base
  but below PaperKit markup.
- Key cached detail by document, page, crop/rotation, level of detail, and tile
  coordinates. Keep overlapping tiles; never replace the whole detail surface
  for a content-offset change.
- At fixed zoom, prioritize the visible grid and a ring in the pan direction.
  Publish each completed tile without animation while leaving the base below,
  so no white/blank rectangle appears.
- During pinch, freeze requests for transient scale values. On pinch end,
  select the new zoom level, render visible tiles first, then neighboring tiles.
- Bound memory with a small reusable tile pool/LRU cache and cancel obsolete
  low-priority requests. Do not clear usable old-scale content before the new
  level is ready.
- Remove per-tile "rendering/completed" status text from the normal reading UI;
  retain diagnostics in logs or an opt-in debug display.

The user explicitly accepted the `0.1.19` renderer tradeoff after physical use.
Keep its rendering policy stable while the remaining editor behavior is
verified and the PaperKit path is promoted into the actual app flow.

## External evidence to consult first

- Apple `CATiledLayer` documentation describes asynchronous, cached rendering
  at multiple levels of detail:
  <https://developer.apple.com/documentation/quartzcore/catiledlayer>
- Apple's archived `ZoomingPDFViewer` sample uses a `CATiledLayer`-backed PDF
  view, 512-pixel tiles, and multiple levels of detail:
  <https://github.com/robovm/apple-ios-samples/blob/master/ZoomingPDFViewer/ZoomingPDFViewer/TiledPDFView.m>
- Nutrient's renderer engineering article explicitly documents why rendering
  only the current visible rectangle is a poor pan strategy and describes
  retaining/repositioning a bounded tile pool while asynchronously appending
  newly visible tiles:
  <https://www.nutrient.io/blog/rendering-pdfs-on-android/>
- `vfr/Reader`/`PDFReader` is an older open-source example of a full-page
  preview underneath multithreaded `CATiledLayer` PDF rendering. Treat it as a
  structural reference, not drop-in modern Swift code:
  <https://github.com/vfr/Reader>
- Existing annotation references already evaluated by this repository are
  listed in `docs/ARCHITECTURE.md`, including Apple's WWDC22 PDF page overlays,
  `DannyBehar/PDFViewer`, `theagitist/Pumice`, and
  `TheProductArchitect/cecilias-notes`.

Goodnotes and Notability should be used for UX acceptance criteria—no visible
blank tiles, stable text during pan, sharp resting content, and immediate Pencil
input—but their private rendering architecture must not be asserted without a
public technical source.

## Remaining physical acceptance checks for the editor

On the physical iPadOS 26 device, separately test:

1. Hold a pinch without lifting: no intermediate high-resolution work or
   repeated status changes.
2. End a pinch: visible content becomes sharp promptly and only the required
   level is scheduled.
3. Slowly pan at fixed zoom: already sharp text and ink remain sharp and stable.
4. Flick with inertia: no shaking, full-surface swaps, white rectangles, or
   repeated global status messages.
5. Reverse pan direction: cached regions are reused rather than rerendered.
6. Pan beyond prefetched coverage: the complete base remains visible until a
   tile is ready; completed tiles appear without a fade or blank gap.
7. Draw while zoomed: PDF background work does not change PaperKit input feel,
   ink sharpness, tool behavior, or coordinate alignment.
8. Repeat on a large and image-heavy PDF while watching for crashes or memory
   pressure.

## Continuation routine

1. Run `git status --short --branch` and preserve unrelated user changes.
2. Read the newest `VALIDATION.md` and `CHANGELOG.md` entries.
3. Research before changing a major subsystem; record the evidence and license.
4. Keep experiments isolated from `StudyCoachRootView()` until physical-device
   acceptance succeeds.
5. Run `scripts/validate-repository.ps1` and `git diff --check` on Windows.
6. Push an implementation commit to `main` and wait for both GitHub Actions
   Apple jobs, including the strict Swift 6 build.
7. Record the workflow URL and exact result in `VALIDATION.md`.
8. Create a new semantic tag only after CI passes. Physical iPad acceptance
   remains a separate result and must never be inferred from CI.
9. Update this handoff after every meaningful result and before stopping due to
   context, time, or usage limits. State what is confirmed, what failed, what is
   only proposed, the exact latest commit/tag, and the next safe action.

## Evidence boundaries and Git discipline

- Repository and Git state override this document if they conflict.
- Preserve and inspect unexplained local changes; never reset or clean them just
  because another agent did not document them.
- Keep static checks, Apple builds, simulator results, Swift Playgrounds
  compilation, and physical iPad behavior separate.
- Do not mark a physical behavior as passed based on CI.
- Before changing the version or creating a tag, verify `VERSION.md`, HEAD,
  remote state, existing tags, and the relevant CI result.
- A Git tag and a GitHub Release are separate objects; report them separately.
- Update `In Progress`, repository state, CI, tag state, known issues, rejected
  approaches, and next steps as soon as they materially change.
