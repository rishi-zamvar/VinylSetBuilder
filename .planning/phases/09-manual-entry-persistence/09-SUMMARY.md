---
phase: 09
plan: 09
subsystem: manual-entry-and-persistence
tags: [MAN, PERS, V19, SwiftData, exclusion-reason]
requires: [08]
provides: [MAN-01, MAN-02, MAN-03, MAN-04, MAN-05, PERS-01, PERS-02, PERS-03, PERS-04, BPM-07, V19]
affects: [CrateRows, BeamSearchSequencer, BPMLadder, TrackResolver, CrateStore, CrateDetailView, AppModel]
tech-stack:
  added: [SwiftData]
  patterns: [value-types-in-core-model-classes-in-app, full-rewrite-persistence, scalar-order-arrays]
key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/ExclusionReason.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Correction/ManualEntryDraft.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateDump.swift
    - App/Persistence/CrateRecords.swift
    - App/Persistence/CrateArchive.swift
    - App/Persistence/LaunchOptions.swift
    - App/Views/ManualEntrySheet.swift
    - UITests/ManualEntryUITests.swift
    - Scripts/persistence-check.sh
    - Artifacts/persistence/dump-1.txt
    - Artifacts/persistence/dump-2.txt
  modified:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Presentation/CrateRows.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/Track.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Resolution/TrackResolver.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/BPM/BPMLadder.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift
    - App/AppModel.swift
    - App/Views/CrateDetailView.swift
    - App/Views/NotIncludedSectionView.swift
decisions:
  - "Exclusion reason is derived from the terminal state in CrateRows, not passed through from whichever layer spoke last"
  - "One representative candidate serves the badges, the reason and the edit target — the contradiction becomes unconstructible"
  - "MAN-04 is three field-level ?? guards on Track.isManual, including the failure path, not a blanket skip"
  - "Core holds no @Model and never names the persistence framework; the records live in the app target"
  - "Persistence save is a full rewrite, guarded on the crate array actually changing"
  - "PERS-01 is measured by simctl terminate plus a canonical field-by-field dump diff, not by an XCUITest terminate alone"
metrics:
  duration: ~2h40m
  completed: 2026-08-30
---

# Phase 9 Plan 09: Manual Entry & Persistence Summary

Hand entry became the load-bearing path it was already being used as, crates now survive being
killed with a 730/730-line zero diff, and V19 is closed with the invariant asserted in code.

## The measured acceptance gate — every number

| # | Gate | Required | **Measured** | Verdict |
|---|---|---|---|---|
| 1 | **MAN-01** as an interaction count | under 15 s, cost model stated | **8 taps + 16 keystrokes + 1 sheet = 13.3 s** (wall clock 16.3 s in the harness) | **MET**, twice |
| 2 | **MAN-04** proven by test | real resolution runs over a manual track and does not overwrite | real `TrackResolver` + real `BPMLadder` vs contradicting stubs, 5 tests, field by field | **MET** |
| 3 | **PERS-01** | 20 vinyls, `simctl` kill, relaunch, field-by-field diff == 0 | **730/730 lines, 0 differing. 20 vinyls.** | **MET** |
| 4 | **V19** | closed, invariant asserted | four strings reachable, `assert` in `CrateRows.make`, photographed | **MET** |
| 5 | Regression | everything green | `test.sh` **353**, `hygiene.sh` **9 pass 0 fail**, `ui-test.sh` **9/9 at totalTestCount=9**, `build-app.sh` **SUCCEEDED** | **MET** |

Supporting numbers, all printed by the run rather than asserted from memory:

| What | Measured |
|---|---|
| MAN-03 prefill on screen | `170` — a real neighbour tempo, asserted non-empty and numeric |
| MAN-02 taps for a key | **1**, out of 24 |
| MAN-05 bucket edit | 5 taps + 6 keystrokes = 7.3 s, and the record **rejoined**: running order **2 → 3** |
| PERS-03 across the kill | **47 candidates survived, 20 selected, 27 UNSELECTED** |
| MAN-04 across the kill | **12** `.manual` marks survived |
| V19 on screen, live data | the regenerated `03-walk-07-done-sequenced.png` — **three of the four terminal causes in one frame**, on the owner's own twelve photographs |
| Test suite | 315 → **353** |
| Requirements | 55 → **65 of 67** |

