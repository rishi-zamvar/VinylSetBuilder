---
phase: 05
plan: 05
title: The Sequencer, Rewritten
subsystem: sequencing
requirements: [SEQ-03, SEQ-08, SEQ-09, SEQ-10]
provides: [bidirectional-bpm-gate, two-stage-sequencer, AsyncSequencer, BeamDivergenceCheck]
affects: [BPMRules, BeamSearchSequencer, SequenceResult, CrateDetailView, hygiene.sh, MVP-SPEC]
completed: 2026-08-30
---

# Phase 5: The Sequencer, Rewritten — Summary

Bidirectional BPM adjacency replaces the retired non-decreasing rule, delivered as a two-stage
search — an ascending sweep that maximises vinyl count, then 2-opt that minimises Camelot
distance — after the divergence check proved a single bidirectional beam was losing records.

| gate | before | after |
|---|---|---|
| `./Scripts/test.sh` | 172 green | **200 green** |
| `./Scripts/hygiene.sh` | 8 pass, **1 fail** | **9 pass, 0 fail** |
| `./Scripts/build-app.sh` | SUCCEEDED | SUCCEEDED |
| `./Scripts/ui-test.sh` | 7 tests | 7 tests, `totalTestCount=7` |

> **The stated starting state was not quite the real one.** The brief said "hygiene.sh → 9 gates
> pass". Measured before touching anything: **G8 was already red** — 34 sweep hits against 32
> ledger rows, because two `ROADMAP.md` lines were added after `CARRIED-DEBT.md` was written.
> That is recorded here rather than quietly fixed.

---

## The algorithm, and why it is correct

### The theorem everything rests on

> A set `S` admits a legal sequence — a Hamiltonian path in the graph joining pairs within
> tolerance — **iff** the ascending-BPM ordering of `S` has every consecutive gap `≤ tolerance`.
>
> *Proof.* (⇐) the sorted order is itself such a path. (⇒) if some sorted gap exceeds tolerance,
> `S` splits into a low part and a high part, both non-empty, and every cross pair differs by at
> least that gap — so **no edge crosses**. A path over `S` must cross at least once. ∎

Three consequences, and they are the whole design:

1. **The achievable vinyl counts are identical under the old rule and the new one.** The BPM
   graph is a unit-interval graph on the tempo line; it decomposes into islands separated by gaps
   wider than the tolerance, and no path crossed an island boundary under either rule. So
   "most vinyls wins", every exclusion reason, and the rejoin-on-add behaviour are *untouched*
   by the rule change. This is why 200 tests pass including every SEQ-04 and SEQ-06 test written
   against the old algorithm.
2. **The count objective is therefore best searched ascending**, where the space is a DAG.
3. **What the rule change actually buys is ordering freedom** — a feasible set may now be visited
   in any Hamiltonian order, not only the sorted one.

An invariant falls out and is asserted on 20 fixture/tolerance combinations: re-sorting any
winning sequence by BPM must itself be legal. Nothing else would catch the search returning an
infeasible *set* while every adjacent pair of the produced *order* looked fine.

### Stage 1 — most vinyls wins

An ascending sweep along the BPM-sorted candidates, carrying the beam forward and seeding a fresh
length-1 state at each position, so the beam holds paths of **mixed length**. That is load-bearing:
rank-1 is "length desc", so a longer path evicts a shorter one and the count objective gets real
pruning pressure.

### Stage 1b — insertion repair

Any vinyl the beam left out is spliced back at the cheapest legal position, checked against the
same gate. The count can only go up.

### Stage 2 — fewest Camelot hops

2-opt segment reversal from stage 1's ascending order. **The new rule is exactly what makes this
legal**: reversing a segment changes only the two edges at its ends and preserves every interior
edge *because the gate is symmetric*. Under the retired non-decreasing rule the move would have
been illegal. So the spec change does not merely permit a backward step — it hands over the
classic local-search move for free. Only strictly-improving legal moves are accepted, so the
count can never regress and the distance can never rise.

A path and its reverse always cost the same, so the result is canonicalised to the
lexicographically smaller of the two. Without that the output would not be a function of its input.

### Q1's total order

The rank is `(length desc, distance asc, first asc, last asc, path lexicographic)`. `first`,
`last` and the path are indices into the BPM-sorted array, whose sort key is
`(bpm, camelot, track UUID)` — a **total** order ending in the UUID, so the sorted array is a
deterministic function of the candidate *set* and every index is a position-independent name for
a track. The lexicographic leg closes the order: two distinct paths always differ somewhere.

