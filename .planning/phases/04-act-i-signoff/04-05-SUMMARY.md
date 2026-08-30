---
phase: 04-act-i-signoff
plan: 05
subsystem: act-verification
tags: [verdict, sign-off, refusal, gates, screenshots, non-determinism, recount]
requires:
  - "Scripts/screenshot-audit.py + Scripts/screenshots.sh + Scripts/probe-frames.py (04-01)"
  - "Scripts/hygiene.sh G1-G8 (04-02)"
  - "V4/V5 closed, V9 root-cause attempt (04-03)"
  - "Scripts/ledger-check.py + gate G9 (04-04)"
provides:
  - ".planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md — the Act I verdict: REFUSED on gate S3"
  - ".planning/VISUAL-DEFECTS.md row V18 — the identity-move defect that refused Act I"
  - "the requirement count re-derived by eight independent commands"
  - "NC-Z — the ui-test.sh zero-test guard shown able to fail"
affects:
  - "Act II does not open — Phase 4 stays IN PROGRESS pending plan 04-06"
  - "Phase 11 inherits a corrected instrument note: the mean-drift bar is blind to a permutation"
tech-stack:
  added: []
  patterns:
    - "a gate that goes red on real evidence is the gate working; declaring the pair away would have buried a state instability in an allowlist"
    - "verify a threshold was never moved by grepping git log -p for its assignment, not by reading the current value"
    - "content-band pixel counting (below y=150) separates 'different clock' from 'different screen' where a mean cannot"
key-files:
  created:
    - .planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md
  modified:
    - .planning/VISUAL-DEFECTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
decisions:
  - "VERDICT REFUSED on gate S3 — screenshots.sh exited 1 on 2 of 3 clean runs; the rules were fixed before 04-01 ran and no gate was re-thresholded to reach a different one"
  - "V18 filed rather than fixed: this plan touches no code, and a defect fixed outside the plan that measured it is a defect fixed without a negative control"
  - "the act criterion (MET) and the phase criterion (NOT MET) are reported separately and reach different answers"
  - "roadmap update-plan-progress deliberately NOT run: it would compute 5/5 plans as Complete and contradict the verdict"
  - "CRATE-04 left ticked despite weakened UI evidence — this plan may not tick or untick any requirement"
metrics:
  duration: "~90 min (three full battery runs dominate)"
  tasks: 3
  files: 4
  completed: 2026-08-30
---

# Phase 4 Plan 05: The Act I Verdict — Summary

**The verdict is REFUSED, on gate S3, and the gate that failed is
`./Scripts/screenshots.sh`, which exited 1 on two of the three clean runs this plan made.** The
artefact is `Artifacts/screenshots/02-walk-09-detail-manual-order.png`: on both failing runs it
regenerated as the **sequenced** order under a **Custom order** header — 22,142 differing pixels
below y=150 against the committed frame, the same wrong state twice — while the UI suite reported
**7 passed / 0 failed** from the log *and* from `build/ui.xcresult`. The root cause is
`CrateDetailModel.moveRows`, which commits a manual order for an **identity** move, and the crate
walk's CRATE-04 step, which asserts a button *exists* instead of measuring the row order. Filed as
ledger row **V18**. **Owner: a new Act I plan, `04-06`.** Act II does not open.

S1, S2, S4, S5, S6 and S7 all hold, on three runs each. This is a refusal on one gate with a named
cause, a named artefact and a named plan.

---

## The three runs, side by side

Two were planned. A third was run because run 2 failed and one observation of a failure is not a
characterisation of it.

