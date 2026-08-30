---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: V4 and V5 are CLOSED with re-runnable evidence; V9's rule was DISPROVED and carried.
stopped_at: Completed 04-03-PLAN.md — V4 and V5 closed with measurements; V9's rule disproved and carried to Phase 11
last_updated: "2026-08-30T13:38:46.188Z"
last_activity: 2026-08-30
progress:
  total_phases: 14
  completed_phases: 2
  total_plans: 23
  completed_plans: 19
  percent: 83
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29) and .planning/ROADMAP.md (rebuilt 2026-08-30)

**Core value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

**Current focus:** Act I, Phase 4 — Act I Sign-off. Phases 1, 2 and 3 are closed. Every screen
the shell has is photographed; what Phase 4 owns is the act-level audit (screenshot count equals
screen count, zero Medium-or-above defects still open, zero TODO/FIXME) and the V-defect backlog
Phases 2 and 3 recorded but were forbidden to fix.

## The shape of the work

Three acts, strictly linear, no interleaving:

| Act | Phases | What it is | Act ship criterion |
|---|---|---|---|
| **I — The shell you can walk** | 1–4 | Every screen navigable in the simulator on stubbed fixture data | Committed settle-delay screenshots of every screen |
| **II — The engine, headless** | 5–9 | OCR → segmentation → identity → BPM/key → sequencing, pure and testable | A measured number per phase, never a green tick |
| **III — The wiring** | 10–14 | One stub swapped at a time, then persistence, manual entry, `vinylctl` | The app runs on real data; `vinylctl` prints a real sequenced set |

## Current Position

Act: I of III
Phase: 4 of 14 (Act I Sign-off — Every Screen, Photographed) — IN PROGRESS
Plan: 04-03 complete (3 of 5). Next: **04-04 — adjudicate the defect ledger row by row.**
Status: V4 and V5 are CLOSED with re-runnable evidence; V9's rule was DISPROVED and carried.
        **V4** — the placeholder badge pair measured **4.01:1** against WCAG 2.2 AA's 4.5:1 for
        12 pt text and now measures **7.96:1**, with the complete pair still strictly ahead at
        18.27:1, so SEQ-11's *dimmed, never hidden* holds on both halves. Measured twice before
        and three times after, and by TWO independent implementations (an in-test Swift histogram
        and `probe-frames.py --ink 128`) that return the same integers. **The plan's own
        `contrast >= 60` gate measured 125 on the DEFECTIVE badge — it could never have caught
        V4. The threshold was kept where it was set and the failure of the gate is reported, not
        hidden.** Two mutations reddened the two halves at their named lines, xcresult-confirmed.
        **V5** — `unresolvedVinyl` moved off `position: 2`; label AND position uniqueness now
        assert across every crate in the new `FixtureCrates.all`, which `demoStore` is built from
        so the two lists cannot drift. Red before the fix and red under the restored duplicate,
        naming `["Vinyl 3"]` and `[2]`.
        **V9 — the rule this row carried for two phases is WRONG.** Reproduced deliberately for
        the first time: present-and-cancel returns two BYTE-IDENTICAL frames, ink 9677 both. A
        seven-frame bisection kept every title. A two-session A/B isolated the real rule, four
        times without variation: **the title is lost for the session iff the FIRST route change
        is the one driven from inside the sheet's Create** (A=0, B=11746). That also explains the
        33-frame split — CaptureWalk test 1 enters Create-first and reads 0, test 2 enters via
        Add More and reads 11746, same class, same build. Three fixes tried and all REJECTED by
        measurement (H3 forced `.large`, H1 hoisted `.navigationTitle`, H2 removed the sheet's
        nested `NavigationStack` — 0/11746 every time), all reverted; `RootView` carries no
        change. **V9 carried to Phase 11** with its repro and its three dead ends written down.
        171 Core tests green (168 + 3); 7 UI tests green from the log AND `build/ui.xcresult`;
        device-SDK build green; hygiene 8 pass / 0 fail; audit green — 46 files, 44 distinct
        states, 0 orphan. 8 frames changed materially and they are exactly the 8 that render a
        badge pair; 26 changed only in the simulator clock, measured below y=150.
        **Hazard found: `ui-test.sh` exited 0 having run ZERO tests, twice, on the first
        invocation after a UI-test file was edited. A green rc from it is not evidence that
        anything ran — read `passedTests` from the result bundle.**
Last activity: 2026-08-30

Progress: [████████░░] 83%

16 of the 18 plans on disk have summaries. The two that do not are **not** pending work:

- `01-05-PLAN.md` — **never executed.** `AsyncSequencer` and `BeamDivergenceCheck` do not
  exist, so SEQ-08/09/10 are wholly outstanding and Phase 9 inherits this plan's content.
  This is the one real gap between the Phase 1 record and what is on disk.

- `01-08-PLAN.md` — **superseded, not skipped.** Its CRATE-03/04/05 content was delivered by
  02-01 (`CrateDetailModel`) and 02-03 (`CrateDetailView`); its SEQ-05 tolerance slider moved
  to Phase 9 by decision D2-4. Nothing from it is missing except SEQ-05, which is tracked
  there.

**Requirements:** 67 total, 67 mapped, **23 complete, 44 outstanding**.

> **Recounted by command at Phase 3 close (03-05), from the ticked boxes and not by
> incrementing the previous figure:**
>
> ```
> grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md   ->  23
> grep -c "^- \[ \] \*\*" .planning/REQUIREMENTS.md   ->  44        23 + 44 = 67
> ```
>
> Phase 3 contributed all six of its requirements: OCR-04 and SEG-07 (03-02's Core, 03-04's
> sheet), CAP-02/03/05/06 (03-01's Core, 03-03's screen), every one of them re-verified in one
> twelve-fixture session by 03-05. The figure of 17 that stood before Phase 3 was plan 02-05's
> and was correct when written.
>
> `SEQ-03` is still **REOPENED** and is still not counted. `./Scripts/test.sh` prints a green
> line reading *"BPM is non-decreasing across the whole winning sequence"* — that test is
> passing and **wrong**, because the rule went bidirectional on 2026-08-30. Phase 9's.

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

### Pending Todos

- Re-file the interrupted WIP test `.planning/open-questions/RejoinTests.swift.wip` as a
  proper seeded-shuffle determinism test when Phase 9 opens.

### Blockers/Concerns

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

Last session: 2026-08-30T13:38:12.439Z
Stopped at: Completed 04-03-PLAN.md — V4 and V5 closed with measurements; V9's rule disproved and carried to Phase 11
113 unit + 2 UI tests green; all four ship-criterion gates exit 0; 15/15 screenshots committed
after purging the host glob first; V1 and V2 closed with evidence; six new visual findings
recorded (V3 Medium, V4-V7 Low, V8 informational); requirement count corrected 15 -> 17.
Next: Phase 3 — The Capture & Correction Screens, Stubbed.
Resume file: None
