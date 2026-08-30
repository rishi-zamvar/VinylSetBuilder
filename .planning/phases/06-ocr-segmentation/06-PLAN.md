---
phase: 06
plan: 06
title: OCR & Segmentation
type: implementation
autonomous: true
wave: 1
depends_on: [05]
requirements: [OCR-01, OCR-02, OCR-03, OCR-05, SEG-01, SEG-02, SEG-03, SEG-04, SEG-05, SEG-06, SEG-08]
---

# Phase 6 — OCR & Segmentation

## Objective

Turn the twelve photographed sleeves into track lines. Real `Vision` text recognition behind a
`TextRecognizing` seam in the **app** target, EXIF orientation passed and the returned coordinates
transformed into one convention **exactly once**; pure baseline-angle segmentation in **Core**,
measured on the same twelve fixtures.

Close **V12** — the price-sticker fragment `"Zzz."` must stop titling a record.

## Context

- `.planning/research/OCR-SPIKE.md` — the measured spike. **Every finding in it is a fact and is
  not re-derived.** Sleeves not labels; angle clustering not radial; EXIF orientation explicit;
  binary confidence; catalogue numbers kept; price stickers dominant; broad side markers.
- `.local/ocr/ocr2.swift` + `ocr2_out.json` — the working EXIF-correct probe and its output
  (104 observations, **89** trusted).
- `Tests/Fixtures/Labels/*.HEIC` — the twelve photographs (gitignored, restored from `~/Desktop/test/`).
- `.planning/VISUAL-DEFECTS.md` V12 — carried to this phase by name.
- `.planning/RIGOR-POLICY.md` — TDD stands; the measured acceptance gate stands; negative
  controls only on brand-new gates; two observations only for the headline numbers.

## What this phase does NOT build, decided before any code

| Not built | Why |
|---|---|
| Label-centre detection, circle finding, **polar unwrapping** | Spike Finding 1/2. The records are sleeves; radial clustering would cluster around the wrong object. `SEG2-01` stays deferred. |
| A fractional confidence threshold | Finding 4. Confidence is 1.00 / 0.50 / 0.30 and nothing between, so `>= 1.0` **is** the filter (SEG-08). A `0.35` cut-off would invent precision the reader does not have. |
| A second OCR path for the correction sheet | `RawObservationRows` already renders untrusted reads (OCR-04, shipped in Phase 3). |
| Live camera capture | Phase 8. This phase reads files. |
| Resolution of any recognised string to a real release | Phase 7. This phase produces the **key** (catalogue number, artist-ish and title-ish lines); Phase 7 spends it. |

## Design, fixed before implementation

### The one transform (OCR-02)

`Vision` reports normalised coordinates **in the original, unrotated buffer**, even when handed an
orientation. All twelve fixtures are orientation **6** (`.right`). The single documented transform
lives in Core as `ObservationGeometry.upright(_:orientation:)`:

