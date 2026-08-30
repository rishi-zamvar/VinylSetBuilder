---
phase: 08
plan: 08
type: execution
autonomous: true
requirements: [CAP-01, CAP-04, RES-02, BPM-07]
closes_defects: [V15, V16]
---

# Phase 8 — Wiring & Camera

## Objective

The stubs come out and the engine goes in. After this plan the app is no longer a shell:
a shutter press runs real Vision recognition, real angle-cluster segmentation, the real
resolution ladder and the real BPM ladder, and the crate screen sequences what comes back.

## Context

- Phase 6 built `AngleClusterSegmenter` and measured it (9 of 12 usable track counts,
  6 of 6 catalogue numbers). **It has never been wired to a screen.**
- Phase 7 built `TrackResolver` + `BPMLadder` and measured them live. **Neither has ever
  been called from the app target** — only from `Tools/*-harness`.
- `AsyncSequencer` (Phase 5) IS already wired, in `CrateDetailView`. Swap 4 is therefore a
  VERIFICATION plus the missing re-sequence-after-resolution edge, not a substitution. It is
  recorded as what it is; nothing is re-swapped to manufacture a fourth swap.
- The simulator has no camera. The camera-fallback path reads the twelve real photographs,
  bundled as an app resource, and runs the SAME Vision + segmentation code the device runs.

## The four swaps, one at a time

`./Scripts/ui-test.sh` after EACH, `totalTestCount` recorded per swap. The suite has 7 tests
and must stay 7 — no test is added, because the gate is "7/7 from totalTestCount".

### Swap 1 — `FixtureLineSegmenter` → `AngleClusterSegmenter`

- `CaptureItem` gains `orientation: PhotoOrientation = .right` so the segmenter can be
  constructed with the orientation the reader returned (OCR-02 is applied once, in Core).
- `CaptureView` constructs `AngleClusterSegmenter(orientation: item.orientation)`.
- `FixtureLineSegmenter` and its tests are DELETED. A stub the app no longer calls is debt.
- The XCUITest draft-line expectations (9 / 16 / 4 / 11 lines) were the STUB's numbers. They
  are re-derived from a measured run of the real segmenter over the same observations and
  committed as the new expectations. Every changed number is recorded old → new.
- **Closes V15 and V16** — the correction sheet stops being over-split, cross-cluster repeats
  and near-duplicates are collapsed before a line ever reaches a `TextField`.

### Swap 2 — `FixturePhotoSource` → the real camera

- `App/Capture/SleeveCamera.swift` — `AVCaptureSession` + `AVCapturePhotoOutput`, configured
  and started on a dedicated queue, the delegate callback bridged to `async` with a
  `CheckedContinuation`. `@preconcurrency import AVFoundation` at this one boundary.
  `makeIfAvailable()` returns nil where there is no capture device (the simulator).
- `App/Capture/SleevePhotoSource.swift` — `PhotoCapturing`. `capture()` returns a
  `.reading` item as soon as the photograph exists; a second seam method `read(_:)` runs
  Vision + `AngleClusterSegmenter` and returns the finished item. **That two-phase shape is
  CAP-01**: the tile appears at once, recognition catches up.
- No camera → the twelve bundled fixtures, in filename order, wrapping past the twelfth
  (the rule `FixturePhotoSource` held, kept where the fallback now lives).
- `CaptureItemStatus` gains `.reading`. `CaptureSession` gains `replace(_:)`, which also
  re-evaluates the flip prompt, because the sides are not known until the read finishes.
- Side markers and status stop being a hand-scored table and are DERIVED from the
  segmentation by one pure, unit-tested rule in Core. `FixturePhotoSource` is DELETED.
- The walk's 6/5/1 tally and its flip set are re-measured against the derived values.

### Swap 3 — the fixture resolver → the real ladder

- `App/Resolution/SleevePipeline.swift` composes the SHIPPING `URLSessionTransport`,
  `ThrottledTransport`, `MusicBrainzClient`, `DiscogsClient`, `ResolutionCache`,
  `TrackResolver`, `TierZeroCorpus` (bundled `bpmkey.tsv`), `SoundCloudClient`,
  `AVAudioFileDecoder` and `BPMLadder`. Nothing is re-implemented.
- Triggered per vinyl from `CrateDetailView` for vinyls whose candidates are all `.pending`.
- **RES-02's UI half:** `AppModel.resolving: Set<UUID>` drives a per-row "Resolving…" status
  in the crate screen. Per-item, visible, and it clears.
- **BPM-07's UI half:** a track the ladder could not give a tempo keeps its identity and its
  place, and its row prints the ladder's own `failureReason`.

### Swap 4 — the sequencer path

- Verify `AsyncSequencer` is the only sequencing path the app takes (`grep`, plus the walk).
- Wire the missing edge: when resolution completes, the crate re-sequences.

## Tasks

1. **(TDD)** Core: `CaptureItem.orientation`, `CaptureSession.replace(_:)`, `.reading`
   status, and `SleeveStatus` — the pure read/partial/unread rule.
2. **Swap 1** — segmenter, delete the stub, re-measure the UI expectations. `ui-test.sh`.
3. **Swap 2** — camera + fixture fallback + live OCR, delete `FixturePhotoSource`,
   bundle the twelve photographs. `ui-test.sh`.
4. **Swap 3** — the pipeline, per-item status, re-sequence on completion. `ui-test.sh`.
5. **Swap 4** — verify the sequencer path; `ui-test.sh`.
6. End-to-end evidence, `hygiene.sh`, `build-app.sh`, UAT entries, docs.

## Measured acceptance gate

1. Every stub swapped and `./Scripts/ui-test.sh` green at `totalTestCount=7` after EACH
   swap — the count recorded per swap, not asserted once at the end.
2. The app runs the real pipeline on real photographs end to end, and the sequenced result
   is photographed in the simulator.
3. The non-blocking shutter demonstrated as far as the simulator allows; everything a camera
   is required for appended to `.planning/UAT-PENDING.md` as device-only.

## Disk discipline

`df -h /` before and after every heavy run. Never two `xcodebuild` invocations at once.
`rm -rf build` and clear DerivedData between runs. Stop and clean below 3 GB free.
