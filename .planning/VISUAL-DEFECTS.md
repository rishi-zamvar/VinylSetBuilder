# Visual defects — found by looking at screenshots, not by tests

These are real and visible in `Artifacts/screenshots/`. Unit tests pass on all of them,
which is exactly why the screenshot matters.

Every row cites the specific screenshot that is its evidence. A row without a named
screenshot is an opinion, not a defect.

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| ~~V1~~ | ~~**"1 records"** — pluralisation not handled~~ | **FIXED 2026-08-30 (plan 02-01), CLOSED WITH EVIDENCE (plan 02-05).** See "V1 — closed" below. Evidence: **the defect itself is photographed in `01-06-crate-list.png`** (`Sunday Chill — 1 records`, opened and read by plan 04-04 — added because both previously-cited frames show the FIXED text); the fix in `02-walk-01-crate-list.png` and `02-01-crate-list-pluralised.png`. | — | Closed |
| ~~V2~~ | ~~Whole UI washed out to near-invisible grey~~ | **NOT A DEFECT — RESOLVED 2026-08-30, RE-CONFIRMED ON THE NEW SCREENS (plan 02-05).** See "V2 — closure re-confirmed" below. Evidence: all fifteen `02-walk-*.png`, probed twice. | — | Closed |
| V3 | **The not-included bucket names a record "Vinyl 2" even though its artist, title, BPM and key are all known.** The row reads `Vinyl 2 · 178 · 6A · "No track within 4 BPM of the set"` — the badges carry real data from a track the app can name `Dillinja — Angels Fell`. A DJ reading the bucket cannot tell which record was left out, which is half of what SEQ-07 exists to say. | `02-walk-07-not-included-expanded.png` (rows "Vinyl 2" / **"Vinyl 4"** since plan 04-03 closed V5; the same two rows read "Vinyl 2" / "Vinyl 3" in every capture before it — the name is still a position, which is V3's whole complaint, and the renumbering does not touch it); same defect independently visible in plan 02-03's `02-03-crate-detail-bucket-expanded.png`; **SECOND SIGHTING obtained 2026-08-30 by plan 03-05 on a screen that did not exist when V3 was found** — `03-walk-07-done-sequenced.png`, twelve freshly captured records in the bucket, the eight visible rows reading `Vinyl 1` … `Vinyl 8` while the strip four frames earlier (`03-walk-04-strip-twelve.png`) named the same records from their own OCR text. **Not fixed here — the product call is U8 and it is the owner's.** **ADJUDICATED 2026-08-30 (plan 04-04): CARRIED, owner Phase 4 / U8** — see the machine-readable ledger for the full reason and the asymmetry between the two candidate fixes. | **Medium** | CARRIED — Phase 4 / U8 |
| ~~V4~~ | ~~**Placeholder badges are near-invisible.**~~ | **CLOSED 2026-08-30 (plan 04-03), with four numbers on two independently captured runs.** The `—` / `—` pair rendered `.secondary` ink on a `.thinMaterial` capsule and measured **4.01:1**, under WCAG 2.2 AA's 4.5:1 for 12 pt text. A solid `.tertiarySystemFill` capsule plus `.primary.opacity(0.7)` ink takes it to **7.96:1**, and the complete pair stays strictly ahead at 18.27:1, so SEQ-11's *dimmed, never hidden* holds on both halves. See "V4 — closed, and what the plan's own gate could not see" below. Evidence: `04-badge-placeholder.png`, `04-badge-complete.png`, `02-walk-07-not-included-expanded.png`; assertion `UITests/BadgeContrastUITests.swift`. | Low | Closed |
| ~~V5~~ | ~~**Two fixture vinyls share `position: 2`, so both would render as "Vinyl 3".**~~ | **CLOSED 2026-08-30 (plan 04-03).** `unresolvedVinyl` moved to `position: 3`. `FixtureCratesTests` now asserts label uniqueness AND position uniqueness across **every** crate `FixtureCrates.all` exposes, and `demoStore` is built from that same list so a crate added to the app is a crate under test. Red before the fix and red again under the restored duplicate, the label assertion naming `["Vinyl 3"]` and the position one naming `[2]`. The defect is now visible in a photograph for the first time: `02-walk-07-not-included-expanded.png` reads `Vinyl 2` / `Vinyl 4` where it read `Vinyl 2` / `Vinyl 3`. | Low | Closed |
| V6 | **Running-order index alignment at double digits could not be assessed.** No fixture crate reaches ten rows, so no photograph in the set shows an index of `10` or above against the `minWidth: 20` monospaced column. Honest "not assessable from this capture" rather than a guess either way. | none — the fifteen photographs top out at index `2`; `03-walk-07` reaches twelve records but all twelve are excluded, so the running order is empty. **ADJUDICATED 2026-08-30 (plan 04-04): CARRIED, owner Phase 11** (D-04-2), and it must be RE-CARRIED rather than closed if Phase 11's own run still produces fewer than ten sequenced rows. | Low | CARRIED — Phase 11 |
| ~~V7~~ | ~~**The walk never photographs the empty running order.**~~ | **CLOSED 2026-08-30 (plan 03-03), with a picture.** The walk's step 4 now presses the real shutter, and a captured sleeve carries OCR text but no BPM, so the sequencer cannot schedule it and the new crate's running order is genuinely empty. `02-walk-05-new-crate-detail.png` shows "Nothing sequenced yet" above "Not in the set (1)". The walk asserts it two-sidedly (`empty-running-order` present AND `sequenced-row-1` absent), and Mutation D below proves that assertion can fail. | — | Closed |
| ~~V8~~ | ~~**The capture screen still reads as scaffolding**~~ | **CLOSED 2026-08-30 (plan 03-03).** `CapturePlaceholderView` is deleted and `RootView` routes `.capture` to the real `CaptureView`. **CORRECTED by plan 04-04:** this row previously said *"no frame anywhere says 'Camera arrives in Phase 3' any more"*, and that is false — `02-03-capture-stub.png`, a historical frame plan 02-03 committed, still reads exactly that, and it was opened at 1206x2622 and read. **That is the row's photograph of its own defect** and it is why the claim is corrected rather than deleted. No frame *written by the current suite* carries the string. Evidence — defect: `02-03-capture-stub.png`; fix: `02-walk-03-capture-empty.png`, `02-walk-11-add-more-capture.png` and all four `03-03-capture-*.png`. | — | Closed |
| V9 | **Thirteen of the crate walk's fifteen frames render no navigation title — neither large nor inline.** `02-walk-06` was cropped and looked at: the bar carries only the `Crates` and `Edit` buttons and the crate's name is nowhere on the screen. **The rule this row carried for two phases was WRONG and is corrected below** — it is not "a sheet was presented". Plan 04-03 root-caused it to a two-session A/B with exactly one variable, and rejected three fixes by measurement. See "V9 — the rule was wrong, and here is the right one" below. | absent: `02-walk-03` … `02-walk-15` (13 frames, band ink 0), `03-walk-01/02/03/04/07`. present: `02-walk-01` (9677), `02-smoke-crate-list` (9677), all four `03-03-capture-*` (11746), `03-walk-08`/`09` (11746) | **Low** | CARRIED — **Phase 11** |
| V10 | **The sleeve framing guide changes size when the flip-side prompt appears.** The preview is a flexible box, so the inline banner pushing in shrinks the preview and the guide follows it: the guide's stroked square measures **872x873 px** with no prompt and **686x686 px** with one — a 21% jump, mid-framing. Correct arithmetic (`edgeCoverage` holds at 0.881 and 0.879 of the preview's shorter edge in both cases, which is the point of deriving it from `FramingGuide.sleeve`), but with a live viewfinder a reticle that resizes while you are lining a sleeve up is its own annoyance. Belongs to Phase 10, where the preview stops being a flexible black rectangle and becomes a fixed-aspect camera layer. | `03-03-capture-flip-prompt.png` (686 px) against `03-03-capture-empty.png`, `03-03-capture-one-item.png`, `03-03-capture-flip-suppressed.png` (872 px). Measured on 7 frames across 3 runs. | Low | CARRIED — Phase 10 |
| V12 | **The inspect sheet titles a record `Zzz.`** — a two-syllable fragment of a price sticker — on a photograph that also read `Cause 4 Concern` (the artist) and `A: High Down` (the title), both at confidence 1.00. `CaptureItem.displayLabel` takes the **first trusted observation in reading order**, and OCR reading order is spatial, not semantic, so whichever scrap of text sits highest-left on the sleeve becomes the record's name. Not a regression and not V3: it is the deliberate ceiling of D-03-6's naming rule (which exists to keep `"Vinyl N"` off the new screens) made visible for the first time. A DJ scrolling a twelve-tile strip cannot tell which record `Zzz.` is. Real segmentation (SEG-01…06) is what gives a title rule something better to pick from. | `03-04-sheet-lines.png`, `03-04-sheet-after-merge.png`, `03-04-sheet-after-split.png`, `03-04-sheet-hand-typed.png` (all four title-bars read `Zzz.`); independently, `FixtureObservations.swift:205` — IMG_0503's first observation is `"Zzz."` at 1.00; and XCUITest's own accessibility dump on this plan's second run printed `identifier: 'capture-thumb-6', label: 'Zzz.'` on the thumbnail strip, a different screen | **Medium** | **CLOSED — Phase 6, 2026-08-30.** `CaptureItem.displayLabel` now takes the first trusted reading the SEG-03 noise filter KEEPS. `IMG_0503` reads `Cause 4 Concern-`; `IMG_0508` moved from `$10.007` to `Da Lick`; the other ten names are unchanged. Photographed in the regenerated `03-04-sheet-lines.png`. Commit `f980c1a`. |
| ~~V13~~ | ~~**A long recognised line's behaviour in the correction field is not assessable from this capture.**~~ | **CLOSED 2026-08-30 (plan 03-05), assessed with numbers on both halves.** The 44-character read *does* truncate in the field; the 106-character read *does not* — it wraps. See "V13 — closed, and what the assessment found" below. Evidence: `03-walk-05-inspect-sheet.png`, `03-walk-06-inspect-raw-text.png`, and the measured row heights. | — | Closed |
| ~~V14~~ | ~~**Two of the crate walk's fifteen states are the same picture.**~~ `02-walk-08-detail-edit-mode` (edit mode, sequenced order) and `02-walk-10-detail-restored` (edit mode, order restored to sequenced) are the same screen by construction — Restore's whole job is to return to state 8 — so the walk photographs **14 materially distinct states, not 15**. Measured three times: byte-identical (`md5 d55b41d7…`) on one run, and differing only in a 1×1 antialiased pixel and a 41×92 px toolbar-material patch on the other two. Not a rendering bug; a coverage-accounting one, and it matters because Phase 4's ship criterion is "screenshot count equals screen count". Restore's *effect* is legible only by comparing `02-walk-09` to `02-walk-10`, never from `02-walk-10` alone. | **CLOSED 2026-08-30 (plan 04-01), by a command rather than by a person noticing.** `python3 Scripts/screenshot-audit.py` prints `crate walk: 15 files, 1 declared pair, 14 distinct states` — measured four times (three by 04-01, once again by 04-04) — and the pair is a `DECLARED_DUPLICATES` entry of kind `IDENTICAL`, which is the only kind that collapses the state count, so a NEW duplicate cannot be absorbed silently. Control NC-2 planted one and Gate B reddened naming both frames. Evidence: `02-walk-08-detail-edit-mode.png`, `02-walk-10-detail-restored.png`, commit `726d833`. | Informational | Closed |
| V15 | **The correction field truncates a long track line and gives no way to read the rest without tapping into it.** `EXCLUSIVE NEW MIXES FROM V CLASSIC THE ALBUM` (44 characters, the corpus's longest **trusted** read) renders as `EXCLUSIVE NEW MIXES FR…` in a 237.3 pt single-line `TextField`. The value is intact — XCUITest reads all 44 characters back off the field — so nothing is lost, but roughly half of the longest lines a DJ has to correct are invisible at rest. The raw list below does not have this problem (see V13's closure), so the same string is fully readable eleven rows further down the same sheet. | `03-walk-05-inspect-sheet.png`, line 4. **ADJUDICATED 2026-08-30 (plan 04-04): CARRIED, owner Phase 6** — blocked on U9 and superseded in the same direction, because SEG-03's filter drops the fragments that make the longest lines long. | Low | CLOSED — Phase 8 |
| V16 | **The over-split draft contains exact duplicate lines.** IMG_0505's eleven-line draft carries `SIMON BASSLINE SMITH` **twice** — the OCR read the same text off two surfaces of one sleeve, and D-03-4's one-line-per-trusted-observation rule keeps both. IMG_0503 shows the near-miss version: `Timeless Recordings` / `TimelessRecordings` and `Cause 4 Concern-` / `Cause 4 Concern`. A person correcting this sheet has to delete lines they cannot tell apart from the ones they are keeping. This is the deliberate cost of not segmenting in Act I, made visible — de-duplication is SEG-03's filtering and belongs to Phase 6. | `03-walk-06-inspect-raw-text.png` (lines 2 and 5 both `SIMON BASSLINE SMITH`); `03-04-sheet-lines.png` (lines 8/9 and 2/10) | Low | CLOSED — Phase 8 |
| V11 | **Add More opens a capture screen that says "0 records" for a crate that already holds four.** The session count is scoped to the visit, which is CAP-03's own wording ("scanned so far in this session") and decision D-03-3, so it is behaving as designed — recorded as informational so a reviewer looking at the picture is not surprised, and so the owner can say whether they would rather see the crate's total. | `02-walk-11-add-more-capture.png` (Friday Warehouse, 4 records in the crate, "0 records" on the strip). **ADJUDICATED 2026-08-30 (plan 04-04): CARRIED, owner Phase 4 / U11** — filed as U11 by this plan, because the row had sat informational with no mechanism to ever get answered. | Informational | CARRIED — Phase 4 / U11 |
| V17 | **The crate walk does not reproduce the same screen STATES run to run.** On 1 of 7 known runs, `02-walk-09-detail-manual-order.png` and `02-walk-10-detail-restored.png` were captured **outside** edit mode — no delete circles, no drag handles, `Edit` in the toolbar instead of `Done` — so frame 10 photographed **state 7, not state 8**, against byte-identical code (`App/`, `UITests/`, `project.yml` unchanged since `bd925ea`). Not a regression and not a rendering bug: non-determinism in the walk itself. **Found by plan 04-01 (Finding 3) and handed to the ledger; filed here by plan 04-04.** | Gate B of `Scripts/screenshot-audit.py` reddened on it and named the pair (`02-walk-07` vs `02-walk-10`, fraction 0.000154, 0 differing pixels below y=150), rc=1. Two independent measurements localise it to the same two frames: pixel diff (**17.6%** against 0.015%) and per-frame mean drift (**0.2266** and **0.2026** against the stated ±0.06 bar, with **0** frames over that bar between two normal runs). **ADJUDICATED 2026-08-30 (plan 04-04): CARRIED, owner Phase 11.** One anomalous observation is not a rate and is not reported as one. | Low | CARRIED — Phase 11 |
| ~~V18~~ | ~~**A drag that reorders nothing still puts the crate into "Custom order", and the walk's CRATE-04 assertion cannot see the difference.**~~ | **FIXED AND CLOSED 2026-08-30 (plan 04-06).** See "V18 — closed, with evidence" below, which carries both halves of the route. **Back to the defect:** delete the line `guard order != ids else { return }` from `CrateDetailModel.moveRows` and `ManualOrderTests.swift` reddens with 4 expectations — measured, `rc=1`. **To the fix:** commit `a20a43d` (the guard), `d658e3e` (the assertions that were missing), `fbcf12c` (the walk measures row order, not button presence). **Photograph:** `02-walk-09-detail-manual-order.png`, regenerated on three clean runs, reads `1 Photek — Ni Ten Ichi Ryu` / `2 Source Direct — Snake Style` under `Custom order` — the swap, not the sequenced order. `test_givenAnOutOfRangeMove_whenApplied_thenNothingTraps` and `test_givenAManualOrder_whenARowIsMovedOntoItsOwnIndex_thenTheExistingOrderIsPreserved` assert both directions. **Gate S3 now rc=0 on 3 of 3 runs.** | — | Closed |
| V22 | **V19's root cause survives in `vinylctl`.** The excluded row prints `Cause 4 Concern — High Down  160`, but High Down measured **116.1** — 160 is *Strange Nature*. Name from one candidate, tempo from another. Phase 9 fixed exactly this in the app by binding badges/reason/edit to one candidate via `NotIncludedRow.trackID`; `vinylctl` is a separate front end and never received it. | `Artifacts/vinylctl/sequence-baseline.txt` — the record block lists `High Down [116.1]` and `Strange Nature [160]`; the excluded table merges them | **Medium** | next milestone |
| V23 | **The sequencer's objective has no notion of which cluster a DJ wants.** On the live twelve it chose `136 → 138.8` and excluded `174.8` and `175` — which are **0.2 BPM apart**, the best transition available in the whole crate. Both are valid two-record sets, so maximise-count ties and the Camelot tie-break cannot separate them (neither pair has two known keys). The tie is broken arbitrarily. | `Artifacts/vinylctl/sequence-baseline.txt` — set is 136/138.8; `Drumsound 174.8` and `Vinyl 3 175` both excluded | **Medium** | owner decision |

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

