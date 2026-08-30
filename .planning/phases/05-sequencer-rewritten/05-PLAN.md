---
phase: 05
plan: 05
title: The Sequencer, Rewritten
type: implementation
autonomous: true
wave: 1
depends_on: [04]
requirements: [SEQ-03, SEQ-08, SEQ-09, SEQ-10]
---

# Phase 5 — The Sequencer, Rewritten

## Objective

Replace the single forward pass over BPM-sorted candidates with a beam search over the **full
neighbour set**, so that the hard gate is `|bpm[i+1] − bpm[i]| ≤ tolerance` **in either
direction**, exactly as `.planning/SEQUENCER-SPEC.md` specifies. Clear every one of the 17
artefacts of the retired non-decreasing rule. Build `AsyncSequencer` and `BeamDivergenceCheck`,
which plan 01-05 promised and never delivered. Answer Q1 with a measurement, not an opinion.

This is the product. Nothing else in the app is uncontested; this is.

## Context

- `.planning/SEQUENCER-SPEC.md` — the owner's revised specification, confirmed verbatim
- `.planning/phases/04-act-i-signoff/CARRIED-DEBT.md` §1, §2 — the 17-artefact inventory
- `.planning/open-questions/Q1-sequencer-determinism.md` — the order-dependence question
- `.planning/open-questions/RejoinTests.swift.wip` — the unfinished rejoin test, to be promoted
- `.planning/RIGOR-POLICY.md` — TDD stands; the measured acceptance gate stands

## The correctness argument, stated before any code is written

**Theorem.** Let `S` be any set of tracks and let `tol` be the tolerance. `S` admits a legal
sequence (a Hamiltonian path in the graph whose edges join pairs within `tol`) **if and only if**
the ascending-BPM ordering of `S` has every consecutive gap `≤ tol`.

*Proof.* (⇐) trivial — the sorted order is itself such a path. (⇒) Suppose the sorted order
`s₁ ≤ … ≤ s_k` has some gap `s_{j+1} − s_j > tol`. Split `S` into `L = {s₁…s_j}` and
`R = {s_{j+1}…s_k}`, both non-empty. Every cross pair differs by at least that gap, so **no edge
crosses**. A Hamiltonian path over `S` must cross at least once. Contradiction. ∎

**Three consequences, and they shape the whole plan:**

1. The set of achievable vinyl **counts is unchanged** by the rule change. The BPM graph is a
   unit-interval graph on the BPM line; it decomposes into islands separated by gaps `> tol`, and
   no path can cross an island boundary under either the old rule or the new one.
2. Therefore the **rank-1 objective (most vinyls wins) is untouched**, and so are every exclusion
   reason and the rejoin behaviour. What changes is purely the **ordering freedom** — a feasible
   set may now be visited in any Hamiltonian order, not only the sorted one, which is a strictly
   larger space for the soft Camelot objective to minimise over.
3. This gives a free invariant worth asserting: **re-sorting the winning sequence by BPM must
   itself be legal.** If it ever is not, the search returned an infeasible set.

## The arithmetic problem with the owner's canonical example — recorded, not hidden

The spec says `170 → 178 → 174` "is now legal, because every adjacent step is within 4".
It is not: `|178 − 170| = 8`, which exceeds the tolerance at **every** point of the user-tunable
range 3…6. Under the confirmed consecutive reading that sequence is unreachable, and no
implementation of the confirmed spec can produce it.

`170 → 178 → 174` is legal only under the **two-apart** reading (`|174 − 170| = 4`), which
`SEQUENCER-SPEC.md` explicitly kills: *"The two-apart reading is dead — do not revive it."*
Note also that those three numbers are exactly the *input candidate array* printed by the
half-written test in `Q1-sequencer-determinism.md` (v1@170, v2@178, v3@174) — which that document
already suspected was printing the input rather than the output.

**Resolution, applied without asking:** implement the confirmed consecutive rule, and prove the
substance of acceptance item 2 — *a sequence containing a legal backward step is produced when it
yields a better key path* — with numbers that are arithmetically reachable. Both halves get a
test:

- `test_…_thenOwnersLiteralExampleIsUnreachableAtEveryTolerance` — asserts `canFollow(170, 178)`
  is false at tolerance 3, 4, 5 and 6, and that sequencing those three vinyls yields
  `[170, 174, 178]`, never `[170, 178, 174]`.
- `test_…_thenABackwardStepIsProduced` — the real canonical proof, below.

## Tasks

### Task 1 — the gate goes bidirectional (`type=auto`, `tdd=true`)

**Behaviour:** rewrite the gate section of `BPMRulesTests.swift` first. `canFollow(174, 170,
tolerance: 4)` must become `true`; add the mirrored boundary pair — exactly `4.0` apart passes
**down** as well as up, and `4.01` fails **down** as well as up. Delete the `⚠️ STALE` MARK.
Run: must be RED.

