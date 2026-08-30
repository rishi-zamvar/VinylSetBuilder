---
phase: 04-act-i-signoff
plan: "04-06"
subsystem: crate-detail / screenshot-regeneration
tags: [defect-closure, V18, gate-S3, CRATE-04, tdd, negative-controls]
requires: [04-05]
provides: ["gate S3 rc=0 x3", "V18 CLOSED", "probe-frames --drift"]
affects: [CrateDetailModel, CrateWalkUITests, probe-frames, VISUAL-DEFECTS, ACT-I-SIGNOFF]
tech-stack:
  added: []
  patterns: ["measure, don't check presence", "in-band controls on the comparator itself"]
key-files:
  created: [".planning/phases/04-act-i-signoff/04-06-PLAN.md"]
  modified:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateDetailModel.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/ManualOrderTests.swift
    - UITests/CrateWalkUITests.swift
    - Scripts/probe-frames.py
    - .planning/VISUAL-DEFECTS.md
    - .planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md
    - Artifacts/screenshots/ (34 PNGs + MANIFEST.md)
decisions:
  - "An identity drag PRESERVES an existing manual order rather than clearing it — both directions have their own test and their own mutation."
  - "The walk normalises to edit mode ON after the drag loop, so the photographed state cannot depend on which drag recipe won."
  - "The +/-0.06 mean-drift bar is never quoted alone again: --drift reports a positional count beside it."
metrics:
  duration: ~140 min
  completed: 2026-08-30
---

# Phase 4 Plan 06: Close V18, Clear Gate S3 — Summary

**Gate S3 HOLDS. `./Scripts/screenshots.sh` returned rc=0 on all three consecutive clean runs**,
where plan 04-05 measured rc=0 / rc=1 / rc=1. V18 is fixed at its root, closed in the ledger
with a route back to the defect and a route to the fix, and the presence assertion that hid it
is gone. A second defect was found and fixed on the way, and one earlier three-run series that
went rc=0 / rc=0 / rc=1 is reported rather than dropped.

## The fix

One guard, in the one function every caller routes through — `CrateDetailView`'s `.onMove` is
the only call site of `moveRows`, checked before editing:

```swift
let order = Self.moved(ids, fromOffsets: fromOffsets, toOffset: toOffset)
guard order != ids else { return }
```

Leaving `manualOrder` **untouched** rather than clearing it is what makes it correct in both
directions: a sequenced list stays `.sequenced`, a hand-arranged list keeps its arrangement.

## The tests that now cover it

| Test | Direction it defends | State before this plan |
|---|---|---|
| `test_givenAnOutOfRangeMove_whenApplied_thenNothingTraps` | a sequenced list: an identity drag leaves `manualOrder == nil` and `orderingMode == .sequenced` | asserted the displayed order only — for **both** the single-row and the three-row identity case. This is the omission 04-05 found |
| `test_givenAManualOrder_whenARowIsMovedOntoItsOwnIndex_thenTheExistingOrderIsPreserved` | a hand-arranged list: an identity drag preserves the manual order byte-for-byte | did not exist. Without it, "clear the override on a no-op" passes as a fix and silently throws the user's ordering away |
| `CrateWalkUITests` step 9 | the **row order** at the moment of photography, plus the round trip back on Restore | a `waitForExistence` presence check on `restore-sequenced-order-button` |

Core suite: **171 → 172** tests (one new case; the rest are new assertions inside an existing
case). UI suite: 7 tests, unchanged in count, materially stronger in what step 9 asserts.

## The three `screenshots.sh` exit codes

**Series B — the three consecutive clean runs against the final code:**

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| **`./Scripts/screenshots.sh`** | **rc=0** | **rc=0** | **rc=0** |
| drag recipe that won | 2 (edit mode OFF) | 1 (edit mode ON) | 2 (edit mode OFF) |
| row order before → after | `1 Source Direct / 2 Photek` → `1 Photek / 2 Source Direct` | same | same |
| UI, from the log | `Executed 7 tests, with 0 failures` | same | same |
| UI, from `build/ui.xcresult` | passed=7 failed=0 | same | same |
| `screenshot-audit.py` | AUDIT PASSED | AUDIT PASSED | AUDIT PASSED |
| walk states | 15 files, 1 declared pair, 14 distinct | same | same |

