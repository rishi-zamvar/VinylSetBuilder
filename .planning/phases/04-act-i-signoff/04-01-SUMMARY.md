---
phase: 04-act-i-signoff
plan: 01
subsystem: testing
tags: [screenshots, pillow, xcuitest, audit, xcresulttool, gates]

requires:
  - phase: 02-crate-screens-stubbed
    provides: the fifteen 02-walk-* frames and V14's near-duplicate finding
  - phase: 03-capture-correction-stubbed
    provides: the 03-03/03-04/03-walk frames and the ad-hoc photometric probe
provides:
  - Scripts/probe-frames.py — the committed photometric/hash/dimension probe
  - Scripts/screenshot-audit.py — three executable gates (coverage, distinctness, classification)
  - Scripts/screenshots.sh — one command regenerates the set from a purged host
  - Artifacts/screenshots/MANIFEST.md — generated, never hand-edited
  - "a measured finding: the crate walk is not deterministic across runs"
affects: [04-04 defect ledger, 04-05 verdict, Phase 11 re-screenshotting]

tech-stack:
  added: []
  patterns:
    - "thresholds as module constants with no CLI override, so they cannot be tuned to make a red frame green"
    - "declared duplicates carry a KIND — IDENTICAL collapses the state count, DISTINCT does not"
    - "verify a test run from the result bundle, not from the exit code"

key-files:
  created:
    - Scripts/probe-frames.py
    - Scripts/screenshot-audit.py
    - Scripts/screenshots.sh
    - Artifacts/screenshots/MANIFEST.md
  modified:
    - .gitignore
  deleted:
    - Artifacts/screenshots/sim-settled-crate-list.png

decisions:
  - "Gate B's whole-frame fraction is a candidate generator, not a decider; every flagged pair is adjudicated by looking at it"
  - "Bucketing by a mean BAND rather than round(mean,1), because rounding has a boundary hole a new near-duplicate could walk through"
  - "sim-settled-crate-list.png deleted; 01-06-crate-list.png carries the same V1 bug state and is cited twice"

metrics:
  duration: ~37 min (three full UI suite runs dominate)
  tasks: 3
  files: 5
  completed: 2026-08-30
---

# Phase 4 Plan 01: The Screen-State Inventory, Content-Hashed — Summary

Three committed scripts and a generated manifest replace "screenshot count equals screen
count" with a measurement: **44 files, 2 declared IDENTICAL pairs, 42 distinct screen states**,
and for the crate walk specifically **15 files, 1 declared pair, 14 distinct states** — V14's
finding, now produced by a command instead of by a person noticing.

Three gates were each made red on purpose and green again. One of them went red on its own,
against real evidence, and caught something nobody was looking for.

---

## Headline: what the commands actually printed

```
$ python3 Scripts/probe-frames.py --check Artifacts/screenshots/*.png
SUSPECT: none (44 frames measured, thresholds MIN_DARK=110 MIN_BRIGHT=200)
rc=0

$ python3 Scripts/screenshot-audit.py
44 files — 42 distinct screen states (2 duplicate group(s))
crate walk: 15 files, 1 declared pair, 14 distinct states
classification: 34 regenerable, 10 historical, 0 orphan
gate B: 15 pairs compared, 5 under threshold
AUDIT PASSED — gates A, B and C green
rc=0

$ ./Scripts/screenshots.sh
==> 1/5 purging the regenerable set from the host
    purged 34 regenerable frame(s); 0 remain (must be 0)
==> 2/5 running the UI suite
==> 3/5 verifying the run from build/ui.xcresult
    route=test-results-summary passed=6 failed=0
==> 4/5 collecting from the simulator container
collected 34 screenshot(s) ... into Artifacts/screenshots/
==> 5/5 auditing and rewriting the manifest
AUDIT PASSED — gates A, B and C green
rc=0
```