**Implementation:** `BPMRules.canFollow` becomes `abs(b - a) <= tolerance + 1e-9`. The `b >= a`
clause — artefact **A11**, the retired rule as executable code — is deleted. Doc comment A09/A10
rewritten. Signature unchanged (N05), call site unchanged (N04). Run: must be GREEN.

**Done when:** `./Scripts/test.sh --filter BPMRules` green, and `grep "b >= a"` returns nothing.

### Task 2 — the search goes bidirectional (`type=auto`, `tdd=true`)

**Behaviour first.** New `Tests/.../SequencerAdjacencyTests.swift`:

1. **Adjacency, both directions.** Over the 40-vinyl fixture at tolerances 3, 4, 5, 6:
   every adjacent pair satisfies `|Δ| ≤ tol`. Plus exact boundary cases at 4.0 / 4.01 in both
   directions, driven through the sequencer, not just the gate.
2. **A backward step is produced when the keys make it the better path.** Three vinyls, all
   pairwise within tolerance 4 so *every* permutation is BPM-legal, with keys chosen so the
   minimum-key-distance ordering is **not** the ascending one:

   | vinyl | BPM | key | |
   |---|---|---|---|
   | 1 | 170 | 8A | |
   | 2 | 172 | 2A | `d(8A,2A) = 6` |
   | 3 | 174 | 9A | `d(8A,9A) = 1`, `d(9A,2A) = 5` |

   Ascending order `170→172→174` costs `6 + 5 = 11`. The order `170→174→172` costs `1 + 5 = 6`
   and **steps backward** at the last hop. The old single-pass algorithm could only ever return
   the 11. Assert: count 3, `totalCamelotDistance == 6`, and at least one strictly decreasing
   adjacent pair. (Path cost is symmetric, so a path and its reverse always tie; both members of
   this tie contain a backward step, so the assertion is tie-proof.)
3. **The owner's literal example is unreachable** — see the section above.
4. **The sorted-order invariant** from the theorem: re-sorting the winning sequence by BPM is
   itself legal, checked on the 40-vinyl fixture across four tolerances.
5. **One track per vinyl**, including two candidates of the same vinyl inside one window
   (the existing test is kept and re-run against the new search).

Run: RED (2 and 4 cannot pass on a forward-only pass).

**Implementation.** `BeamSearchSequencer.sequence` becomes:

- fold, drop nil-BPM, sort by the **total order** `(bpm, camelot, uuid)` — this makes `sorted` a
  deterministic function of the candidate *set*, independent of input array order
- seed the beam with **every** track as a length-1 path, unpruned (pruning rank-equal seeds to 50
  would discard the start of a long chain before it can prove itself)
- each round, expand every beam state by **every** track whose vinyl is unvisited and which
  passes `BPMRules.canFollow` — the full neighbour set, forward and backward. The gate is asked
  of the one shared function; the window is never re-derived inline, so there is exactly one
  place where tolerance arithmetic lives
- prune to `beamWidth` by rank, stop when a round produces nothing
- paths held in a parent-pointer arena, visited vinyls in a bitmask, so extension is O(1) and no
  array is copied per state

**The rank is made a total order (mandatory, per the phase brief):**
`(length desc, distance asc, firstIndex asc, lastIndex asc, path lexicographic)`.
`firstIndex`/`lastIndex`/the path are indices into `sorted`, and `sorted` is ordered by a total
key **ending in the track UUID** — so the tiebreaker is UUID-derived and carries no dependence on
input array position. The final lexicographic path comparison makes it total: two distinct states
always have distinct paths. Nothing anywhere in the ordering may come from `Set` iteration —
Swift's `Hasher` is per-process seeded, so set order is not even stable across runs.

**Done when:** the whole suite is green and every assertion in Task 2's file passes.

### Task 3 — `AsyncSequencer` (`type=auto`) — SEQ-09

