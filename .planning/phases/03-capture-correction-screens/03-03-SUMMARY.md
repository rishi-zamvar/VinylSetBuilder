---
phase: 03-capture-correction-screens
plan: 03
subsystem: ui
tags: [swiftui, xcuitest, capture, accessibility-identifiers, screenshots]

requires:
  - phase: 03-01
    provides: FramingGuide.sleeve, CaptureItem, CaptureItemStatus, CaptureSession, PhotoCapturing, FixturePhotoSource, FixtureLineSegmenter, FixtureObservations
  - phase: 02
    provides: CrateStore routing, CrateDetailView state-ownership pattern, CrateWalkUITests, ScreenshotRecorder
provides:
  - "CaptureView — the sleeve framing guide, the shutter, the inline flip prompt and Done"
  - "CaptureThumbnailStrip — fixed-width square tiles in a horizontal ScrollView, one per capture, each with a legible status pill"
  - "FlipSidePromptView — an inline Scan/Skip banner that never blocks the shutter"
  - "CaptureScreenUITests — the four capture states photographed, CAP-05 asserted both ways in one run"
  - "Phase 2's fifteen-state walk repaired and green against the new screen"
  - "The full capture-screen accessibility-identifier contract, live-verified against the real accessibility tree"
affects: [03-04, 03-05, phase-10-camera, phase-11-wiring]

tech-stack:
  added: []
  patterns:
    - "The screen holds no rules: geometry is read off FramingGuide.sleeve, naming off CaptureItem.displayLabel, prompt visibility off CaptureSession.pendingFlipPrompt"
    - "Status text lives OUTSIDE the tile's Button, because a SwiftUI Button merges its label's children into one accessibility element"
    - "Mutation-based negative controls: one-line inversions run, reddened, and reverted, confirmed from log AND result bundle"

key-files:
  created:
    - App/Views/CaptureView.swift
    - App/Views/CaptureThumbnailStrip.swift
    - App/Views/FlipSidePromptView.swift
    - UITests/CaptureScreenUITests.swift
  modified:
    - App/Views/RootView.swift
    - UITests/CrateWalkUITests.swift
    - UITests/ScreenshotRecorder.swift
    - .planning/VISUAL-DEFECTS.md
  deleted:
    - App/Views/CapturePlaceholderView.swift

key-decisions:
  - "Tasks 1 and 2 committed together — CaptureView's body references both new subviews, so an intermediate commit could not have compiled"
  - "The thumbnail's status pill sits outside the Button so 03-05 can read the 6/5/1 tally back off staticTexts"
  - "ScreenshotRecorder's settle stays at 3.0/4.0 — raising it to 4.0/5.0 was measured and changed nothing"
  - "V3's predicted second sighting is NOT claimed: the bucket is collapsed on walk state 5, so no picture shows the label"

patterns-established:
  - "Pattern: every behavioural claim on a new screen gets a mutation that proves the assertion can redden, verified from two sources"
  - "Pattern: view geometry derived from a Core-tested value type, then read BACK off the rendered accessibility frame as an independent check"

requirements-completed: [CAP-02, CAP-03, CAP-05, CAP-06]

duration: 47min
completed: 2026-08-30
---

# Phase 3 Plan 03: The Capture Screen Summary

**A sleeve-sized framing guide whose 0.881 rendered edge coverage is derived from `FramingGuide.sleeve` rather than retyped, a shutter that pulls real OCR fixtures through the `PhotoCapturing` seam into the crate, a scrolling thumbnail strip with legible per-record read status, and an inline flip prompt that fires on fixture 1 and is suppressed on fixture 2 — proved both ways in one run and proved able to fail by two opposite mutations.**

## Performance

- **Duration:** ~47 min
- **Tasks:** 3 of 3
- **Files created:** 4 · **modified:** 4 · **deleted:** 1
- **Commits:** 2 code/test commits + 1 docs commit

## Accomplishments

### Task 1 + 2 — the screen (CAP-02, CAP-03, CAP-05, CAP-06)

