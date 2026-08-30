# Roadmap: Vinyl Set Builder

## Overview

Six phases carry this from an empty Xcode project to the owner's Definition of Done: scan 20
vinyls, watch metadata mostly auto-resolve, get back a BPM-gated, Camelot-sensible set that
re-optimises as more records are added, and find it all still there after a restart.

**Revised 2026-08-29 after the Phase 2 OCR spike was run early** against 12 real record
photographs from the owner's own crate. It answered the project's original #1 risk — whether
Vision can read text off a vinyl label at all — and passed, but disproved several of the
spec's structural assumptions along the way (see `research/OCR-SPIKE.md`). This revision:

1. **Demotes Phase 2 from a go/no-go spike to ordinary work.** The captured unit turns out to
   be a whole 12" sleeve, not a label close-up; concentric/curved text — the thing feared
   most — barely appears in this collection; and OCR performance is a non-issue (~130 ms/image).
   `SEG-01` (validating the segmentation algorithm against the 12 committed fixtures) moves
   from Phase 2 into Phase 3, because it is now genuinely Segmentation's own validation work —
   angle-cluster segmentation, the algorithm the spike recommends, is what Phase 3 builds.
2. **Promotes Phase 4 to carry the project's new #1 go/no-go gate.** Apple Music
   Understanding's accuracy on this owner's bass-heavy jungle/DnB audio is completely
   unverified — the OS 27 API surface wasn't testable on the spike machine — and the
   SoundCloud API only ever returns a 30-second preview, which may or may not be enough for a
   reliable key read. Phase 4 now opens with an explicit accuracy spike against the bundled
   6,608-track corpus as ground truth, before the app depends on Music Understanding
   unattended.

The build order still does **not** follow the MVP-SPEC's own §3 UI-first sequence literally,
for the same original reason:

1. **The sequencer is built and fully proven in Phase 1**, not Phase 4. It is pure logic over
   `(vinylID, bpm, camelot)` tuples with zero dependency on camera, OCR, or network — and it
   is the project's uncontested differentiator (label OCR is a commodity; nothing else models
   one-track-per-physical-record with full re-optimisation). Phase 1 also builds every screen
   against fixture data, so the whole crate-management flow (list, create, reorder, delete,
   multi-crate membership) is real and demonstrable before a single real photograph is taken.
2. **Camera + OCR (Phase 2) and Segmentation (Phase 3) stay split**, now simply because they
   are different concerns — capture/recognition vs. clustering/parsing — not because one gates
   the other's design. The spike already answered the design question for both.

No new phase was invented for "wiring it all together": because Phase 1 builds the real UI
against protocol seams (not against ad-hoc stub code), each later phase simply replaces a stub
implementation with a real one. By the end of Phase 5 the full loop already works on real data
as a natural consequence of that architecture, not as separate integration work.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Foundation, Domain Model & Sequencer** - Package, models, secrets, and the full crate-management UI navigable end-to-end against fixture data, with the beam-search sequencer built and proven correct in isolation
- [ ] **Phase 2: Camera + OCR** - Continuous whole-sleeve capture and on-device OCR with the EXIF-orientation bug fixed, per the answered spike
- [ ] **Phase 3: Segmentation** - One sleeve photo reliably split into its individual candidate tracks, using baseline-angle clustering validated against the 12 committed fixtures
- [ ] **Phase 4: Metadata Resolution (identity + BPM/Key)** - Candidate tracks resolve to artist/title via the bundled corpus and Discogs/MusicBrainz, and to BPM/Camelot key via the bundled corpus and SoundCloud + on-device Music Understanding — gated by a measured accuracy spike, the project's new go/no-go checkpoint
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

### Phase 2: Camera + OCR
**Goal**: The camera captures whole sleeves continuously without ever blocking, and Vision OCR reads real sleeve/label text well enough to build on — the accuracy question is already answered (`research/OCR-SPIKE.md`); this phase implements it correctly, including the EXIF-orientation bug the spike found.
**Depends on**: Phase 1
**Requirements**: CAP-01, CAP-02, CAP-03, CAP-04, CAP-05, CAP-06, OCR-01, OCR-02, OCR-03, OCR-04, OCR-05
**Success Criteria** (what must be TRUE):
  1. User can shoot a sleeve and the shutter returns to a live camera view immediately, with no blocking spinner, across a 20-vinyl session with no stall, memory warning, or thermal throttle — a low-risk bar per the spike's measured ~130 ms/image after a 455 ms warm-up.
  2. A framing guide sized for a whole 12" sleeve (not a label close-up) shows where to place it, and a thumbnail strip shows every vinyl scanned so far in the session with its per-item resolution status.
  3. Each captured photo yields text observations with bounding box, baseline angle, and per-observation confidence: EXIF orientation is passed into `VNImageRequestHandler`, and the returned coordinates — which Vision reports in the ORIGINAL unrotated buffer space regardless — are transformed into one documented convention exactly once; recognition is seeded with a custom vocabulary of the owner's recurring label/artist names; OCR runs off the main thread; raw recognised text for a photo can be inspected on screen.
  4. When a scan yields tracks for only one side, an inline prompt offers Scan or Skip without leaving the camera — suppressed when both sides were already read from a single photo, which the fixtures show is the common case; tapping Done leaves the capture loop and lands on the sequenced crate view.
