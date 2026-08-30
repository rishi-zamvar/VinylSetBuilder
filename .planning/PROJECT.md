# Vinyl Set Builder

## What This Is

A personal-use iOS app for one DJ. You photograph the labels of the records in your
crate; the app reads the track listings off them, works out the BPM and musical key of
each track, and orders the whole crate into a set you could actually play — ascending
in tempo, harmonically sensible, one track per record.

It is a crate-digging tool, not a music player. There is no audio in it at any point.
It is not distributed and never will be.

## Core Value

**The sequenced set.** If everything else is clumsy but the app hands back an ordered,
mixable run of records with sane tempo and key transitions that re-optimises when you
add more, it has done its job. Scanning is only the input method.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Capture vinyl labels continuously without waiting on any screen
- [ ] Read track listings off a label photo with on-device OCR
- [ ] Split one label photo into its individual tracks (1–5 per side)
- [ ] Resolve each track to artist, title, BPM and Camelot key
- [ ] Hand-enter or correct any track in under 15 seconds
- [ ] Produce a BPM-gated, Camelot-optimised sequence, one track per record
- [ ] Re-optimise the whole sequence on every record added, including readmitting
      previously excluded records
- [ ] Persist crates on-device across app restarts
- [ ] Run on the physical iPhone 14 Pro under a paid developer account

### Out of Scope

- **aubio / Essentia** — GPL/AGPL C/C++ vendoring for what ~350 lines of Accelerate does.
  Not worth the build complexity for a personal app.
- **AcoustID fingerprinting** — it matches a fingerprint to a *known recording*; it does
  not produce tempo or key, and it needs the audio to already be identified. Music
  Understanding replaces the reason we wanted it.
- **Microphone capture of the record playing** — considered and deferred. It is the only
  route that resolves a dubplate present nowhere online, but it costs ~30s per record with
  the record actually playing, which contradicts the "scan 20 without waiting" goal.
  Revisit if the SoundCloud hit-rate proves too low.
- **YouTube audio extraction** — signature-cipher extraction is fragile and breaks
  constantly, and it analyses a different master than the pressing in hand.
- **Playback** — this builds the set; Rekordbox and the CDJs play it.
- **Cloud sync / accounts / sharing** — single user, single device, no auth.
- **App Store distribution** — personal build. Directly enables bundling API keys.
- **Multiple tracks per vinyl in one sequence** — hard rule. One record contributes
  exactly one track. Non-negotiable in MVP.
- **A VLM or trained model for segmentation** — deterministic geometry first; revisit only
  if it measurably fails on real labels.

## Context

**Prior work this draws on directly.** The CrateDig project already contains a working
Camelot-distance function and BPM-gated transition-graph sequencer in Python. That logic
ports to Swift; the librosa/allin1 audio half has no role here.

**An unusually good local data source exists.** `walkman-dj/data/library.db` holds 7,098
recordings, of which **7,010 have both a BPM and a Camelot key** — DSP-derived from the
owner's own collection, in the same jungle/DnB/garage genres as the vinyls being scanned.
Pruned and deduplicated to `(artist, title, bpm, camelot)` this is an **880 KB** read-only
SQLite (6,608 unique rows) that bundles into the app for instant offline resolution with
zero network calls. This is tier 0 of the resolution ladder.

**Caveat, measured not assumed:** the corpus skews house/techno, not jungle. Only 12% of it
sits in the 160–184 BPM band; 55% is 100–139. The genre column is empty throughout, so tempo
is the only proxy available. Tier 0 is worth bundling because it is free and instant, but the
real resolution load will fall on the SoundCloud → Music Understanding tier and on manual
entry. Measure the true tier-0 hit rate early rather than planning around an optimistic one.

**The records are the hard part, not the code.** The collection is heavy on white labels
and dubplates. These are frequently absent from Discogs and MusicBrainz entirely. No
amount of OCR accuracy or model quality fixes a record that does not exist in any
database. Manual entry is therefore a first-class path and must be fast, not an error
state.

