---
phase: 06
plan: 06
subsystem: ocr-segmentation
tags: [ocr, segmentation, vision, measured-gate, V12]
requires: [05]
provides:
  - TextRecognizing seam + SleeveTextRecognizer (OCR-01/02/03/05)
  - ObservationGeometry.upright — the one EXIF transform (OCR-02)
  - AngleClusterSegmenter + LabelSegmentation (SEG-01..06, SEG-08)
  - VinylEntry.catalogueNumber — the Phase 7 resolution key
  - Scripts/ocr-score.sh — the measured acceptance gate
affects: [07, 08]
tech-stack:
  added: [VNRecognizeTextRequest, ImageIO]
  patterns: [angle-clustering, approximate-substring-scoring, Task.detached-off-main]
key-files:
  created:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/OCR/ObservationGeometry.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/OCR/FuzzyMatch.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/OCR/TextRecognizing.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/OCR/RecognitionVocabulary.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/TrackTextFilter.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/AngleClusterSegmenter.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/LabelSegmentation.swift
    - App/OCR/SleeveTextRecognizer.swift
    - Tools/ocr-harness/main.swift
    - Scripts/ocr-score.sh
    - .planning/phases/06-ocr-segmentation/expected-scores.json
    - Artifacts/ocr/score-run1.json, score-run2.json, score-run3.json
  modified:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Segmentation/LabelSegmenting.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Capture/CaptureSession.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Domain/VinylEntry.swift
decisions:
  - D-06-1 the EXIF transform is applied in exactly one place and is deliberately not idempotent
  - D-06-2 cap height is inverted from the axis-aligned box, not taken as min(w,h)
  - D-06-3 the gate runs real recognition over the .HEIC files, never the recorded JSON
  - D-06-4 VNRecognizeTextRequest kept over RecognizeTextRequest so the baseline is comparable
  - D-06-5 the segmenter is NOT swapped into the app — that is Phase 8's per-swap-verified job
metrics:
  duration: ~2h15m
  completed: 2026-08-30
  tasks: 6
  tests: 200 -> 236
---

# Phase 6 Plan 06: OCR & Segmentation Summary

Real `Vision` recognition behind a `TextRecognizing` seam with EXIF orientation passed and
corrected exactly once, and pure baseline-angle segmentation in Core — **6 clean / 5 partial /
1 fail** and **9 of 12** usable track counts on live runs over the owner's twelve photographs,
with **6 of 6** catalogue numbers kept and **V12 closed**.

---

## 1. The two acceptance numbers

Both were measured by `./Scripts/ocr-score.sh`, which compiles the **shipping** recogniser
(`App/OCR/SleeveTextRecognizer.swift`) and the **shipping** segmenter into one macOS binary and
runs real recognition over `Tests/Fixtures/Labels/*.HEIC`. It never reads
`.local/ocr/ocr2_out.json` — a gate that scored a recording would pass with the reader unplugged.

| Gate | Baseline | Measured | Times measured |
|---|---|---|---|
| **1 — OCR** | ≥ 6 clean / 5 partial / 1 fail | **6 clean / 5 partial / 1 fail** | **3** (`score-run1/2/3.json`) |
| **2 — segmentation** | ≥ 9 of 12 usable track counts | **9 of 12** | **3** |
| **3 — catalogue** | ≥ 5 of the 6 that carry one | **6 of 6, 0 invented** | **3** |

Runs 1, 2 and 3 are **byte-identical apart from timings** — checked by diffing the JSON with the
millisecond field removed. The per-fixture scoring is committed to `Artifacts/ocr/`.

### Per-fixture, from the live run