### MAN-01: the cost model, so the 15-second claim is reproducible

Measured as a **count**, because a stopwatch on a simulator measures the simulator. The wall
clock is reported too, and it is *higher* than the costed figure — 16.3 s — because XCUITest
pays an accessibility-snapshot round trip on every query and a person does not. The count is the
claim; the wall clock is a sanity check on it, and it is reported rather than hidden.

| Interaction | Cost | Basis |
|---|---|---|
| tap on a control already on screen | 1.0 s | the **top** of the 0.6–1.0 s band, deliberately |
| keystroke on the software keyboard | 0.3 s | ≈40 wpm, conservative against typical thumb typing |
| sheet presentation | 0.5 s | the animation, waited through once |

**The full four-field correction:** open the row (1) · tempo +1 (1) · key (1) · clear artist (1) ·
tap artist (1) · type `Hand Typed` (10) · clear title (1) · tap title (1) · type `By Ear` (6) ·
Save (1) = **8 taps, 16 keystrokes, 1 sheet → 13.3 s.**

**Honest ceiling, stated because it matters:** the budget is dominated by *typing*, not by the
sheet. At 0.3 s/keystroke, an artist-plus-title of about 32 characters puts the total at 15 s on
its own. Everything the sheet controls — the taps — costs 8.0 s and the design cannot make a
person type faster. The realistic case is far cheaper: on the records this sheet is actually
opened for, the artist is unknowable and only the tempo and key get supplied, which is the
**5 taps + 6 keystrokes = 7.3 s** measured on the bucket path.

Two design changes came out of measuring this rather than guessing it, both real fixes:

- **Save moved from a bottom bar into the header.** A bottom bar sits under the software
  keyboard, so committing an edit would have cost an extra tap to dismiss the keyboard first.
- **A one-tap clear button per text field.** The field arrives holding whatever the resolver
  guessed, and a confident wrong guess is the common case without a catalogue number. Deleting it
  by hand costs one keystroke per character: **8 taps + 40 keystrokes = 18.5 s, over budget.**
  With the clear button, 16 keystrokes and 13.3 s. It is the single cheapest thing in the sheet.

## V19 — closed, and the root cause was structural

**The reported symptom** was a wording problem: a row showing 136 BPM and 4B labelled
`"no SoundCloud upload matched"`. **The actual cause was in the source, not the string.**
`CrateRows.bestKnownBadges` picked the candidate with the **highest known BPM**, while
`CrateRows.reason` picked the **first candidate carrying any `failureReason`**. On a
multi-candidate record those are two different tracks — so the badges described one candidate and
the sentence described another. Both halves are fixed:

- **Structural.** One `representative` candidate, chosen once, now serves the badges, the reason
  **and** the edit target (`NotIncludedRow.trackID`). The contradiction is unconstructible, not
  merely corrected.
- **Behavioural.** The reason is derived from the terminal state.

**The closing evidence is the frame V19 was filed against, regenerated from the same live
twelve-record run.** `03-walk-07-done-sequenced.png` now reads:

| Row | Badges | Reason |
|---|---|---|
| The Accidental Heroes — Dragstar | `136` `4B` | *No track within 4 BPM of the set* |
| Cause 4 Concern — High Down | `160` `—` | *No track within 4 BPM of the set* |
| Vinyl 1 | `—` `—` | *No SoundCloud upload matched* |
| Vinyl 5 | `—` `—` | *No identity to look up* |

Every row carrying a BPM badge names the tempo window and no row without one does — the invariant
holding on the owner's own records, not only on fixtures. The DJ can now tell "go and type this
one in" from "this one just does not fit", which is the distinction SEQ-07's single bucket was
collapsed on the strength of.

