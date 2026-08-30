---
phase: 01-foundation-domain-model-sequencer
plan: 06
subsystem: domain
tags: [swift-testing, reducer, swiftui, xcodegen, crate-management]

# Dependency graph
requires:
  - phase: 01-01
    provides: Crate/VinylEntry/Track domain value types, purity guard
  - phase: 01-02
    provides: XcodeGen app target, Scripts/build-app.sh
provides:
  - "CrateStore — pure-value-type reducer for CRATE-01/02/06/07"
  - "Route + CrateSummary — navigation-as-data and list-row projection"
  - "FixtureCrates — deterministic Phase-1 demo library exercising the in-window/excluded/unresolved/shared-vinyl cases"
  - "AppModel + 4 thin SwiftUI views wired to CrateStore"
  - "Fixed Scripts/build-app.sh: explicit SYMROOT/OBJROOT so the app target reliably resolves the local package's built module"
affects: [01-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "withCrate(_:_:) — single private no-op-on-unknown-ID guard every CrateStore mutator routes through"
    - "createCrate names AND routes in one call — no caller can create a crate without landing on capture"
    - "Purity guard is a literal substring scan — prose near banned framework names (even 'No SwiftUI' or 'until Phase 6 supplies SwiftData') trips it; reword the doc comment, don't touch the guard"

key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/Route.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateSummary.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureCrates.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateStoreTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/MultiCrateMembershipTests.swift
    - App/AppModel.swift
    - App/Views/CrateListView.swift
    - App/Views/NewCrateSheet.swift
    - App/Views/CapturePlaceholderView.swift
    - Artifacts/screenshots/01-06-crate-list.png
  modified:
    - App/Views/RootView.swift
    - Scripts/build-app.sh
    - .planning/phases/01-foundation-domain-model-sequencer/deferred-items.md

key-decisions:
  - "Adapted CrateStore to the REAL Crate/VinylEntry/Track shapes from 01-01 (which carry side/rawOCRText/resolutionState/etc.) rather than the plan's simplified illustrative interface — per the plan's own fallback instruction, and because 01-01 already shipped those types."
  - "Scripts/build-app.sh now passes explicit SYMROOT/OBJROOT (Rule 3 auto-fix): bare `xcodebuild -project` with no derived-data context gives the local VinylSetBuilderCore package a build directory separate from the app target, so the app's swiftc can't find the package's .swiftmodule even though the package compiles cleanly. Forcing a shared build root fixes it; every later plan running build-app.sh benefits."

patterns-established:
  - "FixtureCrates: fixed UUIDs (F19ED000-... prefix) + a fixed Date so the Phase-1 demo library is byte-identical across launches, verified by a direct equality test."

requirements-completed: [CRATE-01, CRATE-02, CRATE-06, CRATE-07]

# Metrics
duration: 35min
completed: 2026-08-30
---

# Phase 1 Plan 06: Crate Management (List, Create, Delete, Multi-Crate Selection) Summary

**`CrateStore` — a pure-value-type reducer proving CRATE-01/02/06/07 entirely via `swift test` (23 new tests, 88/88 full suite green), with a thin four-screen SwiftUI shell verified BUILD SUCCEEDED on the device SDK and live on the iOS 26 simulator.**

## Performance

- **Duration:** ~35 min active execution
- **Started:** 2026-08-29T23:59Z (approx, per commit `ee9ef66`)
- **Completed:** 2026-08-30T00:11Z (approx, per commit `aef5233`)
- **Tasks:** 3/3 completed
- **Files modified:** 14 (11 created, 3 modified)

## Accomplishments

- `CrateStore` implements CRATE-01 (derived, never-cached record counts), CRATE-02
  (create + route-to-capture as one atomic call), CRATE-06 (delete crate / remove vinyl,
  with contiguous position renumbering and selection cleanup, no-op on unknown IDs), and
  CRATE-07 (per-crate `selectedTrackByVinyl`, proven independent in both directions with a
  whole-struct equality check, not just the one key).
- `FixtureCrates.demoStore` ships two crates: "Friday Warehouse" (4 vinyls: an in-window
  170/172 BPM pair, a 178 BPM excluded vinyl, a nil-BPM unresolved vinyl, and a shared
  vinyl) and "Sunday Chill" (1 vinyl — the same shared vinyl, selected differently),
  verified byte-identical across two evaluations.
- `./Scripts/test.sh` — **88/88 tests pass**, including all 23 new tests (16 `CrateStoreTests`
  + 7 `MultiCrateMembershipTests`) and the full shared-package suite from concurrently
  running plans 01-04 and 01-07.
- `./Scripts/build-app.sh` — **BUILD SUCCEEDED** against the installed iOS 26 device SDK,
  `CODE_SIGNING_ALLOWED=NO`, after fixing a real environment bug (see Deviations).
- Went beyond the plan's stated ceiling: built for the newly-available iOS 26 simulator,
  installed, launched, and screenshotted the live crate list — `Artifacts/screenshots/
  01-06-crate-list.png` shows "Sunday Chill / 1 records" and "Friday Warehouse / 4 records",
  confirming CRATE-01 end to end, not just in `swift test`.

## Task Commits

1. **Task 1: CrateStore tests (RED) then reducer (GREEN)** - `ee9ef66` (test) → `68f38eb` (feat)
2. **Task 2: CRATE-07 multi-crate membership tests (RED) then FixtureCrates (GREEN)** - `9e3d6f8` (test) → `e084fa9` (feat)
3. **Task 3: Thin SwiftUI shell + build-script fix** - `5bbe2a2` (feat)
4. **Bonus: simulator screenshot** - `aef5233` (chore)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/Route.swift` — `enum Route { .crateList, .capture(crateID:), .crateDetail(crateID:) }`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateSummary.swift` — `struct CrateSummary { id, name, recordCount }`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift` — the reducer (see Public API below)
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureCrates.swift` — `mixedResultsCrate`, `secondCrate`, `demoStore`
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CrateStoreTests.swift` — 16 tests
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/MultiCrateMembershipTests.swift` — 7 tests
- `App/AppModel.swift` — `@Observable @MainActor final class AppModel { var store: CrateStore = FixtureCrates.demoStore }`
- `App/Views/RootView.swift` — `NavigationStack` switching on `model.store.route`; `.crateDetail` is a one-line placeholder with `// TODO(01-08): CrateDetailView` (corrected from the plan's stale "01-07" reference — 01-08-PLAN.md's actual `files_modified` owns `CrateDetailView.swift`/`RootView.swift`, confirmed by reading the sibling plan file directly)
- `App/Views/CrateListView.swift` — CRATE-01 list + swipe-delete (CRATE-06) + `+` sheet
- `App/Views/NewCrateSheet.swift` — CRATE-02 form; does not navigate itself
- `App/Views/CapturePlaceholderView.swift` — crate name, "Camera arrives in Phase 2", Add Fixture Vinyl (174 BPM, bridging the 170/178 gap for a hand-run SEQ-08 demo), Done → `open(crateID)`
- `Scripts/build-app.sh` — added explicit `SYMROOT`/`OBJROOT` (see Deviations)
- `.planning/phases/01-foundation-domain-model-sequencer/deferred-items.md` — closed the loop on 01-07's deferred purity-guard note

## Public API (for 01-08 to read instead of re-deriving)

```swift
public enum Route: Hashable, Sendable {
    case crateList
    case capture(crateID: UUID)
    case crateDetail(crateID: UUID)
}

public struct CrateSummary: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let recordCount: Int
}

public struct CrateStore: Sendable, Equatable {
    public private(set) var crates: [Crate]     // newest first
    public var route: Route

    public init(crates: [Crate] = [], route: Route = .crateList)

    public var summaries: [CrateSummary] { get }
    public func crate(_ id: UUID) -> Crate?

    @discardableResult
    public mutating func createCrate(named rawName: String, now: Date = Date()) -> UUID

    public mutating func deleteCrate(_ id: UUID)
    public mutating func removeVinyl(_ vinylID: UUID, from crateID: UUID)

    public mutating func addVinyl(_ vinyl: VinylEntry, to crateID: UUID)
    public mutating func selectTrack(_ trackID: UUID, forVinyl vinylID: UUID, in crateID: UUID)
    public func selectedTrack(forVinyl vinylID: UUID, in crateID: UUID) -> UUID?

    public mutating func open(_ crateID: UUID)
    public mutating func closeToList()
}

public enum FixtureCrates {
    public static var mixedResultsCrate: Crate { get }   // "Friday Warehouse", 4 vinyls
    public static var secondCrate: Crate { get }         // "Sunday Chill", 1 vinyl (shared)
    public static var demoStore: CrateStore { get }      // [secondCrate, mixedResultsCrate]
}
```

Every mutator no-ops on an unknown ID via one private `withCrate(_:_:)` guard — no trap paths.
`addVinyl` is idempotent per vinyl ID. `selectTrack` is a no-op if the vinyl isn't in that crate.

## Decisions Made

- Used the actual (richer) `Crate`/`VinylEntry`/`Track` signatures from 01-01 rather than the
  plan's illustrative simplified ones — the plan's own fallback explicitly authorized this.
- Corrected a stale cross-reference: the plan's Task 3 said "Plan 01-07 replaces [the
  crateDetail placeholder] with CrateDetailView." Reading 01-07-PLAN.md and 01-08-PLAN.md
  directly (both were mid-execution concurrently) showed 01-07 actually owns
  `TrackBadges`/`CrateRows`/badge views, and 01-08 owns `CrateDetailView.swift` +
  `RootView.swift`. The `// TODO` marker in `RootView.swift` points to 01-08, matching
  reality, not the plan's outdated text.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Purity-guard false positives from doc-comment prose (twice)**
