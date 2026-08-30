# Visual defects — found by looking at screenshots, not by tests

These are real and visible in `Artifacts/screenshots/`. Unit tests pass on all of them,
which is exactly why the screenshot matters.

Every row cites the specific screenshot that is its evidence. A row without a named
screenshot is an opinion, not a defect.

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| ~~V1~~ | ~~**"1 records"** — pluralisation not handled~~ | **FIXED 2026-08-30 (plan 02-01), CLOSED WITH EVIDENCE (plan 02-05).** See "V1 — closed" below. Evidence: `02-walk-01-crate-list.png` and `02-01-crate-list-pluralised.png`. | — | Closed |
| ~~V2~~ | ~~Whole UI washed out to near-invisible grey~~ | **NOT A DEFECT — RESOLVED 2026-08-30, RE-CONFIRMED ON THE NEW SCREENS (plan 02-05).** See "V2 — closure re-confirmed" below. Evidence: all fifteen `02-walk-*.png`, probed twice. | — | Closed |
| V3 | **The not-included bucket names a record "Vinyl 2" even though its artist, title, BPM and key are all known.** The row reads `Vinyl 2 · 178 · 6A · "No track within 4 BPM of the set"` — the badges carry real data from a track the app can name `Dillinja — Angels Fell`. A DJ reading the bucket cannot tell which record was left out, which is half of what SEQ-07 exists to say. | `02-walk-07-not-included-expanded.png` (rows "Vinyl 2" / "Vinyl 3"); same defect independently visible in plan 02-03's `02-03-crate-detail-bucket-expanded.png`; **SECOND SIGHTING obtained 2026-08-30 by plan 03-05 on a screen that did not exist when V3 was found** — `03-walk-07-done-sequenced.png`, twelve freshly captured records in the bucket, the eight visible rows reading `Vinyl 1` … `Vinyl 8` while the strip four frames earlier (`03-walk-04-strip-twelve.png`) named the same records from their own OCR text. **Not fixed here — the product call is U8 and it is the owner's.** | **Medium** | Phase 4 |
| V4 | **Placeholder badges are near-invisible.** An unresolved record's `—` / `—` badge pair renders `.foregroundStyle(.secondary)` on a `.thinMaterial` capsule — light grey on light grey. SEQ-11's rule is that a missing value is *dimmed, never hidden*; at this contrast it is very close to hidden. | `02-walk-07-not-included-expanded.png`, the "Vinyl 3" row | Low | Phase 4 |
| V5 | **Two fixture vinyls share `position: 2`, so both would render as "Vinyl 3".** `FixtureCrates.mixedResultsCrate` gives `sharedVinyl` and `unresolvedVinyl` the same `position`, and `VinylEntry.label`'s fallback is `"Vinyl \(position + 1)"`. **Not visible in any of the fifteen photographs** — only one of the two ever lands in the bucket — so this is a latent duplicate-label hazard found by reading the fixture, not by looking. Recorded because V3's fix touches the same line. | none — read from `FixtureCrates.swift:24` and `:48`, not from a picture | Low | Phase 4 |
| V6 | **Running-order index alignment at double digits could not be assessed.** No fixture crate reaches ten rows, so no photograph in the set shows an index of `10` or above against the `minWidth: 20` monospaced column. Honest "not assessable from this capture" rather than a guess either way. | none — the fifteen photographs top out at index `2` | Low | Phase 4 |
| ~~V7~~ | ~~**The walk never photographs the empty running order.**~~ | **CLOSED 2026-08-30 (plan 03-03), with a picture.** The walk's step 4 now presses the real shutter, and a captured sleeve carries OCR text but no BPM, so the sequencer cannot schedule it and the new crate's running order is genuinely empty. `02-walk-05-new-crate-detail.png` shows "Nothing sequenced yet" above "Not in the set (1)". The walk asserts it two-sidedly (`empty-running-order` present AND `sequenced-row-1` absent), and Mutation D below proves that assertion can fail. | — | Closed |
| ~~V8~~ | ~~**The capture screen still reads as scaffolding**~~ | **CLOSED 2026-08-30 (plan 03-03).** `CapturePlaceholderView` is deleted and `RootView` routes `.capture` to the real `CaptureView`. No frame anywhere says "Camera arrives in Phase 3" any more. Evidence: `02-walk-03-capture-empty.png`, `02-walk-11-add-more-capture.png` and all four `03-03-capture-*.png`. | — | Closed |
| V9 | **Thirteen of the walk's fifteen frames render no large navigation title.** The crate list shows "Crates" on `02-walk-01` and then never again; the crate detail never shows the crate's name at all; the capture screen shows "Capture" in one test and not in the other. A DJ two screens deep cannot tell from the picture which crate they are in. **Not a capture-timing artefact** — see "V9 — measured, not guessed" below. **Not introduced by plan 03-03**: it is equally absent on Phase 2's own `CrateDetailView` and `CrateListView`, which this plan did not touch, and plan 02-03's frames of the same screens have their titles. | absent: `02-walk-03` … `02-walk-15` (13 frames). present: `02-walk-01-crate-list.png`, all four `03-03-capture-*.png`, and every `02-03-crate-detail*.png` | **Low** | Phase 4 |
| V10 | **The sleeve framing guide changes size when the flip-side prompt appears.** The preview is a flexible box, so the inline banner pushing in shrinks the preview and the guide follows it: the guide's stroked square measures **872x873 px** with no prompt and **686x686 px** with one — a 21% jump, mid-framing. Correct arithmetic (`edgeCoverage` holds at 0.881 and 0.879 of the preview's shorter edge in both cases, which is the point of deriving it from `FramingGuide.sleeve`), but with a live viewfinder a reticle that resizes while you are lining a sleeve up is its own annoyance. Belongs to Phase 10, where the preview stops being a flexible black rectangle and becomes a fixed-aspect camera layer. | `03-03-capture-flip-prompt.png` (686 px) against `03-03-capture-empty.png`, `03-03-capture-one-item.png`, `03-03-capture-flip-suppressed.png` (872 px). Measured on 7 frames across 3 runs. | Low | Phase 10 |
| V12 | **The inspect sheet titles a record `Zzz.`** — a two-syllable fragment of a price sticker — on a photograph that also read `Cause 4 Concern` (the artist) and `A: High Down` (the title), both at confidence 1.00. `CaptureItem.displayLabel` takes the **first trusted observation in reading order**, and OCR reading order is spatial, not semantic, so whichever scrap of text sits highest-left on the sleeve becomes the record's name. Not a regression and not V3: it is the deliberate ceiling of D-03-6's naming rule (which exists to keep `"Vinyl N"` off the new screens) made visible for the first time. A DJ scrolling a twelve-tile strip cannot tell which record `Zzz.` is. Real segmentation (SEG-01…06) is what gives a title rule something better to pick from. | `03-04-sheet-lines.png`, `03-04-sheet-after-merge.png`, `03-04-sheet-after-split.png`, `03-04-sheet-hand-typed.png` (all four title-bars read `Zzz.`); independently, `FixtureObservations.swift:205` — IMG_0503's first observation is `"Zzz."` at 1.00; and XCUITest's own accessibility dump on this plan's second run printed `identifier: 'capture-thumb-6', label: 'Zzz.'` on the thumbnail strip, a different screen | **Medium** | Phase 6 |
| ~~V13~~ | ~~**A long recognised line's behaviour in the correction field is not assessable from this capture.**~~ | **CLOSED 2026-08-30 (plan 03-05), assessed with numbers on both halves.** The 44-character read *does* truncate in the field; the 106-character read *does not* — it wraps. See "V13 — closed, and what the assessment found" below. Evidence: `03-walk-05-inspect-sheet.png`, `03-walk-06-inspect-raw-text.png`, and the measured row heights. | — | Closed |
| V14 | **Two of the crate walk's fifteen states are the same picture.** `02-walk-08-detail-edit-mode` (edit mode, sequenced order) and `02-walk-10-detail-restored` (edit mode, order restored to sequenced) are the same screen by construction — Restore's whole job is to return to state 8 — so the walk photographs **14 materially distinct states, not 15**. Measured three times: byte-identical (`md5 d55b41d7…`) on one run, and differing only in a 1×1 antialiased pixel and a 41×92 px toolbar-material patch on the other two. Not a rendering bug; a coverage-accounting one, and it matters because Phase 4's ship criterion is "screenshot count equals screen count". Restore's *effect* is legible only by comparing `02-walk-09` to `02-walk-10`, never from `02-walk-10` alone. | `02-walk-08-detail-edit-mode.png` and `02-walk-10-detail-restored.png`, compared across three independently captured runs | Informational | Phase 4 |
| V15 | **The correction field truncates a long track line and gives no way to read the rest without tapping into it.** `EXCLUSIVE NEW MIXES FROM V CLASSIC THE ALBUM` (44 characters, the corpus's longest **trusted** read) renders as `EXCLUSIVE NEW MIXES FR…` in a 237.3 pt single-line `TextField`. The value is intact — XCUITest reads all 44 characters back off the field — so nothing is lost, but roughly half of the longest lines a DJ has to correct are invisible at rest. The raw list below does not have this problem (see V13's closure), so the same string is fully readable eleven rows further down the same sheet. | `03-walk-05-inspect-sheet.png`, line 4 | Low | Phase 4 |
| V16 | **The over-split draft contains exact duplicate lines.** IMG_0505's eleven-line draft carries `SIMON BASSLINE SMITH` **twice** — the OCR read the same text off two surfaces of one sleeve, and D-03-4's one-line-per-trusted-observation rule keeps both. IMG_0503 shows the near-miss version: `Timeless Recordings` / `TimelessRecordings` and `Cause 4 Concern-` / `Cause 4 Concern`. A person correcting this sheet has to delete lines they cannot tell apart from the ones they are keeping. This is the deliberate cost of not segmenting in Act I, made visible — de-duplication is SEG-03's filtering and belongs to Phase 6. | `03-walk-06-inspect-raw-text.png` (lines 2 and 5 both `SIMON BASSLINE SMITH`); `03-04-sheet-lines.png` (lines 8/9 and 2/10) | Low | Phase 6 |
| V11 | **Add More opens a capture screen that says "0 records" for a crate that already holds four.** The session count is scoped to the visit, which is CAP-03's own wording ("scanned so far in this session") and decision D-03-3, so it is behaving as designed — recorded as informational so a reviewer looking at the picture is not surprised, and so the owner can say whether they would rather see the crate's total. | `02-walk-11-add-more-capture.png` (Friday Warehouse, 4 records in the crate, "0 records" on the strip) | Informational | Phase 4 |