**Credentials already on this machine.** Discogs token at `~/.config/keys/enrich.env`.
MusicBrainz needs no key, only a User-Agent. GetSongBPM key being registered against
the public repo as the mandatory backlink.

**Test fixtures come from the user.** Real vinyl label photographs are supplied directly
into the Claude Code session and committed as the golden fixture set. Phase ship criteria
(track-count accuracy, auto-resolve rate) are measured against these, not against
synthetic images.

## Constraints

- **Tech stack**: Swift only, SwiftUI, **iOS 26**. No Python runtime, no embedded interpreter.
  URLSession covers every API call.
- **iOS 26 deployment target is deliberate**: it is what the installed toolchain
  (Xcode 26.0.1, iOS 26 SDK) can actually build. **Nothing in the project may depend on an
  SDK that is not installed.** The modern Swift-native Vision `RecognizeTextRequest` is
  iOS 18+, so it remains available. Apple's Music Understanding framework needs iOS 27 and
  is therefore NOT used — see the audio-analysis constraint below.
- **OCR**: Apple Vision, `.accurate` recognition level. On-device, free, no model bundling,
  no network. At the iOS 26 target the Swift-native `RecognizeTextRequest` (iOS 18+) is
  available and preferred over the older `VNRecognizeTextRequest`.
- **BPM + key**: the app's **own Accelerate/vDSP analyser**, on-device and offline —
  tempo via onset envelope + autocorrelation, key via chromagram + Krumhansl-Schmuckler
  profile matching, mapped to Camelot. No API key, no rate limit, no third-party licence.
  It sits behind an `AudioAnalyzing` protocol so Apple's Music Understanding can replace it
  as a drop-in when Xcode 27 ships, without touching any caller.
- **Persistence**: SwiftData, on-device only.
- **Device**: iPhone 14 Pro, paid Apple Developer account, 1-year provisioning.
- **Public repo**: the repo is public. (It was made public for a GetSongBPM backlink that is
  no longer needed, but it stays public.) Therefore **no secret may ever be committed** —
  keys are generated into a gitignored `Secrets.swift` at build time from `~/.config/keys/`,
  compiled into the binary as intended, never in version control. The bundled BPM corpus and
  the fixture photographs are likewise gitignored.
- **Rate limits**: Discogs 60 req/min authenticated. Max 3 concurrent requests, backoff
  on 429.
- **API call frugality**: resolution must climb the ladder — bundled corpus → local cache →
  free-unlimited (MusicBrainz) → free-limited (Discogs, SoundCloud). Never call a
  quota-limited source for a datum available cheaper.