**Distinct-state count vs file count:** 44 files on disk, 42 distinct screen states. The two
collapsed pairs are `02-walk-08 / 02-walk-10` (V14's, semantically correct) and
`02-smoke-crate-list / 02-walk-01-crate-list` (two tests photographing the identical crate
list; every differing pixel sits in the status-bar clock band, **0 differ below y=150**).

---

## Findings — things that were not true before this plan ran

### 1. The regenerable set is 34 files, not 33

The plan's `<interfaces>` block says 33 and STATE.md says *"33 screenshots — 9 + 4 + 5 + 15"*.
Both omit `02-smoke-crate-list.png`, which `SmokeUITests` writes in the same
`xcodebuild test` invocation. The plan's own list, added up, is also 34
(1 + 15 + 4 + 5 + 9).

**Measured three ways, three times each:** the purge glob finds 34 and leaves exactly the 10
historical frames; `collect-screenshots.sh` reported `collected 34 screenshot(s)` on each of
three runs; the audit classifies 34 as regenerable. **34 is right, 33 is an undercount in two
documents.** Bookkeeping for 04-04/04-05, not fixed here.

### 2. Six near-duplicate pairs, not one — and three of them are false positives

V14 named one near-duplicate pair. Measurement finds six under
`NEAR_DUPLICATE_FRACTION = 0.005`. **The threshold was fixed in advance and has not been
re-fitted.** Instead, every flagged pair was opened and looked at:

| Pair | Fraction | Below y=150 | Verdict |
|---|---|---|---|
| `02-walk-08-detail-edit-mode` / `02-walk-10-detail-restored` | 0.000000 (1 px) | 1 | **IDENTICAL** |
| `02-smoke-crate-list` / `02-walk-01-crate-list` | 0.000454 | **0** | **IDENTICAL** |
| `02-03-crate-list-after-delete` / `02-walk-01-crate-list` | 0.001017 | 1026 | **DISTINCT** |
| `02-03-crate-list-after-delete` / `02-smoke-crate-list` | 0.001036 | 1026 | **DISTINCT** |
| `03-04-sheet-after-split` / `03-04-sheet-lines` | 0.002757 | 8719 | **DISTINCT** |
| `02-01-crate-list-pluralised` / `sim-settled-crate-list` | 0.001653 | 3379 | **DISTINCT** (file since deleted) |

The three `DISTINCT` verdicts are the interesting ones. `02-03-crate-list-after-delete` reads
**"Friday Warehouse — 3 records"**; the other two read **"4 records"**. One digit is 0.03% of a
3,162,132-pixel frame and **100% of the state**. Likewise the split frame moved the word
"Cause" from line 2 to line 1 — the entire reason the frame exists — for 0.28% of the frame.

So the plan's Gate B design needed one addition (deviation, below): `DECLARED_DUPLICATES`
carries a **kind**. Only `IDENTICAL` collapses the distinct-state count. A single-category
allowlist would have declared these three away and reported 39 distinct states instead of 42.

**Margin warning for 04-05:** the closest genuinely-distinct pair in the whole set is
`02-walk-08` vs `02-walk-09` at **0.989%**, against a 0.5% threshold. That is a factor of two,
not a comfortable margin. It was not adjusted.

### 3. THE CRATE WALK IS NOT DETERMINISTIC — this is the important one

`./Scripts/screenshots.sh` was run three times. **Run 1 failed the audit. Runs 2 and 3
passed.**

On run 1, `02-walk-09-detail-manual-order` and `02-walk-10-detail-restored` were captured
**outside edit mode** — no red delete circles, no drag handles, "Edit" in the toolbar instead
of "Done". The committed set and runs 2 and 3 capture both frames **inside** edit mode.

The consequence is exactly backwards from V14:

| Comparison | committed set | run 1 | run 2 | run 3 |
|---|---|---|---|---|
| `02-walk-08` vs `02-walk-10` | 1 px (0.00003%) | **556,511 px (17.6%)** | 0 px (identical) | 1 px (0.00003%) |
| `02-walk-07` vs `02-walk-10` | — | **487 px (0.015%), 0 below y=150** | 17.6% | 17.6% |

On run 1, **frame 10 is a photograph of state 7, not state 8.** Gate B caught it and named it:

```
Gate B: UNDECLARED near-duplicate 02-walk-07-not-included-expanded.png vs
02-walk-10-detail-restored.png — fraction=0.000154 (487/3162132 px, 0 below y=150)
is under NEAR_DUPLICATE_FRACTION=0.005.
AUDIT FAILED — 1 problem(s)
```

**`App/`, `UITests/` and `project.yml` are byte-identical to the commit Phase 3 closed on**
(`git diff bd925ea..HEAD -- App/ UITests/ project.yml` is empty). Same code, same test,
different photograph. This is non-determinism in the walk, not a regression, and not something
04-01 fixes.

**How many times measured:** 3 runs by this plan (1 anomalous), plus the committed set from
Phase 3's run (normal), plus V14's own 3 runs (all normal) = **7 known observations, 1
anomalous**. Roughly 1 in 7 on this evidence; that estimate rests on a single anomalous
observation and should not be treated as a rate.

**This is a finding for 04-05's verdict.** It is not fixed and no gate was loosened to
accommodate it — run 1 reddening was the gate working. It also weakens S3 as written: *"the
regenerated set matches the manifest's coverage rows"* held on all three runs (Gate A never
went red), but the regenerated set does not reproduce the same **states** run to run.