**SUPERSEDED IN ONE RESPECT, 2026-08-30 by plan 04-03.** Everything above about the settle delay
and `.disabled(true)` stands. The closing sentence's suspicion — "once the walk has swapped
`RootView`'s content through several `Route` cases in one long session" — is *nearly* right and
was still not testable as written: it is not several swaps, it is **the first one**, and only when
that first one is driven from inside the new-crate sheet's `Create`. Route swaps by themselves are
harmless, measured seven ways. See "V9 — the rule was wrong, and here is the right one" above.

---

## A tooling hazard found while measuring V9, worth more than the frame it was found on

`./Scripts/ui-test.sh -only-testing:…` **exited 0 having run zero tests**, twice, both times on the
first invocation after a UI-test source file was edited: `xcodebuild` reported
`Test Suite 'VinylSetBuilderUITests.xctest' passed` with no test cases in it, and
`build/ui.xcresult` confirmed `passedTests 0, failedTests 0, totalTestCount 0`. Re-running the
identical command immediately afterwards ran the tests normally.

`Scripts/screenshots.sh` is already immune — it asserts `passed > 0` before it will collect. A bare
`ui-test.sh` is not. **A green exit code from `ui-test.sh` is not evidence that anything ran**;
read `passedTests` out of the result bundle and compare it to the number you expected, which is
what gate G2 in `Scripts/hygiene.sh` already does for the Core suite and for the same reason.

