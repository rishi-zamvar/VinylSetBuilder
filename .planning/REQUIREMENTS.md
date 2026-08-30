# Requirements: Vinyl Set Builder

**Defined:** 2026-08-29
**Core Value:** The sequenced set — an ordered, mixable run of records with sane tempo and
key transitions, that re-optimises when you add more.

## v1 Requirements

### Project Setup

- [x] **SETUP-01**: Xcode project builds and runs on a physical iPhone 14 Pro under the paid developer account, targeting **iOS 26** — the installed SDK
- [x] **SETUP-02**: Algorithm code (segmentation, sequencing, Camelot maths) lives in a local Swift package that links neither AVFoundation nor URLSession, so its tests cannot touch a camera or a network
- [x] **SETUP-03**: API credentials are read from `~/.config/keys/` at build time into a gitignored `Secrets.swift`, so no secret is ever committed to the public repo
- [x] **SETUP-04**: The full test suite runs from the command line with no device, no camera and no network

### Crate Management

- [x] **CRATE-01**: User can see a list of every saved crate with its name and record count
- [x] **CRATE-02**: User can create a new crate, name it, and land directly in the camera
- [x] **CRATE-03**: User can open a crate and see its sequenced running order
- [x] **CRATE-04**: User can manually reorder tracks in a crate, overriding the sequencer
- [x] **CRATE-05**: User can re-enter the capture loop from an existing crate via "Add More"
- [x] **CRATE-06**: User can delete a crate, and can remove a single vinyl from a crate
- [x] **CRATE-07**: The same vinyl can belong to several crates with a different selected track in each

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
- [x] **OCR-04**: Raw recognised text for a label can be inspected on screen, for debugging a bad read
- [ ] **OCR-05**: OCR runs off the main thread and never blocks the capture loop

### Segmentation

- [ ] **SEG-01**: Angle-cluster segmentation is validated against the 12 committed fixture photographs, reporting per-fixture track-count accuracy (baseline established in `research/OCR-SPIKE.md`: 6 clean / 5 partial / 1 fail)
- [ ] **SEG-02**: Observations are grouped by BASELINE ANGLE to separate physical surfaces (sleeve vs. record label), then grouped within each cluster — not by radial distance from a label centre, which the fixtures disproved
- [ ] **SEG-03**: Non-track text is filtered before clustering — shop price stickers (currency/decimal regex), RPM, ℗/© lines, addresses, URLs and emails. Catalogue numbers are EXTRACTED AND KEPT, not discarded
- [ ] **SEG-04**: A side or track marker splits tracks in preference to geometry — covering `A`/`AA`/`B`/`BB`, `A1`/`B2`, `SIDE A`, `Side One`, and arbitrary named sides such as `COLD SIDE:` / `STEEL SIDE:` found in the fixtures
- [ ] **SEG-05**: A parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one
- [ ] **SEG-06**: The app infers whether an unscanned flip side probably exists, from side markers or their absence
- [x] **SEG-07**: User can correct any segmentation result — split a track, merge two, or type a track line by hand
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

- [x] **SEQ-01**: Camelot distance is computed as flat hop count around the 12-position wheel, plus 1 for a letter change
- [x] **SEQ-02**: The sequence never contains two tracks from the same physical vinyl
- [ ] **SEQ-03**: Consecutive tracks differ by no more than BPM_TOLERANCE in EITHER direction — `|bpm[i+1] − bpm[i]| ≤ tolerance`. **The non-decreasing requirement is removed** (owner decision 2026-08-30, see `.planning/SEQUENCER-SPEC.md`). ⚠️ REOPENED — the shipped implementation enforces the old monotonic rule and its tests assert it, so both are now wrong
- [x] **SEQ-04**: Among valid sequences, the one visiting the most vinyls wins; ties break on lowest total Camelot distance
- [ ] **SEQ-05**: User can adjust BPM_TOLERANCE on a slider from 3 to 6, defaulting to 4.0, and the sequence re-optimises
- [x] **SEQ-06**: A vinyl with no track on the winning path is excluded, and shows a plain-language reason
- [x] **SEQ-07**: Unresolved and excluded records share one collapsed section, each row carrying its own reason
- [ ] **SEQ-08**: Adding a vinyl re-runs the whole optimisation, and a previously excluded record rejoins if a new addition bridges the gap
- [ ] **SEQ-09**: Sequencing runs off the main thread and completes fast enough to feel instant at 100 vinyls / 400 candidates
- [ ] **SEQ-10**: Beam search is checked against a wider beam for divergence, so a silently suboptimal path is detectable
- [x] **SEQ-11**: Every track in a crate shows its BPM and Camelot key as a badge in the sequenced list

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

