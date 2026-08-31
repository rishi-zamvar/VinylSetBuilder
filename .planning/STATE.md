---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: complete
stopped_at: "Completed 10-PLAN.md — vinylctl, SEQ-05, V21, MVP-SPEC section 9 walked; 66 of 67"
last_updated: "2026-08-31T02:20:00.000Z"
last_activity: 2026-08-30
progress:
  total_phases: 10
  completed_phases: 10
  total_plans: 30
  completed_plans: 28
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29) and .planning/ROADMAP.md (rebuilt 2026-08-30)

**Core value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

**Current focus:** Act III, Phase 9 — **Manual Entry & Persistence. DELIVERED 2026-08-30.**
Covers the roadmap's Phase 12 (Manual Entry) and Phase 13 (Persistence). Hand entry is now the
load-bearing path it was already being used as: **8 taps + 16 keystrokes + 1 sheet = 13.3 s** for
a full four-field correction under a stated cost model, measured twice. Crates survive being
killed with `simctl terminate`: **730/730 dump lines, 0 differing, 20 vinyls, 27 unselected
candidates and 12 `.manual` marks intact.** **V19 CLOSED** — the not-included bucket names the
terminal cause, with the invariant asserted in `CrateRows.make`. Suite 315 → 353; UI walk 7 → 9;
hygiene 9/9; requirements 55 → **65 of 67**.

## The shape of the work

Three acts, strictly linear, no interleaving:

| Act | Phases | What it is | Act ship criterion |
|---|---|---|---|
| **I — The shell you can walk** | 1–4 | Every screen navigable in the simulator on stubbed fixture data | Committed settle-delay screenshots of every screen |
| **II — The engine, headless** | 5–9 | OCR → segmentation → identity → BPM/key → sequencing, pure and testable | A measured number per phase, never a green tick |
| **III — The wiring** | 10–14 | One stub swapped at a time, then persistence, manual entry, `vinylctl` | The app runs on real data; `vinylctl` prints a real sequenced set |

## Current Position

Act: III of III — **COMPLETE**
Phase: 10 (`vinylctl` & Definition of Done) — **DELIVERED 2026-08-30. The last phase.**
Plan: 10, complete. See `.planning/phases/10-vinylctl-dod/10-SUMMARY.md` and
`.planning/phases/10-vinylctl-dod/DEFINITION-OF-DONE.md`.
Status: **`vinylctl sequence` runs the whole pipeline over the owner's twelve real photographs
from a terminal and produces the same set the app does — measured, not asserted.**

        `./Scripts/test.sh` **365** green · `./Scripts/hygiene.sh` **9 pass 0 fail** ·
        `./Scripts/ui-test.sh` **10 of 10** from totalTestCount · `./Scripts/build-app.sh`
        SUCCEEDED · `./Scripts/persistence-check.sh` 0 fail ·
        `python3 Scripts/screenshot-audit.py` AUDIT PASSED · **66 of 67 requirements.**

        **Plan counting, stated rather than left to look like a shortfall.** 28 SUMMARYs against
        30 PLANs. The two without one are `01-05-PLAN.md` and `01-08-PLAN.md`, both written under
        the pre-compression roadmap and **never executed**. `01-05`'s content (AsyncSequencer,
        BeamDivergenceCheck) was carried forward and delivered by Phase 5, and hygiene gate G4
        now fails the build if either disappears. All **ten** phases of the compressed roadmap
        are complete.

        **Gate 2, the one this phase existed for:** `./Scripts/vinylctl-vs-app.sh` runs the same
        twelve photographs through both front ends and reports **IDENTICAL** — same two rows,
        same tempos, same keys, same order — with a structural check beside it that both reach
        the set through `AsyncSequencer.sequence(candidates:…sequencerInput)` then
        `CrateRows.make`, and that the CLI declares no engine of its own.

        **What building it found: V21.** The first run printed a set of 2 above a bucket of 9 for
        TWELVE photographs. `IMG_0507` segments to zero track lines, and `BeamSearchSequencer`
        takes `[Track]` — a trackless vinyl is structurally incapable of appearing in
        `notIncluded`, so the record simply vanished, contradicting RES-01. Fixed in
        `CrateRows.make`, the one place a `SequenceResult` meets its crate. Post-fix: 2 + 10 = 12
        in the CLI, and `Running order (2)` / `Not in the set (10)` in the app's own walk.

        **MVP-SPEC §9, walked honestly: 3 MET, 1 PARTIALLY MET, 1 NOT MET.** Item 2's
        "auto-resolves for most" is **NOT MET** — the app auto-*names* 10 of 12 records and
        auto-*resolves* **5 of 12** to a tempo, which is what the sequencer gates on; tier-0
        measured **0** on this collection; and the artist+title rung produces confident wrong
        answers that are in the committed baseline (`fellowship` → *Lizz Wright — Fellowship*).
        Item 3 is **PARTIALLY MET**: the tolerance clause holds live, the harmonic clause is not
        assessable because **1 of 21** track lines came back with a key.

        **And the finding no gate catches:** the two records in the live set are at 136 and
        138.8 BPM on a crate of jungle twelves. The set obeys every rule it is gated on and is
        still probably not one the owner would play — UAT U4/U6, the project's real success
        criterion, which no assertion here could ever have answered.

        **The one outstanding requirement is CAP-04**, whose memory and thermal halves need a
        physical iPhone: `SleeveCamera.makeIfAvailable()` returns nil on every simulator, so not
        one line of the capture-device path has ever executed. Recorded as UAT **U13** and NOT
        claimed.

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
| Phase 04-act-i-signoff P06 | ~140 min | 6 tasks | 7 files |
| Phase 09 P09 | 2h40m | 8 tasks | 19 files |
| Phase 10 P10 | 2h20m | 6 tasks | 20 files |

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
- [Phase 04-act-i-signoff]: An identity drag PRESERVES an existing manual order rather than clearing it — both directions have their own test and their own mutation (V18)
- [Phase 04-act-i-signoff]: The walk normalises to edit mode ON after the drag loop, so the photographed state cannot depend on which drag recipe won
- [Phase 04-act-i-signoff]: The +/-0.06 mean-drift bar is never quoted alone again: probe-frames --drift reports a positional content-band count beside it

