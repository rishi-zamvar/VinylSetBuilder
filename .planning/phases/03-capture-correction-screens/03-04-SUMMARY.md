---
phase: 03-capture-correction-screens
plan: 04
subsystem: ui
tags: [swiftui, xcuitest, correction, ocr, accessibility-identifiers, screenshots, mutation-testing]

requires:
  - phase: 03-02
    provides: SegmentationDraft (splitLine / mergeUp / setText / addLine / tracks), DraftLine, RawObservationRows, RawObservationRow
  - phase: 03-03
    provides: CaptureView, CaptureThumbnailStrip's per-tile onTap closure, ScreenshotRecorder, the capture identifier contract
  - phase: 03-01
    provides: CaptureItem (observations, displayLabel), FixtureObservations, FixtureLineSegmenter
  - phase: 02
    provides: CrateStore.update as the single crate write path, CrateDetailView.commit precedent
provides:
  - "InspectCorrectSheet — SEG-07's editable track lines with one-tap split, one-tap merge-up, always-live hand entry, add-a-line, Apply and Close"
  - "RawObservationListView — OCR-04's full observation list, untrusted reads included, confidence rendered white-on-saturated"
  - "The write-back path: a corrected vinyl's candidates replaced and committed through CrateStore.update, no second mutator"
  - "InspectSheetUITests — five photographed states, every count two-sided, both {n}-family negative controls"
  - "The inspect-sheet accessibility-identifier contract, live-verified against the real accessibility tree"
affects: [03-05, phase-06-segmentation, phase-11-wiring]

tech-stack:
  added: []
  patterns:
    - "The sheet holds no rules: it calls SegmentationDraft's four mutators and RawObservationRows.make and implements none of them"
    - "A custom Binding that writes only on a REAL change — a text field's focus echo must not reach a mutator with delete-on-blank semantics"
    - "Scroll elements into view by window-frame containment, never by isHittable, which throws rather than returning false for an element with no activation point"
    - "Mutation-based negative controls confirmed from BOTH xcodebuild's log and build/ui.xcresult's failedTests"

key-files:
  created:
    - App/Views/InspectCorrectSheet.swift
    - App/Views/RawObservationListView.swift
    - UITests/InspectSheetUITests.swift
  modified:
    - App/Views/CaptureView.swift
    - .planning/VISUAL-DEFECTS.md

key-decisions:
  - "The raw-text frame is photographed on fixture 1, not fixture 6: IMG_0503's 16 observations are ALL confidence 1.00, so it cannot show OCR-04's untrusted reads at all"
  - "The UI test is its own file, not five more states in CrateWalkUITests — reaching fixture 6 needs six shutter presses inside a walk whose fifteen-state shape other plans assert on"
  - "Apply and Close live in a fixed header/footer rather than the scroll content, so neither can be scrolled out of reach"
  - "A plain Button + `if` rather than DisclosureGroup, so inspect-raw-text-section resolves as exactly one button"
  - "inspect-raw-obs-{n} is one leaf element with the isStaticText trait, so it resolves as the staticText the frozen contract names"

patterns-established:
  - "Pattern: commit a fix BEFORE mutating the file it lives in — `git checkout --` on a mutation also discards uncommitted work in that file"
  - "Pattern: assert the line count immediately after a tap that should focus a field, so a stray tap reads as a sentence rather than a missing-snapshot error three lines later"

requirements-completed: [OCR-04, SEG-07]

duration: 48min
completed: 2026-08-30
---

# Phase 3 Plan 04: The Inspect / Correct Sheet Summary

**A correction sheet where split, merge-up and hand entry are each literally one tap against the owner's real OCR — proved by two-sided line-count deltas rather than by a screenshot — sitting above an OCR-04 raw-text list that keeps the 0.30 reads the segmenter threw away, with the write-back routed through the one `CrateStore.update` path the crate screen already uses.**

## What shipped