The mean-drift measurement independently localises it. Per-frame mean drift against the stated
±0.06 bar:

| Comparison | frames | max drift | over the bar |
|---|---|---|---|
| run 1 vs run 2 | 44 | 0.2266 | **2** — `02-walk-09`, `02-walk-10` |
| run 1 vs run 3 | 44 | 0.2026 | **2** — `02-walk-09`, `02-walk-10` |
| **run 2 vs run 3** | 44 | **0.0306** | **0** |

Two independent measurements — pixel diff and mean drift — point at the same two frames.
`min = 0` and `max = 255` on every frame of every run.

### 4. Coverage: every MVP-SPEC §2 and §4 state has a photograph

18 `COVERED` rows and 1 `DEFERRED — Phase 12` row (the manual-entry sheet, MAN-01…05).
**No flow row turned out to be uncovered.** Every frame named in a row was opened and looked at
before the row was written — 22 frames viewed, including all six the duplicate adjudication
turned on. Coverage was not inferred from a filename.

---

## Negative controls — all run for real, with exit codes and printed text

The plan mandates five. Seven were run, because two of the five could not fail as literally
specified and needed replacing rather than reporting as green.

### On the probe (Task 1)

**NC-P1 — pale frame.** `Image.new('RGB',(100,100),(200,200,200))`
```
SUSPECT: /tmp/vsb-nc/pale.png — min=200 > 110 (no genuinely dark pixel); min == max == 200 (flat frame)
1 of 1 frames failed the V2 signature            rc=1
```
Reddens and names the frame. **Note:** a solid 200-grey trips *two* rules, because a solid
colour is also flat. To show the `min > MIN_DARK` rule failing **alone**, an extra control was
built:

**NC-P1b — pale but not flat.** min=150, max=255.
```
SUSPECT: /tmp/vsb-nc/pale-notflat.png — min=150 > 110 (no genuinely dark pixel)
1 of 1 frames failed the V2 signature            rc=1
```

**NC-P2 — flat frame.** All-black.
```
SUSPECT: /tmp/vsb-nc/flat.png — max=0 < 200 (no white ground); min == max == 0 (flat frame)
1 of 1 frames failed the V2 signature            rc=1
```
The `min != max` rule **cannot be isolated**: `min == max` and `min <= 110` and `max >= 200`
cannot hold simultaneously, so a flat frame always trips a second rule too. That is arithmetic,
not a weak gate — stated rather than glossed.

Both synthetic frames were deleted. The control is now permanent: `probe-frames.py --selftest`
rebuilds both plus a healthy frame and asserts the verdicts (`rc=0`, 4 PASS lines).

### On the audit (Task 2)

**NC-1a — the plan's coverage control, verbatim.** `mv 03-walk-05-inspect-sheet.png /tmp/`
```
note: flow row §4 'Inspect / correct sheet — editable segmentation (split, merge, hand-type)'
      lost 1 of 5 frames — 03-walk-05-inspect-sheet.png
AUDIT PASSED — gates A, B and C green            rc=0
```
**This control does NOT redden, and that is correct.** Gate A's requirement is *"at least one
committed photograph"* per state, and that row is backed by five frames. Removing one leaves
the state covered. Reported green rather than dressed up. A `note:` line was added so the
erosion is at least visible; two stronger controls were then run:

**NC-1b — remove every frame backing a row.**
```
Gate A: flow row §4 'Inspect / correct sheet — editable segmentation (split, merge, hand-type)'
has NO existing frame (expected any of: 03-walk-05-inspect-sheet.png, 03-04-sheet-lines.png,
03-04-sheet-after-split.png, 03-04-sheet-after-merge.png, 03-04-sheet-hand-typed.png)
AUDIT FAILED — 1 problem(s)                      rc=1
```

