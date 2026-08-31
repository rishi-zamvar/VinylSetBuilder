# Roadmap: Vinyl Set Builder

**Rebuilt 2026-08-30.** The previous roadmap was a six-phase capability list that had drifted
into a non-linear order — the sequencer was pulled into Phase 1 ahead of the UI, "wiring" was
declared to be a natural consequence rather than a phase, and the shell was never actually
finished before engine work began. This replaces it entirely.

## The throughline

Three acts, strictly linear. Each phase depends only on the phases before it. No interleaving.

> *"UI first then the engine then we wire everything in with tdd and proper workflow…
> I want research verification, quality preset and a linear path, time isn't an issue…
> quality is the main focal point… proper coding hygiene and a tight codebase."*

**ACT I — THE SHELL YOU CAN WALK** (Phases 1–4)
Every screen exists and is navigable in the booted simulator, rendering from stubbed fixture
data. Nothing real behind it. This is MVP-SPEC §3 Phase 0 exactly: *"you can walk the entire
flow end to end with fake data."*
**Act ship criterion:** committed screenshots of EVERY screen, taken in the booted simulator
after a settle delay.

**ACT II — THE ENGINE, HEADLESS** (Phases 5–9)
Each capability built behind the protocol seams the shell already consumes. Pure, testable,
no UI. Dependency order: OCR → segmentation → identity resolution → BPM/key → sequencing.
**Act ship criterion:** every phase closes on a *measured number* against real fixtures, never
a green tick.

**ACT III — THE WIRING** (Phases 10–14)
Swap each stub for its real implementation, one at a time, verifying the app still walks after
each swap. Then persistence, manual entry, and `vinylctl` — a macOS CLI over the same Core
package that runs the whole pipeline on the owner's 12 real record photographs end to end.
**Act ship criterion:** the app runs on real data, and `vinylctl` prints a real sequenced set.

## Standing rules — every phase, no exceptions

| Rule | What it means |
|---|---|
| **TDD** | Tests precede implementation. RED commit, then GREEN commit. |
| **Measured ship criterion** | Every phase closes on a number, a rate, or a committed artefact. "Tests pass" is not a ship criterion. |
| **Screenshots after a settle delay** | Any phase that renders UI captures into `Artifacts/screenshots/` *after* a settle delay, and files anything visible in it into `.planning/VISUAL-DEFECTS.md`. |
| **Hygiene** | No dead code, no unused protocol conformances, no `TODO` left behind, consistent naming. The `CorePurityTests` guard stays green. Checked at the close of every phase, and swept explicitly in Phases 4 and 14. |
| **Toolchain discipline** | iOS 26, the installed SDK. `MusicUnderstanding` does not exist here. No phase may be planned against an absent SDK. Simulator UDID `4B4E1C1F-BED6-4812-9238-C151337265DA`. |
| **Research on** | Phases marked **Research: yes** open with an investigation step before any code. |

## Phases

- [x] **Phase 1: Foundation & Protocol Seams** - Core package, purity guard, app target, build-time secrets — the compile-time skeleton every act hangs off
- [x] **Phase 2: The Crate Screens, Stubbed** - Crate list, creation, sequenced detail, reorder, Add More, delete, multi-crate membership — all against fixture data
- [x] **Phase 3: The Capture & Correction Screens, Stubbed** - Framing guide, thumbnail strip, flip prompt, Done, and the inspect/correct sheet — all against fixture photographs and fixture observations
- [ ] **Phase 4: Act I Sign-off — Every Screen, Photographed** - Settle-delay screenshots of every screen committed, first codebase-wide hygiene sweep, and the visual defects Phase 2's audit recorded but did not fix (V3 Medium, V4–V7 Low). **V1 and V2 are already closed** — Phase 2 shut them with evidence, so Phase 4 no longer owns them. **2026-08-30: 6 of 6 plans delivered. 04-05 returned REFUSED on gate S3; 04-06 closed V18 and re-ran `./Scripts/screenshots.sh` clean three times (rc=0/rc=0/rc=0), so S3 — and all seven gates — now hold. Two Medium-or-above ledger rows (V3, V12) stay carried. See `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md` and its ADDENDUM.**
- [ ] **Phase 5: The OCR Engine** - Vision text recognition behind a `TextRecognizing` seam, EXIF orientation passed and coordinates transformed exactly once, measured against the 12 fixtures
- [ ] **Phase 6: The Segmentation Engine** - Baseline-angle clustering, noise filtering, side markers and catalogue-number extraction, measured as track-count accuracy on the 12 fixtures
- [x] **Phase 7: Resolution & the BPM Ladder** (absorbed Phase 8) - Catalogue-number-first Discogs, MusicBrainz fallback, bounded concurrency, backoff, cache — measured as auto-resolve rate
- [x] **Phase 8: The BPM & Key Ladder** - DELIVERED INSIDE PHASE 7 on 2026-08-30. Tier-0 hit rate 0%, SoundCloud match 85%, analyser tempo 41% usable / key 34% usable
- [ ] **Phase 9: The Sequencer, Finished and Proven Deterministic** - Q1 answered, tolerance slider, rejoin-on-add, off-main-thread, beam divergence check — measured as determinism across seeded shuffles
- [x] **Phase 10: The Camera, Live** - DELIVERED 2026-08-30 in `.planning/phases/08-wiring-camera/`. Real `AVCaptureSession` + `AVCapturePhotoOutput` behind the capture screen; non-blocking shutter MEASURED at 10-26 ms with all 12 tiles seen mid-read. Memory and thermals are device-only and went to UAT U2c, not claimed
- [x] **Phase 11: The Swap** - DELIVERED 2026-08-30 in `.planning/phases/08-wiring-camera/`. Four swaps, `ui-test.sh` green at `totalTestCount=7` after each. The app runs the real pipeline end to end on the twelve photographs: 3 sequenced (172 / 174.8 / 175) + 9 not in the set = 12, twice
- [ ] **Phase 12: Manual Entry** - The sub-15-second hand-entry path, reachable from the sequenced list and the not-included bucket, never overwritten by later automatic resolution
- [ ] **Phase 13: Persistence** - SwiftData on-device, explicit integer ordering, every candidate retained — crates survive a restart intact
- [ ] **Phase 14: `vinylctl` & Definition of Done** - A macOS CLI over the same Core package that runs the whole pipeline on the 12 real photographs, plus the final hygiene sweep

## Phase Details

---

## ACT I — THE SHELL YOU CAN WALK

---

