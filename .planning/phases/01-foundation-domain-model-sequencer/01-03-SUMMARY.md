---
phase: 01-foundation-domain-model-sequencer
plan: 03
subsystem: sequencing
tags: [camelot-wheel, bpm-gate, tdd, swift-testing, ported-from-python]

# Dependency graph
requires:
  - phase: 01-01
    provides: "VinylSetBuilderCore SPM package, Track.camelot/bpm fields, CorePurityTests guard, Scripts/test.sh"
provides:
  - "Camelot type: parse(_:), from(pitch:mode:), distance(to:), majorTable/minorTable ported value-for-value from walkman-dj camelot.py"
  - "BPMRules: fold(_:), canFollow(_:_:tolerance:), defaultTolerance (4.0), toleranceRange (3...6), clampTolerance(_:)"
affects: [01-04, 01-05]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Port-not-design: canonical Python tables copied verbatim rather than re-derived", "Failable parse() unifies two input formats (Camelot code vs musical key) behind one entry point"]

key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/Camelot.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BPMRules.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CamelotTests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/BPMRulesTests.swift
  modified: []

key-decisions:
  - "Camelot distance is flat hop count + 1 for a letter change only — no extra letter weighting (D1, locked)"
  - "BPMRules.fold applies bpm < 100 -> bpm * 2 exactly once, never iteratively (D6, locked): 50 -> 100, not 200"
  - "BPMRules.canFollow requires non-decreasing AND |delta| <= tolerance + 1e-9 epsilon for slider float slop (D2, locked)"
  - "Bare musical key \"A\" parses to nil (collides with an incomplete Camelot code with no hour) while bare \"B\" parses to 1B (a genuine musical key) — asymmetric by explicit plan spec, both covered by named tests"

patterns-established:
  - "Camelot.parse(_:) is the single entry point for both Camelot-code strings (\"8A\") and musical-key strings (\"Am\", \"F#m\", \"C\") — callers never need to know which format they were given"

requirements-completed: [SEQ-01]

# Metrics
duration: 12min
completed: 2026-08-30
---

# Phase 1 Plan 3: Camelot Wheel and BPM Rules Summary

**Ported walkman-dj's Camelot wheel (flat-hop distance + letter-change penalty) and half-time BPM fold into Swift as two pure, fully-tested primitives with no dependency on the sequencer that will consume them.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-30T06:56:03Z
- **Completed:** 2026-08-30T07:08:00Z
- **Tasks:** 2 completed
- **Files modified:** 4 (all new)

## Accomplishments

- `Camelot` struct with `parse(_:)`, `from(pitch:mode:)`, `distance(to:)`, and the ported `_MAJOR`/`_MINOR` pitch tables — 10 tests green, including an exhaustive 24x24 distance-bound loop
- `BPMRules` enum with `fold(_:)`, `canFollow(_:_:tolerance:)`, `defaultTolerance`, `toleranceRange`, `clampTolerance(_:)` — 10 tests green
- Full package suite: 25/25 tests green, purity guard (SETUP-02) still passes with the new files present

## Task Commits

Each task was committed atomically (TDD: test commit, then feat commit):

1. **Tests (RED) for both types** - `0b69927` (test)
2. **Task 1: Camelot implementation (GREEN)** - `ab3566b` (feat)
3. **Task 2: BPMRules implementation (GREEN)** - `7b9a037` (feat)

_Note: both tasks' tests were written together in one RED commit since they share no
implementation dependency and both needed to fail-to-compile before either GREEN commit,
per the TDD flow; each GREEN commit is scoped to its own task's source file only._

## Files Created/Modified

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/Camelot.swift` - Camelot wheel type, ported pitch tables, parse/distance
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BPMRules.swift` - half-time fold + non-decreasing/tolerance gate
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/CamelotTests.swift` - 10 tests (parsing, distance, ported-table spot checks)
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/BPMRulesTests.swift` - 10 tests (fold boundary, gate tolerance/direction)

## Public Signatures (for plan 01-04 to build on without reading source)

```swift
public struct Camelot: Equatable, Hashable, Sendable, Codable {
    public let hour: Int      // 1...12
    public let isMinor: Bool  // A = minor, B = major
    public init?(_ code: String)
    public var code: String { get }
    public func distance(to other: Camelot) -> Int
    public static func from(pitch: String, mode: String) -> Camelot?
    public static func parse(_ value: String?) -> Camelot?
    static let majorTable: [String: Int]  // internal, ported _MAJOR
    static let minorTable: [String: Int]  // internal, ported _MINOR
}

public enum BPMRules {
    public static let defaultTolerance: Double  // 4.0
    public static let toleranceRange: ClosedRange<Double>  // 3.0...6.0
    public static func fold(_ bpm: Double) -> Double
    public static func canFollow(_ a: Double, _ b: Double, tolerance: Double) -> Bool
    public static func clampTolerance(_ t: Double) -> Double
}
```

## Decisions Made

- Followed the plan's validated `Camelot` shape and ported tables verbatim, value for value, per the "port not design" constraint.
- Resolved the one genuinely ambiguous spec point (bare "A" vs bare "B") exactly as the plan's named tests required: `"A"` alone is rejected (would otherwise silently resolve via `majorTable["A"] == 11`, colliding with "incomplete Camelot code" garbage), `"B"` alone resolves to `"1B"` because it's a real musical key with no such collision risk in practice. Documented inline with a `ponytail:` comment so a future "tighten the parser" pass doesn't silently invert this.
- `majorTable`/`minorTable` kept internal (not `public`) since only `Camelot.parse`/`from` need them and the plan's "artifacts" check (`Camelot.majorTable["C"]`) is exercised from inside the test target via `@testable import`, which sees internal symbols.

## Deviations from Plan

None - plan executed exactly as written. The `Codable` conformance and doc-comment ceiling note on `canFollow` (called for in the plan's `<action>` text) were both included.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`Camelot.distance(to:)` and `BPMRules.fold`/`canFollow` are ready as pure, tested primitives for plan 01-04's beam search sequencer. No blockers. Full suite green at 25/25 including the pre-existing purity and domain tests.

---
*Phase: 01-foundation-domain-model-sequencer*
*Completed: 2026-08-30*

## Self-Check: PASSED
