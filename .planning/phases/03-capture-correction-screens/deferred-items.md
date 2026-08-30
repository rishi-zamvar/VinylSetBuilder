# Deferred items — Phase 3

Out-of-scope discoveries, logged rather than fixed.

## D1 — `move(fromOffsets` appears in a Core doc comment

Found during 03-02's verification (`grep -rn "move(fromOffsets" VinylSetBuilderCore/Sources/`,
which the plan expects to return nothing).

`Crates/CrateDetailModel.swift:108` contains the string inside a comment explaining that the API
is **not** reachable from Core (D2-6). There is no call and no import; the grep gate is matching
prose. Pre-existing, landed in plan 02-01, unrelated to 03-02's changes, so it was not edited.

Fix, when someone is in that file anyway: reword the comment, or tighten the gate to ignore
comment lines. Either is a one-line change.

---

## Recorded at Phase 3 close (plan 03-05) — deliberately not built, and who owns each

Every one of these is a **decision**, not an omission. They are written here so Phase 4's
sign-off does not read them as Phase 3 debt.

### D-03-2 — no photograph bytes in the strip

The thumbnail tile is a rendered sleeve-shaped card carrying the record's own OCR text, not an
image view. The repo is public and the twelve HEICs stay in `~/Desktop/test/`, gitignored.
`CaptureItem.photoRef` carries `"IMG_0498.HEIC"` today and a real image handle in Phase 10; the
tile already takes an optional `Image` that is `nil` for the whole of Act I, so the swap adds a
value and changes no layout. **Visible consequence:** the framing preview in every
`03-walk-*` and `03-03-*` frame is a plain black rectangle. **Owner: Phase 10.**

### D-03-4 — Act I does not segment, so the draft arrives over-split

`FixtureLineSegmenter` emits one track line per trusted observation, in reading order. No angle
clustering, no marker splitting, no noise filtering — all of that is SEG-01…06/08. IMG_0503
therefore opens with **sixteen** lines including `$9.73 [Import]` and `#00°L`, and IMG_0505 with
eleven including a duplicate. This is useful rather than merely tolerated: merge is exercised on
the first tap against real data. **It is also the direct cause of defect V16** (exact duplicate
lines in one draft). **Owner: Phase 6.**

### D-03-5 — the strip shows READ status, not resolution status

CAP-03's own wording says "per-item resolution status". Nothing resolves in Act I — resolution is
Phase 7 — so the honest Act I rendering is `.read` / `.partial` / `.unread`, scored per fixture
from the OCR spike's own 6 clean / 5 partial / 1 fail verdicts. `CaptureItemStatus` is a separate
type from `ResolutionState` precisely so Phase 11 can extend it without a migration.
**Owner: Phase 11.**

### The word-midpoint split ceiling

`SegmentationDraft.splitLine` splits at the **word midpoint** — the whitespace boundary nearest
the middle of the string — and nowhere else. It cannot split at the caret, and a single-word line
is a deliberate no-op (tested explicitly in Core). `03-walk`'s own evidence for the ceiling:
`Zzz. Cause 4 Concern-` splits to `Zzz. Cause` / `4 Concern-`, which is not where a person would
have cut it. Caret-position splitting needs a focused text selection this sheet does not model,
and real marker-driven splitting is SEG-04. **Owner: Phase 6 for the rule, Phase 12 for the
editing affordance.**

### CAP-01 and CAP-04 are not in this phase, by design

The non-blocking shutter and the twenty-record thermal/memory run are live-camera behaviours. The
simulator has no camera, so they sit in Act III Phase 10 and no plan here imported them. What
Phase 3 *can* say about the twenty-record case it now says with a number: twenty-one captures in
one session, tiles unchanged at **104.0 pt** at 1 item and at 21, and the last tile reachable in
13 bounded drag steps (`03-walk-08`, `03-walk-09`). That is CAP-03's layout claim, not CAP-04's
performance claim, and the two are not being conflated.

### Not Phase 3's, restated so sign-off does not inherit them by accident

- **`AsyncSequencer` and `BeamDivergenceCheck` do not exist.** Plan 01-05 was never executed.
  `grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/` returns
  nothing (run again by 03-05, rc=1). **SEQ-08, SEQ-09 and SEQ-10 are wholly outstanding** and
  Phase 9 inherits `01-05-PLAN.md`'s content.
- **SEQ-03 is REOPENED**, not complete. The rule went bidirectional (`|Δbpm| ≤ tolerance`, the
  non-decreasing requirement removed) on 2026-08-30, and the shipped implementation and its tests
  still assert the old monotonic rule — `./Scripts/test.sh` still prints the green line *"BPM is
  non-decreasing across the whole winning sequence"*, which is currently passing **and wrong**.
  Phase 9's, with the five-artefact inventory in `REQUIREMENTS.md`.
