---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 02-04-PLAN.md
last_updated: "2026-08-30T08:22:27.179Z"
last_activity: 2026-08-30
progress:
  total_phases: 14
  completed_phases: 0
  total_plans: 13
  completed_plans: 10
  percent: 77
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29) and .planning/ROADMAP.md (rebuilt 2026-08-30)

**Core value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

**Current focus:** Act I, Phase 2 — The Crate Screens, Stubbed. Four of its nine requirements
already landed during Phase 1's plans; CRATE-03/04/05 (the crate detail screen, manual
reorder, Add More) are what remains before Act I can continue.

## The shape of the work

Three acts, strictly linear, no interleaving:

| Act | Phases | What it is | Act ship criterion |
|---|---|---|---|
| **I — The shell you can walk** | 1–4 | Every screen navigable in the simulator on stubbed fixture data | Committed settle-delay screenshots of every screen |
| **II — The engine, headless** | 5–9 | OCR → segmentation → identity → BPM/key → sequencing, pure and testable | A measured number per phase, never a green tick |
| **III — The wiring** | 10–14 | One stub swapped at a time, then persistence, manual entry, `vinylctl` | The app runs on real data; `vinylctl` prints a real sequenced set |

## Current Position

Act: I of III
Phase: 2 of 14 (The Crate Screens, Stubbed)
Plan: 02-04 complete (of 5 planned for Phase 2 — 02-05 remains)
Status: In progress
Last activity: 2026-08-30

Progress: [████████░░] 77%

**Requirements:** 67 total, 67 mapped, 19 complete, 48 outstanding.

> CRATE-03/04/05 are checked off at the **Core value-type** layer (plan 02-01). The
> crate detail screen that makes them user-visible is plan 02-03; the phase does not
> ship until its XCUITest walk and 15 screenshots are green.

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

### Pending Todos

- Re-file the interrupted WIP test `.planning/open-questions/RejoinTests.swift.wip` as a
  proper seeded-shuffle determinism test when Phase 9 opens.

### Blockers/Concerns

- **Q1 — the sequencer may be order-dependent.** The beam's rank tuple ends in
  `start-index asc`, derived from array position, so a shuffle can change which equal-ranked
  states survive pruning. Because the sequencer re-runs on every vinyl added, this would
  produce *different sets from the same records*. **Phase 9 must answer this**, and if
  confirmed, fix it by making the rank tuple a total order with a position-independent
  tiebreaker (the track UUID). See `.planning/open-questions/Q1-sequencer-determinism.md`.

- **V1 / V2 — visual defects, open.** "1 records" pluralisation, and the whole UI washed out
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

## Session Continuity

Last session: 2026-08-30T08:21:58.813Z
Stopped at: Completed 02-04-PLAN.md
88 -> 113 tests green, V1 pluralisation fixed and closed.
Next: plans 02-02 and 02-03 — the crate detail screen and the XCUITest walk.
Resume file: None
