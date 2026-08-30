# Requirements: Vinyl Set Builder

**Defined:** 2026-08-29
**Core Value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

## v1 Requirements

### Project Setup

- [ ] **SETUP-01**: Xcode project builds and runs on a physical iPhone 14 Pro under the paid developer account, targeting **iOS 26** — the installed SDK
- [ ] **SETUP-02**: Algorithm code (segmentation, sequencing, Camelot maths) lives in a local Swift package that links neither AVFoundation nor URLSession, so its tests cannot touch a camera or a network
- [ ] **SETUP-03**: API credentials are read from `~/.config/keys/` at build time into a gitignored `Secrets.swift`, so no secret is ever committed to the public repo
- [ ] **SETUP-04**: The full test suite runs from the command line with no device, no camera and no network

### Crate Management

- [ ] **CRATE-01**: User can see a list of every saved crate with its name and record count
- [ ] **CRATE-02**: User can create a new crate, name it, and land directly in the camera
- [ ] **CRATE-03**: User can open a crate and see its sequenced running order
- [ ] **CRATE-04**: User can manually reorder tracks in a crate, overriding the sequencer
- [ ] **CRATE-05**: User can re-enter the capture loop from an existing crate via "Add More"
- [ ] **CRATE-06**: User can delete a crate, and can remove a single vinyl from a crate
- [ ] **CRATE-07**: The same vinyl can belong to several crates with a different selected track in each

### Capture

- [ ] **CAP-01**: User can photograph a vinyl label and the shutter returns to the camera immediately, with no blocking spinner
- [ ] **CAP-02**: A framing guide overlay shows where to place the record sleeve, sized for a whole 12" sleeve rather than a label close-up
- [ ] **CAP-03**: A thumbnail strip shows every vinyl scanned so far in this session with its per-item resolution status
- [ ] **CAP-04**: User can scan 20 vinyls in one session without the app stalling, running out of memory, or thermally throttling
- [ ] **CAP-05**: When a scan yields tracks for only one side, an inline prompt offers Scan or Skip without leaving the camera — suppressed when both sides were already read from a single photo, which the fixtures show is common
- [ ] **CAP-06**: User can tap Done to leave the capture loop and see the sequenced result

### Text Recognition

- [ ] **OCR-01**: Each captured photo yields text observations with bounding boxes, per-observation confidence, and baseline angle
- [ ] **OCR-02**: EXIF orientation is passed to `VNImageRequestHandler`, and the returned coordinates — which Vision reports in the ORIGINAL unrotated buffer space — are transformed into one documented convention exactly once
- [ ] **OCR-03**: Recognition is seeded with a custom vocabulary of the owner's recurring label and artist names
- [ ] **OCR-04**: Raw recognised text for a label can be inspected on screen, for debugging a bad read
- [ ] **OCR-05**: OCR runs off the main thread and never blocks the capture loop

### Segmentation

- [ ] **SEG-01**: Angle-cluster segmentation is validated against the 12 committed fixture photographs, reporting per-fixture track-count accuracy (baseline established in `research/OCR-SPIKE.md`: 6 clean / 5 partial / 1 fail)
- [ ] **SEG-02**: Observations are grouped by BASELINE ANGLE to separate physical surfaces (sleeve vs. record label), then grouped within each cluster — not by radial distance from a label centre, which the fixtures disproved
- [ ] **SEG-03**: Non-track text is filtered before clustering — shop price stickers (currency/decimal regex), RPM, ℗/© lines, addresses, URLs and emails. Catalogue numbers are EXTRACTED AND KEPT, not discarded
- [ ] **SEG-04**: A side or track marker splits tracks in preference to geometry — covering `A`/`AA`/`B`/`BB`, `A1`/`B2`, `SIDE A`, `Side One`, and arbitrary named sides such as `COLD SIDE:` / `STEEL SIDE:` found in the fixtures
- [ ] **SEG-05**: A parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one
- [ ] **SEG-06**: The app infers whether an unscanned flip side probably exists, from side markers or their absence
- [ ] **SEG-07**: User can correct any segmentation result — split a track, merge two, or type a track line by hand
- [ ] **SEG-08**: Only observations at the trusted confidence tier are used for track lines; the fixtures showed confidence is effectively binary (1.00 vs 0.50/0.30), so a fractional threshold is not a useful filter