**NC-1c — remove the sole frame of a single-frame row.**
```
Gate A: flow row §2.1 'Crates screen — empty state' has NO existing frame
(expected any of: 02-walk-15-crate-list-empty.png)
AUDIT FAILED — 1 problem(s)                      rc=1
```
Both name the flow **row**, not just "a file is missing". The crate-walk arithmetic also
tracked correctly under NC-1c: `14 files, 1 declared pair, 13 distinct states`.

**NC-2 — plant an undeclared near-duplicate.** `cp 02-walk-06… 02-walk-99-planted.png`
```
Gate B: UNDECLARED near-duplicate 02-walk-06-crate-detail-sequenced.png vs
02-walk-99-planted.png — fraction=0.000000 (0/3162132 px, 0 below y=150) is under
NEAR_DUPLICATE_FRACTION=0.005. Look at both frames and add a DECLARED_DUPLICATES entry
with a kind and a reason.
AUDIT FAILED — 1 problem(s)                      rc=1
```

**NC-3 — plant a real 1×1 PNG with no citation.**
```
Gate C: ORPHAN zz-leftover.png — not written by the current suite and cited by no .md under
.planning/docs (excluding .planning/phases/04-act-i-signoff).
AUDIT FAILED — 1 problem(s)                      rc=1
```

**Unplanned bonus control:** Gate C went red on the **real** orphan before anything was
planted, on the untouched committed tree — `Gate C: ORPHAN sim-settled-crate-list.png … rc=1`.
The gate was proved able to fail on real evidence, not only on a plant.

`git status --short` was empty of this plan's paths after every revert (only the concurrent
04-02 executor's `Scripts/hygiene.sh` and `CARRIED-DEBT.md` appeared, which are not mine).

### On the one-command script (Task 3)

**NC-S — absent result bundle.** `build/ui.xcresult` moved aside; step 2 replaced with a no-op.
```
==> 1/5 purging the regenerable set from the host
    purged 34 regenerable frame(s); 0 remain (must be 0)
==> 2/5 running the UI suite
    [NC] simulating a run that produced no result bundle
==> 3/5 verifying the run from build/ui.xcresult
    build/ui.xcresult is missing — the run produced no result bundle.
    REFUSING to collect: the simulator container still holds the
    previous run's PNGs and they would look like this run's.
rc=1
```
**Step 4/5 never printed** — the script refused rather than collecting stale PNGs from the
container. That is the exact hazard `collect-screenshots.sh` warns about in its own header,
and it is now closed in code. The host was left with the 10 historical frames intact and 0
regenerable, then restored with `git checkout --`.

The first attempt at this control ran against `/tmp` instead of the repo, because
`screenshots.sh` does `cd "$(dirname "$0")/.."` and the mutated copy was placed in `/tmp`.
It was re-run from inside `Scripts/`. Recorded because the first result was meaningless and
would have read as a pass.

---

## Deviations from plan

### 1. [Rule 2 — missing critical functionality] `DECLARED_DUPLICATES` gained a `kind` field

- **Found during:** Task 2, first measurement of the committed set
- **Issue:** The plan seeds the allowlist with `(frame_a, frame_b, reason)` and computes
  `distinct = len(frames) - len(declared_pairs)`. Measurement found six flagged pairs, three of
  which are materially different screens (§Findings 2). Declaring those under a single category
  would have subtracted them from the distinct-state count and reported 39 states where there
  are 42 — a gate quietly producing a wrong number.
- **Fix:** entries are `(a, b, kind, reason)` with `kind ∈ {IDENTICAL, DISTINCT}`. Only
  `IDENTICAL` collapses. The threshold itself is untouched at 0.005.
- **Files modified:** `Scripts/screenshot-audit.py`
- **Commit:** `726d833`

### 2. [Rule 1 — bug] Bucketing by a mean band, not `round(mean, 1)`

- **Found during:** Task 2
- **Issue:** The plan specifies bucketing by `(w, h, round(mean, 1))`. Two frames with means
  243.649 and 243.651 round into different buckets and would **never be compared** — a
  near-duplicate could walk straight through Gate B on a rounding boundary. A gate with a hole
  in it is decorative.
