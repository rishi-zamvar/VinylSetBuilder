# Roadmap: Vinyl Set Builder

## Overview

Six phases carry this from an empty Xcode project to the owner's Definition of Done: scan 20
vinyls, watch metadata mostly auto-resolve, get back a BPM-gated, Camelot-sensible set that
re-optimises as more records are added, and find it all still there after a restart.

The build order deliberately does **not** follow the MVP-SPEC's own §3 UI-first sequence
literally, though research judged its spirit sound. Two changes, both justified by risk:

1. **The sequencer is built and fully proven in Phase 1**, not Phase 4. It is pure logic over
   `(vinylID, bpm, camelot)` tuples with zero dependency on camera, OCR, or network — and it
   is the project's uncontested differentiator (label OCR is a commodity; nothing else models
   one-track-per-physical-record with full re-optimisation). Proving it correct against
   fixtures while the real risk — camera/OCR/segmentation — is still being spiked costs
   nothing and de-risks the hardest algorithm early. Phase 1 also builds every screen against
   fixture data, so the whole crate-management flow (list, create, reorder, delete, multi-crate
   membership) is real and demonstrable before a single real photograph is taken.
2. **The riskiest assumption in the whole project — whether Vision can read text off a
   circular label at all — gets an explicit go/no-go spike inside Phase 2**, before
   Segmentation's clustering strategy is designed. `SEG-01` (the spike requirement) is
   grouped into Phase 2 rather than Phase 3's Segmentation category, because its output
   — the concentric-vs-horizontal layout split on the owner's real fixture photos — is what
   Phase 3 needs in hand before it can be designed at all.

No new phase was invented for "wiring it all together": because Phase 1 builds the real UI
against protocol seams (not against ad-hoc stub code), each later phase simply replaces a stub
implementation with a real one. By the end of Phase 5 the full loop already works on real data
as a natural consequence of that architecture, not as separate integration work.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Foundation, Domain Model & Sequencer** - Package, models, secrets, and the full crate-management UI navigable end-to-end against fixture data, with the beam-search sequencer built and proven correct in isolation
- [ ] **Phase 2: Camera + OCR (go/no-go spike)** - Continuous label capture and on-device OCR, gated by a measured spike over real fixture photos proving Vision can read the owner's actual labels
- [ ] **Phase 3: Segmentation** - One label photo reliably split into its individual candidate tracks, using the layout strategy the Phase 2 spike found
- [ ] **Phase 4: Metadata Resolution (identity + BPM/Key)** - Candidate tracks resolve to artist/title via the bundled corpus and Discogs/MusicBrainz, and to BPM/Camelot key via the bundled corpus and SoundCloud + on-device Music Understanding
- [ ] **Phase 5: Manual Entry & Fast Correction** - A sub-15-second hand-entry path for anything automatic resolution misses, reachable from every relevant screen
- [ ] **Phase 6: Persistence** - Crates, vinyls, candidates, photos and sequence order survive quitting and reopening the app, entirely on-device

## Phase Details

### Phase 1: Foundation, Domain Model & Sequencer
**Goal**: The project compiles and runs on-device, the sequencing algorithm is provably correct in isolation, and every screen in the app is navigable end-to-end against fixture data — including a fully sequenced, reorderable crate view.
**Depends on**: Nothing (first phase)
**Requirements**: SETUP-01, SETUP-02, SETUP-03, SETUP-04, SEQ-01, SEQ-02, SEQ-03, SEQ-04, SEQ-05, SEQ-06, SEQ-07, SEQ-08, SEQ-09, SEQ-10, SEQ-11, CRATE-01, CRATE-02, CRATE-03, CRATE-04, CRATE-05, CRATE-06, CRATE-07
**Success Criteria** (what must be TRUE):
  1. The project builds and launches on the physical iPhone 14 Pro under the paid developer account, targeting iOS 27.
  2. The full test suite, including the sequencer's unit tests, runs from the command line with no device, camera, or network — and a beam-width-50 run agrees with a wider-beam run on the same fixture, or a divergence is flagged.
  3. Given a fixture set of `(vinylID, bpm, camelot)` tuples, the sequencer produces a one-track-per-vinyl, BPM-ascending sequence honouring `BPM_TOLERANCE` (slider 3-6, default 4.0), correctly excludes and later re-admits a vinyl when a bridging tuple is added, and breaks Camelot ties by lowest total hop distance.
  4. User can walk the entire crate flow against fixture data — list crates, create and name a new one, land on a capture screen, open a crate to see a sequenced list with BPM/Camelot badges and a plain-language reason on each excluded/unresolved row, drag to reorder, add more, remove a vinyl, delete a crate.
  5. The same fixture vinyl can be added to two different crates and carry a different selected track in each.
**Plans**: TBD
**UI hint**: yes