| | **run 1** | **run 2** | **run 3** |
|---|---|---|---|
| `./Scripts/test.sh` | **rc=0**, `Test run with 171 tests … passed` | **rc=0**, 171 | **rc=0**, 171 |
| `./Scripts/build-app.sh` | **rc=0**, `** BUILD SUCCEEDED **` | **rc=0**, SUCCEEDED | **rc=0**, SUCCEEDED |
| UI suite — **log rc** | 0 | 0 | 0 |
| UI suite — **log count** | `Executed 7 tests, with 0 failures (0 unexpected)` | same | same |
| UI suite — **xcresult passed** | **7** | **7** | **7** |
| UI suite — **xcresult failed** | **0** | **0** | **0** |
| `ui-test.sh` zero-test guard | `totalTestCount=7` | `totalTestCount=7` | `totalTestCount=7` |
| `xcresulttool` route | `test-results-summary` | same | same |
| purged / collected | 36 / 36 | 36 / 36 | 36 / 36 |
| `screenshot-audit.py` | **AUDIT PASSED** | **AUDIT FAILED — 2 problem(s)** | **AUDIT FAILED — 2 problem(s)** |
| **`./Scripts/screenshots.sh`** | **rc=0** | **rc=1** | **rc=1** |
| `./Scripts/hygiene.sh` | 9 pass, 0 fail, rc=0 | 9 pass, 0 fail, rc=0 | 9 pass, 0 fail, rc=0 |
| `ledger-check.py` | rc=0 | rc=0 | rc=0 |
| `probe-frames.py --check` | `SUSPECT: none (46 frames)` | same | same |
| frames on disk | 46 | 46 | 46 |

**Four numbers per run for the UI suite, as the plan demands: log rc, log count, xcresult passed,
xcresult failed. All four are green on all three runs.** That is precisely what makes the failure
worth reporting — a log-only green could not have distinguished a passing suite from a dead
runner, and the result bundle confirms the suite really did run and really did pass while
photographing the wrong screen.

A fourth confirmation run was made on the **restored committed set** after run 3: audit rc=0,
probe rc=0, ledger rc=0, hygiene 9/0. The committed evidence is sound; regeneration is not.

---

## What Gate B printed, twice

```
Gate B: UNDECLARED near-duplicate 02-walk-08-detail-edit-mode.png vs
02-walk-09-detail-manual-order.png — fraction=0.002888 (9131/3162132 px, 9131 below y=150)
is under NEAR_DUPLICATE_FRACTION=0.005.
AUDIT FAILED — 2 problem(s)
```

The same pair measures **31,273 px / 0.989%** in the committed set and in run 1, because the rows
really did swap. In runs 2 and 3 it measures **9,131 px / 0.289%**, because they did not.

**The threshold was not moved and the pair was not declared.** Declaring it would have made the
audit green and buried a state instability in an allowlist — the precise failure mode the gate
exists to prevent, and the same refusal 04-01 made for the same class of failure.

---

## Per-frame drift against the ±0.06 bar — and the instrument that saw nothing

| Comparison | frames | max per-frame mean drift | frames over the ±0.06 bar |
|---|---|---|---|
| committed vs run 1 | 46 | **0.0360** | **0** |
| run 1 vs run 2 | 46 | **0.0362** | **0** |
| committed vs run 2 | 46 | **0.0453** | **0** |

**Zero frames over the bar on every comparison — including the comparison where a screen state
changed.** `02-walk-09` drifted **0.0346** between run 1 and run 2 while **22,142 content pixels**
changed, because a swap of two adjacent rows is a *permutation*: the same ink, moved. A mean
cannot see it.

04-01 reported V17 as localised by "two independent measurements", pixel diff and mean drift.
**Tonight one of the two was blind.** Recorded so Phase 11 does not inherit the wrong instrument.

The measurement that *does* see it — differing pixels below y=150, the audit's own content band:

| Comparison | frames with **zero** content-band difference | the exceptions |
|---|---|---|
| committed vs run 1 | **45 of 46** | `02-walk-08` by **1** antialiased pixel |
| committed vs run 2 | **44 of 46** | `02-walk-09` by **22,142 px**; `02-walk-08` by 3 |
| committed vs run 3 | **44 of 46** | `02-walk-09` by **22,142 px**; `02-walk-08` by 1 |

Exactly one frame, exactly the reorder frame, the same 22,142 pixels both times. Run 2 vs run 3 on
that frame: 1,431 differing pixels, bounding box **(172, 79)–(272, 116)** — the status-bar clock —
**0** below y=150. The same wrong state, twice.

