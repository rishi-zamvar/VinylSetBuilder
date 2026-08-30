# Phase 2 context — The Crate Screens, Stubbed

**Act I — the shell you can walk.** Every crate screen exists, is navigable in the booted
simulator, and renders from `FixtureCrates`. Nothing real behind it.

## What is already green — verify and extend, do not rebuild

| Requirement | Where it lives | Phase 2's job |
|---|---|---|
| CRATE-01 list | `CrateStore.summaries`, `App/Views/CrateListView.swift` | Fix V1 pluralisation; prove on screen |
| CRATE-02 create → capture | `CrateStore.createCrate`, `NewCrateSheet` | Prove on screen |
| CRATE-06 delete crate / remove vinyl | `CrateStore.deleteCrate` / `.removeVinyl` | **`removeVinyl` has no UI yet** — add it |
| CRATE-07 multi-crate membership | `Crate.selectedTrackByVinyl`, `FixtureCrates.sharedVinyl` | **Not visible on screen yet** — make the pin real |
| SEQ-07 one not-included bucket | `CrateRows`, `NotIncludedSectionView` | Render it, screenshot it expanded |
| SEQ-11 BPM/Camelot badges | `TrackBadges`, `BadgePairView` | Render them, screenshot them |

## Genuinely outstanding

**CRATE-03** open a crate → sequenced running order. **CRATE-04** manual reorder overriding the
sequencer. **CRATE-05** Add More re-enters capture for the *same* crate.

## Locked decisions

**D2-1 — The product conflict, resolved: membership is the sequencer's, arrangement is the user's.**
CRATE-04 (manual reorder) and SEQ-08 (full re-optimisation on every add) collide. The rule:

> `apply(_:)` re-derives which tracks are IN the set — always the sequencer's call.
> `manualOrder` re-derives only the ORDER of the ones that are in. Concretely: filter
> `manualOrder` to IDs still present in `result.sequence`, then append newly-sequenced IDs, in
> the sequencer's own order, at the end. One tap restores the computed order.

This is the rule that silently destroys user work if it is wrong. It gets its own tests.

**D2-2 — `selectedTrackByVinyl` is a pin, not a readout.** When a crate has a selection for a
vinyl, only that candidate is fed to the sequencer for that vinyl. This is the only thing that
makes CRATE-07 visible on screen rather than only in a unit test: the shared Photek vinyl shows
*Ni Ten Ichi Ryu* in Friday Warehouse and *The Hidden Camera* in Sunday Chill. A pin naming a
track that is not among the vinyl's candidates is ignored, not trusted.

**D2-3 — No `AsyncSequencer`. Plan 01-05 was never executed.** `AsyncSequencer` and
`BeamDivergenceCheck` do not exist on disk. Phase 2 calls `BeamSearchSequencer` synchronously.
Off-main-thread sequencing is SEQ-09, which belongs to Phase 9. Do not build it here.

**D2-4 — No tolerance slider.** SEQ-05 is Phase 9's requirement, not Phase 2's. `Crate.bpmTolerance`
is read as-is. Do not add a slider; it would put an unowned requirement in this phase.

**D2-5 — `BPMRules.canFollow` stays monotonic.** The bidirectional rewrite (SEQ-03, per
`.planning/SEQUENCER-SPEC.md`) is Phase 9 work and is an algorithmic change to the beam search.
Phase 2 must not touch `BPMRules` or `BeamSearchSequencer`. Every Phase 2 assertion must hold
under whichever sequencer is installed — assert *relationships* (this row is in the running
order, that vinyl is in the bucket), never a hardcoded BPM ordering.

**D2-6 — Core purity is a substring scan.** `AVFoundation`, `Vision`, `UIKit`, `AppKit`,
`SwiftUI`, `SwiftData`, `URLSession`, `URLRequest`, `URLProtocol` must not appear anywhere under
`VinylSetBuilderCore/Sources/` — *including in doc comments*. View state and view logic go in
Core value types; the SwiftUI views stay thin.

**D2-7 — Every plan is autonomous.** No blocking gates, no resume signals. Anything genuinely
needing a human or a physical device is appended to `.planning/UAT-PENDING.md` and the run
continues.

## The ship criterion, measured

1. One XCUITest walks list → create → name → capture → detail → reorder → restore → Add More →
   remove vinyl → second crate → delete crate → empty, unattended, green.
2. **15 screenshots** in `Artifacts/screenshots/`, named `02-walk-01-…` through `02-walk-15-…`,
   each taken after a settle delay. `ls Artifacts/screenshots/02-walk-*.png | wc -l` == 15.
3. V2 is **diagnosed with a number before anything is restyled** — the launch-fade hypothesis is
   ruled out first by an A/B screenshot at t≈0.3 s vs t≈3.0 s, and `.disabled(true)` is ruled out
   by asserting the rows are `isEnabled` and `isHittable`.
4. V1 fixed: `Text("^[\(count) record](inflect: true)")`. The walk asserts the literal
   string `1 record` exists and `1 records` does not.
5. `grep -rn "TODO\|FIXME" App/ VinylSetBuilderCore/Sources/ UITests/` returns zero.

## Verified environment — do not re-derive

- iOS **26**, never 27. `MusicUnderstanding` does not exist. Never reference it.
- Simulator booted: `4B4E1C1F-BED6-4812-9238-C151337265DA` (VSB-Test, iPhone 16 Pro).
- `./Scripts/test.sh` → 88 green today. `./Scripts/build-app.sh` → device-SDK, signing-free.
- `xcodegen` 2.44.1 at `/opt/homebrew/bin/xcodegen`. **No *shared* scheme exists on disk** —
  `VinylSetBuilder.xcodeproj/xcshareddata/xcschemes/` is absent, so any `-scheme` that currently
  works is relying on xcodebuild's autocreation. That autocreated scheme has no test action and
  cannot run a UI test target. Plan 02-02 declares a real one in `project.yml`.
- The physical iPhone 14 Pro **Max** now installs a signed build (see TOOLCHAIN.md). Irrelevant
  to this phase — every Phase 2 gate runs on the simulator — but it means U1 is no longer a
  blanket excuse for an unverified UI.
- `python3` has **Pillow 12.1.1**. ImageMagick is **not** installed — do not reach for `convert`.
