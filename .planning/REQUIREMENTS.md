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

- [x] **CAP-01**: User can photograph a vinyl label and the shutter returns to the camera immediately, with no blocking spinner
- [x] **CAP-02**: A framing guide overlay shows where to place the record sleeve, sized for a whole 12" sleeve rather than a label close-up
- [x] **CAP-03**: A thumbnail strip shows every vinyl scanned so far in this session with its per-item resolution status
- [ ] **CAP-04**: User can scan 20 vinyls in one session without the app stalling, running out of memory, or thermally throttling
- [x] **CAP-05**: When a scan yields tracks for only one side, an inline prompt offers Scan or Skip without leaving the camera — suppressed when both sides were already read from a single photo, which the fixtures show is common
- [x] **CAP-06**: User can tap Done to leave the capture loop and see the sequenced result

### Text Recognition

- [x] **OCR-01**: Each captured photo yields text observations with bounding boxes, per-observation confidence, and baseline angle
- [x] **OCR-02**: EXIF orientation is passed to `VNImageRequestHandler`, and the returned coordinates — which Vision reports in the ORIGINAL unrotated buffer space — are transformed into one documented convention exactly once
- [x] **OCR-03**: Recognition is seeded with a custom vocabulary of the owner's recurring label and artist names
- [x] **OCR-04**: Raw recognised text for a label can be inspected on screen, for debugging a bad read
- [x] **OCR-05**: OCR runs off the main thread and never blocks the capture loop

### Segmentation

- [x] **SEG-01**: Angle-cluster segmentation is validated against the 12 committed fixture photographs, reporting per-fixture track-count accuracy (baseline established in `research/OCR-SPIKE.md`: 6 clean / 5 partial / 1 fail)
- [x] **SEG-02**: Observations are grouped by BASELINE ANGLE to separate physical surfaces (sleeve vs. record label), then grouped within each cluster — not by radial distance from a label centre, which the fixtures disproved
- [x] **SEG-03**: Non-track text is filtered before clustering — shop price stickers (currency/decimal regex), RPM, ℗/© lines, addresses, URLs and emails. Catalogue numbers are EXTRACTED AND KEPT, not discarded
- [x] **SEG-04**: A side or track marker splits tracks in preference to geometry — covering `A`/`AA`/`B`/`BB`, `A1`/`B2`, `SIDE A`, `Side One`, and arbitrary named sides such as `COLD SIDE:` / `STEEL SIDE:` found in the fixtures
- [x] **SEG-05**: A parenthetical suffix (`(VIP)`, `(Remix)`, `(Dub)`) attaches to the preceding track rather than starting a new one
- [x] **SEG-06**: The app infers whether an unscanned flip side probably exists, from side markers or their absence
- [x] **SEG-07**: User can correct any segmentation result — split a track, merge two, or type a track line by hand
- [x] **SEG-08**: Only observations at the trusted confidence tier are used for track lines; the fixtures showed confidence is effectively binary (1.00 vs 0.50/0.30), so a fractional threshold is not a useful filter

### Metadata Resolution

- [x] **RES-01**: Each candidate track resolves to an artist and a title, or is explicitly marked as failed
- [x] **RES-02**: Resolution runs in the background per vinyl, with at most 3 requests in flight, and per-item status visible in the UI
- [x] **RES-03**: Discogs supplies release, artist, label and format; MusicBrainz is the fallback
- [x] **RES-08**: When a catalogue number is present it is used as the primary Discogs key ahead of artist+title — it read cleanly on 6 of 12 fixtures and is far more discriminating for white labels
- [x] **RES-04**: A match above 0.75 normalised similarity is accepted, 0.50–0.75 is queued for user confirmation, below 0.50 is rejected
- [x] **RES-05**: HTTP 429 triggers backoff and retry rather than a failed resolution
- [x] **RES-06**: Resolution results are cached, so re-running the sequencer never re-issues a network request
- [x] **RES-07**: Cancelling or leaving a crate cancels that crate's in-flight resolution work

### BPM and Key