**Deviation from the ledger's literal numbering, and why.** The ledger lists the precedence
1, 2, 3, 4 "most specific first". Taken literally as a cascade that makes rows 3 and 4
**unreachable** — every case in them also has no BPM, so row 1 would swallow them. The invariant
the ledger actually demands (`bpm != nil` ⇒ reason 2) is what fixes 2 above 1; 3 and 4 are the
*specific* causes and 1 is the generic fallback. Evaluation order is therefore **2 → 3 → 4 → 1**,
all four strings are reachable, and `ExclusionReasonTests` has a test proving none of the four is
dead. All four strings appear verbatim as specified.

**The invariant, asserted.** `CrateRows.make` runs an `assert` over every row set it builds:
a row whose BPM badge is not the placeholder must carry the tolerance-window sentence.
**Negative control, measured:** reverting `reason()` to first-note-wins makes the assert trap the
whole test run with `V19 INVARIANT BROKEN: Vinyl 1 [136] says No SoundCloud upload matched` —
the exact screenshot defect, now unshippable rather than merely fixed.

**One definition of the words.** `ExclusionReason` holds all four sentences and the tolerance
formatting; `BeamSearchSequencer`'s private `formattedTolerance` duplicate was deleted and the
`BPMLadder`'s sentences were recapitalised, so a bucket row reads the same whichever layer wrote
it.

**V19 also exposed a gap in the ledger's own gate.** It had been filed **below** the
machine-readable section, and `Scripts/ledger-check.py` parses the human table only from the text
**above** that heading — so gate G9 reported "18 rows" and was structurally blind to the
nineteenth. V19's row was moved above the heading and both V19 and the new V20 are now in the
machine-readable block. G9 reports **20 rows, 13 closed, 7 carried, 1 Medium-or-above open** —
the Medium count went 2 → 1 because V19 closed.

## MAN-04 — the bug class that destroys a user's work

Not a flag check. The gate runs the **shipping** `TrackResolver` and the **shipping** `BPMLadder`
against stubs that answer with a different value for **every** field (`AUTOMATIC ARTIST`,
`AUTOMATIC TITLE`, 199 BPM, `12B`), so an overwrite is unmissable rather than a plausible-looking
near-match. Three guards, all keyed on one predicate `Track.isManual`:

| Where | Guard | Why it was needed |
|---|---|---|
| `TrackResolver.assign` | `track.artist ?? automatic`, state stays `.manual` | the direct overwrite |
| `TrackResolver.failed` | a lookup that finds nothing leaves the track alone | **the subtle one.** White labels and dubplates are in no database — which is *why* somebody typed them in — so the failure path is the one a hand-entered record actually travels. Stamping `.failed` there would drop the mark and let the *next* pass overwrite everything this one respected |
| `BPMLadder.applied` | `track.camelot ?? analysed` | a typed tempo was already safe (`fill` returns early on `bpm != nil`); the key was not |

Five tests: fully typed survives untouched, half-typed has **only** its gaps filled, a non-manual
track is still freely rewritten (this is what proves the guard keys on the mark rather than being
unconditionally broad), the failure path keeps the mark, and `isManual` is exactly `.manual`.

**Negative control, measured:** dropping the title guard makes the full-entry test read
`AUTOMATIC TITLE`; dropping the key guard makes the half-entry test read `12B`.

**And it survives the kill:** 12 `.manual` marks came back off disk after `simctl terminate`. Had
the state not persisted, hand entry would have been protected only until the app closed — which
is the same as unprotected, because the automatic pass runs on the *next* launch.

## The Core / storage boundary, as drawn

| Layer | Owns | Forbidden |
|---|---|---|
| `VinylSetBuilderCore` | `Crate` / `VinylEntry` / `Track` as pure `Codable` values; `position: Int` on vinyl and track; `manualOrder: [UUID]` and `selectedTrackByVinyl` as **plain scalars**; `CrateDump` | naming any persistence framework — **even in a comment**; holding a `@Model`; any I/O |
| `App/Persistence` | the three `@Model` record classes, the container, and the two mapping functions | holding a rule. A mapping function that decides anything is a rule in the wrong layer |