---

## The root cause, confirmed three ways

1. **Source.** `CrateDetailModel.swift:91` — `orderingMode` is `.manual` *whenever*
   `crate.manualOrder != nil`. `moveRows` (`:96`) writes `crate.manualOrder` for **any** in-range
   offsets with no comparison against the current order, and `moved()` (`:113`) returns the array
   **unchanged** for an identity move (`fromOffsets: [1], toOffset: 1`). A drag landing on the row
   boundary — which the walk's own recipe-4 comment calls *"a coin flip"* — therefore renders
   **Custom order** and **Restore** over the sequencer's own order.
2. **The committed test suite already documents it.** `ManualOrderTests.swift:194` moves a row onto
   its own index and asserts only that the displayed order is unchanged. Three lines earlier, the
   out-of-range case *also* asserts `crate.manualOrder == nil`. **That assertion is absent for the
   identity move.**
3. **The photograph**, opened and read at full size on run 2 and confirmed identical on run 3 by
   measurement.

**Why the walk did not catch it:** `reorderTookEffect()` (`CrateWalkUITests.swift:389`) is
`app.buttons["restore-sequenced-order-button"].waitForExistence(timeout: 3)` — a **presence**
check. Step 9 then asserts only that `ordering-mode-label` *changed*. Neither looks at the row
order; both are satisfied by an identity move. All three runs printed identical
`WALK DRAG RECIPE FIRED: 1: press-and-drag on the row, edit mode ON` and
`WALK ordering-mode-label (manual) = 'Custom order'` lines for two different outcomes.

This is `CONTEXT.md`'s own mutation-J lesson repeating verbatim: **a presence assertion standing
where a measurement belongs.**

---

## The seven gates

| Gate | Result | Number | Times measured |
|---|---|---|---|
| S1 flow coverage | **HOLDS** | 18 COVERED, 0 uncovered, 1 DEFERRED | **4** |
| S2 distinctness | **HOLDS** | 46 files → **44 distinct states**; crate walk **15 → 14** | **4** |
| **S3 one-command regeneration** | **FAILS** | rc=0 / **rc=1** / **rc=1** | **3** |
| S4 test / build / ui-test | **HOLDS** | 171 · SUCCEEDED · 7 passed 0 failed (log + bundle) | **3**, four numbers each |
| S5 hygiene G1–G6 | **HOLDS** | 6 pass, 0 fail | **4** |
| S6 requirement count | **HOLDS** | 23 + 44 = 67 = 67 | **4** by gate, **8** derivations by hand |
| S7 ledger adjudication | **HOLDS** | 18 rows, 8 closed, 10 carried, 0 unadjudicated | **4** |

Negative controls from 04-01…04-04 are **cited with their exit codes, not re-run**, as the plan
requires. One new control was run tonight — see below.

**No gate was narrowed, filtered or re-thresholded — checked by command, not asserted.** Every
threshold in the project appears **exactly once** in `git log -p` as an addition and was never
edited: `NEAR_DUPLICATE_FRACTION = 0.005`, `MEAN_BAND = 0.1`, `CONTENT_TOP = 150`,
`MIN_DARK = 110`, `MIN_BRIGHT = 200`, `contrastMin = 60`, `wcagAAMin = 4.5`,
`G7_EXPECTED_TOTAL = 67`. Measured once.

### NC-Z — a new negative control, on the guard that had never been proved red

`Scripts/ui-test.sh`'s zero-test guard was added by 04-03 *after* the script twice exited 0 having
run nothing. It had never been shown able to fail. Run tonight against a bundle reporting no tests:

```
ui-test.sh: totalTestCount=0
ui-test.sh: FAIL — the bundle reports ZERO tests executed.
rc=1
```

and the same parser returns **7** on a healthy summary. Measured once each. The guard works.

---

## The recount — eight commands that had to agree

