# Vinyl Set Builder — MVP Spec

Personal-use iOS app. Photograph vinyl labels, resolve metadata, auto-sequence a mixable set.

**Platform:** iPhone 14 Pro, iOS 17+, SwiftUI
**Scope:** single user, no auth, no App Store distribution
**Non-goals (MVP):** audio analysis, playback, cloud sync, sharing, multi-track-per-vinyl playlists

---

## 1. Core Model

### Entities

```
Crate (playlist)
  id, name, createdAt
  vinyls: [VinylEntry]
  sequence: [TrackID]        // ordered, one per vinyl
  excluded: [TrackID]        // failed BPM gate, flagged

VinylEntry
  id, capturedAt
  photos: [ImageRef]         // one per side scanned
  sidesScanned: Set<Side>    // .a, .b
  candidates: [Track]        // ALL tracks read off the label
  selectedTrack: TrackID?    // chosen by sequencer, mutable

Track
  id, vinylID, side, position
  rawOCRText: String
  artist, title: String?
  bpm: Double?
  camelot: String?           // "8A", "11B", etc.
  matchConfidence: Double
  resolutionState: .pending | .resolved | .failed | .manual
```

### Hard rules

- One physical vinyl contributes **exactly one track** to a crate's sequence. Non-negotiable in MVP.
- All candidate tracks stay cached even when unselected. The sequencer needs them on every re-run.
- A vinyl can appear in multiple crates with a different selected track in each.

---

## 2. User Flow

1. **Crates screen** — list of saved playlists. Tap `+` for new.
2. **New Crate** — name it, drop straight into camera.
3. **Capture loop**
   - Shoot one vinyl side. Shutter returns immediately to camera.
   - Thumbnail strip at bottom shows scanned vinyls with a per-item resolution spinner.
   - If segmentation suggests a flip side exists, inline prompt: *"Looks like there's a B-side. Scan it?"* with Scan / Skip.
   - Tap **Done** when finished.
4. **Sequencing** — runs on Done and on every subsequent add. Shows ordered list plus an Excluded section.
5. **Crate detail** — reorderable list, per-track BPM/key badges, **Add More** button re-enters the capture loop.

---

## 3. Build Order (UI-first)

Each phase ships something tappable. Stubs return fixture data until the real layer lands.

### Phase 0 — UI shell with full stubs
- All five screens navigable
- `MetadataResolver` protocol returns hardcoded fixture tracks after a fake 1.5s delay
- `Sequencer` protocol returns naive BPM sort
- **Ship criterion:** you can walk the entire flow end to end with fake data

### Phase 1 — Camera + Vision OCR
- `AVCaptureSession` still capture, label-framing guide overlay
- `VNRecognizeTextRequest`, `.accurate` level, custom vocabulary seeded with your label/artist names
- Output: raw observations with bounding boxes and confidence
- **Ship criterion:** raw text dumps onscreen for 10 real labels from your crate

### Phase 2 — Multi-track segmentation
- Group text observations into track-line regions (see §4)
- Emit N candidate tracks per photo
- **Ship criterion:** correct track count on 8/10 test labels

### Phase 3 — Metadata resolution
- Discogs search, MusicBrainz fallback
- BPM/key from GetSongBPM or Discogs release data
- Manual-entry sheet for failures
- **Ship criterion:** 70%+ auto-resolve on your jungle/garage records

### Phase 4 — Sequencer
- Real constrained optimizer (see §5)
- **Ship criterion:** produces a set you'd actually play

### Phase 5 — Persistence
- SwiftData or Core Data, on-device only
- **Ship criterion:** crates survive app restart

---

## 4. Multi-Track Segmentation

The hard part. One photo of one label may hold 1 to 5 tracks.

**Approach:** deterministic geometric clustering on Vision bounding boxes, no ML model.

1. Filter observations below confidence threshold (~0.3)
2. Discard known non-track text: catalog numbers (regex for alphanumeric codes), `RPM`, `SIDE A/B`, `℗`/`©` lines, label names
3. Cluster remaining observations by radial position from label center. Vinyl label text runs concentrically, so distance-from-center is a stronger grouping signal than Y-coordinate on a circular label
4. Within each cluster, merge horizontally adjacent observations into one line
5. Apply track-line heuristics:
   - A leading `A1`, `B2`, `1.`, `2.` marker splits tracks deterministically. Highest confidence signal available, prefer it over geometry when present
   - Parenthetical suffixes (`(VIP)`, `(Remix)`, `(Dub)`) attach to the preceding line, not a new track
   - Duration stamps (`4:32`) mark line ends

**Flip-side detection:**
- Explicit `A1`/`A2` markers with no `B*` present → prompt for flip
- Side label reads `A` or `AA` → prompt for flip
- No side markers at all → prompt anyway, cheap to skip

**Fallback:** every segmentation result is editable. Tap the vinyl thumbnail to split, merge, or hand-type track lines. Given your white-label and dubplate situation, expect to use this and design the sheet to be fast rather than treating it as an error path.

---

## 5. Sequencing Algorithm

Runs on Done and on every vinyl added afterward. Full re-optimization, not incremental.

### Constraints

**Hard gate (BPM only):**
```
|bpm[i+1] - bpm[i]| <= BPM_TOLERANCE     // default 4.0, user-tunable 3-6
                                         // EITHER direction, between consecutive tracks
```

