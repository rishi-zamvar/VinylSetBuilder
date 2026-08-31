---
phase: 08
plan: 08
subsystem: wiring
tags: [camera, ocr, segmentation, resolution, bpm, sequencing]
requires: [05-sequencer, 06-ocr-segmentation, 07-resolution-bpm]
provides: [live-capture-pipeline, per-item-resolution-status]
affects: [App/Views/CaptureView.swift, App/Views/CrateDetailView.swift, VinylSetBuilderCore]
requirements: [CAP-01, RES-02]
partial-requirements: [CAP-04, BPM-07]
closes-defects: [V15, V16]
metrics:
  tests: 315
  hygiene: 9
  ui-tests: 7
  requirements: 55/67
completed: 2026-08-30
---

# Phase 8 Plan 08: Wiring & Camera Summary

**The app stopped being a shell.** All four stubs are out, `ui-test.sh` was green at
`totalTestCount=7` after each swap, and the app now photographs twelve real sleeves, reads them
with Vision, segments, resolves against MusicBrainz and Discogs, fetches tempo from SoundCloud
and its own vDSP analyser, and hands back a sequenced set — measured twice.

## The four swaps, with the UI count after each

| # | Swap | `totalTestCount` | passed | failed |
|---|---|---|---|---|
| 1 | `FixtureLineSegmenter` → `AngleClusterSegmenter` | **7** | 7 | 0 |
| 2 | `FixturePhotoSource` → `SleeveCamera` + live Vision | **7** | 7 | 0 |
| 3 | no resolver → `TrackResolver` + `BPMLadder` | **7** | 7 | 0 |
| 4 | the sequencer path (verification) | **7** | 7 | 0 |

Counts read from `build/ui.xcresult` via `xcresulttool`, committed at
`Artifacts/wiring/swap{1,2,3,4}-uitest-summary.json`. Every run also passed the zero-test guard.

**Swap 4 was a verification, not a substitution, and that is stated rather than dressed up.**
`AsyncSequencer` has been the app's only sequencing path since Phase 5 — `CrateDetailView.load()`
is the single call site and no synchronous `BeamSearchSequencer` reaches the app target. What was
genuinely missing was the *edge*: the crate derived its running order once, on appear, before
anything had a tempo. It now re-sequences as each record resolves. That landed with swap 3.

## The end-to-end run, on real photographs

`03-walk-07-done-sequenced.png`, taken in the simulator after the walk shot all twelve sleeves
and pressed Done. The crate screen then ran the live pipeline: OCR → segmentation → resolution
→ BPM → sequence.

**Two observations, agreeing:**

| Run | Sequenced | Not in the set | Total | Tempos |
|---|---|---|---|---|
| swap 3 | 3 | 9 | 12 | 172 / 174.8 / 175 |
| swap 4 | 3 | 9 | 12 | 172 / 174.8 / 175 |

```
1  G Squad — Monitor                                    172    1B
2  Drumsound & Simon 'Bassline' Smith — Dubtrack        174.8  —
3  Phunckateck's Juju — Invocación                      175    —
```

Adjacent gaps 2.8 and 0.2 BPM, both inside SEQ-03's 4.0 gate — asserted in the walk against
tempos that came off SoundCloud and through the vDSP analyser minutes earlier, not off a fixture.
Only the first row carries a key, which is exactly Phase 7's decision to degrade key to a
soft field below 0.8 confidence, showing up on screen for the first time.

**Nine records are not in the set, and the screen says why in the ladder's own words:**
`no SoundCloud upload matched` (×4 visible), `no identity to look a tempo up by` (×2 visible),
`No track within 4 BPM of the set`. That is BPM-07's screen half. Nine of twelve of this crate
are white labels and dubplates that are in no database — Phase 7 measured that already, and the
app now shows it honestly instead of failing silently.

**`sequenced + not-included == 12` is asserted** (RES-01: nothing silently dropped).

## CAP-01, measured