- [x] **BPM-01**: Every resolved track carries a BPM and a Camelot key, or is explicitly marked as lacking them
- [x] **BPM-02**: A bundled read-only copy of the owner's existing 7,010-track BPM/Camelot corpus is consulted first, before any network call
- [x] **BPM-03**: When the bundled corpus misses, audio is fetched from SoundCloud using the owner's existing OAuth credentials
- [x] **BPM-04**: Fetched audio is analysed on-device by the app's own Accelerate/vDSP analyser to produce tempo and key, and is not retained afterwards
- [x] **BPM-08**: Audio analysis sits behind an `AudioAnalyzing` protocol, so Apple's Music Understanding can replace the in-house analyser as a drop-in when an iOS 27 SDK exists
- [x] **BPM-09**: The analyser's accuracy is measured against the 29-track ground-truth set (known BPM + Camelot, audio already cached in `.local/`) and the figure is recorded — tempo scored octave-aware, key scored by Camelot distance
- [x] **BPM-05**: A detected key is converted to Camelot notation
- [x] **BPM-06**: Any BPM below 100 is doubled, unconditionally, to fold half-time reads into the genre's real range
- [x] **BPM-07**: A track whose BPM cannot be established by any route is surfaced for manual entry rather than silently dropped

### Manual Entry

- [x] **MAN-01**: User can enter or correct artist, title, BPM and key for any track in under 15 seconds
- [x] **MAN-02**: Camelot key is chosen from a tap grid, not typed
- [x] **MAN-03**: BPM entry pre-fills from a sensible neighbour value rather than starting empty
- [x] **MAN-04**: A manually entered track is marked as such and is never silently overwritten by a later automatic resolution
- [x] **MAN-05**: Manual entry is reachable directly from the sequenced list and from the excluded list, not only from a failure dialog

### Sequencing

- [x] **SEQ-01**: Camelot distance is computed as flat hop count around the 12-position wheel, plus 1 for a letter change
- [x] **SEQ-02**: The sequence never contains two tracks from the same physical vinyl
- [x] **SEQ-03**: Consecutive tracks differ by no more than BPM_TOLERANCE in EITHER direction — `|bpm[i+1] − bpm[i]| ≤ tolerance`. The previous ordering clause is retired (owner decision 2026-08-30, see `.planning/SEQUENCER-SPEC.md`). Closed by Phase 5: `BPMRules.canFollow` is `abs(b - a) <= tolerance + 1e-9`, proved symmetric over a swept grid, and the search expands over the full neighbour set
- [x] **SEQ-04**: Among valid sequences, the one visiting the most vinyls wins; ties break on lowest total Camelot distance
- [ ] **SEQ-05**: User can adjust BPM_TOLERANCE on a slider from 3 to 6, defaulting to 4.0, and the sequence re-optimises
- [x] **SEQ-06**: A vinyl with no track on the winning path is excluded, and shows a plain-language reason
- [x] **SEQ-07**: Unresolved and excluded records share one collapsed section, each row carrying its own reason
- [x] **SEQ-08**: Adding a vinyl re-runs the whole optimisation, and a previously excluded record rejoins if a new addition bridges the gap — `RejoinTests`, vinyl IDs `[1, 3, 2]`, and removing the bridge excludes it again
- [x] **SEQ-09**: Sequencing runs off the main thread and completes fast enough to feel instant at 100 vinyls / 400 candidates — `AsyncSequencer` on a `Task.detached`; measured 1.1 s debug / 0.27 s release, 100 of 100 vinyls sequenced
- [x] **SEQ-10**: Beam search is checked against a wider beam for divergence, so a silently suboptimal path is detectable — `BeamDivergenceCheck`; 20 runs vs width 150 (19 identical counts, width 50 never the loser) and 20 vs width 400 (20 identical)
- [x] **SEQ-11**: Every track in a crate shows its BPM and Camelot key as a badge in the sequenced list

### Persistence