- **Fix:** compare pairs with matching dimensions and `|Δmean| ≤ 0.1`. This is a strict
  superset of the plan's buckets (it adds 5 comparisons the rounding missed, 17 vs 12 on the
  45-file set) and still nowhere near the naive 990.
- **Files modified:** `Scripts/screenshot-audit.py`
- **Commit:** `726d833`

### 3. [Rule 2] A second measurement per flagged pair: differing pixels below `CONTENT_TOP`

- **Issue:** A whole-frame fraction cannot distinguish "same screen, different clock" from
  "same screen, one digit changed". Both are ~0.1%.
- **Fix:** every pair also reports differing pixels below y=150 and the diff bounding box. The
  band was **measured, not guessed**: the diff bbox of the one pair known to differ only in the
  clock (`02-smoke` vs `02-walk-01`) is (167, 79)–(277, 117). This is the evidence each
  `IDENTICAL`/`DISTINCT` verdict rests on, and it is printed in the manifest.
- **Commit:** `726d833`

### 4. [Rule 2] A `note:` line when a flow row loses some but not all of its frames

- **Found during:** NC-1a, which passed green while a cited frame was missing.
- **Fix:** partial erosion prints a note. Deliberately **not** a failure — "at least one
  photograph per state" is the requirement, and requiring all listed frames would redden
  whenever a redundant frame is legitimately pruned.
- **Commit:** `636864f`

### 5. [Rule 3] `sys.dont_write_bytecode` + `__pycache__/` in `.gitignore`

The audit's `importlib` load was writing `Scripts/__pycache__/`. Fixed at source so the
artefact is never created; the `.gitignore` line is belt-and-braces.
**Commit:** `dece528`

### 6. Task 3's `done` criterion says "33-frame set"; it regenerates 34

Not a deviation in behaviour — a correction to the plan's arithmetic. See Finding 1.

### Not deviated from, deliberately

- `NEAR_DUPLICATE_FRACTION` stays at 0.005. `MIN_DARK` stays at 110. `MIN_BRIGHT` stays at 200.
  None was touched, and the probe has no CLI override for any of them by design.
- Run 1's Gate B failure was **not** made to pass by declaring the `02-walk-07 / 02-walk-10`
  pair. Declaring it would have absorbed a state instability into an allowlist, which is the
  precise failure mode the gate exists to prevent.

---

## The orphan deletion

`Artifacts/screenshots/sim-settled-crate-list.png` — **cited in 0 documents**, confirmed by
`grep -rn "sim-settled" .planning docs`, whose only hits are this phase's own CONTEXT.md and
PLAN.md (excluded from the citation search as circular). Deleted in `726d833`.

It was opened and looked at first, as the plan requires. It is **not** junk: it shows
**"Sunday Chill — 1 records"**, the V1 pluralisation bug, settled. `.planning/VISUAL-DEFECTS.md`'s
V1 row cites only `02-walk-01-crate-list.png` and `02-01-crate-list-pluralised.png`, and **both
of those show the fixed "1 record"** — so V1's row cites no photograph of the defect it names.

Deletion was still safe, and this was checked rather than assumed: **`01-06-crate-list.png`
also shows "1 records"**, is not regenerable, and is cited in 2 documents. The bug's evidence
path survives. That check is why the file was deleted rather than kept, and 04-04 may want to
add `01-06-crate-list.png` to V1's evidence cell so the closed defect cites a picture of itself.

---

## Measurement counts — how many times each claim was measured

| Claim | Times measured | Result |
|---|---|---|
| `probe --check` → `SUSPECT: none` | **4** (committed 45; then runs 1, 2, 3 at 44) | none suspect every time |
| `min = 0`, `max = 255` on every frame | **3** (runs 1, 2, 3 × 44 frames) | invariant |
| Audit exits 0 on a healthy set | **4** (post-deletion; runs 2, 3; post-NC revert) | rc=0 |
| Audit exits 1 on a broken set | **6** (real orphan, NC-1b, NC-1c, NC-2, NC-3, run 1) | rc=1, named the cause |
| Crate walk = 14 distinct states | **3** (committed set, run 2, run 3) | 15 files, 1 pair, 14 states |
| `02-walk-08` vs `02-walk-10` | **4** by this plan (+3 by V14) | 3 near-identical, **1 at 17.6%** |
| Walk non-determinism | **1 anomalous observation** out of 7 known | see Finding 3 |
| Per-frame mean drift | **3** pairwise comparisons | 0.0306 max between two normal runs |
| Regenerable set = 34 files | **3** (purge glob, collect output ×3, audit ×3) | 34, not 33 |
| `xcresulttool` route A works | **4** (pre-check + runs 1, 2, 3) | `test-results-summary`, never the fallback |
| UI suite green | **3** (runs 1, 2, 3) | `passed=6 failed=0` from `build/ui.xcresult` |

