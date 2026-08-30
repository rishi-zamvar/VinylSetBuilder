---
phase: 03-capture-correction-screens
plan: 05
subsystem: capture-correction-screens
tags: [xcuitest, ship-criterion, visual-audit, screenshots, negative-controls, act-i]
requires:
  - CaptureView, CaptureThumbnailStrip, FlipSidePromptView (03-03)
  - InspectCorrectSheet, RawObservationListView (03-04)
  - FixturePhotoSource, FixtureObservations, CaptureSession (03-01)
  - SegmentationDraft, RawObservationRows (03-02)
  - UITests/ScreenshotRecorder.swift, Scripts/collect-screenshots.sh (02-02/02-04)
provides:
  - Phase 3's ship criterion as an executable test that can fail
  - the nine photographed 03-walk states, and the audit of all 33 Act I frames
  - V13 closed with numbers; V3 carried with a second sighting; V14/V15/V16 filed
  - REQUIREMENTS/ROADMAP/STATE/UAT-PENDING/deferred-items brought true at Phase 3 close
affects:
  - .planning/VISUAL-DEFECTS.md
  - .planning/UAT-PENDING.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
tech-stack:
  added: []
  patterns:
    - "reachability is a geometry question before it is a hittability question — isHittable RAISES on an off-screen element"
    - "scroll-to-element is a bounded, held, BIDIRECTIONAL drag; a one-directional swipe loop runs away"
    - "a layout claim is measured as a layout claim (tile width), never as a count"
key-files:
  created:
    - UITests/CaptureWalkUITests.swift
    - Artifacts/screenshots/03-walk-01-capture-guide.png … 03-walk-09-strip-scrolled-to-end.png
  modified:
    - .planning/VISUAL-DEFECTS.md
    - .planning/UAT-PENDING.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/phases/03-capture-correction-screens/deferred-items.md
    - all 24 previously committed 02-walk / 03-03 / 03-04 / 02-smoke screenshots (re-captured)
decisions:
  - "the two sheet frames are taken on fixtures 5 and 8, not one fixture — the only two carrying the corpus's longest trusted read (44 chars) and its longest read overall (106 chars)"
  - "03-walk-07 photographs the not-included bucket EXPANDED, which is what obtains V3's second sighting; nothing asserts the Vinyl N labels, so Phase 4's fix need not edit a test"
  - "CAP-03's 20-item claim is measured by tile width at 1 vs 21, because mutation J proves a count cannot see it"
metrics:
  duration: ~95 min
  tasks: 2
  files: 40
  completed: 2026-08-30
---

# Phase 3 Plan 05: The Ship Criterion, Executable — and the Act I Phase 3 Audit Summary

Turned the roadmap's Phase 3 sentence into `CaptureWalkUITests` — two tests that assert the named
flip set, the 6/5/1 tally and CAP-03's layout claim in ways a count cannot fake — ran it, looked at
all thirty-three Act I frames, closed V13 with numbers, obtained V3's second sighting without
fixing it, and brought the whole record true.

---

## The claims, and how many times each was measured

Nothing below rests on one observation unless the row says "once".