---

## V1 — closed, with evidence

**Fix, in `CrateListView.swift:21`:**

```swift
Text("^[\(summary.recordCount) record](inflect: true)")   // "1 record" / "4 records"
```

Automatic-grammar-agreement markdown, not a manual `count == 1 ? … : …` branch. The inflection
**did** fire on this SDK; the documented branch fallback was never needed.

**Evidence — the picture.** `02-walk-01-crate-list.png` reads `Sunday Chill — 1 record` and
`Friday Warehouse — 4 records`, side by side in the same frame. `02-01-crate-list-pluralised.png`
shows the same pair from the run that landed the fix. Looked at directly, at 1206×2622, both
times.

**Evidence — the two-sided assertion.** `CrateWalkUITests` step 1 asserts both halves, so the
test can fail in either direction:

- `label.contains("1 record")` — the corrected string is present
- `!label.contains("1 records")` — the defective string is absent

A one-sided `contains("1 record")` would have passed on the defect itself, since `"1 records"`
contains `"1 record"`. Both halves are required.

**Negative control.** The same step asserts
`XCTAssertFalse(app.staticTexts["record-count-Wednesday Nonexistent"].exists)`, so a
`record-count-*` query that silently resolved nothing would redden the test rather than pass
vacuously.

**V1 is closed.** It has a fix, a picture, and an assertion that can fail.