Mapped against the three-act roadmap rebuilt 2026-08-30. Every v1 requirement maps to exactly
one phase; verification/hygiene phases (4, 11, 14) intentionally carry no requirements.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETUP-01 | Act I — Phase 1 | Complete — 01-02 |
| SETUP-02 | Act I — Phase 1 | Complete — 01-01 |
| SETUP-03 | Act I — Phase 1 | Complete — 01-02 |
| SETUP-04 | Act I — Phase 1 | Complete — 01-01 |
| CRATE-01 | Act I — Phase 2 | Complete — 01-06 |
| CRATE-02 | Act I — Phase 2 | Complete — 01-06 |
| CRATE-03 | Act I — Phase 2 | Complete — 02-01/02-03/02-04 |
| CRATE-04 | Act I — Phase 2 | Complete — 02-01/02-03/02-04 |
| CRATE-05 | Act I — Phase 2 | Complete — 02-01/02-03/02-04 |
| CRATE-06 | Act I — Phase 2 | Complete — 01-06 |
| CRATE-07 | Act I — Phase 2 | Complete — 01-06 |
| SEQ-07 | Act I — Phase 2 | Complete — 01-07 |
| SEQ-11 | Act I — Phase 2 | Complete — 01-07 |
| CAP-02 | Act I — Phase 3 | Pending |
| CAP-03 | Act I — Phase 3 | Pending |
| CAP-05 | Act I — Phase 3 | Pending |
| CAP-06 | Act I — Phase 3 | Pending |
| OCR-04 | Act I — Phase 3 | Complete |
| SEG-07 | Act I — Phase 3 | Complete |
| OCR-01 | Act II — Phase 5 | Pending |
| OCR-02 | Act II — Phase 5 | Pending |
| OCR-03 | Act II — Phase 5 | Pending |
| OCR-05 | Act II — Phase 5 | Pending |
| SEG-01 | Act II — Phase 6 | Pending |
| SEG-02 | Act II — Phase 6 | Pending |
| SEG-03 | Act II — Phase 6 | Pending |
| SEG-04 | Act II — Phase 6 | Pending |
| SEG-05 | Act II — Phase 6 | Pending |
| SEG-06 | Act II — Phase 6 | Pending |
| SEG-08 | Act II — Phase 6 | Pending |
| RES-01 | Act II — Phase 7 | Pending |
| RES-02 | Act II — Phase 7 | Pending |
| RES-03 | Act II — Phase 7 | Pending |
| RES-04 | Act II — Phase 7 | Pending |
| RES-05 | Act II — Phase 7 | Pending |
| RES-06 | Act II — Phase 7 | Pending |
| RES-07 | Act II — Phase 7 | Pending |
| RES-08 | Act II — Phase 7 | Pending |
| BPM-01 | Act II — Phase 8 | Pending |
| BPM-02 | Act II — Phase 8 | Pending |
| BPM-03 | Act II — Phase 8 | Pending |
| BPM-04 | Act II — Phase 8 | Pending |
| BPM-05 | Act II — Phase 8 | Pending |
| BPM-06 | Act II — Phase 8 | Pending |
| BPM-07 | Act II — Phase 8 | Pending |
| BPM-08 | Act II — Phase 8 | Pending |
| BPM-09 | Act II — Phase 8 | Pending |
| SEQ-01 | Act II — Phase 9 | Complete — 01-03 |
| SEQ-02 | Act II — Phase 9 | Complete — 01-04, re-validate under bidirectional search |
| SEQ-03 | Act II — Phase 9 | ⚠️ REOPENED — spec changed 2026-08-30 |
| SEQ-04 | Act II — Phase 9 | Complete — 01-04, re-validate under bidirectional search |
| SEQ-05 | Act II — Phase 9 | Pending |
| SEQ-06 | Act II — Phase 9 | Complete — 01-04, re-validate under bidirectional search |
| SEQ-08 | Act II — Phase 9 | Pending |
| SEQ-09 | Act II — Phase 9 | Pending |
| SEQ-10 | Act II — Phase 9 | Pending |
| CAP-01 | Act III — Phase 10 | Pending |
| CAP-04 | Act III — Phase 10 | Pending |
| MAN-01 | Act III — Phase 12 | Pending |
| MAN-02 | Act III — Phase 12 | Pending |
| MAN-03 | Act III — Phase 12 | Pending |
| MAN-04 | Act III — Phase 12 | Pending |
| MAN-05 | Act III — Phase 12 | Pending |
| PERS-01 | Act III — Phase 13 | Pending |
| PERS-02 | Act III — Phase 13 | Pending |
| PERS-03 | Act III — Phase 13 | Pending |
| PERS-04 | Act III — Phase 13 | Pending |