| # | Claim | Measurement | Times measured |
|---|---|---|---|
| 1 | All 12 fixture photographs load through the capture screen in one session | `capture-thumb-12` exists, `capture-thumb-13` does not, tally sums to 12, `capture-session-count` reads `12 records` | **3** full-suite runs (A, B, C), plus 3 more isolated runs of the walk during development |
| 2 | The flip prompt fires on exactly `[1, 3, 4, 5, 7, 8, 10, 11, 12]` | XCUITest records the index of every real prompt in a real session and asserts the array | **3** runs here, plus 03-01's independent Core unit test over `FixturePhotoSource` — **two independent observation methods**, as CONTEXT.md §8 named in advance |
| 3 | …and is suppressed on exactly `[2, 6, 9]` | asserted **separately**, so an empty `fired` array cannot pass vacuously | **3** runs here + 03-01's Core test |
| 4 | The status tally is exactly `6 Read / 5 Partial / 1 Unread` | one dictionary read off `capture-thumb-status-{n}`, asserted whole so a blank status is a missing key | **3** runs here + 03-01's Core `statusTally` test |
| 5 | The strip scrolls past 20 items without the tiles compressing | `capture-thumb-1`'s frame width at 1 item and at 21: **104.0 pt → 104.0 pt** | **3** runs, identical each time |
| 6 | Tile 21 is *reachable*, not merely present | 13 bounded drag steps take it from `x = 2296` to `x = 282`, then `isHittable` | **3** runs; 13 steps each time |
| 7 | No tile is named `Vinyl N` (D-03-6 / V3 containment) | regex assertion on all 12 tile labels every run, **and** `grep -rn "VinylEntry.label" App/` → rc=1 | **3** runs + 1 grep |
| 8 | The V2 pallor signature is absent from every Act I frame | Pillow probe: `min ≤ 110`, `max ≥ 200`, `min ≠ max` | **3** independently captured runs, 33 frames each. `SUSPECT: none` all three times |
| 9 | Per-frame mean drift between runs | 0.022 (A↔B), 0.024 (A↔C), 0.029 (B↔C) against Phase 2's ±0.06 bar | **3** pairwise comparisons |
| 10 | The correction `TextField` truncates a 44-character line | field value read back at 44 chars in a 237.33 pt field; picture shows `EXCLUSIVE NEW MIXES FR…` | **3** runs, identical |
| 11 | The raw list **wraps** the 106-character read rather than cutting it | row height 70.75 pt against a one-line control of 19.33 pt = four rendered lines | **3** runs, identical to 4 decimal places |
| 12 | The draft carries exact duplicate lines | `SIMON BASSLINE SMITH` twice in IMG_0505's eleven lines | **3** runs |
| 13 | V3's second sighting: the bucket names twelve freshly captured records `Vinyl 1…8` | printed label list, byte-identical on all three runs; photographed on each | **3** runs |
| 14 | V9's rule: the large title survives only until a `.sheet` is presented | 33 frames per run split cleanly by route, no exception | **3** runs |
| 15 | V14: walk states 8 and 10 are the same picture | byte-identical on run B; differ by 1 px / a 41×92 px toolbar patch on A and C | **3** runs |
| 16 | The suite is green | log says `** TEST SUCCEEDED **`, `Executed 6 tests, with 0 failures`; `build/ui.xcresult` independently says `passed=6 failed=0` | **3** runs, **two independent sources each** |
| 17 | The three headline assertions can fail | mutations I, J, K, each reddening at a named line, each confirmed from log **and** xcresult | **once each** — three separate mutation runs |
| 18 | `app.otherElements["capture-flip-prompt"].label` is empty | printed on every firing fixture | 9 fixtures × 3 runs = **27** |

---

## The ship-criterion audit, verbatim

Every command the plan named, its output, its exit code. Nothing filtered.

```
$ ./Scripts/test.sh
✔ Test run with 168 tests in 0 suites passed after 0.031 seconds.
rc=0                                        # baseline was 113; Phase 3 took it to 168
```

```
$ ./Scripts/build-app.sh
** BUILD SUCCEEDED **
rc=0                                        # device SDK, CODE_SIGNING_ALLOWED=NO. U7 did not recur
```

```
$ ./Scripts/ui-test.sh
Executed 6 tests, with 0 failures (0 unexpected) in 432.867 (432.895) seconds
** TEST SUCCEEDED **
rc=0

$ xcrun xcresulttool get test-results summary --path build/ui.xcresult
xcresult result=Passed passed=6 failed=0 total=6      # the SECOND, independent source
```

```
$ ls Artifacts/screenshots/03-walk-*.png | wc -l
9
$ ls Artifacts/screenshots/02-walk-*.png | wc -l
15
```

```
$ grep -rn "TODO\|FIXME" App/ VinylSetBuilderCore/Sources/ UITests/ Scripts/
rc=1                                        # no output. The Phase 4 criterion is already met
```