### Phase 1: Foundation & Protocol Seams
**Status**: COMPLETE (2026-08-30)
**Goal**: The project compiles for the device SDK, algorithm code is structurally quarantined
from the camera and the network, and secrets reach the binary without ever reaching git.
**Depends on**: Nothing (first phase)
**Requirements**: SETUP-01, SETUP-02, SETUP-03, SETUP-04
**Success Criteria** (what must be TRUE):
  1. ✅ `VinylSetBuilderCore` builds, and `CorePurityTests` **fails the build** if Core imports AVFoundation, Vision, UIKit, AppKit, SwiftUI or SwiftData, or mentions URLSession. Measured: 0 forbidden symbols.
  2. ✅ `./Scripts/build-app.sh` compiles the app target against the iOS 26 device SDK with signing disabled, and the `Generate Secrets.swift` build phase writes real values into a gitignored, untracked file. Measured: BUILD SUCCEEDED; `generate-secrets.sh --check` passes.
  3. ✅ `./Scripts/test.sh` runs the whole suite from the command line with no device, no camera and no network. Measured: 88 tests green.
  4. ⏳ The app installs and launches on the physical iPhone 14 Pro. **UAT U1 — needs the owner** (Xcode signed into the Apple ID, phone connected and trusted). Signing-free device-SDK compilation already passes.
**Plans**: 4 of 4 delivered
  - [x] 01-01 — Core package, 7 domain value types, 3 protocol seams, purity guard (SETUP-02, SETUP-04)
  - [x] 01-02 — XcodeGen app target, iOS 26, build-time `Secrets.swift` (SETUP-01, SETUP-03)
**Carried out of this phase**: U1 (device install) stays open in `UAT-PENDING.md`.

---

### Phase 2: The Crate Screens, Stubbed
**Goal**: The whole crate side of the app is real, navigable SwiftUI rendering from
`FixtureCrates` — you can list, create, open, reorder, add to and delete a crate, and see a
sequenced running order with badges and a reasoned not-included bucket, with nothing real
behind any of it.
**Depends on**: Phase 1
**Requirements**: CRATE-01, CRATE-02, CRATE-03, CRATE-04, CRATE-05, CRATE-06, CRATE-07, SEQ-07, SEQ-11
**Already delivered in this phase** (built during Phase 1's plans, mapped here because it is
Act I work): CRATE-01, CRATE-02, CRATE-06, CRATE-07 (`CrateStore`, `FixtureCrates`,
`CrateListView`, `NewCrateSheet`) and SEQ-07, SEQ-11 (`CrateRows` single not-included bucket,
`TrackBadges`, `BadgePairView`, `SequencedRowView`, `NotIncludedSectionView`).
**Still outstanding**: CRATE-03, CRATE-04, CRATE-05 — the crate detail screen itself.
**Success Criteria** (what must be TRUE):
  1. Opening a fixture crate shows its sequenced running order — every row carrying a BPM badge and a Camelot badge — with the single collapsed not-included section beneath it, each of its rows carrying its own plain-language reason string.
  2. Dragging a row reorders the crate and the manual order survives navigating away and back, overriding whatever the stub sequencer returned.
  3. "Add More" from an open crate re-enters the capture screen and returns to the same crate, not a new one.
  4. The same fixture vinyl appears in two different crates with a different selected track in each — demonstrated on screen, not only in a unit test.
  5. Deleting a crate, and removing a single vinyl from a crate, both work from the UI and the counts update correctly.
**Ship criterion (measured)**: an XCUITest walks list → create → capture → detail → reorder →
add more → remove vinyl → delete crate without a single stub throwing, and every one of those
states is screenshotted into `Artifacts/screenshots/` after a settle delay.
**Plans**: 5 of 5 delivered
  - [x] 02-01 — `CrateDetailModel`: running order, the CRATE-07 pin, the manual override that survives a re-sequence, `addMore`/`update` (CRATE-03/04/05/07)
  - [x] 02-02 — XCUITest target, shared scheme, unattended run script, settle-delay screenshot pipeline proven end to end (CRATE-01)
  - [x] 02-03 — `CrateDetailView`, `RootView` wiring, V1's inflection fix, the frozen accessibility-identifier contract (CRATE-01/02/03/04/05/06/07, SEQ-07, SEQ-11)
  - [x] 02-04 — the whole-flow XCUITest walk and its fifteen photographed states (all nine requirements)
  - [x] 02-05 — V1/V2 closure with evidence, visual audit of all fifteen pictures, hygiene sweep, ship-criterion audit
**UI hint**: yes
**Planned against three facts worth carrying forward**: plan 01-05 was never executed, so
`AsyncSequencer` and `BeamDivergenceCheck` do not exist on disk and SEQ-08/09/10 are wholly
Phase 9's; SEQ-05 (the tolerance slider) is Phase 9's requirement and is deliberately absent
here; and `BPMRules`/`BeamSearchSequencer` are untouched by Phase 2, so Phase 9's bidirectional
rewrite starts from an unmodified baseline.

---

### Phase 3: The Capture & Correction Screens, Stubbed
**Goal**: The capture loop and the inspect/correct sheet exist as real, navigable screens
driven by the 12 committed fixture photographs standing in for a live camera — so that when
Act III swaps a real camera and a real OCR pipeline underneath them, no new UI is written.
**Depends on**: Phase 2
**Requirements**: CAP-02, CAP-03, CAP-05, CAP-06, OCR-04, SEG-07
**Success Criteria** (what must be TRUE):
  1. The capture screen shows a framing guide sized for a **whole 12" sleeve**, not a label close-up — the fixtures showed the label is under 10% of the frame and the sleeve is the captured unit.
  2. A thumbnail strip along the bottom shows every vinyl "scanned" so far in the session, each with its own resolution status indicator, and it scrolls past 20 items without layout breaking.
  3. Tapping a thumbnail opens the inspect/correct sheet: the raw recognised text for that photo is readable on screen (OCR-04), and the segmented track lines can be split, merged, or hand-typed (SEG-07) — all against fixture observations.
  4. The flip-side prompt appears inline, without leaving the camera, offering Scan or Skip — and is **suppressed** when the fixture already yielded both sides from one photograph, which the spike found is common (`A:` / `AA:`).
  5. "Done" leaves the capture loop and lands on the sequenced result for that crate.