---

## V2 — closure re-confirmed against the screens that did not exist when it was diagnosed

V2 was closed on 2026-08-30: the pallor was the **launch fade**, not styling. That closure is
not re-litigated here. What plan 02-05 owed was narrower — V2 was diagnosed against a single
crate-list capture, and this phase then built four screens that capture did not contain: the
crate detail, edit mode, the expanded not-included bucket, and the empty crate list.

**Measured, twice, on independently captured pixels.** The Pillow probe was run over all
fifteen `02-walk-*.png` on plan 02-04's run and again on plan 02-05's own clean re-run
(`Artifacts/screenshots/02-walk-*.png` purged first, `./Scripts/ui-test.sh` re-run,
`./Scripts/collect-screenshots.sh` re-collected). Both runs: **`SUSPECT: none`, probe exit 0.**

| Signature | Threshold | Result across all fifteen, both runs |
|---|---|---|
| a genuinely black pixel exists | `min` ≤ 110 | `min = 0` on every frame |
| a white ground exists | `max` ≥ 200 | `max = 255` on every frame |
| the frame is not flat | `min ≠ max` | holds on every frame |

Per-frame means agreed between the two runs to within **±0.06** — the largest disagreement on
any of the fifteen. The V2 signature (`min` above ~110, meaning no dark pixel anywhere) appears
on none of the new screens.

**The stronger disproof is functional, not photometric.** The `.disabled(true)` hypothesis is
the one with real consequences, because a disabled enclosing view dims its content **and makes
that content untappable**. The walk taps `crate-row-Friday Warehouse`, `edit-button`,
`add-more-button`, `restore-sequenced-order-button`, `capture-add-fixture-button` and
`capture-done-button`, and every one of them responds — the screen changes, and the walk only
reaches state 15 because all of them did. **Disabled content is not tappable, so the walk
completing is a categorical disproof that no pixel measurement could give.** It has now
completed three times: twice under plan 02-04 and once under plan 02-05.

**V2's closure holds on the new screens.** No restyling was done and none is warranted.

---

