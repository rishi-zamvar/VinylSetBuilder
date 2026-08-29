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

- **Audio analysis of any kind** — there is no audio. The app sees photographs of paper
  labels. This also kills the spec's original AcoustID fallback, which fingerprints audio
  and can therefore never fire here.
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
Pruned to `(artist, title, bpm, camelot)` this is a small read-only SQLite that can be
bundled into the app, giving instant offline resolution with zero network calls for a
meaningful share of lookups. This is tier 0 of the resolution ladder.

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

- **Tech stack**: Swift only, SwiftUI, iOS 17+. No Python runtime, no embedded interpreter.
  URLSession covers every API call.
- **OCR**: Apple Vision (`VNRecognizeTextRequest`, `.accurate`). On-device, free, no model
  bundling, no network.
- **Persistence**: SwiftData, on-device only.
- **Device**: iPhone 14 Pro, paid Apple Developer account, 1-year provisioning.
- **Public repo**: the GitHub repo must stay public because GetSongBPM requires a
  verifiable backlink. Therefore **no secret may ever be committed**. Keys are generated
  into a gitignored `Secrets.swift` at build time from `~/.config/keys/` — compiled into
  the binary as intended, never in version control.
- **Rate limits**: Discogs 60 req/min authenticated. Max 3 concurrent requests, backoff
  on 429.
- **API call frugality**: resolution must climb the ladder — bundled library.db → cache →
  free-unlimited (MusicBrainz) → free-limited (Discogs, GetSongBPM). Never call a paid or
  quota-limited source for a datum available cheaper.

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
*Last updated: 2026-08-29 after initialization*