```
grep -c "^- \[x\] \*\*"                  .planning/REQUIREMENTS.md   ->  23
grep -c "^- \[ \] \*\*"                  .planning/REQUIREMENTS.md   ->  44
grep -cE "^- \[.\] \*\*"                 .planning/REQUIREMENTS.md   ->  67
grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+\*\*' … | sort -u | wc -l     ->  67
grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+\*\*' … | sort | uniq -d      ->  (empty)
```

`23 + 44 == 67 == 67`, no duplicates. The harness printed **AGREE**. Plus:

| # | Derivation | Result |
|---|---|---|
| 6 | traceability table row count | **67** |
| 7 | ROADMAP phase-requirement lines summed | **67**, 67 distinct, 0 duplicates |
| 8 | set difference **both ways**, checkbox list ↔ traceability | **empty in both directions** |
| 9 | *(extra)* phase assignment per requirement, ROADMAP ↔ traceability | `diff` **empty**, all 67 agree |
| — | `hygiene.sh` G7 | `23 complete + 44 outstanding = 67 total = 67 distinct` |

**All eight agree; `REQUIREMENTS.md` needed no correction and was not changed.** The gate and the
hand run agree, so G7 is not broken. **SEQ-03 confirmed still `- [ ]` and still `⚠️ REOPENED`.**
**No requirement was ticked or unticked.**

One stale figure was found and **annotated rather than deleted**, in the ROADMAP and not in the
requirements file: the sequencer amendment ends *"Requirements complete drops from 15 to 14"* —
correct when written, three counts ago. The annotation was worded to avoid every token in gate
G8's two-pass sweep, and G8 still reports 32 hits.

---

## Every committed frame opened and read — 46 of 46, none skipped

All 46 were opened at full size. **The number of frames on disk is 46 and the number opened is 46.
None were skipped.**

Nothing was found that is not already a V-row. What each group shows, and the defect it evidences,
is written out frame by frame in `ACT-I-SIGNOFF.md` §6. The frames 04-03 changed were given
particular attention, as the plan asks:

- **V4's badges** — `02-walk-07` shows the placeholder `—` / `—` pair on a **solid** capsule,
  legibly darker than ground and still visibly quieter than the complete pair; the element crops
  `04-badge-placeholder.png` and `04-badge-complete.png` show both halves side by side. The
  historical `02-03-crate-detail-bucket-expanded.png` shows the **old, fainter `.thinMaterial`**
  version — an unplanned before-picture. **The fix looks right to the eye as well as at 7.96:1.**
- **V5's relabelled bucket row** — `02-walk-07` reads `Vinyl 2` / **`Vinyl 4`**; the historical
  frame reads `Vinyl 2` / `Vinyl 3`, the collision. Correct.
- **V9's frames** — the split is exactly the measured rule: `02-walk-01` and `02-smoke` carry the
  large title, `02-walk-03` … `02-walk-15` and `03-walk-01/02/03/04/07` do not, and all four
  `03-03-capture-*` (entered via Add More) do. The six historical `02-03-crate-detail-*` frames
  **all** carry it — independent support for the session rule, from a run predating the finding.

Two unplanned observations worth recording, neither a new defect:

- `01-06-crate-list.png` shows **both** V1's defect (`Sunday Chill — 1 records`) **and** the
  washed-out pallor V2 was filed for. It is the only photograph of V2's reported symptom.
- `02-03-capture-stub.png` does still read `Camera arrives in Phase 3`, exactly as 04-04 corrected
  V8's row to say.

---

## Measurement counts