## The rule V2 left behind, and it applies to its own successors

The pallor was an artefact of the capture harness. Restyling on the strength of that screenshot
would have damaged correct, well-contrasted code to satisfy a measurement error — a real
regression introduced to fix an imaginary bug, and one that would have been very hard to trace
back afterwards.

**So the order of hypotheses is fixed, and it is not negotiable:**

1. **Capture timing first.** If a screen looks pale, raise the settle delay and re-capture.
   Only a pallor that *survives a longer delay* is a styling question at all.
2. Then `.disabled(true)` on an enclosing view — it dims *and* disables, so test it by tapping,
   not by looking.
3. Then an inherited `.foregroundStyle(.secondary)` / `.opacity()` on a container.

Never adjust the probe's threshold to make a frame pass. If a frame is suspect, it is suspect.

## V9 — measured, not guessed, and the settle is not the answer

V2's protocol is explicit and it was followed in order, without deviation.

**Step 1, raise the settle and re-capture.** The whole suite was re-run with
`ScreenshotRecorder.defaultSettle` at **4.0 s** and `launchSettle` at **5.0 s** (up from 3.0/4.0).
The same thirteen frames came back with no title, and the title band was **pixel-identical**:
ink count 0 on all thirteen at both settles, 9498 on `02-walk-01` at both, 11753 on all four
`03-03-capture-*.png` at both. A longer delay changes nothing, so the settle was put back where
Phase 2 measured it rather than left raised for a benefit that does not exist — adjusting a knob
that does not move the needle is the mistake V2 was about.

**Step 2, `.disabled(true)`.** Disproved by tapping, not by looking, exactly as the rule requires:
the walk taps `crate-row-Friday Warehouse`, `edit-button`, `add-more-button`,
`restore-sequenced-order-button`, `capture-shutter-button`, `capture-flip-skip-button` and
`capture-done-button` on these very screens and every one responds. It reached state 15 three
times during this plan.

**What the evidence actually points at.** The title renders on the first screen after launch and
on every screen plan 02-03 photographed in its own short-lived tests, and stops rendering once
the walk has swapped `RootView`'s content through several `Route` cases in one long session. That
implicates the navigation container, not any screen's styling. Nothing was restyled on the
strength of it, and nothing should be until someone reproduces it deliberately.

**Measurement count: three full suite runs** (3.0 s, 4.0 s, 3.0 s again), 19 frames probed each
time, plus 11 untouched frames from plans 01-06/02-01/02-03 as the control group.

---

## V3 — the second sighting plan 03-03 was expected to produce, and did not

CONTEXT.md §6 predicted that CAP-06's Done would land on a crate detail whose freshly captured
vinyl sat in the not-included bucket labelled "Vinyl 1", giving V3 a second piece of evidence on a
screen that did not exist when it was found.

**That frame was not obtained, and the row is not being claimed on a prediction.**
`02-walk-05-new-crate-detail.png` does show the bucket — "Not in the set (1)" — but the bucket is
**collapsed by default**, so the row's label is not in the picture. Expanding it would mean adding
a sixteenth state to Phase 2's walk, which plan 03-03 was explicitly forbidden to do.

V3's original evidence is unchanged and still visible in this run at `02-walk-07`, `02-walk-08`,
`02-walk-09` and `02-walk-10` ("Vinyl 2" / "Vinyl 3"). The second sighting is carried to plan
03-05, which owns the full twelve-fixture walk and can expand the bucket without touching Phase
2's file. A row without a named screenshot is an opinion, not a defect — so it is not being
written as one.

---

## V4 — still open, and deliberately not repeated on the new screen

V4 (placeholder badges rendering `.secondary` on `.thinMaterial`, light grey on light grey) is
still open and still visible on the "Vinyl 3" row of `02-walk-07-not-included-expanded.png`. Plan
03-03 did not fix it — it belongs to Phase 4 — but it did refuse to repeat it. The thumbnail
strip's status indicator, which is the single piece of information the strip exists to carry,
renders white on a solid saturated ground (`Read` dark green, `Partial` amber, `Unread` dark red)
rather than secondary-on-material. Visible at `03-03-capture-flip-suppressed.png`, two `Read`
pills legible at a glance.

---

## Negative controls run by plan 03-03 — the tests are provably able to fail

A green suite is worth nothing until it has been made red on purpose. Three one-line mutations
were applied, run, and reverted. Each produced a **clean assertion failure at the named line**,
not a crashed runner, and each was confirmed from two independent sources: xcodebuild's log and
`build/ui.xcresult`'s own `failedTests` count.