- **Found during:** Task 1 (`CrateStore.swift` doc comment said "No SwiftUI, no I/O") and
  Task 2 (`FixtureCrates.swift` doc comment said "until Phase 6 supplies SwiftData
  persistence")
- **Issue:** `CorePurityTests` does a literal substring scan for banned framework names.
  Explanatory prose that merely *names* SwiftUI/SwiftData to say Core doesn't use them still
  matches the substring — same exact pattern 01-01 and 01-07 hit before me.
- **Fix:** Reworded both comments to the same meaning without the literal banned word
  ("No view framework, no I/O"; "until Phase 6 supplies real on-device persistence").
- **Files modified:** `CrateStore.swift`, `FixtureCrates.swift`
- **Verification:** `./Scripts/test.sh` green immediately after each fix.
- **Committed in:** `68f38eb`, `e084fa9`

**2. [Rule 3 - Blocking] `Scripts/build-app.sh` failed with "Unable to find module dependency: 'VinylSetBuilderCore'"**
- **Found during:** Task 3, first `build-app.sh` run after adding `App/AppModel.swift`
- **Issue:** Root-caused by reading the full `xcodebuild` log (not guessing): the local
  `VinylSetBuilderCore` package compiled cleanly (zero errors in its own compile step, log
  lines 204-850), but its built `.swiftmodule` landed at
  `VinylSetBuilderCore/build/Debug-iphoneos/...` — a *separate* build directory from the app
  target's `build/Debug-iphoneos/...` — because a bare `xcodebuild -project` invocation with
  no derived-data context computes SYMROOT/OBJROOT per-project rather than sharing one root
  across a project and its local package sub-project. The app target's search paths never
  saw the package's output, so every `import VinylSetBuilderCore` in `App/` failed.
- **Fix:** Added `SYMROOT="$(pwd)/build" OBJROOT="$(pwd)/build"` to the `xcodebuild` invocation
  in `Scripts/build-app.sh`, forcing both projects into one shared build root.
- **Files modified:** `Scripts/build-app.sh`
- **Verification:** Reproduced the failure twice (including after a clean `rm -rf build`, to
  rule out stale cache), then confirmed **BUILD SUCCEEDED** with the fix applied, both via a
  manual `xcodebuild` invocation and via the updated script itself.
- **Committed in:** `5bbe2a2`
- **Scope note:** This is a fix to shared infrastructure (`Scripts/build-app.sh`, created by
  01-02), not something 01-06's own source files caused. Every later plan that runs
  `build-app.sh` (01-08 onward) needs this fix too and now has it for free.

**Total deviations:** 3 auto-fixed (2 doc-comment false-positives, 1 real build-script bug).
No architectural changes, no scope creep — all three are exactly the class of thing Rules 1
and 3 are for.

## Known Stubs

- `App/Views/RootView.swift`'s `.crateDetail` case is `Text("Crate detail")` — explicitly
  scaffolding for 01-08's `CrateDetailView`, marked with a `// TODO(01-08)` comment. Not a
  gap in this plan's own scope (CRATE-01/02/06/07 have no dependency on the detail screen).
- `App/Views/CapturePlaceholderView.swift` is disposable scaffolding per the plan's own
  instruction ("the camera does not exist until Phase 2") — the "Add Fixture Vinyl" button is
  intentional manual-testing plumbing, not a stub masking missing functionality.

## Self-Check: PASSED

Verified after writing this summary:
- All 11 created files FOUND on disk (Route.swift, CrateSummary.swift, CrateStore.swift,
  FixtureCrates.swift, CrateStoreTests.swift, MultiCrateMembershipTests.swift, AppModel.swift,
  CrateListView.swift, NewCrateSheet.swift, CapturePlaceholderView.swift, screenshot PNG)
- All 6 commits (`ee9ef66`, `68f38eb`, `9e3d6f8`, `e084fa9`, `5bbe2a2`, `aef5233`) FOUND in
  `git log --oneline --all`
- `./Scripts/test.sh` re-run: 88/88 passed
- `./Scripts/build-app.sh` re-run: BUILD SUCCEEDED
- `grep -rn "selectedTrack" .../Domain/VinylEntry.swift`: no matches (confirmed)
- `grep -rE "AVFoundation|URLSession|SwiftUI|SwiftData" VinylSetBuilderCore/Sources/`: no matches