- [Phase 06]: OCR-02's transform lives in exactly ONE function and is deliberately NOT idempotent — a test asserts applying it twice differs, so a double application cannot pass unnoticed
- [Phase 06]: cap height is INVERTED from the axis-aligned box of rotated text, not taken as min(w,h) — DUBTRACK measures 0.061 that way against a true 0.026, and at 0.061 its two track lines merge. This single change is what lifted the pipeline off its floor
- [Phase 06]: a string read in two different angle clusters is the ARTIST or the LABEL, never a track — it is the sleeve and the record saying the same name, and fuzzily so (DRUMSOUND & vs RUMSOUND &)
- [Phase 06]: a record that names two or more sides has told you how many tracks it has, and that beats any geometry — it alone gets IMG_0499, IMG_0503 and IMG_0506 exactly right
- [Phase 06]: catalogue numbers need THREE letters minimum, not two — two would swallow JA22, which is IMG_0502's misread title. 6 of 6 recovered, 0 invented
- [Phase 06]: the trebled-character noise rule must be bounded to short strings — unbounded it ate AAA: Strange Nat ure, IMG_0503's own B-side, and cost a whole fixture
- [Phase 06]: VNRecognizeTextRequest kept over the Swift-native RecognizeTextRequest, against CLAUDE.md's stated preference — the gate is a REGRESSION gate against a baseline the older API produced, and swapping readers would make a changed number unattributable. Re-measuring under the new API is named in the file as the follow-up
- [Phase 06]: the segmenter is NOT swapped into CaptureView — that is Phase 8's per-swap-verified job, and doing it here would also orphan FixtureLineSegmenter into a G5 failure in the same commit. V15/V16 re-carried for exactly this reason
- [Phase 06]: V15's premise was half FALSE and is corrected in the ledger rather than quietly inherited — the 106-character line is confidence 0.30 and lives in the raw-text view, which OCR-04 shows unfiltered and segmentation never touches
- [Phase 09]: Exclusion reason is derived from the terminal state, not passed through from whichever layer spoke last (V19)
- [Phase 09]: One representative candidate serves a not-included row's badges, reason and edit target — the contradiction becomes unconstructible
- [Phase 09]: MAN-04 is three field-level guards on Track.isManual, including the failure path, not a blanket skip
- [Phase 09]: Core holds no @Model and never names the persistence framework; the record classes live in the app target
- [Phase 09]: Persistence save is a full rewrite, guarded on the crate array actually changing
- [Phase 09]: PERS-01 is measured by simctl terminate plus a canonical field-by-field dump diff, not by an XCUITest terminate alone
- [Phase 10]: SleevePipeline gained ONE parameter (the corpus URL, defaulting to the app's Bundle.main lookup) rather than the CLI rebuilding the ladders — that parameter is the entire difference between the two front ends
- [Phase 10]: V21: a record with no track lines was invisible to the sequencer — fixed in CrateRows.make, the one place a SequenceResult meets its crate, because the sequencer takes [Track] and cannot learn a trackless vinyl exists
- [Phase 10]: vinylctl sequences through CrateDetailModel.sequencerInput, not crate.allCandidates — CRATE-07's pinning lives there and the two paths give different answers
- [Phase 10]: Carried defects were re-pointed off Phases 11, 12 and 14, which the roadmap compression deleted — a carry to a phase that will never run is a carry to nowhere

### Pending Todos

**None. v1.0 is closed.** The one item that stood here — re-filing
`.planning/open-questions/RejoinTests.swift.wip` as a proper seeded-shuffle determinism test —
was discharged by Phase 5: `SequencerDeterminismTests` and `RejoinTests` are both on disk and
green, and Q1 was answered by measurement (identical vinyl order across 10 seeded shuffles,
measured three times).

### Blockers/Concerns

**v1.0 is closed. Nothing below blocks anything — these are the open items, each with a named
owner, and every one of them is the owner's rather than a phase's, because there is no phase
left to hand them to. The stale Phase 2–6 concerns that stood here have been superseded by the
phases that closed them and are recorded in those phases' SUMMARYs.**

- **CAP-04 — the last unticked requirement, and it needs the phone.** Memory and thermals across
  20 records cannot be observed on a simulator that shares the Mac's envelope and runs no camera
  pipeline. What IS measured is the loop not degrading: 21 consecutive captures, read latency
  1046 ms → 960 ms first-five against last-five mean. UAT **U13**. **66 of 67.**

- **V3 / U8 — unanswered since Phase 2, and now the common case rather than the edge case.** The
  bucket names a record `Vinyl N` where the app can name it from its own OCR text. With tier-0 at
  0% on this collection, **8 of the 10** not-included rows in the committed baseline read
  `Vinyl N`. Four phases have carried it rather than pick for the owner. Both fixes are still
  defensible and they are not equivalent in side effects — fix B moves a committed baseline.

- **U4 / U6 — is this a set you would actually play.** The project's real success criterion, and
  the one thing no phase of this milestone could ever have answered. The live set came out at 136
  and 138.8 BPM on a crate of jungle twelves; both tempos are almost certainly wrong matches
  against the wrong SoundCloud uploads.

- **Tier-0 is measured now, and the number is 0.** The bundled 6,608-row corpus is the owner's
  house/techno library and only 12% of it sits in the 160–184 band. This was predicted, not
  discovered, and it is why manual entry is a routine path rather than an error path.

- **V6, V9, V17, V20 — four Low/Informational defects carried past v1.0 with no phase left to own
  them.** Adjudicated, none blocking, all handed to the owner as UAT **U12**. Listed rather than
  quietly closed, because a defect that stops being mentioned reads, a release later, like one
  that was fixed.

- **V11 / U11 — session count or crate total on the capture strip.** Behaving as designed per
  CAP-03's own wording; whether 0 is the right number to show a DJ standing over a four-record
  crate is a taste call.

- **V10 / U10, U2b, U2d, U1 — everything that needs a real camera or a real phone.** No
  `AVCaptureVideoPreviewLayer` was ever added, deliberately: it would be unverifiable code drawn
  on an empty buffer.

- **Two pre-compression plans were never executed, and that is not hidden debt.** `01-05-PLAN.md`
  and `01-08-PLAN.md` have no SUMMARY. `01-05`'s content — `AsyncSequencer` and
  `BeamDivergenceCheck` — was delivered by Phase 5, and hygiene gate G4 fails the build if either
  disappears. They are counted in the denominator above rather than quietly excluded from it.

- **Toolchain, non-negotiable.** iOS 26 is the installed SDK. `MusicUnderstanding.framework` does
  **not** exist on this machine — never import it; gate G3 enforces it. BPM and key come from the
  in-house Accelerate/vDSP analyser behind `AudioAnalyzing`. Simulator UDID
  `4B4E1C1F-BED6-4812-9238-C151337265DA`.

## Session Continuity

Last session: 2026-08-31T02:20:00Z
Stopped at: Completed 10-PLAN.md — **the last phase of v1.0.**

`./Scripts/test.sh` **365** · `./Scripts/hygiene.sh` **9 pass 0 fail** · `./Scripts/ui-test.sh`
**10 of 10** · `./Scripts/build-app.sh` **SUCCEEDED** · `./Scripts/persistence-check.sh` 0 fail ·
`Scripts/screenshot-audit.py` **AUDIT PASSED** · ledger **21 rows, 14 closed, 7 carried, 1
Medium-or-above open** · **66 of 67 requirements**.

Nine commits this phase. `vinylctl` is a real front end over the same Core package and the same
app adapters; its answer on the owner's twelve photographs is committed at
`Artifacts/vinylctl/sequence-baseline.txt`; and `Scripts/vinylctl-vs-app.sh` reports **IDENTICAL**
against the app on the same input, with a structural check beside the empirical one.

Building it found **V21** — a record whose sleeve yields no track line was in neither the set nor
the bucket, contradicting RES-01 — fixed at the one place both front ends route through.

**Next: nothing. v1.0 is done.** What remains is the owner's: the phone (CAP-04/U13), the two
product calls (U8, U11), the four carried defects (U12), and the only question that ever
mattered — whether the set is one you would play (U4/U6).
Resume file: None