Nothing anywhere in the ordering reads `Set` or `Dictionary` iteration order. Swift's `Hasher` is
seeded per process, so that would have made the app non-deterministic **between launches** — a
failure no same-process re-run could ever detect. Visited-vinyl tracking is a bitmask for exactly
this reason.

---

## The acceptance gate, measured

| # | gate | result | times measured |
|---|---|---|---|
| 1 | adjacency both directions | **PASS** | 4.0 passes / 4.01 fails, up **and** down, at the gate and through the sequencer; plus a swept symmetry grid of 4 tolerances × 53 × 53 pairs = 11,236 assertions | 3 |
| 2 | `170 → 178 → 174` produced | **FAILED AS WRITTEN — see below** | 2 |
| 2′ | a backward step produced when keys favour it | **PASS** — `totalCamelotDistance == 6` against the ascending order's 11 | 3 |
| 3 | one track per vinyl | **PASS** — incl. two same-vinyl candidates both carrying the perfect key inside one window; unique across 20 fixture/tolerance runs | 3 |
| 4 | the rejoin, both halves | **PASS** — excluded before the bridge; after, vinyl IDs `[1, 3, 2]`, present **and last**; remove the bridge and it leaves again | 3 |
| 5 | **Q1 determinism** | **PASS** — identical vinyl-ID order across 10 seeded shuffles × 5 fixtures × 4 tolerances, and on the dense 100-vinyl crate | **3, one in a separate process** |
| 6 | beam 50 vs 150 agree | **PARTIAL — see below** | 2 |
| 7 | 100 vinyls / 400 candidates | **PASS** — 1.1–1.5 s debug, **0.27 s release**, bound 10 s debug; 100 of 100 vinyls sequenced, off the main actor via `Task.detached` | 4 |
| 8 | degenerate crates | **PASS** — empty, single vinyl, all-nil BPM, mixed-nil; all stable under shuffling, no crash | 3 |
| 9 | suite + gates | **PASS** — 200 / 9-of-9 / SUCCEEDED / 7 UI tests | 2 |

### Gate 2 FAILED as literally specified, and it cannot be met

**`170 → 178 → 174` is arithmetically unreachable under the confirmed spec.** `|178 − 170| = 8`,
which exceeds `BPM_TOLERANCE` at **every** point of the user-tunable range 3–6. No implementation
of the confirmed consecutive rule can produce it. It is legal only under the **two-apart** reading
— `|174 − 170| = 4` — which `SEQUENCER-SPEC.md` explicitly kills: *"The two-apart reading is dead
— do not revive it."* The brief and the spec contradict each other on this one example.

Those three numbers are also, exactly, the *input candidate array* printed by the half-written
test in `Q1-sequencer-determinism.md` (v1@170, v2@178, v3@174) — which that document already
suspected was printing the input rather than the output. The example appears to be an artefact of
that misread, promoted to canon.

Handled by implementing the confirmed rule and testing **both** halves:

- `test_givenTheOwnersLiteralExample_…` asserts `canFollow(170, 178)` is false at tolerances 3, 4,
  5 and 6 in both directions, and that sequencing those three vinyls yields `[170, 174, 178]`,
  never `[170, 178, 174]`.
- `test_givenKeysThatFavourABackwardStep_…` proves the substance — a backward step *is* produced
  when it yields the better key path. Three vinyls all pairwise within 4, so every permutation is
  BPM-legal and the keys alone decide: ascending `170 → 172 → 174` costs 11; `170 → 174 → 172`
  costs 6 and steps backward. 6 is the assertion.
- A separate fixture proves a step of **exactly −4.0** is admitted, with a 4.01 counterpart
  proving that same pair then never goes adjacent.

`MVP-SPEC.md` §5 now carries this finding in its supersession note.

### Gate 6 is PARTIAL, and the honest version is stronger

Beam 50 and beam 150 do **not** always agree. Measured, 5 seeds × 4 tolerances:

- **19 of 20 runs return identical counts.** The exception is seed 7 / tolerance 3, where width
  150 returns **39** vinyls while widths 50, **400 and 1000 all return 40**.
- Vinyl *order* agrees on 8 of 20.
- Against width 400: **20 of 20 identical counts.**

