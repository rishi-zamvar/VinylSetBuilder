---
phase: 01-foundation-domain-model-sequencer
plan: 04
subsystem: sequencing
tags: [beam-search, tdd, swift-testing, camelot, bpm-gate, product-differentiator]

# Dependency graph
requires:
  - phase: 01-03
    provides: "Camelot.distance(to:), BPMRules.fold/canFollow/clampTolerance — pure primitives the beam gates and tie-breaks on"
provides:
  - "BeamSearchSequencer: Sequencing — width-50 beam search, the app's core differentiator"
  - "SequencerFixtures.swift: makeTrack/makeVinyl/makeCrateFixture/SeededRandom, reused by plan 01-05"
affects: [01-05, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sort-then-single-pass beam: BPM-ascending order is a topological order of the non-decreasing gate DAG, so no revisit/backtrack is needed"
    - "Visited-vinylID Set per beam State is the entire enforcement of D3 (one track per record) — no post-hoc dedup pass"
    - "Deterministic tie-break tuple (vinyl count desc, distance asc, start index asc) makes pruning and winner-selection the same comparison, and makes plan 01-05's beam-width divergence check meaningful"

key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BeamSearchSequencer.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/SequencerFixtures.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/BeamSearchSequencerTests.swift
  modified: []

key-decisions:
  - "A vinyl only lands in the 'no BPM yet' bucket if NONE of its candidates carry a BPM at all — one resolved candidate makes it BPM-eligible even if that candidate later loses on tempo, matching D7's intent that the two reasons must be genuinely distinguishable"
  - "Exclusion reason strings are exact and locked for plan 01-07 to render verbatim: 'No BPM yet — resolve it or enter it by hand' and 'No track within {N} BPM of the set' (N via a formatter that renders 4.0 as \"4\", 4.5 as \"4.5\")"
  - "edgeCost(from:to:) returns 0 when either Camelot is nil/unparseable — key never excludes, it only orders survivors (ponytail comment left in source naming the one known ceiling: this mildly favours unknown-key tracks in an exact count tie)"

patterns-established:
  - "Fold-before-gate: BPMRules.fold is applied once while building the sorted array, so the same folded number is what the gate checks AND what the returned Track.bpm carries — no double-fold, no gate/badge mismatch"

requirements-completed: [SEQ-02, SEQ-03, SEQ-04, SEQ-06]

# Metrics
duration: 10min
completed: 2026-08-30
---

# Phase 1 Plan 4: Beam-Search Sequencer Summary

**Width-50 beam search over BPM-sorted, half-time-folded candidates, gated by non-decreasing/tolerance BPM and tie-broken by Camelot distance — the app's uncontested differentiator, TDD'd with 18 named tests covering every locked algorithm rule (D3/D4/D5/D7) plus four degenerate-input cases.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T06:56:32Z (per STATE.md handoff)
- **Completed:** 2026-08-30T07:03:30Z
- **Tasks:** 3 completed
- **Files modified:** 3 (all new)

## Actual Test Output

Full package suite, `./Scripts/test.sh`:

```
Test run with 81 tests in 0 suites passed after 0.015 seconds.
```

This project's `./Scripts/test.sh` runs the whole `VinylSetBuilderCoreTests` target, which two other concurrent executors (plans 01-06, 01-07) are also writing into — 81 is the shared-target total, not just this plan's tests. This plan's own 18 tests, isolated via `--filter BeamSearch`, plus the 1 fixture-determinism test:

```
Test run with 18 tests in 0 suites passed after 0.013 seconds.   (BeamSearchSequencerTests)
Test "makeCrateFixture is byte-identical across two runs with the same seed" passed.
```

19/19 new tests for this plan green. 81/81 full-suite green at final verification (see "Deviations" for one transient failure observed mid-run, not caused by this plan).

## Accomplishments

- `BeamSearchSequencer` (124 lines): width-50 beam, one left-to-right pass over BPM-ascending sorted candidates, `Set<UUID>` per beam state enforcing at-most-one-track-per-vinylID even in the exact case a naive scan gets wrong (two same-vinyl candidates both inside the BPM window)
- Deterministic fixture builders (`SequencerFixtures.swift`) reused as-is by plan 01-05: `vinylID`, `makeTrack`, `makeVinyl`, `SeededRandom` (LCG, no `SystemRandomNumberGenerator`), `makeCrateFixture(vinylCount:seed:)`
- 18 named tests covering SEQ-02 (unique vinylIDs), SEQ-03 (non-decreasing + boundary at exactly 4.0 vs 4.01, half-time fold before gate), SEQ-04 (count beats distance, distance breaks count ties, unparseable key stays eligible), SEQ-06 (exact reason strings, no duplicate notIncluded rows, exact partition), plus 4 degenerate-input tests (empty, single, all-nil, single-vinyl-many-candidates)
- Purity guard (SETUP-02) still green with the new source file present

## Task Commits

1. **Task 1: Deterministic fixture builders** - `4fafef7` (test)
2. **Task 2: Sequencer tests (RED)** - `1457b2a` (test) — confirmed RED for the expected reason (`cannot find 'BeamSearchSequencer' in scope`), not a typo
3. **Task 3: BeamSearchSequencer (GREEN)** - `59e2f3c` (feat) — all 18 Task-2 tests turned green, no test edited

## Files Created/Modified

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BeamSearchSequencer.swift` - the sequencer: normalise/fold, sort, single-pass beam, notIncluded reason assignment
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/SequencerFixtures.swift` - shared deterministic fixture builders (plan 01-05 dependency)
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/BeamSearchSequencerTests.swift` - the 18 named tests

## Exact Exclusion Reason Strings (locked for plan 01-07)

- Unresolved (no BPM on any candidate for that vinyl): `"No BPM yet — resolve it or enter it by hand"`
- Excluded on tempo: `"No track within \(N) BPM of the set"` where N renders 4.0 as `"4"` and 4.5 as `"4.5"` (e.g. the default-tolerance case reads `"No track within 4 BPM of the set"`)

Plan 01-07 must render these verbatim, not reinvent its own copy.

## Decisions Made

- A vinyl is only "unresolved" if it has zero candidates with any BPM at all — a vinyl with one resolved-but-tempo-excluded candidate and three nil-BPM candidates still gets the tempo reason, not the unresolved one, since D7 requires the two reasons to be genuinely distinguishable by cause.
- Kept the winner-selection and pruning comparisons identical (`rank(_:)` used both for `prune` and for the final `beam.min`), so "what survives the beam" and "what wins at the end" can never silently disagree.
- On a fully-empty beam (all candidates nil-BPM, so nothing ever enters `sorted`), did NOT early-return `.empty` — that would have wrongly dropped the notIncluded rows. Only a literally empty `candidates` array returns `.empty`; an all-nil-BPM crate still walks through to produce one notIncluded row per vinyl.

## Deviations from Plan

**None in this plan's own code.** One transient, unrelated observation during verification:

- **Not a deviation, not fixed, logged as out-of-scope:** one `./Scripts/test.sh` run mid-session showed `CorePurityTests` failing on `CrateStore.swift: SwiftUI` — that file belongs entirely to the concurrently-running plan 01-06 (uncommitted/untracked at the time, per `git status`), not to this plan. `.planning/phases/01-foundation-domain-model-sequencer/deferred-items.md` already documents this from plan 01-07's own run (same finding, filed first). Three subsequent full-suite runs after that one blip were all green (81/81), consistent with a benign race against another agent's in-flight edit to a file this plan never touches. No action taken here per the scope boundary rule — plan 01-06 owns that fix.

## Issues Encountered

None specific to this plan's code. All 18 named tests passed on the first GREEN implementation with no test weakened or edited to fit.

## User Setup Required

None.

## Next Phase Readiness

`BeamSearchSequencer` is a pure, fully-tested `Sequencing` implementation ready to replace `NaiveBPMSortSequencer` at the UI wiring point (plan 01-06). `SequencerFixtures.swift` is ready for plan 01-05's beam-width divergence and performance tests to extend without redefinition. No blockers.

---
*Phase: 01-foundation-domain-model-sequencer*
*Completed: 2026-08-30*

## Self-Check: PASSED

All 3 created files found on disk. All 3 task commits (`4fafef7`, `1457b2a`, `59e2f3c`) found in git log.
