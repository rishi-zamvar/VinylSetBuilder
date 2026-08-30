---
phase: 01-foundation-domain-model-sequencer
plan: 01
subsystem: domain
tags: [swift-package-manager, swift-testing, domain-model, protocol-oriented]

# Dependency graph
requires: []
provides:
  - "VinylSetBuilderCore SPM package (swift-tools-version 6.0, zero external dependencies)"
  - "Domain value types: Side, ResolutionState, Track, VinylEntry, Crate, TextObservation, SequenceResult, NotIncluded"
  - "Protocol seams: Sequencing, LabelSegmenting, MetadataResolving"
  - "Fixture implementations: NaiveBPMSortSequencer, FixtureMetadataResolver"
  - "CorePurityTests — compile/test-time enforcement that Core never imports AVFoundation/Vision/UIKit/AppKit/SwiftUI/SwiftData or mentions URLSession"
  - "Scripts/test.sh — one-command CLI test entry point"
affects: [01-02, 01-03, 01-04, 01-05, 01-06, 01-07, phase-2, phase-3, phase-4, phase-5, phase-6]

# Tech tracking
tech-stack:
  added: [Swift Testing (import Testing, @Test, #expect)]
  patterns:
    - "position: Int is the ordering source of truth (D9) — never array/relationship order"
    - "SequenceResult.notIncluded is a single bucket for unresolved + excluded, each carrying its own reason string (D7)"
    - "Protocol seams are Sendable and pure/async — no I/O type ever appears in a Core protocol signature"
    - "Purity guard scans every .swift file under Sources/ for banned substrings via #filePath walk-up; asserts scanned > 0 so a broken path walk fails loudly, not vacuously"

key-files:
  created:
    - VinylSetBuilderCore/Package.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/Side.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/ResolutionState.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/Track.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/VinylEntry.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/Crate.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/TextObservation.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/SequenceResult.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/Sequencing.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/LabelSegmenting.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Resolution/MetadataResolving.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureMetadataResolver.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/NaiveBPMSortSequencer.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CorePurityTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/DomainTests.swift
    - Scripts/test.sh
  modified: []

key-decisions:
  - "Root marker file VinylSetBuilderCore.swift added (not in original plan file list) because SPM refuses to build a target with zero source files — needed for Task 1 to be independently green before Task 2's domain types land."
  - "Purity guard's banned-token list is a plain substring match, so prose mentioning framework names in doc comments (not imports) trips it. Reworded two comments (TextObservation's bounding-box doc, MetadataResolving's LabelTextRecognizing doc) to avoid the literal words 'Vision' while keeping identical meaning — this is the guard behaving as designed, not a bug in it."

patterns-established:
  - "Every Track/VinylEntry/Crate mutation happens on value types; ordering is always derived via .sorted(by: \\.position), never trusted from array-as-stored order."
  - "Fixture types (Fixtures/) are placeholder protocol conformances used by later Phase-1 plans (e.g. 01-06 crate UI) so they don't block on 01-04's real BeamSearchSequencer or Phase 4's real resolver."

requirements-completed: [SETUP-02, SETUP-04]

# Metrics
duration: 2min
completed: 2026-08-30
---

# Phase 1 Plan 01: Foundation Domain Model & Sequencer Package Summary

**VinylSetBuilderCore SPM package with 7 domain value types, 3 protocol seams, 2 fixture stubs, and a purity guard test that fails the build if Core ever imports a camera or network framework**

## Performance

- **Duration:** ~2 min of active execution (3 task commits)
- **Started:** 2026-08-29T23:45:22-07:00
- **Completed:** 2026-08-29T23:46:48-07:00
- **Tasks:** 3/3 completed
- **Files modified:** 16 created (1 more than the plan's 15 — see Deviations)

## Accomplishments
- `swift test --package-path VinylSetBuilderCore` runs 5/5 tests green from a plain terminal — no device, no simulator, no network.
- `CorePurityTests` proven to actually catch violations: deliberately added `import AVFoundation` to a Core source file, watched the test fail with a named violation, then reverted (per the plan's explicit instruction).
- All four `must_haves.truths` from the plan frontmatter verified directly: purity test fails loudly not vacuously (asserts `scanned > 0`), every domain type is `public Sendable` with explicit `position: Int`, all three protocol seams compile with a conforming fixture.
- `grep -rE "AVFoundation|URLSession|SwiftUI|SwiftData" VinylSetBuilderCore/Sources/` returns nothing (exit 1, no matches) — confirmed post-hoc as the plan's independent verification step.

## Task Commits

1. **Task 1: Package scaffold and the purity guard test** - `ba479d5` (feat)
2. **Task 2: Domain value types** - `cac144d` (test, RED) → `7c2f9d6` (feat, GREEN)
3. **Task 3: Protocol seams and fixture stubs** - `36ab5cf` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `VinylSetBuilderCore/Package.swift` — swift-tools-version 6.0, `.macOS(.v14)` / `.iOS(.v17)`, zero dependencies
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/VinylSetBuilderCore.swift` — root marker file, not in original plan (see Deviations)
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/*.swift` — Side, ResolutionState, Track, VinylEntry, Crate, TextObservation, SequenceResult+NotIncluded
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/Sequencing.swift` — `protocol Sequencing: Sendable { func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult }`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/LabelSegmenting.swift` — `protocol LabelSegmenting: Sendable { func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track] }`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Resolution/MetadataResolving.swift` — `protocol MetadataResolving: Sendable { func resolve(_ track: Track) async -> Track }`
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureMetadataResolver.swift` — 1.5s simulated delay, output varies by `track.position` across 5 fixture rows
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/NaiveBPMSortSequencer.swift` — filters nil-BPM, sorts ascending, empty `notIncluded`
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CorePurityTests.swift` — SETUP-02 enforcement
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/DomainTests.swift` — 4 tests covering position-ordering, per-crate selection independence (CRATE-07), Codable round-trip, single-bucket notIncluded
- `Scripts/test.sh` — SETUP-04, `swift test --package-path VinylSetBuilderCore "$@"`

## Public Signatures (for plans 03-07 to read instead of re-deriving)

```swift
public struct Track: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public let vinylID: UUID
    public var side: Side
    public var position: Int
    public var rawOCRText: String
    public var artist: String?
    public var title: String?
    public var bpm: Double?
    public var camelot: String?
    public var matchConfidence: Double
    public var resolutionState: ResolutionState
    public var failureReason: String?
    public var displayName: String { get }
}

public struct VinylEntry: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var capturedAt: Date
    public var photoRefs: [String]
    public var sidesScanned: Set<Side>
    public var candidates: [Track]
    public var position: Int
    public var orderedCandidates: [Track] { get }   // sorted by position
    public var label: String { get }
}

public struct Crate: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var vinyls: [VinylEntry]
    public var bpmTolerance: Double                 // default 4.0
    public var manualOrder: [Track.ID]?
    public var selectedTrackByVinyl: [UUID: UUID]   // CRATE-07: per-crate, not per-vinyl
    public var recordCount: Int { get }
    public var allCandidates: [Track] { get }
}

public struct SequenceResult: Sendable, Hashable {
    public let sequence: [Track]
    public let notIncluded: [NotIncluded]           // D7: single bucket
    public let totalCamelotDistance: Int
    public static let empty: SequenceResult
}

public struct NotIncluded: Sendable, Hashable, Codable, Identifiable {
    public var id: UUID { vinylID }
    public let vinylID: UUID
    public let reason: String
}

public protocol Sequencing: Sendable {
    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult
}

public protocol LabelSegmenting: Sendable {
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track]
}

