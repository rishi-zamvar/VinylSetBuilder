# Act I Sign-off

**Decided:** 2026-08-30 · **By:** plan `04-05` · **Against:** the seven gates S1–S7 fixed in
`.planning/phases/04-act-i-signoff/CONTEXT.md` **before plan 04-01 ran a single command**.

---

## 1. VERDICT

# REFUSED

**What is missing, in three lines:**

1. **Gate S3 is red.** `./Scripts/screenshots.sh` — the one command that regenerates the whole
   screenshot set from a purged host — exited **1** on **two of the three clean runs** this plan
   made. It exited 0 once.
2. **The artefact:** `Artifacts/screenshots/02-walk-09-detail-manual-order.png`. On both failing
   runs it came back photographing the **sequenced** order under a **Custom order** header —
   **22,142 differing pixels below y=150** against the committed frame, the same wrong state both
   times. The committed frame is correct; **regeneration is not.**
3. **The plan that would close it: `04-06`.** Give `CrateDetailModel.moveRows` an identity guard,
   give the crate walk's CRATE-04 step an assertion on **row order** rather than on the existence
   of a button, then re-run the set clean three times. Filed as ledger row **V18**.

Act II may **not** open on this. Act I's claim is *every screen exists, is navigable in the
simulator on stubbed data, and is photographed.* The photographs exist and are right. What is not
established is that they can be **re-taken** — and Act I's whole value to Acts II and III is that
Phase 11 re-runs this walk and re-screenshots the set after each of five stub swaps. A walk that
photographs the wrong state on two runs in three, while reporting **7 passed / 0 failed** from
both the log and the result bundle, is not a baseline anything can be compared against. The
refusal is cheap now and expensive later: it costs one small plan today, and it would cost the
credibility of five comparison sets in Phase 11.

**Everything else holds.** S1, S2, S4, S5, S6 and S7 all pass, on three independent runs each.
This is a refusal on one gate, with a named cause, a named artefact and a named plan — not a
statement that Act I is in bad shape.

---

## 2. The two criteria, reported separately

They are two different bars and conflating them is the exact dishonesty this phase exists to
prevent. One is MET and the other is not.

### 2a. The act criterion — **MET**

> *"Act ship criterion: committed screenshots of EVERY screen, taken in the booted simulator
> after a settle delay."* — `ROADMAP.md`, throughline section, verbatim

| Clause | Result | Evidence |
|---|---|---|
| committed screenshots | MET | 46 PNGs tracked in `Artifacts/screenshots/`, working tree clean at `54860cb` |
| of **every** screen | MET | Gate A of `Scripts/screenshot-audit.py`: **18 COVERED rows, 0 uncovered**, 1 `DEFERRED — Phase 12`. Green on all three runs |
| in the booted simulator | MET | UDID `4B4E1C1F-BED6-4812-9238-C151337265DA`, iPhone 16 Pro, iOS 26.0.1, named in every `build/ui.xcresult` |
| after a settle delay | MET | `UITests/ScreenshotRecorder.swift:21,24` — `defaultSettle = 3.0`, `launchSettle = 4.0`, one `Thread.sleep` in one place; **45 of the 46 recorder call sites go through it** |

**The one exception, stated rather than glossed.** Two of the 46 files —
`04-badge-placeholder.png` (178×60) and `04-badge-complete.png` (228×61) — are **element crops**
written by `BadgeContrastUITests.swift:212` via `XCUIElement.screenshot()`, which does **not** go
through the settle delay; it uses `waitForExistence` instead. They are V4's pixel evidence, not
screens. **Zero Gate A flow rows cite either of them** (verified by command), so no screen's
coverage depends on a frame taken without the settle. The other 44 are full-screen states through
the recorder.

**The one screen Act I does not photograph** is the manual-entry sheet (MAN-01…05). It is not a
gap: the owner's own act structure puts manual entry in Act III, and the manifest records it as
`DEFERRED — Phase 12` with that reasoning. Act I does not build the screen, so there is nothing
to photograph.

### 2b. The phase criterion — **NOT MET**

> *"screenshot count equals screen count with zero screens missing; `VISUAL-DEFECTS.md` has zero
> rows at Medium or above still open; a grep for `TODO`/`FIXME` across `App/` and
> `VinylSetBuilderCore/Sources/` returns zero hits."* — `ROADMAP.md` Phase 4, verbatim

It is a three-part conjunction. Reported clause by clause, because reporting it as one word hides
which part failed.

| # | Clause | Result | The number, and the command |
|---|---|---|---|
| 1 | screenshot count equals screen count, zero screens missing | **MET** | `python3 Scripts/screenshot-audit.py` → `46 files — 44 distinct screen states`; Gate A `18 COVERED, 0 uncovered`. Measured **4 times** (3 runs + the restored committed set) |
| 2 | `VISUAL-DEFECTS.md` has zero rows at Medium or above still open | **NOT MET** | `python3 Scripts/ledger-check.py` → `18 rows, 8 closed, 10 carried, **2 Medium-or-above open**`. Measured **4 times** |
| 3 | grep `TODO`/`FIXME` across `App/` and `VinylSetBuilderCore/Sources/` returns zero hits | **MET** | the roadmap's literal command, `grep -rn "TODO\|FIXME" App/ VinylSetBuilderCore/Sources/` → **rc=1, zero hits**; independently `hygiene.sh` G1 → PASS. **2 derivations, 3 runs of G1** |