```
$ ./Scripts/test.sh --filter CorePurity
✔ Test "SETUP-02: Core links no camera and no network framework" passed after 0.018 seconds.
✔ Test run with 1 test in 0 suites passed after 0.018 seconds.
rc=0

$ grep -c 'TextObservation(text:' VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureObservations.swift
104                                         # all 104 real OCR strings live in Core and none trips the purity scan
```

```
$ grep -rn "CapturePlaceholderView\|capture-add-fixture-button" App/ UITests/
rc=1                                        # the Phase 2 placeholder is gone from source AND tests

$ grep -rn "VinylEntry.label" App/
rc=1                                        # D-03-6 holds: V3's naming rule is not called from any screen

$ grep -rn "MusicUnderstanding" App/ VinylSetBuilderCore/ UITests/
rc=1                                        # the iOS 27 framework is still nowhere in the tree

$ grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/
rc=1                                        # re-confirming the Phase 9 gap, not a Phase 3 one
```

```
$ grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md
23
$ grep -c "^- \[ \] \*\*" .planning/REQUIREMENTS.md
44                                          # 23 + 44 = 67, recounted, not incremented
```

**Every gate exited clean.** Nothing was narrowed, filtered or re-thresholded to make it do so.

---

## The requirement mapping — which frame each of the six is visible in

| Requirement | Visible in | What the frame shows |
|---|---|---|
| **CAP-02** — sleeve framing guide, not a label close-up | `03-walk-01-capture-guide.png` | the stroked square at `290.67 × 291 pt` (square to half a point, measured off the live accessibility frame), covering 0.88 of the preview's shorter edge, captioned *"Fill the square with the whole sleeve — not just the label."* |
| **CAP-03** — thumbnail strip with per-item status, scrolling past 20 | `03-walk-04-strip-twelve.png` (12 tiles, `12 records`, Read/Read/Partial/Partial visible), `03-walk-08-strip-twentyone.png` (`21 records`, tiles still 104 pt), `03-walk-09-strip-scrolled-to-end.png` (the end of the strip reached, last tile fully visible) |
| **CAP-05** — inline flip prompt, suppressed when both sides were read | `03-walk-02-flip-prompt-fires.png` (fixture 1, *Only one side read / HIGHER*, Skip + Scan, shutter still live behind it) **against** `03-walk-03-flip-suppressed.png` (fixture 2, same run, no prompt) — the pair is the claim, not either frame alone |
| **CAP-06** — Done leaves the loop and lands on the crate | `03-walk-07-done-sequenced.png` | the crate detail, `Nothing sequenced yet`, `Not in the set (12)` expanded |
| **OCR-04** — raw recognised text inspectable | `03-walk-06-inspect-raw-text.png` | 11 draft lines above, 12 raw rows below including the 0.30 read the segmenter dropped, confidence as white-on-solid capsules |
| **SEG-07** — split / merge / hand-type a track line | `03-walk-05-inspect-sheet.png` | four lines, scissors and merge-up on every row, merge-up correctly dimmed on row 1, *Add a line*, *Apply* |

---

## Per-frame table — all thirty-three, from the one run that produced the committed set