**Ship criterion (measured)**: all 12 fixture photographs load through the stubbed capture
screen in one simulated session; the flip prompt fires on exactly the fixtures that lack a
second side marker and on no others; every screen and sheet state is screenshotted after a
settle delay.
**Plans**: 5 of 5 delivered
  - [x] 03-01 — Capture Core: the real-OCR fixture generator (104 observations, 12 photographs), `FramingGuide`, `CaptureItem`/`CaptureSession`, the flip rule, the `PhotoCapturing` seam, `FixtureLineSegmenter` (CAP-02/03/05)
  - [x] 03-02 — Correction Core: `SegmentationDraft` (split / merge-up / hand-type / add) and `RawObservationRows` (OCR-04, SEG-07)
  - [x] 03-03 — the capture screen: sleeve guide, shutter, thumbnail strip with status, inline flip prompt, Done — and Phase 2's walk repaired against it (CAP-02/03/05/06)
  - [x] 03-04 — the inspect/correct sheet, presented from a thumbnail tap (OCR-04, SEG-07)
  - [x] 03-05 — the twelve-fixture session walk, the twenty-one-item strip test, nine photographed states, the visual audit of all 33 frames and the ship-criterion audit (all six)
**Ship criterion: MET, and measured.** `CaptureWalkUITests` drives all 12 fixture photographs
through the capture screen in one session; the flip prompt fires on exactly
`[1, 3, 4, 5, 7, 8, 10, 11, 12]` and is suppressed on exactly `[2, 6, 9]`, asserted as named sets
in both directions; the strip's status tally is exactly `6 Read / 5 Partial / 1 Unread`; and
every screen and sheet state is photographed through one settle-delay helper at ≥3 s. Mutations
I, J and K reddened those three claims cleanly (`.planning/VISUAL-DEFECTS.md`).
**Research**: done — the 12 fixture HEICs never enter the simulator. `Scripts/generate-ocr-fixtures.sh`
turns the real OCR run into a committed `FixtureObservations.swift`, and `FixturePhotoSource`
deals it one shutter press at a time through the `async PhotoCapturing` seam Phase 10's
`AVCapturePhotoOutput` implements. No photograph bytes are in the repo (D-03-2).
**UI hint**: yes
**Carried out of this phase**: V3 (Medium) carried with a **second** piece of evidence and no
fix — the product call is U8 and it is the owner's. V4, V9, V14, V15 (Low/Informational) to
Phase 4; V10 to Phase 10; V12 and V16 to Phase 6. V13 closed with numbers. U9 and U10 added to
`UAT-PENDING.md`.

---

### Phase 4: Act I Sign-off — Every Screen, Photographed
**Goal**: Act I is provably complete: a committed screenshot of every screen in the app, taken
in the booted simulator after a settle delay, with the two known visual defects diagnosed and
fixed and the codebase swept clean before any engine work starts.
**Depends on**: Phase 3
**Requirements**: none — this is the act's verification and hygiene gate
**Success Criteria** (what must be TRUE):
  1. `Artifacts/screenshots/` contains one committed screenshot per screen and per significant sheet state, every one taken **after a settle delay**, and a script regenerates the whole set in one command.
  2. **V2 is diagnosed before it is fixed.** The washed-out contrast is first tested against the launch-fade hypothesis by re-screenshotting with a settle delay. Only if the pallor survives that is the cause chased into the view tree — checking `.disabled(true)` on an enclosing view *first*, since that would mean the rows are not tappable and the defect is functional, not cosmetic. The finding is recorded either way.
  3. **V1 is fixed**: `Text("^[\(count) record](inflect: true)")` — "1 record" / "4 records", correct without a manual branch.
  4. Hygiene sweep: no dead code, no unused protocol conformances, no `TODO` comments, consistent naming across `App/` and `VinylSetBuilderCore/`, and `CorePurityTests` still green.
**Ship criterion (measured)**: screenshot count equals screen count with zero screens missing;
`VISUAL-DEFECTS.md` has zero rows at Medium or above still open; a grep for `TODO`/`FIXME`
across `App/` and `VinylSetBuilderCore/Sources/` returns zero hits.

**SHIP-CRITERION RESULT — reported clause by clause 2026-08-30 by plan 04-05.**
Full evidence: `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md`.

  1. *screenshot count equals screen count, zero screens missing* — **MET.**
     `python3 Scripts/screenshot-audit.py` → `46 files - 44 distinct screen states`; Gate A
     reports 18 COVERED rows and 0 uncovered. Measured 4 times.
  2. *`VISUAL-DEFECTS.md` has zero rows at Medium or above still open* — **NOT MET.**
     `python3 Scripts/ledger-check.py` → `18 rows, 8 closed, 10 carried, 2 Medium-or-above open`.
     The two are **V3** (blocked on the owner's unanswered U8) and **V12** (Phase 6 owns the
     SEG-03 filter that fixes it). Both are outside Act I's authority to close; neither was
     re-worded to make the clause read differently.
  3. *a grep for `TODO`/`FIXME` returns zero hits* — **MET.** `rc=1`, zero hits, by the literal
     command above and independently by `hygiene.sh` G1.

**PHASE-LEVEL VERDICT: REFUSED**, on sign-off gate **S3**, not on the clause above.
`./Scripts/screenshots.sh` exited **1 on two of three clean runs**:
`Artifacts/screenshots/02-walk-09-detail-manual-order.png` came back photographing the
sequencer's own order under a *Custom order* header, 22,142 differing content pixels against the
committed frame, while the UI suite reported 7 passed / 0 failed from log **and** result bundle.
Root cause filed as ledger row **V18**: `CrateDetailModel.moveRows` commits a manual order for an
identity move, and the walk's CRATE-04 step asserts a button **exists** instead of measuring the
row order. **Plan 04-06 closes it.** The **act**-level criterion (committed settle-delay
screenshots of every screen) is separately reported **MET** — the committed frames are right; it
is regeneration that is not.

**2026-08-30, plan 04-06 — the refusal is answered.** V18 is fixed at its root (`moveRows` now
returns early when a move produces the order already displayed) and CLOSED in the ledger with a
route back to the defect as well as to the fix. The walk's CRATE-04 step measures the **row
order** instead of a button's existence, with three controls on that comparator run in band.
`./Scripts/screenshots.sh` then returned **rc=0 on three consecutive clean runs** — recipes 2, 1
and 2 won, so both edit-mode branches were exercised — against 04-05's rc=0 / rc=1 / rc=1.
**Gate S3 HOLDS, and all seven gates S1-S7 now hold.** Two Medium-or-above ledger rows (V3, V12)
remain carried and unchanged, so the phase criterion's clause 2 is still not met; that is
reported, not papered over. See the **ADDENDUM** in `ACT-I-SIGNOFF.md`.

