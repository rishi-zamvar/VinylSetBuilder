# Sequencer specification — REVISED 2026-08-30

Supersedes MVP-SPEC §5 and the previous SEQ-03 wording. Owner's decision, verbatim:

> "we are solving for 2 objective functions. if we denote song as n, song n-1 and song n+1
> must be +- 4 bpm of each other. Furthermore song n-1 and song n+1 should minimize distance
> according to camelot wheel key"
>
> "most records still win as long as two functions are properly optimized"

## The specification

**Hard constraint — BPM adjacency, bidirectional**
```
|bpm[i+1] − bpm[i]| ≤ BPM_TOLERANCE      (default 4.0, user-tunable 3–6)
```
**The non-decreasing requirement is REMOVED.** BPM may go up or down between consecutive
tracks. `170 → 178 → 174` is now legal, because every adjacent step is within 4.

**Hard constraint — structural**
At most one track per `vinylID`. Unchanged, non-negotiable.

**Soft objective — harmonic**
```
minimise  Σ camelotDistance(track[i], track[i+1])
```
Camelot never excludes a record; it only orders survivors. Unchanged.

**Ranking**
1. Maximise the number of vinyls in the sequence
2. Tie-break on minimum total Camelot distance

Unchanged — "most records still win", provided both functions are properly optimised.

## The reading — CONFIRMED BY OWNER 2026-08-30

The owner wrote *"song n−1 and song n+1 must be +- 4 bpm of each other"*. Read literally that
constrains tracks **two apart** (skipping n), which would be an unusual rule and, combined with
adjacency, extremely tight.

**CONFIRMED: consecutive tracks.** Owner's words, 2026-08-30: *"yes consecutive tracks"*.
For every adjacent pair, `|Δbpm| ≤ tolerance`. The two-apart reading is dead — do not revive it.

## Consequence — this is an ALGORITHMIC change, not a parameter tweak

The existing `BeamSearchSequencer` exploits monotonicity: it sorts candidates by BPM and makes
a **single forward pass**, so edges only ever point forward in the sorted array. That is what
made it a DAG.

**Removing the non-decreasing rule destroys that property.** Edges now point both directions,
so the search space is a general graph and the problem becomes a longest-path / TSP-flavoured
search rather than a DAG traversal. Consequences to handle:

1. The single-pass beam over BPM-sorted candidates is no longer correct — it cannot reach a
   sequence that steps backwards. The beam must expand over the full neighbour set.
2. Cost rises. Beam width 50 was chosen against a DAG; it must be re-validated against the
   wider space, and the width-50-vs-150 divergence check (SEQ-10) matters much more now.
3. **Q1 (order-dependence) becomes more likely, not less.** With more equal-ranked states
   competing for beam slots, a rank tuple ending in array position will break ties differently
   under a shuffle. The total-order fix (append the track UUID as a final tiebreaker) is now
   effectively mandatory, not optional.
4. Existing tests asserting "BPM is non-decreasing across the whole winning sequence" are now
   **asserting the wrong thing** and must be replaced with adjacency-window assertions.

## Tests this now requires

- Every adjacent pair satisfies `|Δbpm| ≤ tolerance`, in either direction
- A sequence containing a legal backward step is produced when it yields a better key path —
  `170 → 178 → 174` with compatible keys is the canonical case, taken from the owner's own words
- Boundary: exactly 4.0 apart passes, 4.01 fails, in **both** directions
- Still at most one track per vinyl, including when two candidates from the same vinyl both sit
  inside the window
- Determinism: shuffling the candidate array does not change the output vinyl order (Q1)
- Maximise-count still beats minimise-distance when they conflict