### Metadata Resolution

- [ ] **RES-01**: Each candidate track resolves to an artist and a title, or is explicitly marked as failed
- [ ] **RES-02**: Resolution runs in the background per vinyl, with at most 3 requests in flight, and per-item status visible in the UI
- [ ] **RES-03**: Discogs supplies release, artist, label and format; MusicBrainz is the fallback
- [ ] **RES-08**: When a catalogue number is present it is used as the primary Discogs key ahead of artist+title — it read cleanly on 6 of 12 fixtures and is far more discriminating for white labels
- [ ] **RES-04**: A match above 0.75 normalised similarity is accepted, 0.50–0.75 is queued for user confirmation, below 0.50 is rejected
- [ ] **RES-05**: HTTP 429 triggers backoff and retry rather than a failed resolution
- [ ] **RES-06**: Resolution results are cached, so re-running the sequencer never re-issues a network request
- [ ] **RES-07**: Cancelling or leaving a crate cancels that crate's in-flight resolution work

### BPM and Key

- [ ] **BPM-01**: Every resolved track carries a BPM and a Camelot key, or is explicitly marked as lacking them
- [ ] **BPM-02**: A bundled read-only copy of the owner's existing 7,010-track BPM/Camelot corpus is consulted first, before any network call
- [ ] **BPM-03**: When the bundled corpus misses, audio is fetched from SoundCloud using the owner's existing OAuth credentials
- [ ] **BPM-04**: Fetched audio is analysed on-device by the app's own Accelerate/vDSP analyser to produce tempo and key, and is not retained afterwards
- [ ] **BPM-08**: Audio analysis sits behind an `AudioAnalyzing` protocol, so Apple's Music Understanding can replace the in-house analyser as a drop-in when an iOS 27 SDK exists
- [ ] **BPM-09**: The analyser's accuracy is measured against the 29-track ground-truth set (known BPM + Camelot, audio already cached in `.local/`) and the figure is recorded — tempo scored octave-aware, key scored by Camelot distance
- [ ] **BPM-05**: A detected key is converted to Camelot notation
- [ ] **BPM-06**: Any BPM below 100 is doubled, unconditionally, to fold half-time reads into the genre's real range
- [ ] **BPM-07**: A track whose BPM cannot be established by any route is surfaced for manual entry rather than silently dropped

### Manual Entry

- [ ] **MAN-01**: User can enter or correct artist, title, BPM and key for any track in under 15 seconds
- [ ] **MAN-02**: Camelot key is chosen from a tap grid, not typed
- [ ] **MAN-03**: BPM entry pre-fills from a sensible neighbour value rather than starting empty
- [ ] **MAN-04**: A manually entered track is marked as such and is never silently overwritten by a later automatic resolution
- [ ] **MAN-05**: Manual entry is reachable directly from the sequenced list and from the excluded list, not only from a failure dialog

### Sequencing