Both drag recipes won at least once across the three, so both edit-mode branches of the walk
were exercised and both produced the same 14 distinct states. That is a stronger result than
three repetitions of one path.

**Gate S3: HOLDS.**

## What FAILED, and is reported rather than dropped

1. **An earlier three-run series went rc=0 / rc=0 / rc=1.** Its failure was **not** V18 — V18
   did not reproduce on any run tonight — but a **second defect that V18's fix uncovered**. The
   four drag recipes run in different edit modes and the first to fire wins; with recipe 1
   always "succeeding" on the identity move it had just committed, the list was always left in
   edit mode. Once recipe 1 could lose, the state photographed as frames 9 and 10 followed the
   gesture routing: `02-walk-10-detail-restored.png` came back **byte-identical** to
   `02-walk-07-not-included-expanded.png` — 0 differing pixels, fraction 0.000000 — and the
   declared `08/10` pair went stale. Fixed by normalising to edit mode ON after the drag loop
   (`3efc975`). Series-B run 3 is exactly that case, and it is rc=0.
2. **My first version of the row-order check was itself blind, and the walk caught it.** A row's
   label leads with its **position** (`"1, Source Direct — Snake Style, 170, 5A"`) and
   `indexLabel` renumbers 1…N after every move, so a real swap changes the text of every label
   and a multiset comparison of raw labels sees two disjoint sets. Measured: the walk fired all
   four recipes, swapped a two-row list four times, and reported `recipe: none` over a committed
   manual order. `rowIdentities()` strips the position; an in-band control asserts that strip
   actually fires, so it cannot silently stop.
3. **Recipe 1 does not reliably reorder.** Across the 8 walk runs made with the corrected
   comparator it genuinely reordered **3** times and failed **5**. Every green run through the
   old presence check was recipe 1 "succeeding" on the identity move it had committed — the old
   check printed `WALK DRAG RECIPE FIRED: 1` for both outcomes. This is V18's mechanism observed
   directly rather than inferred, and it is the whole explanation of 04-05's three runs.

## Negative controls — every passing check is provably able to fail

| Control | Method | Result |
|---|---|---|
| **NC-A** — the guard is load-bearing | deleted `guard order != ids else { return }`, re-ran `test.sh` | **rc=1**, 4 expectations red, each naming `manualOrder` or `.manual`. Reverted |
| **NC-B** — the *wrong* fix is caught | replaced the guard with `crate.manualOrder = nil; rebuildRows()` on a no-op | **rc=1**, 3 expectations red in the preserve-direction test. Reverted |
| **NC-C** — the walk's comparator can fail | `isReorder(before, before)` asserted **false**, in band on every walk | passes; a comparator that called a list a permutation of itself would redden the walk |
| **NC-D** — the walk's comparator can succeed | `isReorder(before, reversed(before))` asserted **true**, in band | passes; an always-false comparator would redden the walk |
| **NC-E** — the position strip fires | `rowIdentities(before) != before` asserted, in band | passes; without it the check would compare positions, not rows |
| **NC-F** — the mean bar is blind to a permutation | `probe-frames.py --selftest`, two synthetic frames that are a permutation | `mean_delta=0.0`, `mean_ok=True` — **the ±0.06 bar passes a completely rearranged image** — while `content_px=20000`, `content_ok=False` |
| **NC-G** — the new positional bar can pass | same selftest: a frame against itself, and a change confined above y=150 | `content_px=0` both times |

NC-A and NC-B were run against a **committed** file and reverted with `git checkout`; the
working tree was clean before each mutation and clean after each revert.

## The second finding from the verdict, addressed

04-05: *the ±0.06 mean-drift bar measured 0.0346 on a frame with 22,142 changed content
pixels — a mean cannot see a permutation.* This was **cheap**, so it was fixed rather than
carried: `probe-frames.py --drift A B` reports the mean delta **and** the differing-pixel count
below `y=150`, and fails if either bar is breached. Both are module constants, for the reason
the file's own header already gives about tunable thresholds. Its negative control is permanent
and lives in `--selftest` (NC-F above).

Used immediately: all **34** regenerated PNGs measured against their committed versions are
**content-identical** — 0 differing pixels below y=150 each — with every mean delta inside the
bar. Only the status-bar clock moved.

## Measurement counts

