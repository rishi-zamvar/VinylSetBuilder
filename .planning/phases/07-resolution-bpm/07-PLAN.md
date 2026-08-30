---
phase: 07
plan: 07
type: execution
autonomous: true
wave: 1
depends_on: [06]
requirements: [RES-01, RES-02, RES-03, RES-04, RES-05, RES-06, RES-07, RES-08, BPM-01, BPM-02, BPM-03, BPM-04, BPM-05, BPM-06, BPM-07, BPM-08, BPM-09]
---

# Phase 7 — Resolution & the BPM Ladder

## Objective

A segmented track line becomes an **artist, a title, a BPM and a Camelot key** — or is
honestly marked failed and handed to manual entry. The ladder climbs cheapest-first and
never spends a quota call on a datum available free.

## The one architectural decision that shapes everything

Core may not contain the substring `URLSession`. The obvious reading — "put the API clients
in the app target" — would move the *retry policy, the rate limit, the result ranking, the
ladder itself and every JSON parse* out of the tested package and into the one place with no
test target. That is backwards.

So the seam is drawn one level lower:

```
Core:  HTTPFetching (protocol, Foundation types only)
       DiscogsClient / MusicBrainzClient / SoundCloudClient  — logic, ranking, parsing
       ResolutionLadder, BPMLadder, TrackResolver
       TierZeroCorpus (raw SQLite3), VDSPAudioAnalyzer (Accelerate)
App:   URLSessionTransport: HTTPFetching   — ~40 lines, the only networking code
       AudioFileDecoder                    — the only AVFoundation audio code
```

`HTTPFetching` names no banned symbol: it takes an `HTTPRequest` value (URL, method,
headers, body) and returns `HTTPResponse` (status, headers, body). A fake conformance in the
test target can therefore **count requests**, which is exactly what RES-06 demands proof of.

## Deviations from STACK.md, declared up front

- **Raw SQLite3, not GRDB.** STACK.md recommends GRDB and lists raw SQLite3 as acceptable
  "for a single trivial lookup query". The tier-0 lookup is one indexed `SELECT` plus one
  title-index `SELECT` for the fuzzy fallback. Adding an SPM dependency — and its fetch, its
  build time on every `swift test`, and its bundling story — to save ~40 lines of
  `sqlite3_step` is the wrong trade. `SQLite3` is not on the purity ban list.
- **`AudioAnalyzing` takes mono `[Float]` + sample rate**, not an asset. Decoding needs
  AVFoundation, which Core cannot have. Sample-level is also the honest seam: it is what a
  DSP analyser actually consumes, and an app-side adapter can hand Music Understanding an
  asset the day that SDK exists.

## Tasks

### Task 1 — the HTTP seam and the match bands  (RES-04)
`Core/Net/HTTPFetching.swift`, `Core/Resolution/MatchScoring.swift`.
Normalised similarity from `FuzzyMatch`; bands **> 0.75 accept / 0.50…0.75 confirm /
< 0.50 reject**, boundaries unit-tested at their edges. TDD.

### Task 2 — Discogs and MusicBrainz over the seam  (RES-03, RES-05, RES-08)
Catalogue number is the **primary** Discogs key, artist+title the fallback. 429 → backoff and
retry, not a failure. MusicBrainz: User-Agent required, 503 "server busy" is transient and
retried. Fake-transport tests for both, including a 429-then-200 sequence. TDD.

### Task 3 — the artist cross-check  (RES-08)
The measured failure: `0-44904` returns a **Tchaikovsky** record. A catalogue candidate is
accepted only if its artist or title is findable in the sleeve's own OCR text. Negative
control: the Tchaikovsky payload must be REJECTED by a test that fails if the check is removed.

### Task 4 — the ladder, the cache and the bound  (RES-01, RES-02, RES-06, RES-07)
`TrackResolver: MetadataResolving`. Order: cache → MusicBrainz (free, unlimited) → Discogs
(60/min). At most 3 in flight. Cancellation propagates. A test counts transport calls and
asserts the second pass over the same crate issues **zero**.

### Task 5 — `URLSessionTransport` in the app target
The real conformance. Nothing else in the app target does networking.

### Task 6 — GATE 1, measured twice
`Scripts/resolve-score.sh` + `Tools/resolve-harness`. Compiles the SHIPPING clients and the
SHIPPING transport into one macOS binary and hits Discogs live with the **six catalogue
numbers the shipped segmenter actually extracts** — `0-44904, EMF2029, 0-44845, TYME012,
TECH008, CSI006` — scored against committed ground truth. **≥ 5 of 6.**

### Task 7 — the tier-0 corpus  (BPM-02)
`Core/BPM/TierZeroCorpus.swift`, raw SQLite3, read-only, `journal_mode=delete` already set.
Punctuation-normalised match, documented tie-break for the `The Rapture Pt. II` case.

### Task 8 — the vDSP analyser  (BPM-04, BPM-05, BPM-08)
`AudioAnalyzing` protocol + `VDSPAudioAnalyzer`: onset envelope + autocorrelation for tempo,
chromagram + Krumhansl-Schmuckler for key → Camelot. Verify Accelerate does not trip the
purity guard **first**; if it does, the analyser moves to the app target behind the same
protocol. Synthetic-signal tests: a click train at a known tempo, a sine triad in a known key.

### Task 9 — SoundCloud audio acquisition  (BPM-03)
Search + **duration sanity bound + weighted artist/title similarity**. A 79-minute DJ mix is
never the answer for a 5-minute track. Responses cached to `.local/sc_cache/` so re-runs are
offline.

### Task 10 — the BPM ladder  (BPM-01, BPM-06, BPM-07)
tier-0 → cache → SoundCloud+analyser. `BPMRules.fold` applied exactly once. A track no route
can establish is `.failed` with a reason, surfaced for manual entry, never dropped.

### Task 11 — GATES 2, 3 and 4, each measured twice
- `Scripts/sc-score.sh` — SoundCloud match rate on the 40-track truth set. **≥ 72%.**
- `Scripts/tier0-score.sh` — tier-0 hit rate. **Reported, not gated.** The corpus skews
  house/techno; a low number is a valid result that reallocates weight onto manual entry.
- `Scripts/analyser-score.sh` — `Tools/mu-validate.swift` retargeted from
  `MusicUnderstandingSession` to `AudioAnalyzing`, over the 29 cached previews. Tempo
  octave-aware, key by Camelot distance. **Both numbers reported.**
  **Documented fallback:** if key accuracy is poor, key degrades to a soft/manual field and
  BPM stays automatic. The sequencer tolerates this by design — Camelot only ORDERS
  survivors, it never excludes. That is a valid outcome, not a failure.

### Task 12 — close out
Requirements ticked, ROADMAP and STATE updated, hygiene green, suite green.

## Verification

`./Scripts/test.sh` green (≥ 236) · `./Scripts/hygiene.sh` 9 pass 0 fail ·
`./Scripts/build-app.sh` SUCCEEDED · the four gate scripts, each run twice, artefacts
committed under `Artifacts/`.
