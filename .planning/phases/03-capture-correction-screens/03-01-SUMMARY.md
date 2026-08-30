---
phase: 03-capture-correction-screens
plan: 01
subsystem: capture
tags: [capture, fixtures, framing-guide, flip-prompt, ocr, seams]
requires:
  - TextObservation, Track, VinylEntry, Side, ResolutionState (Domain)
  - LabelSegmenting (Segmentation)
  - .local/ocr/ocr2_out.json (the owner's real OCR run — gitignored, optional)
provides:
  - FixtureObservations (generated: 12 fixtures / 104 observations / 89 trusted)
  - FramingGuide + FramingGuide.sleeve (CAP-02)
  - CaptureItemStatus, CaptureItem, CaptureSession (CAP-03, CAP-05)
  - PhotoCapturing (the async seam Phase 10 swaps a real camera into)
  - FixturePhotoSource (the twelve-fixture ground-truth source)
  - FixtureLineSegmenter (D-03-4 Act I stub for LabelSegmenting)
  - Scripts/generate-ocr-fixtures.sh
affects:
  - plan 03-03 (CaptureView binds to CaptureSession/FramingGuide/FixturePhotoSource verbatim)
  - plan 03-05 (the XCUITest walk is the second observation of both ship numbers)
  - phase 06 (FixtureLineSegmenter is the seam SEG-01…06 replaces)
  - phase 10 (PhotoCapturing is the seam the real camera replaces)
tech-stack:
  added: []
  patterns:
    - "Generated fixture data gates its own output against the Core purity token list before writing"
    - "Behavioural claims asserted as NAMED SETS, never counts — then proven to redden on an injected defect"
    - "An async protocol seam written before anything awaits, so the later swap moves no call site"
key-files:
  created:
    - Scripts/generate-ocr-fixtures.sh
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureObservations.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixturePhotoSource.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureLineSegmenter.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Capture/FramingGuide.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Capture/CaptureSession.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Capture/PhotoCapturing.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/FixtureObservationsTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/FramingGuideTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CaptureSessionTests.swift
  modified:
    - .planning/research/OCR-SPIKE.md
    - .planning/phases/03-capture-correction-screens/CONTEXT.md
decisions:
  - "The trusted count is 89, not the plan's 88 — 88/101 is the FIRST OCR run, the fixtures come from the second (104/89). Measured, then the two stale docs corrected."
  - "FixturePhotoSource is an actor, not the struct CONTEXT.md sketched — capture() advances a counter and the protocol is Sendable"
  - "Observations are paired to the hand-scored table by FILENAME, never by parallel index, so a reorder of either cannot silently mis-attribute a record's text"
  - "displayLabel treats an all-whitespace trusted reading as no reading — a blank thumbnail label is a defect, not a name"
  - "CaptureSession.append assigns pendingFlipPrompt rather than only setting it, so a fresh shutter press supersedes a stale prompt"
metrics:
  duration: ~40 min
  completed: 2026-08-30
---

# Phase 3 Plan 01: Capture Core Summary

The twelve real photographs are now committed Swift data, the sleeve framing guide is a value
type that can tell itself from a reticle, and the capture session decides the flip prompt from a
hand-scored table whose two ship numbers are asserted as named sets and proven to redden.

## Tasks Completed

| Task | Name | Commit | Files |
|---|---|---|---|
| 1 | Transcode the real OCR run, with a purity gate on its own output | `1d6ff7d` | `Scripts/generate-ocr-fixtures.sh`, `Fixtures/FixtureObservations.swift`, `FixtureObservationsTests.swift` |
| 2 | FramingGuide, CaptureItem/Status, CaptureSession, the flip rule | `3f0bf86` | `Capture/FramingGuide.swift`, `Capture/CaptureSession.swift`, `FramingGuideTests.swift`, `CaptureSessionTests.swift` |
| 3 | The PhotoCapturing seam, the twelve-fixture source, the Act I segmenter | `409232b` | `Capture/PhotoCapturing.swift`, `Fixtures/FixturePhotoSource.swift`, `Fixtures/FixtureLineSegmenter.swift`, `CaptureSessionTests.swift` |

## Measured test output, against the 113 baseline

```
$ ./Scripts/test.sh
✔ Test run with 168 tests in 0 suites passed after 0.024 seconds.

$ ./Scripts/test.sh --filter FixtureObservations   → Test run with  6 tests ... passed
$ ./Scripts/test.sh --filter FramingGuide          → Test run with  2 tests ... passed
$ ./Scripts/test.sh --filter CaptureSession        → Test run with 20 tests ... passed
$ ./Scripts/test.sh --filter CorePurity            → Test run with  1 test  ... passed
$ ./Scripts/build-app.sh                           → ** BUILD SUCCEEDED **
```

113 baseline → **168**. **This plan added 28** (6 + 2 + 20). The other 27 are plan 03-02's,
which executed concurrently in the same tree; the 168 figure is the shared total, not this
plan's alone. No filtered run reported 0 tests, so none passed vacuously.

Gate checks:

```
grep -rn "VinylEntry.label" .../Capture/                  → nothing (D-03-6 clean)
grep -c "TextObservation(" .../FixtureObservations.swift  → 104
./Scripts/generate-ocr-fixtures.sh (2nd run)              → "unchanged" (idempotent)
```

## How many times each behavioural claim was measured

Discipline 1 of the two: this section is the honest count, not an implication.

| Claim | Measurements **so far** | Where the next one comes from |
|---|---|---|
| The flip prompt fires on `{1,3,4,5,7,8,10,11,12}` and is suppressed on exactly `{2, 6, 9}` | **1** — this plan's Core unit test over `FixturePhotoSource` | **Observation B is plan 03-05's XCUITest**, counting real prompts across a 12-shot session. Until that runs, this claim is single-sourced and should be read as such. |
| The status tally is 6 read / 5 partial / 1 unread | **1** — `CaptureSession.statusTally` over the twelve | 03-05's XCUITest reading `capture-thumb-status-{n}` labels |
| The guide is sleeve-sized and not label-sized | **1** — geometry only | Never in the simulator. U10 already records that this is unanswerable without a live camera; Phase 10 is where a real 12" sleeve at arm's length settles it. |
| 104 observations / 89 trusted | **2, independently** — counted in Python straight off `ocr2_out.json`, and re-counted in Swift off the generated table by `FixtureObservationsTests` | — |
| The generator's purity gate blocks a banned token | **2** — clean run writes; poisoned run refuses (below) | — |

## Negative controls built, and proven to fail

Discipline 2 of the two: every one of these was **run against an injected defect**, not reasoned
about.

1. **Purity gate.** Poisoned `IMG_0498`'s first string to `"HIGHER SwiftUI"` and ran the
   generator's Python. Output: `PURITY GATE FAILED — refusing to write … SwiftUI <- IMG_0498.HEIC:
   'HIGHER SwiftUI'`, exit 1, **no file written**. The gate is not decorative.
2. **The radian conversion.** `FixtureObservationsTests` asserts the angle is within 1e-6 of
   `-93.945…° × π/180` **and** is NOT within 1e-6 of the raw degree figure. A skipped conversion
   reddens. (The plan's illustrative value `-1.6396436585` is wrong in the 8th decimal; the real
   figure is `-1.6396528464`. The test computes it rather than quoting it, so this did not matter.)
3. **The framing guide.** `sleeve.edgeCoverage > 0.6` **and** `FramingGuide(aspectRatio: 1.0,
   insetFraction: 0.45).edgeCoverage < 0.6` in one test. Without the second half the first passes
   on any square guide, reticle included.
4. **The flip split — the exact stated worry.** Injected a defect that suppresses the prompt on
   the **wrong three** fixtures while keeping the count at three (gave `IMG_0500` two markers,
   took one off `IMG_0503`). Result: `suppressed → [2, 9, 3]) == ([2, 6, 9])` **failed**, and the
   named-markers test failed alongside it. A count-based assertion would have passed on that
   defect. Restored byte-identical (`cmp` clean) and re-ran green.
5. **The status tally.** Injected `IMG_0507 .unread → .partial`; the tally assertion failed with
   `[partial: 6, read: 6]`. Restored.
6. **The segmenter's confidence filter.** Three observations all at 0.5 must yield an empty array.
   A segmenter ignoring confidence entirely would emit three and still pass every fixture-count
   assertion elsewhere.
7. **`^Vinyl \d+$`.** The V3 guard loop asserts no fixture matches — and then asserts the pattern
   *does* match the literal `"Vinyl 2"`, so the loop is not testing a pattern that never matches
   anything.
8. **`vinylEntry(for:)`** is asserted to return a value for a held id **and** nil for one the
   session does not hold.

## Deviations from Plan

### 1. [Rule 1 — measurement contradicts the plan] The trusted count is 89, not 88

- **Found during:** Task 1, before a line of Swift was written.
- **Issue:** The plan and CONTEXT.md §1 both assert "88 trusted", sourced from `OCR-SPIKE.md`
  finding 4 ("Of 104 observations, 88 were 1.00"). Counting `.local/ocr/ocr2_out.json` directly
  gives **89** at 1.00, 2 at 0.50, 13 at 0.30, of 104.
- **Root cause, established rather than guessed:** `.local/ocr/ocr_out.json` — the **first** run —
  holds 101 observations, **88** of them at 1.00. The spike was later re-run (the doc's own line 6
  says "101 → 104"); the total was updated to 104, the trusted count was not. 88 belongs to a
  corpus that is not the one Act I's fixtures are generated from.
- **Fix:** the generator computes the counts and writes them into its own header; the test asserts
  **89**, measured. Per CONTEXT.md's own rule — "where the spec and the 12 real photographs
  disagree, the photographs win". Corrected `.planning/research/OCR-SPIKE.md` (with a dated
  correction note naming both runs, so the 88 figure is explained rather than quietly erased) and
  CONTEXT.md §1 finding 4. `03-01-PLAN.md` is left as-written: it is the record of what was planned.
- **Consequence for later plans:** none. Nothing downstream keys on 88; the trusted *tier*
  (`conf >= 1.0`) is unchanged, and `FixtureLineSegmenter`'s per-fixture counts (16 for `IMG_0503`,
  3 for `IMG_0507`) were correct as planned.

### 2. [Rule 3 — contract could not compile as sketched] `FixturePhotoSource` is an actor

- CONTEXT.md §4 sketches `public struct FixturePhotoSource: PhotoCapturing`, but `capture()`
  advances a counter and `PhotoCapturing` is `Sendable`; a struct cannot mutate from a
  non-mutating async method. The plan's own action text anticipated this ("a `final class` (or an
  `actor`)"). Chose `actor` — fewer lines than a class plus a lock, and `capture()` was already
  `async`, so no call site sees a difference. `public init(crateID:)` is unchanged, and the
  key-link pattern `FixturePhotoSource\s*:\s*PhotoCapturing` still matches.

### 3. [Rule 2 — a defect the plan did not ask about] Observations paired by filename

- `FixturePhotoSource` holds the hand-written verdict table; `FixtureObservations` is generated.
  Indexing both positionally would silently mis-attribute a record's text if either ever
  reordered. Changed to a lookup by `file`. One line, removes the whole failure class.

### 4. [Rule 2] `displayLabel` skips an all-whitespace trusted reading

- The plan says "first observation with `confidence >= 1.0`, trimmed". Taken literally, a trusted
  observation that trims to empty yields a blank thumbnail label. It now falls through to the next
  trusted observation and then to `photoRef`. No current fixture exercises this.

### 5. [documentation] The doc comment could not name `VinylEntry.label`

- The D-03-6 gate is `grep -rn "VinylEntry.label" .../Capture/` returning nothing, and 03-05 runs
  the same grep. The comment explaining *why* the property is avoided tripped its own gate.
  Reworded to "the vinyl entry's own `label` property". The gate is clean.

## Concurrency note

Plan 03-02 executed in the same working tree at the same time. Its red-phase test file
(`SegmentationDraftTests.swift`) briefly broke compilation of the whole test target, which blocked
one filtered run of this plan's tests; it cleared once 03-02 landed its implementation, and no
retry or workaround was needed beyond waiting. Every commit here used explicit `git add <path>`,
so nothing of 03-02's was swept in. The 168-test total is the two plans' shared figure.

## What this leaves for the next plans

- **03-03** binds `CaptureView` to `CaptureSession`, `FramingGuide.sleeve` and
  `FixturePhotoSource`. All three rules live here; the screen holds none of them.
- **03-05** owes observation B on both ship numbers. Until it runs, the `{2, 6, 9}` claim and the
  6/5/1 tally each stand on **one** measurement.
- **Phase 6** replaces `FixtureLineSegmenter`; the `ponytail:` comment on it names that ceiling
  and points at SEG-01…06 so nobody mistakes it for an attempt at the real algorithm.
- **Phase 10** replaces `PhotoCapturing`'s body. No call site moves.

## Known Stubs

Both are intentional, named in D-03-3 / D-03-4, and each has its replacing phase recorded in
source:

| Stub | File | Replaced by |
|---|---|---|
| `FixtureLineSegmenter` — one line per trusted observation, no clustering or marker splitting | `Fixtures/FixtureLineSegmenter.swift` | Phase 6 (SEG-01…06/08). Deliberately over-splits so 03-04's merge is exercised on real data. |
| `FixturePhotoSource` — deals twelve committed fixtures instead of a camera | `Fixtures/FixturePhotoSource.swift` | Phase 10, behind the unchanged `PhotoCapturing` seam. |

`CaptureItem.sideMarkers` is hand-scored rather than derived — that is D-03-4, not a stub:
Phase 6 gives it a producer and the CAP-05 rule does not change.

## Nothing failed

No task was blocked, no fallback was taken, no fix-attempt limit was reached, and no verification
step was skipped. `./Scripts/ui-test.sh` was not run: this plan touches no app target code and
the plan does not list it.

## Self-Check: PASSED

All ten claimed files exist on disk; all three claimed commit hashes exist in `git log`.
`FixtureObservations.swift` is 554 lines and carries 104 `TextObservation(` constructions.

## Requirements deliberately NOT marked complete

`03-01-PLAN.md` carries `requirements: [CAP-02, CAP-03, CAP-05]`, and the executor workflow
would normally check them off here. It has not been done, on purpose. All three are worded as
things a *person sees* — "a framing guide overlay shows…", "a thumbnail strip shows…", "an
inline prompt offers Scan or Skip…". This plan shipped their **rules**, in Core, with no screen
attached. Plan **03-03** builds the overlay, the strip and the prompt, and is where the three
should be checked off. Marking them now would claim a working screen that does not yet exist.