**Plans**: 6 of 6 delivered.
  - [x] 04-01 — the screen-state inventory content-hashed, the committed photometric probe, and one command that regenerates the whole set (S1/S2/S3)
  - [x] 04-02 — `Scripts/hygiene.sh`: eight gates each proven able to fail, plus the carried-debt inventory corrected (S5/S6)
  - [x] 04-03 — V4 and V5 closed with pixel and uniqueness measurements; one bounded root-cause attempt at V9 (S7)
  - [x] 04-04 — the defect ledger adjudicated row by row, `Scripts/ledger-check.py` as gate G9, U11 filed (S7)
  - [x] 04-05 — three clean runs, the eight-command recount, all 46 frames read, and the verdict: **REFUSED on S3** (S1-S7)
  - [x] 04-06 — **REQUIRED to close the refusal**: an identity guard on `moveRows`, a row-order assertion in the walk's CRATE-04 step, then three clean regenerations at rc=0
**UI hint**: yes
**Planned 2026-08-30 against four facts.** (1) The phase owns **zero requirements** — its
deliverables are a verdict and a clean ledger, and its gates are numbered S1-S7 in
`.planning/phases/04-act-i-signoff/CONTEXT.md`. (2) **V3 is NOT fixed here** (D-04-1): both
candidate fixes are a product call, asked as U8, unanswered. (3) The ship criterion above is a
**three-part conjunction** and 04-05 reports it clause by clause — the Medium-or-above clause is
expected to read NOT MET, with V3 blocked on the owner and V12 owned by Phase 6, which is what
makes the verdict `SIGNED OFF WITH NAMED CARRY` rather than a pass. (4) **A REFUSAL is a valid
outcome** and the rules for choosing between the three verdicts were fixed in CONTEXT.md before
plan 04-01 ran a single command.

---

## ACT II — THE ENGINE, HEADLESS

Every phase in this act is pure logic behind a protocol the shell already consumes. No UI is
touched. Each closes on a measured number against real fixtures.

**A note on the purity guard.** Core may not import Vision or AVFoundation. The OCR and audio
adapters therefore live outside Core, behind seams Core owns (`TextRecognizing`,
`AudioAnalyzing`) — and each is exercised headlessly by a small measurement harness under
`Tools/`. Those harnesses are the seed of `vinylctl` (Phase 14); write them so they compose.

---

### Phase 5: The OCR Engine
**Goal**: A photograph goes in, trustworthy text observations with boxes, confidence and
baseline angle come out — in one documented coordinate convention, off the main thread.
**Depends on**: Phase 4
**Requirements**: OCR-01, OCR-02, OCR-03, OCR-05
**Success Criteria** (what must be TRUE):
  1. Each fixture photograph yields observations carrying a bounding box, a per-observation confidence and a baseline angle, as Core value types with no Vision type leaking across the seam.
  2. EXIF orientation is passed to the request handler explicitly. Vision returns coordinates in the **original unrotated buffer space** even when given an orientation; the transform into the project's single documented convention is applied **exactly once**, and a test proves a double-transform would fail.
  3. Recognition is seeded with a custom vocabulary of the owner's recurring label and artist names, and the effect of that vocabulary is *measured* rather than assumed — `customWords` is a bias list, not a guarantee.
  4. OCR runs off the main thread and a concurrent recognition never blocks a caller.
**Ship criterion (measured)**: re-run against all 12 committed fixtures, scoring **at least the
spike baseline of 6 clean / 5 partial / 1 fail** — a regression below that fails the phase.
Per-image latency reported against the spike's ~130 ms (455 ms first-call warm-up) and
committed to `research/OCR-SPIKE.md` as a second data point.
**Plans**: TBD
**Research**: yes — the spike used `VNRecognizeTextRequest` on macOS; confirm the Swift-native
`RecognizeTextRequest` (iOS 18+, available at the iOS 26 target) reproduces the same EXIF and
coordinate-space behaviour before committing to it.

---

### Phase 6: The Segmentation Engine
**Goal**: One sleeve photograph becomes the right number of candidate track lines, by baseline
angle — the algorithm the fixtures actually support, not the radial clustering the spec assumed.
**Depends on**: Phase 5
**Requirements**: SEG-01, SEG-02, SEG-03, SEG-04, SEG-05, SEG-06, SEG-08
**Success Criteria** (what must be TRUE):
  1. Observations are grouped by **baseline angle** to separate physical surfaces (rotated record label vs. sleeve), then grouped within each cluster. No label-centre detection, no circle finding, no polar unwrapping — the fixtures disproved the radial approach.
  2. Non-track text is filtered before clustering — price stickers by a currency/decimal regex (`$10.00`, `6.00€`, `8.00%`), RPM, ℗/© lines, addresses, URLs, emails — while **catalogue numbers are extracted and kept** as first-class output (`TYME 012`, `tech008`, `CSI 006`, `EMF2029`).
  3. A side or track marker splits tracks in preference to geometry, across the full observed vocabulary: `A`/`AA`/`B`/`BB`, `A1`/`B2`, `SIDE A`, `Side One`, and arbitrary named sides such as `COLD SIDE:` / `STEEL SIDE:`.
  4. A parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one.
  5. Only the trusted confidence tier feeds track lines. Confidence is effectively binary in this collection (1.00 vs 0.50/0.30 — 88 of 104 observations were 1.00), so the filter is a tier, not a fraction — and a test asserts that.
  6. The app infers whether an unscanned flip side probably exists, from side markers or their absence, and that inference is what drives Phase 3's flip prompt.
**Ship criterion (measured)**: per-fixture track-count accuracy reported across all 12
committed fixtures, with a hand-scored expected count per fixture committed alongside.
Target ≥ 9/12 usable track counts, which is what the spike's read quality supports. The table
goes into `research/` as the baseline every later change is measured against.
**Plans**: TBD

---