| Fixture | verdict (want) | slots | tracks (want) | catalogue | segmenter's lines |
|---|---|---|---|---|---|
| IMG_0498 | clean (clean) | 3/3 | **2 (2)** ✅ | `0-44904` | `Abstract` · `The Message - Brown Gtauno Originat Mix!` |
| IMG_0499 | clean (clean) | 3/3 | **2 (2)** ✅ | `EMF2029` | `A: DRAGSTAR` · `AA: ELEMENTZ` |
| IMG_0500 | partial (partial) | 2/3 | **1 (2)** ❌ | `0-44845` | one line, un-split |
| IMG_0501 | partial (partial) | 2/3 | **3 (2)** ❌ | — | `LINU ME` · `STAY` · `eFOCUSED` |
| IMG_0502 | partial (partial) | 2/3 | **1 (1)** ✅ | — | `JA22 •MAIATCIN DAVE ANCEL MIX` |
| IMG_0503 | clean (clean) | 3/3 | **2 (2)** ✅ | `TYME012` | `A: HIGH DOWN` · `AAA: STRANGE NAT URE` |
| IMG_0504 | clean (clean) | 3/3 | **3 (2)** ❌ | — | `xtasia` · `fellowship` · `'sweetness'` |
| IMG_0505 | clean (clean) | 3/3 | **2 (2)** ✅ | `TECH008` | `DUBTRACK` · `SUPERSONIC` |
| IMG_0506 | clean (clean) | 3/3 | **2 (2)** ✅ | `CSI006` | `COLD: WIDE OPBY` · `STEEL` |
| IMG_0507 | fail (fail) | 0/2 | **0 (0)** ✅ | — | *(nothing)* |
| IMG_0508 | partial (partial) | 1/2 | **1 (1)** ✅ | — | `Da Lick` |
| IMG_0509 | partial (partial) | 2/3 | **2 (2)** ✅ | — | `SONIC` · `"SMADON MIND` |

**Zero per-fixture verdict drift.** Every one of the twelve reached the verdict the spike's
scored-results table recorded, so the gate is a genuine regression detector and not a total that
happens to sum right.

### What the OCR score actually measures — stated plainly

The score is a **regression gate against `research/OCR-SPIKE.md`, not a measure of absolute
accuracy against a discography.** Each fixture carries one artist slot and one slot per title,
each written as the **shortest distinctive form** of that element (`Brown` for
*Fuck Willie Brown (Dom & Roland Remix)*, because `Brown` is what a reader can plausibly return).
A slot is `null` when the spike could not read that element at all; a `null` slot can never be
found. `clean` = every slot found, `fail` = none, `partial` = between. Matching is
approximate-substring at one edit per four characters, over the alphanumeric concatenation of
**all** observations at every confidence — which is how the spike itself scored, and is why
untrusted reads count here but not in segmentation (SEG-08 governs that).

The one-edit-per-four ratio was fixed **before** the first run and calibrated on a datum the
spike already published: `WIDE OPBY` for `WIDE OPEN`, two edits in eight. It is tight enough to
still reject `JA22` for `JAZZ` — two edits in four — which the spike scored as a miss.

---

## 2. V12 — closed, with a route back to the defect

The inspect sheet titled a record **`Zzz.`**, a shard of a shop price sticker, on a photograph
that also read `Cause 4 Concern` at confidence 1.00. `CaptureItem.displayLabel` took the *first
trusted observation in reading order*, and reader order is **spatial, not semantic**, so whatever
scrap sat highest-left on the sleeve became the record's name.

**Fix (`f980c1a`):** `displayLabel` now takes the first trusted reading the SEG-03 noise filter
**keeps**. One definition of "not a track line", shared by the thing that names records and the
thing that lists them.

| Evidence | What it shows |
|---|---|
| the **previous** `03-04-sheet-lines.png` | the defect — title bar reads `Zzz.` |
| the **regenerated** `03-04-sheet-lines.png` | the fix — title bar reads `Cause 4 Concern-` |
| `FixtureObservations.swift:205` | the defect's precondition, independent of any screen |
| `test_givenAFixtureWhoseFirstTrustedReadIsASticker_whenNamed_thenItSkipsIt` | reddens if the filter is removed; asserts the precondition too, so it cannot pass vacuously |
| `test_givenTheTwelveFixtures_whenNamed_thenNoNameIsFilteredNoise` | covers all twelve, not the one |