**Clause 2 is NOT MET.** Written in those words, not softened, not re-worded, not moved. The two
open Medium rows:

**V3 — the not-included bucket cannot name the record it excluded.** Owner **Phase 4 / U8**.
Outside Act I's reach because it is blocked on an **unanswered owner question**, not on code. Two
fixes are defensible and they are not equivalent in their side effects: Fix A gives
`VinylEntry.label` the first-candidate `Track.displayName` fallback `SequencedRow.title` already
has, and moves nothing measured; Fix B marks the fixture tracks `.resolved`, and **would move
Phase 3's committed `6 Read / 5 Partial / 1 Unread` strip baseline**, which has a negative control
behind it. That asymmetry is recorded as *evidence for* U8 and is explicitly **not** a reason to
pick for the owner. Guessing would waste the question. Locked as decision **D-04-1** before any
plan in this phase ran. Photographed twice, a phase apart:
`02-walk-07-not-included-expanded.png` and `03-walk-07-done-sequenced.png`.

**V12 — the inspect sheet titles a record `Zzz.`, a fragment of a price sticker.** Owner
**Phase 6**. Outside Act I's reach because the fix is a **capability Act I has not built**:
Phase 6 success criterion 2 already specifies SEG-03's currency/decimal filter verbatim, which
drops price-sticker fragments *before* any naming rule picks from them. Writing that filter inside
Act I would be building the thing Phase 6 immediately replaces — and Phase 11 then deletes the
stub it was written against. Confirmed on three different screens across three runs.

**Both carries are provably outside Claude's authority to close.** Had S1–S7 all held, that is
precisely the situation the pre-fixed rule calls `SIGNED OFF WITH NAMED CARRY`. **They did not all
hold**, so the verdict is REFUSED and the carries are recorded rather than pleaded.

---

## 3. The seven gates

Each row: the gate, the result, the command, the number it produced, **how many times it was
measured**, and the negative control that proved it can go red. Controls from plans 04-01 to 04-04
are **cited, not re-run**, as the plan requires; NC-Z is new tonight.