| # | Mutation | Expected to redden | What actually happened |
|---|---|---|---|
| A | `CaptureSession.append` sets `pendingFlipPrompt = item.id` unconditionally — always prompt | the suppression half of CAP-05 | `CaptureScreenUITests.swift:110` — "the prompt fired on a photograph that already read TWO sides". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| B | `CaptureSession.append` sets `pendingFlipPrompt = nil` unconditionally — never prompt | the firing half of CAP-05 | `CaptureScreenUITests.swift:81` — "no flip prompt after fixture 1, which read no side markers at all". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| D | `FixtureLineSegmenter` gives every track `bpm: 174` | the walk's rewritten step 5 (V7's closure) | `CrateWalkUITests.swift:122` — "the new crate shows neither a running order nor the empty-order placeholder". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |

A and B are the same claim mutated in opposite directions, which is what makes
"fires on fixture 1, suppressed on fixture 2" a measurement rather than a coincidence.

Standing negative controls in the source, asserted every run and never removed:
`capture-thumb-99` and `sequenced-row-99` must not resolve; `capture-thumb-2` must not exist
after one shutter press; the session count must contain `1 record` **and not** `1 records`.

---

## Two-observation rule

Plans 02-03 and 02-04 both reached a confident wrong conclusion about simulator container
freshness from a single observation, and 02-04's second run disproved its own first reading.

**Any claim about behaviour recorded in this file must rest on at least two independent
observations, and must say how many times it was measured.** Every claim above does.

## Standing instruction

Every phase that renders UI captures its screens into `Artifacts/screenshots/` and records any
defect visible in them here. Passing tests say the logic is right; only the picture says the
product is usable.

Three things are **rules**, not suggestions:

1. **Settle for at least 3 seconds**, and confirm the app is actually in the foreground, before
   every capture. A screenshot taken during a transition is not evidence. Phase 2's fifteen all
   go through one `capture(_:settle:)` helper precisely so this cannot be skipped on one state
   out of fifteen.
2. **Purge the host glob before a counting run.** `Artifacts/screenshots/` accumulates and
   nothing clears it, so a run that captured fourteen states still counts fifteen on a leftover.
   `find Artifacts/screenshots -name '<glob>' -delete` first, then run the test, then collect.
3. **Look at every picture, not a sample.** A phase that produces fifteen screenshots and audits
   three has produced twelve unread files. V3 is visible only on the seventh frame, in a section that is
   collapsed by default, and no automated probe would ever have found it.


---

## Plan 03-04 — all five frames looked at, and what they do NOT show

Five states, five pictures, every one opened at 1206x2622 and read, not sampled. The plan named
three specific things to look for, from Phase 2's own findings. Two came back clean and the
third is un-assessable; all three are recorded, including the clean ones, because "we looked and
found nothing" is only worth anything if it is written down.

| Frame | Fixture | State | What it shows |
|---|---|---|---|
| `03-04-sheet-lines.png` | IMG_0503 | the draft as opened | 16 over-split lines, merge-up dimmed on row 1 |
| `03-04-sheet-raw-text.png` | IMG_0498 | raw text expanded | 9 lines above, 11 raw rows below, the 0.30 read among them |
| `03-04-sheet-after-merge.png` | IMG_0503 | after one `inspect-merge-up-2` | 15 lines; row 1 is `Zzz. Cause 4 Concern-` |
| `03-04-sheet-after-split.png` | IMG_0503 | after one `inspect-split-1` | 16 lines; rows 1-2 are `Zzz. Cause` / `4 Concern-` |
| `03-04-sheet-hand-typed.png` | IMG_0503 | after Add a line + typing | 17 lines; row 17 is `DUBPLATE WHITE LABEL` |

**Contrast on the confidence values — NONE FOUND, and this was V4's exact failure mode.** V4 is
`.secondary` on `.thinMaterial`: light grey on light grey, invisible in a photograph and
invisible to every test. It is not repeated here. `03-04-sheet-raw-text.png` renders `1.00` as
white on a solid dark green capsule and `0.30` as white on a solid dark red one, both legible at
a glance, and the trusted/untrusted distinction is carried by the **number as well as** the
colour, so it survives a colour-blind reader and a greyscale print. The plan required this to be
checked on a picture rather than asserted; it was.

**Truncated fields that make two lines read identically — NONE FOUND in these five frames**, and
that is a weaker statement than it looks, which is why it is also filed as **V13** above. Every
line in both photographed fixtures fits its field; the corpus contains a 106-character read that
does not, on a fixture no 03-04 frame opens.

**Controls colliding on a long line — NONE FOUND.** Scissors and merge-up are fixed-width on the
right and the field flexes into what is left, so the row is stable at 9 lines
(`03-04-sheet-raw-text.png`) and at 17 (`03-04-sheet-hand-typed.png`) with no reflow between
them. This was checked at both counts rather than at one.