**Coverage:**
- v1 requirements: 67 total
- Mapped to phases: 67/67 ✓
- Unmapped: 0
- Complete: 17 (SETUP-01/02/03/04, CRATE-01/02/03/04/05/06/07, SEQ-01/02/04/06/07/11)
- Outstanding: 50

*Recounted 2026-08-30 by plan 02-05 from the ticked boxes above, not from the previous line:
`grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md` → 17. The old figure said 15 and named
`SEQ-03` as complete, which contradicts SEQ-03's own entry — it is **REOPENED**. It also omitted
CRATE-03/04/05, which Phase 2 delivered and photographed.*

**Placement notes:**
- `CAP-02/03/05/06` are screens and sit in Act I (Phase 3), rendered from the 12 fixture
  photographs. `CAP-01` (non-blocking shutter) and `CAP-04` (20 records without stalling or
  throttling) are live-camera behaviours and sit in Act III (Phase 10) — the simulator has no
  camera, so they cannot be verified in Act I.
- `OCR-04` (raw text inspectable on screen) and `SEG-07` (correct a segmentation) are the
  inspect/correct *sheet*, built in Act I against fixture observations and fed real data by
  the Act III swap. The engine requirements they sit next to (`OCR-01/02/03/05`,
  `SEG-01…06/08`) are headless Act II work.
- `SEQ-07` and `SEQ-11` are display concerns — the not-included bucket and the BPM/Camelot
  badges — so they belong to the Act I shell, not to the Act II sequencer phase.
- `MAN-01…05` sit in Act III per the mandated act structure, so the manual-entry sheet is the
  one screen Act I does not build. Recorded as a decision, not a gap.

**Carried into Phase 9 — `AsyncSequencer` and `BeamDivergenceCheck` DO NOT EXIST.** Plan 01-05
was written but never executed, so there is no async sequencing seam and no beam-divergence
check on disk. `grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/`
returns nothing (run by plan 02-05, 2026-08-30). **SEQ-08, SEQ-09 and SEQ-10 are therefore
wholly outstanding**, not partially built, and Phase 9 inherits `01-05-PLAN.md`'s content along
with `.planning/open-questions/RejoinTests.swift.wip`. This is a real gap between what the
Phase 1 record implies and what is on disk — do not plan against a file that is not there.

**Carried into Phase 9 — the monotonic-BPM artefacts inventory.** SEQ-03 went bidirectional on
2026-08-30, but the shipped Act I code and docs still assert the old non-decreasing rule in
five places. Phase 2 deliberately did **not** touch them (`git diff --stat` on
`VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/` is empty, so Phase 9's rewrite
starts from an unmodified Phase 1 baseline). The full list, so Phase 9 does not have to
re-derive it:

| Artefact | What it asserts |
|---|---|
| `Sequencing/BeamSearchSequencer.swift:81` | comment: sorted-ascending order is a topological order of the "non-decreasing" DAG |
| `Domain/SequenceResult.swift:15` | doc comment: `sequence` is "non-decreasing BPM" |
| `Tests/…/BeamSearchSequencerTests.swift:30` | test *"BPM is non-decreasing across the whole winning sequence"* — currently green, and wrong |
| `Tests/…/BPMRulesTests.swift:33` | section comment "D2: non-decreasing AND within tolerance" |
| `Fixtures/NaiveBPMSortSequencer.swift:2` | stub sorts ascending by design |
| `ROADMAP.md:385` | Definition of Done says "a sequenced set with ascending BPM" |

**Open question carried into Phase 9:** `Q1` — `BeamSearchSequencer` may be order-dependent
because its rank tuple ends in a position-derived `start-index asc`. See
`.planning/open-questions/Q1-sequencer-determinism.md`. Phase 9 answers it or does not ship.

---
*Requirements defined: 2026-08-29*
*Last updated: 2026-08-30 after the three-act roadmap rebuild — 67/67 mapped across 14 phases*