| Claim | Times measured | Result |
|---|---|---|
| `./Scripts/test.sh` = 171 green | **3** | identical every run |
| `./Scripts/build-app.sh` = BUILD SUCCEEDED | **3** | identical |
| UI suite = 7 passed / 0 failed, log **and** result bundle | **3** (four numbers each) | identical |
| `./Scripts/screenshots.sh` | **3** | **rc=0, rc=1, rc=1** |
| `screenshot-audit.py` on a regenerated set | **3** | PASSED, FAILED, FAILED |
| `screenshot-audit.py` on the **committed** set | **2** (before run 1, after restore) | PASSED both |
| `./Scripts/hygiene.sh` = 9 pass / 0 fail | **5** (3 runs + after filing V18 + after the verdict doc) | rc=0 every time |
| `ledger-check.py` | **5** | rc=0; 17 rows before V18, 18 after |
| `probe-frames.py --check` = `SUSPECT: none (46)` | **4** | identical |
| `02-walk-09` regenerates the wrong state | **2 of 3 runs** | 22,142 content px both times |
| run 2 and run 3's frame 09 are the same state | **1** (bbox + content-band count) | 0 px below y=150 |
| per-frame mean drift vs the ±0.06 bar | **3** pairwise comparisons | 0 frames over the bar in all three |
| requirement count | **8 derivations + 4 gate runs** | 23 / 44 / 67 / 67, all agree |
| every threshold unedited since introduction | **1** (`git log -p`, 8 constants) | each appears once, as an addition |
| NC-Z, the zero-test guard | **1 red, 1 green** | rc=1 on a zero-count bundle |
| frames opened and read | **46 of 46**, once each | nothing new found |
| `TODO`/`FIXME` = zero hits | **2 derivations, 3 runs of G1** | rc=1 |

Where a thing was measured **once**, the table says once.

---

## Deviations from Plan

**1. [Rule 3 — blocking] A third run was made.** The plan specifies two. Run 2 failed, and one
observation of a failure is not a characterisation of it — the two-observation discipline applies
to failures as well as to greens. Run 3 reproduced run 2 exactly. Both failures are reported; so
is the passing run.

**2. [Rule 2 — missing critical functionality] V18 was filed.** The plan does not anticipate a new
defect at 04-05. A refusal that names a cause but leaves it out of the ledger would be a refusal
with nowhere to go, and S7's whole point is that every defect has an adjudicated row. Filed as
**Low, CARRIED — Phase 4 / 04-06**. The severity was chosen from the ledger's own stated rule and
is **not load-bearing**: the verdict is REFUSED on S3 either way. Said out loud so the choice
cannot be read as fitted to a verdict.

**3. [Rule 2] NC-Z was run.** The plan asks for negative controls to be cited, not re-run. But the
zero-test guard was added by 04-03 *in response to* a failure and had never itself been shown red,
and S4 leans on it. A guard that has never been red is a decoration.

**4. `roadmap update-plan-progress 4` was deliberately NOT run.** It derives status from plan
counts and would compute 5 of 5 delivered as *Complete*, contradicting the verdict. The Phase 4
progress row was written by hand as `5/5 | In progress — REFUSED on S3 by 04-05; 04-06 required`.
The plan's own instruction — *"Do not mark Phase 4 complete if the verdict is REFUSED"* — takes
precedence over the tool.

**5. `requirements mark-complete S1…S7` was deliberately NOT run.** S1–S7 are sign-off gates from
`CONTEXT.md`, not requirement IDs: `grep -c '\*\*S[1-7]\*\*' .planning/REQUIREMENTS.md` returns
**0** for each. Same reasoning 04-04 recorded for S7. G7 still reads 23 / 44 / 67 / 67 afterwards.

**6. The regenerated screenshot sets were discarded and the committed set restored.** Both failing
runs' frames would have replaced correct evidence with a wrong state, and committing the anomalous
`02-walk-09` would have required a `DECLARED_DUPLICATES` entry to keep the audit green — the exact
allowlist absorption the gate exists to prevent. `git checkout -- Artifacts/screenshots/`, then
audit / probe / ledger / hygiene all re-confirmed green on the restored set. The anomalous frames
are described by measurement in the verdict document instead of by filename.

**7. No code was touched.** `git status --short` shows only `.planning/` paths.

### Not deviated from, deliberately

- **No gate was narrowed, filtered or re-thresholded**, and this was verified rather than claimed.
- **V3 and V12 were not guessed at.** D-04-1 held.
- **CRATE-04 was not unticked**, though its UI evidence is now demonstrably weaker than the tick
  implies. This plan may not tick or untick any requirement, and the model is demonstrably correct.
  Named in the verdict so 04-06 re-establishes the evidence rather than assuming it.