- point map `(x, y) → (1 − y, x)` (a 90° CCW rotation of the buffer's bottom-left-origin frame),
  so a bounding box `(x, y, w, h)` becomes `(1 − (y + h), x, h, w)`
- direction map `(dx, dy) → (−dy, dx)`, i.e. **`angle + 90°`** — which sends the measured raw
  sleeve angle of `−90°` to `0°`, exactly as an upright photograph should read.

It is applied in **one** place, at the boundary where observations enter the segmenter. Nothing
downstream re-rotates.

### Cap height, and why `min(w, h)` is wrong

Line grouping needs the thickness of a text line. `Vision` gives an **axis-aligned** box around
**rotated** text, so for text at angle θ with true width `W` and cap height `H`:

    w = W·|cos θ| + H·|sin θ|        h = W·|sin θ| + H·|cos θ|

giving `H = (h·|cos θ| − w·|sin θ|) / (cos²θ − sin²θ)`. Near 45° the denominator vanishes, so the
guard falls back to `min(w, h)`. This is not a tuning knob — it is the correct inverse, and it is
the single change that took the prototype from 7/12 to 10/12: `DUBTRACK` in IMG_0505 measures
`min(w,h) = 0.061` but a true cap height of **0.026**, and at 0.061 the two track lines merge.

### The segmentation pipeline (SEG-01…06, SEG-08)

1. **Trusted tier only** — `confidence >= 1.0` (SEG-08).
2. **Catalogue number extracted and kept** (SEG-03) — `[A-Z]{3,6}\s?\d{2,4}` or `\d-\d{4,6}`,
   removed from the track-line pool and carried as a field on the result and on `VinylEntry`.
   Three letters minimum, deliberately: two would swallow `JA22`, a misread *title* in IMG_0502.
3. **Noise filter** (SEG-03) — currency/decimal, percent, URL/email, `MADE IN`, `PUBLISHED BY`,
   `WRITTEN AND PRODUCED`, `RECORDINGS`/`RECORDS`, genre words, format marks, all-digit strings,
   and anything under **4** alphanumerics. Four, not three, because `Zzz.` is three.
4. **Angle clustering** (SEG-02) — circular gap clustering on the upright baseline angle,
   tolerance **20°**, with wrap-around merge.
5. **Cross-cluster repeats are the artist or the label, not a track** — a string that appears in
   two different angle clusters is the sleeve *and* the record saying the same name. Fuzzy, so
   `DRUMSOUND &` and `RUMSOUND &` collapse.
6. **Near-duplicate collapse inside a cluster** — `Da Lick` × 3 and `Da Lich` are one track.
7. **Side markers split in preference to geometry** (SEG-04) — `A:`/`AA:`/`AAA:`/`B:`/`BB:`,
   `A "…"`, `SIDE A`, `SIDE ONE`, `<WORD> SIDE:`, and a **fuzzy** `SIDE` so the measured misread
   `Gide One /` is still a side header. Two or more distinct sides, at least one carrying text,
   ⇒ the track count is the number of distinct sides.
8. **Otherwise geometry** — the largest surviving angle cluster, grouped into lines by projecting
   box centres onto the perpendicular of the cluster's mean baseline, split where the gap exceeds
   **0.5 × the median cap height**.
9. **Version qualifiers attach to the preceding line** (SEG-05) — `(VIP)`, `(Remix)`, `(Dub)`,
   `Mix`, `Version`, `Edit`, `Instrumental`, and any leading `(`/`[`.
10. **A lone short scrap is not a track listing** — if the entire trusted, non-noise text of a
    photograph is one observation under 8 alphanumerics, the result is **zero** tracks. This is a
    fitted heuristic and is marked as one: it exists because IMG_0507 reads only `cemenic`.
11. **Flip-side inference** (SEG-06) — `expectsFlipSide` is true when fewer than two distinct
    sides were found. One flat sleeve routinely reads both.

`0.5 × median cap height` is the **one** tuned constant. Sensitivity, measured over the recorded
corpus: `0.3 → 8`, `0.4 → 8`, `0.5 → 10`, `0.6 → 9`, `0.8 → 7`. It was tuned **on these twelve
fixtures**; there is no held-out set and the summary says so.

### V12's closure

`CaptureItem.displayLabel` currently takes the **first trusted observation in reading order**, and
IMG_0503's first trusted observation is `"Zzz."`. It will take the first trusted observation that
the SEG-03 noise filter keeps. `Zzz.` is three alphanumerics with a trebled character; it is
noise by two independent rules, and the next kept observation is `Cause 4 Concern-`.

## Tasks

### Task 1 — `ObservationGeometry` and `FuzzyMatch` (TDD) `type=auto tdd=true`

<behavior>
`ObservationGeometry.upright` sends orientation-6 raw `−90°` to `0°`, maps the box corner
correctly, swaps width and height, and is the identity for orientation 1. `capHeight` returns the
true cap height for rotated text and falls back to `min(w, h)` within 15° of the diagonal.
`FuzzyMatch.distance` is Levenshtein; `FuzzyMatch.isClose` allows one edit per four characters.
</behavior>
<implementation>
`Core/OCR/ObservationGeometry.swift`, `Core/OCR/FuzzyMatch.swift`. Pure. No banned token appears
in either file, including in the doc comments — the purity guard scans substrings.
</implementation>

### Task 2 — `TrackTextFilter`: noise, catalogue numbers, side markers, version qualifiers (TDD) `type=auto tdd=true`

<behavior>
Every price-sticker string the spike recorded is noise. `TYME 012`, `tech008`, `CSI 006`,
`EMF2029`, `0-44904` and `0-44845` are catalogue numbers; `JA22` is not. `A:`, `AA:`, `SIDE A`,
`Side One`, `COLD SIDE:`, `STEEL SIDE:` and the misread `Gide One /` are side markers; `ART` is
not. `Zzz.` is noise.
</behavior>
<implementation>
`Core/Segmentation/TrackTextFilter.swift`, driven from the twelve fixtures' real strings.
</implementation>

### Task 3 — `AngleClusterSegmenter` and `LabelSegmentation` (TDD) `type=auto tdd=true`

<behavior>
The segmenter reproduces the hand-scored track count on **at least 9 of the 12** fixtures, extracts
a catalogue number on at least 5 of the 6 fixtures that carry one, and reports `expectsFlipSide`
correctly. `LabelSegmenting.segment` now returns `LabelSegmentation`; `VinylEntry` carries the
catalogue number.
</behavior>
<implementation>
`Core/Segmentation/AngleClusterSegmenter.swift`, `Core/Segmentation/LabelSegmentation.swift`.
Update `LabelSegmenting`, `FixtureLineSegmenter`, `CaptureSession.vinylEntry`, `VinylEntry`, and
the affected tests. Commit the hand-scored expected counts as
`.planning/phases/06-ocr-segmentation/expected-scores.json`.
</implementation>

### Task 4 — the OCR seam and the real recogniser (OCR-01/02/03/05) `type=auto`

<behavior>
`TextRecognizing` is a Core protocol returning `[TextObservation]`. `SleeveTextRecognizer` in the
app target reads a file's EXIF orientation, passes it to the request handler, seeds the request
with the owner's recurring names, and runs off the main actor.
</behavior>
<implementation>
`Core/OCR/TextRecognizing.swift`, `Core/OCR/RecognitionVocabulary.swift`,
`App/OCR/SleeveTextRecognizer.swift`. The app file is the **only** place the framework is named.
</implementation>

### Task 5 — the measured acceptance gate `type=auto`

<behavior>
`./Scripts/ocr-score.sh` compiles the shipping recogniser and the shipping segmenter into one
macOS binary, runs **real** recognition over the twelve `.HEIC` files, scores both gates against
the committed ground truth, and exits non-zero below baseline. Run **twice** — both numbers are
headline.
</behavior>
<implementation>
`Tools/ocr-harness/main.swift`, `Scripts/ocr-score.sh`. Scoring: a needle is *found* when some
window of the normalised trusted text is within one edit per four characters of it — calibrated
in advance on the spike's own `WIDE OPBY` for `WIDE OPEN` (two edits in eight). **clean** = artist
found and every title found; **fail** = artist not found and no title found; **partial** = between.
A title the spike itself could not read is recorded as `null` and never counts as found.
Negative control (brand-new gate): junk text must score `fail`, and an absent needle must not match.
</implementation>

### Task 6 — V12, hygiene, and the phase record `type=auto`

<behavior>
`CaptureItem.displayLabel` skips noise; IMG_0503 no longer names itself `Zzz.`. The full battery
is green, screenshots regenerated once, and the ledger, requirements, roadmap and state updated.
</behavior>
<implementation>
`CaptureSession.swift`, `.planning/VISUAL-DEFECTS.md`, `.planning/REQUIREMENTS.md`,
`.planning/ROADMAP.md`, `.planning/STATE.md`, `06-SUMMARY.md`.
</implementation>

## Verification

| # | Gate | How |
|---|---|---|
| 1 | OCR ≥ 6 clean / 5 partial / 1 fail, real `Vision`, **measured twice** | `./Scripts/ocr-score.sh` |
| 2 | Segmentation ≥ 9 of 12 usable track counts, **measured twice** | `./Scripts/ocr-score.sh` |
| 3 | Catalogue number on ≥ 5 of the 6 fixtures that carry one | same run |
| 4 | V12 closed — `Zzz.` no longer titles IMG_0503 | unit test + the regenerated frames |
| 5 | `./Scripts/test.sh` green, count ≥ 200 | |
| 6 | `./Scripts/hygiene.sh` 9 pass 0 fail | |
| 7 | `./Scripts/build-app.sh` SUCCEEDED | |
| 8 | Any disagreement between the live run and `ocr2_out.json` reported, not smoothed | |

## Success criteria

1. Both headline numbers met, each measured twice, per-fixture scoring committed.
2. Catalogue numbers kept as a field on `VinylEntry`, not discarded.
3. V12 closed with evidence.
4. Nothing in the "does NOT build" table was built.