| Artifact | Requirement | What it does |
|---|---|---|
| `App/Views/InspectCorrectSheet.swift` (257 lines) | SEG-07 | Editable lines first, `Add a line`, a collapsed raw-text disclosure, fixed Close/Apply. Merge-up disabled on row 1, where Core makes it a no-op. |
| `App/Views/RawObservationListView.swift` (71 lines) | OCR-04 | Every observation with its 1-based number, verbatim text and preformatted confidence. Nothing hidden, nothing re-formatted. |
| `App/Views/CaptureView.swift` (modified) | — | The thumbnail strip's existing `onTap` closure now presents the sheet. The screen gained a sheet, not a button. |
| `UITests/InspectSheetUITests.swift` (303 lines) | both | Six real sleeves shot, both sheets driven, five states photographed. |

Every identifier in CONTEXT.md §5's sheet table exists **and was verified against the live
accessibility tree with the element type the table names** — `inspect-line-{n}` came back as
`Other`, `inspect-raw-obs-{n}` as `StaticText`, `inspect-line-field-{n}` as `TextField`, the rest
as `Button`. Not assumed: XCUITest's own log names the type on every query.

## Verification — actual output

```
./Scripts/test.sh          -> Test run with 168 tests in 0 suites passed after 0.025 seconds
./Scripts/build-app.sh     -> ** BUILD SUCCEEDED **        (iphoneos SDK, no signing)
./Scripts/ui-test.sh       -> Executed 4 tests, with 0 failures (0 unexpected) in 213.565s
                              ** TEST SUCCEEDED **
build/ui.xcresult          -> passed 4  failed 0  result Passed
./Scripts/collect-screenshots.sh -> collected 25 screenshot(s)
ls Artifacts/screenshots/03-04-*.png | wc -l -> 5      (after a purge)

grep -rn "VinylEntry.label" App/                                  -> nothing (D-03-6 holds)
grep -rn "String(format:" App/Views/RawObservationListView.swift   -> nothing (Core formats once)
```

The `TEST SUCCEEDED` / 0-failed result is confirmed **twice from independent sources**: xcodebuild's
own log line, and `build/ui.xcresult`'s `passedTests`/`failedTests` read back through
`xcresulttool`. The four tests are the Phase 2 walk, the smoke test, `CaptureScreenUITests` and
this plan's `InspectSheetUITests` — the two earlier suites are still green against the modified
`CaptureView`.

## The five frames

All five were **looked at**, twice: once on the run that produced them and again on the final
clean run after the purge. Not sampled.

| File | Fixture | State | What is in it |
|---|---|---|---|
| `03-04-sheet-lines.png` | IMG_0503 | the draft as opened | 16 over-split lines; merge-up dimmed on row 1, live on rows 2-16 |
| `03-04-sheet-raw-text.png` | IMG_0498 | raw text expanded | 9 track lines above, 11 raw rows below, `зali/ti\| Fuck W` at **0.30** in dark red among the 1.00 greens |
| `03-04-sheet-after-merge.png` | IMG_0503 | after one `inspect-merge-up-2` | 15 lines; row 1 is now `Zzz. Cause 4 Concern-` |
| `03-04-sheet-after-split.png` | IMG_0503 | after one `inspect-split-1` | 16 lines; rows 1-2 are `Zzz. Cause` / `4 Concern-` |
| `03-04-sheet-hand-typed.png` | IMG_0503 | after Add a line + typing | 17 lines; row 17 reads `DUBPLATE WHITE LABEL` |

## Measurement counts — how many times each claim was measured

The plan asked for this explicitly. Where a claim has one observation, it says one.