### Phase 7: The Identity Resolver
**Status**: COMPLETE (2026-08-30) — executed as one phase together with Phase 8, in
`.planning/phases/07-resolution-bpm/`. See `07-SUMMARY.md` for every measured number.
**Measured**: catalogue-number resolution **6 of 6** against a baseline of 5 of 6, twice, with
three live negative controls. Overall 17-18 of 21 track lines identified across the twelve
photographs; the artist+title fallback rung produces confident wrong answers and is the
weakest part of the ladder. MusicBrainz answered 2-3 of the 6 catalogue lookups for free
(it knows 5 of 6 when it is not returning 503).
**Goal**: A candidate track line becomes an artist and a title — or is honestly marked failed —
climbing the cheapest-first ladder and never spending a quota call on a datum available free.
**Depends on**: Phase 6
**Requirements**: RES-01, RES-02, RES-03, RES-04, RES-05, RES-06, RES-07, RES-08
**Success Criteria** (what must be TRUE):
  1. **A catalogue number, when present, is the primary Discogs key, ahead of artist+title.** It read cleanly on 6 of 12 fixtures and is far more discriminating for white labels. Artist+title is the fallback, not the other way round.
  2. Discogs supplies release, artist, label and format; MusicBrainz is the fallback; every track ends `.resolved` or explicitly `.failed`, never silently dropped.
  3. Match acceptance is banded: above 0.75 normalised similarity accepted, 0.50–0.75 queued for user confirmation, below 0.50 rejected — and the band boundaries are unit-tested at their edges.
  4. At most 3 requests are in flight at once; HTTP 429 triggers backoff and retry rather than a failed resolution; cancelling or leaving a crate cancels that crate's in-flight work.
  5. Results are cached such that re-running the sequencer issues **zero** network requests — proven by a test that counts requests through an injected transport.
**Ship criterion (measured)**: catalogue-number resolution scored against the fixtures,
holding **at least the measured baseline of 5 of 6 correct**. Overall auto-resolve rate across
the 12 fixtures reported as a number, alongside a request count proving the cache and the
concurrency bound. The MVP-SPEC's aspirational "70%+" is recorded as a target, not a gate —
white labels genuinely absent from every database are not a resolver defect.
**Plans**: TBD
**Research**: yes — the SoundCloud probe returned a 79-minute DJ mix as the second hit for a
correct artist query. Result selection needs a duration sanity bound plus similarity scoring
before it is trusted; investigate the equivalent failure mode on Discogs search.

---

### Phase 8: The BPM & Key Ladder
**Status**: COMPLETE (2026-08-30) — delivered inside Phase 7.
**Measured**: Gate A tier-0 hit rate **0 of 17 and 0 of 18** on the real collection (control
against the corpus's own source library 40 of 40, so the reader works — the corpus simply does
not contain this music). Gate B SoundCloud match rate **85%** (34 of 40) against a 72%
baseline, twice, second run offline from cache; analyser tempo **38% exact / 41% usable**
octave-aware and **59% within 5%**, key **24% exact / 34% within one Camelot hop**.
**DECISION: key degrades to a soft/manual field**, kept automatically only above a 0.8
confidence where its precision is 71%. BPM stays automatic.
**Goal**: Every resolved track carries a BPM and a Camelot key, or is honestly marked as
lacking them — via the cheapest route that can supply it. This phase carries the project's
largest remaining unknown and closes on two separate measured gates.
**Depends on**: Phase 7
**Requirements**: BPM-01, BPM-02, BPM-03, BPM-04, BPM-05, BPM-06, BPM-07, BPM-08, BPM-09
**Success Criteria** (what must be TRUE):
  1. The bundled read-only 6,608-row tier-0 corpus (880 KB, `journal_mode=delete`, generated at build time and gitignored like `Secrets.swift`) is consulted **first, before any network call**, with punctuation-normalised matching and a documented tie-break for the known conflicting-key case (`The Rapture Pt. II` 3A vs `The Rapture, Pt. II` 2B).
  2. On a tier-0 miss, audio is fetched from SoundCloud with the owner's existing OAuth credentials — accepting that client-credentials returns a **30-second preview**, which is ample for tempo (~85 beats at 170 BPM) and weaker for key.
  3. Fetched audio is analysed on-device by the app's own **Accelerate/vDSP** analyser — onset envelope + autocorrelation for tempo, chromagram + Krumhansl-Schmuckler for key — and is **not retained** afterwards. A test asserts the audio buffer does not outlive the analysis.
  4. The analyser sits behind an `AudioAnalyzing` protocol, so Apple's Music Understanding is a drop-in the day an iOS 27 SDK exists, with no caller changed. `MusicUnderstanding` is never imported — it is absent from this SDK and this system.
  5. Any BPM below 100 is doubled unconditionally, exactly once, folding half-time reads into the genre's real range. A track whose BPM no route can establish is surfaced for manual entry, not dropped.
**Ship criterion (measured)** — two gates, both numbers:
  - **Gate A, tier-0 hit rate.** Measured against the real jungle/DnB fixture tracks, not assumed. The corpus skews house/techno — only 12% sits in the 160–184 BPM band — so a low hit rate is an expected outcome, not a failure; it reallocates weight onto Phase 12 (manual entry) and is recorded as such.
  - **Gate B, analyser accuracy.** Scored against the 29-track cached ground truth in `.local/` (`truth.tsv`, `mu_dataset.json`, `mu_audio/*.mp3`), tempo scored **octave-aware** and key scored by **Camelot distance**, via `Tools/mu-validate.swift` retargeted from `MusicUnderstandingSession` to `AudioAnalyzing`. The SoundCloud match rate must hold at **≥ 72%**, the measured baseline.
  - **Documented fallback, decided in advance:** if key accuracy from a 30 s preview proves poor, key degrades to a soft/manual field while BPM stays automatic. The sequencer tolerates this by construction — Camelot distance only *orders* survivors and never excludes.
**Plans**: TBD
**Research**: yes — this is the phase's whole first move. Do not build the ladder before Gate B
has a number.

---

### Phase 9: The Sequencer, Finished and Proven Deterministic
**Goal**: The project's differentiator is finished and, critically, **proven to give the same
set from the same records** — because it re-runs on every vinyl added, an order-dependent
sequencer would silently produce a different set each time.
**Depends on**: Phase 8
**Requirements**: SEQ-01, SEQ-02, SEQ-03, SEQ-04, SEQ-05, SEQ-06, SEQ-08, SEQ-09, SEQ-10
**Already delivered** (Phase 1 plans 01-03 and 01-04, mapped here because sequencing is Act II
work): SEQ-01 (`Camelot` flat hop count +1 for letter change), SEQ-02 (`Set<UUID>` enforcing
one track per vinyl), SEQ-03 (BPM gate, bidirectional since 2026-08-30), SEQ-04 (most vinyls wins, ties on
lowest total Camelot distance), SEQ-06 (exclusion with a plain-language reason) —
`BeamSearchSequencer`, width 50.
**Still outstanding**: SEQ-05, SEQ-08, SEQ-09, SEQ-10, and **Q1**.
**Success Criteria** (what must be TRUE):
  1. **Q1 is answered.** `.planning/open-questions/Q1-sequencer-determinism.md` records that the rank tuple ends in `start-index asc`, derived from array position — so a shuffle may change which equal-ranked states survive pruning. A test builds a crate, sequences it, shuffles the candidate array with a **seeded** RNG, sequences again, and asserts the resulting **vinyl ID order** is identical — comparing IDs, not `Track` structs — across several seeds. The interrupted WIP test's `170 → 178 → 174` output must be explained: either the test was malformed (printing the input array) or the sequencer is genuinely order-dependent, and the answer is written down.
  2. **If confirmed, it is fixed** by making the rank tuple a **total order** — appending a stable, position-independent tiebreaker, the track's UUID being the obvious candidate. `SEQ-03`'s **bidirectional adjacency** gate is then re-asserted on the fixed sequencer.
  3. `BPM_TOLERANCE` is a slider from 3 to 6 defaulting to 4.0, and moving it re-optimises the whole sequence live.
  4. Adding a vinyl re-runs the **whole** optimisation as a pure re-derivation with no memory of the prior run, and a previously excluded record **rejoins** when a new addition bridges the gap — proven on a hand-constructed fixture, not a random one.
  5. Sequencing runs off the main thread, and beam width 50 is checked against a wider beam so a silently suboptimal path is *detectable* rather than assumed absent.
