---
phase: 09
plan: 09
title: Manual Entry & Persistence
type: execution
autonomous: true
wave: 1
depends_on: [08]
requirements: [MAN-01, MAN-02, MAN-03, MAN-04, MAN-05, PERS-01, PERS-02, PERS-03, PERS-04, BPM-07]
defects: [V19]
---

# Phase 9 — Manual Entry & Persistence

## Objective

Make the hand-entry path load-bearing, and make a crate survive being killed.

Phase 7 measured the tier-0 corpus at **0 of 35** on this collection and the last end-to-end run
put **8 of 12** records outside the set. Manual entry is therefore not a fallback for a rare
failure — it is the path half this crate takes. It has to be fast enough to use twelve times in a
row: one tap per operation, no dialogs, no modes.

And close **V19**, because the not-included bucket currently names the last ladder rung it touched
rather than the terminal cause, which is the one thing SEQ-07's single-bucket design rests on.

## Context

- `.planning/RIGOR-POLICY.md` — TDD stands, measured gates stand, ceremony is cut
- `.planning/VISUAL-DEFECTS.md` V19 row (line 808) and its "The fix" section (line 823)
- `Artifacts/screenshots/03-walk-07-done-sequenced.png` — V19's evidence
- Core purity forbids the substrings `AVFoundation Vision UIKit AppKit SwiftUI SwiftData
  URLSession URLRequest URLProtocol` anywhere under `VinylSetBuilderCore/Sources`, **including in
  comments**. The persistence types therefore live in the APP target and Core never names the
  framework, not even to say it does not use it.

## The Core / storage boundary, stated up front

| Layer | Owns | May not |
| --- | --- | --- |
| `VinylSetBuilderCore` | `Crate`, `VinylEntry`, `Track` as `Codable` value types; `position: Int` on both `VinylEntry` and `Track`; `Crate.manualOrder: [UUID]` and `selectedTrackByVinyl: [UUID: UUID]` as **plain scalars**, never object relationships; `CrateDump`, the canonical field-by-field text projection | name any persistence framework; hold a `@Model`; do I/O |
| `App/Persistence` | the `@Model` record classes, the container, and the two mapping functions | hold a rule — a mapping function that decides anything is a rule in the wrong layer |

Ordering is by explicit `position` on both sides of the map and sorted **at the call site**, so
nothing anywhere depends on a to-many relationship preserving order (which it does not).

## Tasks

### Task 1 — V19: the exclusion reason names the terminal cause `type=auto` `tdd=true`

**Root cause, measured from the source, not the screenshot:** `CrateRows.bestKnownBadges` picks the
candidate *with the highest BPM*, while `CrateRows.reason` picks the *first candidate carrying any
`failureReason`*. On a multi-candidate vinyl those are different tracks, so the badges describe one
candidate and the sentence describes another. That is the whole defect.

**behavior:** exclusion reason is a pure function of the vinyl's terminal state, in this precedence:

| # | condition | string |
| --- | --- | --- |
| 2 | any candidate has a BPM | `No track within {N} BPM of the set` |
| 3 | no candidate has both an artist and a title | `No identity to look up` |
| 4 | identified, and the ladder recorded why the audio route came up empty | the ladder's own sentence, e.g. `No SoundCloud upload matched` |
| 1 | identified, no tempo, nothing recorded | `No BPM yet — resolve it or enter it by hand` |

**Deviation from the ledger's literal numbering, recorded here rather than silently:** the ledger
lists "no BPM at all" first. Taken literally as a cascade that makes rows 3 and 4 unreachable —
every case in 3 and 4 also has no BPM. The invariant the ledger actually demands (`bpm != nil` ⇒
reason 2) fixes 2 above 1; 3 and 4 are the *specific* causes and 1 is the generic fallback, so the
evaluation order is 2 → 3 → 4 → 1 and all four strings are reachable. All four appear verbatim.

**implementation:**
- new `ExclusionReason` enum in Core: the **one** place all four strings and the tolerance
  formatting live. `BeamSearchSequencer` and `CrateRows` both call it; the private
  `formattedTolerance` duplicate in the sequencer goes.
- `BPMLadder`'s sentences are recapitalised to sentence case so a row reads the same whichever
  layer supplied it (`no SoundCloud upload matched` → `No SoundCloud upload matched`).
- `NotIncludedRow` gains `trackID: UUID?` — the representative candidate — so the badges, the
  reason and (Task 4) the edit target are all about the **same** track by construction. This is the
  structural half of the fix; the precedence is the behavioural half.
- **the invariant, asserted:** `CrateRows.make` runs a `assert` over every row it emits —
  `badges.bpm != placeholder` implies the reason is the tolerance-window sentence — so a
  regression trips in every debug test run rather than being noticed in a screenshot months later.

**verification:** a test that reproduces the exact V19 shape (one vinyl, one candidate at 136 BPM
with a key, a second candidate carrying `failureReason` = the SoundCloud sentence) and asserts the
row reads the window sentence. Plus one test per row of the table. Plus a sweep asserting the
invariant across a generated crate.

**done:** `swift test` green; the four strings each reachable; `ResolutionTriggerTests`' D7
verbatim test updated to the new contract with the reason for the change written down.

### Task 2 — MAN-04: automatic resolution may fill a gap, never overwrite a hand-typed value `type=auto` `tdd=true`

**behavior:** a track at `resolutionState == .manual` keeps every field a person put in it, for
ever, through any number of later automatic passes. Empty fields may still be filled.

**implementation:** two field-level guards, at the only two places the automatic path writes:
- `TrackResolver.assign` — `artist`/`title` become `track.artist ?? release.artist`; the state
  stays `.manual`