`Zzz.` is reached by **two independent rules** — the four-alphanumeric floor and the
trebled-character rule — so removing either one does not reopen the defect.

**A second record moved, and it was not in the ticket.** `IMG_0508` was named `$10.007`; it is now
named `Da Lick`, which is the record's actual title. The other ten names are unchanged.

---

## 3. What was built

**Core, pure, no image and no framework:**

- `ObservationGeometry.upright(_:orientation:)` — **OCR-02, and the only place it happens.** For
  orientation 6 the point map is `(x, y) → (1 − y, x)` and the direction map is `angle + 90°`,
  which sends the measured raw sleeve angle of −90° to 0°. A test asserts the transform is **not
  idempotent**, so applying it twice by mistake cannot go unnoticed.
- `ObservationGeometry.capHeight` — inverts the axis-aligned box of rotated text
  (`H = (h·|cos θ| − w·|sin θ|)/(cos²θ − sin²θ)`), falling back to `min(w, h)` within 15° of the
  diagonal. This is the single change that lifted the pipeline off its floor: `DUBTRACK` on
  IMG_0505 measures `min(w,h) = 0.061` against a true cap height of **0.026**, and at 0.061 its
  two track lines merge into one. A test round-trips a synthesised box at ten angles.
- `FuzzyMatch` — Levenshtein, plus Sellers' approximate-substring variant that scores the gate.
- `TrackTextFilter` — SEG-03/04/05/08. Every pattern answers a string the spike measured.
- `AngleClusterSegmenter` + `LabelSegmentation` — SEG-01/02/06.
- `TextRecognizing` + `RecognizedSleeve` + `RecognitionVocabulary` — the OCR seam and OCR-03's
  bias list.

**App, the one file that names the framework:** `SleeveTextRecognizer` reads the file's EXIF
orientation and passes it explicitly (the handler ignores it otherwise), turns language
correction off, seeds `customWords`, and runs inside `Task.detached` so the shutter never stalls
(OCR-05).

**The pipeline, in order:** trusted tier → catalogue extracted **and kept** → noise filtered →
angle-clustered → cross-cluster repeats dropped as artist/label → near-duplicates collapsed →
side markers split in preference to geometry → otherwise lines by perpendicular projection →
artist-marked lines dropped → version qualifiers attached upward.

Two of those steps are worth naming because they are what actually works:

- **A string read in two different angle clusters is the artist or the label, never a track.**
  It is the sleeve and the record saying the same name. Fuzzy, because the second reading is
  worse than the first — `DRUMSOUND &` on the sleeve, `RUMSOUND &` on the label. This is what
  takes IMG_0505 from four candidate lines to its two real titles.
- **A record that names two or more sides has told you how many tracks it has**, and it is a
  better witness than any geometry. That alone gets IMG_0499, IMG_0503 and IMG_0506 exactly right.

---

## 4. What was NOT built, and why

| Not built | Why |
|---|---|
| Label-centre detection, circle finding, **polar unwrapping** | Spike Finding 1/2 — these are sleeves. Radial clustering would cluster around the wrong object. `SEG2-01` stays deferred. |
| A fractional confidence threshold | Confidence is 1.00/0.50/0.30 with nothing between. `>= 1.0` **is** the filter. |
| **The swap of `AngleClusterSegmenter` into `CaptureView`** | `App/Views/CaptureView.swift:35` still constructs `FixtureLineSegmenter`. Phase 8's named job is "each stub replaced one at a time, the walk re-verified after every single swap". Doing it here would be doing it **without** that per-swap verification, and would orphan `FixtureLineSegmenter` into a hygiene G5 failure in the same commit. |
| A second de-duplicator for the inspect sheet (V16) | The de-duplicator exists in the segmenter and is measured. It reaches the sheet via the Phase 8 swap. Writing a second one now is writing one Phase 8 deletes. |
| Live camera capture | Phase 8. This phase reads files. |
| Resolving any string to a real release | Phase 7. This phase produces the key; Phase 7 spends it. |