- [x] **PERS-01**: Crates, vinyls, candidate tracks, photos and sequences survive quitting and reopening the app
- [x] **PERS-02**: Ordered data is stored with explicit integer ordering fields, never relying on relationship order
- [x] **PERS-03**: Every candidate track stays stored even when unselected, because the sequencer needs them on every re-run
- [x] **PERS-04**: All storage is on-device; nothing is uploaded anywhere

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
| CAP-02 | Act I — Phase 3 | Complete — 03-01/03-03/03-05 |
| CAP-03 | Act I — Phase 3 | Complete — 03-01/03-03/03-05 |
| CAP-05 | Act I — Phase 3 | Complete — 03-01/03-03/03-05 |
| CAP-06 | Act I — Phase 3 | Complete — 03-03/03-05 |
| OCR-04 | Act I — Phase 3 | Complete — 03-02/03-04/03-05 |
| SEG-07 | Act I — Phase 3 | Complete — 03-02/03-04/03-05 |
| OCR-01 | Act II — Phase 6 | Complete — 06 |
| OCR-02 | Act II — Phase 6 | Complete — 06 |
| OCR-03 | Act II — Phase 6 | Complete — 06 |
| OCR-05 | Act II — Phase 6 | Complete — 06 |
| SEG-01 | Act II — Phase 6 | Complete — 06 |
| SEG-02 | Act II — Phase 6 | Complete — 06 |
| SEG-03 | Act II — Phase 6 | Complete — 06 |
| SEG-04 | Act II — Phase 6 | Complete — 06 |
| SEG-05 | Act II — Phase 6 | Complete — 06 |
| SEG-06 | Act II — Phase 6 | Complete — 06 |
| SEG-08 | Act II — Phase 6 | Complete — 06 |
| RES-01 | Act II — Phase 7 | Complete |
| RES-02 | Act II — Phase 7 + Phase 8 | **COMPLETE.** Engine in Phase 7 (max 3 in flight, proved by peak-in-flight). Phase 8 wired it: `CrateDetailView` resolves every record with no identity, one at a time, and `AppModel.resolving` drives a per-row "Resolving…" that appears and clears — asserted in the live walk, which fails if no per-item status is ever seen |
| RES-03 | Act II — Phase 7 | Complete |
| RES-04 | Act II — Phase 7 | Complete |
| RES-05 | Act II — Phase 7 | Complete |
| RES-06 | Act II — Phase 7 | Complete |
| RES-07 | Act II — Phase 7 | Complete |
| RES-08 | Act II — Phase 7 | Complete |
| BPM-01 | Act II — Phase 7 | Complete |
| BPM-02 | Act II — Phase 7 | Complete |
| BPM-03 | Act II — Phase 7 | Complete |
| BPM-04 | Act II — Phase 7 | Complete |
| BPM-05 | Act II — Phase 7 | Complete |
| BPM-06 | Act II — Phase 7 | Complete |
| BPM-07 | Act II — Phase 7 + Phase 8 + Phase 9 | **COMPLETE — Phase 9 built the manual-ENTRY path this row was waiting on.** A record with no tempo is now one tap from a sheet that pre-fills a neighbour's BPM (MAN-03), and V19 made the reason it prints the terminal cause rather than the last rung touched. Original note follows. Partial, and one half further on. Engine in Phase 7 (Track.needsManualBPM, identity kept, reason recorded). Phase 8 put the reason ON SCREEN: the not-included row now prints the ladder's own words ("no SoundCloud upload matched", "no identity to look a tempo up by") instead of the sequencer's "No BPM yet" — photographed in 03-walk-07-done-sequenced.png. The manual-ENTRY path is still Phase 12, so this stays open |
| BPM-08 | Act II — Phase 7 | Complete |
| BPM-09 | Act II — Phase 7 | Complete |
| SEQ-01 | Act II — Phase 9 | Complete — 01-03 |
| SEQ-02 | Act II — Phase 5 | Complete — re-validated under the bidirectional search |
| SEQ-03 | Act II — Phase 5 | Complete — 05, bidirectional gate + full-neighbour search |
| SEQ-04 | Act II — Phase 5 | Complete — re-validated; two-stage search, count then distance |
| SEQ-05 | Act II — Phase 9 | Pending |
| SEQ-06 | Act II — Phase 5 | Complete — re-validated under the bidirectional search |
| SEQ-08 | Act II — Phase 5 | Complete — 05 |
| SEQ-09 | Act II — Phase 5 | Complete — 05 |
| SEQ-10 | Act II — Phase 5 | Complete — 05 |
| CAP-01 | Act III — Phase 8 | **COMPLETE, measured.** The shutter is two-phase: `SleevePhotoSource.capture()` returns a `.reading` item the instant the photograph exists and `read()` follows. Measured in the live walk at 10-26 ms shutter-to-tile over 12 presses and 10-38 ms over 21, with **all twelve tiles observed still carrying `Reading`** while Vision ran. There is no spinner anywhere in the path. The live-camera half of the latency is UAT U2b |
| CAP-04 | Act III — Phase 8 | Partial, and the missing half is named rather than fudged. Measured: 21 consecutive captures, each a full HEIC decode plus a Vision pass, with recognition latency going 1165 ms to 962 ms (first-five against last-five mean) — no degradation. NOT measured, and not claimed: memory and thermals, which a simulator sharing the Mac's envelope and running no camera pipeline cannot show. UAT U2c |
| MAN-01 | Act III — Phase 9 | Complete — Phase 9. MEASURED as an interaction count, twice: a full four-field correction is **8 taps + 16 keystrokes + 1 sheet = 13.3 s** at 1.0 s/tap, 0.3 s/keystroke, 0.5 s/sheet. `ManualEntryUITests.swift` prints the count and fails over 15 s |
| MAN-02 | Act III — Phase 9 | Complete — Phase 9. 24-code grid, **one tap**, inside the two-tap bound with one to spare. `ManualEntryDraft.camelotGrid`, photographed in `09-manual-04-sheet-from-bucket.png` |
| MAN-03 | Act III — Phase 9 | Complete — Phase 9. Own tempo, else the crate's **folded median**, else 174. Median because one 87 BPM half-time read drags a mean out of the genre. Measured on screen: prefill `170` |
| MAN-04 | Act III — Phase 9 | Complete — Phase 9. **The gate ran the real `TrackResolver` and the real `BPMLadder`** against stubs contradicting every field, over a fully-typed and a half-typed track. Three field-level guards on `Track.isManual`, including the failure path — the one a white label actually travels. 12 `.manual` marks survived a `simctl` kill |
| MAN-05 | Act III — Phase 9 | Complete — Phase 9. One sheet, both entry points, the row IS the button. The bucket half is the one that mattered: 9 of 12 records landed there last run and none was correctable. Driven live, and a hand-entered tempo made a record **rejoin** — running order 2 → 3 |
| PERS-01 | Act III — Phase 9 | Complete — Phase 9. MEASURED: 20-vinyl crate, killed with **`simctl terminate`**, relaunched, canonical field-by-field dump **730/730 lines, 0 differing**. `Scripts/persistence-check.sh`, artefacts in `Artifacts/persistence/`. Second, independent observation through the harness in `ManualEntryUITests.swift` |
| PERS-02 | Act III — Phase 9 | Complete — Phase 9. `position: Int` on vinyl and track, `listPosition` on the crate, `manualOrder` a scalar `[UUID]`, the CRATE-07 selection ONE `[String]` of pairs. No ordered relationship anywhere. Sorted at the call site on the way out |
| PERS-03 | Act III — Phase 9 | Complete — Phase 9. MEASURED across the kill: **47 candidates survived, 20 selected, 27 UNSELECTED** |
| PERS-04 | Act III — Phase 9 | Complete — Phase 9. The container and the bundle are the only paths; nothing in `App/Persistence` opens a socket, and Core cannot |

