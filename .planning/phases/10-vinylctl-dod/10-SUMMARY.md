---
phase: 10
plan: 10
subsystem: vinylctl, SEQ-05, the final sweep
tags: [cli, sequencer, definition-of-done, hygiene]
requires: [09]
provides:
  - vinylctl, a macOS front end over the same VinylSetBuilderCore package and the same app adapters
  - Artifacts/vinylctl/sequence-baseline.{txt,json} — the pipeline's committed answer on the owner's twelve photographs
  - Scripts/vinylctl-vs-app.sh — the measured proof that both front ends produce the same set
  - SEQ-05, the BPM tolerance slider
  - .planning/phases/10-vinylctl-dod/DEFINITION-OF-DONE.md — MVP-SPEC §9 walked with verdicts
affects: [CrateRows, CrateStore, CrateDetailView, SleevePipeline, hygiene.sh, screenshot-audit.py]
tech-stack:
  added: []
  patterns:
    - one pipeline, two front ends — the CLI links Core and compiles the shipping app adapters, and declares no engine of its own
    - a structural check beside every empirical one, because the empirical one can be confounded by the live network
key-files:
  created:
    - Tools/vinylctl/main.swift
    - Scripts/vinylctl.sh
    - Scripts/vinylctl-vs-app.sh
    - UITests/SEQ05ToleranceUITests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/ToleranceTests.swift
    - .planning/phases/10-vinylctl-dod/DEFINITION-OF-DONE.md
    - Artifacts/vinylctl/sequence-baseline.txt
    - Artifacts/vinylctl/sequence-baseline.json
    - Artifacts/vinylctl/vs-app.txt
    - Artifacts/screenshots/10-seq05-tolerance-widened.png
    - Artifacts/screenshots/10-seq05-tolerance-tightened.png
  modified:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/CrateRows.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift
    - App/Views/CrateDetailView.swift
    - App/Resolution/SleevePipeline.swift
    - UITests/CaptureWalkUITests.swift
    - Scripts/hygiene.sh
    - Scripts/screenshot-audit.py
    - README.md