---

## 5. Deviations from plan

**1. [Rule 4-adjacent, decided and recorded] `VNRecognizeTextRequest` kept over the Swift-native
`RecognizeTextRequest`.** `CLAUDE.md` calls the newer API "preferred" at the iOS 26 target, and
also states the older one "is not deprecated and remains a valid fallback — it is what the OCR
spike used". Phase 6's gate is a **regression gate against a baseline the older API produced**.
Swapping readers would have confounded the measurement the gate exists to make: a changed number
could not have been attributed to the segmenter or to the reader. The older API is used, the
reason is written into the file's doc comment, and re-measuring the baseline under
`RecognizeTextRequest` is named there as the right follow-up.

**2. [Rule 1 — bug] The trebled-character noise rule ate a real side marker.** `AAA: Strange Nat
ure` is IMG_0503's B-side and `AAA` is three identical characters. Unbounded, the rule filtered
it, the side count fell to one, and the fixture dropped from 2 tracks to 3 lines — 8 of 12
instead of 9. The rule is now bounded to strings of four alphanumerics or fewer, which is all it
ever needed to be (`Zzz.` is three), and a test asserts the marker survives. Caught by the
suite on its first green run, not by reading. Commit `1c4ed55`.

**3. [Rule 3 — blocking] `TextObservation` is ambiguous at this SDK level.** The recognition
framework ships its own type of that name, so the app target would not compile. Fully qualified
at the two sites in `SleeveTextRecognizer`. Commit `9d9db2c`.

**4. [Rule 3 — blocking] `Regex` is not `Sendable`,** so the boilerplate patterns could not be a
`static let [Regex<Substring>]`. Rewritten as three alternations. Commit `1db5f22`.

**5. [Rule 2] `ledger-check.py` rejected a grammatical headline.** Its template hard-coded
"of which M **are** Medium or above" and the count is now 1. The regex accepts `is|are`; **no
threshold and no count was touched**, and the checker's own self-test still passes all cases.

---

## 6. What failed, and what disagrees

**The live run does NOT disagree with the recorded JSON.** This was the one thing the phase was
asked to check honestly, so it was checked directly: the shipped segmenter was run over
`FixtureObservations` (the committed transcription of `ocr2_out.json`) and over the live
recognition of the twelve `.HEIC` files, and the two agree **fixture for fixture** — same 9 of 12,
same three misses, same six catalogue numbers, same track lines. The live observation counts also
reproduce the recording exactly: 104 observations, **89** trusted, and the same per-fixture split
(11/9, 7/5, 9/7, 5/5, 5/4, 16/16, 6/4, 12/11, 12/9, 3/3, 11/10, 7/6).

**Three fixtures miss their track count, and none of them is a near miss of a good rule:**

- **IMG_0500 → 1, wants 2.** *Invocación* has an Original Version and a Remix. `Gide One /` is a
  misread `Side One` and is recognised as a side header, but only one side is stated, so the
  side rule cannot fire and geometry puts all five surviving reads on one line.
- **IMG_0501 → 3, wants 2.** `STAY` and `eFOCUSED` are two lines of type for one title, *Stay
  Focused*, and `LINU ME` is a garbled fragment of the other. Nothing available to a geometric
  segmenter joins the first pair or rejects the third.
- **IMG_0504 → 3, wants 2.** `fellowship` is the artist and sits **between** the two titles on
  the sleeve. There is no positional signal that says so, and no cross-cluster repeat to catch it
  — this photograph has only one angle cluster. Phase 7's resolver is what can say
  "`fellowship` is an artist" with evidence.

