---
phase: 01-foundation-domain-model-sequencer
plan: 07
subsystem: ui
tags: [swift, swiftui, presentation-layer, value-types, tdd]

requires:
  - phase: 01-foundation-domain-model-sequencer (01-01)
    provides: "Track, VinylEntry, Crate, SequenceResult, NotIncluded domain value types"
  - phase: 01-foundation-domain-model-sequencer (01-03)
    provides: "Camelot.parse and BPMRules.fold"
provides:
  - "TrackBadges — the single place BPM/Camelot text is formatted for any row"
  - "CrateRows.make(result:crate:) — pure (SequenceResult, Crate) -> screen rows projection"
  - "SequencedRow, NotIncludedRow — the row types plan 01-08 composes into the crate detail screen"
  - "BadgePairView, SequencedRowView, NotIncludedSectionView — thin SwiftUI projections of the above"
affects: [01-08]

tech-stack:
  added: []
  patterns:
    - "Presentation value types (Core) + thin projecting Views (App) — no logic in a View body, so SEQ-* requirements are testable via swift test with zero view instantiated"

key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/TrackBadges.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/CrateRows.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/TrackBadgesTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateRowsTests.swift
    - App/Views/BadgePairView.swift
    - App/Views/SequencedRowView.swift
    - App/Views/NotIncludedSectionView.swift
  modified: []

key-decisions:
  - "SEQ-07's notIncluded stays exactly one array end to end (D7) — CrateRows.notIncluded has no excluded/unresolved split, verified by a grep check with zero property-name hits"
  - "TrackBadges folds BPM once via BPMRules.fold before formatting (D6) — the badge can never show a number the sequencer didn't actually gate on"
  - "A not-included vinyl's badges use its highest-known-BPM candidate (the one the exclusion is about), falling back to first-candidate then placeholders"

requirements-completed: [SEQ-07, SEQ-11]

duration: ~8min (task commits) / longer wall-clock due to shared-workspace build contention, see below
completed: 2026-08-30
---

# Phase 1 Plan 07: Badges + Single Not-Included Bucket Summary

**Pure-value-type projection of `SequenceResult` into screen rows: `TrackBadges` formats a folded BPM + normalised Camelot code once, and `CrateRows` puts every unresolved/excluded vinyl into one bucket with its own verbatim reason string — both fully proven by `swift test`, no view ever instantiated.**

## Performance

- **Started:** 2026-08-29T23:56:00-07:00 (approx, from prior commit)
- **Completed:** 2026-08-30T00:07:16-07:00
- **Tasks:** 3/3 completed
- **Files modified/created:** 7 (2 Core sources, 2 Core tests, 3 App views)

## Accomplishments

- `TrackBadges` — 9/9 tests green. Badges never blank (em-dash placeholder), BPM is folded and rounded-not-truncated to one decimal, key is normalised via `Camelot.parse`.
- `CrateRows.make(result:crate:)` — 11/11 tests green. `SequencedRow`s are a straight projection (order preserved, one-based labels); `NotIncludedRow`s are one collection with the sequencer's reason passed through byte-for-byte, stale vinyl IDs skipped via `compactMap` (no force-unwrap trap), section header/visibility driven by count.
- Three thin SwiftUI views (`BadgePairView`, `SequencedRowView`, `NotIncludedSectionView`) — no `@Observable`, no logic, `DisclosureGroup` starts collapsed per SEQ-07's wording.
- `swift test` (`./Scripts/test.sh`): **88/88 green** at final check (grew from 25 at plan start as two other concurrently-running executors — plans 01-04 BeamSearchSequencer and 01-06 CrateStore — landed their own work in the same shared package during this run).
- Static verification per the plan's `<verification>` block, all clean:
  - `grep -nE "excluded|unresolved" CrateRows.swift` → only doc-comment prose, zero properties named either.
  - `grep -rn "bpm < 100" Presentation/` → empty (fold goes through `BPMRules.fold` only).
  - `grep -n "reason" NotIncludedSectionView.swift` → `Text(row.reason)`, no transformation.
  - SETUP-02 Core purity guard passes with both new `Presentation/` files.

## Task Commits

1. **Task 1: SEQ-11 — TrackBadges** — RED `d06058d`, GREEN `d3b16ae` (test/feat)
2. **Task 2: SEQ-07 — CrateRows and the single not-included bucket** — RED `6d0ca7b`, GREEN `102f328` (test/feat)
3. **Task 3: Thin badge and row views** — `691b5fa` (feat)

**Plan metadata:** this SUMMARY + STATE.md update, committed separately per protocol.

_Note: `deferred-items.md`'s content for this plan was accidentally swept into concurrent plan 01-04's commit `59e2f3c` by a shared-git-index race (two `git add`/`git commit` calls landing on the same `.git/index.lock` window). The content is correct and present in history; only the commit attribution is off. Not re-fixed — rewriting another executor's already-pushed-to-shared-history commit was judged higher risk than the cosmetic misattribution._

