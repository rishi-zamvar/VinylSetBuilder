---
phase: 02-crate-screens-stubbed
plan: 05
subsystem: closure-and-hygiene
tags: [visual-audit, defect-closure, hygiene, ship-criterion, act-i]
requires:
  - the fifteen photographed states (02-04)
  - CrateDetailView / CrateListView / RootView (02-03)
  - CrateDetailModel (02-01), XCUITest harness (02-02)
provides:
  - "V1 closed with a named evidence screenshot and a two-sided assertion"
  - "V2's closure re-confirmed on the four screens that did not exist when it was diagnosed"
  - "six new visual findings (V3 Medium, V4-V7 Low, V8 informational), each with evidence or an honest 'none'"
  - "the ship-criterion audit, run by command, numbers recorded verbatim"
  - "a corrected requirement count and a truthful Phase 2 roadmap row"
  - "the AsyncSequencer gap and the monotonic-BPM artefact inventory, written where Phase 9's planner will read them"
affects:
  - Phase 3 (inherits V8, the capture stub it replaces)
  - Phase 4 (inherits V3 Medium and V4-V7 Low; no longer owns V1/V2)
  - Phase 9 (inherits SEQ-08/09/10 unbuilt, and six monotonic-BPM artefacts to rewrite)
tech-stack:
  added: []
  patterns:
    - "every behavioural claim rests on at least two independent observations, and says how many"
    - "a gate is reported, never filtered: the one XXX hit is named and explained, not grepped away"
    - "the host screenshot glob is purged before the counting run, so the count cannot pass on a leftover"
key-files:
  created:
    - .planning/phases/02-crate-screens-stubbed/02-05-SUMMARY.md
  modified:
    - .planning/VISUAL-DEFECTS.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/UAT-PENDING.md
    - .planning/phases/02-crate-screens-stubbed/deferred-items.md
    - Artifacts/screenshots/02-walk-01..15 (+ 02-smoke-crate-list) replaced with this plan's own clean re-run
decisions:
  - "Zero App/ and zero Core changes: no measured defect survived a settle delay, so nothing was restyled"
  - "02-smoke-crate-list.png KEPT — but for a different reason than 02-04 gave; see below"
  - "V3 recorded, not fixed: the plan makes recording the deliverable and Phase 4 the sign-off gate"
  - "The XXX gate hit is reported honestly rather than filtered — mktemp's template cannot be removed"
metrics:
  duration: ~35 min
  tasks: 2
  files: 22
  completed: 2026-08-30
  tests_before: 113 unit + 2 UI
  tests_after: 113 unit + 2 UI
---

# Phase 2 Plan 05: Closure and Hygiene Summary

All fifteen photographs were looked at, not sampled; V1 is closed with a picture and an
assertion that can fail, V2's closure is re-confirmed on the four screens it was never tested
against, six new findings are recorded with evidence, every hygiene sweep is clean, and the
ship criterion is audited by command with the numbers written down — and the audit found and
corrected a requirement count that was wrong in two directions at once.

## What I audited, and how many times I measured each claim

The lesson this plan was handed is that plans 02-03 and 02-04 both reached a confident wrong
conclusion from a single observation. So every claim below carries its sample count.