**The plan's stated sensitivity figures were wrong and are corrected here.** The plan quoted
`0.3 → 8, 0.4 → 8, 0.5 → 10, 0.6 → 9, 0.8 → 7` for `lineGapFactor`, taken from a throwaway
prototype. The **shipped** implementation measures `0.2 → 8, 0.3 → 8, 0.4/0.5/0.6/0.7 → 9,
0.8 → 7, 1.5 → 6`, and for `angleTolerance` `10°/15°/20°/25° → 9, 30°/40° → 8`. The prototype and
the implementation differ on IMG_0500 alone. The shipped numbers are the ones in the source
comment. The chosen value sits **in the middle of a four-wide plateau**, not on a spike, which is
the only thing that makes a constant fitted to its own corpus worth trusting at all — and it
**was** fitted to these twelve, with no held-out set. That is stated, not glossed.

**V15 and V16 were assigned to this phase and are re-carried, not closed.** V15's premise turned
out to be **half false**: the 106-character line that motivated it is confidence 0.30 and lives in
the raw-text view, which OCR-04 exists to show unfiltered and which segmentation never touches.
The other half of V15, and all of V16, are real and the mechanism now exists and is measured —
but it reaches the inspect sheet only through the Phase 8 swap. Both rows now name Phase 8 with
that written down. Phase 6 closed **one** of the three rows it was given.

---

## 7. The gate was proved able to fail

The OCR gate is brand new, so it carries negative controls (`RIGOR-POLICY.md`: only brand-new
gates do).

| Control | Mutation | Result |
|---|---|---|
| **NC-1** | committed baseline raised to 7 clean, run unchanged | `BASELINE NOT MET: clean 6 < 7`, **rc=1** |
| **NC-2** | `lineGapFactor` 0.5 → 1.5 | `BASELINE NOT MET: usable 6 < 9`, and the **Core unit test reddens on the same mutation** — the gate and the suite are two witnesses, not one twice |
| **NC-3** *(in the harness, every run)* | junk text scored against real ground truth | scores `fail` |
| **NC-4** *(in the harness, every run)* | a real read scored against its own ground truth | scores `clean` |
| baseline | unmutated | **rc=0** |

Every exit code was read **from the process**, not from the tail of a pipeline. This project has
twice been burned by a script exiting 0 having measured nothing.

---

## 8. Final battery

| Check | Result |
|---|---|
| `./Scripts/test.sh` | **236 passed**, 0 failed (was 200) |
| `./Scripts/hygiene.sh` | **9 pass, 0 fail** |
| `./Scripts/build-app.sh` | **BUILD SUCCEEDED** (iOS 26 device SDK) |
| `./Scripts/ocr-score.sh` | **BASELINE HELD** ×3 |
| `./Scripts/screenshots.sh` | **rc=0 first run**; audit gates A/B/C green; 46 files, 44 distinct states, 0 orphans |
| `python3 Scripts/probe-frames.py --check` | `SUSPECT: none (46 frames measured)` |
| UI suite, from `build/ui.xcresult` | total 7, passed 7, failed 0 |
| `python3 Scripts/ledger-check.py` | rc=0 — 18 rows, **10 closed**, 8 carried, **1** Medium-or-above open |

Requirements: **27 → 38 complete of 67.** OCR-01/02/03/05 and SEG-01/02/03/04/05/06/08.

35 screenshots regenerated, in one run, because two record names moved.

---

## Known Stubs

None introduced. One **pre-existing** stub is deliberately left in place and is named above:
`App/Views/CaptureView.swift:35` still constructs `FixtureLineSegmenter` rather than
`AngleClusterSegmenter`. The real segmenter is built, tested and measured; wiring it is Phase 8's
swap, which re-verifies the walk after every single substitution. This is why V15 and V16 are
re-carried rather than closed, and it is written into both ledger rows.

---

## Self-Check: PASSED

Every file this summary names exists on disk (14 of 14 created, checked by `[ -f ]`). Every
commit hash it cites is in the log (14 of 14, checked by `git log --oneline --all | grep`). The
one claim that could have been flattering — that the segmenter is deliberately NOT wired into
the app — is verified in the other direction: `App/Views/CaptureView.swift:35` does still read
`private let segmenter = FixtureLineSegmenter()`.
