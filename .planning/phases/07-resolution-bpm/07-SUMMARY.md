# Phase 7 — Resolution & BPM Ladder — SUMMARY

**Status:** COMPLETE. All four acceptance gates measured **twice**, live, and committed to
`Artifacts/` before the machine's disk filled. The summary itself was blocked by `ENOSPC` and
is reconstructed here from the executor's report and the committed artefacts.

## The four numbers

| Gate | Bar | Measured | Runs |
|---|---|---|---|
| Catalogue-number resolution | ≥ 5 of 6 | **6 of 6** | 2, both `BASELINE HELD` |
| SoundCloud match rate | ≥ 72% | **85.0%** (34/40) | 2, byte-identical; 2nd offline from cache |
| Tier-0 corpus hit rate | report only | **0 of 35 — 0%** | 2 |
| Analyser — tempo | report only | 38% exact · 41% usable · 59% within 5% | 2, byte-identical |
| Analyser — key | report only | 24% exact · 34% within one hop | 2 |

Gates 1 and 2 were **proved able to fail** — baselines temporarily raised to 7-of-6 and 95%,
both returned `BASELINE NOT MET`, exit 1.

## The tier-0 result is the headline, and it is a zero

**The bundled 6,608-row corpus contains none of this collection.** This is not a reader bug:
the control run against the corpus's own source library scores **40 of 40**.

The corpus skews house/techno — only 12% of it sits in the 160–184 BPM band — and the owner's
vinyl is jungle/DnB. The frugality ladder's cheapest rung therefore contributes nothing here.
**All weight moves onto the audio route and manual entry.** Phase 9's manual-entry work is now
load-bearing rather than a fallback.

## Key degrades to a soft/manual field — the documented fallback, taken on evidence

Kept automatically only above 0.8 confidence, where precision is 71% (7 keys kept, 5 usable),
versus 38% at 0.5. **BPM stays automatic.** The sequencer tolerates this by design: Camelot
distance only ORDERS survivors and never excludes a record, so a missing key costs ordering
quality, not membership.

## Measured and REJECTED — recorded in source so they are not re-added

- **Comb-summed autocorrelation** — the textbook bar-vs-beat fix — made tempo **worse**:
  41% → 34% usable.
- **The first analyser returned `7B` for 20 of 29 tracks.** A 2048-point FFT bin is wider than
  a semitone below 370 Hz, so the chromagram had no bass resolution. Split into two front ends:
  1024/256 for onsets, 8192/4096 for chroma, per-frame normalised, plus parabolic interpolation
  of the ACF peak (one lag step was worth ~3 BPM).

## Architecture

`HTTPFetching` (Foundation types only) is declared in **Core**, so the ladder, ranking, retry
policy, rate limiting and every JSON parse sit **inside the tested package**.
`App/Network/URLSessionTransport.swift` is the only networking file in the project;
`App/Audio/AVAudioFileDecoder.swift` the only audio-decoding one.
`MetadataResolving` now takes a whole **sleeve** — a catalogue number belongs to the record,
not to a track.

## What FAILED, plainly

1. **The artist+title fallback rung produces confident wrong answers.** With no catalogue
   number, IMG_0501 resolved to *"Gregaress — Linus Rides With Me Everyday"*, IMG_0504 to
   *"Lizz Wright — Fellowship"*. Most land in the `.pending` confirmation band — that band
   working as designed — but some resolve outright. **The catalogue rung is 6/6; this rung is
   the weak half of the ladder.**
2. **A SoundCloud match is not a guarantee of the right audio.** Several picks are remixes,
   bootlegs or sped-up re-uploads (`+ REVERB + BASS BOOST + SPED UP`). This feeds gate 4's
   numbers and is part of why tempo accuracy is 41% rather than higher.
3. **MusicBrainz 503s constantly** — it knows 5 of the 6 catalogue numbers for free but answered
   only 2–3 per run before retries exhausted and the ladder fell through to Discogs. The
   frugality saving is real but variable.
4. **TDD lapsed on task 4** — `TrackResolverTests.swift` was written after `TrackResolver.swift`.
   Every other task was test-first.
5. **UI suite reported 4 passed / 3 crashed** (`signal kill`) during the disk exhaustion. Cause
   is environmental — two concurrent `ui-test.sh` runs plus a full disk. **Unverified**; the
   clean re-run is what hit `ENOSPC`. Re-run required.

## Deviations from STACK.md, both deliberate

- **Raw TSV instead of GRDB/SQLite for tier-0.** The punctuation-normalised lookup cannot use
  the `(artist_norm, title_norm)` index anyway, so the table is read into memory whatever the
  format. No dependency, and it avoids the WAL bundling trap entirely.
- **`AudioAnalyzing` takes mono `[Float]`**, not an asset — keeps Core free of audio frameworks.

## Requirements

38 → **53 of 67**. RES-02 and BPM-07 left deliberately *partial*: their remaining half is a
screen (wiring, manual entry), not an engine.