| Frame | Dimensions | Mean | Min | Max | Bytes | md5 (first 8) |
|---|---|---|---|---|---|---|
| `03-walk-01-capture-guide.png` | 1206x2622 | 157.02 | 0 | 255 | 92,136 | `639762e7` |
| `03-walk-02-flip-prompt-fires.png` | 1206x2622 | 173.03 | 0 | 255 | 122,416 | `1ada7164` |
| `03-walk-03-flip-suppressed.png` | 1206x2622 | 153.93 | 0 | 255 | 110,410 | `b4ec2738` |
| `03-walk-04-strip-twelve.png` | 1206x2622 | 152.03 | 0 | 255 | 118,810 | `ec9e50fb` |
| `03-walk-05-inspect-sheet.png` | 1206x2622 | 242.16 | 0 | 255 | 151,324 | `23199e8b` |
| `03-walk-06-inspect-raw-text.png` | 1206x2622 | 235.78 | 0 | 255 | 285,414 | `89ff44d7` |
| `03-walk-07-done-sequenced.png` | 1206x2622 | 245.89 | 0 | 255 | 392,023 | `95fff482` |
| `03-walk-08-strip-twentyone.png` | 1206x2622 | 151.14 | 0 | 255 | 128,307 | `4c232fe0` |
| `03-walk-09-strip-scrolled-to-end.png` | 1206x2622 | 151.09 | 0 | 255 | 121,673 | `f372fef4` |
| `03-03-capture-empty.png` | 1206x2622 | 156.13 | 0 | 255 | 100,627 | `0f3a3eeb` |
| `03-03-capture-flip-prompt.png` | 1206x2622 | 172.15 | 0 | 255 | 129,720 | `4b121c2a` |
| `03-03-capture-flip-suppressed.png` | 1206x2622 | 153.04 | 0 | 255 | 120,015 | `40cfb7e4` |
| `03-03-capture-one-item.png` | 1206x2622 | 154.69 | 0 | 255 | 108,035 | `e26610ce` |
| `03-04-sheet-after-merge.png` | 1206x2622 | 237.53 | 0 | 255 | 290,726 | `7d63d4d6` |
| `03-04-sheet-after-split.png` | 1206x2622 | 237.68 | 0 | 255 | 289,148 | `b3cd4555` |
| `03-04-sheet-hand-typed.png` | 1206x2622 | 237.83 | 0 | 255 | 274,202 | `c28ec922` |
| `03-04-sheet-lines.png` | 1206x2622 | 237.68 | 0 | 255 | 287,589 | `3cf3a2f0` |
| `03-04-sheet-raw-text.png` | 1206x2622 | 237.79 | 0 | 255 | 248,491 | `9d281c9b` |
| `02-walk-01-crate-list.png` | 1206x2622 | 242.37 | 0 | 255 | 104,987 | `61190fb5` |
| `02-walk-02-new-crate-sheet.png` | 1206x2622 | 233.69 | 0 | 255 | 169,553 | `fdf1ebc9` |
| `02-walk-03-capture-empty.png` | 1206x2622 | 157.26 | 0 | 255 | 90,868 | `89505705` |
| `02-walk-04-capture-with-vinyl.png` | 1206x2622 | 173.28 | 0 | 255 | 121,100 | `9e252681` |
| `02-walk-05-new-crate-detail.png` | 1206x2622 | 242.80 | 0 | 255 | 136,422 | `8f5da327` |
| `02-walk-06-crate-detail-sequenced.png` | 1206x2622 | 242.52 | 0 | 255 | 172,648 | `bcb9334c` |
| `02-walk-07-not-included-expanded.png` | 1206x2622 | 243.46 | 0 | 255 | 221,190 | `bdc4a19b` |
| `02-walk-08-detail-edit-mode.png` | 1206x2622 | 243.65 | 0 | 255 | 229,338 | `916c391a` |
| `02-walk-09-detail-manual-order.png` | 1206x2622 | 243.58 | 0 | 255 | 234,209 | `45b9e70a` |
| `02-walk-10-detail-restored.png` | 1206x2622 | 243.65 | 0 | 255 | 229,333 | `2581dbaa` |
| `02-walk-11-add-more-capture.png` | 1206x2622 | 156.85 | 0 | 255 | 94,786 | `23a9a1d8` |
| `02-walk-12-detail-after-remove-vinyl.png` | 1206x2622 | 242.49 | 0 | 255 | 150,991 | `b13b58dd` |
| `02-walk-13-second-crate-different-selection.png` | 1206x2622 | 242.35 | 0 | 255 | 143,555 | `86d3e34b` |
| `02-walk-14-crate-list-after-delete.png` | 1206x2622 | 243.13 | 0 | 255 | 94,938 | `db164206` |
| `02-walk-15-crate-list-empty.png` | 1206x2622 | 253.53 | 0 | 255 | 84,919 | `a91a52f8` |

Every frame: `min = 0`, `max = 255`, `min ≠ max`. No V2 signature anywhere, three runs running.
All thirty-three come from **one** `xcodebuild test` run into **one** simulator container, after
the whole `03-walk-*`, `02-walk-*`, `03-03-*`, `03-04-*`, `02-smoke-*` glob was deleted from the
host. Not one is a leftover.

