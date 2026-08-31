---
phase: 10
plan: 10
title: "`vinylctl` & Definition of Done"
type: execution
autonomous: true
wave: 1
depends_on: [09]
requirements: [SEQ-05, CAP-04]
---

# Phase 10 — `vinylctl` & Definition of Done

## Objective

Close the project honestly. Three things, in this order:

1. **SEQ-05** — the BPM tolerance slider, 3–6, default 4.0, re-optimising. The last small
   requirement. Every primitive it needs already exists (`BPMRules.toleranceRange`,
   `BPMRules.clampTolerance`, `Crate.bpmTolerance` already threaded into `AsyncSequencer`,
   `CrateRows.make` and `CrateRecords`). What is missing is a store mutator and a control.
2. **`vinylctl`** — a macOS CLI over the SAME `VinylSetBuilderCore` package and the SAME app
   adapters. One pipeline, two front ends. Composed from the Act II harness pattern in
   `Tools/` and `Scripts/*-score.sh`, not reimplemented.
3. **The Definition of Done (MVP-SPEC §9), walked and reported item by item** — including the
   items that come back NOT MET, and the two places where the spec has drifted from the code.

## Context

- Owner's twelve real photographs: `Tests/Fixtures/Labels/*.HEIC` (gitignored, present).
- The app's composition root for the two ladders is `App/Resolution/SleevePipeline.swift`.
  **vinylctl must link that file, not a copy of it.** Its only obstacle is
  `Bundle.main.url(forResource: "bpmkey")`, which is nil outside an app bundle.
- The app's per-record capture→entry step is `CaptureSession.vinylEntry(for:segmenter:)`
  in Core, driven by `App/Views/CaptureView.shoot()` and `App/Capture/SleevePhotoSource.read()`.
- The app's sequence+rows step is exactly two calls, in `CrateDetailView.load()`:
  `AsyncSequencer().sequence(candidates:bpmTolerance:)` then `CrateRows.make(result:crate:)`.
- V19's reason precedence lives in `CrateRows.reason(for:representative:tolerance:sequencerSaid:)`
  and is asserted by `CrateRows.invariantHolds`.
- CAP-04's device half is already recorded as UAT **U2c**. The simulator has no camera
  (`SleeveCamera.makeIfAvailable()` returns nil). Nothing here may claim the device half.

## Tasks

### Task 1 — SEQ-05: the tolerance slider (type=auto, tdd=true)

**behavior**
- `CrateStore.setBPMTolerance(_:in:)` clamps through `BPMRules.clampTolerance` — 2.0 → 3.0,
  9.0 → 6.0, 4.5 → 4.5 — and no-ops on an unknown crate id.
- A crate created by `createCrate` reads 4.0 (already covered; re-asserted as the default).
- **Changing tolerance changes the set.** A Core test builds candidates whose sequence at
  tolerance 3 is strictly shorter than at 6, and asserts both against the shipping sequencer.

**implementation**
- Core: the mutator on `CrateStore`, routed through the existing private `withCrate`.
- App: a `Slider` in `CrateDetailView`'s running-order section, `in: BPMRules.toleranceRange`,
  `step: 0.5`, identifier `bpm-tolerance-slider`, with a live caption
  `bpm-tolerance-label`. On change: `model.store.setBPMTolerance(...)` then `await load()`,
  which is the same re-derivation path `commitEdit` uses.