- `BPMLadder.applied` — `camelot` becomes `track.camelot ?? analysed` (`fill` already returns early
  when `bpm != nil`, so a hand-typed tempo was already safe; the key was not); state stays `.manual`
- `Track.isManual` as the single predicate

**verification (this is the measured gate, not a green tick):** run the real `TrackResolver` and the
real `BPMLadder` — against stub clients that return *different* values for every field — over
(a) a fully hand-entered track and (b) a half-entered one, and assert field-by-field equality on
what the person typed and only-the-gaps filled on the rest.

**done:** both tests green; a mutation that removes either guard fails them.

### Task 3 — MAN-01/02/03 in Core: the edit as a value `type=auto` `tdd=true`

**behavior:** `ManualEntryDraft` — artist, title, BPM text, Camelot code — built from a track plus
its crate neighbours, applied back onto a track marked `.manual`.

- **MAN-03**: BPM pre-fills. Precedence: the track's own BPM → the **median** of the crate's known
  BPMs → 174. Median rather than mean because one 87 BPM half-time read drags a mean out of the
  genre entirely. 174 is the fallback because this is a jungle collection and an empty field is
  the thing MAN-03 forbids.
- **MAN-02**: `ManualEntryDraft.camelotGrid` — the 24 wheel codes, `1A…12A`, `1B…12B`, as data.
  One tap selects, so the "two taps maximum" bound is met with one to spare.
- `CrateStore.updateTrack(_:in:)` — the one write path for an edited candidate.

**done:** prefill precedence, grid completeness (24, distinct, all parse via `Camelot`), apply
marks `.manual`, and a BPM below 100 folds through `BPMRules.fold` exactly as the badge does.

### Task 4 — MAN-05: the sheet, reachable from both lists `type=auto`

**implementation:** `ManualEntrySheet` presented from a tap on any sequenced row **and** any
not-included row. No mode, no dialog: the row is the button.

- artist and title: plain fields, prefilled
- BPM: prefilled field plus −1/+1 steppers, so the common correction is one tap
- key: the 24-code grid, one tap
- Save commits through `CrateStore.updateTrack` and the crate re-sequences

**done:** `./Scripts/build-app.sh` SUCCEEDED.

### Task 5 — Persistence `type=auto` `tdd=true`

**implementation:**
- Core: `CrateDump` — `[Crate]` to a sorted, canonical, one-field-per-line text projection.
  Deterministic by construction (dictionary iteration order is not), which is what makes
  "field-by-field diff == 0" a real measurement rather than a hope.
- App: `@Model` records for crate / vinyl / track. Every stored property has a default; every
  to-many relationship is `Optional` with an explicit inverse; order is carried by `position: Int`
  and by scalar `[UUID]` arrays, never by relationship order.
- Save is a **full rewrite** on every store mutation. `ponytail:` a handful of crates is not worth
  an upsert diff; revisit if a crate list ever outgrows a screen.
- Launch arguments: `-vsb-reset` (wipe and reseed the fixtures — every existing UI test gets this,
  or the crate walk's final delete-everything step poisons the next run), `-vsb-seed20` (a
  deterministic 20-vinyl crate, several candidates each, only one selected — PERS-03's proof
  material), `-vsb-dump N` (write the canonical dump to the container).
- PERS-04: nothing leaves the device — the container and the bundle are the only paths.

**done:** Core round-trip tests green; `build-app.sh` SUCCEEDED.

### Task 6 — The UI walk `type=auto`

`ManualEntryUITests`: fixture crate → tap a sequenced row → sheet → edit all four fields → save →
assert the row changed; then tap a **not-included** row → sheet → save → assert. Counts every
interaction and prints it, and times the whole edit.

**done:** `./Scripts/ui-test.sh` green with `totalTestCount` ≥ 8. **Run alone. Never concurrently
with another xcodebuild.**

### Task 7 — PERS-01, measured `type=auto`

`Scripts/persistence-check.sh`, driving the **already-installed** app so no second xcodebuild runs:

1. `simctl launch … -vsb-reset -vsb-seed20 -vsb-dump 1`
2. `simctl terminate` — the requirement's own words
3. `simctl launch … -vsb-dump 2`
4. `diff dump-1.txt dump-2.txt`

**done:** 20 vinyls present, unselected candidates present, `diff` reports **0** differing lines.

### Task 8 — Close out `type=auto`

Requirements ticked, V19 closed in the ledger with a re-runnable evidence path, `hygiene.sh` 9/9,
`test.sh` green, SUMMARY written with every number.

## Measured acceptance gate

| # | Gate | Pass condition |
| --- | --- | --- |
| 1 | MAN-01 | interaction count for a full four-field correction, stated with a per-interaction cost, totalling under 15 s; plus the walk's own wall clock |
| 2 | MAN-04 | the real resolver and the real ladder run over a manual track and change nothing a person typed |
| 3 | PERS-01 | 20-vinyl crate, `simctl terminate`, relaunch, canonical dump diff == 0 |
| 4 | V19 | all four strings reachable, invariant asserted in `CrateRows.make` |
| 5 | regression | `test.sh` green, `hygiene.sh` 9 pass 0 fail, `ui-test.sh` green with a non-zero count, `build-app.sh` SUCCEEDED |

## Disk discipline

`df -h /` before and after every UI run. One `xcodebuild` at a time. `rm -rf build` **and**
`rm -rf ~/Library/Developer/Xcode/DerivedData/*` between heavy runs — Phase 8 proved `build/` alone
is not enough, a stale `.xcresult` reported a failure against source that no longer existed.
