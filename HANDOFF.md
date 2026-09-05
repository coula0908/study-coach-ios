# StudyCoachCore handoff

Last updated: 2026-09-05

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
- Latest installable package tag: `0.1.25`
- Latest runtime implementation commit: `b603868` — floating toolbar,
  Pencil-only dotted/fixed-angle paths, light-stable colors, corrected eraser
  widths/cursor, and newest-first PhotoKit tray
- Latest researched toolbar-design commit: `1a14d92` — StudyCoach-owned exact
  native tools, direct Pencil interactions, structured insertion, and feature
  capability boundaries
- `0.1.19` annotated tag target commit: `8ebf8bc` — Apple validation record
- `0.1.20` annotated tag target commit: `13c0c20` — version record and
  physical-test instructions
- `0.1.21` annotated tag target commit: `0a0cb53` — version record and
  physical-test candidate
- `0.1.22` annotated tag target commit: `6d252be` — first-frame hotfix test
  candidate
- `0.1.23` annotated tag target commit: `9556872` — compact toolbox physical
  test candidate after full Apple CI success
- `0.1.24` annotated tag target commit: `e6f375f` — document tabs and
  contextual tool controls; physical testing found the defects now addressed
  by `0.1.25`
- `0.1.25` annotated tag target commit: `f52bc26` — floating advanced-tool
  physical candidate after full Apple CI success
- Package/module: `StudyCoachCore`
- Production entry point: `StudyCoachRootView()`
- Current isolated candidate entry point:
  `StudyCoachPaperKitPDFDiagnosticView()` on iPadOS 26 or later
- Source version `0.1.25` keeps the accepted PaperKit editor and `0.1.19`
  renderer. GitHub Actions run `33947081676` passes Xcode 16 fallback, Xcode 26
  normal and strict Swift 6 builds, and both iPad Simulator jobs. Annotated tag
  `0.1.25` points to `f52bc26`; physical iPadOS 26 testing is pending.

## In Progress

- New user-authorized 0.1.26 work: automatic ordered saving + annotated PDF
  export; left tabs/right document actions on one top row; vertical/horizontal
  page-edge scrolling through More; dotted release disappearance; consistent
  rounded highlighter output; contact-visible stroke eraser cursor.
  Investigate tiny two-point dot paths and mismatched marker/preview opacity.
  Use public Observation for PaperKit changes, not the rejected delegate.
  CI and physical acceptance pending. 0.1.25 is not accepted for advanced ink.
- Physical `0.1.24` testing found that its toolbar still participates in the
  vertical layout (the PDF jumps when the context row opens), dark-mode ink
  adaptation makes edited colors appear inverted, native marker azimuth still
  does not behave as a fixed tip angle, `.bitmap` eraser width is not visibly
  adjustable, and `.vector` still has no useful range cursor. The user also
  requested a dotted pen and a Goodnotes-style recent-photo tray.
- `0.1.25` is now an isolated editor-control correction. Move the complete
  palette into a fixed overlay above the PDF so row changes never relayout the
  page; constrain and center both scrollable rows; force light-style ink color
  interpretation over the fixed white PDF; label eraser modes; use predictable
  fixed-width pixel erasing for the adjustable partial/precision modes; and
  add an official PhotoKit recent-assets strip with a Files action below it.
  Swift Playgrounds requires the consumer app's **Photo Library** capability
  before direct recent-photo access; code must detect a missing purpose string
  before requesting access so the preview cannot crash.
- Apple's public `PKInkingTool.azimuth` is only a base angle and the final mark
  also uses live Pencil force/azimuth/angle. Therefore repeatedly assigning a
  native marker cannot provide the fixed highlighter angle the user expects.
  The same custom, Pencil-only capture boundary needed for dotted ink will be
  evaluated for fixed-angle output. PaperKit remains the viewport owner and
  solid pen/marker input remains native; no external package is approved.
- `PaperMarkup.subelements` is iPadOS 27-only, so an iPadOS 26 implementation
  cannot post-process the last native PaperKit stroke in place. The supported
  iPadOS 26 path is to construct a `PKDrawing` from public `PKStrokePoint`,
  `PKStrokePath`, and `PKStroke` values and append it to `PaperMarkup` after an
  isolated Pencil-only patterned stroke. Record this as an experimental tool
  until physical latency, coordinates, undo, erase, and persistence pass.
- Implementation is now compiled in `b603868`. The solid pen and 45-degree
  marker retain native PaperKit input. Dotted pen and explicit 0/90-degree
  marker use the isolated capture above; finger input still belongs to
  PaperKit. Color editing is resolved under light appearance. Partial and
  precision erasers both use adjustable fixed-width bitmap input; precision
  is 35% of the selected width; vector mode has toolbar and Pencil-hover range
  feedback. PhotoKit shows 18 newest-first assets and retains PhotosPicker and
  Files fallbacks.
- `0.1.25` Windows validation, Xcode 16 and Xcode 26 normal builds, strict Swift
  6 compilation, and both iPad Simulator jobs pass in Actions run
  `33947081676`. Physical acceptance remains required, especially custom
  gesture arbitration, dotted undo/whole-stroke semantics, fixed marker shape,
  Pencil hover, and Photo Library capability behavior.