**Plans**: TBD
**UI hint**: yes

### Phase 3: Segmentation
**Goal**: A photographed sleeve is reliably split into the individual tracks it actually contains, using baseline-angle clustering — separating sleeve text from label text by the angle each physical surface sits at, not by radial distance from a label centre.
**Depends on**: Phase 2
**Requirements**: SEG-01, SEG-02, SEG-03, SEG-04, SEG-05, SEG-06, SEG-07, SEG-08
**Success Criteria** (what must be TRUE):
  1. Given the 12 committed fixture photographs, the shipped angle-cluster segmentation reports per-fixture track-count accuracy, measured against the spike's own baseline (`research/OCR-SPIKE.md`: 6 clean / 5 partial / 1 fail — a usable track count on 9 of 12) — the implementation matches or improves on it, it does not merely re-assert it.
  2. Observations are grouped by baseline angle into per-surface clusters (sleeve vs. label, e.g. −90° vs +150°) rather than by radial distance from a label centre — no centre detection, no circle finding, no polar unwrapping — and only observations at the trusted confidence tier (`conf >= 1.0`) are used to build track lines, since the spike found confidence is effectively binary (1.00 vs 0.50/0.30) and a fractional threshold is not a useful filter.
  3. Non-track text is filtered before clustering — shop-price stickers via a currency/decimal regex, RPM, ℗/© lines, addresses, URLs and emails — while catalogue numbers are extracted and kept, not discarded. A side or track marker splits tracks in preference to geometry whenever present, covering `A`/`AA`/`B`/`BB`, `A1`/`B2`, `SIDE A`, `Side One`, and arbitrary named sides such as `COLD SIDE:`/`STEEL SIDE:` found in the fixtures; a parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one.
  4. The app infers whether an unscanned flip side probably exists from side markers or their absence, feeding the Phase 2 capture-loop prompt with a real signal.
  5. User can correct any segmentation result — split a track, merge two, or type a track line by hand.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Metadata Resolution (identity + BPM/Key)
**Goal**: Every candidate track resolves to a real artist, title, BPM and Camelot key wherever that data exists anywhere in reach — bundled corpus first, network last — gated by an explicit accuracy spike against known-good data before the app depends on Music Understanding unattended. This is now the project's #1 go/no-go checkpoint, replacing the answered OCR spike.
**Depends on**: Phase 3
**Requirements**: RES-01, RES-02, RES-03, RES-04, RES-05, RES-06, RES-07, RES-08, BPM-01, BPM-02, BPM-03, BPM-04, BPM-05, BPM-06, BPM-07
**Success Criteria** (what must be TRUE):
  1. A Music Understanding accuracy spike — the new go/no-go gate — measures on-device tempo and key extraction from a 30-second SoundCloud preview against the bundled 6,608-track corpus's known-good BPM/Camelot values as ground truth, requiring macOS/iOS 27 (unavailable at spike time, now installable). The report states measured tempo accuracy, measured key accuracy specifically from a 30-second window (which may land on an intro, breakdown, or drum-only passage), and the real tier-0 hit rate for the 160-184 BPM jungle/DnB band the corpus is thin on (only 12% of it). This decides whether key stays fully automatic or degrades to a soft/manual field, before the rest of Phase 4 is built to depend on it.
  2. Each candidate track resolves to an artist and title — via the bundled corpus, then cache, then MusicBrainz, then Discogs, with a present catalogue number used as the primary Discogs key ahead of artist+title (it read cleanly on 6 of 12 fixtures and is more discriminating for white labels) — or is explicitly marked failed; resolution runs in the background with at most 3 requests in flight and per-item status visible, an HTTP 429 triggers backoff and retry rather than failure, and leaving a crate cancels its in-flight work.
  3. A match above 0.75 normalised similarity is auto-accepted, 0.50-0.75 is queued for user confirmation, below 0.50 is rejected; resolution results are cached so re-running the sequencer never re-issues a network request.
  4. Every resolved track carries a BPM and a Camelot key or is explicitly marked as lacking them: the bundled corpus is consulted first, SoundCloud audio — selected with a duration sanity bound and artist/title similarity scoring rather than the first search hit, since a live test returned a 79-minute DJ mix as result 2 — analysed on-device with Music Understanding is the fallback, a detected key is converted to Camelot notation, and any BPM under 100 is doubled unconditionally. If criterion 1's spike finds key accuracy poor, key degrades to a soft/manual field while BPM stays automatic — the sequencer tolerates this by design, since Camelot distance only orders survivors on the winning path and never excludes a vinyl on key alone.
  5. A track whose BPM cannot be established by any route is surfaced for manual entry rather than silently dropped.
**Plans**: TBD
**UI hint**: yes

### Phase 5: Manual Entry & Fast Correction
**Goal**: When automatic resolution misses — expected to be common on white labels and dubplates, and more so if Phase 4's spike finds the real tier-0 hit rate low — completing a track by hand is fast enough that it never feels like a fallback.
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
| 2. Camera + OCR | 0/TBD | Not started | - |
| 3. Segmentation | 0/TBD | Not started | - |
| 4. Metadata Resolution (identity + BPM/Key) | 0/TBD | Not started | - |
| 5. Manual Entry & Fast Correction | 0/TBD | Not started | - |
| 6. Persistence | 0/TBD | Not started | - |
