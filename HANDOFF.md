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
- Latest installable package tag: `0.1.19`
- Latest runtime implementation commit: `ad6c460` — keep sharp PDF tiles
  during fixed-scale pan
- `0.1.19` annotated tag target commit: `8ebf8bc` — Apple validation record
- Package/module: `StudyCoachCore`
- Production entry point: `StudyCoachRootView()`
- Current isolated candidate entry point:
  `StudyCoachPaperKitPDFDiagnosticView()` on iPadOS 26 or later
- Source version `0.1.19` is implemented in `ad6c460` and pushed to
  `origin/main`.
  GitHub Actions run `33859079628` passed the Xcode 16.4 fallback build,
  Xcode 26 normal build, strict Swift 6 build, and iPad Simulator tests.
  Annotated tag `0.1.19` is pushed and physical iPadOS 26 interaction is still
  pending.

## In Progress

- Runtime implementation of the fixed-scale PDF tile/cache strategy has begun
  with the user's explicit authorization.
- Target source version: `0.1.19`.
- Pinch behavior: keep the existing stable representation and submit no
  transient zoom-level renders until the gesture ends.
- Fixed-scale pan behavior: retain completed high-resolution tiles, request
  only missing visible and neighboring tiles, and never clear the whole detail
  surface merely because content offset changed.
- The complete bounded page image remains underneath so a missing tile never
  appears white or blank. Per-tile status-message flashing must be removed.
- Current stage: the single visible-region bitmap has been replaced by a
  bounded cached grid, with planner tests and documentation, in commit
  `ad6c460`. Windows `scripts/validate-repository.ps1` and `git diff --check`
  pass, and the commit is on `origin/main`. GitHub Actions run `33859079628`
  passed both Apple jobs, including strict Swift 6 and iPad Simulator tests.
  Validation commit `8ebf8bc` and annotated tag `0.1.19` are on the remote.
  The next required result is physical iPadOS 26 acceptance.

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

## Current design decision — implemented, awaiting device validation

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

The user explicitly authorized implementation after the design discussion.
Keep this path isolated until its physical iPad behavior is accepted.

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

## Required acceptance checks for the next renderer

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