- [ ] **SEQ-01**: Camelot distance is computed as flat hop count around the 12-position wheel, plus 1 for a letter change
- [ ] **SEQ-02**: The sequence never contains two tracks from the same physical vinyl
- [ ] **SEQ-03**: Consecutive tracks differ by no more than BPM_TOLERANCE, and BPM never decreases along the sequence
- [ ] **SEQ-04**: Among valid sequences, the one visiting the most vinyls wins; ties break on lowest total Camelot distance
- [ ] **SEQ-05**: User can adjust BPM_TOLERANCE on a slider from 3 to 6, defaulting to 4.0, and the sequence re-optimises
- [ ] **SEQ-06**: A vinyl with no track on the winning path is excluded, and shows a plain-language reason
- [ ] **SEQ-07**: Unresolved and excluded records share one collapsed section, each row carrying its own reason
- [ ] **SEQ-08**: Adding a vinyl re-runs the whole optimisation, and a previously excluded record rejoins if a new addition bridges the gap
- [ ] **SEQ-09**: Sequencing runs off the main thread and completes fast enough to feel instant at 100 vinyls / 400 candidates
- [ ] **SEQ-10**: Beam search is checked against a wider beam for divergence, so a silently suboptimal path is detectable
- [ ] **SEQ-11**: Every track in a crate shows its BPM and Camelot key as a badge in the sequenced list

### Persistence

- [ ] **PERS-01**: Crates, vinyls, candidate tracks, photos and sequences survive quitting and reopening the app
- [ ] **PERS-02**: Ordered data is stored with explicit integer ordering fields, never relying on relationship order
- [ ] **PERS-03**: Every candidate track stays stored even when unselected, because the sequencer needs them on every re-run
- [ ] **PERS-04**: All storage is on-device; nothing is uploaded anywhere

## v2 Requirements

### Export

- **EXP-01**: Export a finished sequence to Rekordbox via the owner's existing pyrekordbox workflow
- **EXP-02**: Export a sequence as CSV or M3U

### Alternative Audio Sources

- **ALT-01**: Capture 30s of the record playing through the microphone and analyse it with Music Understanding, for dubplates present nowhere online
- **ALT-02**: Match against local MusicLake audio files when the Mac is reachable

### Sequencing Sophistication

- **SEQ2-01**: Energy-arc templates (warm-up → peak → cool-down) instead of strictly monotonic BPM
- **SEQ2-02**: Deliberate BPM drops as an allowed transition
- **SEQ2-03**: Penalise Camelot letter changes more heavily than hop distance, if flat weighting produces poor sets

### Segmentation Sophistication

- **SEG2-01**: Polar-unwrap preprocessing for concentric labels, if the Phase 1 spike proves they are common

## Out of Scope