public protocol MetadataResolving: Sendable {
    func resolve(_ track: Track) async -> Track
}
```

## Decisions Made

- Added `VinylSetBuilderCore.swift` root marker file, not listed in the plan's `files_modified`. SPM's `swift build` hard-errors ("target ... is empty") if a target has zero source files, and Task 1 needed to build/test green in isolation before Task 2 added the Domain/ files. The marker is a two-line comment; it stays in the tree harmlessly and does not affect the public API.
- Purity guard uses plain substring matching against file contents (as the plan specified), which means prose in doc comments can false-positive on framework names even when there's no import. Hit this twice (`TextObservation`'s "Vision's convention" comment, `MetadataResolving`'s "app target's Vision layer" comment) — both reworded to avoid the literal banned word while preserving the same explanation. This is intentional guard behavior per the plan (a strict substring scan is what makes SETUP-02 "test-enforced fact rather than convention"), not a defect to fix in the test itself.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added a root marker source file so the target isn't empty**
- **Found during:** Task 1 (Package scaffold and purity guard test)
- **Issue:** `swift build` failed with `target 'VinylSetBuilderCore' referenced in product 'VinylSetBuilderCore' is empty` — the plan's Task 1 has no source files under `Sources/`, only `Package.swift` and the test.
- **Fix:** Added `Sources/VinylSetBuilderCore/VinylSetBuilderCore.swift` as a two-line comment-only marker file.
- **Files modified:** `VinylSetBuilderCore/Sources/VinylSetBuilderCore/VinylSetBuilderCore.swift`
- **Verification:** `./Scripts/test.sh` built and ran the purity test green immediately after.
- **Committed in:** `ba479d5` (Task 1 commit)

**2. [Rule 1 - Bug] Reworded two doc comments that false-positived the purity guard**
- **Found during:** Task 2 (`TextObservation.boundingBox` comment said "Vision's convention") and Task 3 (`MetadataResolving.swift` comment said "app target's Vision layer")
- **Issue:** The purity guard does a literal substring scan for the word "Vision" (correctly, per plan intent — catching real imports). Prose explaining *why* a type looks the way it does (referencing Apple's Vision framework by name, without importing it) tripped the same scan.
- **Fix:** Reworded both comments to describe the same fact ("normalized [0,1] coordinate convention", "the app target's OCR layer") without the literal banned substring.
- **Files modified:** `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/TextObservation.swift`, `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Resolution/MetadataResolving.swift`
- **Verification:** `./Scripts/test.sh` — all 5 tests green after each fix.
- **Committed in:** `7c2f9d6` (Task 2 commit), `36ab5cf` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug/false-positive)
**Impact on plan:** Neither changes any public API, test count, or requirement. No scope creep — both are exactly what the plan's own design ("purity is test-enforced, not conventional") predicts will happen when writing prose near banned words.

## Issues Encountered

None beyond the two deviations above, both resolved within the same task they surfaced in.

## User Setup Required

None — no external service configuration required. The purity test itself is the gate; there is nothing to configure.

## Next Phase Readiness

- Plans 01-02 through 01-07 (and Phases 2-6) can now `import VinylSetBuilderCore` and get every domain type plus all three protocol seams.
- `NaiveBPMSortSequencer` and `FixtureMetadataResolver` are ready for 01-06's crate UI to bind against without waiting on 01-04 (`BeamSearchSequencer`) or Phase 4 (real resolver).
- No blockers. The purity guard is live from this commit forward — any later plan that accidentally imports AVFoundation/Vision/UIKit/AppKit/SwiftUI/SwiftData into Core, or references `URLSession`/`URLRequest`/`URLProtocol`, will fail `./Scripts/test.sh` immediately.

---
*Phase: 01-foundation-domain-model-sequencer*
*Completed: 2026-08-30*

## Self-Check: PASSED
All 6 referenced files and 4 commit hashes verified present on disk / in git history.