| Claim | Times measured | How |
|---|---|---|
| **Gate S3 rc=0** | **3** | three consecutive `screenshots.sh` runs, series B |
| the walk reorders the rows | **8** | every walk run made with the corrected comparator, before/after orders printed |
| UI suite 7 passed / 0 failed | **3**, two ways each | the log line *and* `build/ui.xcresult` via `xcresulttool`, plus `ui-test.sh`'s `totalTestCount=7` guard |
| Core suite 172 green | **5** | after RED, after GREEN, after both mutations reverted, and twice in the final sweep |
| `hygiene.sh` 9 pass 0 fail | **4** | after the fix, after the ledger row, after the closure section, final sweep |
| `ledger-check.py` rc=0 | **3**, plus `--selftest` | after each ledger edit and in the final sweep |
| `screenshot-audit.py` AUDIT PASSED | **5** | inside each of the three runs, plus two standalone |
| `probe-frames.py --check` `SUSPECT: none (46)` | **2** | standalone, after the regeneration and in the final sweep |
| the regenerated set is content-identical | **1 per frame × 34** | `--drift` against `git show HEAD:<path>` |

## V18, closed with both halves

- **Back to the defect:** delete `guard order != ids else { return }` → 4 expectations redden,
  `rc=1`, quoted verbatim in the ledger. The opposite mutation → 3 redden.
- **To the fix:** `a20a43d` the guard, `d658e3e` the assertions, `fbcf12c` the walk's row-order
  measurement, `3efc975` the edit-mode normalisation, `009ff13` `--drift`.
- **The photograph:** `02-walk-09-detail-manual-order.png` reads `Custom order` + `Restore` over
  `1 Photek — Ni Ten Ichi Ryu` / `2 Source Direct — Snake Style`. The `08` vs `09` pair measures
  **31,273 px / 0.009890** — 04-05's figure for the *correct* state. The defect measured
  **9,131 px / 0.002888**.

Ledger: **18 rows, 9 closed, 9 carried**, 2 Medium-or-above open (unchanged: V3 and V12).

## Deviations from Plan

**1. [Rule 1 - Bug] The walk's post-drag edit mode was recipe-dependent**
- **Found during:** Task 5, S3 series-A run 3
- **Issue:** frames 9 and 10 were photographed in whichever edit mode the winning recipe left
  behind; frame 10 came back byte-identical to frame 7 and the audit reddened
- **Fix:** `setEditMode(true)` after the drag loop; `rowIdentities()` also strips edit mode's
  leading `Remove` so orders read in different modes stay comparable
- **Files modified:** `UITests/CrateWalkUITests.swift`
- **Commit:** `3efc975`

**2. [Rule 1 - Bug] The first row-order comparator could not see a permutation**
- **Found during:** Task 3, first walk run
- **Issue:** raw labels embed the row's position, which renumbers on every move
- **Fix:** `rowIdentities()` strips the first all-digit component, with an in-band control
- **Files modified:** `UITests/CrateWalkUITests.swift`
- **Commit:** `fbcf12c`

## Still open, and deliberately not touched

- **`ui-test.sh`'s `RC=$?` is dead code under `set -e`** (04-05 §11 finding 6). Outside this
  plan's scope, and the S3 evidence above was gathered with the script exactly as the verdict
  measured it. The S3 claim does not rest on that variable: `screenshots.sh` re-derives
  pass/fail from the result bundle and refuses to collect on `failed != 0` or `passed == 0`.
- **The phase criterion's clause 2 is still NOT MET.** Two Medium-or-above rows remain: **V3**
  (blocked on the owner's unanswered U8) and **V12** (Phase 6's SEG-03 filter). 04-06 changed
  the ledger from 8/10 to 9/9 closed/carried; the Medium-or-above count is 2, exactly as before.
- **Three green tests still defend a retired specification**, and `AsyncSequencer` /
  `BeamDivergenceCheck` still do not exist. Both are Phase 9's.

## Known Stubs

None introduced by this plan.

## Self-Check: PASSED

All 9 named files exist on disk; all 9 named commits resolve in `git log`. Re-derived rather
than trusted: the guard is present in `CrateDetailModel.swift` (1 hit), no
`restore-sequenced-order-button` presence check survives in `CrateWalkUITests.swift` (0 hits),
and the machine-readable ledger carries exactly one `V18 | — | CLOSED` row.