| Gate | Result | Command | Number | Times measured | Proved able to fail by |
|---|---|---|---|---|---|
| S1 | **HOLDS** | `python3 Scripts/screenshot-audit.py` (Gate A) | 18 COVERED, 0 uncovered, 1 DEFERRED | **4** (runs 1–3 + committed set) | NC-1b and NC-1c, 04-01 — removed every frame backing a row, and the sole frame of a single-frame row; both `AUDIT FAILED`, **rc=1**, each naming the flow **row**. (NC-1a, the plan's own control, did **not** redden and 04-01 reported it green with the reason) |
| S2 | **HOLDS** | `python3 Scripts/screenshot-audit.py` (Gate B) | 46 files → **44 distinct screen states**; crate walk **15 files → 14 distinct states** | **4** | NC-2, 04-01 — planted an undeclared near-duplicate; `AUDIT FAILED`, **rc=1**, naming both frames. Also reddened on **real** evidence 3 times tonight (runs 2 and 3, and 04-01's own run 1) |
| S3 | **FAILS** | `./Scripts/screenshots.sh` | run 1 **rc=0**; run 2 **rc=1**; run 3 **rc=1** | **3** | NC-S, 04-01 — result bundle removed; the script **refused to collect** and exited **1** before step 4/5. Tonight it went red twice on real evidence |
| S4 | **HOLDS** | `test.sh`, `build-app.sh`, `screenshots.sh` step 2/3 + `xcresulttool` | **171** Core tests; **BUILD SUCCEEDED**; UI **7 passed / 0 failed** from the log *and* from `build/ui.xcresult` | **3** each, four numbers per run | **NC-Z, new tonight** — the zero-test guard in `ui-test.sh` run against a bundle reporting no tests: `totalTestCount=0`, `FAIL — the bundle reports ZERO tests executed`, **rc=1**; the same parser returns 7 on a healthy summary. Measured once each |
| S5 | **HOLDS** | `./Scripts/hygiene.sh` G1–G6 | **6 pass, 0 fail** | **4** | NC-G1…NC-G6, 04-02 — six mutations, **rc=1** each, every one naming its file and token. NC-G2 additionally forced a real fix: a build failure had been reported as SKIP |
| S6 | **HOLDS** | `hygiene.sh` G7, plus eight hand-run derivations | **23 complete + 44 outstanding = 67 total = 67 distinct**, no duplicate ID | **4** by gate, **8 derivations** by hand | NC-G7, 04-02 — a duplicated requirement line; **rc=1**, reddening on **both** rules independently (`duplicate requirement ID(s): SEQ-01` and `total = 68 but distinct IDs = 67`) |
| S7 | **HOLDS** | `python3 Scripts/ledger-check.py` / G9 | **18 rows, 8 closed, 10 carried**, 0 unadjudicated, 2 Medium-or-above open | **4** | NC-L1…NC-L4, 04-04 — **rc=1** each, naming the row; plus NC-L0, which neutered `check()` and drove 11 of 12 selftest cases red |

**No gate was narrowed, filtered or re-thresholded.** Checked, not asserted: every threshold in
the project appears **exactly once** in `git log -p` as an addition and was never edited —
`NEAR_DUPLICATE_FRACTION = 0.005`, `MEAN_BAND = 0.1`, `CONTENT_TOP = 150`, `MIN_DARK = 110`,
`MIN_BRIGHT = 200`, `contrastMin = 60`, `wcagAAMin = 4.5`, `G7_EXPECTED_TOTAL = 67`. Measured once,
by command.

In particular, S3 was **not** rescued by adding `02-walk-08 / 02-walk-09` to `DECLARED_DUPLICATES`.
That would have made the audit green and buried a state instability in an allowlist — the precise
failure mode the gate exists to prevent, and the same refusal 04-01 made for the same class of
failure.

---

## 4. Why S3 failed — the whole chain, measured

### The three runs

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| `./Scripts/test.sh` | rc=0, **171 tests** | rc=0, **171 tests** | rc=0, **171 tests** |
| `./Scripts/build-app.sh` | rc=0, **BUILD SUCCEEDED** | rc=0, **BUILD SUCCEEDED** | rc=0, **BUILD SUCCEEDED** |
| UI suite — log rc | 0 | 0 | 0 |
| UI suite — log count | `Executed 7 tests, with 0 failures` | `Executed 7 tests, with 0 failures` | `Executed 7 tests, with 0 failures` |
| `xcresult` passed | **7** | **7** | **7** |
| `xcresult` failed | **0** | **0** | **0** |
| `ui-test.sh` guard | `totalTestCount=7` | `totalTestCount=7` | `totalTestCount=7` |
| frames collected | 36 regenerable, 46 on disk | 36 / 46 | 36 / 46 |
| `screenshot-audit.py` | **AUDIT PASSED** | **AUDIT FAILED — 2 problems** | **AUDIT FAILED — 2 problems** |
| `./Scripts/screenshots.sh` | **rc=0** | **rc=1** | **rc=1** |
| `./Scripts/hygiene.sh` | 9 pass, 0 fail | 9 pass, 0 fail | 9 pass, 0 fail |
| `ledger-check.py` | rc=0 | rc=0 | rc=0 |
| `probe-frames.py --check` | `SUSPECT: none (46)` | `SUSPECT: none (46)` | `SUSPECT: none (46)` |

**Every gate except the audit was green on every run.** The UI suite was verified from the result
bundle as well as the log all three times, which is the discipline that makes the next sentence
meaningful: **the suite passed 7/7 while photographing the wrong screen.**

### What Gate B actually printed, twice

```
Gate B: UNDECLARED near-duplicate 02-walk-08-detail-edit-mode.png vs
02-walk-09-detail-manual-order.png — fraction=0.002888 (9131/3162132 px, 9131 below y=150)
is under NEAR_DUPLICATE_FRACTION=0.005.
AUDIT FAILED — 2 problem(s)
```

In the committed set and in run 1, that same pair measures **31,273 px / 0.989%** — above the
threshold, because the two rows really did swap. In runs 2 and 3 it measures **9,131 px /
0.289%**, because they did not.

### The frame, looked at

`02-walk-09-detail-manual-order.png` from run 2 was **opened and read at full size**. It shows the
header **`Custom order`** with the blue **`Restore`** action — and rows
`1 Source Direct — Snake Style · 170 · 5A` / `2 Photek — Ni Ten Ichi Ryu · 172 · 8A`, which is the
**sequenced** order, unchanged from frame 8. The committed frame shows them swapped
(`1 Photek` / `2 Source Direct`), which is what CRATE-04 is about.

Run 3's frame was confirmed to be the **same state** by measurement rather than by re-reading it:
run 2 vs run 3 differ by 1,431 px whose bounding box is **(172, 79)–(272, 116)** — the status-bar
clock — with **0** differing pixels below y=150.

### Content-band arithmetic against the committed set

| Comparison | frames with **zero** differing pixels below y=150 | the exceptions |
|---|---|---|
| committed vs run 1 | **45 of 46** | `02-walk-08` by **1** antialiased pixel |
| committed vs run 2 | **44 of 46** | `02-walk-09` by **22,142 px**; `02-walk-08` by 3 |
| committed vs run 3 | **44 of 46** | `02-walk-09` by **22,142 px**; `02-walk-08` by 1 |

Exactly one frame, exactly the reorder frame, exactly the same 22,142 pixels on both failing runs.
Regeneration is otherwise pixel-perfect.

### The root cause, confirmed three ways

1. **Source.** `CrateDetailModel.swift:91` — `orderingMode` is `.manual` *whenever*
   `crate.manualOrder != nil`. `moveRows` (`:96`) writes `crate.manualOrder` for **any** in-range
   offsets, with no comparison against the current order, and `moved()` (`:113`) returns the array
   **unchanged** for an identity move such as `fromOffsets: [1], toOffset: 1`. So a drag that lands
   on the row boundary — which the walk's own recipe 4 comment calls *"a coin flip"* — commits a
   manual order identical to the sequenced one, renders `Custom order`, and shows `Restore`.
2. **The committed test suite already documents it.**
   `ManualOrderTests.swift:194` moves a row onto its own index and asserts only
   `ladder.rows.sequenced.map(\.id) == before`. Three lines earlier, the out-of-range case *also*
   asserts `ladder.crate.manualOrder == nil`. **That assertion is absent for the identity move.**
3. **The photograph**, above, on two independent runs.

### Why the walk did not catch it

`reorderTookEffect()` (`CrateWalkUITests.swift:389`) is:

```swift
app.buttons["restore-sequenced-order-button"].waitForExistence(timeout: 3)
```

A **presence** check. Step 9 then asserts only that `ordering-mode-label` **changed**. Neither
looks at the row order. Both are satisfied by an identity move. All three runs printed
`WALK DRAG RECIPE FIRED: 1: press-and-drag on the row, edit mode ON` and
`WALK ordering-mode-label (manual) = 'Custom order'` — identical logs for two different outcomes.

This is `CONTEXT.md`'s own mutation-J lesson repeating verbatim: *prefer assertions that MEASURE
over assertions that CHECK PRESENCE.* Mutation J shrank the thumbnail tiles from 101 pt to 41 pt
and every count and existence assertion still passed. Here a drag reordered nothing and every
existence assertion still passed.

### The instrument that saw nothing

04-01 localised V17 with **two** independent measurements, pixel diff and per-frame mean drift,
and reported that they agreed. Tonight **one of the two was blind**:

| Comparison | max per-frame mean drift | bar | frames over the bar |
|---|---|---|---|
| committed vs run 1 | 0.0360 | ±0.06 | **0** |
| run 1 vs run 2 | 0.0362 | ±0.06 | **0** |
| committed vs run 2 | 0.0453 | ±0.06 | **0** |

`02-walk-09` drifted **0.0346** between run 1 and run 2 — comfortably inside the bar — while
22,142 content pixels changed. A swap of two adjacent rows is a **permutation**: the same ink,
moved. A mean cannot see it. **The ±0.06 mean-drift bar must not be used on its own as a
regeneration check**, and 04-01's "two independent measurements" claim is weaker than it reads.
Recorded here so Phase 11 does not inherit the wrong instrument.

### Filed as V18

`.planning/VISUAL-DEFECTS.md` row **V18**, severity **Low**, **CARRIED — Phase 4 / 04-06**.

Severity was chosen from the ledger's own stated rule (*product-visible defects are Medium or Low;
harness and accounting defects are Low or Informational*): it is product-visible, shows no
incorrect data and loses nothing. **The severity is not load-bearing** — the verdict is REFUSED on
S3 either way, and calling it Medium would change nothing except the count in clause 2. Said out
loud so the choice cannot be read as fitted to a verdict.

---

## 5. The recount — eight derivations that had to agree

Re-derived by command, not copied from this plan, from `CONTEXT.md`, or from `STATE.md`.

```
grep -c "^- \[x\] \*\*"                    .planning/REQUIREMENTS.md   ->  23   complete
grep -c "^- \[ \] \*\*"                    .planning/REQUIREMENTS.md   ->  44   outstanding
grep -cE "^- \[.\] \*\*"                   .planning/REQUIREMENTS.md   ->  67   total
grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+\*\*' … | sort -u | wc -l       ->  67   distinct IDs
grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+\*\*' … | sort | uniq -d        ->  (empty)
```

`23 + 44 == 67 == 67`, no duplicate ID. The harness printed **AGREE**.

Three further derivations, because agreement between five greps over one file is still agreement
about one file — plus a fourth that was not asked for:

| # | Derivation | Result |
|---|---|---|
| 6 | `REQUIREMENTS.md` traceability table row count | **67** |
| 7 | `ROADMAP.md` phase-requirement lines, summed | **67**, 67 distinct, **0 duplicates** |
| 8 | set difference **both ways**, checkbox list ↔ traceability table | **empty in both directions** |
| 9 | *(extra)* phase assignment per requirement, ROADMAP ↔ traceability | `diff` **empty** — all 67 agree on which phase owns them |
| — | `hygiene.sh` G7, the committed gate | `23 complete + 44 outstanding = 67 total = 67 distinct, no duplicate ID` |

**All eight agree. Nothing in `REQUIREMENTS.md` needed correcting**, so nothing was changed there.
The gate and the hand run agree, so G7 is not broken and NC-G7 covered the case that mattered.

**SEQ-03 confirmed still unticked** — `.planning/REQUIREMENTS.md:89` reads `- [ ] **SEQ-03**` and
carries `⚠️ REOPENED`. Counting it complete is precisely half of the error that produced a
plausible wrong total before.

**No requirement was ticked or unticked.** Phase 4 owns zero requirements and completes none.

**One stale figure found, and it is in the ROADMAP, not the requirements file.** The
2026-08-30 sequencer amendment ends *"Requirements complete drops from 15 to 14."* — correct when
written, three counts ago. Annotated in place with the live figure and the command to re-derive
it; the checkbox list is the source of truth and was not touched.

**One honest challenge to the count, recorded and not acted on.** `CRATE-04` is ticked complete,
and the frame that photographs it —`02-walk-09-detail-manual-order.png` — is exactly the frame
that came back wrong on two of three runs tonight. The requirement's *implementation* is not in
doubt (run 1 and the committed frame both show a real reorder; `ManualOrderTests` covers the
model), but its **UI evidence is weaker than the tick implies**. Left ticked, because this plan
may not tick or untick anything and because the model is demonstrably correct. Named here so
04-06 re-establishes it rather than assuming it.

---

## 6. Screenshot accounting

| Quantity | Number | How |
|---|---|---|
| Files on disk, tracked | **46** | `ls Artifacts/screenshots/*.png` |
| Distinct md5s | **46** | md5 alone would report 46 distinct states — **it cannot see the two identical-state pairs**, because the status-bar clock differs. This is why S2 is decided by content comparison and not by hashing |
| Declared `IDENTICAL` pairs | **2** | `02-walk-08` / `02-walk-10`; `02-smoke-crate-list` / `02-walk-01-crate-list` |
| Declared `DISTINCT` pairs (measured false positives) | **4** | kept as separate states — only `IDENTICAL` collapses |
| **Distinct screen states** | **44** | 46 − 2 |
| Crate walk | **15 files → 14 distinct states** | V14's arithmetic, produced by a command. This is the case that proves a filename count lies: state 10 *is* state 8, because Restore's whole job is to return there |
| Regenerable | **36** | `REGENERABLE_PREFIXES` in `screenshot-audit.py` — the source of truth `screenshots.sh` purges against |
| Historical evidence | **10** | not regenerable, each cited by name in a `.planning/` document |
| Orphans | **0** | one was found and deleted by 04-01 (`sim-settled-crate-list.png`, cited in 0 documents) |
| Frames opened and read by this plan | **46 of 46** | every committed frame, at full size. None skipped |
| Full-screen states through the settle-delay recorder | **44** | the other 2 are V4's element crops |

**Closest genuinely-distinct pair in the whole set:** `02-walk-08` vs `02-walk-09` at **0.989%**
against a 0.5% threshold — a factor of two, not a comfortable margin, and 04-01 flagged it as one
to watch. Tonight that margin is exactly what S3 fell through: the pair dropped to **0.289%** and
Gate B fired. The margin warning was correct, and the threshold was still not moved.

### What every frame shows — the 46, read

All 46 were opened. Nothing new was found that is not already a V-row; the notes below are what
each frame is, and the defect each one evidences.

**Crate walk, 15 frames.** 01 crate list (`1 record` / `4 records`, V1 fixed, large title present)
· 02 New Crate sheet with keyboard · 03 capture, guide at full size, `0 records` · 04 capture with
1 record, flip banner, **guide visibly smaller — V10** · 05 `Nothing sequenced yet` + `Not in the
set (1)` — V7's closure · 06 running order 1–2 with 170/5A and 172/8A badges · 07 bucket expanded,
`Vinyl 2` 178/6A and `Vinyl 4` — / — — **V3 and V5-fixed and V4-fixed all in one frame** · 08 edit
mode, red circles and drag handles, `Done` · 09 `Custom order` + `Restore`, rows swapped ·
10 `Running order` restored, still in edit mode — identical to 08 by construction, V14 · 11 Add
More on Friday Warehouse reading **`0 records` for a four-record crate — V11** · 12 one row left
after a vinyl was removed · 13 Sunday Chill showing `Photek — The Hidden Camera` 174/9A, CRATE-07's
different selection · 14 list after delete, `3 records` · 15 `No Crates Yet`. **Frames 03–15 carry
no navigation title — V9**, and 01 does; the split is exactly V9's measured rule.

**Smoke, 1 frame.** The crate list again, clock 6:12 against 6:09 — the declared IDENTICAL pair,
confirmed by eye.

**Capture screen, 4 frames.** Empty, one item, flip prompt (**guide 686 px, V10**), flip suppressed
(guide back to 872, CAP-05's suppression). All four carry the large `Capture` title, because those
sessions entered through Add More — V9's rule again, from the other side.

**Inspect sheet, 5 frames.** Lines (title **`Zzz.` — V12**; `$9.73 [Import]` and `8.00%` price
noise; `Timeless Recordings` / `TimelessRecordings` — **V16**; `TYME 012` catalogue number kept) ·
after merge (line 1 becomes `Zzz. Cause 4 Concern-`) · after split (`Zzz. Cause` / `4 Concern-`,
count restored — the merge runs first, which the test confirms) · hand-typed (line 17
`DUBPLATE WHITE LABEL`) · raw text on fixture 1 (`HIGHER`, confidences **1.00 green and 0.30 red** —
OCR-04 keeping the untrusted read).

**Capture/inspect walk, 9 frames.** Guide · flip fires · flip suppressed · strip at 12 with
`Read` / `Partial` pills and **records named from their own OCR text**, which is V3's
counter-evidence · inspect sheet on `JA22` with line 4 **`EXCLUSIVE NEW MIXES FR…` truncated — V15**
· raw text on `DRUMSOUND &` with **`SIMON BASSLINE SMITH` twice — V16** and a truncated URL ·
done-sequenced with **twelve records all excluded, `Vinyl 1`…`Vinyl 8` — V3's second sighting, and
the reason V6 is not assessable** · strip at 21 · strip scrolled to the end, tile widths unchanged
— CAP-03 measured, not counted.

**Badge crops, 2 frames.** Placeholder `—` / `—` and complete `178` / `6A`, both legible, the
placeholder visibly quieter. Both halves of SEQ-11 confirmed by eye at the 7.96:1 and 18.27:1
numbers.

**Historical, 10 frames.** `01-06-crate-list` — **`Sunday Chill — 1 records`, V1's own defect, and
the frame is also visibly washed out, which is the only photograph of V2's reported symptom** ·
`02-01-crate-list-pluralised` the same screen fixed and at full contrast · `02-03-capture-stub`
reading **`Camera arrives in Phase 3` — V8's own defect**, exactly as 04-04 corrected the row to
say · six `02-03-crate-detail-*` frames, all of which **do** carry the large title, which is
independent support for V9's session rule · `02-03-crate-list-after-delete` reading `3 records`,
the digit that makes it DISTINCT from the `4 records` frames. `02-03-crate-detail-bucket-expanded`
additionally shows the **pre-fix** `Vinyl 2` / `Vinyl 3` collision (V5) with the **old, fainter
`.thinMaterial` badges** (V4) — a before-picture for both closures.

---

## 7. Carried debt that is NOT Act I's

Named here so the verdict does not absorb it. Phase 4 owns the **ledger**; Phase 9 owns the
**code**. Nothing below was edited — `git diff --stat ce31189 HEAD -- …/Sequencing/` is empty and
the newest commit touching `Sequencing/` is still `59e2f3c feat(01-04)`, so Phase 9 starts from an
unmodified baseline.

### 7a. `AsyncSequencer` and `BeamDivergenceCheck` do not exist — Phase 9's

Plan `01-05-PLAN.md` was written and **never executed**. There is no async sequencing seam and no
beam-divergence check on disk. Re-confirmed tonight three times by gate G4:

```
grep -rn --exclude-dir=.build "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/   ->  rc=1
```

**SEQ-08, SEQ-09 and SEQ-10 are _wholly_ outstanding, not partly built.** The Phase 1 record
implies a seam that is not there. Phase 9 inherits `01-05-PLAN.md`,
`.planning/open-questions/RejoinTests.swift.wip` and `Q1-sequencer-determinism.md`.

### 7b. SEQ-03 is REOPENED, and **three currently-green test assertions pass while defending a rule that no longer exists** — Phase 9's

The owner replaced the non-decreasing BPM rule with bidirectional adjacency on 2026-08-30. The
shipped Act I code still **implements** the retired rule —
`BPMRules.swift:17`, `b >= a && (b - a) <= tolerance + 1e-9`, where the `b >= a` clause *is* the
retired rule as executable code, findable only by a structural pass. **17 artefacts**, accounted
for by gate G8 against a live 32-hit sweep, three runs.

Three green assertions defend it, and **one of the three carries no marker at all**:

| # | Test | Marked `⚠️ STALE`? |
|---|---|---|
| 1 | `test_givenSequence_whenInspected_thenBPMIsNonDecreasing` — `BeamSearchSequencerTests.swift:41` | yes |
| 2 | `test_givenDecreasingBPM_whenGated_thenRejected` — `BPMRulesTests.swift:48` (correct expectation under the new rule is `true`) | yes |
| 3 | `test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending` — `BeamSearchSequencerTests.swift:65` | **no** |

`./Scripts/test.sh` printed `171 tests … passed` on all three runs tonight, and one of the lines it
printed was
`✔ Test "[STALE — retired spec, Phase 9 replaces] BPM is non-decreasing across the whole winning sequence" passed`.

**A green suite that contains a test defending a dead specification is a suite whose greenness
means less than it appears to, and a sign-off that does not say so is overstating what it
verified.** Said here, in those words. **Phase 9 rewrites three assertions, not two.** None of this
is counted against Act I, and none of it is fixed here.

---

## 8. What Act I did NOT verify

A sign-off that lists only what passed is an advertisement. This is the negative space.

| Not verified | Why it could not be, here | Where it becomes answerable |
|---|---|---|
| **The manual-entry sheet** (MAN-01…05) | Act I does not build the screen — the owner's own act structure puts manual entry in Act III. A recorded decision, not a gap | **Phase 12** |
| **The live camera** (CAP-01 non-blocking shutter, CAP-04 twenty records without stalling or throttling) | **The simulator has no camera.** The preview is a black rectangle by decision D-03-2. Putting these in Act I would have put an unverifiable criterion in Act I | **Phase 10** |
| **Whether the app installs and launches on the physical iPhone 14 Pro** (U1) | Needs the device connected and trusted; `devicectl` reports it `unavailable`. Signing-free device-SDK compilation passes, which is a different claim | owner + **Phase 10** |
| **Whether the produced set is one the owner would actually play** (U4 / U6) | Irreducibly human, and it is **the project's real success criterion**. No assertion in this repo speaks to it | owner |
| **Whether the correction sheet is fast in a real hand** (U9) | A stopwatch-and-thumb judgement on a real layout. Every measurement here can say the tap count is 1; none can say the sheet is quick. It is also the named blocker on carried defect V15 | owner |
| **Whether the framing guide frames a real sleeve** (U10) | Verified **as geometry only** — 0.881 edge coverage, 290.67 × 291 pt, square to within half a point. Whether 0.88 is right for a 12″ sleeve at arm's length is unanswerable without a camera behind it | owner + **Phase 10** |
| **Double-digit running-order index alignment** (V6) | **Not assessable and not guessed.** No fixture crate reaches ten *sequenced* rows — `03-walk-07` reaches twelve records but all twelve are excluded, so the running order is empty. Manufacturing a third fixture crate would rewrite the very walk this phase audits (D-04-2) | **Phase 11**, and it must be **re-carried** rather than closed if that run still produces fewer than ten rows |
| **That the crate walk photographs the same states run to run** | This is what failed. 1 of 3 runs tonight; 2 of 9 known observations under V17's older signature | **04-06**, then Phase 11 |
| **Any real OCR, segmentation, resolution, BPM or key** | Act I renders from `FixtureCrates` and `FixtureObservations` throughout. Every measured baseline in the roadmap (6/5/1 OCR, 5-of-6 catalogue, 72% SoundCloud, 29-track ground truth) is **unmeasured by Act I** and belongs to Act II | **Phases 5–9** |
| **`ui-test.sh`'s `RC=$?`** | Under `set -e` the script has already exited if `xcodebuild` failed, so `RC` is always 0 by the time it is read. Harmless — the failure path never reaches it — but it is dead, and it is written down rather than fixed, because this plan touches no code | 04-06 or Phase 14's sweep |

---

## 9. Open questions for the owner

**Nothing here blocked execution.** Every one was routed to `.planning/UAT-PENDING.md` and the plan
continued. 11 U-rows: **4 closed** (U2, U3, U5, U7), **7 open**.

| # | The question, in one sentence | Blocks |
|---|---|---|
| **U8** | The not-included bucket names a record `Vinyl 2` when the app can name it `Dillinja — Angels Fell` — must "which record got left out" be legible in Act I, or can it wait for real resolution in Act III? (Fix A is code-side and moves nothing measured; Fix B is fixture-side and moves Phase 3's `6 Read / 5 Partial / 1 Unread` baseline) | **V3**, a Medium row |
| **U11** | Add More opens a capture screen reading `0 records` for a crate that holds four — session count, or crate total? The number is correct as specified; the question is which number to *show* | nothing — Phase 11 re-photographs it regardless |
| **U9** | Are merge-up, split and hand-type the right three operations, and is one tap each fast enough for a record you will correct dozens of times? | **V15** |
| **U10** | Does a guide covering 0.88 of the shorter edge frame a real 12″ sleeve at arm's length? | nothing until Phase 10 |
| **U4 / U6** | Is the produced set one you would actually play? | nothing mechanically; it is the project's real success criterion |
| **U1** | Connect and trust the iPhone 14 Pro so the signed build can be installed | Phase 1 criterion 4, and Phase 10 |

---

## 10. How to re-derive this verdict

A sceptical reader should not have to trust any number above.

```bash
./Scripts/test.sh                                     # expect 171 green
./Scripts/build-app.sh                                # expect BUILD SUCCEEDED
./Scripts/screenshots.sh                              # THE GATE — expect rc=1 on roughly 2 runs in 3
xcrun xcresulttool get test-results summary --path build/ui.xcresult   # expect passed 7 / failed 0
python3 Scripts/screenshot-audit.py                   # green on the committed set
python3 Scripts/probe-frames.py --check Artifacts/screenshots/*.png
./Scripts/hygiene.sh                                  # expect 9 pass, 0 fail
python3 Scripts/ledger-check.py                       # expect 18 rows, 8 closed, 10 carried, 2 Medium+
grep -rn "TODO\|FIXME" App/ VinylSetBuilderCore/Sources/ ; echo "rc=$?"    # expect rc=1
```

`screenshots.sh` is the one to run more than once. When it goes red, open
`Artifacts/screenshots/02-walk-09-detail-manual-order.png` and read the two rows under the
**Custom order** header: if they are in the same order as `02-walk-08`, that is V18.

`xcresulttool` route used on this machine, all three runs: **`get test-results summary`**. The
`--legacy` fallback in `screenshots.sh` was never exercised and remains **unproven**.

---

## 11. What FAILED tonight, plainly

1. **`./Scripts/screenshots.sh` exited 1 on 2 of 3 runs.** This is the refusal.
2. **The crate walk passed 7/7 while photographing the wrong screen**, on both failing runs, with
   identical log output to the passing run.
3. **The per-frame mean-drift instrument saw nothing** — 0.0346 on a frame with 22,142 changed
   content pixels. One of 04-01's two "independent" localisers is blind to a permutation.
4. **CRATE-04's walk assertion is a presence check**, and the requirement is ticked complete on it.
5. **`ManualOrderTests` omits, for the identity move, the `manualOrder == nil` assertion it makes
   three lines earlier for the out-of-range move.**
6. **`ui-test.sh`'s `RC=$?` is dead code** under `set -e`.
7. Not new, but re-confirmed and still true: **three green tests defend a retired specification**,
   and **`AsyncSequencer` / `BeamDivergenceCheck` do not exist**.

---

## 12. To close this refusal — plan 04-06

1. `CrateDetailModel.moveRows` — return early when the computed order equals the current one, so
   an identity drag does not commit a manual order. TDD: the RED test is
   `moveRows(fromOffsets: [1], toOffset: 1)` then `#expect(crate.manualOrder == nil)`, which is
   the assertion `ManualOrderTests.swift:194` is missing today.
2. `CrateWalkUITests` step 9 — assert the **row order changed**, by capturing
   `sequenced-row-1`/`-2` labels before the drag and asserting they swapped. `reorderTookEffect()`
   must measure, not check presence.
3. Re-run `./Scripts/screenshots.sh` **three times clean** and require rc=0 every time.
4. Re-run the seven gates and re-issue this document.

Until then, **Act I is not signed off, and Act II does not open.**

---

*Verdict issued 2026-08-30 by plan 04-05, against gates fixed in `CONTEXT.md` before plan 04-01
ran. Three independent clean runs. Every committed frame opened and read. The requirement count
re-derived by eight commands that had to agree. A refusal is a legitimate outcome and this is one.*

---

# ADDENDUM — the refusal answered, 2026-08-30, plan 04-06

This section is appended, not merged into the verdict above. The verdict is 04-05's record of
what was true when it was issued and it stays exactly as written. What follows is what changed.

## Gate S3 now HOLDS

`./Scripts/screenshots.sh`, three consecutive runs from a purged host, against the final code:

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| `./Scripts/screenshots.sh` | **rc=0** | **rc=0** | **rc=0** |
| purge | 36 frames, 0 remain | 36, 0 | 36, 0 |
| UI suite, from the log | `Executed 7 tests, with 0 failures` | same | same |
| UI suite, from `build/ui.xcresult` | route=`test-results-summary` passed=**7** failed=**0** | same | same |
| `ui-test.sh` zero-test guard | `totalTestCount=7` | 7 | 7 |
| drag recipe that fired | **2** (edit mode OFF) | **1** (edit mode ON) | **2** (edit mode OFF) |
| row order, before → after | `1 Source Direct / 2 Photek` → `1 Photek / 2 Source Direct` | same | same |
| walk states | 15 files, 1 declared pair, **14 distinct** | same | same |
| `screenshot-audit.py` | **AUDIT PASSED** | **AUDIT PASSED** | **AUDIT PASSED** |

**Where 04-05 measured rc=0 / rc=1 / rc=1, this is rc=0 / rc=0 / rc=0.** The three runs are not
three repetitions of one path: recipes 1 and 2 both won, so both edit-mode branches of the walk
were exercised and both produced the same 14 distinct states.

An **earlier** series of three runs, made against an intermediate state of the code, went
**rc=0 / rc=0 / rc=1** and is reported here rather than dropped. Its failure was **not** V18 —
V18 did not reproduce on any run tonight — but a second defect that V18's fix uncovered by
letting a recipe other than 1 win for the first time: the walk's post-drag edit mode followed
the gesture routing, so `02-walk-10` came back **byte-identical** to `02-walk-07` (0 differing
pixels) and the declared `08/10` pair went stale. Fixed in `3efc975`; the series-B runs above
are the three clean runs the gate asks for, and one of them (run 3) is exactly that case.

## The other six gates, re-measured

| Gate | Verdict | Command | What it printed | Times measured tonight |
|---|---|---|---|---|
| S1 | HOLDS | `screenshot-audit.py` gate A | 18 covered rows, 0 uncovered | 4 (3 runs + standalone) |
| S2 | HOLDS | `screenshot-audit.py` gate B | 46 files → 45 distinct; walk 15 → 14 | 4 |
| **S3** | **HOLDS** | `./Scripts/screenshots.sh` | **rc=0, rc=0, rc=0** | **3** |
| S4 | HOLDS | `test.sh`, `ui-test.sh` + `xcresulttool` | **172** Core tests (was 171 + 1 new); UI **7 passed / 0 failed** from log *and* bundle | 3 each |
| S5 | HOLDS | `./Scripts/hygiene.sh` | **9 pass, 0 fail** | 3 |
| S6 | HOLDS | `hygiene.sh` G7 | 23 complete + 44 outstanding = 67 | 3 |
| S7 | HOLDS | `ledger-check.py` / G9 | **18 rows, 9 closed, 9 carried**, rc=0 | 3, plus `--selftest` |

**All seven gates now hold.** The act criterion — committed settle-delay screenshots of every
screen — was already MET in the verdict and is unchanged.

## What this addendum does NOT claim

- **The phase criterion's clause 2 is still NOT MET, and 04-06 did not touch it.** Two
  Medium-or-above rows remain open: **V3**, blocked on the owner's unanswered U8, and **V12**,
  owned by Phase 6's SEG-03 filter. Closing V18 changed the ledger from 8 closed / 10 carried to
  **9 closed / 9 carried**; the Medium-or-above count is **2**, exactly as before.
- **Finding 6 of §11 is still open.** `ui-test.sh`'s `RC=$?` is still dead code under `set -e`.
  It was left alone deliberately: it is outside this plan's stated scope, and the three-run S3
  evidence above was gathered with the script exactly as the verdict measured it. The S3 claim
  does not rest on that variable — `screenshots.sh` re-derives pass/fail from the result bundle
  and refuses to collect on `failed != 0` or `passed == 0`.
- **Findings 7 of §11 is unchanged**: three green tests still defend a retired specification, and
  `AsyncSequencer` / `BeamDivergenceCheck` still do not exist. Both are Phase 9's.

Findings **1 through 5** of §11 are closed by this plan.
