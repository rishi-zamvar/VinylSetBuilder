---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 04-05-PLAN.md — VERDICT: REFUSED on gate S3; plan 04-06 required
last_updated: "2026-08-30T14:01:15.034Z"
last_activity: 2026-08-30
progress:
  total_phases: 14
  completed_phases: 3
  total_plans: 23
  completed_plans: 21
  percent: 91
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29) and .planning/ROADMAP.md (rebuilt 2026-08-30)

**Core value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

**Current focus:** Act I, Phase 4 — **STILL OPEN. Plan 04-05 returned the verdict REFUSED.**
All five planned plans delivered; the act-level gate S3 is red and plan **04-06** is required
before Act II opens. Phases 1, 2 and 3 are closed.

## The shape of the work

Three acts, strictly linear, no interleaving:

| Act | Phases | What it is | Act ship criterion |
|---|---|---|---|
| **I — The shell you can walk** | 1–4 | Every screen navigable in the simulator on stubbed fixture data | Committed settle-delay screenshots of every screen |
| **II — The engine, headless** | 5–9 | OCR → segmentation → identity → BPM/key → sequencing, pure and testable | A measured number per phase, never a green tick |
| **III — The wiring** | 10–14 | One stub swapped at a time, then persistence, manual entry, `vinylctl` | The app runs on real data; `vinylctl` prints a real sequenced set |

## Current Position