| What | Measurement |
|---|---|
| shutter → tile, 12 presses | 10, 11, 13, 14, 15, 14, 15, 16, 17, 18, 19, 26 ms |
| shutter → tile, 21 presses | 10 → 38 ms |
| tiles observed still `Reading` | **all 12 of 12** |
| tile → verdict (the Vision pass) | 843–1368 ms |

The shutter returns two orders of magnitude faster than the work it does not wait for, and the
intermediate state was directly observed on every single press. There is no spinner in the path.

**The first measurement of this was wrong and is recorded as wrong.** `waitForExistence` reported
1.4 s for all twelve presses — it polls once a second. A 20 ms poll on the identical code showed
10–26 ms. The harness was being measured, not the app.

## CAP-04: what the simulator can and cannot say

**Measured:** 21 consecutive captures, each a full HEIC decode plus a Vision pass. Recognition
latency **1165 ms → 962 ms** (first-five vs last-five mean) — no degradation, which is the
signature a leak or an unbounded queue would leave.

**Not measured, and not claimed:** memory and thermals. The simulator shares the Mac's envelope
and runs no camera pipeline, so a leak in `AVCapturePhotoOutput` or a hot ISP cannot appear.
Appended to `.planning/UAT-PENDING.md` as **U2c**, with the exact procedure.

**Also to UAT:** **U2b** — not one line of `SleeveCamera`'s capture-device path has ever
executed. `makeIfAvailable()` returns nil on every simulator. It compiles against the device SDK
and that is all that is proven. **U2d** — no `AVCaptureVideoPreviewLayer` was added, deliberately:
there is nothing to preview on a machine with no camera, and it would be unverifiable code drawn
on an empty buffer.

## Defects

**V15 CLOSED** — and the premise it was carried on was measured false on the way. The reason for
handing it to Phase 6 was that SEG-03's filter would shorten the long lines. The real segmenter
*joins* a cluster's readings into one line, so the longest draft line grew from 44 characters to
57. **The first fix failed and is recorded:** `axis: .vertical` with `.textFieldStyle(.roundedBorder)`
still capped growth at two lines — the 29-character control and the 57-character line both
rendered at exactly `44.00000000000003pt`. Dropping the rounded-border style and adding
`lineLimit(1...10)` is the fix. Measured live: a 12-character control at **22.0pt** against a
63-character line at **66.0pt**.

**V16 CLOSED** — no fixture drafts a duplicate line any more. IMG_0505 went from 11 lines
(carrying `SIMON BASSLINE SMITH` twice) to 2. Asserted in Core over all twelve and in the live walk.

**V6, V9, V10, V17 RE-CARRIED**, each with a written reason. V6 on its own stated condition: it
needed a ten-row sequence and the real run produces three, so it is still not assessable and a
ten-row fixture is not worth manufacturing. V10's premise is now half false — the camera exists,
the preview layer deliberately does not.

## Deviations from plan

### Auto-fixed issues

**1. [Rule 1 — Bug] The per-item status cleared before the re-sequence it belonged to**
- **Found during:** swap 4
- **Issue:** `resolvePending` removed a record from `AppModel.resolving` and *then* re-sequenced.
  "Nothing says Resolving" therefore meant "the network is quiet", not "the set on screen is the
  answer", and the crate briefly showed a running order it was about to replace. The walk caught
  it as a header saying two sequenced next to three drawn rows, one of them **36 BPM outside the
  gate** — a torn read across two renders.
- **Fix:** `await load()` first, clear the status after.
- **Commit:** `929ec1c`

**2. [Rule 2 — Missing critical functionality] Neither section header carried its count**
- **Found during:** swap 3
- **Issue:** a SwiftUI `List` only puts drawn rows in the accessibility tree, so the count of
  records in a crate was unreadable below the fold — by a test *or by a person scrolling*. The
  walk first reported "7 of 12 records were dropped" on a crate that had all twelve.
- **Fix:** `Running order (N)` and the bucket's existing `Not in the set (N)`.
- **Commit:** `4db589f`

**3. [Rule 3 — Blocking] `@Observable` could not expand `Set<UUID>`**
- `App/AppModel.swift` imported `Observation` but not `Foundation`. Commit `4db589f`.

### Deliberate deletions