| Claim | Observations | Detail |
|---|---|---|
| **Merge-up removes exactly one line** | **3** | 03-02's Core unit test; this plan's UI test (16 -> 15, two-sided); mutation E proving the UI assertion can redden |
| **Split restores the line** | **3** | 03-02's Core unit test; this plan's UI test (15 -> 16, two-sided); the picture, where rows 1-2 read `Zzz. Cause` / `4 Concern-` |
| **Hand entry lands the typed text** | **2** | 03-02's Core `setText` test; this plan's UI test reading `field.value` back and asserting it equals `DUBPLATE WHITE LABEL` and is non-empty |
| **The raw list keeps the untrusted reads** | **3** | the UI test's strict `raw(11) > lines(9)`; the confidence labels (`inspect-raw-obs-4` and `-10` contain `0.30`, `-1` contains `1.00`); mutation F, which reddens when they are filtered out |
| **Apply writes back / Close does not** | **3** | reopening after Apply shows 17 lines two-sided; reopening after a merge-then-Close shows 17 again; mutation G, which reddens when `store.update` is removed |
| **Merge-up is disabled on row 1** | **1** | `isEnabled` asserted false on row 1 and true on row 2 in one run. **One observation.** The picture shows a dimmed arrow, which is the same run's evidence, not an independent one. |
| **The empty-line focus echo deletes the row without the guard** | **6** | red 4 times (first run; three runs after an accidental revert), green 2 times with the guard, plus the `app.textFields` dump showing 16 of 17 identifiers |
| **`isHittable` throws rather than returning false off-screen** | **1** | one run, `Failed to determine hittability of "capture-thumb-6"`. **One observation** — but it is a runner behaviour, not a product claim, and the frame-containment replacement has since run green 8 times |

## Deviations from plan

### 1. The raw-text frame is fixture 1, not fixture 6 — the plan's premise was measurably wrong

The plan says: *"On `IMG_0503` that is 16 trusted against a larger raw total — assert the
inequality."* **`IMG_0503` has 16 observations and all 16 are confidence 1.00.** Counted directly
out of the generated fixture:

```
IMG_0498  total 11  trusted  9      IMG_0503  total 16  trusted 16
```

A strict `raw > lines` assertion on fixture 6 would have failed, and
`03-04-sheet-raw-text.png` taken there would have shown zero untrusted rows while its own caption
claimed *"untrusted reads visible"* — a picture that lies is worse than no picture.

**Resolved by splitting the fixtures, not by weakening the assertion.** The four correction states
stay on fixture 6, the richest real read, exactly as planned. The raw-text state moves to fixture
1, which has two genuine 0.30 reads (`зali/ti| Fuck W`, `Remi:600`) that appear nowhere else in
the app — the exact thing OCR-04 exists for. The inequality is still asserted as an inequality
(`XCTAssertGreaterThan(raw, lines)`), never a hardcoded pair, so a fixture change cannot make it
vacuous. Frame count is still five.

### 2. The UI test is its own file, not five more states in `CrateWalkUITests`

The plan's task-2 `<files>` names `UITests/CrateWalkUITests.swift`. Reaching fixture 6 needs six
shutter presses, and the walk is Phase 2's fifteen-state ship criterion whose shape 03-03 was
explicitly forbidden to change and which 03-05 owns extending. `InspectSheetUITests` follows
`CaptureScreenUITests`'s precedent instead: enter through CRATE-05's Add More, do one job, leave
the walk alone. The walk is still green (110.8 s, 0 failures) and still produces its fifteen
frames.

### 3. [Rule 1 — Bug] Tapping an empty hand-added line deleted it

**Found during:** task 2, on the first UI run. **Issue:** a `TextField` re-publishes its current
value through its binding when it takes focus. The empty line added by `Add a line` therefore
sent `""` into `SegmentationDraft.setText`, which owns the clear-to-delete rule, and the row was
removed by the very tap that should have focused it — the keyboard never appeared at all.
**Fix:** the binding writes only on a real change (`current != newText`), so an echo is inert
while a deliberate clear-to-delete still behaves exactly as Core tested it. Core was not touched.
**Files:** `App/Views/InspectCorrectSheet.swift`. **Commit:** `c4b9a2a`.

### 4. [Rule 3 — Blocking] `isHittable` throws on an element with no activation point

`capture-thumb-6` sits off the right edge of the horizontal strip. `while !thumb.isHittable` did
not loop — it aborted the test with *"Failed to determine hittability … Activation point invalid"*.
Replaced with window-frame containment of the element's midpoint, which is readable in that state.
**Files:** `UITests/InspectSheetUITests.swift`. **Commit:** `aecb92b`.