Act: I of III
Phase: 4 of 14 (Act I Sign-off — Every Screen, Photographed) — **IN PROGRESS. NOT COMPLETE.**
Plan: 5 of 5 delivered. **Next: 04-06 — close the refusal.**
Status: **VERDICT: REFUSED**, issued 2026-08-30 by plan 04-05 against the seven gates S1-S7 that
        `CONTEXT.md` fixed before plan 04-01 ran a single command. Full evidence in
        `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md`.

        **The gate that failed: S3.** `./Scripts/screenshots.sh` — the one command that
        regenerates the whole screenshot set from a purged host — exited **1 on two of the three
        clean runs** plan 04-05 made (run 1 rc=0, runs 2 and 3 rc=1). On both failures
        `Artifacts/screenshots/02-walk-09-detail-manual-order.png` came back photographing the
        **sequenced** order under a **Custom order** header: **22,142 differing pixels below
        y=150** against the committed frame, the same wrong state twice, the two anomalous frames
        differing from each other only inside the status-bar clock. 44 of 46 frames were
        content-identical to the committed set on both runs — one frame, exactly the reorder
        frame.

        **Root cause, confirmed three ways, filed as ledger row V18 (Low, CARRIED to 04-06).**
        (1) `CrateDetailModel.moveRows` writes `crate.manualOrder` for any in-range offsets
        including an identity move, `moved()` returns the array unchanged, and `orderingMode` is
        `.manual` whenever `manualOrder != nil` — so a drag landing on the row boundary renders
        *Custom order* + *Restore* over the sequencer's own order. (2) The committed
        `ManualOrderTests.swift:194` already documents it: it asserts an identity move leaves the
        displayed order alone and **omits** the `manualOrder == nil` assertion it makes three
        lines earlier for the out-of-range case. (3) The photograph, on two independent runs.

        **The walk could not see it.** `reorderTookEffect()` asks whether
        `restore-sequenced-order-button` **exists**; step 9 asserts only that the header changed.
        Neither looks at the row order. The UI suite reported **7 passed / 0 failed** from the log
        **and** from `build/ui.xcresult` on all three runs, printing identical
        `WALK DRAG RECIPE FIRED: 1` lines for two different outcomes. This is `CONTEXT.md`'s own
        mutation-J lesson repeating: a presence assertion standing where a measurement belongs.

        **The instrument that saw nothing.** Per-frame mean drift — one of 04-01's two
        "independent" localisers of V17 — measured **0.0346** on that frame between run 1 and
        run 2, well inside the stated ±0.06 bar, while 22,142 content pixels changed. A mean
        cannot see a permutation. Do not use the drift bar alone as a regeneration check.

        **Everything else held, on three runs each:** `./Scripts/test.sh` **171 green**;
        `./Scripts/build-app.sh` **BUILD SUCCEEDED**; UI suite **7 passed / 0 failed** from log
        and result bundle; `./Scripts/hygiene.sh` **9 pass, 0 fail**;
        `python3 Scripts/ledger-check.py` rc=0; `probe-frames.py --check` `SUSPECT: none (46)`;
        the audit green on the committed set. S1, S2, S4, S5, S6 and S7 all hold.

        **The two criteria, reported separately.** The **act** criterion (committed settle-delay
        screenshots of every screen) is **MET** — 18 covered flow rows, 0 uncovered, the settle
        living in one place at 3.0s/4.0s. The **phase** criterion is **NOT MET**: clause 1 MET,
        **clause 2 NOT MET** (2 Medium-or-above rows open — V3 blocked on the owner's unanswered
        U8, V12 owned by Phase 6's SEG-03 filter), clause 3 MET (`TODO`/`FIXME` rc=1).

        **All 46 committed frames were opened and read**, none sampled, none skipped.
        Nothing visible in them is not already a V-row.
Last activity: 2026-08-30

Progress: [█████████░] 91%

21 of the 23 plans on disk have summaries. The two that do not are **not** pending work:

- `01-05-PLAN.md` — **never executed.** `AsyncSequencer` and `BeamDivergenceCheck` do not
  exist, so SEQ-08/09/10 are wholly outstanding and Phase 9 inherits this plan's content.
  Re-confirmed three times tonight by hygiene gate G4 (`rc=1`, no hits).

- `01-08-PLAN.md` — **superseded, not skipped.** Its CRATE-03/04/05 content was delivered by
  02-01 (`CrateDetailModel`) and 02-03 (`CrateDetailView`); its SEQ-05 tolerance slider moved
  to Phase 9 by decision D2-4.

**Requirements:** 67 total, 67 mapped, **23 complete, 44 outstanding**.

> **Re-derived at Phase 4 close (plan 04-05) by EIGHT commands that had to agree — not copied
> from anywhere, including from this file's previous figure:**
>
> ```
> grep -c "^- \[x\] \*\*"  .planning/REQUIREMENTS.md            ->  23   complete
> grep -c "^- \[ \] \*\*"  .planning/REQUIREMENTS.md            ->  44   outstanding
> grep -cE "^- \[.\] \*\*" .planning/REQUIREMENTS.md            ->  67   total
> ... | sort -u | wc -l                                            ->  67   distinct IDs
> ... | sort | uniq -d                                             ->  (empty)
> ```
>
> Plus: the traceability table has **67** rows; the ROADMAP phase table sums to **67** with no
> duplicates; the set difference between the checkbox list and the traceability table is **empty
> in both directions**; and — an extra check nobody asked for — the phase assignment per
> requirement agrees between ROADMAP and traceability for all 67. `hygiene.sh` G7 agrees.
> Nothing in `REQUIREMENTS.md` needed correcting.
>
> `SEQ-03` is still **REOPENED** and still not counted. `./Scripts/test.sh` printed, on all three
> runs tonight, a green line reading *"[STALE — retired spec, Phase 9 replaces] BPM is
> non-decreasing across the whole winning sequence"*. That test passes and is **wrong**.
> Phase 9's.
>
> One stale figure was found and annotated rather than deleted: `ROADMAP.md`'s sequencer
> amendment ends *"Requirements complete drops from 15 to 14"* — correct when written, three
> counts ago.

## What already exists — 113 tests green, committed

Do not re-plan this. It is TDD'd and on disk.

| Built | Requirements | Phase it now belongs to |
|---|---|---|
| `VinylSetBuilderCore` SPM package + `CorePurityTests` guard (build fails if Core imports AVFoundation/Vision/UIKit/AppKit/SwiftUI/SwiftData or mentions URLSession) | SETUP-02, SETUP-04 | 1 |
| XcodeGen app target (iOS 26), build-time gitignored `Secrets.swift`, `Scripts/test.sh`, `Scripts/build-app.sh` | SETUP-01, SETUP-03 | 1 |
| `CrateStore`, `FixtureCrates`, crate list/create/delete, multi-crate selection | CRATE-01, CRATE-02, CRATE-06, CRATE-07 | 2 |
| `TrackBadges`, `CrateRows` (single not-included bucket) | SEQ-07, SEQ-11 | 2 |
| `Camelot` + `BPMRules`, ported from the owner's own Python | SEQ-01 | 9 |
| `BeamSearchSequencer` width 50, `Set<UUID>` one-track-per-vinyl | SEQ-02, SEQ-03, SEQ-04, SEQ-06 | 9 |

## Performance Metrics

**Velocity:**

- Total plans completed: 5 (4 under the previous roadmap's Phase 1, plus 02-01)
- Average duration: ~20 min
- Total execution time: ~2 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 (old 01-01) | 1 | 2 min | 2 min |
| 1 (old 01-02) | 1 | 20 min | 20 min |
| 9 (old 01-03) | 1 | 12 min | 12 min |
| 9 (old 01-04) | 1 | 10 min | 10 min |
| 2 (old 01-06) | 1 | 35 min | 35 min |
| 2 (old 01-07) | 1 | 8 min | 8 min |
| 2 (02-01) | 1 | 35 min | 35 min |

*Plan numbering restarts under the new phase structure. The old `01-0x` plans are preserved
in `.planning/phases/01-foundation-domain-model-sequencer/` as the record of what was built.*
| Phase 02-crate-screens-stubbed P02 | 25m | 2 tasks | 6 files |
| Phase 02 P03 | 55 min | 2 tasks | 5 files |
| Phase 02 P04 | ~50 min | 2 tasks | 18 files |
| Phase 02-crate-screens-stubbed P05 | 35m | 2 tasks | 22 files |
| Phase 03 P02 | ~50 min | 2 tasks | 4 files |
| Phase 03 P01 | ~40 min | 3 tasks | 12 files |
| Phase 03 P03 | 47min | 3 tasks | 9 files |
| Phase 03 P04 | 48 | 2 tasks | 5 files |
| Phase 03 P05 | ~95 min | 2 tasks | 40 files |
| Phase 04 P02 | 25m | 3 tasks | 5 files |
| Phase 04 P01 | 37m | 3 tasks | 5 files |
| Phase 04 P03 | 61 | 3 tasks | 13 files |
| Phase 04-act-i-signoff P04 | 24m | 3 tasks | 4 files |
| Phase 04-act-i-signoff P05 | ~90m | 3 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Roadmap-level decisions:

- [Roadmap rebuild, 2026-08-30]: **Three strictly linear acts** — shell, then engine, then
  wiring. The previous roadmap's "no wiring phase needed, it's a natural consequence" claim
  was replaced by an explicit swap phase (11) that substitutes one stub at a time.

- [Roadmap rebuild]: **The sequencer moved out of Phase 1 into Act II Phase 9**, where the
  engine belongs. Its already-built parts are marked complete there rather than re-planned.

- [Roadmap rebuild]: **CAP split across acts.** CAP-02/03/05/06 are screens (Act I, Phase 3);
  CAP-01 and CAP-04 are live-camera behaviours (Act III, Phase 10). The simulator has no
  camera, so putting them in Act I would put an unverifiable criterion in Act I.

- [Roadmap rebuild]: **Manual entry stays in Act III** per the owner's own act structure, so
  its sheet is the one screen Act I does not build. Recorded as a decision, not a gap.

- [Roadmap rebuild]: **14 phases against a `standard` granularity band of 5–8.** Deliberate.
  Compressing would mean merging engine capabilities (losing per-capability measured gates)
  or interleaving acts (losing the throughline). Time is not a constraint.

- [Roadmap rebuild]: **Every phase closes on a measured number**, never "tests pass". Every
  UI-bearing phase commits screenshots taken after a settle delay.

- [Phase 1]: `VinylSetBuilderCore` — 7 domain value types, 3 protocol seams
  (`Sequencing`/`LabelSegmenting`/`MetadataResolving`), 2 fixture stubs, purity guard.

- [Phase 1]: `DEVELOPMENT_TEAM` recovered from the local Apple Development signing identity
  and set in `project.yml`; device-signed build succeeds end to end.

- [Phase 9 work already done]: Camelot distance = flat hop count + 1 for a letter change (D1,
  locked). `BPMRules.fold` applies `bpm < 100 → ×2` exactly once (D6, locked).

- [Phase 9 work already done]: `BeamSearchSequencer` distinguishes unresolved from
  tempo-excluded by whether ANY candidate has a BPM.

- [Phase 2 work already done]: `notIncluded` stays one array (D7) — no excluded/unresolved
  split in `CrateRows`. `TrackBadges` folds BPM via `BPMRules.fold` before formatting so the
  badge never contradicts the sequencer's ordering.

- [Phase 1]: `build-app.sh` passes explicit `SYMROOT`/`OBJROOT` so the app target reliably
  finds the local package's built module (was U7).

- [Phase 02]: Membership is the sequencer's, arrangement is the user's — a manual order survives a re-sequence filtered to survivors, newcomers append, one call restores (D2-1)
- [Phase 02]: moveRows hand-rolls the offset shift: SwiftUI's move(fromOffsets:toOffset:) is unreachable from Core under the D2-6 purity scan
- [Phase 02-crate-screens-stubbed]: Shared scheme declared in project.yml — xcodebuild's autocreated scheme has no test action and cannot run a UI test target
- [Phase 02-crate-screens-stubbed]: UI assertions match crate names only, never record-count strings — V1's rewording landed mid-run and would have broken a text-matching test
- [Phase 02]: EditButton() replaced by a plain Button — toolbar content is hosted outside the view's environment, so EditButton drove an edit binding the List never read
- [Phase 02]: A List's .onMove/.onDelete ForEach must not sit inside a conditional, or the List renders no reorder or delete affordances at all
- [Phase 02]: Accessibility identifiers are verified against the live tree with a throwaway probe, never assumed — it found three functional defects no unit test could reach
- [Phase 02]: 02-04: the crate walk asserts on frozen identifiers only; the one caption under test (ordering-mode-label) is captured before the act and asserted CHANGED, never hardcoded
- [Phase 02]: 02-04: container freshness re-measured across three runs — 02-02 was right (fresh container per xcodebuild test); 02-03's persistence reading was the previous run's own output. The screenshot count gate must purge the HOST glob, which is the real hazard
- [Phase 02]: 02-05: every behavioural claim in the phase record now carries its sample count — nothing is asserted from one observation, after 02-03 and 02-04 both got container freshness wrong that way
- [Phase 02]: 02-05: V2's closure re-confirmed FUNCTIONALLY, not photometrically — the walk taps six controls and they all respond, and disabled content is not tappable, which no pixel measurement can match
- [Phase 02]: 02-05: the requirement count was wrong in BOTH directions (counted reopened SEQ-03, omitted CRATE-03/04/05) and the two errors cancelled to a plausible 15/52 — corrected to 17/50, recount command written beside the figure
- [Phase 02]: 02-05: the mktemp XXXXXX gate hit is reported, not filtered — narrowing the grep to manufacture a green exit code is exactly the gate-weakening the plan forbids
- [Phase 03]: SEG-07 splitLine splits at the word midpoint (odd counts favour the first line) — a marked ceiling; a character index is the upgrade path
- [Phase 03]: SegmentationDraft carries the tracks' Side through, so correcting a B-side read cannot republish it as A
- [Phase 03]: OCR-04 keeps the untrusted 0.50/0.30 reads — the discarded row is the evidence a bad read needs
- [Phase 03]: Trusted OCR count is 89 not 88 — 88/101 is the first spike run; Act I fixtures come from the second (104/89). OCR-SPIKE.md and Phase 3 CONTEXT.md corrected.
- [Phase 03]: FixturePhotoSource is an actor, not a struct — capture() advances a counter behind a Sendable protocol
- [Phase 03]: Capture screen holds no rules: framing-guide geometry derived from FramingGuide.sleeve, never retyped (measured 0.881 coverage on rendered pixels)
- [Phase 03]: Thumbnail status pill sits outside the tile's Button — a SwiftUI Button merges its label's children into one accessibility element and capture-thumb-status-{n} would vanish
- [Phase 03]: ScreenshotRecorder settle stays 3.0/4.0: raising to 4.0/5.0 was measured across 19 frames and changed nothing (V9 is not a timing artefact)
- [Phase 03]: 03-04: the raw-text frame is photographed on fixture 1, not fixture 6 — IMG_0503's 16 observations are ALL confidence 1.00, so it cannot show OCR-04's untrusted reads at all
- [Phase 03]: 03-04: commit a fix BEFORE mutating the file it lives in — reverting a mutation with git checkout also discards uncommitted work in that file
- [Phase 03]: 03-05: XCUITest's isHittable RAISES on an element scrolled off screen ("Activation point invalid"), it does not return false — reachability is asked of the geometry first (is the centre inside the window), and isHittable only after
- [Phase 03]: 03-05: a scroll-to-element loop must be BIDIRECTIONAL and momentum-free — fifteen one-directional slow swipes drove capture-thumb-5 from off the right edge to x=-516 off the left; the fix is a bounded drag held at the end
- [Phase 03]: 03-05: CAP-03's "scrolls past 20 without layout breaking" is measured by TILE WIDTH at 1 item vs 21, not by a count — mutation J shrank the tiles to 41pt and every count and existence assertion still passed
- [Phase 03]: 03-05: the two sheet frames are taken on fixtures 5 and 8, not on one fixture, because those are the only two carrying the corpus's longest trusted read (44 chars) and its longest read overall (106 chars) — the frames that make V13 answerable
- [Phase 03]: 03-05: V9 narrowed to a repro — every frame with a large navigation title was taken before any .sheet was presented, every frame without one after; 33 of 33 frames obey it across three runs
- [Phase 03]: 03-05: V3's second sighting was obtained by EXPANDING the not-included bucket, which 03-03 was forbidden to do; the walk photographs it and prints the labels but asserts nothing about them, so Phase 4's fix does not have to edit a test
- [Phase 04]: 04-02: monotonic-BPM artefact count corrected to 17 (ledger said 'five places', table listed six); BPMRules.swift:17 `b >= a` is the retired rule as executable code, findable only by a structural pass
- [Phase 04]: 04-02: THREE green assertions defend the retired BPM rule, not two — test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending carries no STALE marker. Phase 9 rewrites three
- [Phase 04]: 04-02: MetadataResolving kept with zero references — a declared seam Phase 7 (RES-01..08) implements, allowlisted in hygiene.sh G5 with its phase named
- [Phase 04]: Gate B's whole-frame pixel fraction is a candidate generator, not a decider — declared duplicates carry a kind (IDENTICAL collapses the state count, DISTINCT does not)
- [Phase 04]: sim-settled-crate-list.png deleted as the one orphan; 01-06-crate-list.png carries the same unfixed '1 records' state and is cited twice
- [Phase 04]: V4 closed on WCAG 2.2 AA (4.01:1 -> 7.96:1); the plan's own contrast>=60 gate measured 125 on the defective badge and is reported as unable to have caught it — the threshold was NOT moved
- [Phase 04]: V9's two-phase-old rule ('a sheet removes the title') is FALSE. The measured rule: the title is lost iff the FIRST route change of the session comes from the sheet's Create. Carried to Phase 11 with H1/H2/H3 rejected at 0/11746 each
- [Phase 04-act-i-signoff]: A CLOSED defect row must cite a re-runnable route to the DEFECT as well as to the fix; V1 and V8 gained photographs of their own defects (04-04)
- [Phase 04-act-i-signoff]: V17 filed as a seventeenth ledger row from 04-01's Finding 3 — the crate walk's run-to-run state instability, carried to Phase 11 (04-04)
- [Phase 04]: 04-05: **VERDICT REFUSED on gate S3** — screenshots.sh exited 1 on 2 of 3 clean runs. The rules were fixed in CONTEXT.md before 04-01 ran; no gate was narrowed, filtered or re-thresholded to reach a different one. Every threshold in the project appears exactly once in git history as an addition and was never edited — checked by command, not asserted
- [Phase 04]: 04-05: V18 filed — CrateDetailModel.moveRows commits a manual order for an IDENTITY move, so a boundary drag renders 'Custom order' + Restore over the sequencer's own order; the walk's reorderTookEffect() only checks a button EXISTS. Carried to 04-06, not fixed here: this plan touches no code
- [Phase 04]: 04-05: the per-frame mean-drift bar (±0.06) is BLIND to a row permutation — 0.0346 on a frame with 22,142 changed content pixels. 04-01's 'two independent measurements' claim is weaker than it reads; only the pixel-fraction gate caught this
- [Phase 04]: 04-05: D-04-1 through D-04-5 all held under the verdict — V3 was not guessed at, V6 was not manufactured, the probe is committed, and every screenshot is classified rather than merely counted
- [Phase 04]: 04-05: the act criterion and the phase criterion are reported SEPARATELY and reach different answers — act MET, phase NOT MET on clause 2. Conflating them would have been the exact dishonesty the phase exists to prevent
- [Phase 04]: 04-05: two of the 46 committed frames (04-badge-*.png) are element crops taken WITHOUT the settle delay; zero Gate A flow rows cite either, so no screen's coverage depends on them. Stated rather than glossed
- [Phase 04]: 04-05: NC-Z — the ui-test.sh zero-test guard was itself shown able to fail (totalTestCount=0 -> rc=1). It had never been proved red since 04-03 added it

### Pending Todos

- Re-file the interrupted WIP test `.planning/open-questions/RejoinTests.swift.wip` as a
  proper seeded-shuffle determinism test when Phase 9 opens.

### Blockers/Concerns

- **THE REFUSAL — S3 is red and Act I is not signed off.** `./Scripts/screenshots.sh` exited 1 on
  2 of 3 clean runs (04-05). `02-walk-09-detail-manual-order.png` regenerates as the SEQUENCED
  order under a *Custom order* header, 22,142 content pixels off the committed frame, the same
  wrong state twice. Root cause **V18**. **Plan 04-06 closes it**: an identity guard on
  `CrateDetailModel.moveRows`, and a row-order assertion replacing `reorderTookEffect()`'s
  presence check, then three clean regenerations at rc=0. **Act II does not open before that.**

- **CRATE-04 is ticked complete, and its UI evidence is weaker than the tick implies.** The frame
  that photographs it is the frame that came back wrong twice tonight. The model is demonstrably
  correct (run 1, the committed frame, and `ManualOrderTests`), so the tick was NOT removed —
  plan 04-05 may not tick or untick any requirement — but 04-06 must re-establish the evidence
  rather than assume it.

- **A green UI suite is not evidence that the right screen was photographed.** 7 passed / 0 failed
  from the log AND from `build/ui.xcresult`, three runs, two of which photographed a wrong state.
  Verifying from the result bundle closed the *zero-tests* hazard; it does not close this one.
  Only a measurement of the content can.

- **V3 — the not-included bucket cannot tell you which record it excluded.** It labels the row
  `Vinyl 2` while showing that record's real `178` / `6A` badges and the reason "No track within
  4 BPM of the set". The app can name that track `Dillinja — Angels Fell`. Root cause read from
  source: `VinylEntry.label` requires `resolutionState == .resolved` while `SequencedRow.title`
  uses `Track.displayName` which does not, and **no fixture `Track` ever sets `.resolved`**.
  Medium. Evidence `Artifacts/screenshots/02-walk-07-not-included-expanded.png`. Phase 4 owns
  the fix; the owner owns the call (U8 in `UAT-PENDING.md`) because it is defensibly either a
  code defect or a fixture defect.

- **SEQ-08 / SEQ-09 / SEQ-10 are wholly outstanding, and the Phase 1 record implies otherwise.**
  Plan 01-05 was never executed; `AsyncSequencer` and `BeamDivergenceCheck` do not exist on
  disk. Phase 9 inherits `01-05-PLAN.md` and `RejoinTests.swift.wip`. **This is Phase 9 debt,
  not Phase 2 debt.**

- **Six Act I artefacts still assert the removed non-decreasing BPM rule** (SEQ-03 went
  bidirectional 2026-08-30), including a currently-green test named *"BPM is non-decreasing
  across the whole winning sequence"*. Deliberately NOT fixed in Phase 2 — `Sequencing/` is
  provably untouched since `59e2f3c feat(01-04)`, so Phase 9 rewrites from a clean baseline.
  Full inventory in `REQUIREMENTS.md`.

- **Q1 — the sequencer may be order-dependent.** The beam's rank tuple ends in
  `start-index asc`, derived from array position, so a shuffle can change which equal-ranked
  states survive pruning. Because the sequencer re-runs on every vinyl added, this would
  produce *different sets from the same records*. **Phase 9 must answer this**, and if
  confirmed, fix it by making the rank tuple a total order with a position-independent
  tiebreaker (the track UUID). See `.planning/open-questions/Q1-sequencer-determinism.md`.

- **V1 / V2 — CLOSED 2026-08-30 by plan 02-05.** V1 fixed and verified in
  `02-walk-01-crate-list.png` with a two-sided assertion; V2 was never a defect (launch fade)
  and its closure was re-confirmed on the four screens Phase 2 added, probed twice with
  `SUSPECT: `, plus a functional disproof — the walk taps six controls and they all
  respond, and disabled content is not tappable. **Phase 4 instead inherits V3 (Medium — the
  not-included bucket names a fully-known record "Vinyl 2") and V4–V7 (Low).** V3 needs the
  owner's call, logged as U8. Original wording, kept for the record:

- ~~**V1 / V2 — visual defects, open.**~~ "1 records" pluralisation, and the whole UI washed out
  to near-invisible grey. **V2 must first rule out a launch-fade screenshot artefact** by
  re-screenshotting after a settle delay, before any restyling; then check `.disabled(true)`
  on an enclosing view, because that would make it a functional bug wearing a cosmetic
  disguise. Both close in Phase 4. See `.planning/VISUAL-DEFECTS.md`.

- **Measured baselines that must not regress** (Act II gates are scored against these):
  - OCR: **6 clean / 5 partial / 1 fail** across the 12 fixtures — Phase 5.
  - Catalogue-number resolution: **5 of 6 correct** — Phase 7.
  - SoundCloud match rate: **72%** — Phase 8.

- **Phase 8 carries the largest remaining unknown.** The in-house Accelerate/vDSP analyser's
  tempo and key accuracy on bass-heavy jungle/DnB is unmeasured, and SoundCloud only ever
  returns a 30-second preview — ample for tempo, weaker for key. Gate B scores it against the
  29 cached ground-truth tracks in `.local/`. Documented fallback: key degrades to a
  soft/manual field while BPM stays automatic; the sequencer tolerates this because Camelot
  distance only orders survivors and never excludes.

- **Tier-0 hit rate is unmeasured.** The bundled 6,608-row corpus skews house/techno — only
  12% sits in the 160–184 BPM band. A low hit rate is an expected outcome, not a failure; it
  reallocates weight onto Phase 12 (manual entry).

- **Toolchain, non-negotiable.** iOS 26 is the installed SDK. `MusicUnderstanding.framework`
  does **not** exist on this machine — never import it. BPM/key come from the in-house
  Accelerate/vDSP analyser behind `AudioAnalyzing`. Simulator UDID
  `4B4E1C1F-BED6-4812-9238-C151337265DA` is installed and bootable.

- **Still needs the owner:** U1 (install on the physical iPhone 14 Pro — Xcode signed into the
  Apple ID, phone connected and trusted), U2 (live capture feel across 20 real records),
  U4/U6 (whether the produced set is one you would actually play — the project's real
  success criterion).

- V9: 13 of the walk's 15 frames render no large navigation title. Not settle (identical at 3.0s and 4.0s), not .disabled (every control taps), not caused by plan 03-03 — implicates RootView's Route-swap navigation. Filed for Phase 4.

## Session Continuity

Last session: 2026-08-30
Stopped at: Completed 04-05-PLAN.md — **VERDICT: REFUSED on gate S3**
Three independent clean runs of the full battery, from a purged host each time. 171 Core tests
green x3; device-SDK build SUCCEEDED x3; UI suite 7 passed / 0 failed from log AND result bundle
x3; hygiene 9 pass / 0 fail x3; ledger-check rc=0 x3; probe `SUSPECT: none (46 frames)` x3.
`./Scripts/screenshots.sh` rc=0 / **rc=1** / **rc=1**. All 46 committed frames opened and read.
Requirement count re-derived by eight commands that agreed at 23 / 44 / 67 / 67, nothing to
correct. V18 filed; ledger now 18 rows, 8 closed, 10 carried, 2 Medium-or-above open.
Next: **04-06 — close the refusal.** Do not open Act II first.
Resume file: `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md`