### Phase 2: Camera + OCR (go/no-go spike)
**Goal**: The camera captures labels continuously without ever blocking, and Vision OCR reads real label text well enough to build on — validated against the owner's actual collection, not assumed.
**Depends on**: Phase 1
**Requirements**: CAP-01, CAP-02, CAP-03, CAP-04, CAP-05, CAP-06, OCR-01, OCR-02, OCR-03, OCR-04, OCR-05, SEG-01
**Success Criteria** (what must be TRUE):
  1. User can shoot a label and the shutter returns to a live camera view immediately, with no blocking spinner, across a 20-vinyl session with no stall, memory warning, or thermal throttle.
  2. A framing guide shows where to place the label, and a thumbnail strip shows every vinyl scanned so far in the session with its per-item resolution status.
  3. Each captured label yields text observations with bounding boxes (normalised into one documented convention, Vision's bottom-left origin flipped exactly once) and per-observation confidence, seeded with a custom vocabulary of the owner's recurring label/artist names, runs off the main thread, and can be inspected as raw text on screen.
  4. A scored spike report over 10-15 real fixture photos states the concentric-vs-plain-horizontal layout split and whether Vision reads each layout well enough to proceed — this is the go/no-go checkpoint before Phase 3's segmentation strategy is designed.
  5. When a scan suggests an unscanned flip side, an inline prompt offers Scan or Skip without leaving the camera; tapping Done leaves the capture loop and lands on the sequenced crate view.
**Plans**: TBD
**UI hint**: yes

### Phase 3: Segmentation
**Goal**: A photographed label is reliably split into the individual tracks it actually contains, branching by the layout Phase 2's spike found rather than committing to one clustering strategy globally.
**Depends on**: Phase 2
**Requirements**: SEG-02, SEG-03, SEG-04, SEG-05, SEG-06, SEG-07
**Success Criteria** (what must be TRUE):
  1. Given Phase 2's frozen fixture photos, one label photo is split into its individual candidate tracks correctly on at least 8 of 10 fixtures, measured separately for concentric and plain-horizontal layouts.
  2. Catalogue numbers, RPM, SIDE A/B markers, ℗/© lines and label names are discarded before clustering, and a leading track marker (`A1`, `B2`, `1.`) splits tracks in preference to geometry whenever one is present.
  3. A parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one.
  4. The app infers whether an unscanned flip side probably exists from side markers or their absence, feeding the Phase 2 capture-loop prompt with a real signal.
  5. User can correct any segmentation result — split a track, merge two, or type a track line by hand.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Metadata Resolution (identity + BPM/Key)
**Goal**: Every candidate track resolves to a real artist, title, BPM and Camelot key wherever that data exists anywhere in reach — bundled corpus first, network last — measured against the owner's real collection, not assumed to work.
**Depends on**: Phase 3
**Requirements**: RES-01, RES-02, RES-03, RES-04, RES-05, RES-06, RES-07, BPM-01, BPM-02, BPM-03, BPM-04, BPM-05, BPM-06, BPM-07
**Success Criteria** (what must be TRUE):
  1. Each candidate track resolves to an artist and title — via the bundled corpus, then cache, then MusicBrainz, then Discogs — or is explicitly marked failed; resolution runs in the background with at most 3 requests in flight and per-item status visible, an HTTP 429 triggers backoff and retry rather than failure, and leaving a crate cancels its in-flight work.
  2. A match above 0.75 normalised similarity is auto-accepted, 0.50-0.75 is queued for user confirmation, below 0.50 is rejected; resolution results are cached so re-running the sequencer never re-issues a network request.
  3. Every resolved track carries a BPM and a Camelot key or is explicitly marked as lacking them: the bundled 7,010-track corpus is consulted first, SoundCloud audio analysed on-device with Music Understanding is the fallback for anything it misses (audio not retained afterwards), a detected key is converted to Camelot notation, and any BPM under 100 is doubled unconditionally.
  4. A measured report against real fixture tracks states the resolve-rate split (bundled corpus vs. SoundCloud vs. failure) and checks Music Understanding's tempo/key output against the bundled corpus's known-good values for the same tracks, before the app depends on it unattended.
  5. A track whose BPM cannot be established by any route is surfaced for manual entry rather than silently dropped.
**Plans**: TBD
**UI hint**: yes

### Phase 5: Manual Entry & Fast Correction
**Goal**: When automatic resolution misses — expected to be common on white labels and dubplates — completing a track by hand is fast enough that it never feels like a fallback.
**Depends on**: Phase 4
**Requirements**: MAN-01, MAN-02, MAN-03, MAN-04, MAN-05
**Success Criteria** (what must be TRUE):
  1. User can enter or correct artist, title, BPM and key for any track in under 15 seconds.
  2. Camelot key is chosen from a tap grid, never typed; BPM entry pre-fills from a sensible neighbour value rather than starting empty.
  3. A manually entered track is marked as such and is never silently overwritten by a later automatic resolution.
  4. Manual entry is reachable directly from the sequenced list and from the excluded list, not only from a failure dialog.
**Plans**: TBD
**UI hint**: yes

### Phase 6: Persistence
**Goal**: Everything the app has built stays exactly as left, on-device only, across an app restart — including the order the owner set.
**Depends on**: Phase 5
**Requirements**: PERS-01, PERS-02, PERS-03, PERS-04
**Success Criteria** (what must be TRUE):
  1. Closing and reopening the app finds every crate, vinyl, candidate track, photo and sequence intact.
  2. The saved order of tracks and candidates survives restart exactly as arranged, backed by explicit integer ordering fields rather than SwiftData relationship order.
  3. Every candidate track — including ones not currently selected — remains stored, so the sequencer can re-run over all of them at any time.
  4. Nothing the app stores is ever uploaded anywhere; all persistence is on-device.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation, Domain Model & Sequencer | 0/TBD | Not started | - |
| 2. Camera + OCR (go/no-go spike) | 0/TBD | Not started | - |
| 3. Segmentation | 0/TBD | Not started | - |
| 4. Metadata Resolution (identity + BPM/Key) | 0/TBD | Not started | - |
| 5. Manual Entry & Fast Correction | 0/TBD | Not started | - |
| 6. Persistence | 0/TBD | Not started | - |