**Ship criterion (measured)**: identical vinyl-ID order across **≥ 10 seeded shuffles** of the
same crate; beam-50 vs beam-150 agreement on both vinyl count and total Camelot distance
across every seeded fixture, with any disagreement reported as data rather than swallowed;
p95 sequencing wall time at **100 vinyls / 400 candidates** reported as a number against the
"feels instant" bar.
**Plans**: TBD
**Carried in**: Q1. This phase closes it or the phase does not ship.

---

## ACT III — THE WIRING

---

### Phase 10: The Camera, Live
**Goal**: A real `AVCaptureSession` sits behind the capture screen Phase 3 already built, and
the shutter never makes you wait.
**Depends on**: Phase 9
**Requirements**: CAP-01, CAP-04
**Success Criteria** (what must be TRUE):
  1. Session configuration and `startRunning()` run off the main thread (the call blocks), inside a dedicated `CameraController` — `@preconcurrency import AVFoundation` accepted at that one boundary rather than fought.
  2. The next capture is issued only after the previous `didFinishProcessingPhoto:` callback fires — never overlapping, which `AVCapturePhotoOutput` handles unpredictably — with the delegate bridged through a `CheckedContinuation` so the call site is a plain `try await camera.capturePhoto()`.
  3. The shutter returns to the camera immediately with **no blocking spinner**; OCR and resolution proceed in the background and the thumbnail strip updates independently as each completes.
  4. No UI is rewritten. The real camera enters through the same seam the fixture photographs entered through in Phase 3.
**Ship criterion (measured)**: a 20-record session on the device with shutter-to-ready latency
reported as a number, peak memory reported, and thermal state sampled throughout. The spike
measured OCR at ~130 ms/image, so the CAP-04 risk is expected to be small — the point is to
*confirm that with a number*, not to assume it.
**Plans**: TBD
**UI hint**: yes
**Carried out**: UAT U2 — the live capture *feel* across 20 real records still needs the owner
and the physical phone. The simulator has no camera.

---

### Phase 11: The Swap
**Goal**: Every stub is replaced by its real implementation, **one at a time**, with the app
proven to still walk after each individual swap — so that when something breaks, exactly one
change is responsible.
**Depends on**: Phase 10
**Requirements**: none — this is the act's integration gate
**Success Criteria** (what must be TRUE):
  1. Swaps land in dependency order — `TextRecognizing`, then `LabelSegmenting`, then `MetadataResolving`, then `AudioAnalyzing`, then `Sequencing` — as separate commits, never batched.
  2. After **each** swap the XCUITest walk from Phase 2 and Phase 3 passes unchanged, and the full screenshot set is regenerated after a settle delay and compared against the Act I set.
  3. Any stub that survives the swap is deleted, not left dormant. The fixture implementations remain **only** where a test needs them, and a test asserts no fixture type is reachable from the shipping app path.
  4. The purity guard is still green after every swap — Vision and AVFoundation never migrate into Core on the way in.
**Ship criterion (measured)**: five swaps, five green walks, five screenshot sets. Then the
full app run end to end on the **12 real record photographs**, reporting: tracks segmented,
tracks resolved, tracks with BPM and key, and length of the resulting sequence — four numbers,
committed.
**Plans**: TBD
**UI hint**: yes

---

### Phase 12: Manual Entry
**Goal**: The path for everything automatic resolution misses — which for a crate of white
labels and dubplates is a first-class path, not an error state.
**Depends on**: Phase 11
**Requirements**: MAN-01, MAN-02, MAN-03, MAN-04, MAN-05
**Success Criteria** (what must be TRUE):
  1. Artist, title, BPM and key can be entered or corrected for any track **in under 15 seconds**, timed on the device — the requirement is a stopwatch, not a feeling.
  2. Camelot key is chosen from a **tap grid**, never typed. BPM pre-fills from a sensible neighbour value rather than starting empty.
  3. A manually entered track is marked as such and is **never silently overwritten** by a later automatic resolution — proven by a test that resolves over a manual entry and asserts the manual value survives.
  4. Manual entry is reachable directly from the sequenced list **and** from the not-included bucket, not only from a failure dialog.
**Ship criterion (measured)**: median wall-clock time to fully enter one track, measured across
several real fixture tracks on the device, reported against the 15-second bar. Screenshots of
the entry sheet, the Camelot tap grid and the manual badge, after a settle delay.
**Plans**: TBD
**UI hint**: yes

---

### Phase 13: Persistence
**Goal**: Close the app, reopen it, find the crate intact — with ordering that survives
because it is stored explicitly, not because a relationship happened to come back sorted.
**Depends on**: Phase 12
**Requirements**: PERS-01, PERS-02, PERS-03, PERS-04
**Success Criteria** (what must be TRUE):
  1. Crates, vinyls, candidate tracks, photos and sequence order all survive quitting and relaunching the app.
  2. Ordered data uses **explicit integer ordering fields** and plain `[UUID]` scalar arrays — never `@Relationship` to-many array order, which Core Data backs with an `NSSet` and does not guarantee across a fetch. `Track.position` is the source of truth for in-vinyl order, sorted at the call site.
  3. **Every** candidate track stays stored even when unselected, because the sequencer needs all of them on every re-run. A test deletes nothing and asserts the candidate count is unchanged after a save/load cycle.
  4. All storage is on-device. Nothing is uploaded anywhere — asserted by the same style of guard that enforces Core purity.