`Sequencing/AsyncSequencer.swift`. Wraps any `Sequencing` and runs it on a **`Task.detached`** —
Xcode 26 defaults `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a plain `Task` inherits
main-actor isolation and would measure nothing.

Measured: **100 vinyls / 400 candidates** through `AsyncSequencer`, wall-clock, stated bound
**≤ 10 s in an unoptimised `swift test` debug build** (the suite runs debug; the shipped app is
optimised). Reported as a number, not a tick.

`CrateDetailView` is rewired to `AsyncSequencer`, because SEQ-09 says *sequencing runs off the
main thread* and a seam with no caller is not a shipped seam. `./Scripts/ui-test.sh` must stay
green; if it goes red twice the wiring reverts to synchronous and SEQ-09 is reported as
partially closed. That decision is pre-committed here so it is not made under pressure later.

### Task 4 — `BeamDivergenceCheck` (`type=auto`) — SEQ-10

`Sequencing/BeamDivergenceCheck.swift`. Runs the same candidates at two beam widths and reports
whether the vinyl-ID orders agree, plus count and distance deltas. Beam width 50 was chosen
against a DAG; this is what re-validates it against the general graph.

Measured: **50 vs 150** across seeds {7, 42, 1234, 99, 2026} × tolerances {3, 4, 5, 6} — 20 runs.
Every count delta must be 0. Reported as a number.

### Task 5 — Q1, measured twice (`type=auto`)

`Tests/.../SequencerDeterminismTests.swift`. Sequence a fixture, then re-sequence **10 seeded
shuffles** of the same candidate array, asserting the output **vinyl ID order** is identical each
time — IDs, not `Track` structs. Across several fixtures and tolerances. Degenerate shuffles are
rejected so the test cannot pass by not shuffling.

This is a headline number: **run twice**, per RIGOR-POLICY.

Also settle what the WIP test actually hit: run its exact `actual == expected` full-
`SequenceResult` comparison and record whether the failure lives in `sequence` or in
`notIncluded` (which is built in input first-appearance order **by design**, for the UI).

Then promote `RejoinTests.swift.wip` into the suite, including both halves of the rejoin —
excluded **before** the bridge, present **and last** after, vinyl IDs `[1, 3, 2]`.

### Task 6 — clear the 17 artefacts and re-arm the gates (`type=auto`)

Remove every A-row of `CARRIED-DEBT.md` §2a: A01–A03 (`ROADMAP.md`), A04–A05 (`docs/MVP-SPEC.md`
§5 and §9 — including the supersession marker §5 has never carried), A06 (`SequenceResult.swift`),
A07–A08 (`BeamSearchSequencer.swift`), A09–A11 (`BPMRules.swift`), A12–A17 (the three green tests
defending the dead rule).

`Scripts/hygiene.sh`:
- **G4 flips from absence to presence.** It exists to confirm the Phase-9 gap; the gap closes
  here, so the gate must now fail if `AsyncSequencer` or `BeamDivergenceCheck` disappears.
- **G8 is rewritten.** The A/N ledger identity was a *carrying* device for an open debt; with the
  debt paid, the honest gate is an absence gate: zero hits of the retired rule in the code trees,
  and in `docs/` every surviving hit must sit on a line explicitly marked `SUPERSEDED`. G8 is
  **already red at baseline** (34 sweep hits against 32 accounted rows — two `ROADMAP.md` lines
  landed after the ledger was written), so this task also restores it to green.

`REQUIREMENTS.md`: SEQ-03, SEQ-08, SEQ-09, SEQ-10 tick. G7's four-way count must still agree.

### Task 7 — full gate run and SUMMARY (`type=auto`)

`./Scripts/test.sh`, `./Scripts/hygiene.sh`, `./Scripts/build-app.sh`, `./Scripts/ui-test.sh`
(reading the test count, not the exit code). Then `05-SUMMARY.md`, with every acceptance number
and how many times it was measured, Q1's verdict, and anything that failed.

## Verification / acceptance gate

A number for each. The phase fails if any is unmet.

| # | Gate | Measurement |
|---|---|---|
| 1 | Adjacency in both directions | 4.0 passes / 4.01 fails, up **and** down, at gate and through the sequencer |
| 2 | A backward step is produced when keys favour it | `totalCamelotDistance == 6` vs the ascending order's 11; owner's literal `170→178→174` proved unreachable |
| 3 | One track per vinyl | unique vinyl IDs, incl. two same-vinyl candidates in one window |
| 4 | The rejoin, both halves | excluded before the bridge; after, IDs `[1, 3, 2]` — present **and last** |
| 5 | Q1 determinism | identical vinyl-ID order across 10 seeded shuffles. **Measured twice** |
| 6 | Beam 50 vs 150 | 20 runs (5 seeds × 4 tolerances), count delta 0 in all |
| 7 | 100 vinyls / 400 candidates | wall-clock ≤ 10 s debug, off the main actor via `Task.detached` |
| 8 | Degenerate crates | empty, single vinyl, all-nil BPM — no crash |
| 9 | Suite + gates | `test.sh` green (≥ 172), `hygiene.sh` 9/9, `build-app.sh` SUCCEEDED, `ui-test.sh` ≥ 7 tests |

## Output

- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BPMRules.swift` (rewritten gate)
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BeamSearchSequencer.swift` (rewritten search)
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/AsyncSequencer.swift` (new)
- `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BeamDivergenceCheck.swift` (new)
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/SequencerAdjacencyTests.swift` (new)
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/SequencerDeterminismTests.swift` (new)
- `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/RejoinTests.swift` (promoted from `.wip`)
- `Scripts/hygiene.sh` (G4 flipped, G8 rewritten)
- `docs/MVP-SPEC.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` (artefacts cleared)
- `.planning/phases/05-sequencer-rewritten/05-SUMMARY.md`