Both zero-test runs are also the reason the V9 probe harness purges `zz-v9-*.png` from every
simulator container before each run: the runner's data container is **not** always fresh per
`xcodebuild test` — one container was observed accumulating four separate runs' output — so a
stale frame from the previous hypothesis reads exactly like the current one's evidence.

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
`02-walk-09` and `02-walk-10` ("Vinyl 2" / "Vinyl 4" after plan 04-03's V5 fix renumbered the
second row; "Vinyl 2" / "Vinyl 3" before it). The second sighting is carried to plan
03-05, which owns the full twelve-fixture walk and can expand the bucket without touching Phase
2's file. A row without a named screenshot is an opinion, not a defect — so it is not being
written as one.

---

## V4 — closed, and what the plan's own gate could not see

**Measured twice on independently captured runs, each time by two independent implementations**
— an in-test luminance histogram in `UITests/BadgeContrastUITests.swift` and
`python3 Scripts/probe-frames.py --ink 128` on the host, over the same element-screenshot PNGs.
Both return the same integers, so neither is only checking itself.

| | contrast (mode − min) | WCAG 2.2 ratio |
|---|---|---|
| placeholder, before | 125 | 4.01:1 |
| placeholder, after | **167** | **7.96:1** |
| complete, before | 245 | 19.30:1 |
| complete, after | 239 | 18.27:1 |

**The fix.** `.background(.thinMaterial, in: Capsule())` → `Color(uiColor: .tertiarySystemFill)`,
and `.secondary` → `.primary.opacity(0.7)` for the incomplete style. Same "solid ground, not
translucent material" move plan 03-03 made for the capture strip's status pill; no third badge
idiom was invented, and no colour crossed into Core (D8 holds — `TrackBadges.placeholder` is
untouched).

**The part worth writing down: 04-03-PLAN.md's own gate could not have caught this.** The plan
fixed `contrast = mode − min ≥ 60` in advance, as a legibility floor, and forbade re-fitting it.
Measured on the *defective* badge it came back **125** — over the floor by a factor of two. That
threshold was kept exactly where it was set, and it is reported for what it is: a gate that never
went red on the defect it was written for. What reddens is WCAG 2.2 §1.4.3 AA at 4.5:1, whose
number comes from the published standard rather than from this repo's data and would read the
same if no badge had ever been measured here.

Both halves of SEQ-11 are provably able to fail, each at its own named line, each confirmed from
`build/ui.xcresult`'s failed-test list as well as from the log:

| Mutation | Expected to redden | What happened |
|---|---|---|
| `.thinMaterial` + `.secondary` restored | the legibility half | `BadgeContrastUITests.swift:143` — "reads at 4.01:1 … below WCAG 2.2 AA's 4.5:1". xcresult `passed 0 / failed 1`. The `≥ 60` assertion stayed GREEN at 125 throughout, which is the evidence for the paragraph above. |
| incomplete style set to `.primary` (dimming removed) | the *dimmed* half | `BadgeContrastUITests.swift:122` — "the complete badge pair's contrast (239) is not strictly greater than the placeholder's (239)". xcresult `passed 0 / failed 1`. |

---

## V9 — the rule was wrong, and here is the right one

The rule this row carried for two phases was: *presenting and dismissing a `.sheet` removes the
large navigation title for the rest of the session.* It was inferred from a 33-frame split, never
reproduced deliberately. Plan 04-03 reproduced it deliberately for the first time, on a two-frame
test, and **it did not reproduce**.

**Step 1 — the band, calibrated before it was trusted.** Derived once from
`02-walk-01-crate-list.png` by row-profiling the dark pixels between the status bar and the first
list row, then held fixed: **`--region 0,383,1206,74 --ink 128`**. The two dark runs in that area
are the `+` toolbar glyph (rows 226–278, x 1065–1117) and the title `Crates` (rows 383–456,
x 52–359); the band excludes the button on purpose, which is what makes ink 0 mean *no title*
rather than *no toolbar*. Calibration against known values:

| Frame | recorded previously | measured here |
|---|---|---|
| `02-walk-01-crate-list.png` | ~9498 | **9677**, and identically on two independently captured copies of that frame (the pre-regeneration file and the regenerated one), so the number is a property of the screen, not of the run |
| `03-03-capture-empty.png` | 11753 | **11746** (Δ7, 0.06%) |
| any title-less frame | 0 | **0** |