## Negative controls — four mutations, all reddened cleanly

Full table in `.planning/VISUAL-DEFECTS.md`. Every one confirmed from the log **and** from
`build/ui.xcresult`; none crashed the runner.

| # | Mutation | Result |
|---|---|---|
| E | merge-up button wired to `{ }` | `InspectSheetUITests.swift:148` — "one merge-up took 16 lines to 16". xcresult `passed 0 / failed 1` |
| F | raw list filtered to `\.isTrusted` | `InspectSheetUITests.swift:97` — "IMG_0498 produced 11 observations; the sheet lists 3". xcresult `passed 0 / failed 1` |
| G | `apply()` never calls `store.update` | "Apply did not write 17 corrected lines back — reopened with 16". xcresult `passed 0 / failed 1` |
| H | the binding's equality guard removed (accidental, then deliberate) | the empty line is deleted by the tap; red 4×, green 2× with the guard |

F is the interesting one: hiding the two 0.30 reads made the walk stop at **3**, not at 9, because
removing observation 4 breaks the contiguity that `inspect-raw-obs-{n}` is counted by. The
contiguity property is doing real work.

**A procedural lesson worth more than the mutation that produced it.** Reverting mutation E with
`git checkout -- App/Views/InspectCorrectSheet.swift` also discarded the *uncommitted* fix from
deviation 3, which lived in the same file, and the suite went red on the next three runs. Diagnosed
by dumping `app.textFields` rather than by guessing. **Commit a fix before mutating the file it
lives in.**

## Visual audit — two new defects, and two explicit "none found"

Filed in `.planning/VISUAL-DEFECTS.md`:

- **V12 (Medium, Phase 6):** the sheet titles a record `Zzz.` — a price-sticker fragment — on a
  photograph that also read `Cause 4 Concern` and `A: High Down` at 1.00.
  `CaptureItem.displayLabel` takes the first trusted observation in **reading order**, and reading
  order is spatial, not semantic. Not a regression and not V3: it is the ceiling of D-03-6's
  naming rule made visible. Visible in 4 of the 5 frames; independently visible in the fixture
  source and in XCUITest's own strip dump (`label: 'Zzz.'`).
- **V13 (Low, plan 03-05):** long-line behaviour in the correction field is **not assessable** from
  this capture. The widest line any frame renders is 20 characters; the corpus's longest real read
  is 106 (`IMG_0505`), on a fixture no 03-04 frame opens. Honest "unknown", not a guess.
- **Contrast on the confidence values — NONE FOUND.** V4's failure mode (`.secondary` on
  `.thinMaterial`) is not repeated: `1.00` is white on solid dark green, `0.30` white on solid dark
  red, and the distinction is carried by the number as well as the colour.
- **Controls colliding on a long line — NONE FOUND**, checked at 9 lines and at 17.

## Nothing FAILED

Every gate in the plan's `<verification>` block ran and passed: the Core suite (168), the
device-SDK build, the unattended UI suite (4/4), the screenshot collection, the five-file count
gate after a purge, and both greps. No state was dropped; the plan's keyboard fallback was not
needed — hand entry was photographed, not deferred.

## Known Stubs

None. Every line the sheet renders comes from a real `SegmentationDraft` built from real
`FixtureObservations` data, and Apply writes real `Track`s into the real crate. The one deliberate
Act I limitation — `FixtureLineSegmenter` emitting one line per trusted observation instead of
segmenting (D-03-4) — is inherited from 03-01, is the reason merge is exercised on the first tap,
and is Phase 6's to replace.

## Self-Check: PASSED

Every file this summary claims was created exists on disk with the line count quoted
(`InspectCorrectSheet.swift` 257, `RawObservationListView.swift` 71,
`InspectSheetUITests.swift` 303), all five `03-04-*.png` are on the host after the purge, all
three commit hashes resolve in `git log`, and the two test-file line numbers cited for mutations
E and F (`148`, `97`) still point at the assertions those mutations reddened.
