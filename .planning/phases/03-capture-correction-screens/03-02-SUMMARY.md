---
phase: 03-capture-correction-screens
plan: 02
subsystem: correction
tags: [correction, segmentation, ocr, presentation, seg-07, ocr-04]
requires:
  - Track, Side, ResolutionState (Domain)
  - TextObservation (Domain)
provides:
  - SegmentationDraft, DraftLine (SEG-07 — splitLine / mergeUp / setText / addLine / tracks())
  - RawObservationRow, RawObservationRows.make (OCR-04)
affects:
  - plan 03-04 (InspectCorrectSheet binds to this API verbatim — one call per button)
  - plan 03-05 (the XCUITest walk is the second, independent observation of every claim below)
tech-stack:
  added: []
  patterns:
    - "Pure value-type screen model, held in view state and committed via tracks() — the CrateDetailModel shape"
    - "Presentation strings formatted exactly once under en_US_POSIX — the TrackBadges rule"
    - "One private whitespace rule shared by split and merge, so the round trip cannot drift"
key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Correction/SegmentationDraft.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Correction/RawObservationRows.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/SegmentationDraftTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/RawObservationRowsTests.swift
  modified: []
decisions:
  - "splitLine splits at the word midpoint, odd counts favouring the first line — a marked ponytail ceiling, upgrade path is a character index"
  - "The draft carries the tracks' Side through untouched, so correcting a B-side read cannot silently republish it as A"
  - "setText stores text verbatim; only split and merge normalise whitespace, because collapsing a space as it is typed would make the field unusable"
  - "mergeUp ORs isHandEdited into the surviving line — absorbed hand-typed text stays flagged as hand-typed"
  - "DraftLine.id IS the Track.id it came from, which is what makes tracks() ids stable across calls"
metrics:
  duration: ~50 min
  completed: 2026-08-30
  tests_before: 113
  tests_after: 140 (this plan alone) / 168 (shared suite, with 03-01 landed)
---

# Phase 3 Plan 02: Correction Core Summary

`SegmentationDraft` — an over-split OCR read made correctable in one tap per operation (split,
merge up, hand-type, add) and converted back to contiguous `Track`s — plus `RawObservationRows`,
which projects every recognised observation including the 0.50/0.30 reads the trusted tier
discards, because those are exactly the rows you need when a record reads badly.

## The measured test count

| | Count |
|---|---|
| Baseline before this plan | **113** |
| This plan's own tests | **27** (19 `SegmentationDraft` + 8 `RawObservationRows`) |
| Baseline + this plan, measured in an isolated copy of the package | **140**, green |
| Shared suite once 03-01 also landed, `./Scripts/test.sh` | **168**, green |

`./Scripts/test.sh` final output, run twice consecutively:

```
✔ Test run with 168 tests in 0 suites passed after 0.023 seconds.
```

`./Scripts/test.sh --filter SegmentationDraft` → `19 tests ... passed`.
`./Scripts/test.sh --filter RawObservationRows` → `8 tests ... passed`.
`./Scripts/test.sh --filter CorePurity` → `1 test ... passed`.
`./Scripts/build-app.sh` → `** BUILD SUCCEEDED **` (first try, U7 did not recur).

## What was built

### `SegmentationDraft` — SEG-07, one call and one argument per operation

```swift
public struct DraftLine: Identifiable, Sendable, Hashable {
    public let id: UUID              // the Track.id it came from
    public var text: String
    public var isHandEdited: Bool
}

public struct SegmentationDraft: Sendable, Equatable {
    public let vinylID: UUID
    public private(set) var lines: [DraftLine]
    public init(vinylID: UUID, tracks: [Track])
    public mutating func splitLine(_ id: DraftLine.ID)
    public mutating func mergeUp(_ id: DraftLine.ID)
    public mutating func setText(_ id: DraftLine.ID, to text: String)
    public mutating func addLine()
    public func tracks() -> [Track]
}
```

Exactly CONTEXT.md §4's signatures, so 03-04 has nothing to negotiate. Behaviour worth naming:

- **mergeUp** joins into the line **above**, which survives with its id; the merged line
  disappears. On the first line and on an unknown id it does nothing — the Act I draft arrives
  over-split (D-03-4), so merge is the first tap most records get and it has to be safe anywhere.
- **splitLine** splits at the word midpoint, odd counts favouring the first line (5 → 3/2,
  3 → 2/1). A single-word line has no midpoint and is left exactly as it was.
- **setText** to empty or whitespace **removes** the line — that is how a person deletes a junk
  read, and a blank line left behind would become a blank row in the crate.
- **tracks()** drops blanks and renumbers `0..<n`, so a corrected vinyl is indistinguishable in
  shape from a segmented one. Ids are the lines' own, so two calls return the same tracks.

### `RawObservationRows` — OCR-04, evidence not summary

```swift
public struct RawObservationRow: Identifiable, Sendable, Hashable {
    public let id: Int            // 1-based, reading order
    public let text: String       // verbatim
    public let confidence: String // "1.00" / "0.50" / "0.30"
    public let isTrusted: Bool    // >= 1.0
}
public enum RawObservationRows { public static func make(_:) -> [RawObservationRow] }
```

Nothing is sorted, filtered, deduplicated or trimmed. `confidence` is formatted once under
`Locale(identifier: "en_US_POSIX")`, following `TrackBadges`.

## Discipline 1 — how many times each claim was measured

**One measurement each, from this plan's unit tests, plus a mutation kill.** The second
independent observation for every SEG-07 and OCR-04 claim is **03-05's XCUITest driving the real
buttons** and it does not exist yet. Nothing below is confirmed twice yet; saying otherwise would
be the exact overclaim this phase was told to stop making.