- UITest: assert the caption reads the default on entry, drag the slider, assert the caption
  CHANGED (never a hardcoded target value — 02-04's rule).

**done when** `swift test` green, the slider is in the walk, requirement ticked.

### Task 2 — `vinylctl` (type=auto)

`Tools/vinylctl/main.swift` + `Scripts/vinylctl.sh`, built exactly like `resolve-score.sh`:
`swift build --package-path VinylSetBuilderCore`, then one `swiftc` that compiles the SHIPPING
app adapters from source and LINKS Core's objects.

Files compiled in: `App/Generated/Secrets.swift`, `App/OCR/SleeveTextRecognizer.swift`,
`App/Network/URLSessionTransport.swift`, `App/Audio/AVAudioFileDecoder.swift`,
`App/Resolution/SleevePipeline.swift`.

**One deviation is required and is the whole "one pipeline" point:** `SleevePipeline.init` is
made non-private and takes the corpus URL, defaulting to today's `Bundle.main` lookup, so
`shared` is byte-identical in behaviour and the CLI passes `App/Generated/bpmkey.tsv`.

Subcommands (criterion 3 — every stage bisectable with no simulator):
- `ocr <photos…>` — observations, trusted count, orientation, ms
- `segment <photos…>` — tracks, sides, catalogue number, status
- `resolve <photos…>` — identity per line, with the source rung
- `analyze <photos…>` — the BPM ladder's answer per identified track
- `sequence <photos…>` — the whole thing: per record the OCR'd text, the catalogue number,
  the resolved identity **or an explicit reason it failed**; then the sequenced set with BPM
  and Camelot per row; then the not-included bucket with V19's per-row reason.
- `--tolerance <n>` on `sequence`, so SEQ-05 is exercisable headlessly too.

**done when** `./Scripts/vinylctl.sh sequence Tests/Fixtures/Labels/*.HEIC` runs to completion
over all twelve without crashing.

### Task 3 — the committed baseline (type=auto)

`Artifacts/vinylctl/sequence-baseline.txt` — the literal stdout of task 2 on the twelve, and
`sequence-baseline.json` — the machine-readable form, so a future change is diffable.
Committed. The fixtures are gitignored; the OUTPUT is not.

### Task 4 — does it match the app? (type=auto)

`Scripts/vinylctl-vs-app.sh`: runs `vinylctl sequence` and the existing live twelve-record
XCUITest walk (`CaptureWalkUITests`, which already prints `PIPELINE sequenced row N:`),
canonicalises both to `title | bpm | camelot` triples in order, and diffs.

**Both halves hit the live network, so a difference may be the internet rather than the code.**
Any difference is reported with its cause named, never smoothed over. A structural check runs
beside it: the two front ends must make the same two calls, which is grep-able.

### Task 5 — MVP-SPEC §9, walked (type=auto)

Each of the five items gets a verdict — MET / PARTIALLY MET / NOT MET — with the number
behind it and the evidence path. Three known tensions get stated, not papered over:
- item 2's "auto-resolves for most": tier-0 measured 0 of 35, catalogue rung 6/6 but only 6 of
  12 records carry a readable catalogue number, artist+title produces confident wrong answers.
  **State the real auto-resolve rate from task 3's run.**
- item 2's 15 s: Phase 9 measured 13.3 s costed / 16.3 s wall, typing-dominated.
- item 3's "ascending BPM": retired 2026-08-30 for bidirectional adjacency. Report against the
  CURRENT spec and note the drift.

### Task 6 — the final sweep (type=auto)

- `Scripts/ledger-check.py` green, every open defect carried with a named owner.
- `.planning/UAT-PENDING.md` current: CAP-04's device half, V3/U8, everything still needing
  the owner.
- **V3 stays open. U8 is not guessed.**
- A README section a person could follow to build and run this, including `vinylctl`.
- `hygiene.sh` G1 extended to sweep `Tools/` — the roadmap's own §14 criterion names it.

## Measured acceptance gate

1. `vinylctl sequence` over all twelve, no crash, output committed
2. its sequence compared against the app's on the same input, difference reported honestly
3. SEQ-05 built and tested: 3–6 changes the set, default 4.0
4. every §9 item walked with an honest verdict
5. `test.sh`, `hygiene.sh`, `ui-test.sh`, `build-app.sh` all green at the end

## Out of scope

CAP-04's device half (memory, thermals, live camera) — no camera exists here. It is recorded
in `UAT-PENDING.md` as U2c and is NOT claimed.
