# Q1 — Is `BeamSearchSequencer` order-dependent?

**Status:** OPEN. Must be answered by the rebuilt roadmap before the sequencer is signed off.
**Raised:** 2026-08-30, from a half-written test left by an interrupted executor.

## What was seen

A work-in-progress test, `RejoinTests.swift` (preserved here as `RejoinTests.swift.wip`),
asserted that shuffling the candidate array does not change the sequencer's output. **It failed.**

Both printed arrays were textually identical, which is itself suspicious, and both showed:

```
vinyl 1 @ 170 BPM (8A)
vinyl 2 @ 178 BPM (9A)
vinyl 3 @ 174 BPM (8B)
```

## Why this matters

`170 → 178 → 174` is **not BPM-non-decreasing**, which SEQ-03 requires. Two possibilities,
and they have very different consequences:

1. **The test is malformed** — it may be printing the input candidate array rather than the
   produced sequence, and the equality failure may be a `Track` `Equatable` subtlety.
   Cost: nothing, delete the test and write it properly.
2. **The sequencer is genuinely order-dependent** — beam search prunes to width 50 by a rank
   tuple, and if that ordering is not a *total* order, ties break by array position, so the
   same crate could sequence differently depending on the order candidates arrive in. Since
   the whole product re-runs the sequencer on every add, an order-dependent sequencer would
   produce different sets from the same records. **That is a serious correctness bug.**

Possibility 2 is plausible: the rank tuple is `(count desc, distance asc, start-index asc)`.
`start-index` is derived from array position, so a shuffle changes it, which changes which
equal-ranked states survive pruning.

## What the answer requires

A test that:
1. Builds a crate, sequences it, records the result
2. Shuffles the candidate array with a **seeded** RNG, sequences again
3. Asserts the resulting **vinyl ID order** is identical — comparing IDs, not `Track` structs
4. Repeats across several seeds

If it fails, the fix is to make the rank tuple a **total order** by appending a stable
tiebreaker that does not depend on input position — the track's UUID is the obvious candidate.

## Note

The 88 committed tests were all green before this WIP file appeared, and are green again with
it moved aside. Nothing committed is broken. This is an open question, not a regression.