| Claim | Observation A (this plan) | Times run green | Observation B (still owed) |
|---|---|---|---|
| Split, merge and hand-entry each correct a draft in one call | 19 unit tests | 5 green runs (isolated ×2, repo ×3) | 03-05 XCUITest tapping `inspect-split-{n}` / `inspect-merge-up-{n}` |
| A corrected draft converts back to contiguous positions from zero | 3 of those tests | same 5 runs | 03-05 counting `inspect-line-{n}` after Apply |
| Raw text including the untrusted reads is renderable | 8 unit tests | 5 green runs | 03-05 reading `inspect-raw-obs-{n}` |
| The trusted tier is a tier, not a fraction | probed at 1.0, 0.999, 0.5, 0.3 | same 5 runs | 03-01's fixture data independently carries the same three real values |

The **inputs**, by contrast, are twice-grounded already: every string in both test files is quoted
verbatim from `.local/ocr/ocr2_out.json`, checked out of the JSON at execution time rather than
retyped from the spike write-up — `"The Message -"`, `"Brown"`, `"Dom &"`, `"Roland"`, `"0-44904"`
(IMG_0498), `"A: High Down"`, `"Cause 4 Concern"`, `"AAA: Strange Nat ure"` (IMG_0503), `"Da Lick"`
(IMG_0508, read four times over), `"·009"` (IMG_0499), `"Skynet 6.00g"` @0.50 (IMG_0500),
`"Remi:600"` @0.30 (IMG_0498).

## Discipline 2 — the tests are provably able to fail

Fourteen mutations were applied to the two implementations, one at a time, each reverted after
measuring. **All fourteen killed the suite.** Run in an isolated copy of the package so the
concurrent 03-01 executor's in-flight files could not confound the result.

`SegmentationDraft` (7/7):

| Mutation | Result |
|---|---|
| midpoint `(n+1)/2` → `n/2` (favour the second line) | 2 tests red |
| mergeUp loses its `index > 0` guard | **hard crash** — `Fatal error: Index out of range` inside the first-line no-op test; the run never completes |
| `tracks()` stops filtering blanks | 1 test red (count **and** positions) |
| splitLine's single-word guard `> 1` → `> 0` | 1 test red (count and full-value equality) |
| mergeUp joins with no space | 3 tests red |
| `tracks()` stops renumbering | 1 test red |
| setText stops removing cleared lines | 2 tests red |

`RawObservationRows` (7/7):

| Mutation | Result |
|---|---|
| filter to the trusted tier — the exact mistake OCR-04 exists to prevent | 3 tests red |
| threshold `>= 1.0` → `> 0.9` | the 0.999 test red |
| threshold `>= 1.0` → `>= 0.4` | the 0.999 test **and** the tier test red |
| ids 0-based | 1 test red (set equality and order) |
| text trimmed | the padding test red |
| rows sorted by text | 3 tests red |
| confidence `%.2f` → `%.1f` | the format test red |

The mergeUp guard mutation is worth a line on its own: it did **not** produce a tidy failed
expectation, it aborted the test runner. It is still a kill — but a suite that only grepped for
`✘` would have seen nothing, which is why the run output was read in full rather than filtered.

## Deviations from plan

**1. [Rule 3 — blocking] The shared test target was red for reasons outside this plan.**
The concurrent 03-01 executor landed `FramingGuideTests.swift`, `FixtureObservationsTests.swift`
and `CaptureSessionTests.swift` in their own RED phase, so `./Scripts/test.sh` could not compile
partway through this plan's execution. Their files were **not touched**. The mutation work was
instead run against an isolated `rsync` copy of the package in the scratch directory with only
those three in-flight files removed, and the shared suite was re-run to green (168) once 03-01
landed its implementations. No fix was applied to anything outside this plan's four files.

**2. The plan's `grep -rn "move(fromOffsets" VinylSetBuilderCore/Sources/` expects nothing and
returns one hit.** It is a pre-existing **doc comment** in
`Crates/CrateDetailModel.swift:108` that says the API *is not reachable from Core* — the
precedent the plan itself points at. There is no call. Out of this plan's scope, logged to
`deferred-items.md`, not edited.

**3. `SegmentationDraft` carries a private `side`.** CONTEXT.md §4's signature has no side
parameter, and defaulting `tracks()` to `.a` would silently rewrite a B-side read's side on
correction. The draft therefore stores the incoming tracks' side and hands it back. One stored
property, no signature change, no behaviour a caller can get wrong.

## Known stubs

None. Both types are complete implementations of their requirements; nothing here returns a
placeholder or an empty literal that a screen would render.

## Requirements

- **SEG-07** — split, merge and hand-type a segmentation result: Core half complete. The screen
  half is 03-04 and the proof-by-tapping is 03-05.
- **OCR-04** — raw recognised text inspectable: Core half complete, same two follow-ons.

## Self-Check: PASSED

All four created files exist on disk (`SegmentationDraft.swift` 117 lines, `RawObservationRows.swift`
43, `SegmentationDraftTests.swift` 259, `RawObservationRowsTests.swift` 111). All five commits
resolve: `1554406`, `dd0ba98` (Task 1 red/green), `ea95859`, `b66de63` (Task 2 red/green),
`8b814be` (this closure). Final `./Scripts/test.sh` re-run after the last 03-01 commit landed:
**168 tests passed**, with `--filter SegmentationDraft` 19 and `--filter RawObservationRows` 8.

`state advance-plan` was deliberately **not** run: 03-01 executes concurrently in the same wave
and both executors incrementing the same counter would double-advance it. `state update-progress`
recalculates from disk instead and reports `[███████░░░] 67%`.