`App/Views/CaptureView.swift` replaces `CapturePlaceholderView`, which is **deleted**; `RootView`
routes `.capture` to it. `App/Views/CaptureThumbnailStrip.swift` and
`App/Views/FlipSidePromptView.swift` are its two subviews.

All eleven identifiers in CONTEXT.md §5's capture table exist, with the element types the table
names — and every one was **exercised by a live typed query** in the new UI test rather than
assumed: `app.otherElements["capture-framing-guide"]`, `app.otherElements["capture-flip-prompt"]`,
`app.scrollViews["capture-thumbnail-strip"]`, `app.buttons["capture-thumb-{n}"]`,
`app.staticTexts["capture-thumb-status-{n}"]`, `app.staticTexts["capture-session-count"]`.

The screen holds no rules. Guide geometry comes from `FramingGuide.sleeve.edgeCoverage` and
`.aspectRatio`; names come from `CaptureItem.displayLabel`; prompt visibility comes from
`CaptureSession.pendingFlipPrompt`; status text is `CaptureItemStatus.label`.

### Task 3 — Phase 2's walk, repaired and stronger

Exactly **two** assertions changed, both strengthenings, each closing a recorded Phase 2 gap.

| Step | Was | Now | Why it is a strengthening |
|---|---|---|---|
| 4 | tap `capture-add-fixture-button`, then assert only that the screen did not navigate away | tap `capture-shutter-button`, then assert `capture-thumb-1` **exists** and `capture-thumb-2` **does not** | Phase 2 asserted nothing about the crate's contents here, which is precisely why walk states 3 and 4 came out byte-identical (md5 `6a903ce3`) — **deferred item D-02-04-1**. The strip now reflects the capture, and the new assertion is two-sided where there was none. |
| 5 | assert `sequenced-row-1` exists | assert `empty-running-order` **exists**, `sequenced-row-1` **does not**, `not-included-section` **exists** | A captured sleeve carries OCR text and no BPM (nothing resolves in Act I, D-03-5), so the sequencer genuinely cannot schedule it. This is the first time the walk reaches and photographs the empty running order — **closing V7**, which Phase 2 recorded as an un-photographed branch. Three assertions replace one, and the `sequenced-row-99` negative control is untouched. |

Steps 1–3 and 6–15, every negative control and every two-sided count assertion, are unchanged.
No other step needed changing to go green.

## The two disciplines

### 1. Measurement counts, per claim

| Claim | How many times measured | Evidence |
|---|---|---|
| Suite is green (3 tests, 0 failures) | **3 full runs**, each read from **two independent sources** | log `Executed 3 tests, with 0 failures` + `** TEST SUCCEEDED **`; `build/ui.xcresult` → `result Passed, passedTests 3, failedTests 0, skippedTests 0`. The two agreed all three times. |
| The framing guide is square | **2** (accessibility frame, 2 runs) + **7** (rendered pixels, 3 runs) | a11y frame `(55.67, 238.0, 290.67, 291.0)` — byte-identical across both runs that printed it. Pixel measurement: 872×873 or 686×686 on every frame. |
| The guide covers 0.88 of the preview's shorter edge, derived not retyped | **7 frames across 3 runs** | measured coverage **0.881** (5 frames) and **0.879** (2 frames) against `FramingGuide.sleeve.edgeCoverage == 0.88` |
| The flip prompt FIRES on fixture 1 (`IMG_0498`, no side markers) | **3** (once per full run) | `03-03-capture-flip-prompt.png` + `XCTAssertTrue(app.otherElements["capture-flip-prompt"]...)` |
| The flip prompt is SUPPRESSED on fixture 2 (`IMG_0499`, `A`+`AA`) | **3** (once per full run) | `03-03-capture-flip-suppressed.png` + `waitForNonExistence` |
| Fixtures 1 and 2 both score `.read` | **3** (once per full run), UI side only | `capture-thumb-status-1` and `-2` labels read back as `"Read"`. The 6/5/1 **full tally** is 03-05's job — this plan only ever shoots two sleeves, and does not claim the tally. |
| The session count inflects (`1 record`, not `1 records`) | **3** (once per full run), two-sided each time | `03-03-capture-one-item.png` reads "1 record"; `03-03-capture-flip-suppressed.png` reads "2 records" |
| Skip dismisses the prompt without removing the record | **3** (once per full run) | `03-03-capture-one-item.png` |
| The prompt does not block the shutter | **3** (once per full run) | `XCTAssertTrue(app.buttons["capture-shutter-button"].isHittable)` while the prompt is up |
| No frame carries the V2 pallor signature | **3 full probe runs** over 19 frames each (57 frame-probes) | `SUSPECT: none` every time; `min 0 / max 255` on all 19 |
| V9 (missing large nav titles) is not a settle artefact | **2 settle values** (3.0s and 4.0s), 19 frames each, plus 11 untouched control frames | title-band ink identical at both settles: 0 on the same 13 frames, 9498 and 11753 on the same 6 |
| Drag recipe 1 still fires | **3** (once per full run) | `WALK DRAG RECIPE FIRED: 1: press-and-drag on the row, edit mode ON` |