`CorePurityTests` scans Core's sources for the framework name as a **substring, comments
included**, so the boundary is enforced by the build rather than by discipline. Three rules, each
paid for by a documented gotcha rather than a preference:

1. **Order is never a relationship's job.** A to-many relationship is backed by an `NSSet`.
   `position: Int` on both levels plus `listPosition: Int` on the crate; sorted at the call site.
2. **Ordered *references* are scalar arrays.** `manualOrder` is `[UUID]` stored as one attribute.
   CRATE-07's selection is flattened to **one** `[String]` of `"vinyl:track"` pairs, not two
   parallel arrays — parallel arrays can desynchronise and a desynchronised selection silently
   pins the wrong track.
3. **Parent into the context before the children**, every relationship `Optional`, a default on
   every stored property.

`ponytail:` save is a **full rewrite**, guarded on the crate array actually changing so
navigation does not write. An upsert would have to reconcile three levels of identity, cascade
deletes and relationship reattachment; every merge bug it could have is a bug that silently loses
a hand-typed record. Revisit when a crate list outgrows a phone screen. A container that will not
open degrades to **in-memory** rather than bricking the app, and says so via `isPersistent`.

## PERS-01, measured properly

`CrateDump` is the instrument, and it was **checked before it was trusted** — seven of its own
tests. It exists rather than a `JSONEncoder` call for three reasons: dictionaries and sets iterate
in an order that is not stable **between processes**, and this file is compared between processes;
"field-by-field diff == 0" needs the diff's unit to *be* a field; and order is data, so crates,
vinyls and tracks are printed in **stored order and** with their `position`, making "lost the
array order" and "lost the ordering field" two different diffs.

`Scripts/persistence-check.sh` drives the **already-installed** app and never invokes
`xcodebuild`: launch with `vsb-seed20 vsb-dump=1` → **`simctl terminate`** → launch with
`vsb-dump=2` → `diff`. `XCUIApplication.terminate()` is the harness asking; `simctl terminate` is
the OS killing the process, which is what the requirement says. The XCUITest makes the same claim
through the harness — **two independent observations of the headline number.**

The gate also asserts there was something to survive: "nothing survived" and "everything survived"
both give a zero diff if nobody counts. **Negative control, measured:** relaunching with a wipe
instead of a load gives **862 differing lines and 1 vinyl** — both assertions catch it.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 – Bug] `TrackResolver.failed` stripped the `.manual` mark**
- **Found during:** Task 2, by the MAN-04 test failing on `resolutionState == .failed`
- **Issue:** a lookup that found nothing downgraded a hand-entered track to `.failed`, so the
  protection lasted exactly one automatic pass — on precisely the records it exists for
- **Fix:** `guard !track.isManual else { return track }`, plus a fifth test
- **Commit:** `9c1084b` (GREEN commit for MAN-04)

**2. [Rule 1 – Bug] the keyboard accessory bar ate every tap on the field below the focused one**
- **Found during:** Task 6, first UI run — XCUITest reported *"neither element nor any descendant
  has keyboard focus"* against a title field that was plainly on screen
- **Issue:** `ToolbarItemGroup(placement: .keyboard)` renders directly above the keyboard, which
  on this sheet was exactly over the title field and its clear button
- **Fix:** removed it. `.scrollDismissesKeyboard(.interactively)` covers dismissal, and Save
  moved into the header where the keyboard cannot reach it
- **Commit:** `2db3a80`

**3. [Rule 1 – Bug] the sheet titled itself "New track" for an existing record**
- **Found during:** reading `09-manual-04-sheet-from-bucket.png`
- **Issue:** a resolved record carries no OCR text, so the header fell through to a literal that
  says the record does not exist
- **Fix:** fall back to `displayName`, which has its own `"Unknown track"` floor. Screenshots
  regenerated; the header now reads `Dillinja — Angels Fell`