**Ship criterion (measured)**: a crate of 20 vinyls with all candidates is written, the app is
terminated via `simctl` and relaunched, and the reloaded crate is compared field-by-field
against the pre-quit snapshot — reporting zero diffs, including sequence order and the
not-included bucket's reasons.
**Plans**: TBD

---

### Phase 14: `vinylctl` & Definition of Done
**Goal**: A first-class macOS CLI over the same `VinylSetBuilderCore` package, which runs the
entire pipeline on the owner's 12 real record photographs and prints a real sequenced set —
and the final hygiene sweep that closes the project.
**Depends on**: Phase 13
**Requirements**: none — this is the milestone's proof and final sweep
**Success Criteria** (what must be TRUE):
  1. `vinylctl` is a real executable target in the repo, built by the same `Scripts/` toolchain, composed from the Act II measurement harnesses rather than duplicating them. It links `VinylSetBuilderCore` and the same adapters the app does — **one pipeline, two front ends**, no second implementation.
  2. `vinylctl sequence <photos…>` runs photographs → OCR → segmentation → resolution → BPM/key → sequence and prints the ordered set with per-track BPM and Camelot, plus the not-included bucket with each row's reason.
  3. Subcommands expose each stage on its own (`ocr`, `segment`, `resolve`, `analyze`) so any future regression is bisectable to one stage from the command line, with no simulator involved.
  4. **Definition of Done, walked end to end** (MVP-SPEC §9): create a crate and scan 20 vinyls without waiting on any screen; most auto-resolve and the rest hand-entered in under 15 s each; a sequenced set whose consecutive tempo steps stay inside the tolerance and whose harmonic neighbours make sense; add 5 more and watch the sequence re-optimise **including a previously excluded record rejoining**; quit, reopen, crate intact.
  5. Final hygiene sweep: zero dead code, zero unused protocol conformances, zero `TODO`/`FIXME`, consistent naming, purity guard green, and every stub from Act I deleted.
**Ship criterion (measured)**: `vinylctl sequence` run over the 12 real photographs prints a
non-empty sequenced set, and its output is committed as the project's closing artefact.
The five Definition-of-Done steps each pass with the numbers recorded. Grep for
`TODO|FIXME|XXX` across `App/`, `VinylSetBuilderCore/Sources/` and `Tools/` returns zero.
**Plans**: TBD
**Carried out**: UAT U4/U6 — whether the produced set is one the owner would actually play is
irreducibly a human judgement, and it is the project's actual success criterion.

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Protocol Seams | 4/4 | Complete | 2026-08-30 |
| 2. The Crate Screens, Stubbed | 5/5 | Complete | 2026-08-30 |
| 3. The Capture & Correction Screens, Stubbed | 5/5 | Complete | 2026-08-30 |
| 4. Act I Sign-off — Every Screen, Photographed | 5/5 | **In progress — REFUSED on S3 by 04-05; 04-06 required** | - |
| 5. The OCR Engine | 0/TBD | Not started | - |
| 6. The Segmentation Engine | 0/TBD | Not started | - |
| 7. The Identity Resolver | 0/TBD | Not started | - |
| 8. The BPM & Key Ladder | 0/TBD | Not started | - |
| 9. The Sequencer, Finished and Proven Deterministic | 2/TBD | In progress | - |
| 10. The Camera, Live | 0/TBD | Not started | - |
| 11. The Swap | 0/TBD | Not started | - |
| 12. Manual Entry | 0/TBD | Not started | - |
| 13. Persistence | 0/TBD | Not started | - |
| 14. `vinylctl` & Definition of Done | 0/TBD | Not started | - |

## Requirement Coverage

**67 of 67 v1 requirements mapped. Zero orphans. Zero duplicates.**

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | SETUP-01, SETUP-02, SETUP-03, SETUP-04 | 4 |
| 2 | CRATE-01…07, SEQ-07, SEQ-11 | 9 |
| 3 | CAP-02, CAP-03, CAP-05, CAP-06, OCR-04, SEG-07 | 6 |
| 4 | — (verification/hygiene gate) | 0 |
| 5 | OCR-01, OCR-02, OCR-03, OCR-05 | 4 |
| 6 | SEG-01…06, SEG-08 | 7 |
| 7 | RES-01…08 | 8 |
| 8 | BPM-01…09 | 9 |
| 9 | SEQ-01…06, SEQ-08, SEQ-09, SEQ-10 | 9 |
| 10 | CAP-01, CAP-04 | 2 |
| 11 | — (integration gate) | 0 |
| 12 | MAN-01…05 | 5 |
| 13 | PERS-01…04 | 4 |
| 14 | — (DoD proof + final sweep) | 0 |
| **Total** | | **67** |

**Already complete: 27 of 67.** SETUP-01/02/03/04, CRATE-01/02/03/04/05/06/07,
CAP-02/03/05/06, OCR-04, SEG-07, SEQ-01/02/03/04/06/07/08/09/10/11.
**Outstanding: 40 of 67.**

*Recounted 2026-08-30 by plan 03-05's audit, from the ticked boxes in `REQUIREMENTS.md` and not
by incrementing the previous line. Re-derive both halves in two commands:*

```
grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md   ->  27
grep -c "^- \[ \] \*\*" .planning/REQUIREMENTS.md   ->  40        27 + 40 = 67
```

*Phase 3 contributed all six of its requirements. The previous figure of 17 was plan 02-05's and
was correct when written — it predates Phase 3. The figure of 23 was correct until Phase 5, which
closed `SEQ-03` (reopened by the spec change), `SEQ-08`, `SEQ-09` and `SEQ-10`: +4, hence 27.*

### Two placement notes, stated openly

- **CAP requirements are split across acts on purpose.** CAP-02/03/05/06 are *screens* and
  belong to Act I, where they render from fixture photographs. CAP-01 (non-blocking shutter)
  and CAP-04 (20 records without stalling or throttling) are *live-camera behaviours* that
  cannot exist until a real `AVCaptureSession` does, so they sit in Act III Phase 10. The
  simulator has no camera; pretending otherwise would put an unverifiable criterion in Act I.
- **Manual entry is Act III, not Act I**, because the owner's own act structure names it
  there. Its sheet is therefore the one screen Act I does not build — recorded here so it
  reads as a decision rather than a gap.

## Granularity Note

`config.json` sets granularity `standard`, whose typical band is 5–8 phases. This roadmap has
**14**. That is deliberate and it is the mandate's doing, not padding: three acts that may not
interleave, a five-capability engine that must be built in dependency order, a swap phase that
verifies one substitution at a time, and a quality preset that requires every phase to close
on its own measured number. Compressing to 8 would mean either merging engine capabilities
(losing the per-capability measured gate) or interleaving the acts (losing the throughline).
Both were rejected. Time is not a constraint; quality is the focal point.