The 9498 → 9677 gap is 1.9% and comes from a capture that is no longer on disk; it is recorded
rather than tuned away, because moving the band to hit 9498 would be fitting the instrument to
the number.

**Step 2 — the deliberate repro, which failed.** launch → capture → present `NewCrateSheet` →
**Cancel** → capture. Expected 9677 → 0. Got **9677 → 9677, and the two PNGs were byte-identical
(same md5)**. Presenting and dismissing the sheet does nothing.

**Step 3 — bisecting the whole walk route in one session**, seven captures: launch list 9677 ·
after Cancel 9677 · crate detail 26230 · list again 9677 · capture after **Create** 11746 ·
detail after Create 17050 · list after Create 9677. Every frame keeps its title. So neither the
sheet, nor Create, nor route switching is sufficient.

**Step 4 — the A/B that isolates it.** Two app sessions differing in exactly one thing:

| Session | Route taken | Title band ink |
|---|---|---|
| A | launch → new-crate sheet → type → **Create** → capture | **0** |
| B | launch → crate detail → back → new-crate sheet → type → **Create** → capture | **11746** |

**The corrected rule: the navigation title is lost for the rest of the session if and only if the
FIRST `Route` change of the session is the one driven from inside the sheet's `Create`. Insert any
prior route change and the identical Create keeps every title.** That A/B reproduced identically
on **four independent runs** (the baseline and the three hypothesis runs below).

It also explains the whole 33-frame split without the sheet being the cause:
`CaptureWalkUITests` test 1 enters capture through Create-first and its five frames read 0, while
test 2 enters through **Add More** and its two frames read 11746 — same file, same class, same
build, two sessions. `CaptureScreenUITests` also enters through Add More, and all four
`03-03-capture-*` frames have their title.

**Three hypotheses, each rejected by measurement.** A rejected hypothesis with a number is the
point of the exercise; Phase 11 should not spend its budget on these again.

| # | Hypothesis | Change made | A / B ink | Verdict |
|---|---|---|---|---|
| H3 | SwiftUI's inline/large inference latches after a presentation | `.navigationBarTitleDisplayMode(.large)` on the `NavigationStack`'s content | **0 / 11746** | **REJECTED** — unchanged |
| H1 | view identity churn: `.navigationTitle` is re-applied to a new `_ConditionalContent` branch on every route swap | hoisted to ONE `.navigationTitle(title)` on the stack's content, driven by `model.store.route`; removed from all three screens | **0 / 11746** | **REJECTED** — unchanged. The title's application site is not the variable. |
| H2 | the sheet's own nested navigation container takes over title rendering | deleted `NewCrateSheet`'s `NavigationStack`, moved Cancel/Create into `Form` rows | **0 / 11746** | **REJECTED** — unchanged |

All three were reverted; the working tree carries none of them.

**Carried to Phase 11**, because Phase 11's criterion 2 re-runs the Phase 2 and Phase 3 walks and
regenerates the whole screenshot set after each of five stub swaps, so `RootView`'s navigation is
opened and re-verified there five times — and because what is left after H1, H2 and H3 is the
navigation *bar's* own large-title state at the moment of the first root swap, which is a UIKit
bridging question rather than a modifier-placement one, and is worth opening once with the
navigation code already in hand rather than twice.

**Repro for Phase 11, one command:** measure `--region 0,383,1206,74 --ink 128` on any frame from
a session whose first navigation was the new-crate sheet's Create. Expect 0. Do a single crate-row
tap and back first, and the same screen measures 11746.

**Measurement count: seven UI runs** — one two-frame repro, one seven-frame bisection, one A/B
baseline, three hypothesis A/Bs, and one re-run after a stale test enumeration (see below).

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

---

## V18 — closed, with evidence

**The row that refused Act I.** Both halves of the route are below: a way back to the defect,
and a way to the fix. Neither is prose — each is a command.

### The mutation, and the assertion it reddens

Delete one line from `CrateDetailModel.moveRows`:

```swift
        let order = Self.moved(ids, fromOffsets: fromOffsets, toOffset: toOffset)
        guard order != ids else { return }        // <- delete this line
```

`./Scripts/test.sh` then reddens with **4 expectations**, measured, `rc=1`:

```
✘ ManualOrderTests.swift:185: (single.crate.manualOrder → [B37DD671-…]) == nil
✘ ManualOrderTests.swift:186: (single.orderingMode → .manual) == .sequenced
✘ ManualOrderTests.swift:202: (ladder.crate.manualOrder → [2EA47038-…, CB173352-…, 80D5A8FF-…]) == nil
✘ ManualOrderTests.swift:203: (ladder.orderingMode → .manual) == .sequenced
```

The **other** direction has its own mutation, because a guard that *cleared* the override on a
no-op would satisfy every assertion above and silently throw a user's arrangement away.
Replace the guard with `if order == ids { crate.manualOrder = nil; rebuildRows(); return }` and
`test_givenAManualOrder_whenARowIsMovedOntoItsOwnIndex_thenTheExistingOrderIsPreserved` reddens
with **3 expectations**, `rc=1`. Both mutations were run and both were reverted.

### The fix

`CrateDetailModel.moveRows` computes the order the move would produce, compares it with the
order already displayed, and returns without touching `crate.manualOrder` when they are equal.
One guard, in the one function every caller routes through — `CrateDetailView`'s `.onMove` is
the only call site, and it goes through this function. Commit **`a20a43d`**; the assertions are
**`d658e3e`**.

### The presence check is gone

`reorderTookEffect()` asked whether `restore-sequenced-order-button` **exists**. It now polls
`sequencedRowLabels()` for a genuine **permutation** — same rows, different order — with the
same 3s timeout, so it still doubles as the reorder animation's settle. Commit **`fbcf12c`**.

Three controls run **in band on every walk**, so the comparator cannot quietly stop working:

| Control | Assertion | Why |
|---|---|---|
| negative | `isReorder(before, before)` is **false** | a comparator that calls a list a permutation of itself cannot fail |
| positive | `isReorder(before, reversed(before))` is **true** | …and one that never returns true cannot succeed |
| structural | `rowIdentities(before) != before` | the position strip actually fires — otherwise the check compares positions, not rows |

**Two things were measured while writing that check, and both were surprises.**

1. **Recipe 1 does not reliably reorder.** Across the **8** walk runs made with the corrected
   comparator, recipe 1 (press-and-drag, edit mode ON) genuinely reordered **3** times and
   failed **5**; recipe 2 (edit mode OFF) picked up all five. Every green run through the old
   presence check was recipe 1 "succeeding" on the identity move it had just committed — the
   old check could not tell the two apart, and printed `WALK DRAG RECIPE FIRED: 1` for both.
   That is V18's mechanism, observed directly rather than inferred. (A ninth run, made with the
   broken first version of the comparator, is excluded: it fired every recipe and cannot be
   attributed.)