I asserted early in this phase that a wider beam can never be worse, by induction on the beam
being a superset. **That claim is false and I measured it false.** Pruning keeps the top `k` by
rank; an element in the narrow beam's top-`k` is beaten by at most `k−1` of its own peers but can
be beaten by more than `k′` newcomers in the wider pool, and drop out. The `distanceDelta <= 0`
assertion built on it was removed, and the corrected reasoning is now in
`BeamDivergenceCheck`'s doc comment.

So the shipped gate asserts what actually protects the product — **width 50 never returns fewer
vinyls than a wider beam** (worst count delta 0 across 20 runs vs 150, and 20 vs 400) — rather
than an equality that beam search cannot promise.

---

## The bug the divergence check caught on its first run

This is what SEQ-10 exists for and it earned its place immediately.

The first working implementation was a single bidirectional beam. Measured on the 40-vinyl
fixture at tolerance 4:

| search | seed 7 | seed 42 | seed 1234 |
|---|---|---|---|
| one-stage bidirectional, width 50 | 40 | 34 | 34 |
| one-stage bidirectional, width 150 / 400 / 1000 | 40 | 34 | 34 |
| one-stage bidirectional, **width 10** | 40 | **37** | **35** |
| two-stage, any width | **40** | **40** | **40** |

**A narrower beam finding more records is not an approximation, it is a bug.** Root cause: every
state produced in one round of a bidirectional search has the same length, so rank-1 ties across
the whole round and the Camelot distance silently becomes the only selector. The beam fills with
distance-greedy prefixes that strand, and the *primary* objective gets no search pressure at all.
Width 10 only did better by being accidentally forced to stay diverse.

Two intermediate attempts are recorded because they were measured and rejected, not skipped:

1. **Per-final-track diversity prune** — kept the best state per distinct last track. Cut the
   total count deficit from 34 vinyls to 0 *net*, but individual runs still swung ±2, because it
   could not hold two different visited-sets ending at the same track.
2. **Round-based stage 1** — running the ascending stage in rounds rather than as a sweep dropped
   the fixture to 27/14/17 vinyls, for the same reason: length tied, so distance decided. The
   sweep is not a leftover from the DAG era; it is what makes "most records win" survive pruning.

The fix also improved SEQ-09 in both directions at once: **93 → 100 of 100 vinyls** sequenced, and
**4.44 s → 1.1 s** debug.

---

## Q1 — the verdict

**The sequencer is NOT order-dependent.** Q1 is closed.

Vinyl-ID order is identical across 10 seeded shuffles × 5 fixtures × 4 tolerances, and on the
dense 100-vinyl / 400-candidate crate. Measured three times; the third run was a **separate
process** (release build), which matters because Swift's `Hasher` is seeded per process — a
same-binary re-run could not have ruled hash seeding out. Degenerate shuffles are counted and
required to be zero, so the test cannot pass by not shuffling.

**What the original half-written test actually hit:** it compared whole `SequenceResult` values
(`actual == expected`). `notIncluded` is built in **input first-appearance order by design**, so
the not-included bucket reads in the order the user added the records. Shuffle the input and that
*order* moves while its membership does not. The comparison was too wide; the algorithm was not
too loose. Q1's "possibility 2" — a genuinely order-dependent sequencer — is ruled out.

A control assertion requires the `notIncluded` order to actually move in the diagnostic fixture,
so the diagnosis is not vacuous.

The UUID tiebreaker the brief mandated is in place regardless, and it is not decoration: the
`first`/`last`/path tiebreakers are only sound *because* the sorted array's key ends in the UUID.

---

## The 17 artefacts — all cleared

| rows | where | what was done |
|---|---|---|
| A01–A03 | `.planning/ROADMAP.md` | SEQ-03 restated as bidirectional; the "re-assert the non-decreasing guarantee" success criterion rewritten; the Definition-of-Done clause demanding an ascending set rewritten |
| A04–A05 | `docs/MVP-SPEC.md` §5, §9 | the retired line removed from the hard gate and **the supersession marker §5 had never carried was added**, including the `170 → 178 → 174` finding |
| A06 | `SequenceResult.swift` | doc comment now states bidirectional adjacency and warns callers not to re-sort |
| A07–A08 | `BeamSearchSequencer.swift` | the two comments justifying the single pass *by* the retired rule — gone with the algorithm |
| A09–A11 | `BPMRules.swift` | **including A11, the enforcement itself.** `b >= a && (b - a) <= tolerance + 1e-9` → `abs(b - a) <= tolerance + 1e-9` |
| A12–A17 | two test files | all **three** green assertions defending the dead rule deleted, including the unmarked one `CARRIED-DEBT.md` §2c found |