| Feature | Reason |
|---------|--------|
| Audio playback | This builds the set; the CDJs play it |
| Apple Music Understanding (for now) | Requires iOS 27; `MusicUnderstanding.framework` is absent from the installed SDK and the running system. Kept as a drop-in behind `AudioAnalyzing` for when Xcode 27 ships |
| aubio / Essentia | GPL/AGPL C/C++ vendoring for what ~350 lines of Accelerate does |
| GetSongBPM | Mandatory backlink cannot be satisfied — GitHub does not server-render READMEs and Pages cannot build with Actions disabled. Music Understanding removes the need |
| Spotify audio-features | Empirically returns HTTP 403 for the owner's credentials; not grandfathered past the Nov 2024 deprecation |
| AcoustID | Fingerprints audio to identify a recording; produces no tempo or key |
| AcousticBrainz dumps | Keyed by MusicBrainz MBID, so a white label missing from MusicBrainz is missing here too — same blind spot, 589GB of ETL for it |
| YouTube audio extraction | Fragile signature ciphers, constant breakage, and analyses a different master than the pressing in hand |
| Cloud sync, accounts, sharing | Single user, single device, no auth |
| App Store distribution | Personal build. This is what makes bundling credentials acceptable |
| More than one track per vinyl in a sequence | Hard rule. You cannot play two tracks off one record in one set without going back to it |
| A VLM or trained model for segmentation | Deterministic geometry first; revisit only if measured to fail |
| Barcode scanning | White labels and dubplates have no barcode. Solves the easy case only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETUP-01 | Phase 1 | Pending |
| SETUP-02 | Phase 1 | Pending |
| SETUP-03 | Phase 1 | Pending |
| SETUP-04 | Phase 1 | Pending |
| SEQ-01 | Phase 1 | Pending |
| SEQ-02 | Phase 1 | Pending |
| SEQ-03 | Phase 1 | Pending |
| SEQ-04 | Phase 1 | Pending |
| SEQ-05 | Phase 1 | Pending |
| SEQ-06 | Phase 1 | Pending |
| SEQ-07 | Phase 1 | Pending |
| SEQ-08 | Phase 1 | Pending |
| SEQ-09 | Phase 1 | Pending |
| SEQ-10 | Phase 1 | Pending |
| SEQ-11 | Phase 1 | Pending |
| CRATE-01 | Phase 1 | Pending |
| CRATE-02 | Phase 1 | Pending |
| CRATE-03 | Phase 1 | Pending |
| CRATE-04 | Phase 1 | Pending |
| CRATE-05 | Phase 1 | Pending |
| CRATE-06 | Phase 1 | Pending |
| CRATE-07 | Phase 1 | Pending |
| CAP-01 | Phase 2 | Pending |
| CAP-02 | Phase 2 | Pending |
| CAP-03 | Phase 2 | Pending |
| CAP-04 | Phase 2 | Pending |
| CAP-05 | Phase 2 | Pending |
| CAP-06 | Phase 2 | Pending |
| OCR-01 | Phase 2 | Pending |
| OCR-02 | Phase 2 | Pending |
| OCR-03 | Phase 2 | Pending |
| OCR-04 | Phase 2 | Pending |
| OCR-05 | Phase 2 | Pending |
| SEG-01 | Phase 3 | Pending |
| SEG-02 | Phase 3 | Pending |
| SEG-03 | Phase 3 | Pending |
| SEG-04 | Phase 3 | Pending |
| SEG-05 | Phase 3 | Pending |
| SEG-06 | Phase 3 | Pending |
| SEG-07 | Phase 3 | Pending |
| SEG-08 | Phase 3 | Pending |
| RES-01 | Phase 4 | Pending |
| RES-02 | Phase 4 | Pending |
| RES-03 | Phase 4 | Pending |
| RES-08 | Phase 4 | Pending |
| RES-04 | Phase 4 | Pending |
| RES-05 | Phase 4 | Pending |
| RES-06 | Phase 4 | Pending |
| RES-07 | Phase 4 | Pending |
| BPM-01 | Phase 4 | Pending |
| BPM-02 | Phase 4 | Pending |
| BPM-03 | Phase 4 | Pending |
| BPM-04 | Phase 4 | Pending |
| BPM-05 | Phase 4 | Pending |
| BPM-06 | Phase 4 | Pending |
| BPM-07 | Phase 4 | Pending |
| MAN-01 | Phase 5 | Pending |
| MAN-02 | Phase 5 | Pending |
| MAN-03 | Phase 5 | Pending |
| MAN-04 | Phase 5 | Pending |
| MAN-05 | Phase 5 | Pending |
| PERS-01 | Phase 6 | Pending |
| PERS-02 | Phase 6 | Pending |
| PERS-03 | Phase 6 | Pending |
| PERS-04 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 67 total
- Mapped to phases: 65/67 — BPM-08, BPM-09 pending remap
- Unmapped: 2 (BPM-08, BPM-09) ⚠️

**Note:** `SEG-01` moved from Phase 2 into Phase 3 during the roadmap revision. The Phase 2
OCR spike ran early (see `research/OCR-SPIKE.md`) and already answered the layout question
(sleeve typography, not concentric label text) directly, so `SEG-01` is now genuinely
Segmentation's own validation work — measuring the shipped angle-cluster algorithm against
the 12 committed fixtures — rather than a gate Phase 3's design was waiting on.

---
*Requirements defined: 2026-08-29*
*Last updated: 2026-08-29 after roadmap revision (post OCR-spike) — 65/65 requirements mapped to 6 phases*