## Files Created/Modified

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/TrackBadges.swift` — `TrackBadges(track:)` / `TrackBadges(bpm:camelot:)`, `.bpm`/`.key` strings, `.isIncomplete`, `Self.placeholder = "—"`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/CrateRows.swift` — `SequencedRow`, `NotIncludedRow`, `CrateRows.make(result:crate:)`, `.showsNotIncludedSection`, `.notIncludedHeader`
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/TrackBadgesTests.swift` — 9 tests
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateRowsTests.swift` — 11 tests (built against locally-constructed `SequenceResult`/`NotIncluded` fixtures since 01-04 had no SUMMARY on disk yet when this plan started; the reasons used, "No track within 4 BPM of the set" / "No BPM found", were later confirmed to match 01-04's actual wording — "No track within N BPM of the set" / "No BPM yet — resolve it or enter it by hand" — closely enough that no rewrite was needed, since these tests only assert pass-through, never a literal string match against 01-04's exact wording)
- `App/Views/BadgePairView.swift` — capsule BPM + key badges, dims (not hides) on `isIncomplete`
- `App/Views/SequencedRowView.swift` — index label, title, trailing `BadgePairView`
- `App/Views/NotIncludedSectionView.swift` — `DisclosureGroup`, starts collapsed, `Text(row.reason)` verbatim

## Public API (for plan 01-08)

```swift
public struct TrackBadges: Sendable, Hashable {
    public static let placeholder = "—"
    public let bpm: String
    public let key: String
    public init(track: Track)
    public init(bpm rawBPM: Double?, camelot rawKey: String?)
    public var isIncomplete: Bool { get }
}

public struct SequencedRow: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let vinylID: UUID
    public let indexLabel: String
    public let title: String
    public let badges: TrackBadges
}

public struct NotIncludedRow: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let label: String
    public let reason: String
    public let badges: TrackBadges
}

public struct CrateRows: Sendable, Hashable {
    public let sequenced: [SequencedRow]
    public let notIncluded: [NotIncludedRow]
    public var showsNotIncludedSection: Bool { get }
    public var notIncludedHeader: String { get }
    public static let empty: CrateRows
    public static func make(result: SequenceResult, crate: Crate) -> CrateRows
}
```

`BadgePairView`, `SequencedRowView`, `NotIncludedSectionView` (all `struct ... : View` in `App/Views/`) are self-contained and unreferenced by any other file — plan 01-08 wires them into the crate detail screen; it must not build a second row type.

## Deviations from Plan

### Auto-fixed Issues

None on this plan's own files — `TrackBadges.swift` and `CrateRows.swift` were implemented as specified, all named tests pass on the first GREEN attempt for each task.

### Out-of-scope items found, not fixed (logged to deferred-items.md)

**[Scope boundary] `CrateStore.swift` (plan 01-06) transiently violated the SETUP-02 purity guard** by importing SwiftUI while it was still uncommitted WIP. This is entirely plan 01-06's file and 01-06's responsibility; it resolved itself once 01-06 landed its GREEN commit (`68f38eb`) later in this same run, and the purity guard is green in the final `swift test` run. Logged to `.planning/phases/01-foundation-domain-model-sequencer/deferred-items.md` (see commit-attribution note above) rather than touched directly.

## Build Verification — `./Scripts/build-app.sh`

`./Scripts/build-app.sh` initially failed 5 times in a row with `error: Unable to find module dependency: 'VinylSetBuilderCore'` while this plan was executing (full `rm -rf build VinylSetBuilder.xcodeproj` + regenerate, explicit `-resolvePackageDependencies`, flag variations — all reproduced it, including against `App/Views/RootView.swift` alone, a file this plan doesn't touch). This was logged as **U7** in `.planning/UAT-PENDING.md` and initially misdiagnosed as executor-concurrency contention over the shared `build/`/`.xcodeproj` paths (three plans were genuinely committing concurrently during this run).

**The real root cause was found and fixed by plan 01-06, in the same run:** bare `xcodebuild -project` (no derived-data / workspace context) computes a *separate* build directory for the local `VinylSetBuilderCore` package sub-project than for the app target, so the app's `swiftc` invocation never sees the package's built `.swiftmodule` — independent of any concurrency. The fix, landed in `Scripts/build-app.sh`, passes explicit `SYMROOT="$(pwd)/build" OBJROOT="$(pwd)/build"` to force both projects into one build root.

Re-ran `./Scripts/build-app.sh` after that fix landed: **BUILD SUCCEEDED**, including this plan's three new views (`BadgePairView.swift`, `SequencedRowView.swift`, `NotIncludedSectionView.swift`) compiling cleanly against `VinylSetBuilderCore`. U7 updated to reflect resolution. Both `./Scripts/test.sh` (88/88) and `./Scripts/build-app.sh` (BUILD SUCCEEDED) are green as of this plan's completion.

## Known Stubs

None. `TrackBadges` and `CrateRows` are fully wired pure functions with no placeholder data paths; the three views render only what they are handed and make no network/data assumptions.

## Self-Check: PASSED

Files confirmed present:
- FOUND: VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/TrackBadges.swift
- FOUND: VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/CrateRows.swift
- FOUND: VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/TrackBadgesTests.swift
- FOUND: VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateRowsTests.swift
- FOUND: App/Views/BadgePairView.swift
- FOUND: App/Views/SequencedRowView.swift
- FOUND: App/Views/NotIncludedSectionView.swift

Commits confirmed present in `git log --oneline --all`:
- FOUND: d06058d, d3b16ae, 6d0ca7b, 102f328, 691b5fa