**Measured once, and said so:** nothing. Every claim above has ≥ 2 observations.

**Not measured, and not claimed:** the 6/5/1 status tally end-to-end, the 12-fixture session, the
21-item scroll, and `capture-thumb-99`'s absence beyond a single run's assertion. Those are
03-05's, by the plan's own division.

### 2. Every passing test proved able to fail

Three one-line mutations, applied, run, reverted. Each produced a **clean assertion failure at a
named line — not a crashed runner** — and each was confirmed from the log **and** from
`build/ui.xcresult`'s `failedTests` count, because a check that only greps for a failure glyph
would see nothing on a crash.

| Mutation | Redden target | Result |
|---|---|---|
| A: `CaptureSession.append` always sets `pendingFlipPrompt` | CAP-05's suppression | `CaptureScreenUITests.swift:110` — "the prompt fired on a photograph that already read TWO sides". log: `1 test, 1 failure`. xcresult: `passed 0 / failed 1`. |
| B: `CaptureSession.append` never sets it | CAP-05's firing | `CaptureScreenUITests.swift:81` — "no flip prompt after fixture 1". log: `1 test, 1 failure`. xcresult: `passed 0 / failed 1`. |
| D: `FixtureLineSegmenter` stamps `bpm: 174` on every track | the walk's rewritten step 5 | `CrateWalkUITests.swift:122` — "the new crate shows neither a running order nor the empty-order placeholder". log: `1 test, 1 failure`. xcresult: `passed 0 / failed 1`. |

A and B are the same claim inverted in opposite directions, which is what makes "fires on 1,
suppressed on 2" a measurement rather than a coincidence. All three were reverted and the tree
verified clean (`git diff --stat VinylSetBuilderCore/` empty) before the final run.

## Verification output, verbatim

```
./Scripts/test.sh        → Test run with 168 tests in 0 suites passed after 0.025 seconds
./Scripts/build-app.sh   → ** BUILD SUCCEEDED **
./Scripts/ui-test.sh     → Executed 3 tests, with 0 failures (0 unexpected) in 151.820 seconds
                           ** TEST SUCCEEDED **
build/ui.xcresult        → result Passed | passed 3 | failed 0 | skipped 0
./Scripts/collect-screenshots.sh → collected 20 screenshot(s)
ls Artifacts/screenshots/03-03-*.png | wc -l  → 4
ls Artifacts/screenshots/02-walk-*.png | wc -l → 15
grep -rn "CapturePlaceholderView\|capture-add-fixture-button" App/ UITests/ → nothing
grep -rn "VinylEntry.label" App/                                           → nothing
```

Core suite is 168, unchanged — this plan added no Core code, by design.

## Screenshots — all nineteen, looked at

Purged before the run (`find … -name '03-03-*.png' -delete`, same for `02-walk-*`), so no count
could pass on a leftover. `min`/`max`/`mean` are the V2 pallor probe; `title` is the large
navigation title's ink in the title band.