- `0.1.23` physical use confirmed that the compact controls still consume
  space inefficiently and exposed three concrete defects: the ten separate
  width targets are hard to tap, the marker's visible tip angle remains 45
  degrees when 0 degrees is selected, and the whole-stroke eraser does not
  show a useful size/range cursor. `0.1.24` is now an isolated toolbar-layout
  correction: persistent top document tabs, a centered primary tool row, a
  toggleable tool-specific secondary row, one usable width slider with a
  numeric value, explicit marker construction with its selected azimuth, and
  a nonzero vector-eraser width. The accepted PaperKit input engine, PDF
  geometry, renderer/tile cache, and PaperMarkup format stay unchanged.
- The `0.1.24` layout follows public Goodnotes behavior: open documents live
  in a document-tabs bar and tapping an already-selected tool toggles its
  active-tool settings. Apple's current PencilKit APIs explicitly support an
  exact `PKInkingTool` azimuth and eraser-item width. No external code or
  dependency is being copied.
- `0.1.24` implementation commit `879dda5` passes Windows repository
  validation, `git diff --check`, and GitHub Actions run `33917015064`. The
  annotated package tag `0.1.24` is pushed at `e6f375f`. The immediate next
  step is to physically test tab switching, settings-row toggle, width slider,
  all three marker angles, and all three eraser modes/ranges without regressing
  the accepted editor.
- Physical `0.1.22` launch now passes on iPadOS 26. The user verified every
  implemented tool function and reports that they work, while noting that the
  first launch takes longer than before. The first-frame hotfix is therefore
  accepted for correctness; startup latency remains a measured follow-up, not
  a reason to change the accepted PaperKit renderer in this task.
- `0.1.23` implementation and Apple CI completed. Physical use confirmed the
  functionality but rejected its ten always-visible width buttons and row
  arrangement, and identified the marker-angle and whole-stroke-range issues.
  `0.1.24` now supersedes it as the physical toolbar candidate.
- The `0.1.21` black-screen regression is resolved by `0.1.22`: physical launch
  and every implemented tool function passed. The user did observe a longer
  launch time. Do not conflate that performance observation with the fixed
  five-second preview watchdog failure; measure it separately before changing
  first-frame behavior again.
- `0.1.20` custom-toolbar bridge implementation, Apple CI, package tag, and
  physical Swift Playgrounds A/B checklist are complete. All numbered checks
  1 through 13 passed. Keep the accepted `0.1.19` renderer, PDF
  geometry, PaperMarkup storage format, gesture observation, and production
  `StudyCoachRootView()` unchanged. The experiment keeps
  `PKToolPicker` active while switching its responder visibility between
  `.hidden` and `.visible`, following Apple's documented PaperKit pattern, so
  Pencil double tap and squeeze can continue to use the system picker state.
- The user rejected a cosmetic toolbar that merely mirrors Apple palette
  choices. `0.1.21` therefore owns exact native tool values: 10-step/fine
  widths, per-tool quick colors, marker azimuth, three eraser modes and widths,
  and lasso. Constructed `PKTool` values are applied through
  `PaperMarkupViewController.drawingTool`, and `UIPencilInteraction` handles
  double tap and squeeze directly. There is no hidden Apple palette in the
  current PDF diagnostic; the `0.1.20` picker is historical A/B evidence only.
- `docs/TOOLBAR_ARCHITECTURE.md` now records the researched capability split.
  Text and image use PaperKit structured insertion APIs rather than Apple UI.
  Freehand dashed/dotted ink has no public `PKInkingTool` pattern property and
  requires an isolated stroke-processing test. Audio is an AVFAudio/document
  timeline subsystem and remains after stable document persistence, although
  its toolbar entry is reserved now. No Swift code or dependency changed in
  this design-only step.
- `docs/GOODNOTES_NOTABILITY_FEATURE_MATRIX.md` is the 2026-09-04 public-feature
  baseline for Goodnotes, Notability, and the actual `0.1.19` state. It
  deliberately distinguishes physical-device confirmation from code-only,
  older-root-only, buggy, and missing behavior. The user postponed reviewing
  toolbar state design, PDF geometry design, and implementation ordering to a
  later turn. `docs/TOOLBAR_ARCHITECTURE.md` and
  `docs/PDF_PAGE_GEOMETRY.md` are retained only as explicitly marked,
  unapproved working drafts; do not implement from them before that review.
- `docs/DEVELOPMENT_SEQUENCE.md` records the decided implementation order,
  but the new physical toolbar corrections consume `0.1.24`; shift the
  previously planned geometry/autosave versions forward when that document is
  updated:
  `0.1.20` minimal custom-tool bridge, `0.1.21` complete note-style toolbar,
  `0.1.22` launch hotfix, `0.1.23` compact toolbar refinement, `0.1.24`
  document-tab/context-row correction, `0.1.25` floating advanced-tool
  correction, `0.1.26` PDF geometry normalization, `0.1.27` autosave/recovery,
  and only
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