---
*Roadmap rebuilt: 2026-08-30 — three-act linear structure, 67/67 requirements mapped*

---

## AMENDMENT 2026-08-30 — the sequencer specification changed after this roadmap was written

The owner revised the BPM rule. See `.planning/SEQUENCER-SPEC.md` for the full statement.

**Was:** consecutive tracks within tolerance AND BPM never decreases.
**Now:** consecutive tracks within tolerance **in either direction**. SUPERSEDED: monotonic BPM is retired.

### Why this is not a small edit

`BeamSearchSequencer` currently sorts candidates by BPM and makes a **single forward pass**.
That is only correct because BPM could never go backwards — which made the search a DAG.
Allowing backward steps turns it into a **general graph**, so:

- The single forward pass cannot reach a legal sequence that steps down. It must be replaced
  with expansion over the full neighbour set.
- Beam width 50 was chosen against the DAG. It must be **re-validated** against the wider
  space, and the beam-50-vs-150 divergence check (SEQ-10) becomes materially more important.
- **Q1 (order-dependence) gets more likely, not less.** More equal-ranked states compete for
  beam slots, so a tiebreaker derived from array position will break differently under a
  shuffle. The total-order fix — append the track UUID as the final tiebreaker — is now
  **mandatory**, not optional.

### Effect on Phase 9

- **SEQ-03 is REOPENED.** The shipped code enforces the old rule and its tests assert it.
  Both are now wrong and must be replaced with adjacency-window assertions in both directions.
- **SEQ-02, SEQ-04, SEQ-06 stay implemented but must be RE-VALIDATED** under bidirectional
  search — one-track-per-vinyl and the maximise-count objective are unchanged as *rules*, but
  they have never been exercised against a search that can step backwards.
- Phase 9's canonical acceptance case, from the owner's own words: **`170 → 178 → 174`**
  must be produced when the keys make it the better path.

Requirements complete drops from **15 to 14**.

> *Historical figure, correct on 2026-08-30 when this amendment was written and three counts
> out of date now. The live count at Phase 4 close is **23 complete / 44 outstanding / 67 total**,
> re-derived by eight commands that had to agree (plan 04-05, see
> `.planning/phases/04-act-i-signoff/ACT-I-SIGNOFF.md` §5). Re-derive it; do not copy it.*

---

# COMPRESSED ROADMAP — 2026-08-30 (owner decision)

Act I is built. Phases 5–14 are replaced by **six** phases. Rationale in
`.planning/RIGOR-POLICY.md`. Target: completion by end of day.

**The sequencer moves FIRST**, ahead of the engine — owner's decision, and the right one:
it is algorithmic (a DAG traversal becomes a general-graph search), three currently-green tests
defend the rule it retired, and every downstream stage consumes its output. Building the engine
against the wrong sequencer and retrofitting later is the expensive order.

| # | Phase | Merges | Measured acceptance gate |
|---|-------|--------|--------------------------|
| **5** | **The Sequencer, Rewritten** | was 9 | **DELIVERED 2026-08-30.** Bidirectional adjacency `\|Δbpm\| ≤ tol` either direction; a backward step produced when the keys favour it (the owner's literal `170 → 178 → 174` is unreachable at any tolerance — `\|Δ\| = 8` — and a test pins that finding); one track per vinyl; excluded vinyl **rejoins** at IDs `[1, 3, 2]` when a later addition bridges the gap; identical vinyl order across 10 seeded shuffles (Q1, measured 3x); beam 50 never loses records to beam 150 or 400; 100 vinyls / 400 candidates in 1.1 s debug / 0.27 s release |
| **6** | **OCR & Segmentation** ✅ **DELIVERED 2026-08-30** | was 5 + 6 | Both operate on the same 12 fixtures, so they share a harness. **≥ 6 clean / 5 partial / 1 fail** and **≥ 9 of 12** usable track counts. Angle clustering, EXIF orientation, catalogue numbers KEPT not discarded, price stickers filtered (closes V12). **MET, measured twice on real recognition over the twelve photographs: 6 clean / 5 partial / 1 fail, 9 of 12 usable, and 6 of 6 catalogue numbers with 0 invented. V12 CLOSED. `./Scripts/ocr-score.sh` is the gate; `Artifacts/ocr/score-run1.json` and `score-run2.json` are the two observations. See `.planning/phases/06-ocr-segmentation/06-SUMMARY.md`.**
| **7** | **Resolution & BPM Ladder** | was 7 + 8 | One ladder, one phase. Catalogue-number resolution **≥ 5 of 6** with the artist cross-check; SoundCloud match **≥ 72%**; tier-0 hit rate **measured**; vDSP analyser scored against the 29 cached ground-truth tracks — tempo octave-aware, key by Camelot distance |
| **8** | **Wiring & Camera** | was 10 + 11 | Each stub swapped for its real implementation, walk green after each swap; live `AVCaptureSession` capture (device behaviour → UAT) |
| **9** | **Manual Entry & Persistence** | was 12 + 13 | Hand-entry under 15 s measured as tap/keystroke count; a 20-vinyl crate survives terminate-and-reload with a field-by-field diff of 0 |
| **10** | **`vinylctl` & Definition of Done** | was 14 | `vinylctl` prints a real sequenced set from the owner's 12 photographs; MVP-SPEC §9 walked |

## Carried into this compression, unchanged

- **Q1** — sequencer determinism — is Phase 5's gate, not a footnote.
- ~~The retired non-decreasing rule survives in **17 places including executable code** and
  **three** stale tests, one unmarked.~~ **CLOSED by Phase 5, 2026-08-30.** All 17 artefacts of
  `CARRIED-DEBT.md` §2a are gone, including the enforcement itself; hygiene gate G8 now asserts
  their absence structurally rather than counting them in a ledger.
- **V3** stays open pending the owner's answer on U8. ~~**V12** is Phase 6's.~~ **V12 CLOSED by Phase 6 (commit `f980c1a`).** V15 and V16 were also Phase 6's and are RE-CARRIED to **Phase 11** (corrected 2026-08-30 — they said Phase 8, meaning the stub-swap phase, which this roadmap numbers 11): the de-duplication they need is built and measured, but reaches the inspect sheet only when `CaptureView`'s `FixtureLineSegmenter` is swapped, which is Phase 11's per-swap-verified job.
- Act I's phase criterion clause 2 remains **NOT MET** and is not laundered by this compression.