Non-artefacts N01–N15 were left alone as the ledger directed; `canFollow`'s signature and its call
site survive unchanged.

### G8 was rewritten rather than updated

The A-row/N-row identity was the right shape for *carrying* an open debt and the wrong shape once
paid — every new sentence merely **describing** the change breaks the sum, and it already had.
The gate is now structural: (a) zero hits of the two executable forms of the retired rule or the
stale marker, patterns built from concatenated fragments so the file cannot match itself; (b) any
spec line naming the retired rule must carry a supersession marker on that line; (c) a **positive**
check that `canFollow` is the symmetric form, because absence alone cannot tell you the right rule
is present.

Prose words like "monotonic" and "ascending" are deliberately **no longer banned**: the codebase
now legitimately describes the retirement and stage 1 legitimately searches ascending. A gate
banning them would ban explaining the change.

G4 was **inverted** — it existed to re-confirm the two files were absent; it now fails if either
disappears, demanding a real `public struct` declaration plus a reference from outside the
declaring file.

### Negative controls (both gates are effectively new, so RIGOR-POLICY requires them)

| mutation | result |
|---|---|
| reinstate `b >= a` in `canFollow` | **G8 red** |
| state the retired rule in `MVP-SPEC.md` with no marker | **G8 red** |
| delete `AsyncSequencer.swift` | **G4 red** |

All three reverted; `hygiene.sh` back to 9 pass, 0 fail.

---

## Also built

- **`AsyncSequencer`** (SEQ-09) — plan 01-05 promised it and never ran. `Task.detached`, not
  `Task`: this target defaults `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a plain `Task`
  inherits the caller's isolation and would measure nothing. A probe test asserts the work saw
  `isMainThread == false` **from a `@MainActor` caller**. `CrateDetailView` now uses it and
  re-checks the crate still exists after the await.
- **`BeamDivergenceCheck`** (SEQ-10) — likewise never written. Its negative control uses a starved
  beam of 1 to prove the check can report a divergence at all.
- **`RejoinTests`** promoted out of `.planning/open-questions/`. 6 of its 7 tests passed
  unmodified. The 7th failed on its **own anti-vacuity guard**: seed 12345 is the identity
  permutation of a 3-element array. The guard was right and the seed was bad — a small vindication
  of writing degenerate-shuffle guards at all.

---

## What failed, and what I got wrong

1. **Acceptance gate 2 cannot be met as written.** `170 → 178 → 174` is unreachable at any legal
   tolerance. Recorded above, pinned by a test, and written into `MVP-SPEC.md`. Not worked around.
2. **Acceptance gate 6 is partial.** Beam 50 and 150 do not always agree; the shipped gate asserts
   the stronger, true property instead. Stated, not laundered.
3. **I claimed beam search is monotone in width and it is not.** I wrote the induction into
   `BeamDivergenceCheck`'s doc comment and a `distanceDelta <= 0` assertion, then measured both
   false within the same phase. Corrected in place, with the counterexample recorded.
4. **My first working implementation was worse than the algorithm it replaced** on the primary
   objective — 34 vinyls where the old one and the final one get 40. Only the divergence check
   found it; every adjacency, rejoin and determinism test was green throughout.
5. **Two of my own test fixtures were wrong** and the code was right: the −4.0 downward fixture
   had two equally-optimal orderings, and I asserted the mirror the search did not pick.
6. **The stated baseline was wrong** — `hygiene.sh` was 8/9, not 9/9, before this phase started.
7. `swift test --filter "A\|B"` matched **zero tests and exited 0**. Third instance of this trap
   on this repo. Reading the count caught it.

## Deferred

- **SEQ-05** (the 3–6 tolerance slider) is untouched — it is UI and was not in this phase's gate.
  The sequencer honours the whole range and is tested across 3, 4, 5 and 6 throughout.
- Stage 2 is 2-opt only. Or-opt (relocating a single track) would likely shave the Camelot sum
  further. Not added: no measurement asked for it, and the count objective is the product.

## Self-Check: PASSED

All files claimed above exist; all seven commits are in `git log`.
