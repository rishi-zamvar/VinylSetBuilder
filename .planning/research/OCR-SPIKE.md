# OCR Spike — SEG-01, answered ahead of Phase 2

**Date:** 2026-08-29
**Fixtures:** 12 real records from the owner's crate (`~/Desktop/test/*.HEIC`)
**Method:** Apple Vision `VNRecognizeTextRequest`, `.accurate`, `usesLanguageCorrection = false`,
run natively on macOS 26.3.1 / Swift 6.2. 101 → 104 text observations total.

This is the go/no-go gate the research flagged as the project's #1 risk. **It passes**, but
almost every assumption in spec §4 turned out to be wrong about *why*.

---

## Finding 1 — These are SLEEVES, not labels ⚠️ SPEC-BREAKING

The spec is built around photographing a circular record label with concentric text, and
proposes radial-distance clustering from the label centre on that basis.

The owner's actual photographs are **whole 12" sleeves lying on a countertop**, shot from
above. The record label, when visible at all, is a small circle glimpsed through a die-cut
hole and occupies well under 10% of the frame.

Consequences:
- The best text in every photo is **large horizontal sleeve typography**, not label text.
- One photo routinely captures **both sides** (`A:` and `AA:`) — the spec's per-side capture
  loop and flip-side prompt are largely unnecessary for this collection.
- Concentric/curved text — the thing feared most — **barely appears**. The curved-baseline
  limitation of Vision is close to a non-issue here.
- Radial clustering from a label centre would be clustering around the wrong object.

## Finding 2 — Baseline ANGLE is the segmentation signal, not radial distance ✅ BETTER ALGORITHM

Observation baseline angles form **distinct clusters per physical surface**, because the
record inside the sleeve sits rotated relative to the sleeve itself:

| Fixture | Sleeve cluster | Label cluster | What separated |
|---------|---------------|---------------|----------------|
| IMG_0498 | −90° | **+13°** | sleeve art vs. the black label |
| IMG_0503 | −90° | **+150°** | stickers/sleeve vs. Timeless label |
| IMG_0505 | −92° | **−66°** | sleeve vs. label through die-cut |
| IMG_0500 | +180° | **−130°** | sticker vs. label |

Full angle histogram across all 12 (15° bins): `−90°: 35, −60°: 16, −135°: 8, +150°: 7,
−30°: 6, −165°: 5, +15°: 5, +30°: 4, +180°: 4 …`

**Recommendation: cluster observations by baseline angle first, then group within each
cluster.** This separates label from sleeve with no label-centre detection, no circle
finding, and no polar unwrapping. It is simpler than the spec's approach *and* more robust.

## Finding 3 — EXIF orientation must be passed explicitly 🐛 REAL BUG

`VNImageRequestHandler(cgImage:options:)` **ignores EXIF orientation.** All 12 fixtures carry
`orientation = 6`. Passing it via `VNImageRequestHandler(cgImage:orientation:options:)`
measurably improved recognition:

| Before | After |
|--------|-------|
| `ENICATTONAPE` | `EDUCATION` |
| `Roland =` | `Roland` |
| `Remis` | (merged correctly) |
| — | `SIDE A` *(newly detected)* |
| `AA "Elementz"` partial | `A: High Down` + `AA: Strange Nature` |

**Also note:** Vision returns coordinates in the **original, unrotated** buffer space even
when given an orientation. Angles therefore still read ≈−90°. Any geometric clustering must
apply the orientation transform to coordinates itself, or cluster in raw space consistently.
Getting this half-right is how segmentation breaks silently.

## Finding 4 — Confidence is effectively binary, not continuous

Observed confidences were almost exclusively **1.00, 0.50 or 0.30**. Nothing in between.
The spec's "filter below ~0.3" threshold is nearly a no-op. **Use `conf >= 1.0` as the
trusted tier**, treat 0.5/0.3 as junk. Of 104 observations, 88 were 1.00.

## Finding 5 — Side markers vary far more than `A1`/`B2`