> **SUPERSEDED 2026-08-30** — this gate used to carry a second line, "bpm sequence is
> non-decreasing", and that rule is retired. See `.planning/SEQUENCER-SPEC.md` for the owner's
> revised statement. Tempo may now step down as well as up between consecutive tracks, so
> `170 -> 174 -> 172` is a legal set when the keys make it the better one. Implemented in
> Phase 5; `SequencerAdjacencyTests` is the executable statement of the gate.
>
> Note the owner's illustration `170 -> 178 -> 174` is **not** reachable under the confirmed
> consecutive reading: `|178 - 170| = 8`, which exceeds the tolerance at every point of the
> 3-6 range. It is legal only under the two-apart reading, which the spec explicitly kills.

**Soft objective (Camelot):**
```
minimize  Σ camelotDistance(track[i], track[i+1])
```

Camelot distance on the wheel: same key 0, ±1 hour 1, relative major/minor swap 1, otherwise min hop count around the 12-position ring plus 1 for a letter change.

**Structural constraint:** at most one track per `vinylID` in the sequence.

### Procedure

```
1. Collect all candidate tracks with resolved BPM across all vinyls in the crate
2. Drop tracks with nil BPM into `unresolved` (not excluded, just unusable)
3. Sort candidates by BPM
4. Build a DAG: edge u -> v where v.bpm >= u.bpm
                              and (v.bpm - u.bpm) <= BPM_TOLERANCE
                              and v.vinylID != u.vinylID
5. Edge weight = camelotDistance(u, v)
6. Find the path maximizing vinyl count, tie-broken by minimum total weight,
   subject to visiting each vinylID at most once
7. Tracks on the winning path -> sequence (selectedTrack per vinyl)
8. Vinyls with no candidate on the path -> excluded, with reason
```

Step 6 is the only nontrivial piece. At crate scale (< 100 vinyls, < 400 candidates) a DP over BPM-sorted order with a visited-vinyl set, or plain beam search with width 50, resolves in milliseconds. Do not build anything cleverer until it actually feels slow.

### Exclusion semantics

- Exclusion is **BPM-driven only**. Camelot distance never removes a track, it only orders survivors. Jungle and DnB are rhythm-led, so key is a preference not a filter.
- Excluded vinyls show in a collapsed section with the reason: *"No track within 4 BPM of the set"*
- Every re-run re-evaluates exclusions. A previously excluded vinyl can rejoin if a new addition bridges the gap.

---

## 6. Metadata Resolution

**Pipeline per candidate track:**
```
OCR text
  -> normalize (strip punctuation, collapse whitespace, lowercase)
  -> Discogs /database/search  (type=release, q=artist+title)
  -> pick best match by string similarity + format=Vinyl filter
  -> extract artist, title, year, label
  -> BPM/key lookup: GetSongBPM by artist+title
  -> if miss: MusicBrainz -> AcoustID chain
  -> if still miss: mark .failed, surface manual entry
```

**Matching:** normalized Levenshtein on `artist + title`, accept above 0.75, queue 0.5 to 0.75 for user confirmation, reject below.

**Concurrency:** `TaskGroup` with max 3 concurrent requests. Discogs rate-limits at 60 req/min authenticated. Backoff on 429.

**Expected reality check:** obscure jungle white labels and dubplates are frequently absent from these databases entirely. No model fixes a missing record. Manual entry is a first-class path, not a failure state. Budget UI effort accordingly.

---

## 7. Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Language | Swift only | URLSession handles all API calls. No Python runtime needed. |
| OCR | Vision framework | On-device, free, fast, no model bundling |
| Segmentation | Deterministic geometry | Debuggable and predictable. Revisit a VLM only if this measurably fails |
| Persistence | SwiftData | Native, minimal setup, on-device |
| API keys | Bundled in app | See risk note below |
| Concurrency | Swift structured concurrency | Background resolution while the capture loop stays responsive |

**API key risk:** strings are trivially extractable from an IPA. For a personal build that risk is yours alone, so bundling is a reasonable shortcut. Use a Discogs token scoped to a throwaway account rather than your main one, and never ship this build to anyone.

**On reusing CrateDig:** the Camelot distance function and BPM-gated transition-graph logic from your existing sequencer port over directly. Rewrite them in Swift rather than embedding Python. The vinyl app has no audio to analyze, so the librosa/allin1 half of that pipeline has no role here.

---

## 8. Open Items (LOCKED — see docs/DECISIONS.md)

- Camelot distance weighting: flat hop count, or penalize letter changes harder?
- `BPM_TOLERANCE` default: start at 4.0, expose a slider, tune against real sets
- Half-time and double-time handling: a 87 BPM read may really be a 174 BPM track. Add a normalization pass that folds anything below 100 into the 160 to 180 range for this genre?
- Should `unresolved` (nil BPM) and `excluded` (failed gate) be distinct sections in the UI, or one bucket?

---

## 9. Definition of Done

MVP ships when you can:

1. Create a crate, scan 20 vinyls without waiting on any screen
2. See metadata auto-resolve for most of them, hand-enter the rest in under 15 seconds each
3. Get a sequenced set whose consecutive tempo steps stay inside the tolerance, and whose harmonic neighbors make sense
4. Add 5 more vinyls and watch the whole sequence re-optimize, including a previously excluded record rejoining
5. Close the app, reopen it, and find the crate intact