**Coverage:**
- v1 requirements: 67 total
- Mapped to phases: 67/67 ✓
- Unmapped: 0
- Complete: **23** (SETUP-01/02/03/04, CRATE-01/02/03/04/05/06/07, CAP-02/03/05/06, OCR-04,
  SEG-07, SEQ-01/02/04/06/07/11)
- Outstanding: **44**

*Recounted 2026-08-30 by plan 03-05 **from the ticked boxes above, not from the previous line**.
Re-derive it in one command:*

```
grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md   ->  23
grep -c "^- \[ \] \*\*" .planning/REQUIREMENTS.md   ->  44          23 + 44 = 67
```

*Phase 3 added six: CAP-02/03/05/06 (the capture screen, 03-03), OCR-04 and SEG-07 (the inspect
sheet, 03-04), all six re-verified in one twelve-fixture session by 03-05. The previous figure of
17 was plan 02-05's, correct when written; it predates Phase 3 entirely. `SEQ-03` is still
**REOPENED** and is still not counted.*

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
2026-08-30, but the shipped Act I code and docs still assert — and in one place still
*implement* — the old non-decreasing rule in **seventeen places**. Phase 2 and Phase 4 both
deliberately did **not** touch them (`git diff --stat ce31189 HEAD` on
`VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/` is empty, so Phase 9's rewrite
starts from an unmodified Phase 1 baseline).