The fallback `xcresulttool` route (`--legacy`) was **never exercised** on this machine, because
route A never failed. It is written and it prints which route it used, but it is **unproven** —
stated as unproven rather than claimed as working.

---

## What FAILED, plainly

1. **`./Scripts/screenshots.sh` exited 1 on its first of three runs.** The plan's verification
   says `rc=0`. It was rc=1, because the audit correctly caught a changed screen state. Runs 2
   and 3 were rc=0. Reported as 2-of-3, not as "passes".
2. **The plan's NC-1 does not redden.** Reported green with the reason, and replaced with two
   controls that do.
3. **The `min != max` rule cannot be shown failing in isolation** — arithmetically impossible
   alongside the other two thresholds.
4. **The `xcresulttool` fallback route is untested** on this Xcode.
5. **Two documents undercount the regenerable set** (33 vs the measured 34).
6. Observed while working, **not mine and not touched**: `.planning/STATE.md` now carries a
   prose sentence in its `status:` field and `completed_phases: 2` where it read `3` before,
   both written by the concurrent 04-02 executor's state tooling. Flagged for 04-05's recount.

---

## Commits

| Commit | What |
|---|---|
| `1505a0f` | `Scripts/probe-frames.py` — the probe that ran six times and lived nowhere |
| `726d833` | `Scripts/screenshot-audit.py`, `MANIFEST.md`, orphan deleted |
| `dece528` | stop the audit writing `__pycache__` |
| `636864f` | partial-coverage note |
| `49ee74a` | `Scripts/screenshots.sh` — one command, bundle-verified |
| `08db6e7` | regenerated 34-frame set (run 3) + regenerated manifest |

---

## Handoff

- **04-04** owns the ledger. Two candidate rows from this plan: the walk's run-to-run state
  instability (Finding 3), and V1's evidence cell citing no photograph of its own defect.
- **04-05** owns the verdict. S1 holds (18 covered rows, 0 uncovered). S2 holds and is now
  decidable by command. **S3 is the one to look at hard**: one command does regenerate the set
  and the audit does gate it, but 1 run in 3 produced a different screen state from identical
  code, and the manifest's md5s are therefore run-specific by nature.
- The regenerable count in `04-01-PLAN.md`, `CONTEXT.md` and `STATE.md` should read **34**.

---

## Self-Check: PASSED

Every claim above was re-verified against disk after the summary was written.

| Check | Result |
|---|---|
| `Scripts/probe-frames.py` exists | FOUND, 192 lines (plan floor: 60) |
| `Scripts/screenshot-audit.py` exists | FOUND, 520 lines (plan floor: 120) |
| `Scripts/screenshots.sh` exists | FOUND, 73 lines (plan floor: 20) |
| `Artifacts/screenshots/MANIFEST.md` exists, contains "distinct screen states" | FOUND, 169 lines |
| `sim-settled-crate-list.png` deleted | confirmed absent |
| Commits `1505a0f 726d833 dece528 636864f 49ee74a 08db6e7` | all 6 FOUND in `git log` |
| key_link: audit references `probe-frames` | OK |
| key_link: `screenshots.sh` chains ui-test → collect → audit under `set -euo pipefail` | OK |
| "collected 34 screenshot(s)" on all three runs | OK, verbatim in all three logs |
| "passed=6 failed=0" from `build/ui.xcresult` on all three runs | OK, route A each time |
| `App/`, `UITests/`, `project.yml` unchanged since `bd925ea` | OK, empty diff |
| `sim-settled-crate-list.png` cited 0 times outside this phase | OK |
| V1's ledger row cites only the two FIXED frames | OK — `02-walk-01`, `02-01-crate-list-pluralised` |
| `01-06-crate-list.png` (carries the unfixed "1 records") cited | OK, 2 documents |

Nothing in the summary is claimed without a command behind it. Where a command was run once,
the table in "Measurement counts" says once.