2. **The first version of the row-order check was itself blind.** A row's label leads with its
   *position* (`"1, Source Direct — Snake Style, 170, 5A"`), and `indexLabel` renumbers 1…N
   after every move — so a real swap changes the text of every label and a multiset comparison
   of raw labels sees two disjoint sets. Measured: the walk fired all four recipes, swapped a
   two-row list four times, and reported `recipe: none` over a committed manual order.
   `rowIdentities()` strips the position (and edit mode's leading `Remove`), and the structural
   control above exists so that strip cannot silently stop firing.

### A second defect, found because V18's fix let other recipes win

The four drag recipes run in **different edit modes**, and the first to fire wins. With recipe 1
always "succeeding" the list was always left in edit mode; once it could lose, the state
photographed as frames 9 and 10 began to follow the gesture routing. Measured on S3 series-A
run 3: recipe 2 won, and `02-walk-10-detail-restored.png` came back **byte-identical** to
`02-walk-07-not-included-expanded.png` — **0** differing pixels, fraction 0.000000 — while the
declared `08/10` pair went stale. `screenshots.sh` exited **1**.

This is not V18 and is not filed as a new row: it was introduced and closed inside this plan.
The walk now normalises to edit mode ON after the drag loop, which is the state frame 8
establishes and the state the committed 9/10 pair was photographed in. Commit **`3efc975`**.
Series B then ran three times with recipes **2, 1, 2** — both branches exercised — and all
three were rc=0.

### The photograph

`02-walk-09-detail-manual-order.png`, regenerated from a purged host on three clean runs, reads
`Custom order` + `Restore` over rows **`1 Photek — Ni Ten Ichi Ryu`** / **`2 Source Direct —
Snake Style`**: the swap. The `02-walk-08` vs `02-walk-09` pair measures **31,273 px /
0.009890** — 04-05's recorded figure for the correct state. The defect measured **9,131 px /
0.002888** and reddened gate B. It did not reproduce on any of the three runs.

Every one of the 34 regenerated PNGs is **content-identical** to the committed set below
y=150 — 0 differing pixels each, measured by `probe-frames.py --drift`. Only the status-bar
clock moved.

### And the instrument that saw nothing

Per-frame **mean** drift measured 0.0346 on the defective frame — inside the ±0.06 bar — while
22,142 content pixels had changed, because a mean cannot see a permutation. `--drift` now
reports the mean delta **and** the differing-pixel count below y=150 and fails if either is
breached. Its negative control is a synthetic permutation built in `--selftest`: identical
means (`mean_delta=0.0`, `mean_ok=True`) with `content_px=20000`, `content_ok=False`. Commit
**`009ff13`**. The ±0.06 mean bar must never again be quoted on its own.

---


---

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| V19 | **The not-included bucket reports the wrong exclusion reason.** A row showing a resolved BPM *and* key still reads `"no SoundCloud upload matched"` — but it plainly matched, or those badges could not exist. The row is excluded because its tempo is outside the set's window; the reason names the last ladder rung touched instead of the actual cause. | `Artifacts/screenshots/03-walk-07-done-sequenced.png` — `The Accidental Heroes — Dragstar   136  4B` with `no SoundCloud upload matched`, and `Cause 4 Concern  160` below it, against a set running 169.9–175 | **Medium** | Phase 9 |
| V21 | **A record whose sleeve yields no track line is silently dropped — it appears in neither the running order nor the not-included bucket.** `IMG_0507.HEIC` reads three price-sticker fragments (`cemenic`, `DrumBass`, `$ 10.003`), none of which SEG-03 keeps, so it segments to zero candidates. Twelve photographs went in and the crate accounted for eleven. **Directly contradicts RES-01**, whose whole wording is that a record is never silently dropped. | `Artifacts/vinylctl/sequence-baseline.txt` — the pre-fix run printed `The set — 2 records` above `Not in the set (9)` for twelve photographs; the committed post-fix baseline reads `Not in the set (10)`. Independently visible in the app: `build/app-crosscheck.log` shows `Not in the set (11)` beside one sequenced row, which is twelve. | **Medium** | **CLOSED — Phase 10, 2026-08-30.** Fixed in `CrateRows.make`, the one place a `SequenceResult` is projected against its crate. Commit `e13633d`. |

## Why V19 matters more than it looks

The per-row reason is the entire justification for the one-bucket design (SEQ-07). Two sections
were collapsed into one *specifically* because the reason string was said to carry the
distinction. If the reason is wrong, the bucket is just an undifferentiated pile and the design
decision loses its basis.

Concretely, the DJ cannot tell these apart:
- **"I could not identify this record"** → go and enter it by hand
- **"I identified it fine, it just does not fit this set"** → nothing to do, or widen the tolerance

Those demand opposite responses.

## The fix

Exclusion reason must be derived from the **terminal** state, not the last rung visited.
Precedence, most specific first:

1. no BPM at all → `"No BPM yet — resolve it or enter it by hand"`
2. BPM present but outside the window → `"No track within {N} BPM of the set"`
3. identity never resolved → `"No identity to look up"`
4. identity resolved, no audio found → `"No SoundCloud upload matched"`

A row that has a BPM can never legitimately show reason 3 or 4. **Assert that invariant** —
`bpm != nil` implies the reason is 2 — so this cannot regress silently.

**V19 is CLOSED by Phase 9.** Fix in `CrateRows.reason`, one test per row of the precedence
table in `ExclusionReasonTests.swift`, and the invariant asserted inside `CrateRows.make`.

The closing evidence is the **same frame this row was filed against**, regenerated from the same
live twelve-record run. `03-walk-07-done-sequenced.png` now reads:

| Row | Badges | Reason |
|---|---|---|
| The Accidental Heroes — Dragstar | `136` `4B` | *No track within 4 BPM of the set* |
| Cause 4 Concern — High Down | `160` `—` | *No track within 4 BPM of the set* |
| Vinyl 1 | `—` `—` | *No SoundCloud upload matched* |
| Vinyl 5 | `—` `—` | *No identity to look up* |

Three of the four terminal causes, distinguished in one frame, on the owner's own photographs.
Every row carrying a BPM badge names the tempo window and no row without one does — which is the
invariant, holding on real data rather than only on fixtures. `09-manual-03-bucket-expanded.png`
shows the same on the fixture crate. Commit `760f386`.

**And V19 exposed a gap in this ledger's own gate.** It was filed BELOW the machine-readable
section, and `Scripts/ledger-check.py` parses the human table only from the text ABOVE that
heading — so gate G9 reported "18 rows" and was structurally blind to the nineteenth. The block
above is where every human row now lives, and V19 and V20 are in the machine-readable block, so
G9 counts them.

---

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| V20 | **The hand-entry sheet leaves roughly half the screen empty.** Every control sits in the top 1100 px of a 2622 px sheet; below the Title field there is nothing. Filed as an observation rather than a fault: a full-height sheet with its content at the top is ordinary iOS, the alternative (`.presentationDetents`) either hides the identity fields at `.medium` or needs a content-fitted height that is fiddly for no measured benefit, and MAN-01's interaction count — the thing that actually matters here — is unaffected by the whitespace. | `Artifacts/screenshots/09-manual-04-sheet-from-bucket.png` | **Informational** | Phase 14 |


## Ledger — machine-readable

Regenerated by adjudication (plan 04-04, 2026-08-30), checked by `Scripts/ledger-check.py`,
which runs as gate **G9** of `Scripts/hygiene.sh`. One row per defect, pipe-separated, in this
exact column order. **Do not hand-edit without re-running the checker.**

```
ID | SEVERITY | STATUS | OWNER | EVIDENCE_OR_REASON
```

**23 rows: 14 closed, 9 carried, of which 3 are Medium or above.** Derived from the block below by `Scripts/ledger-check.py`, which re-derives it on every run and fails if this line disagrees — not typed.

### The rules this block is written to, and the checker enforces

1. `STATUS` is exactly `CLOSED` or `CARRIED`. There is no third state — a row that is neither
   is the thing S7 exists to forbid.
2. A `CLOSED` row's `EVIDENCE_OR_REASON` must carry a **re-runnable evidence path**: a `.png`
   basename, a `…Tests.swift` / `test_…` name, a 7+ character commit SHA, or the literal token
   `NOT-A-DEFECT`. The word "Fixed" is not evidence.
3. Any row citing a `.png` must cite one that **exists in `Artifacts/screenshots/`**. A row
   pointing at a frame a later regeneration renamed or dropped has a decorative evidence path,
   not a re-runnable one.
4. A `CARRIED` row's `OWNER` must name a phase (`Phase N`), and may additionally name a U-item
   (`Phase 4 / U8`). The named phase must be one that genuinely re-opens the artefact — see the
   owner audit below.
5. A `CARRIED` row's `EVIDENCE_OR_REASON` must be a **reason**, not a restatement of the defect.
   "Still open" is not a reason.
6. `SEVERITY` is one of `Medium`, `Low`, `Informational`, or `—`.

### What `—` means in the SEVERITY column

`—` means **no severity was ever recorded for this row while it was open** (V1, V7, V8, V13),
or **it was never a defect** (V2). It does not mean "trivial". V4 and V5 carried `Low` while
open — recovered from `git show e7c1c23~1` rather than left as the `—` their closure wrote into
the human table above, so the two tables agree.

### How a CLOSED row evidences itself — the rule, and why it changed

Plan 04-01 found that **V1's row cited two frames that both show the *fixed* text**: the one
frame that showed the defect (`sim-settled-crate-list.png`, reading `1 records`) was an
uncited orphan and was deleted. A closed defect that cites no route back to the defect cannot
be re-checked by anyone who was not there.

**The rule, applied to every closed row in this block:** a `CLOSED` row cites **both halves** —
a re-runnable route to the **defect** (a surviving photograph of it, *or* a named mutation that
restores it and reddens a named assertion), **and** a route to the **fix** (a photograph of the
current state, a test, or a commit).

Two rows are exempt and say so in their own text, because there is no defect to route back to:

- **rows closed by assessment rather than by a fix** — V13 (a "not assessable" question that
  was measured) and V14 (a coverage-accounting question that is now produced by a command);
- **V2**, which was never a defect at all and carries the literal token `NOT-A-DEFECT`.

Applying the rule recovered a photograph for two rows that had none:

| Row | Photograph of the defect, on disk | Verified how |
|---|---|---|
| V1 | `01-06-crate-list.png` — reads `Sunday Chill — 1 records` | opened at 1206×2622 and read directly by this plan; independently confirmed by plan 04-01 before it deleted the orphan. **2 observations** |
| V8 | `02-03-capture-stub.png` — reads `Camera arrives in Phase 3` | opened at 1206×2622 and read directly by this plan. **1 observation** — it is a static committed file, not a behaviour |

### The owner audit — every carry checked against the roadmap before it was written

D-04-3: a carry to a phase that never re-opens the artefact is an abandonment wearing a due
date. Each owner below was checked against `.planning/ROADMAP.md` §"Phase Details", not assumed.

| Owner | Rows | Does that phase re-open the artefact? |
|---|---|---|
| Phase 4 / U8 | V3 | **Yes** — blocked on the owner, not on code. The U-number *is* the mechanism, and U8 is filed and open. |
| Phase 4 / U11 | V11 | **Yes** — same shape as U8; U11 filed by this plan. |
| Phase 6 | V12, V15, V16 | **Yes** — success criterion 2 names the currency/decimal filter (`$10.00`, `6.00€`) and criterion 5 the trusted-tier filter. SEG-01…06/08 rewrite the exact stage that produces `Zzz.`, the duplicate lines and the long fragments. |
| Phase 10 | V10 | **Yes** — CAP-01/04 put a real `AVCaptureSession` behind the capture screen, which is what turns the flexible black rectangle the guide is pinned to into a fixed-aspect camera layer. |
| Phase 11 | V6, V9, V17 | **Yes** — criterion 2 re-runs the Phase 2 and Phase 3 walks and regenerates the whole screenshot set after **each of five** swaps, and the ship criterion runs the app end to end on the 12 real photographs. That is five more independent observations of the walk (V9, V17) and the first real sequence long enough to test a double-digit index (V6). |

**One honest caveat on V6.** Phase 11's ship criterion reports "length of the resulting
sequence" over 12 real records; it does not *guarantee* ten or more sequenced rows. If that run
still produces fewer than ten, V6 stays not-assessable and must be **re-carried, not closed**.
That is written into V6's own reason so the next reader inherits the condition rather than the
conclusion.

### The rows

```
V1 | — | CLOSED | Closed | defect photographed in 01-06-crate-list.png (reads "1 records"); fix photographed in 02-walk-01-crate-list.png (reads "1 record"); the assertion is two-sided in CrateWalkUITests.swift step 1 so it can fail in either direction; fix commit c81805d
V2 | — | CLOSED | Closed | NOT-A-DEFECT — the pallor was the launch fade, not styling. Re-confirmed on 33 frames across three runs by Scripts/probe-frames.py (min=0 and max=255 on every frame) and disproved functionally as well as photometrically, because disabled content is not tappable and the walk taps through to state 15
V3 | Medium | CARRIED | Phase 10 / U8 | Blocked on U8, unanswered. Two fixes are defensible and choosing between them is a product call about the owner's own workflow (D-04-1). Fix A gives VinylEntry.label the first-candidate Track.displayName fallback that SequencedRow.title already has. Fix B marks the fixture tracks .resolved. They are NOT equivalent in side effects — B would move Phase 3's measured 6 Read / 5 Partial / 1 Unread strip tally, which is a committed baseline, and A would not. That asymmetry is recorded as evidence FOR U8 and is explicitly not a licence to choose for the owner. Twice-evidenced on screens a phase apart: 02-walk-07-not-included-expanded.png and 03-walk-07-done-sequenced.png **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V4 | Low | CLOSED | Closed | defect route: restoring .thinMaterial plus .secondary reddens BadgeContrastUITests.swift:143 at 4.01:1, under WCAG 2.2 AA's 4.5:1 for 12pt text; fix measured at 7.96:1 with the complete pair still strictly ahead at 18.27:1, so SEQ-11's dimmed-never-hidden holds on both halves; fix photographed in 04-badge-placeholder.png and 04-badge-complete.png; fix commit 4f32f04
V5 | Low | CLOSED | Closed | defect route: restoring position 2 reddens FixtureCratesTests.swift twice, the label assertion naming Vinyl 3 and the position assertion naming 2; fix visible in 02-walk-07-not-included-expanded.png, which reads Vinyl 2 and Vinyl 4 where it read Vinyl 2 and Vinyl 3; uniqueness is asserted across every crate FixtureCrates.all exposes and demoStore is built from that same list; fix commit 4b8e2f8
V6 | Low | CARRIED | Phase 10 / U12 | RE-CARRIED on its own written condition, which was met exactly as feared. The condition was: if the end-to-end run's sequence is still shorter than ten rows, this row stays not-assessable. Phase 8 ran the whole pipeline live on the twelve photographs twice and the running order came out at THREE rows both times (172 / 174.8 / 175) with nine records not in the set — 03-walk-07-done-sequenced.png. Nine of the twelve are white labels and dubplates absent from every database, so a ten-row set is not reachable from this crate at all and no amount of wiring will make it so. Closing it needs either a larger crate of the owner's records or a deliberate ten-row fixture, and manufacturing the latter to satisfy an index-alignment question remains the wrong trade **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V7 | — | CLOSED | Closed | fix photographed in 02-walk-05-new-crate-detail.png, which shows "Nothing sequenced yet" above "Not in the set (1)"; defect route: mutation D, giving every fixture track bpm 174, reddens CrateWalkUITests.swift:122 with "the new crate shows neither a running order nor the empty-order placeholder"; the assertion is two-sided (empty-order present AND sequenced-row-1 absent); fix commit bb8ff60
V8 | — | CLOSED | Closed | defect photographed in 02-03-capture-stub.png, which still reads "Camera arrives in Phase 3" and was opened and read directly by this plan; fix photographed in 02-walk-03-capture-empty.png and 03-03-capture-empty.png, where CapturePlaceholderView no longer exists and RootView routes .capture to the real CaptureView; fix commit cdb166b
V9 | Low | CARRIED | Phase 10 / U12 | RE-CARRIED unexamined, and said plainly rather than dressed up: Phase 8's scope was the four stub swaps and the camera, and the screenshot re-capture path was not touched by any of them. The disproof this row already records still stands — present the sheet, cancel, re-capture gave 9677 to 9677 with the two PNGs byte-identical — so nothing measured in Phase 8 changes its content. It is re-carried at the same severity with no new evidence and no new claim **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V10 | Low | CARRIED | Phase 10 / U10 | RE-CARRIED, and the premise it was carried on is now only half true. The expectation was that the camera phase would replace the flexible black rectangle with a real AVCaptureSession preview layer, giving the reticle a fixed-aspect container to pin to. Phase 8 built the AVCaptureSession (App/Capture/SleeveCamera.swift) but deliberately added NO AVCaptureVideoPreviewLayer: the only machine that can verify this project has no camera, so a preview layer would be unverifiable code drawn on an empty buffer, and the fixture path renders nothing to preview. The arithmetic remains correct — edgeCoverage holds — and the container is still a flexible box that the inline flip banner shrinks. This closes on the first phase that runs on the physical iPhone, alongside UAT U2b **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V11 | Informational | CARRIED | Phase 10 / U11 | Behaving as designed: the count is scoped to the visit per CAP-03's own wording, "scanned so far in this session", and decision D-03-3. Every automated measurement can confirm the number 0 is correct for the session; none can say 0 is the right number to SHOW a DJ looking at a four-record crate. That makes it a taste call about the owner's workflow, identical in kind to U8, and it had been sitting informational with no mechanism to ever get answered — so this plan filed it as U11. An unanswered U11 blocks nothing, because Phase 11 re-photographs the screen after every swap regardless. Evidence unchanged and confirmed twice: 02-walk-11-add-more-capture.png **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V12 | Medium | CLOSED | Closed | defect photographed in the PREVIOUS 03-04-sheet-lines.png (title bar reads Zzz.) and independently in FixtureObservations.swift:205, IMG_0503's first trusted observation; fix photographed in the regenerated 03-04-sheet-lines.png, whose title bar now reads Cause 4 Concern-; defect route back: test_givenAFixtureWhoseFirstTrustedReadIsASticker_whenNamed_thenItSkipsIt reddens if displayLabel stops filtering, and test_givenTheTwelveFixtures_whenNamed_thenNoNameIsFilteredNoise covers all twelve rather than the one; two independent rules reach Zzz. (a four-alphanumeric floor and the trebled-character rule) so removing either does not reopen it; IMG_0508 moved too, $10.007 to Da Lick; fix commit f980c1a
V13 | — | CLOSED | Closed | closed by assessment rather than by a fix, so there is no defect to route back to. Both halves measured, identically on three runs: the 44-character trusted read truncates in a 237.33pt single-line field (03-walk-05-inspect-sheet.png) while the value stays intact, and the 106-character read wraps to four rendered lines, 70.75pt against a 19.33pt one-line control (03-walk-06-inspect-raw-text.png). The walk asserts height greater than 1.5 times one line, so a future lineLimit(1) would redden it. The truncation half was filed onward as V15 and the identical-lines half as V16; commit e186a3d
V14 | Informational | CLOSED | Closed | closed by accounting rather than by a fix, and by a command rather than by a person noticing: Scripts/screenshot-audit.py prints "crate walk: 15 files, 1 declared pair, 14 distinct states", measured four times (three by plan 04-01, once again by this plan). The pair 02-walk-08-detail-edit-mode.png and 02-walk-10-detail-restored.png is a DECLARED_DUPLICATES entry of kind IDENTICAL, and only IDENTICAL collapses the state count, so a NEW duplicate cannot be absorbed silently — control NC-2 planted one and Gate B reddened naming both frames; commit 726d833
V15 | Low | CLOSED | Closed | CLOSED by Phase 8's swap 1, and the premise it was carried on was measured FALSE on the way. The reason for handing it to Phase 6 was that SEG-03's filter would shorten the long lines; AngleClusterSegmenter JOINS a cluster's readings into one track line, so the corpus's longest draft line grew from 44 characters to 57 on the recorded observations and reads 63 live. First fix attempt failed and is recorded: axis: .vertical with .textFieldStyle(.roundedBorder) still capped growth at two lines — the 29-character control and the 57-character line both rendered at exactly 44.00000000000003pt, measured. Dropping the rounded-border style and adding lineLimit(1...10) is the fix. Fix photographed in 03-walk-05-inspect-sheet.png and asserted in CaptureWalkUITests.swift by test_givenTwelveFixturePhotographs_whenShotInOneSession_thenTheFlipPromptFiresOnExactlyNine, which measures a 12-character one-line control at 22.0pt against the 63-character line at 66.0pt in the same run; commit c89e909
V16 | Low | CLOSED | Closed | CLOSED by Phase 8's swap 1: App/Views/CaptureView.swift now constructs AngleClusterSegmenter, which removes cross-cluster repeats and collapses near-duplicates inside a cluster — exactly this defect's cause, SIMON BASSLINE SMITH read off both the sleeve and the label of IMG_0505 and both kept. Measured on the twelve: IMG_0505's draft goes from 11 lines to 2, IMG_0503's from 16 to 2, and no fixture drafts a duplicate at all. Asserted twice and in two places: test_givenEveryFixture_whenSegmented_thenNoDraftCarriesADuplicateLine in Core over all twelve, and in the live walk, where the duplicate print that used to list SIMON BASSLINE SMITH is now an assertion that the list is empty. Fix photographed in 03-walk-06-inspect-raw-text.png; commit c89e909
V17 | Low | CARRIED | Phase 10 / U12 | RE-CARRIED with one new observation and no fix. The state-reproducibility problem is in the CRATE walk's edit-mode frames, which Phase 8 did not touch. What Phase 8 did find, in its own walk, is a second and different reproducibility hazard worth recording next to this one: XCUITest reads elements one at a time, so a screen still settling can be read across two renders — a header saying two sequenced next to three drawn rows, one of them 36 BPM outside the gate. That one WAS fixed at source (CrateDetailView clears a record's per-item status only after the re-sequence that follows it, commit 929ec1c), which is the shape a fix for this row will also need: make the app settle, do not make the test wait longer **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V18 | — | CLOSED | Closed | THE DEFECT THAT REFUSED ACT I, fixed and closed by plan 04-06. moveRows now compares the order a move produces against the order already displayed and returns early when they are equal, so an identity drag commits nothing: commit a20a43d. Leaving manualOrder untouched rather than clearing it is what makes it correct in both directions, and ManualOrderTests.swift asserts each separately — test_givenAnOutOfRangeMove_whenApplied_thenNothingTraps for the sequenced list and test_givenAManualOrder_whenARowIsMovedOntoItsOwnIndex_thenTheExistingOrderIsPreserved for the hand-arranged one, commit d658e3e. The presence check is gone: reorderTookEffect now polls the ROW ORDER for a genuine permutation, commit fbcf12c, and the walk runs three controls on that comparator in band. Photograph 02-walk-09-detail-manual-order.png, regenerated from a purged host on three clean runs, reads 1 Photek then 2 Source Direct under Custom order — the swap. Gate S3 rc=0 on 3 of 3 runs where 04-05 measured rc=0 rc=1 rc=1, and the 08 vs 09 pair is back at 31273 px 0.009890 against the 9131 px 0.002888 the defect produced. Route back to the defect: delete the guard line and 4 expectations redden, measured.
V19 | Medium | CLOSED | Closed | defect photographed in the PREVIOUS 03-walk-07-done-sequenced.png, the version at commit 96ccfe6 (The Accidental Heroes - Dragstar, badges 136 and 4B, labelled "no SoundCloud upload matched" - impossible, it plainly matched or those badges could not exist); fix photographed twice. In the REGENERATED 03-walk-07-done-sequenced.png - the same live twelve-record run, the same frame, the same row - The Accidental Heroes - Dragstar 136 4B now reads "No track within 4 BPM of the set", Cause 4 Concern - High Down 160 reads the same, Vinyl 1 with no badges reads "No SoundCloud upload matched" and Vinyl 5 with no badges reads "No identity to look up": three of the four terminal causes distinguished in one frame on real data. And in 09-manual-03-bucket-expanded.png on the fixtures. Root cause was structural and visible in the source, not only in the photograph: bestKnownBadges picked the candidate with the highest BPM while reason picked the first candidate carrying any failure note, so on a multi-candidate record the badges described one track and the sentence described another; NotIncludedRow.trackID makes them one candidate by construction. Defect route back: ExclusionReasonTests.swift asserts one test per row of the precedence table plus an 8-vinyl sweep of the invariant, and reverting reason() to first-note-wins makes the assert inside CrateRows.make trap the whole run naming the offending rows - measured. Also asserted live in ManualEntryUITests.swift. Commit 760f386
V20 | Informational | CARRIED | Phase 10 / U12 | Filed on first sight of the screen it is about and carried unfixed, with the reasoning written down rather than deferred silently: a full-height sheet whose content sits at the top is ordinary iOS, and both alternatives are worse - .presentationDetents at .medium hides the identity fields, and a content-fitted height is fiddly for no measured gain. MAN-01 is measured as an interaction count and the whitespace costs no interactions, so nothing this phase claims depends on it. Phase 14 owns the final hygiene sweep and is where a cosmetic call like this belongs. See 09-manual-04-sheet-from-bucket.png **RE-POINTED 2026-08-30 (Phase 10, the final phase).** The phase this row was carried to does not exist: the roadmap was compressed 14 phases into 10 and there is no Phase 11, 12 or 14 left to run. A carry to a phase that will never happen is a carry to nowhere, so the owner is now the project's owner, through the UAT item named beside it.
V21 | Medium | CLOSED | Closed | defect measured in Artifacts/vinylctl/sequence-baseline.txt, the pre-fix run: twelve photographs produced 'The set - 2 records' above 'Not in the set (9)', so one record was in neither list. Root cause read from source, not guessed: BeamSearchSequencer takes [Track] and builds its firstAppearance vinyl list from the tracks it was handed, so a vinyl with zero candidates contributes nothing and is structurally incapable of appearing in notIncluded - the sequencer never learns the record exists and cannot be the place this is fixed. Fixed in CrateRows.make, the one place a SequenceResult is projected against its crate and therefore the only place that can see the discrepancy; both front ends route through it, so one guard covers the app and the CLI. Fix commit e13633d. Defect route back: delete the unaccounted block and three expectations redden - test_givenAVinylWithNoCandidates_whenRowsBuilt_thenItIsStillInTheBucket, test_givenAMixedCrate_whenRowsBuilt_thenEveryVinylIsAccountedForExactlyOnce and test_givenAStaleVinylIDInTheResult_whenRowsBuilt_thenItIsSkipped, which pins that the guard did not resurrect deleted vinyls on the way. Post-fix on real data: 2 sequenced plus 10 not included = 12, in the CLI (sequence-baseline.txt) and in the app (1 plus 'Not in the set (11)')
V22 | Medium | CARRIED | Phase 10 / U8 | **THE DEFECT IS REAL AND THE ORIGINAL DIAGNOSIS WAS WRONG; corrected here by command rather than by reading.** Confirmed: Artifacts/vinylctl/sequence-baseline.txt prints the bucket row `Cause 4 Concern - High Down  160  -` while the IMG_0503 record block four screens above it lists High Down at [116.1] and Strange Nature at [160]. The name comes from one candidate and the tempo from another - V19's exact shape. BUT it is NOT a vinylctl defect and vinylctl is NOT a separate renderer: Tools/vinylctl/main.swift lines 431-432 call model.apply(result) then read model.rows, which is CrateDetailModel -> CrateRows.make, the identical path CrateDetailView.load takes. Grep confirms the CLI contains no row-rendering logic of its own, and Scripts/vinylctl-vs-app.sh asserts exactly that as a structural gate. The real root cause is in CORE and affects BOTH front ends equally: Phase 9's V19 fix bound reason, badges and trackID to one representative candidate (the highest known tempo) and left label bound to VinylEntry.label, which picks the FIRST RESOLVED candidate instead. Two selectors, one row. NOT FIXED HERE, and the reason is not cowardice: the obvious fix - bind label to the representative too - IS U8's fix A. On a record with candidates but none marked .resolved it replaces `Vinyl N` with the candidate's displayName, which is precisely the product call the owner has been asked to make since Phase 2 and which four phases have declined to make for them. Fixing V22 would answer U8 by side effect. It therefore waits on the same answer.
V23 | Medium | CARRIED | Phase 10 / U4 | **RE-POINTED and confirmed against the committed baseline.** Phase 11 does not exist; the roadmap compressed 14 phases into 10 and Phase 10 is the last. The finding stands and is the mechanism behind the Definition-of-Done walk's own item-3 observation that the live set (136 and 138.8 BPM, on a crate of jungle twelves) obeys every rule it is gated on and is still probably not one to play. NOT FIXED HERE: changing the rank tuple is a change to the SEQUENCER'S OBJECTIVE, made at the close of the milestone with no owner sign-off and no way to evaluate the result except U4 - is this a set you would play. That is a Rule 4 architectural call, and guessing it would be exactly the kind of end-of-project change that looks like polish and is a redesign. The proposed tie-break is recorded verbatim so the owner can take it in ten minutes if they agree. Original finding: the sequencer's objective cannot prefer the tighter cluster. On the live twelve it chose 136 -> 138.8 and excluded 174.8 and 175, which are 0.2 BPM apart and the best transition in the crate. Both are valid two-record sets so maximise-count ties, and neither pair has two known keys so the Camelot tie-break cannot separate them. Recommendation: tie-break on mean adjacent BPM delta before Camelot - a one-line change to the rank tuple, no new UI, no genre model.
```


## V23 — why this is a specification gap, not a bug

The code does exactly what the spec says: maximise vinyl count, tie-break on total Camelot
distance. Both candidate sets hold two records, and neither has two known keys, so the
tie-break has nothing to work with. It picks one.

But a DJ looking at this crate would pick `174.8 → 175` without hesitation — that is a jungle
set, and 0.2 BPM is a seamless transition. `136 → 138.8` is a different genre entirely.

**Nothing in the objective knows the crate has a target tempo band.** Options, none of which
should be chosen without the owner:

1. **Prefer the tighter cluster** — tie-break on mean adjacent BPM delta before Camelot. Here:
   0.2 versus 2.8. Cheap, general, needs no genre knowledge, and matches what a DJ optimises.
2. **A target tempo band per crate** — the owner sets "this is a 170–180 set" and records
   outside it are deprioritised. More control, more UI.
3. **Leave it.** With more records the ties get rarer, and at 20+ vinyls this may never fire.

Recommendation: **option 1.** It is a one-line change to the rank tuple, needs no new UI and no
genre model, and it is what "which of these two sets is better?" actually means to a DJ.

> **Note on severity formatting (learned 2026-08-30):** `ledger-check.py` matches the severity
> cell exactly. A qualifier inside it — `**Medium — a product gap, not a code defect**` —
> makes the row invisible to the Medium-or-above count while still *looking* filed. Keep the
> severity cell to the bare word and put the qualification in the description or a note below.
> This is the second time this ledger has silently under-counted: V19 was originally filed
> below the machine-readable section, where the gate structurally could not see it.