decisions:
  - SleevePipeline gained ONE parameter (the corpus URL, defaulting to the app's Bundle.main lookup) rather than the CLI rebuilding the two ladders — that parameter is the entire difference between the front ends
  - vinylctl sequences through CrateDetailModel.sequencerInput, not crate.allCandidates, because CRATE-07's pinning lives there and the two paths give different answers
  - V21 is fixed in CrateRows.make and NOT in the sequencer — the sequencer takes [Track] and cannot learn that a trackless vinyl exists
  - carried defects were re-pointed off phases the roadmap compression deleted; a carry to a phase that will never run is a carry to nowhere
metrics:
  duration: ~2h20m
  completed: 2026-08-30
---

# Phase 10 Plan 10: `vinylctl` & Definition of Done Summary

**`vinylctl sequence` runs the whole pipeline over the owner's twelve real photographs from a
terminal and produces the same set the app does — measured, not asserted — and finding that out
exposed a record the app had been silently dropping.**

## The measured acceptance gate

| # | Gate | Result |
|---|---|---|
| 1 | `vinylctl sequence` over all twelve, no crash, output committed | **MET.** `Artifacts/vinylctl/sequence-baseline.{txt,json}` |
| 2 | its sequence matches the app's on the same input | **MET. IDENTICAL** — same two rows, same tempos, same keys, same order, plus a structural check |
| 3 | SEQ-05 built and tested: 3–6 changes the set, default 4.0 | **MET.** 2 records at 4 → 3 at 6 → 2 at 3, driven through the real slider and photographed |
| 4 | every §9 item walked with an honest verdict | **MET.** 3 MET, 1 PARTIALLY MET, 1 NOT MET |
| 5 | `test.sh`, `hygiene.sh`, `ui-test.sh`, `build-app.sh` green | **MET.** 365 / 9 pass 0 fail / 10 of 10 / BUILD SUCCEEDED |

## `vinylctl`'s output on the twelve photographs

Committed at `Artifacts/vinylctl/sequence-baseline.txt`. Per record it prints the trusted OCR
readings, the extracted catalogue number, and the resolved identity **or the explicit reason it
failed**; then the set; then the bucket with V19's per-row terminal cause.

```
The set — 2 records, tolerance ±4
#   track                                  bpm     key
1   The Accidental Heroes — Elements       136     4B
2   Xstasia — Sweetness                    138.8   —
total Camelot distance across the set: 0

Not in the set (10)
Vinyl 1                        —      —   No SoundCloud upload matched
The Accidental Heroes — Dragstar (etc.)    …
Cause 4 Concern — High Down    160    —   No track within 4 BPM of the set
Vinyl 5                        —      —   No identity to look up
Vinyl 10                       —      —   No identity to look up
```

**What the twelve photographs actually yield, from the committed JSON:**

| | |
|---|---|
| records segmented to at least one track line | **11 of 12** |
| catalogue numbers recovered | **6 of 12 records** (and resolution on those is 6 of 6) |
| track lines given an artist AND a title | **17 of 21** |
| **track lines given a tempo** | **7 of 21** |
| track lines given a key | **1 of 21** |
| **records that made the set** | **2 of 12** |
| bucket rows reading `Vinyl N` rather than a name (V3) | **8 of 10** |

Five subcommands — `ocr`, `segment`, `resolve`, `analyze`, `sequence` — so any regression is
bisectable to one stage with no simulator. `ocr` and `segment` are fully offline.

## Does it match the app? **Yes — measured both ways**

`./Scripts/vinylctl-vs-app.sh` runs the same twelve through the CLI and through the app's live
XCUITest walk and diffs the running orders.

```
A  vinylctl        2 sequenced          B  the app's walk   2 sequenced
   1. The Accidental Heroes — Elements | 136   | 4B            1. (identical)
   2. Xstasia — Sweetness              | 138.8 | —             2. (identical)

VERDICT: IDENTICAL — 2 rows, same titles, same tempos, same keys, in the same order.
```

**A structural check runs beside it, because the empirical one can be confounded and this one
cannot.** Both halves call the live network minutes apart, so an identical result is strong but
not sufficient. The script also greps that both front ends reach the set through
`AsyncSequencer.sequence(candidates: …sequencerInput)` then `CrateRows.make`, both resolve
through `SleevePipeline.process`, and **the CLI declares no `BeamSearchSequencer`,
`TrackResolver` or `BPMLadder` of its own** — 7 of 7 ok.

The only difference between the two front ends is one parameter: `SleevePipeline.init` now takes
the corpus URL, defaulting to the app's own `Bundle.main` lookup, because a command-line tool has
no bundle to look in.

## What `vinylctl` found: **V21, a silently dropped record**

The first full run printed **a set of 2 above a bucket of 9 for twelve photographs.** One record
was in neither list.

`IMG_0507.HEIC` reads three price-sticker fragments — `cemenic`, `DrumBass`, `$ 10.003` — none of
which the SEG-03 noise filter keeps, so it segments to **zero** track lines. Root cause read from
source: `BeamSearchSequencer.sequence` takes `[Track]` and derives its vinyl list from the tracks
it is handed, so a vinyl with no tracks contributes nothing and is *structurally incapable* of
appearing in `notIncluded`. **The sequencer cannot be where this is fixed — it never learns the
record exists.**

Fixed in `CrateRows.make`, the one place a `SequenceResult` is projected against its crate and
therefore the only place that can see the discrepancy. Both front ends route through it, so one
guard covers the app and the CLI. Post-fix, on real data: **2 + 10 = 12** in the CLI, and
`Running order (2)` / `Not in the set (10)` in the app's own walk.

**This directly contradicted RES-01** — "a record is never silently dropped" — which had been
ticked complete for two phases. Three tests now assert it, including one pinning that the guard
does not resurrect a deleted vinyl on the way.

## SEQ-05 — the last small requirement

Every primitive already existed (`BPMRules.toleranceRange`, `clampTolerance`, and
`Crate.bpmTolerance` already threaded through the sequencer, `CrateRows` and SwiftData). What was
missing was a store mutator and a control.

- `CrateStore.setBPMTolerance(_:in:)` — clamped, unknown crate a no-op.
- A `Slider` in the running-order header, `in: 3...6, step: 0.5`, next to the count it changes.
  Re-derivation deferred to the end of the drag (the beam search is ~0.3 s); the caption tracks
  the thumb live so the control never feels detached.
- Measured through the real control on the fixture crate: **2 records at 4 → 3 at 6 (the excluded
  record rejoins) → 2 at 3**, with the bucket's own sentence following the slider to
  `No track within 3 BPM of the set`. Photographed in both directions.

**One thing this cost, and it is worth recording.** The first version of the Core test derived
its expectations from `crate.allCandidates` and predicted a set of three at the default. The walk
came back red at two. `CrateDetailModel.sequencerInput` applies CRATE-07's per-vinyl pinning, so
the crate offers the sequencer five tracks and the *screen* offers it four. **A test that measures
a path the app does not take is worse than no test**, and the UI walk is what caught it.

## The Definition of Done — 3 MET, 1 PARTIALLY MET, 1 NOT MET

Full walk with every number and command at
`.planning/phases/10-vinylctl-dod/DEFINITION-OF-DONE.md`.

| # | Item | Verdict |
|---|---|---|
| 1 | Create a crate, scan 20 vinyls without waiting | **MET on the simulator.** Shutter → tile `11–20 ms` over 12 presses, `9–35 ms` over 21; 12 of 12 tiles seen still `Reading` while the shutter stayed live; read latency `1046 → 960 ms` first-five against last-five. **The camera half is unproven** — U13 |
| 2 | Auto-resolves for most; hand-enter the rest under 15 s | **NOT MET on clause 1. MET on clause 2** |
| 3 | Tempo steps inside the tolerance, sensible harmonic neighbours | **PARTIALLY MET** |
| 4 | Add 5 more, re-optimise, incl. a previously excluded record rejoining | **MET**, three independent ways |
| 5 | Close, reopen, crate intact | **MET.** 730/730 lines, 0 differing, through `simctl terminate` |

### The three tensions, reported rather than papered over

**Item 2's "auto-resolves for most" — the real rate is 42%, not 83%.** The app auto-*names* 10 of
12 records; it auto-*resolves* **5 of 12** to a tempo, and tempo is what the sequencer gates on.
Tier-0 measured **0** on this collection (a house/techno corpus meeting a crate of jungle twelves
— predicted, not discovered). The catalogue rung is 6 of 6 but only 6 of 12 records carry a
readable catalogue number. And the artist+title rung **produces confident wrong answers that are
in the committed baseline where anyone can read them**: `fellowship` on a jungle white label
resolves to *Lizz Wright — Fellowship*, a jazz vocalist; `"SMADON MIND` to *Navene K — Mind*;
`Da Lick` to *Dirty Game Records — What da Lick Read?*. These are not failures the app knows
about — they are answers it believes.

**Item 2's 15 s — 13.3 s costed, 15.8 s wall, and typing-dominated.** 8 taps + 16 keystrokes +
1 sheet under a stated cost model (1.0 s a tap, 0.3 s a keystroke, 0.5 s a sheet). 16 keystrokes
is 4.8 s of the 13.3. A realistic ~32-character artist-plus-title is **9.6 s of keystrokes
alone**, leaving 5.4 s for every tap and the sheet together. The measured correction sits near
the top of what the budget can carry. The wall clock is over and is reported rather than hidden.

**Item 3's "ascending BPM" — retired, and the drift is reconciled.** MVP-SPEC §9 item 3 was
rewritten in commit `c73adf5` from *"with ascending BPM"* to *"whose consecutive tempo steps stay
inside the tolerance"*, because SEQ-03 went bidirectional on 2026-08-30. **The original wording is
not merely outdated, it is unsatisfiable by the current sequencer by design** — a backward step is
produced whenever the keys favour it, and `SequencerAdjacencyTests` pins a fixture whose uniquely
cheapest order opens with a step of exactly −4.0. Gate G8 fails the build if the retired rule
reappears. Reported against the current spec.

### And the finding no gate catches

The two records in the live set are at **136 and 138.8 BPM**, on a crate of jungle twelves that
run 160–180. Both tempos are almost certainly wrong — SoundCloud matches against the wrong
uploads, downstream of the confident-wrong-answer problem above. **The set obeys every rule it is
gated on and is still probably not a set the owner would play.** That is exactly UAT U4/U6, the
project's real success criterion, and nothing in this repository could ever have answered it.

## The final sweep

- **`hygiene.sh` G1 now sweeps `Tools/`**, which the roadmap's §14 criterion always named.
- **V21 filed and CLOSED** with both a defect route and a fix route.
- **Seven carried defects were re-pointed.** V3, V6, V9, V10, V11, V17 and V20 were carried to
  Phases 11, 12 and 14 — **none of which exists** after the roadmap compressed 14 phases into 10.
  A carry to a phase that will never run is a carry to nowhere. Each now names Phase 10 and a UAT
  item, and the re-pointing is written into the row rather than done silently.
- **`UAT-PENDING.md` is current.** U12 (the four defects carried past v1.0 with no phase left to
  own them) and U13 (CAP-04's device half, the last unticked requirement) filed.
- **The screenshot audit is green again** — Phase 9 left it at 3 orphans and 1 undeclared pair.
  The uncited frames are now cited by the §9 walk, where they are the evidence for items 4 and 5,
  and the PERS-01 before/after pair is declared `IDENTICAL` because the two frames being the same
  picture *is* the claim.
- **A README** anyone can follow to clone, test, build, run the app and run `vinylctl`.

## Deviations from Plan

### Auto-fixed

**1. [Rule 1 — Bug] V21: a record with no track lines was silently dropped**
- **Found during:** Task 2, on the first full `vinylctl sequence` run
- **Issue:** twelve photographs produced a set of 2 and a bucket of 9; `IMG_0507` was in neither
- **Fix:** `CrateRows.make` now accounts for every crate vinyl the `SequenceResult` did not name
- **Files:** `CrateRows.swift`, `CrateRowsTests.swift` (3 tests) — **Commit:** `e13633d`

**2. [Rule 3 — Blocking] `CaptureWalkUITests.resolvingRowCount` killed the cross-check**
- **Issue:** `allElementsBoundByIndex.filter` binds each element in a separate query while the
  list re-renders under it. Index 45 existed when the count was taken and not a frame later;
  XCTest raised *"Failed to get matching snapshot"* and killed the run 126 s in.
- **Fix:** `.matching(NSPredicate(…)).count` — one predicate is one snapshot — **Commit:** `10fb8b4`

**3. [Rule 1 — Bug] two screenshots shared one filename**
- **Issue:** both SEQ-05 states wrote to `10-seq05-tolerance-widened.png`; the second overwrote
  the first, so the committed frame was the *tightened* set under a name saying widened
- **Fix:** distinct names, re-run, re-collected, both looked at — **Commit:** `430d30b`

**4. [Rule 2 — Missing critical] the screenshot audit was red before this phase and is now green**
- Phase 9 left 3 orphan frames and 1 undeclared near-duplicate. Fixed by citing and declaring,
  not by widening a threshold — **Commit:** `430d30b`

### Not done, deliberately

**CAP-04's device half was not claimed.** `SleeveCamera.makeIfAvailable()` returns nil on every
simulator; memory and thermals cannot be observed on a machine sharing the Mac's envelope. It is
recorded as U13 and CAP-04 stays unticked. **66 of 67.**

**V3/U8 was not guessed.** Three phases have carried it rather than pick for the owner and this
one did too — even though the baseline now shows 8 of 10 bucket rows reading `Vinyl N`, which
makes it the common case rather than the edge case.

## What is open, and who owns it

| Item | Owner |
|---|---|
| **CAP-04** — 20 records on the device without memory growth or throttling | the owner, U13. The last unticked requirement |
| **V3 / U8** — the bucket names known records `Vinyl N` | the owner, unanswered since Phase 2 |
| **V11 / U11** — session count or crate total on the capture strip | the owner |
| **V6, V9, V17, V20** — four Low/Informational defects, adjudicated, no phase left | the owner, U12 |
| **V10 / U10, U2b, U2d** — anything needing a real camera | the owner + a device |
| **U1** — install on the physical iPhone | the owner (Xcode signed in, phone connected) |
| **U4 / U6** — is this a set you would actually play | **the owner. This is the project's actual success criterion and no phase could answer it** |

## What FAILED

Nothing was left broken. Three things went red during the phase and all three were fixed and are
recorded above as deviations 1–3. One thing is honestly **NOT MET** — §9 item 2's "auto-resolves
for most" — and it is a property of the records, not of the code: nine of the owner's twelve are
white labels and dubplates in no public database. The pipeline reads them, segments them, finds
6 of 6 catalogue numbers, asks four services in the right order and takes the first free answer,
and then there is no answer to take.

## Gates at the close

```
./Scripts/test.sh        365 tests, 2 suites, passed
./Scripts/hygiene.sh     9 pass, 0 fail
./Scripts/ui-test.sh     10 of 10, totalTestCount=10
./Scripts/build-app.sh   ** BUILD SUCCEEDED **
./Scripts/persistence-check.sh   0 fail
python3 Scripts/screenshot-audit.py   AUDIT PASSED — gates A, B and C green
./Scripts/vinylctl.sh sequence …      2 sequenced + 10 not included = 12
./Scripts/vinylctl-vs-app.sh          structural: same calls · empirical: identical
python3 Scripts/ledger-check.py       23 rows, 14 closed, 9 carried, 3 Medium-or-above open
```

**66 of 67 requirements. The one that remains needs the phone.**

## Filed by another process during this run — V22 and V23

**Four commits landed in this repository between `430d30b` and `a3cbc7d` that this executor did
not author** — `315150a`, `87f9846`, `1cec0f1`, `44d4694`. They carry no phase scope and were
not part of this plan. They file two new defects. They are reported rather than absorbed
silently, and they were **verified before being accepted**:

**V22 — REAL, and its diagnosis was WRONG.** The row claimed *"V19's root cause survives in
vinylctl, which is a separate front end and never received Phase 9's `NotIncludedRow` fix."*
The defect is real: `sequence-baseline.txt` prints `Cause 4 Concern — High Down  160  —` while
the `IMG_0503` block lists *High Down* at 116.1 and *Strange Nature* at 160. **The diagnosis is
false.** `vinylctl` is not a separate renderer — `main.swift:431-432` call
`model.apply(result)` then read `model.rows`, which is `CrateDetailModel` → `CrateRows.make`, the
identical path `CrateDetailView.load` takes, and `vinylctl-vs-app.sh` already gates structurally
on exactly that. The root cause is **in Core and hits both front ends**: Phase 9 bound `reason`,
`badges` and `trackID` to one representative candidate and left `label` bound to
`VinylEntry.label`, which selects the first `.resolved` candidate. Two selectors, one row.
Diagnosis corrected in the ledger by command, not by reading.

**Neither was fixed, and both refusals are Rule 4, not fatigue.** V22's obvious fix — bind the
label to the representative — **is U8's fix A**: on a record with candidates but none `.resolved`
it replaces `Vinyl N` with the candidate's own name, which is the exact product call the owner
has been asked to make since Phase 2. Fixing V22 answers U8 by side effect. V23 proposes changing
the **sequencer's objective** (tie-break on mean adjacent BPM delta before Camelot) at the close
of the milestone, with no way to evaluate the result except the owner's own ear. Both are carried
with the proposed fixes recorded verbatim so the owner can take either in minutes.

**Both were carried to "Phase 11", which does not exist** — the same defect this phase had
already fixed for seven other rows. Re-pointed to Phase 10 and a UAT item.

The ledger is consequently **23 rows, 14 closed, 9 carried, 3 Medium-or-above open**, not the
21/14/7/1 this summary's gate table was written against. Gate G9 is green either way; the count
is stated correctly here rather than left at the number that was true an hour earlier.

## Self-Check: PASSED

12 of 12 claimed files present on disk; 10 of 10 cited commit hashes resolve (the eight of this
phase, the plan commit, and `c73adf5`, the Phase 5 commit that rewrote MVP-SPEC §9 item 3).
All four gates re-run after the last code change: `test.sh` 365, `hygiene.sh` 9 pass 0 fail,
`build-app.sh` BUILD SUCCEEDED, `ui-test.sh` TEST SUCCEEDED with `totalTestCount=10`.
