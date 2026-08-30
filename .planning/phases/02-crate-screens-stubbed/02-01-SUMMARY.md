---
phase: 02-crate-screens-stubbed
plan: 01
subsystem: crates
tags: [crate-detail, sequencing, manual-order, routing, presentation]
requires:
  - Crate, VinylEntry, Track, SequenceResult (Domain)
  - Sequencing protocol, BeamSearchSequencer (Sequencing)
  - CrateRows, SequencedRow, TrackBadges (Presentation)
  - CrateStore, Route, FixtureCrates
provides:
  - CrateDetailModel (CRATE-03 running order, CRATE-04 manual override, CRATE-07 pin)
  - OrderingMode
  - CrateStore.addMore(to:) (CRATE-05)
  - CrateStore.update(_:) (the detail screen's write-back path)
affects:
  - plan 02-03 (CrateDetailView binds to this API verbatim)
tech-stack:
  added: []
  patterns:
    - "Pure value-type screen model; init does no work, the caller sequences explicitly"
    - "Manual ordering persisted as a scalar [Track.ID] on Crate, never by reordering vinyls (D9)"
key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateDetailModel.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateDetailModelTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/ManualOrderTests.swift
    - Artifacts/screenshots/02-01-crate-list-pluralised.png
  modified:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift
    - App/Views/CrateListView.swift
    - .planning/VISUAL-DEFECTS.md
decisions:
  - "Membership is the sequencer's, arrangement is the user's — the D2-1 collision, implemented in rebuildRows()"
  - "moveRows hand-rolls the offset shift: SwiftUI's move(fromOffsets:toOffset:) is unreachable from Core under D2-6"
  - "A manual order that filters down to nothing collapses to nil rather than lingering as an empty override"
  - "Survivor lookup is O(n) via a dictionary, not the plan's O(n²) contains scan — so no ceiling comment was needed"
metrics:
  duration: ~35 min
  completed: 2026-08-30
  tests_before: 88
  tests_after: 113
---

# Phase 2 Plan 01: The Crate Detail Brain Summary

`CrateDetailModel` — a pure Core value type carrying the sequenced running order, the per-crate
track pin that makes multi-crate membership visible, and a manual reorder that overrides the
sequencer without being destroyed by it — plus `CrateStore.addMore`/`update` and the V1
pluralisation fix.

## What was built

### `CrateDetailModel` — the full public API

Plan 02-03 builds its view against this verbatim.

```swift
public struct CrateDetailModel: Sendable, Equatable {
    public private(set) var crate: Crate
    public private(set) var result: SequenceResult
    public private(set) var rows: CrateRows

    public init(crate: Crate)                     // does NO work; result and rows are .empty

    public var crateID: UUID { crate.id }
    public var crateName: String { crate.name }
    public var recordCount: Int { crate.recordCount }

    /// CRATE-07. Pinned vinyls offer exactly one candidate; unpinned and stale-pinned
    /// vinyls offer all of them.
    public var sequencerInput: [Track]

    public mutating func apply(_ newResult: SequenceResult)
    public mutating func resequence(using sequencer: some Sequencing)
}

public enum OrderingMode: Sendable, Hashable { case sequenced, manual }

extension CrateDetailModel {
    public var orderingMode: OrderingMode        // .manual iff crate.manualOrder != nil
    public mutating func moveRows(fromOffsets: IndexSet, toOffset: Int)
    public mutating func clearManualOrder()
}
```

There is **no** setter for the crate. The view's cycle is
`CrateDetailModel(crate:)` → mutate → `store.update(model.crate)` → rebuild on the next render,
exactly as plan 02-03 already sketches it. `manualOrder` lives on `Crate`, so the override
survives that round trip with no extra plumbing.

### `CrateStore` — two additions

```swift
/// CRATE-05 — re-enter capture for an EXISTING crate. Navigation only.
public mutating func addMore(to crateID: UUID) {
    guard crate(crateID) != nil else { return }
    route = .capture(crateID: crateID)
}

/// Write-back for an edited crate value. Replaces in place; never inserts.
public mutating func update(_ crate: Crate) {
    guard let index = crates.firstIndex(where: { $0.id == crate.id }) else { return }
    crates[index] = crate
}
```

### The reconciliation rule, exactly as implemented

**Membership is the sequencer's; arrangement is the user's.**

```swift
private mutating func rebuildRows() {
    let base = CrateRows.make(result: result, crate: crate)
    guard let manual = crate.manualOrder else { rows = base; return }

    let byID = Dictionary(uniqueKeysWithValues: base.sequenced.map { ($0.id, $0) })
    let survivors = manual.filter { byID[$0] != nil }
    let seen = Set(survivors)
    let order = survivors + base.sequenced.map(\.id).filter { !seen.contains($0) }

    crate.manualOrder = order.isEmpty ? nil : order

    let reordered = order.compactMap { byID[$0] }.enumerated().map { index, row in
        SequencedRow(id: row.id, vinylID: row.vinylID, indexLabel: String(index + 1),
                     title: row.title, badges: row.badges)
    }
    rows = CrateRows(sequenced: reordered, notIncluded: base.notIncluded)
}
```

`apply(_:)` is `result = newResult; rebuildRows()`. The `SequenceResult` is never mutated — the
sequencer stays memoryless, so SEQ-08's rejoin-on-add still falls out of a full re-derivation.

## Test results — actual output

`./Scripts/test.sh`:

```
✔ Test run with 113 tests in 0 suites passed after 0.012 seconds.
```

**88 before → 113 after. 25 tests added, zero failures, zero skips.** The count breaks down as
9 in `CrateDetailModelTests.swift` and 16 in `ManualOrderTests.swift`.

`./Scripts/build-app.sh` → `** BUILD SUCCEEDED **`.
Simulator build for `id=4B4E1C1F-BED6-4812-9238-C151337265DA` → `** BUILD SUCCEEDED **`.

### The tests that matter most

| Test | What it pins down |
|---|---|
| `test_givenAManualOrder_whenAVinylIsAddedAndResequenced_thenSurvivorsKeepTheirPlacesAndTheNewcomerAppends` | The D2-1 collision. Three vinyls dragged into 3-1-2, a fourth added, re-sequenced: the first three rows are still 3-1-2 and the newcomer is last. |
| `test_givenAManualOrder_whenATrackLeavesTheSet_thenItLeavesTheManualOrderWithNoDanglingID` | A removed vinyl's track ID is gone from both `rows.sequenced` and `crate.manualOrder`. |
| `test_givenTheSameVinylInTwoCratesWithDifferentPins_whenBothAreSequenced_thenTheRunningOrdersShowDifferentTracks` | CRATE-07's entire claim, asserted against the shared `vinylID` found by set intersection — never a hardcoded index. |
| `test_givenNoManualOrder_whenResequenced_thenNoOverrideIsCreated` | Without this, `orderingMode` would be meaningless. |
| `test_givenAPinNamingATrackThatIsNotACandidate_whenSequencerInputIsBuilt_thenThePinIsIgnored` | A stale pin can never silently erase a vinyl from the set. |

## Plan verification block — all six, run before committing

1. `./Scripts/test.sh` → 113 passed, 0 failed, 0 skipped.
2. Purity grep over `VinylSetBuilderCore/Sources/` → **no output**. Clean.
3. `grep -rn "AsyncSequencer" VinylSetBuilderCore/ App/` → **no output**. D2-3 holds.
4. `grep -n "Slider\|setTolerance" CrateDetailModel.swift` → **no output**. D2-4 holds.
5. `git diff --stat HEAD .../Sequencing/` → **empty**. D2-5 holds; the sequencer was not touched.
6. `grep -rn "TODO\|FIXME" .../Crates/` → **no output**.

## Deviations from Plan

### 1. `move(fromOffsets:toOffset:)` does not exist in Foundation — the offset shift is hand-rolled

- **Found during:** Task 2 GREEN.
- **Issue:** The plan's preferred path was the stdlib `RangeReplaceableCollection` method. It
  compiled to `error: value of type '[UUID]' has no member 'move'` — that method ships in
  SwiftUI, which Core cannot import under D2-6.
- **Fix:** The plan's own documented fallback. `CrateDetailModel.moved(_:fromOffsets:toOffset:)`
  implements the shift explicitly, with the off-by-one written down rather than guessed:
  `toOffset` is an insertion index into the array *before* removal, so it is pulled back by
  `fromOffsets.count(in: 0..<toOffset)`. Covered by
  `test_givenAnOutOfRangeMove_whenApplied_thenNothingTraps`, which exercises an upward move, a
  move to a row's own index (must be a no-op), a single-row list, an empty list, and both
  out-of-range ends.
- **Commit:** `b10d4bf`

### 2. Survivor filtering is O(n), so the plan's `ponytail:` ceiling comment was not written

- **Found during:** Task 2 GREEN.
- **Issue:** The plan specified `survivors.contains` over an array (O(n²)) plus a comment naming
  that ceiling. Building the `byID` dictionary *first* and filtering through it is the same
  number of lines and O(n).
- **Fix:** Wrote the O(n) version. Documenting a ceiling that does not exist would be noise, so
  that one comment was dropped. **The second `ponytail:` comment — the newcomer-append rule's
  design ceiling — is present as specified**, since that ceiling is real.
- **Commit:** `b10d4bf`

### 3. One extra test beyond the plan's fifteen: the empty-override collapse

- **Found during:** Task 2 implementation.
- **Issue:** With the plan's shape, draining a crate to zero rows leaves `manualOrder == []` —
  non-nil, so `orderingMode` reads `.manual` and the screen would offer "Restore" for an empty
  list.
- **Fix:** `crate.manualOrder = order.isEmpty ? nil : order`, plus
  `test_givenAManualOrder_whenEveryTrackLeavesTheSet_thenTheOverrideCollapsesToSequenced`. Rule 2
  (correctness), and it keeps the new behaviour from being untested.
- **Commit:** `b10d4bf`

### 4. V1 pluralisation fixed here rather than in a later plan

- **Found during:** Explicitly requested in the execution prompt; the plan file itself does not
  carry it.
- **Fix:** `App/Views/CrateListView.swift` now renders
  `Text("^[\(summary.recordCount) record](inflect: true)")`. Verified on the booted simulator
  after a 5-second settle with the app confirmed running (pid 37411):
  `Artifacts/screenshots/02-01-crate-list-pluralised.png` reads **"Sunday Chill — 1 record"** and
  **"Friday Warehouse — 4 records"**. V1 marked Closed in `.planning/VISUAL-DEFECTS.md`.
- **Commit:** `c81805d`

### Fixture discrepancy: none

`FixtureCrates.mixedResultsCrate` behaved exactly as its own doc comment promises under the
installed `BeamSearchSequencer` at tolerance 4.0 — a two-track running order plus a
tempo-excluded vinyl and an unresolved vinyl carrying **distinct** reason strings. The plan's
fallback (hand-build a crate instead) was not needed for Task 1. Task 2 uses a purpose-built
three-vinyl "ladder" crate anyway, deliberately: those tests are about *order*, and they must
stay readable when Phase 9 changes how *membership* is decided (D2-5).

## Screenshots produced

| File | Evidence |
|---|---|
| `Artifacts/screenshots/02-01-crate-list-pluralised.png` | V1 closed: "1 record" / "4 records". Also independently corroborates that V2 was a launch-fade artefact — text contrast is correct label-black on white. |

No crate-detail screenshot: that screen does not exist until plan 02-03. Everything this plan
built is proven by `swift test` against value types, per the plan's own must-have.

## What FAILED

Nothing. No test was left failing, skipped, or weakened; no assertion was relaxed to make
something pass. The one thing that did not work first time — the stdlib `move` — is recorded as
Deviation 1 above with the compiler error verbatim.

## Anything Act I still owes

- The XCUITest walk and the 15 `02-walk-*` screenshots are Phase 2's ship criterion, owned by
  plans 02-02/02-03, not by this one.
- `Q1` (sequencer order-dependence) is untouched and remains Phase 9's. Nothing added here
  depends on the beam's tiebreak surviving unchanged: every assertion is about relationships
  (this row is in the order, that vinyl is in the bucket) or about the manual order relative to
  itself.

## Self-Check: PASSED

Files verified present on disk:

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateDetailModel.swift` — FOUND
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateDetailModelTests.swift` — FOUND
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/ManualOrderTests.swift` — FOUND
- `Artifacts/screenshots/02-01-crate-list-pluralised.png` — FOUND

Commits verified in `git log`: `b831f8f`, `9360bea`, `1ecc6f9`, `b10d4bf`, `c81805d` — all FOUND.