| # | Frame | State | mean | title | Read as |
|---|---|---|---|---|---|
| 1 | `03-03-capture-empty.png` | guide, empty strip | 156.13 | yes | square guide 872×873 centred on black, caption, "0 records", shutter + Done |
| 2 | `03-03-capture-flip-prompt.png` | fixture 1, prompt UP | 172.15 | yes | "Only one side read / HIGHER", Skip + Scan, 1 record, green `Read` pill |
| 3 | `03-03-capture-one-item.png` | after Skip | 154.69 | yes | prompt gone, tile and pill remain |
| 4 | `03-03-capture-flip-suppressed.png` | fixture 2, NO prompt | 153.04 | yes | 2 records, "HIGHER" + "Emotif/Xstatic EMF2029", two `Read` pills, no banner |
| 5 | `02-walk-01-crate-list.png` | crate list | 242.37 | yes | "1 record" / "4 records" — V1 still closed |
| 6 | `02-walk-02-new-crate-sheet.png` | new-crate sheet | 233.70 | yes | "Test Crate" typed, keyboard up |
| 7 | `02-walk-03-capture-empty.png` | capture, new crate | 157.27 | **no (V9)** | guide + "0 records"; **V8 gone** — no "Camera arrives in Phase 3" |
| 8 | `02-walk-04-capture-with-vinyl.png` | after the shutter | 173.28 | **no (V9)** | 1 record, prompt, `Read` — **differs from frame 7, closing D-02-04-1** |
| 9 | `02-walk-05-new-crate-detail.png` | after Done | 242.81 | **no (V9)** | **"Nothing sequenced yet" + "Not in the set (1)" — V7 closed** |
| 10 | `02-walk-06-crate-detail-sequenced.png` | Friday Warehouse | 242.52 | **no (V9)** | rows 1–2 with 170/5A, 172/8A |
| 11 | `02-walk-07-not-included-expanded.png` | bucket expanded | 243.46 | **no (V9)** | **V3 still visible** ("Vinyl 2"/"Vinyl 3"); **V4 still visible** (— / — badges) |
| 12 | `02-walk-08-detail-edit-mode.png` | edit mode | 243.65 | **no (V9)** | remove circles + reorder grabbers present |
| 13 | `02-walk-09-detail-manual-order.png` | manual order | 243.58 | **no (V9)** | "Custom order" + Restore; rows swapped |
| 14 | `02-walk-10-detail-restored.png` | restored | 243.65 | **no (V9)** | back to "Running order", original order |
| 15 | `02-walk-11-add-more-capture.png` | Add More | 156.85 | **no (V9)** | Friday Warehouse, "0 records" — **V11**, session-scoped by design |
| 16 | `02-walk-12-detail-after-remove-vinyl.png` | after remove | 242.50 | **no (V9)** | one row left |
| 17 | `02-walk-13-second-crate-different-selection.png` | Sunday Chill | 242.33 | **no (V9)** | a different Photek track, 174/9A — CRATE-07 holds |
| 18 | `02-walk-14-crate-list-after-delete.png` | after delete | 243.12 | **no (V9)** | "3 records" — the count followed the removal |
| 19 | `02-walk-15-crate-list-empty.png` | empty | 253.52 | **no (V9)** | "No Crates Yet" |

Pallor probe: **`SUSPECT: none`, 19 frames, three separate runs.**

## Visual defects filed

| # | What | Severity | Owner |
|---|---|---|---|
| ~~V7~~ | **CLOSED** — the empty running order is now photographed, and the assertion behind it was proved able to fail (Mutation D) | — | Closed |
| ~~V8~~ | **CLOSED** — the scaffolding capture screen is deleted | — | Closed |
| V9 | 13 of the walk's 15 frames render no large navigation title. **Not settle** (identical at 3.0s and 4.0s), **not disabled** (every control taps), **not caused by this plan** (the same screens have their titles in plan 02-03's frames, and `CrateDetailView` was not touched) | Low | Phase 4 |
| V10 | The framing guide shrinks 872→686 px (−21%) when the flip prompt pushes into the layout. The arithmetic is right at both sizes; a live viewfinder wants a fixed one | Low | Phase 10 |
| V11 | Add More shows "0 records" for a crate holding four — CAP-03's own wording licenses it, recorded so a reviewer is not surprised | Informational | Phase 4 |