**What the pictures found that no assertion did: V12.** Four of the five frames title the record
`Zzz.`. Every test in this plan passes on that, and would pass on any string at all, because the
identifier contract forbids asserting on a display string — which is the right rule and exactly
why looking at the picture is a separate obligation.


---

## Negative controls run by plan 03-04 — the sheet's tests are provably able to fail

A green suite is worth nothing until it has been made red on purpose. Four mutations, each
applied, run, confirmed from **two independent sources** (xcodebuild's log and
`build/ui.xcresult`'s own `failedTests`), and reverted. None crashed the runner; all four produced
clean assertion failures at named lines.

| # | Mutation | Expected to redden | What actually happened |
|---|---|---|---|
| E | `InspectCorrectSheet`'s merge-up button wired to `{ }` — the control is live and does nothing | SEG-07's merge claim | `InspectSheetUITests.swift:148` — "one merge-up took 16 lines to 16". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| F | `RawObservationListView` filters the list to `\.isTrusted` — the untrusted reads are hidden | OCR-04's entire point | `InspectSheetUITests.swift:97` — "IMG_0498 produced 11 observations; the sheet lists 3". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| G | `apply()` edits its copy of the crate but never calls `store.update` | the write-back | "Apply did not write 17 corrected lines back to the crate — reopened with 16". log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| H | the binding's equality guard removed, so a focus echo reaches `setText` | hand entry | the empty line is deleted by the tap that should focus it; `app.textFields` returns 16 of 17 identifiers and no keyboard ever appears. **Red 4 times, green 2 times with the guard.** |

**F is worth reading twice.** Hiding the two 0.30 reads did not make the list *shorter by two* — it
made the walk stop at **3**, because removing observation 4 breaks the contiguity the
`inspect-raw-obs-{n}` family is counted by. That is the contiguity property doing real work
rather than being a stylistic preference.

**H was not a planned mutation.** It happened because reverting mutation E with
`git checkout -- App/Views/InspectCorrectSheet.swift` also discarded an *uncommitted* fix in the
same file, and the suite went red on the next run. The lesson is procedural and is written down
here rather than learned twice: **commit a fix before mutating the file it lives in.** The
accident was worth having — it turned a one-observation fix into a four-red/two-green
measurement.

Standing negative controls in the source, asserted every run and never removed:
`inspect-raw-obs-999` and `inspect-line-99` must not resolve, in **both** sheets; and every line
count is two-sided (`inspect-line-{k}` exists **and** `inspect-line-{k+1}` does not).


---

## Plan 03-05 — thirty-three frames looked at, and how many times each claim was measured

Nine `03-walk-*.png`, four `03-03-*.png`, five `03-04-*.png` and the fifteen re-captured
`02-walk-*.png`. Every one opened at 1206×2622 and read, not sampled. Phase 2's standing
instruction says a phase that produces fifteen screenshots and audits three has produced twelve
unread files; this is the audit that says it did not.

**All thirty-three frames come from one `xcodebuild test` run, into one simulator container,
after the whole `03-walk-*`, `02-walk-*`, `03-03-*`, `03-04-*` and `02-smoke-*` glob was purged
from the host.** Not one is a leftover.

### The photometric probe — run THREE times, on three independently captured runs

| Signature | Threshold | Result across all 33 frames, all three runs |
|---|---|---|
| a genuinely black pixel exists | `min` ≤ 110 | `min = 0` on every frame |
| a white ground exists | `max` ≥ 200 | `max = 255` on every frame |
| the frame is not flat | `min ≠ max` | holds on every frame |

**`SUSPECT: none`, probe exit 0, three times.** Per-frame mean drift: **0.022** between runs A
and B, **0.024** between A and C, **0.029** between B and C — against Phase 2's stated bar of
±0.06. No threshold was adjusted. The V2 pallor signature appears on none of the new screens.

### What the pictures showed that no assertion did

| Finding | Frames | Times measured |
|---|---|---|
| **V3's second sighting, obtained.** The bucket header reads `Not in the set (12)` and the eight rows the frame reaches read `Vinyl 1` … `Vinyl 8` — the *same* records the strip named `HIGHER`, `Emotif/Xstatic EMF2029`, `inckatecks*`, `Zzz.` … four frames earlier **in the same session**. One record, two names, two screens | `03-walk-07-done-sequenced.png` against `03-walk-04-strip-twelve.png` | **three runs** — the eight-name list came back byte-identical on A, B and C, and the frame was captured on each |
| **V9, narrowed to a clean rule.** Every frame carrying a large navigation title was taken **before any `.sheet` had been presented**; every frame without one was taken **after** a sheet had been presented and dismissed. 33 of 33 frames obey it, with no exception | present: `02-walk-01`, `02-smoke`, all four `03-03-*`, `03-walk-08`, `03-walk-09`. absent: `02-walk-03`…`02-walk-15`, `03-walk-01`…`03-walk-04`, `03-walk-07` | **three runs**, same split each time |
| **V13, closed.** See below | `03-walk-05`, `03-walk-06` | **three runs** for the field width and the row height; the numbers were identical each time |
| **V4, not fixed and now twelve times as visible.** `03-walk-07` renders **twelve** `— —` badge pairs, secondary-on-material, in one frame | `03-walk-07-done-sequenced.png` | twice (Phase 2's frame and this one) |
| **V10, confirmed again.** The guide measures **290.67 × 291 pt** (872 px) with no prompt and is visibly smaller with one, in the same test, four frames apart | `03-walk-01-capture-guide.png` against `03-walk-02-flip-prompt-fires.png` | **three runs**; the pt figure was printed on each |
| **V11, confirmed again.** Add More opens on `Friday Warehouse` reading `0 records` for a four-record crate | `02-walk-11-add-more-capture.png` | twice (Phase 3's original sighting and this re-capture) |
| **V12, confirmed on a third screen.** The strip tile for fixture 6 is labelled `Zzz.` | printed from `capture-thumb-6`'s label on all three runs; visible in `03-04-sheet-lines.png` | **three runs** |
| **V7 stays closed.** `Nothing sequenced yet` above `Not in the set (1)` | `02-walk-05-new-crate-detail.png` | twice, and now a third time at twelve records on `03-walk-07` |
| **V14, new** — states 8 and 10 are the same picture | `02-walk-08`, `02-walk-10` | **three runs** |
| **V15, new** — the correction field truncates at ~22 characters | `03-walk-05-inspect-sheet.png` | **three runs** |
| **V16, new** — the draft carries exact duplicate lines | `03-walk-06`, `03-04-sheet-lines.png` | **three runs** |

### Checked deliberately and found clean — written down because "we looked and found nothing" is only worth something if it is recorded

- **V4's failure mode on the new screens: NOT repeated.** The strip's status pill is white on
  solid dark green / amber / dark red and legible at a glance in `03-walk-04-strip-twelve.png`
  at four tiles and in `03-walk-09-strip-scrolled-to-end.png` at the far end of twenty-one. The
  raw list's confidence capsule is white on solid dark green / dark red in
  `03-walk-06-inspect-raw-text.png`, and carries the number as well as the colour.
- **V3 kept out of the new screens: confirmed two ways.** No tile in the twelve-shot walk
  matched `^Vinyl \d+$` (asserted every run, `CaptureWalkUITests.swift:99`), and
  `grep -rn "VinylEntry.label" App/` returns nothing (rc=1).
- **The framing guide reads as square and frames a sleeve, not a label.** `290.67 × 291 pt`
  measured off the rendered accessibility frame — 0.5 pt out of square on a 291 pt box — and it
  covers most of the preview's shorter edge with the caption *"Fill the square with the whole
  sleeve — not just the label."* directly beneath it. Whether it frames a **real** sleeve at
  arm's length is U10 and cannot be answered without a camera.
- **Controls colliding on a long line: none.** The scissors and merge-up buttons are fixed-width
  on the right at 4 lines (`03-walk-05`) and at 11 (`03-walk-06`), with no reflow between them.

### One thing that is not a defect but should not be discovered twice

`app.otherElements["capture-flip-prompt"].label` is **empty**. The banner uses
`.accessibilityElement(children: .contain)`, which keeps `Skip` and `Scan` individually
queryable — the whole reason the contract specifies it — and therefore publishes no label of its
own. The prompt's text (`Only one side read` / the record's name) lives on its children and is
plainly visible in `03-walk-02-flip-prompt-fires.png`. The walk prints the label every run; it
printed `''` twelve times over. Reading the banner's own label is not a way to read the prompt.

---

## V13 — closed, and what the assessment found

V13 asked one question in two halves, and 03-04 could answer neither because the widest line any
of its frames rendered was 20 characters.

**Half one — the correction `TextField`. It truncates.** IMG_0502's draft holds the corpus's
longest **trusted** read at 44 characters. Measured, three runs, identical each time:

```
WALK12 V13 line 4: 44 chars, field 237.33333333333331pt, 'EXCLUSIVE NEW MIXES FROM V CLASSIC THE ALBUM'
```

and `03-walk-05-inspect-sheet.png` renders it as `EXCLUSIVE NEW MIXES FR…`. The value is intact
— XCUITest reads all 44 characters back — so nothing is lost, but about half of it is invisible
at rest. Filed as **V15**.

**Half two — the raw list. It wraps, and loses nothing.** The corpus's longest read overall is
106 characters, and it is **not** in any draft: it came back at confidence 0.30 and the
segmenter drops it (which is precisely what OCR-04 exists to expose). It appears only in the raw
list, at the bottom edge of `03-walk-06-inspect-raw-text.png` — so the photograph cannot say
whether it wraps or is cut off, and **height was measured instead**:

```
WALK12 V13 raw row 1 height = 19.33331298828125pt      <- one-line control
WALK12 V13 raw row 2 height = 19.3333740234375pt       <- one-line control
WALK12 V13 raw row 3 height = 70.74652099609375pt      <- the 106-character read
```

70.75 against 19.33 is **four rendered lines**. The raw list wraps the longest read in the corpus
in full. The walk asserts `height > 1.5 × one-line`, so a future `lineLimit(1)` would redden it.

**The question V13 was really about — "do two different lines read identically?" — is answered
YES, and truncation is not the cause.** IMG_0505's draft carries `SIMON BASSLINE SMITH` twice
because the OCR read it off two surfaces of one sleeve. Filed as **V16**, owner Phase 6.

---

## V9 — the narrowing plan 03-05 could do that 03-03 could not

03-03 measured the settle (no effect), disproved `.disabled(true)` by tapping, and concluded the
navigation container was implicated without being able to say what triggered it. Thirty-three
frames across two entry routes now split cleanly:

| Route onto the screen | Sheet presented first? | Large title |
|---|---|---|
| launch → crate list (`02-walk-01`, `02-smoke`) | no | **present** |
| crate list → crate detail → Add More → capture (all four `03-03-*`, `03-walk-08`, `03-walk-09`) | no | **present** |
| crate list → new-crate **sheet** → Create → capture (`02-walk-03`, `03-walk-01`…`03-walk-04`) | yes | absent |
| anything at all after that sheet has been dismissed (`02-walk-05`…`02-walk-15`, `03-walk-07`) | yes | absent |

`03-walk-08` and `03-walk-09` are the load-bearing rows: they are the **same `CaptureView`** as
`03-walk-01`…`03-walk-04`, in the **same suite run**, and they have their title because that
test never opens a sheet. The screen is not the variable; the sheet is.

**Measured three times** — runs A, B and C each produced the same split with no exception across
all 33 frames. It remains **Low** and Phase 4's, and nothing was restyled on the strength of it,
per the rule V2 left behind. What changes is that whoever picks it up now has a one-line repro
rather than a hypothesis: present a `.sheet` from `RootView`, dismiss it, and watch every
subsequent `navigationTitle` stop rendering.

---

## Negative controls run by plan 03-05 — the walk's own assertions are provably able to fail

Three mutations, each applied to a **committed** tree (the lesson mutation H left behind), each
run, each confirmed from **two independent sources**, each reverted. None crashed the runner.

| # | Mutation | Expected to redden | What actually happened |
|---|---|---|---|
| I | `FixturePhotoSource.table` scores `IMG_0500` as `.read` instead of `.partial` | the 6/5/1 status tally | `CaptureWalkUITests.swift:153` — *"the strip's status tally is ["Read": 7, "Partial": 4, "Unread": 1], not 6 Read / 5 Partial / 1 Unread"*. log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| J | `CaptureThumbnailStrip`'s tile width shrinks with the item count instead of staying fixed | CAP-03's *"scrolls past 20 items without layout breaking"* | `CaptureWalkUITests.swift:228` — *"the tiles compressed from 101.0pt to 41.0pt — the strip is shrinking, not scrolling"*. log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |
| K | `CaptureSession.append` sets `pendingFlipPrompt = item.id` unconditionally | the named flip set | `CaptureWalkUITests.swift:142` — *"the flip prompt fired on [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], not on [1, 3, 4, 5, 7, 8, 10, 11, 12]"*. log: 1 test, 1 failure. xcresult: `passed 0 / failed 1`. |

**J is the one worth reading twice.** Under it, `capture-thumb-21` still existed, `capture-thumb-22`
still did not, and `21 records` still rendered — **every count and existence assertion in the test
passed**. Only the width comparison saw it. That is the whole argument for measuring the layout
claim as a layout claim, and it is now demonstrated rather than asserted.

After all three reverts: `git diff HEAD` empty, 168 Core tests green, both walk tests green,
`xcresult passed=2 failed=0`.

Standing negative controls in the source, asserted every run and never removed:
`capture-thumb-99` and `capture-thumb-status-99` must not resolve **while `capture-thumb-1` does**
— the positive control is what stops the pair being vacuous; `inspect-line-99` and
`inspect-raw-obs-999` must not resolve; `capture-thumb-13` must not exist after twelve shots and
`capture-thumb-22` must not exist after twenty-one; and the session count must read `12 records`
and never `1 records`.