`FixtureLineSegmenter`, `FixturePhotoSource` and the `PhotoCapturing` protocol were **deleted**,
not left beside their replacements. The protocol had one conformance in the app target and no
test double, which is the project's own stated bar for keeping a seam. Their Core tests were not
deleted with them — they were re-pointed at the shipping segmenter, so the flip set, the side
markers and the status tally are still asserted as **named sets**, now derived rather than
transcribed.

### Test expectations re-derived, with the old value recorded

Every UI expectation that encoded the *stub's* behaviour had to be re-measured. Old → new:

| Assertion | Stub | Real |
|---|---|---|
| IMG_0498 draft lines | 9 | 2 |
| IMG_0503 draft lines | 16 | 2 |
| IMG_0505 draft lines | 11 | 2 |
| IMG_0502 draft lines | 4 | 1 |
| strip status tally | 6 Read / 5 Partial / 1 Unread | 6 Read / **6 Partial** / 0 Unread |
| flip prompt fires on | 1,3,4,5,7,8,10,11,12 | **unchanged** |
| flip suppressed on | 2, 6, 9 | **unchanged** |

## Two things worth knowing that were not expected

**1. The derived read-status rule reproduces the owner's hand score exactly.** `SleeveStatus`
was written from the resolver's needs — a sleeve read well if it yielded lines *and* something to
resolve them with — with no sight of CONTEXT.md §3's tally. Run over the recorded observations it
returns 6 Read / 5 Partial / 1 Unread: the owner's own hand score, record for record. Asserted in
Core, and it is the reason to believe the rule is not arbitrary.

**2. Live Vision on iOS disagrees with the recorded macOS corpus, on one record and in one
direction.** Eleven of twelve verdicts are identical. IMG_0507 — the dubplate the macOS spike got
nothing usable off — reads well enough on iOS to keep a line, so it scores Partial rather than
Unread. Also: IMG_0505 returns **13** observations live against 12 recorded; the 106-character
read comes back at confidence **0.50** against 0.30; IMG_0502 reads `JA22 IX ROFD` (12 chars)
against `JA22 •MAIATCIN DAVE ANCEL MIX` (29). Character counts and row indices were therefore
turned into *recorded* values and the assertions rewritten onto what the requirement actually
says — "an untrusted reading is on screen" rather than "row 4 says 0.30".

## What FAILED

- **A stale test bundle produced a confidently wrong result, twice.** `rm -rf build` is **not**
  enough: `ui-test.sh` ran, exited non-zero, wrote a fresh `.xcresult`, and reported a failure
  against source that no longer existed on disk. `ui-test.sh`'s zero-test guard does not catch
  this, because the count is 7. Every run after that discovery cleared
  `~/Library/Developer/Xcode/DerivedData/*` as well. **This is the phase's most dangerous
  finding** — the result bundle looked authoritative and was not.
- **The V15 fix did not work the first time.** Recorded above; the failure was measured before
  the second attempt rather than assumed away.
- **A `* 1.5` threshold failed on a floating-point ulp** — `66.00000000000003` against
  `66.00000000000004` — while measuring exactly the right thing. Replaced with a whole-line margin.
- **The first end-to-end assertion was wrong about the app.** It reported five records dropped;
  they were below the fold. The app was correct and the test was not.

## Disk

| Point | Free |
|---|---|
| before the phase | 7.2 GB |
| lowest observed | 5.5 GB |
| after the phase | 5.6 GB |

Never below the 3 GB floor. `build/` and DerivedData cleared between every heavy run, and no two
`xcodebuild` invocations ever ran concurrently.

## Final state

`./Scripts/test.sh` **315 green** · `./Scripts/hygiene.sh` **9 pass 0 fail** ·
`./Scripts/ui-test.sh` **7/7 from totalTestCount** · `./Scripts/build-app.sh` **BUILD SUCCEEDED**
· `generate-secrets.sh --check` leak check passed · **55/67 requirements**

## Self-Check: PASSED

Every file this summary names exists on disk; every commit hash it cites is in `git log`; all
three deleted stubs are gone from `VinylSetBuilderCore/Sources`. Verified by command, not by
reading.