| Claim | Observations | How |
|---|---|---|
| No frame carries the V2 pallor signature | **2** | Pillow probe over all 15, on 02-04's captures and again on this plan's own clean re-run |
| The walk is deterministic frame-for-frame | **2** | per-frame luminance means agree to within **±0.06** across the two runs |
| The UI is not `.disabled(true)` | **3** | three complete walk runs, each tapping six controls that all responded |
| States 3 and 4 are byte-identical (D-02-04-1) | **2** | md5 `ab046e5f…` on 02-04's run, `6a903ce3…` on mine — different bytes (clock), same pair |
| `Sequencing/` is unmodified since Phase 1 | **2** | `git diff --stat` empty, **and** `git log -1` on the directory returns `59e2f3c feat(01-04)` |
| V3 ("Vinyl 2" for a fully-known record) | **3** | `02-walk-07` (my run), `02-03-crate-detail-bucket-expanded` (02-03's run), and the source: `VinylEntry.label` requires `.resolved` while no fixture `Track` ever sets it |
| ui-test green | **2** | the log says `** TEST SUCCEEDED **`; the result bundle independently says `passedTests: 2, failedTests: 0, skippedTests: 0, expectedFailures: 0` |

## The fifteen-row luminance table — this plan's own clean re-run

`Artifacts/screenshots/02-walk-*.png` purged first, `./Scripts/ui-test.sh` re-run,
`./Scripts/collect-screenshots.sh` re-collected. The count gate therefore cannot pass on a
leftover — that is the hazard `collect-screenshots.sh`'s header names, and it was honoured.

| File | size | mean | min | max | bytes | md5 | Δmean vs 02-04 |
|---|---|---|---|---|---|---|---|
| `02-walk-01-crate-list.png` | 1206x2622 | 242.4 | 0 | 255 | 103,549 | `5c4bb7d7` | −0.01 |
| `02-walk-02-new-crate-sheet.png` | 1206x2622 | 233.7 | 0 | 255 | 168,337 | `f3ecaf55` | +0.01 |
| `02-walk-03-capture-empty.png` | 1206x2622 | 251.1 | 0 | 255 | 92,427 | `6a903ce3` | −0.04 |
| `02-walk-04-capture-with-vinyl.png` | 1206x2622 | 251.1 | 0 | 255 | 92,427 | `6a903ce3` | −0.04 |
| `02-walk-05-new-crate-detail.png` | 1206x2622 | 241.0 | 0 | 255 | 148,397 | `a8d640ba` | −0.05 |
| `02-walk-06-crate-detail-sequenced.png` | 1206x2622 | 240.5 | 0 | 255 | 188,185 | `064341db` | +0.01 |
| `02-walk-07-not-included-expanded.png` | 1206x2622 | 241.4 | 0 | 255 | 235,445 | `883884cd` | −0.06 |
| `02-walk-08-detail-edit-mode.png` | 1206x2622 | 241.6 | 0 | 255 | 245,372 | `8c66d621` | −0.06 |
| `02-walk-09-detail-manual-order.png` | 1206x2622 | 241.6 | 0 | 255 | 248,914 | `a1e13fa4` | −0.04 |
| `02-walk-10-detail-restored.png` | 1206x2622 | 241.6 | 0 | 255 | 245,369 | `1b1a4494` | −0.06 |
| `02-walk-11-add-more-capture.png` | 1206x2622 | 250.6 | 0 | 255 | 96,381 | `54aa0e62` | −0.06 |
| `02-walk-12-detail-after-remove-vinyl.png` | 1206x2622 | 240.5 | 0 | 255 | 164,856 | `82321125` | −0.02 |
| `02-walk-13-second-crate-different-selection.png` | 1206x2622 | 240.9 | 0 | 255 | 155,512 | `a9e9ec12` | −0.01 |
| `02-walk-14-crate-list-after-delete.png` | 1206x2622 | 242.4 | 0 | 255 | 104,691 | `94aa5ef9` | −0.01 |
| `02-walk-15-crate-list-empty.png` | 1206x2622 | 252.8 | 0 | 255 | 92,590 | `8451ecad` | −0.05 |

```
SUSPECT: none
MEAN DRIFT >0.15 vs 02-04 run: none
probe exit=0
```

Every frame: a genuinely black pixel (`min 0`) and a white ground (`max 255`). The V2 signature
is `min` above ~110 — no dark pixel anywhere. It appears on none of the fifteen, on either run.

## V1 — closed

**Disposition: CLOSED with evidence.** `.planning/VISUAL-DEFECTS.md` has V1 struck through.

- **Fix:** `CrateListView.swift:21` — `Text("^[\(summary.recordCount) record](inflect: true)")`.
  Automatic grammar agreement. **The inflection fired on this SDK**; plan 02-03's documented
  manual-branch fallback was never needed.
- **Evidence, the picture:** `02-walk-01-crate-list.png` — `Sunday Chill — 1 record` and
  `Friday Warehouse — 4 records` in the same frame, both correct, both looked at directly at
  1206×2622. Corroborated by `02-01-crate-list-pluralised.png` from the run that landed the fix.
- **Evidence, the assertion:** two-sided. `contains("1 record")` **and** `!contains("1 records")`.
  A one-sided check would have passed on the defect itself, because `"1 records"` contains
  `"1 record"`. Paired with the negative control
  `XCTAssertFalse(app.staticTexts["record-count-Wednesday Nonexistent"].exists)`, so a query
  resolving nothing reddens rather than passes vacuously.

## V2 — closure re-confirmed on the new screens

**Disposition: STAYS CLOSED. Not re-diagnosed, not re-litigated, nothing restyled.**

V2 was diagnosed against a single crate-list capture. This phase then built four screens that
capture did not contain: **crate detail, edit mode, the expanded not-included bucket, and the
empty crate list**. Those were what needed confirming, and all four carry the healthy signature
on both runs.

**The strongest evidence is functional, not photometric — and the walk gives it away for free.**
`.disabled(true)` on an enclosing view dims content **and makes it untappable**. The walk taps
`crate-row-Friday Warehouse`, `edit-button`, `add-more-button`,
`restore-sequenced-order-button`, `capture-add-fixture-button` and `capture-done-button`, and
every one responds — the walk only reaches state 15 because they all did. Disabled content is
not tappable, so a completed walk is a **categorical** disproof that no pixel measurement can
give. It has now completed three times.

## Every new finding, with severity and evidence

Recorded in `.planning/VISUAL-DEFECTS.md`. **None were fixed** — the plan makes recording the
deliverable and Phase 4 the Act I sign-off gate that inherits Medium and above.

| # | Finding | Sev | Evidence |
|---|---|---|---|
| **V3** | The not-included bucket names a record **"Vinyl 2"** while showing its real `178` / `6A` badges and the reason "No track within 4 BPM of the set". The app can name that track `Dillinja — Angels Fell`. **A DJ cannot tell which record was left out — half of what SEQ-07 exists to say.** Root cause, read from source: `VinylEntry.label` requires `resolutionState == .resolved`, `SequencedRow.title` uses `Track.displayName` which ignores it, and **no fixture `Track` ever sets `.resolved`** (all default `.pending`). Two row types, two naming rules. | **Medium** | `02-walk-07-not-included-expanded.png` |
| V4 | Placeholder `—`/`—` badges render `.secondary` on a `.thinMaterial` capsule — light grey on light grey. SEQ-11's rule is *dimmed, never hidden*; at this contrast it is very close to hidden. | Low | `02-walk-07`, the "Vinyl 3" row |
| V5 | `FixtureCrates.mixedResultsCrate` gives `sharedVinyl` and `unresolvedVinyl` **both `position: 2`**, so both would label "Vinyl 3". Latent duplicate label. | Low | **none — not visible in any of the fifteen.** Only one of the two ever lands in the bucket. Found by reading `FixtureCrates.swift:24` and `:48` |
| V6 | Running-order index alignment at double digits **could not be assessed** — no fixture crate reaches ten rows, so no photograph shows an index ≥ 10 against the `minWidth: 20` monospaced column. | Low | none — honest "not assessable", per the plan's own fallback |
| V7 | The walk **never photographs the empty running order**. It adds a fixture vinyl before opening the new crate, so state 5 has a row and `empty-running-order` is unexercised. A coverage gap in the evidence, not a defect in the pixels. | Low | verified instead via 02-03's `02-03-crate-detail-empty.png`, where it reads "Nothing sequenced yet" and does **not** read like a crash |
| V8 | The capture screen reads as scaffolding — literally "Camera arrives in Phase 3". Correct and deliberate; its doc comment names Phase 3. Recorded only so a reviewer is not surprised. | Informational | `02-walk-03`, `-04`, `-11` |

### What the plan asked me to look for, and did NOT find

Each checked against all fifteen frames at full resolution:

- **badge capsules clipped, overlapping the title, or wrapping** — none. Even in edit mode,
  where the title wraps to two lines to make room for the delete circle and the drag handle,
  the badge pair holds one line and does not collide.
- **em-dash placeholder where a real BPM or key was expected** — none. It appears only on
  "Vinyl 3", the genuinely unresolved fixture, which is exactly correct.
- **reason strings truncating to one line and losing their meaning** — none. Both
  ("No track within 4 BPM of the set", "No BPM yet — resolve it or enter it by hand") render
  in full.
- **row titles truncating so two different tracks read identically** — none. Titles **wrap**,
  they do not truncate. (The related hazard that *does* exist is V5, and it is in the labels,
  not the truncation.)
- **the empty running order reading like a crash** — it does not; see V7 for where that was
  verified.

## The hygiene sweep — every command, every result

```
grep -rn "TODO\|FIXME\|XXX" App/ VinylSetBuilderCore/Sources/ UITests/ Scripts/
  -> Scripts/generate-secrets.sh:73:tmp_file="$(mktemp "$OUT_DIR/.Secrets.swift.XXXXXX")"     rc=0

grep -rn "TODO\|FIXME"        App/ VinylSetBuilderCore/Sources/ UITests/ Scripts/    -> rc=1 (clean)
grep -rn "AVFoundation\|Vision\|UIKit\|AppKit\|SwiftUI\|SwiftData\|URLSession\|URLRequest\|URLProtocol" \
                               VinylSetBuilderCore/Sources/                          -> rc=1 (clean)
grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/    -> rc=1 (clean)
grep -rn "Slider\|setTolerance"  App/ VinylSetBuilderCore/Sources/                   -> rc=1 (clean)
grep -rn "Phase 2"               App/                                                -> rc=1 (clean)
git diff --stat VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/          -> empty
```

**Zero `TODO`, zero `FIXME`, anywhere this phase touched.** The single `XXX` hit is
**mktemp's mandatory template syntax**, not a marker. It cannot be removed: the template must
live in `$OUT_DIR` so the subsequent rename is same-filesystem and therefore atomic, and
`mktemp` requires literal `XXXXXX` in an explicit path template. **I did not filter it out of
the gate to manufacture a clean exit code** — it is reported here, and logged as `D-02-05-2`
with the option for Phase 4 to narrow the pattern to `\bXXX\b(?!X)` if it wants rc=1.

**The sequencer is byte-identical to how Phase 1 left it**, and I have two proofs rather than
one: `git diff --stat` on `Sequencing/` is empty, **and**
`git log --oneline -1 -- .../Sequencing/` returns `59e2f3c feat(01-04): implement
BeamSearchSequencer` — a Phase 1 commit. Phase 9's bidirectional rewrite starts from an
unmodified baseline.

**Two judgement calls, made:**

- **`NaiveBPMSortSequencer` is dead.** `grep -rn "NaiveBPMSortSequencer"` across `App/`,
  `Sources/`, `Tests/` and `UITests/` returns exactly **one** hit — its own declaration at
  `Fixtures/NaiveBPMSortSequencer.swift:4`. Nothing references it; `CrateDetailView` constructs
  `BeamSearchSequencer` directly. **Not deleted** — it is named in plan 01-06's rationale and
  Phase 11 owns stub deletion. Logged as `D-02-05-1` so it does not quietly become permanent.
- **`CapturePlaceholderView`'s doc comment already says Phase 3**, not Phase 2:
  *"The camera does not exist until Phase 3. This is disposable scaffolding…"*. Left alone.

## The ship-criterion audit — verbatim

| Gate | Command | Output | Exit |
|---|---|---|---|
| 1 | `./Scripts/test.sh` | `✔ Test run with 113 tests in 0 suites passed after 0.011 seconds.` | **0** |
| 2 | `./Scripts/build-app.sh` | `** BUILD SUCCEEDED **` | **0** |
| 3 | `./Scripts/ui-test.sh` | `IDETestOperationsObserverDebug: 122.966 sec` / `** TEST SUCCEEDED **` | **0** |
| 4 | `ls Artifacts/screenshots/02-walk-*.png \| wc -l` | `15` | — |

Gate 3, independently from the result bundle rather than the log:

```json
"deviceName": "VSB-Test", "modelName": "iPhone 16 Pro", "osVersion": "26.0.1",
"expectedFailures": 0, "failedTests": 0, "passedTests": 2, "skippedTests": 0
```

**113 > Phase 1's 88**, as required. **15 == the state count in `02-04-SUMMARY.md`'s manifest**,
and the host glob was **purged before the counting run**, so that 15 is fifteen states actually
captured tonight, not a leftover. No state was dropped, the drag fired, and **no U8-for-a-dropped-state
row was needed** — `.planning/UAT-PENDING.md` is correct as 02-04 left it on that point.

Nothing was weakened to reach any of these. No threshold, manifest or assertion was edited.

## The truthful update — and what the audit caught

`REQUIREMENTS.md` traceability now reads `Complete — 02-01/02-03/02-04` for CRATE-03, CRATE-04
and CRATE-05 (they were already ticked; the attribution was blank). `ROADMAP.md` marks Phase 2
complete, `**Plans**: 5 of 5 delivered`, all five listed and ticked, Progress row
`5/5 | Complete | 2026-08-30`.

**The audit caught a count that was wrong in two directions at once.** Both files said
*"Already complete: 15 of 67"* and named `SEQ-01/02/03/04/06/07/11` among them.

- It **included `SEQ-03`**, which was **REOPENED** the same day when the sequencer spec went
  bidirectional. Its own entry in the same file says so. The summary line contradicted the
  requirement it was summarising.
- It **omitted CRATE-03/04/05**, which Phase 2 delivered and photographed.

Recounted from the ticked boxes rather than from the previous line —
`grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md` → **17**. Both files now say **17 complete,
50 outstanding**, with the correction and its command written next to the figure so the next
reader can re-derive it in one command instead of trusting it.

**SEQ-05 was deliberately NOT built (D2-4), and the roadmap still says so.** Verified: it sits
in Phase 9 at ROADMAP lines 56 and 281, Phase 2's own section states it is *"Phase 9's
requirement and is deliberately absent here"*, and
`grep -rn "Slider\|setTolerance" App/ VinylSetBuilderCore/Sources/` returns nothing. **No Phase 2
text implies a tolerance slider exists.**

## Carried forward — the two things Phase 9's planner will otherwise get wrong

### 1. `AsyncSequencer` and `BeamDivergenceCheck` DO NOT EXIST

Plan 01-05 was written but **never executed**. There is no async sequencing seam and no beam
divergence check on disk:

```
grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/   -> nothing
```

**SEQ-08, SEQ-09 and SEQ-10 are wholly outstanding — not partially built.** Phase 9 inherits
`01-05-PLAN.md`'s content along with `.planning/open-questions/RejoinTests.swift.wip`. This is
a real gap between what the Phase 1 record implies and what is on disk, and it is now written
into `REQUIREMENTS.md` directly above the Q1 note, where a Phase 9 planner reading requirements
will hit it. **This is Phase 9's debt, not Phase 2's** — nothing about it belongs to this phase.

### 2. The monotonic-BPM artefact inventory

SEQ-03 went bidirectional (`|Δ| ≤ tolerance`, either direction; the non-decreasing rule is
gone). Six Act I artefacts still assert the old rule. Per the standing instruction these are
**flagged for Phase 9, not fixed here** — and `Sequencing/` is provably untouched, so Phase 9
rewrites from a clean Phase 1 baseline. The inventory is now in `REQUIREMENTS.md` so Phase 9
does not have to re-derive it:

| Artefact | What it asserts |
|---|---|
| `Sequencing/BeamSearchSequencer.swift:81` | sorted-ascending is a topological order of the "non-decreasing" DAG |
| `Domain/SequenceResult.swift:15` | `sequence` is "non-decreasing BPM" |
| `Tests/…/BeamSearchSequencerTests.swift:30` | test *"BPM is non-decreasing across the whole winning sequence"* — **currently green, and wrong** |
| `Tests/…/BPMRulesTests.swift:33` | "D2: non-decreasing AND within tolerance" |
| `Fixtures/NaiveBPMSortSequencer.swift:2` | stub sorts ascending by design |
| `ROADMAP.md:385` | Definition of Done says "a sequenced set with ascending BPM" |

## The `02-smoke-crate-list.png` call — mine to make, and I changed the reason

02-04's plan said delete it; 02-04 kept it on the grounds that *"02-02-SUMMARY names it as
02-05's luminance baseline"*.

**I am 02-05, and that reason turned out to be wrong.** I never used it as a baseline. I did not
need one: each of the fifteen walk frames carries its own `min 0 / max 255` and
`02-walk-01-crate-list.png` covers the identical state at identical dimensions. A baseline
nobody uses is dead weight, and by 02-04's own stated rationale the file should now go.

**Kept anyway, for a better reason.** It is `SmokeUITests`' only artefact. `02-walk-01` is
`CrateWalkUITests`' artefact. Two tests, two photographs — and `SmokeUITests` rewrites this one
on every run, so deleting it from `Artifacts/` does not produce a clean tree, it produces an
untracked file on the next `collect-screenshots.sh`. Churn, not hygiene. It is committed fresh
from this run rather than `git checkout`-ed back, so it is genuinely tonight's evidence.

## Deviations from Plan

### 1. [Deliberate] The screenshots were re-captured and re-committed, not reused

The plan's Task 1 Step 1 says "re-run the probe over the whole set". Task 2's ship-criterion
audit separately requires running `./Scripts/ui-test.sh`. Running the UI test **regenerates**
the fifteen PNGs, so the two tasks cannot both be satisfied against 02-04's committed bytes.

I purged the host glob first (per `collect-screenshots.sh`'s own documented hazard), re-ran,
re-collected, and **committed my own fifteen**. The audit table, every finding and every
evidence path in `VISUAL-DEFECTS.md` therefore cite pixels I actually looked at, and a reader
re-running the probe against the committed files will reproduce my numbers rather than 02-04's.
The two runs agree to ±0.06 mean, so nothing was lost by the swap. `02-smoke-crate-list.png`
likewise — see the section above.

### 2. [Reported, not fixed] The `XXX` gate does not exit 1

The plan's Task 2 `<automated>` verify block opens with
`! grep -rn "TODO\|FIXME\|XXX" …`, which fails on `mktemp`'s mandatory `XXXXXX` template. Per
the constraint *"do not weaken a gate to make it pass"*, I did **not** pipe it through
`grep -v mktemp` and did **not** narrow the pattern. The hit is stated in full, in this summary
and in `deferred-items.md` as `D-02-05-2`, with the reason it cannot be removed and the option
left open for Phase 4. `TODO` and `FIXME` — the markers the criterion is actually about — are
genuinely absent, `rc=1`.

## Requirements

All nine of Phase 2's requirements landed and are visible in the committed photographs. None
were ticked that are not true; the audit in fact **un-ticked** one that was falsely counted
(`SEQ-03`, which belongs to Phase 9 and is reopened).

| Requirement | Where it is visible |
|---|---|
| CRATE-01 | `02-walk-01`, `-14`, `-15` |
| CRATE-02 | `02-walk-02`, `-03` |
| CRATE-03 | `02-walk-05`, `-06` |
| CRATE-04 | `02-walk-09` (Custom order + Restore), `-10` (restored) |
| CRATE-05 | `02-walk-11` — Add More lands on **Friday Warehouse**, the same crate |
| CRATE-06 | `02-walk-12` (2 rows → 1, 4 records → 3), `-14`, `-15` |
| CRATE-07 | `02-walk-13` — the shared vinyl reads `The Hidden Camera` here, `Ni Ten Ichi Ryu` there |
| SEQ-07 | `02-walk-06` (collapsed), `-07` (expanded, each row carrying its reason) |
| SEQ-11 | `02-walk-06`, `-13` — `170`/`5A`, `172`/`8A`, `174`/`9A`, none the placeholder |

## Known Stubs

- **`CapturePlaceholderView`** — Phase 1 scaffolding, doc comment correctly names Phase 3 as its
  replacement, recorded as V8 (informational). Its one consequence is `D-02-04-1`: walk states 3
  and 4 are byte-identical because the screen shows nothing reflecting crate contents. **Confirmed
  independently on my run** (md5 `6a903ce3` for both). State 4's photograph is therefore not
  independent evidence; the vinyl's arrival is proven by state 5, where the new crate's detail
  shows `1 · Fixture Artist — Fixture Track · 174 · 5A`.
- **`NaiveBPMSortSequencer`** — dead, one self-reference only. Deliberately retained; Phase 11
  owns stub deletion, Phase 4 should re-confirm. `D-02-05-1`.

Neither prevents Phase 2's goal being achieved, and neither was introduced by this plan.

## Ship-criterion verdict for Act I Phase 2

**MET.** The criterion is: *an XCUITest walks list → create → capture → detail → reorder → add
more → remove vinyl → delete crate without a single stub throwing, and every one of those
states is screenshotted after a settle delay.*

- the walk runs unattended and green — `** TEST SUCCEEDED **`, 2 passed / 0 failed, **three
  runs across two plans**
- no stub threw in any run
- fifteen states, fifteen settle-delayed photographs, all committed, **counted after purging
  the host glob**
- all fifteen probed: `SUSPECT: none`, on two independent runs
- all fifteen **looked at**, which is the part no probe can do, and which is what produced V3

## What FAILED

Stated plainly, since a clean report that hides its rough edges is worth nothing:

1. **The `XXX` half of the hygiene gate does not exit 1**, and I chose not to make it. See
   deviation 2. `TODO`/`FIXME` are genuinely clean.
2. **The requirement count in two committed planning documents was wrong**, and had been since
   the roadmap rebuild — simultaneously over-counting `SEQ-03` and under-counting CRATE-03/04/05.
   Two errors that happened to cancel to a plausible-looking 15/52 = 67, which is presumably why
   nobody caught it. Corrected to 17/50, with the recount command written beside the figure.
3. **V3 is a Medium defect shipping unfixed into Phase 3.** That is what the plan directs, and
   Phase 4 owns it, but the honest statement is that the not-included bucket currently cannot
   tell you which record it excluded. It is logged for the owner as U8 because the fix has two
   defensible shapes and picking between them is a product call, not a correctness one.
4. **V6 could not be assessed at all.** Double-digit index alignment is unverifiable from a
   fixture set that never exceeds two rows. Recorded as "not assessable" rather than guessed.

Nothing else. No test is red, no gate was weakened, no threshold or assertion was edited, and
neither `App/` nor `VinylSetBuilderCore/` was modified by this plan — because no measured defect
survived a settle delay, so nothing warranted restyling.

## Self-Check: PASSED

```
FOUND: .planning/VISUAL-DEFECTS.md          (V1 struck through; 8 "02-walk-" citations)
FOUND: .planning/REQUIREMENTS.md            (CRATE-03/04/05 -> "Complete — 02-01/02-03/02-04"; 17/50)
FOUND: .planning/ROADMAP.md                 (Phase 2 [x], 5 of 5, "5/5 | Complete | 2026-08-30")
FOUND: .planning/UAT-PENDING.md             (U8 added)
FOUND: .planning/phases/02-crate-screens-stubbed/deferred-items.md  (D-02-05-1/2/3)
FOUND: Artifacts/screenshots/02-walk-01..15  (15/15, committed from this plan's run)
FOUND: commit 69ef303  docs(02-05): close V1 with evidence, re-confirm V2 on the new screens...
FOUND: commit c92a536  docs(02-05): hygiene sweep clean, ship criterion audited...
```

Plan `must_haves.artifacts` verified: `.planning/VISUAL-DEFECTS.md` contains `V1`, and
`must_haves.key_links` verified: it cites `Artifacts/screenshots/` with the `02-walk-` pattern
on 8 lines, every defect row naming the specific screenshot that is its evidence — or an
explicit `none` with the reason, for V5 and V6.