- **Commit:** the closing docs commit of this phase

**4. [Rule 2 – Missing critical functionality] every UI test now launches through `launchFresh()`**
- **Issue:** persistence made launches sticky. The crate walk deletes every crate at the end,
  which was free while nothing persisted and would have poisoned the next run
- **Fix:** `XCUIApplication.launchFresh()` adds the `vsb-reset` token. Bare tokens rather than
  `-flag` pairs, because iOS parses any `-`-prefixed argument into `UserDefaults`

**5. [Rule 2] gate G6 caught this summary's own sibling** — a doc comment in `ManualEntrySheet`
naming `VinylEntry.label` to explain why it is *not* used tripped the substring gate. Reworded.
The gate was right: it cannot tell an explanation from a use.

### Contract changes, made deliberately

**`ResolutionTriggerTests`' D7 verbatim pass-through is superseded once a tempo is known.** D7
said the row prints the sequencer's words verbatim. That was right while the reason had one
upstream author; the app now has three that can speak about the same record, and verbatim
pass-through is exactly what let a stale sentence describe a state established elsewhere. The
reasoning is kept in the test body, not just here. D7 survives untouched wherever the terminal
cause is genuinely unknown.

**A RED expectation was wrong and was corrected during GREEN:** the median of
`[141, 172, 174, 176]` is 172, not 174. The test had asserted the wrong number against its own
stated rule.

## Disk

The machine was in a worse state than the brief described.

| Point | Free |
|---|---|
| Phase start | **5.0 GB** (brief said ~5.6) |
| After the first `build-app.sh` | **1.3 GB** — under the 3 GB floor |
| After `rm -rf build` + all DerivedData | 1.5 GB — **cleaning was not enough** |
| After `simctl erase` of the test device + regenerable dev caches | **7.8 GB** |
| Phase end | **14 GB** |

The data volume is 429 GB of 460 used, which is the owner's, not this project's. The lever that
actually worked was erasing the simulator device (3.6 GB in one device container); `rm -rf build`
and DerivedData together freed 200 MB. **No two `xcodebuild` invocations ever ran concurrently**,
and `build/` plus DerivedData were purged before every UI run.

## What FAILED, and what is not claimed

- **Nothing in this phase failed its gate.** Two UI-test runs failed on the way and both were
  real product bugs, fixed and recorded above; they are not being reported as passes.
- **The wall clock exceeds the costed figure** (16.3 s against 13.3 s). It is reported rather
  than buried. The count is the claim and the reason for the gap is stated.
- **The 15-second budget is typing-dominated** and a long artist-plus-title exceeds it. Said
  plainly rather than measured on a conveniently short string and left there.
- **CAP-04 and SEQ-05 remain open** — 65 of 67. CAP-04 is device-only (memory and thermals) and
  lives in `UAT-PENDING.md`; SEQ-05, the tolerance slider, was not in this phase's requirements.
- **V20 filed and carried, not fixed:** the sheet leaves roughly half the screen empty.
  Informational, owner Phase 14, reasoning written down — a full-height sheet with content at the
  top is ordinary iOS and both alternatives are worse.
- **No device run.** Everything here is the simulator and the signing-free device-SDK build.

## Commits

| Commit | What |
|---|---|
| `dfcc547` | plan |
| `a1f8e62` | RED — V19 |
| `760f386` | GREEN — V19, the terminal cause + the asserted invariant |
| `b27ff3a` | RED — MAN-04 against the real resolver and the real ladder |
| `9c1084b` | GREEN — MAN-04, three field-level guards |
| `fab1d1b` | RED — MAN-01/02/03 |
| `289a4d4` | GREEN — `ManualEntryDraft` + `CrateStore.updateTrack` |
| `108b2a9` | `CrateDump`, PERS-01's instrument |
| `e50315d` | the sheet on both lists + SwiftData persistence |
| `2db3a80` | the UI walk and the `simctl` persistence gate |
| *(this commit)* | sheet title fix, V19 closed in the ledger, V20 filed, requirements, roadmap, this summary |