---

## What FAILED, plainly

1. **`./Scripts/screenshots.sh` exited 1 on 2 of 3 runs.** This is the refusal, and it is S3.
2. **The crate walk passed 7/7 while photographing the wrong screen**, twice, with log output
   identical to the passing run.
3. **The per-frame mean-drift instrument saw nothing** — 0.0346 on a frame with 22,142 changed
   content pixels.
4. **CRATE-04's walk assertion is a presence check**, and the requirement is ticked on it.
5. **`ManualOrderTests` omits, for the identity move, the `manualOrder == nil` assertion it makes
   three lines earlier for the out-of-range move.**
6. **`ui-test.sh`'s `RC=$?` is dead** under `set -e` — harmless, reported, not fixed.
7. Re-confirmed and still true, and **not Act I's**: `AsyncSequencer` and `BeamDivergenceCheck`
   **do not exist** (SEQ-08/09/10 wholly outstanding, Phase 9), and **three currently-green test
   assertions pass while defending a rule the owner retired** — one of the three carrying no
   marker at all. `./Scripts/test.sh` printed one of them green on all three runs tonight.

---

## Known Stubs

None introduced. This plan wrote no product code and rendered no data. The pre-existing Act I
fixtures (`FixtureCrates`, `FixtureLineSegmenter`, `FixtureObservations`, `FixturePhotoSource`) are
Phase 11's to retire, and `MetadataResolving` remains a conformance-free seam Phase 7 implements.

---

## Handoff

**Plan 04-06 closes the refusal**, and it is small:

1. `CrateDetailModel.moveRows` — return early when the computed order equals the current one. The
   RED test is `moveRows(fromOffsets: [1], toOffset: 1)` then `#expect(crate.manualOrder == nil)`,
   which is precisely the assertion `ManualOrderTests.swift:194` is missing today.
2. `CrateWalkUITests` step 9 — capture `sequenced-row-1`/`-2` before the drag and assert they
   **swapped**. `reorderTookEffect()` must measure, not check presence.
3. `./Scripts/screenshots.sh` three times clean, rc=0 every time.
4. Re-run the seven gates and re-issue `ACT-I-SIGNOFF.md`.

**Phase 11 inherits one corrected instrument note:** the ±0.06 per-frame mean-drift bar is blind to
a row permutation and must not be used alone as a regeneration check. Use content-band pixel counts
below y=150.

---

## Self-Check: PASSED

| Check | Result |
|---|---|
| `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md` exists | FOUND |
| … contains `VERDICT`, `REFUSED`, `AsyncSequencer`, `SEQ-03`, `14 distinct`, `NOT MET` | all FOUND |
| … has exactly 7 rows matching `^\| S[1-7] ` | **7** |
| `.planning/ROADMAP.md` contains `Phase 4`, `5 of 5`, `NOT MET` | all FOUND |
| ROADMAP Phase 4 is **not** marked complete | confirmed — `- [x] **Phase 4` count is **0** |
| Consistency: ledger reports 2 Medium-or-above open **and** ROADMAP Phase 4 says `NOT MET` | asserted by command — **PASS** |
| Consistency: verdict word in `ACT-I-SIGNOFF.md` == verdict word in `ROADMAP.md` | both `REFUSED` — **PASS** |
| `.planning/VISUAL-DEFECTS.md` contains `V18` in both the human table and the block | FOUND |
| `python3 Scripts/ledger-check.py` | rc=0, `18 rows, 8 closed, 10 carried, 2 Medium-or-above open` |
| `./Scripts/hygiene.sh` after every edit | rc=0, `gates: 9 pass, 0 fail` |
| `python3 Scripts/screenshot-audit.py` on the restored committed set | rc=0, `AUDIT PASSED` |
| `git status --short` touches only `.planning/` | confirmed |
| Commit `54860cb` (V18) | FOUND in `git log` |