- **Build toolchain**: Xcode 26.0.1 / iOS 26 SDK, macOS 26.6.2. Verified by
  `xcodebuild -showsdks`. `MusicUnderstanding.framework` is absent from both the SDK and the
  running system — checked, not assumed. **No phase may be planned against an unavailable SDK.**

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Camelot distance = flat hop count, +1 for letter change | No extra letter penalty until a real set actually sounds wrong. Tuning a problem not yet heard. | — Pending |
| `BPM_TOLERANCE` default 4.0, slider 3–6 | As specified; tune against real sets. | — Pending |
| Fold `bpm < 100` to `bpm * 2` unconditionally | Jungle/DnB-only app; an 87 BPM read is a 174 BPM track. Skipped a genre-aware normalizer. | — Pending |
| One bucket for unresolved + excluded, each row carries a `reason` string | Two UI sections buy nothing the reason string doesn't already say. | — Pending |
| Sequencer = beam search, width 50. No exact DP attempt. | "Visit each vinylID at most once" makes exact DP exponential. The spec's own fallback is the right answer at crate scale. | — Pending |
| Drop the AcoustID fallback entirely | AcoustID fingerprints audio. This app has no audio. The branch is dead by construction. | — Pending |
| Bundle a pruned `walkman-dj/library.db` as tier-0 resolution | 7,010 rows with both BPM and Camelot, same genres, free, offline, zero latency. Strictly better than an API call. | — Pending |
| Keys in gitignored generated `Secrets.swift`, not committed | Repo must be public for the GetSongBPM backlink; keys still compile into the binary as requested. | — Pending |
| Paid Apple Developer account | 1-year provisioning, no weekly re-sign friction. | — Pending |
| ~~Target iOS 27; use Apple Music Understanding~~ | **REVERSED 2026-08-29.** `MusicUnderstanding.framework` is absent from the installed SDK *and* the running system (macOS 26.6.2, Xcode 26.0.1) — verified, not assumed. It needs Xcode 27, which is not available. Planning against an SDK you do not have is planning a blocker. | ✗ Reversed |
| **Target iOS 26; write our own Accelerate/vDSP audio analyser** | It is what the installed toolchain can build, today, with no blocker. Tempo = onset envelope + autocorrelation; key = chromagram + Krumhansl-Schmuckler → Camelot. Bounded (~350 lines) and — decisively — **we already hold the oracle**: 29 tracks with known BPM + Camelot and their audio cached, so it is TDD against real ground truth rather than guesswork. | — Pending |
| **Audio analysis sits behind an `AudioAnalyzing` protocol** | Music Understanding becomes a drop-in replacement the day Xcode 27 arrives, with no caller changed. The reversal above costs us nothing permanent. | — Pending |
| **SoundCloud is the audio source for analysis** | Working OAuth already proven in CrateDig. Jungle/DnB promos and white-label rips live there precisely when they have no Discogs entry. Fetch → analyse → discard. | — Pending |
| **Drop GetSongBPM entirely** | Its mandatory backlink cannot be satisfied: GitHub does not server-render READMEs, and GitHub Pages cannot build because Actions is disabled at the account level. Music Understanding removes the need. | — Pending |
| **Spotify ruled out empirically** | `/v1/audio-features` returns 403 for the owner's credentials — the client is not grandfathered past the Nov 2024 deprecation. Tested, not assumed. | ✓ Good |
| **Sequencer is the product; OCR is commodity** | VinylBPM already ships label OCR → Discogs → Camelot on the App Store. Nothing models one-track-per-physical-record with re-optimisation. Effort goes to the sequencer. | — Pending |
| **Non-decreasing BPM is a documented ceiling, not a truth** | Real sets arc (warm-up → peak → cool-down). Monotonic BPM is kept for MVP because it makes the DAG tractable, and recorded as a known simplification to revisit. | — Pending |
| **Segment by baseline ANGLE, not radial distance** | Measured on 12 real fixtures: the record sits rotated relative to its sleeve, so each physical surface forms its own baseline-angle cluster (e.g. −90° sleeve vs +150° label). Separates label from sleeve with no centre detection, no circle finding, no polar unwrapping. Simpler than spec §4 and more robust. | ✓ Good — validated on fixtures |
| **The captured unit is a SLEEVE, not a label** | The owner photographs whole 12" sleeves flat; the label is a small die-cut circle under 10% of frame. Best text is large horizontal sleeve type, and one photo commonly captures both sides (`A:` / `AA:`). Concentric-text risk is largely absent for this collection. | ✓ Good — validated on fixtures |
| **Catalogue numbers are a primary resolution key, not noise** | Read cleanly on 6 of 12 fixtures (`TYME 012`, `tech008`, `CSI 006`, `EMF2029`, `0-44904`). Far more discriminating than artist+title for white labels. Spec §4 discards them; that is backwards. | — Pending |
| **Pass EXIF orientation to Vision explicitly** | `VNImageRequestHandler(cgImage:options:)` ignores it. All fixtures are orientation 6; passing it turned `ENICATTONAPE` into `EDUCATION` and surfaced `SIDE A` / `A: High Down` / `AA: Strange Nature`. Coordinates still return in the original unrotated space — transform exactly once. | ✓ Good — bug found and fixed in spike |
| **Do not build polar unwrapping for curved text** | Concentric label text barely appears in this collection. Deferred, probably permanently. | — Pending |
| **Core/app package split** | Segmentation + sequencing live in a Swift package that never links AVFoundation or URLSession, making "no camera, no network in tests" a compile-time fact. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-29 after research — pivoted to iOS 27 + Music Understanding*