**V3's second sighting was NOT obtained, and is not claimed.** CONTEXT.md §6 predicted it on the
post-Done detail screen; that screen's not-included bucket is **collapsed by default**, so no
picture in this set shows the label. Expanding it needs a sixteenth walk state, which this plan
was forbidden to add. Carried to 03-05, which owns the full walk. A row without a named
screenshot is an opinion, not a defect.

## Deviations from plan

**1. [Commit granularity] Tasks 1 and 2 landed in one commit.** `CaptureView`'s body references
`CaptureThumbnailStrip` and `FlipSidePromptView` directly, so a Task-1-only commit would not have
compiled and the per-task commit gate requires a building tree. Both tasks' automated
verifications were run and passed. Commit `cdb166b`.

**2. [Rule 2 — evidence correctness] `ScreenshotRecorder`'s settle was raised, measured, and put
back.** The frame audit found the large navigation title missing on 13 frames. V2's protocol
mandates raising the settle before treating anything as a styling question, so the full suite was
re-run at 4.0/5.0. The same 13 frames were still title-less with **identical** title-band ink, so
the raise bought nothing but 15 s a run and was reverted to 3.0/4.0. The doc comment now records
the experiment so nobody repeats it. This is a third full suite run, not a lowered threshold.

**3. [Scope boundary] V9 was filed, not fixed.** It reproduces on `CrateListView` and
`CrateDetailView`, which this plan did not touch, and on screens that render correctly in plan
02-03's own frames. Fixing Phase 2's navigation container is out of this plan's scope.

## Nothing FAILED

No task was abandoned, no assertion was loosened, no fallback was needed. The simulator booted
first time on all six `xcodebuild test` invocations (3 full + 3 mutation runs).

## Notes for 03-04 and 03-05

- `CaptureThumbnailStrip` already takes an `onTap: (CaptureItem) -> Void`; `CaptureView` passes an
  empty closure. **03-04 adds a `.sheet`, not a button.**
- The status pill is a **sibling of** the tile's `Button`, not inside its label — a `Button` merges
  its label's children into one accessibility element and `capture-thumb-status-{n}` would vanish.
  Do not move it inside when styling the tile.
- `app.otherElements` is the working query for both `capture-framing-guide` and
  `capture-flip-prompt`; `app.scrollViews` for `capture-thumbnail-strip`. Live-verified, not guessed.
- `FixturePhotoSource` is an **actor** and is rebuilt per screen appearance, so `capture-thumb-{n}`
  restarts at 1 on every entry to the screen — including after Add More.
- The framing guide's rendered a11y frame on iPhone 16 Pro is `(55.67, 238.0, 290.67, 291.0)`,
  reproducible to the digit across runs. 03-05 can assert against it.

## Self-Check: PASSED

Every file, screenshot and commit this summary names was verified to exist on disk, and the
three mutation line numbers were re-read from source to confirm they still point at the
assertions they are credited with.

- 8 files claimed created/modified — all found; `CapturePlaceholderView.swift` confirmed deleted
- 4 `03-03-*.png` claimed — all found on the host after the purge
- commits `cdb166b`, `bb8ff60` — both found in `git log`
- `CaptureScreenUITests.swift:81` → the flip-prompt `waitForExistence` (Mutation B's target)
- `CaptureScreenUITests.swift:110` → the flip-prompt `waitForNonExistence` (Mutation A's target)
- `CrateWalkUITests.swift:122` → the `empty-running-order` assertion (Mutation D's target)
- `ScreenshotRecorder` settle values read back as 3.0 / 4.0, as the deviation note claims