Real markers found: `A:`, `AA:`, `SIDE A`, `COLD SIDE:`, `STEEL SIDE:`, `Side One`.
Jungle/DnB 12"s use **A/AA**, not A/B, and white labels invent their own (`COLD`/`STEEL`).
The regex must cover `A|AA|B|BB|SIDE ONE|SIDE A|<word> SIDE:` — not just `A1`/`B2`.

## Finding 6 — Price stickers are the dominant noise

Consistent junk across fixtures: `$10.00`, `6.00€`, `$9.73 [Import]`, `·009`, `#00°L`,
`8.00%`, `15.6-`. Every record has a shop price sticker. A currency/decimal regex filter
removes most non-track noise for near-zero effort. Also seen: `MADE IN ENGLAND`,
`PUBLISHED BY SERIES 3 MUSIC`, `WWW.TECHNIQUERECORDINGS.CO.UK`, email addresses.

## Finding 7 — Performance is a non-issue

~130 ms per image after a 455 ms first-call warm-up, on full-resolution HEIC. Twenty
records is under 3 seconds of OCR. No thermal or memory concern at this scale — the
`CAP-04` risk is much smaller than assumed.

---

## Scored results

| Fixture | Artist | Title(s) | Verdict |
|---------|--------|----------|---------|
| IMG_0499 | The Accidental Heroes | A "Dragstar" / AA "Elementz" | ✅ perfect, both sides + cat# |
| IMG_0503 | Cause 4 Concern | A: High Down / AA: Strange Nature | ✅ perfect, + `TYME 012`, Timeless Recordings |
| IMG_0505 | Drumsound & Simon 'Bassline' Smith | Dubtrack / Supersonic | ✅ perfect, + `tech008` |
| IMG_0504 | fellowship | xtasia / 'sweetness' (drum n bass dub version) | ✅ good |
| IMG_0506 | G Squad | Cold Side: Wide Open / Steel Side: Monk… | ✅ good, + `CSI 006` |
| IMG_0498 | Abstract | The Message / Fuck Willie Brown (Dom & Roland Remix) | ✅ good |
| IMG_0501 | Distorted Minds ft. MC Skibadee | Stay Focused ✓ / "Give It To Me" → `LINU ME` ✗ | ⚠️ 1 of 2 |
| IMG_0500 | garbled | Invocación / Original Version / Remix | ⚠️ title only |
| IMG_0502 | DJ Krust | `JA22` (Jazz?), Dave Angel Mix | ⚠️ partial |
| IMG_0508 | — | Da Lick (×4 reads) | ⚠️ title only |
| IMG_0509 | DJ Kane (`Di RANE`) | Sonic Art / "…Mind" | ⚠️ partial |
| IMG_0507 | — | `DrumBass`, `cemenic` | ❌ fail |

**6 clean / 5 partial / 1 fail.**

Against the spec's Phase 2 criterion ("correct track count on 8/10"), a usable track count is
obtainable on roughly **9 of 12**. Several "partial" rows are still resolvable downstream —
`Da Lick` + `MADE IN ENGLAND`, or `Cause 4 Concern` + `TYME 012`, are perfectly good Discogs
queries. Catalogue numbers (`TYME 012`, `tech008`, `CSI 006`, `EMF2029`, `0-44904`, `0-44845`)
were read cleanly in 6 of 12 fixtures and are a **stronger Discogs key than artist+title**
— the spec discards them as noise, which is backwards.

---

## Actions for the roadmap

1. **Reframe capture**: the unit is a *sleeve*, photographed whole, often yielding both sides.
   Revisit the per-side capture loop and the flip-side prompt (`CAP-05`, `SEG-06`).
2. **Replace radial clustering with angle clustering** (`SEG-02`). Simpler and better.
3. **Pass EXIF orientation**, and fix the coordinate-space transform exactly once (`OCR-02`).
4. **Use catalogue number as a primary resolution key**, not discarded noise (`SEG-03`, `RES-03`).
5. **Broaden the side-marker regex** well beyond `A1`/`B2` (`SEG-04`).
6. **Filter price stickers** with a currency regex (`SEG-03`).
7. **Downgrade the `CAP-04` performance risk** — measured at ~130 ms/image.
8. Curved/concentric text handling is **not needed for this collection** — do not build
   polar unwrapping (`SEG2-01` stays deferred, probably forever).