---

## Defects: closed with evidence, versus carried with reasons

### Closed

**V13 — a long line's behaviour in the correction field.** Closed, both halves, with numbers
rather than an impression:

- The **`TextField` truncates**. IMG_0502's 44-character `EXCLUSIVE NEW MIXES FROM V CLASSIC THE
  ALBUM` — the corpus's longest *trusted* read — renders as `EXCLUSIVE NEW MIXES FR…` in a
  237.33 pt field. The value survives intact (XCUITest reads all 44 characters back), so nothing
  is lost; about half is invisible at rest. Carried on as **V15**.
  Evidence: `03-walk-05-inspect-sheet.png`, line 4.
- The **raw list wraps and loses nothing**. The corpus's longest read overall is 106 characters at
  confidence 0.30, so it never becomes a draft line at all — it exists only in the raw list, which
  is precisely OCR-04's point. It sits at the bottom edge of the frame, so the photograph cannot
  answer the question; **height did**: 70.75 pt against a one-line control of 19.33 pt, four
  rendered lines. The walk now asserts `height > 1.5 × one-line`, so a future `lineLimit(1)`
  reddens it. Evidence: `03-walk-06-inspect-raw-text.png` plus the measurement.
- The question underneath it — *do two lines end up reading identically?* — is **yes**, and
  truncation is not why. Carried on as **V16**.

**V7 — the empty running order.** Stays closed and is now shown a third way: `03-walk-07` is the
same empty-order branch at twelve records rather than one.

**V2 — the pallor.** Closure re-confirmed on a third and fourth screen family (the twelve-tile
strip, the twenty-one-tile strip) across three independently captured runs. `SUSPECT: none`, probe
exit 0, every time. No threshold touched.

### Carried, each with its reason

| Defect | Why it is carried and not closed | Owner |
|---|---|---|
| **V3** (Medium) — the bucket names records `Vinyl N` | **The second sighting CONTEXT.md §6 predicted was obtained** — `03-walk-07-done-sequenced.png` shows twelve records the app named `HIGHER`, `Emotif/Xstatic EMF2029`, `inckatecks*`, `Zzz.` in its own strip four frames earlier, sitting in the bucket as `Vinyl 1 … Vinyl 8`. One record, two names, two screens, one session. **Not fixed on purpose**: both defensible fixes are product calls, U8 asks the owner which, and preempting the answer wastes the question | Phase 4 / U8 |
| **V4** (Low) — placeholder badges `.secondary` on `.thinMaterial` | Not repeated on any new screen (the strip's status pill and the raw list's confidence capsule are white on solid saturated grounds), but not fixed either — it is Phase 4's, and `03-walk-07` now shows twelve of them at once | Phase 4 |
| **V5** (Low) — two fixtures share `position: 2` | Latent, still not visible in any photograph. V3's fix touches the same line | Phase 4 |
| **V6** (Low) — double-digit running-order alignment | **Still not assessable.** `03-walk-07` reaches twelve records but they are all *excluded*, so the running order is empty and no index ≥ 10 was rendered anywhere in 33 frames. Honest "not assessable", again | Phase 4 |
| **V9** (Low) — no large navigation title | Not fixed, per the rule V2 left behind, but **narrowed to a one-line repro**: every frame with a title was taken before any `.sheet` was presented, every frame without one after; 33 of 33 frames obey it, and `03-walk-08`/`03-walk-09` are the same `CaptureView` as `03-walk-01`–`04` in the same run, with titles, because that test opens no sheet | Phase 4 |
| **V10** (Low) — the guide resizes when the prompt appears | Confirmed again (`290.67 pt` with no prompt, visibly smaller with one, same test). Needs a fixed-aspect camera layer, which is Phase 10's | Phase 10 |
| **V11** (Informational) — Add More says `0 records` | Confirmed again on `02-walk-11`. Behaving as designed (D-03-3); it is the owner's call whether the session count or the crate total is the right number | Phase 4 |
| **V12** (Medium) — a record titled `Zzz.` | Confirmed on a third screen — the strip labelled fixture 6 `Zzz.` on all three runs. **The OCR spike already specified the fix** (a currency/decimal filter for price stickers, SEG-03) and real segmentation is what gives a title rule something better to choose from. Not fixable in Act I without inventing the segmenter Phase 6 owns | Phase 6 |
| **V14** (Informational, new) — walk states 8 and 10 are one picture | Recorded rather than fixed: Restore's job *is* to return to state 8, so the identity is semantically correct. It matters only because Phase 4's criterion is "screenshot count equals screen count", and the honest count is **14 distinct states, not 15** | Phase 4 |
| **V15** (Low, new) — the correction field truncates at ~22 characters | The fix (wrap, or a two-line field, or a detail row) is a layout decision on a sheet whose ergonomics are U9's open question. Fixing it before the owner rules on U9 would be guessing | Phase 4 |
| **V16** (Low, new) — the draft carries exact duplicate lines | This is D-03-4 working as designed: Act I emits one line per trusted observation and does not de-duplicate, because de-duplication is SEG-03's filtering. Fixing it here means writing the segmenter Phase 6 owns and Phase 11 would delete | Phase 6 |

**Zero Medium-or-above defects were introduced by this plan.** V3 and V12 are both Medium and both
pre-existing; V14/V15/V16 are Low or Informational.

---

## Negative controls — the walk's own assertions are provably able to fail

Three mutations, each applied to a **committed** tree (mutation H's lesson, one plan ago), each run,
each confirmed from the log **and** `build/ui.xcresult`'s `failedTests`, each reverted.

| # | Mutation | Reddened | Confirmed |
|---|---|---|---|
| I | `FixturePhotoSource.table` scores `IMG_0500` `.read` instead of `.partial` | `CaptureWalkUITests.swift:153` — *"the strip's status tally is ["Read": 7, "Partial": 4, "Unread": 1], not 6 Read / 5 Partial / 1 Unread"* | log: 1 test 1 failure. xcresult: `passed 0 / failed 1` |
| J | `CaptureThumbnailStrip`'s tile width shrinks with the item count | `CaptureWalkUITests.swift:228` — *"the tiles compressed from 101.0pt to 41.0pt — the strip is shrinking, not scrolling"* | log: 1 test 1 failure. xcresult: `passed 0 / failed 1` |
| K | `CaptureSession.append` sets `pendingFlipPrompt = item.id` unconditionally | `CaptureWalkUITests.swift:142` — *"the flip prompt fired on [1 … 12], not on [1, 3, 4, 5, 7, 8, 10, 11, 12]"* | log: 1 test 1 failure. xcresult: `passed 0 / failed 1` |

**J is the one that justifies the whole design of test 2.** Under it `capture-thumb-21` still
existed, `capture-thumb-22` still did not, `21 records` still rendered, and tile 21 was still
reachable — **every count and existence assertion in the test passed.** Only the width comparison
saw it. A count cannot detect an `HStack` that shrinks instead of a `ScrollView` that scrolls.

None crashed the runner. After all three reverts: `git diff HEAD` empty, 168 Core tests green,
both walk tests green, `xcresult passed=2 failed=0`.

---

## Deviations from plan

### 1. [Rule 1 — Bug] `isHittable` raises rather than returning false, and the first scroll loop ran away

**Found during:** Task 1, the first two full runs.

**Issue, in two parts.** The plan's step *"swipe the strip left until `capture-thumb-21` is
`isHittable`, with a bounded number of swipes"* does not work as written, twice over:

- `XCUIElement.isHittable`, asked of an element scrolled off the right-hand edge, **raises**
  *"Failed to determine hittability of "capture-thumb-5" Button: Activation point invalid and no
  suggested hit points based on element frame"* and fails the test outright. It does not return
  `false`, so it cannot be a loop condition.
- Even with that fixed, a one-directional `swipeLeft(velocity: .slow)` loop carries momentum past a
  tile in the *middle* of a twelve-item strip and can never come back: fifteen consecutive swipes
  drove `capture-thumb-5` from off the right edge to **`x = -516`**, off the left one.

**Fix.** Reachability is asked of the geometry first — a tap lands on the element's centre, so a
tile whose centre is inside the window has a valid activation point by definition — and
`isHittable` is only asserted afterwards, which test 2 still does. The scroll is a **bounded,
momentum-free, bidirectional drag**: `press(forDuration:thenDragTo:withVelocity:.slow,
thenHoldForDuration: 0.3)`, capped at ±170 pt per step, direction chosen from where the tile
actually is on each pass. It converges instead of running away, and it works for a tile in the
middle as well as the last one.

**Files modified:** `UITests/CaptureWalkUITests.swift`. **Commit:** `b4dfabe`.

### 2. [Rule 2 — Missing critical measurement] The two sheet frames are taken on two different fixtures

**Found during:** Task 1, while choosing which thumbnail to open.

**Issue.** The plan's table implies both sheet frames come from one sheet (*"the sheet opened from
a thumbnail"*, *"**its** raw-text disclosure expanded"*). Taking both on one fixture would have
left defect V13 exactly where 03-04 left it, because **no single fixture carries both** of the
lines V13 is about: the corpus's longest *trusted* read (44 characters, IMG_0502 = fixture 5,
which becomes a draft line) and its longest read *overall* (106 characters, IMG_0505 = fixture 8,
which is confidence 0.30 and appears only in the raw list).

**Fix.** `03-walk-05` is fixture 5's sheet and `03-walk-06` is fixture 8's raw text. Nine frames
still, both captions still true of what they show, and V13 is answerable. This is the same
reasoning 03-04 used when it took its raw-text frame on fixture 1 rather than fixture 6.

**Files modified:** `UITests/CaptureWalkUITests.swift`. **Commit:** `b4dfabe`.

### 3. [Rule 2 — Missing critical measurement] Two questions a photograph cannot answer, measured instead

**Found during:** Task 2, looking at `03-walk-06`.

**Issue.** The 106-character raw row sits at the bottom edge of the frame, so whether it **wraps**
or is **cut off** — the whole of V13's second half — is not visible in the picture. And "do two
lines read identically?" cannot be answered by squinting at eleven rows.

**Fix.** Added two measurements to the walk: the raw row's **frame height** against a one-line
control (70.75 pt vs 19.33 pt = four lines, and asserted at `> 1.5 ×` so a future `lineLimit(1)`
reddens it), and a dump of all eleven of IMG_0505's line values, which is what found the duplicate
`SIMON BASSLINE SMITH` that became V16.

**Files modified:** `UITests/CaptureWalkUITests.swift`. **Commit:** `e186a3d`.

### 4. [Rule 3 — Blocking] `03-walk-07` photographs the bucket EXPANDED

**Found during:** Task 1.

**Issue.** The plan requires `03-walk-07-done-sequenced.png` to be *"a second, independent piece of
V3 evidence"*. The not-included bucket is **collapsed by default** — which is exactly why 03-03
could not obtain the second sighting and correctly declined to claim it — so a frame of the
landing state would have carried no `Vinyl N` label and V3 would have been carried a second time
on a prediction.

**Fix.** One tap on `not-included-section` before the capture. The frame still shows CAP-06's
landing (`Nothing sequenced yet` above the bucket), so it serves both purposes and the count stays
at nine. **Nothing asserts that the rows read `Vinyl N`** — the labels are printed, and the
photograph is the evidence. An assertion on a defect is a landmine for whichever plan fixes it.

**Files modified:** `UITests/CaptureWalkUITests.swift`. **Commit:** `b4dfabe`.

### 5. [Rule 2] The whole screenshot set was re-captured, not just the nine new frames

The full suite writes all 33 frames into one container per run, so purging only `03-walk-*` would
have left 24 frames on the host from an older run while the new nine came from this one — a mixed
evidence set that reads as a single one. The whole glob is purged before every run and all 33 are
committed together. Consequence: the 24 previously committed frames show as modified.

---

## Authentication gates

None. Nothing in this plan touched a credential, a network call or a signing identity.

---

## What FAILED, plainly

Three things did not go cleanly, and one claim still rests on a single kind of observation.

**1. Two full-suite runs failed before the green one.** Not a flake — two real defects in this
plan's own test code, both described under Deviations #1. The first run failed on
`CaptureWalkUITests.swift:390` (*"tile 5 never became reachable after 15 swipes — frame
(-516.0, 613.3, 104.0, 104.0)"*), the second on the raised `isHittable`. Runs A, B and C are the
three that passed. The plan's `ls … | wc -l | grep -q 9` gate would have passed on the *first* of
those failed runs if `collect-screenshots.sh` had been run after it, because seven of the nine
frames were already written before the failure — which is exactly the leftover hazard the phase
warns about, met in the wild. It was not run; the glob was purged and the suite re-run instead.

**2. The plan's stated scroll technique does not work on this SDK.** `swipeLeft` until
`isHittable` is written into the plan twice and is wrong twice over. Reported rather than quietly
worked around, because the next plan that needs to reach an off-screen element will otherwise
write the same two lines.

**3. `V6` is still not assessable, and this plan had the best chance of closing it.**
`03-walk-07` reaches **twelve** records, which is the first time any Act I frame has passed ten —
but all twelve are *excluded* (no BPM, D-03-5), so the running order is empty and the
double-digit index alignment V6 is about was never rendered. Twelve records and still no
`10` in a monospaced index column. Honest "not assessable", for the second phase running.

**4. One claim rests on a single observation kind.** The flip-prompt banner's own accessibility
label was read 27 times and was empty every time — that is well measured. But the *content* of the
prompt (`Only one side read`, and the record's name beneath it) is asserted **nowhere**; it is
established only by looking at `03-walk-02-flip-prompt-fires.png` and `03-03-capture-flip-prompt.png`.
The identifier contract forbids asserting on display strings, which is the right rule, so this is
a picture-only fact and is recorded as one.

**5. Not a failure, but it should be said out loud: `./Scripts/test.sh` prints a green line that
is wrong.** *"BPM is non-decreasing across the whole winning sequence"* passes, and the rule it
tests was removed on 2026-08-30 when SEQ-03 went bidirectional. One of the 168 green tests asserts
a specification that no longer exists. Phase 9's, tracked in `REQUIREMENTS.md` with the
five-artefact inventory, and untouched here on purpose.

---

## Carried into Act I Phase 4 — so sign-off does not mistake it for Phase 3 debt

- **`AsyncSequencer` and `BeamDivergenceCheck` do not exist.** Plan 01-05 was never executed.
  `grep -rn "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/` → rc=1, run
  again by this plan. **SEQ-08, SEQ-09 and SEQ-10 are wholly outstanding**, not partly built, and
  Phase 9 inherits `01-05-PLAN.md`'s content along with
  `.planning/open-questions/RejoinTests.swift.wip`.
- **SEQ-03 is REOPENED**, not complete, and is not counted in the 23. The BPM rule is now
  bidirectional (`|Δbpm| ≤ tolerance` either direction; the non-decreasing requirement removed),
  and the shipped implementation and its tests still assert the old rule in the five places
  `REQUIREMENTS.md` inventories. Phase 9's.
- **Screenshot count is 14 distinct states out of 15 in the crate walk** (V14), which Phase 4's
  "screenshot count equals screen count" criterion needs to know before it counts.
- **U9 and U10** added to `UAT-PENDING.md`; **U8 still open** and now carrying a second piece of
  evidence.

---

## Self-Check: PASSED

Files claimed created, verified on disk:

```
FOUND: UITests/CaptureWalkUITests.swift
FOUND: Artifacts/screenshots/03-walk-01-capture-guide.png … 03-walk-09-strip-scrolled-to-end.png  (9/9)
FOUND: .planning/phases/03-capture-correction-screens/03-05-SUMMARY.md
```

Commits claimed, verified in `git log`:

```
FOUND: b4dfabe  test(03-05): the twelve-fixture session walk and the twenty-one-item strip
FOUND: e186a3d  test(03-05): measure defect V13 by frame geometry, not by eye
```
