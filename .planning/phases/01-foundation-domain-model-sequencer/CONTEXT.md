# Phase 1: Foundation, Domain Model & Sequencer — Context

**Gathered:** 2026-08-29
**Status:** Ready for planning
**Source:** Locked decisions in PROJECT.md + measured spikes in `.planning/research/`

## Why research was skipped

`--skip-research` was deliberate. This phase has no open technical unknowns:

- The Swift-side questions (SwiftData ordering, package split, bounded concurrency,
  GRDB bundling) are already answered in `.planning/research/STACK.md`.
- The algorithm is a **port of working, tested Python the owner already wrote**, not a
  design problem. Port source identified below.
- The project's remaining unknowns (Music Understanding accuracy) belong to Phase 4.

## Port source — do not reinvent

| Swift target | Port from | Notes |
|---|---|---|
| `Camelot` type, `to camelot(pitch:mode:)` | `walkman-dj/src/walkman_dj/camelot.py` | Canonical `_MAJOR`/`_MINOR` tables. **Independently cross-checked** — the tables written into `Tools/mu-validate.swift` agree with it exactly. |
| Camelot distance | Derive from `camelot_edge_ok` in the same file | That function is a *gate*; this project needs a **distance**. Flat hop count + 1 for a letter change, per locked decision. |
| BPM window / delta | `walkman-dj/src/walkman_dj/distance.py` (`bpm_distance`, `bpm_window`) | Reference only — this project's gate is a fixed tolerance, not a percentage window. |
| Sequence assembly reference | `walkman-dj/src/walkman_dj/dj_sets.py` (`compat`, `try_insert`, `order_clean`) | Reference only. That code has no one-track-per-vinyl constraint, which is this project's whole point. |
| Camelot test cases | `walkman-dj/tests/test_rekordbox_import.py` | Reusable assertions: `Am → 8A`, `C → 8B`, `F#m → 11A`, `Ebm → 2A`, and nil on garbage. |

## Locked decisions (do not re-open)

1. **Camelot distance** = flat hop count around the 12-ring, `+1` for a letter change.
   Same key 0. Relative major/minor 1. No extra letter penalty.
2. **BPM gate** — `|bpm[i+1] − bpm[i]| ≤ BPM_TOLERANCE`, and BPM is **non-decreasing**.
   Default 4.0, user slider 3–6.
   Recorded as a **known ceiling**: real sets arc (warm-up → peak → cool-down). Monotonic
   BPM is kept for MVP because it makes the DAG tractable. It is a simplification, not a truth.
3. **One track per `vinylID`** in a sequence. Non-negotiable.
4. **Objective** — maximise vinyl count first; tie-break on minimum total Camelot distance.
5. **Beam search, width 50**, plus a divergence check against a wider beam (e.g. 150).
   **Do NOT implement exact DP as the primary approach** — the visited-vinyl set makes it
   exponential. If the two beam widths disagree, that is the signal to revisit.
6. **Half/double-time fold** — `if bpm < 100 { bpm *= 2 }`, unconditional. Jungle/DnB only app.
7. **One bucket** for unresolved + excluded, each row carrying its own `reason` string.
   Not two UI sections.
8. **Core package links neither AVFoundation nor URLSession** — this makes "tests need no
   camera and no network" a compile-time fact rather than a convention.
9. **Ordered data uses explicit scalar arrays / `position: Int`**, never `@Relationship`
   to-many order. SwiftData does not preserve relationship order.
10. **Secrets** generate into a gitignored `Secrets.swift` via an Xcode **Run Script build
    phase** (not an SPM plugin — plugins are sandboxed and cannot read `~/.config/keys/`).

## Build-toolchain reality (constrains this phase)

Xcode **26.0.1**, **iOS 26 SDK only**. `MusicUnderstanding` cannot be linked yet.

- The app target builds against **iOS 26** for now; the bump to 27 is tracked as
  `DEFERRED.md` D1/D2 and is Phase 4's job.
- The **Core package is pure Swift** and builds/tests with `swift build` / `swift test`
  today — no Xcode beta, no simulator runtime, no device.
- Therefore: **all 11 SEQ requirements are fully testable in this phase, right now.**
  This is the phase's main leverage and should be exploited, not deferred.

## Claude's discretion

- Package/module naming, file layout within the Core package.
- Whether the beam-search divergence check (`SEQ-10`) is a test-only harness or a runtime
  assertion — either satisfies the requirement.
- SwiftUI view decomposition and navigation mechanism for the crate screens.
- Fixture-data shape for the Phase-1 stubbed resolver, provided it exercises the
  excluded/unresolved path and the rejoin-on-add behaviour, not just the happy path.

## Requirements in scope (22)

`SETUP-01..04`, `SEQ-01..11`, `CRATE-01..07`

## Success bar

The sequencer must be provably correct in isolation — including the case the whole app
exists for: **a previously excluded vinyl rejoining the sequence when a later addition
bridges the BPM gap** (`SEQ-08`). If that has no test, this phase is not done.