> **Corrected 2026-08-30 by plan 04-02.** This paragraph previously said *"five places"* and the
> table below listed **six** rows — the prose and the table disagreed with each other. The
> re-derived count is **seventeen**, and it is neither five nor six. The full two-pass
> derivation, the row-by-row classification of all 32 sweep hits, and the eleven specific errors
> in the old table are in **`.planning/phases/04-act-i-signoff/CARRIED-DEBT.md`**, which is the
> authoritative inventory and is kept honest by gate G8 of `Scripts/hygiene.sh`. The summary
> below is a pointer, not a second source of truth.

**Line numbers below are pinned at commit `073228f`** and every row is keyed on its matched
text — the old table's `ROADMAP.md:385` had drifted to `:415`, which is why line numbers are a
convenience here and not an identity.

| Artefact | What it asserts |
|---|---|
| `Sequencing/BPMRules.swift:17` | **THE ENFORCEMENT** — `b >= a && (b - a) <= tolerance + 1e-9`. The `b >= a` clause *is* the retired rule, in executable code. Contains no matching word, so no prose grep can find it |
| `Sequencing/BPMRules.swift:10` | doc comment: "D2: the sequence's only hard gate. Non-decreasing AND within tolerance" |
| `Sequencing/BPMRules.swift:11` | doc comment: "Monotonic BPM is an MVP simplification" |
| `Sequencing/BeamSearchSequencer.swift:51` | comment: "Ascending by folded BPM" — the pre-sort the single-pass algorithm depends on |
| `Sequencing/BeamSearchSequencer.swift:81` | comment: sorted-ascending order is a topological order of the "non-decreasing" DAG |
| `Domain/SequenceResult.swift:15` | doc comment: `sequence` is "non-decreasing BPM" |
| `Tests/…/BeamSearchSequencerTests.swift:36,37,41` | `test_givenSequence_whenInspected_thenBPMIsNonDecreasing` — green, ⚠️ STALE-marked, and wrong |
| `Tests/…/BeamSearchSequencerTests.swift:61,65` | `test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending` — green, wrong, and **NOT marked**. A third stale assertion the "two marked assertions" count never included |
| `Tests/…/BPMRulesTests.swift:48` | `#expect(BPMRules.canFollow(174, 170, tolerance: 4) == false)` — green, ⚠️ STALE-marked; the correct expectation under bidirectional adjacency is `true` |
| `docs/MVP-SPEC.md:131` | §5 hard gate: "bpm sequence is non-decreasing". **Omitted from the old table.** `.planning/SEQUENCER-SPEC.md` claims to supersede MVP-SPEC §5, but MVP-SPEC carries no marker saying so |
| `docs/MVP-SPEC.md:223` | §9 Definition of Done: "a sequenced set with ascending BPM". **Omitted from the old table** |
| `ROADMAP.md:304` | "SEQ-03 (BPM gate, non-decreasing)". **Omitted from the old table** |
| `ROADMAP.md:310` | plans to *re-assert* "`SEQ-03`'s non-decreasing guarantee" after fixing Q1. **Omitted from the old table** |
| `ROADMAP.md:415` | Definition of Done says "a sequenced set with ascending BPM" (listed as `:385` before; drifted) |
| ~~`Fixtures/NaiveBPMSortSequencer.swift:2`~~ | ~~stub sorts ascending by design~~ — **RESOLVED, not carried.** The file was deleted at commit `073228f` (plan 04-02) as unreferenced dead code |
| ~~`Tests/…/BPMRulesTests.swift:33`~~ | ~~section comment "D2: non-decreasing AND within tolerance"~~ — **reclassified.** Correct when written; commit `ce31189` rewrote it into a ⚠️ STALE supersession marker, which warns about the rule rather than asserting it |

**Open question carried into Phase 9:** `Q1` — `BeamSearchSequencer` may be order-dependent
because its rank tuple ends in a position-derived `start-index asc`. See
`.planning/open-questions/Q1-sequencer-determinism.md`. Phase 9 answers it or does not ship.

---
*Requirements defined: 2026-08-29*
*Last updated: 2026-08-30 at Phase 3 close (plan 03-05) — 67/67 mapped across 14 phases, 23 complete / 44 outstanding, recounted by command*
