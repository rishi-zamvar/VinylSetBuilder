---
phase: 02-crate-screens-stubbed
plan: 04
subsystem: verification-harness
tags: [xcuitest, ship-criterion, screenshots, crate-flow, accessibility-identifiers]
requires:
  - XCUITest target + shared scheme + ScreenshotRecorder (02-02)
  - the 19-identifier accessibility contract (02-03)
  - FixtureCrates.demoStore, BeamSearchSequencer (Phase 1)
provides:
  - "UITests/CrateWalkUITests.swift - Act I's ship criterion, executable and unattended"
  - "fifteen committed state photographs, each probed for real dynamic range"
  - "a permanent regression test for CrateListView / CapturePlaceholderView / CrateDetailView"
  - "the re-measured answer to the container-freshness question 02-02 and 02-03 disagreed on"
affects:
  - plan 02-05 (audits the count and the hygiene against exactly this record)
tech-stack:
  added: []
  patterns:
    - "assert on identifiers; the one caption under test is captured before the act and asserted CHANGED"
    - "every green assertion carries a negative control proving it can fail"
    - "edit state is read relative to a recorded inactive caption, so neither Edit nor Done is hardcoded"
key-files:
  created:
    - UITests/CrateWalkUITests.swift
    - Artifacts/screenshots/02-walk-01-crate-list.png
    - Artifacts/screenshots/02-walk-02-new-crate-sheet.png
    - Artifacts/screenshots/02-walk-03-capture-empty.png
    - Artifacts/screenshots/02-walk-04-capture-with-vinyl.png
    - Artifacts/screenshots/02-walk-05-new-crate-detail.png
    - Artifacts/screenshots/02-walk-06-crate-detail-sequenced.png
    - Artifacts/screenshots/02-walk-07-not-included-expanded.png
    - Artifacts/screenshots/02-walk-08-detail-edit-mode.png
    - Artifacts/screenshots/02-walk-09-detail-manual-order.png
    - Artifacts/screenshots/02-walk-10-detail-restored.png
    - Artifacts/screenshots/02-walk-11-add-more-capture.png
    - Artifacts/screenshots/02-walk-12-detail-after-remove-vinyl.png
    - Artifacts/screenshots/02-walk-13-second-crate-different-selection.png
    - Artifacts/screenshots/02-walk-14-crate-list-after-delete.png
    - Artifacts/screenshots/02-walk-15-crate-list-empty.png
    - .planning/phases/02-crate-screens-stubbed/deferred-items.md
  modified:
    - Scripts/collect-screenshots.sh
decisions:
  - "Recipe 1 fired: press-and-drag on the row with the List in edit mode. Recipes 2-4 never ran."
  - "Zero identifier drift - all 19 of 02-03's contract entries resolved exactly as recorded"
  - "02-smoke-crate-list.png KEPT, not deleted: 02-02-SUMMARY names it as 02-05's luminance baseline"
  - "Container freshness re-measured: 02-02 was right, 02-03's persistence reading was a misdiagnosis"
metrics:
  duration: ~50 min
  tasks: 2
  files: 18
  completed: 2026-08-30
  tests_before: 113 unit + 1 UI
  tests_after: 113 unit + 2 UI
---

# Phase 2 Plan 04: The Crate Walk Summary

One linear XCUITest walks the entire crate flow against stubbed fixture data and photographs
all fifteen states it passes through, unattended, green on the first run and reproducibly green
on a second clean run — which is the difference between "the tests pass" and "the shell can be
walked".

## The state manifest — FIFTEEN states, all captured

No fallback was needed; the drag fired on its first recipe, so no state was dropped and no U8
row was added to `.planning/UAT-PENDING.md`.

| # | State | Proves | Screenshot |
|---|---|---|---|
| 1 | crate list at launch | CRATE-01, **V1** | `02-walk-01-crate-list` |
| 2 | new-crate sheet, name typed | CRATE-02 | `02-walk-02-new-crate-sheet` |
| 3 | capture, empty | **CRATE-02** — create lands in the camera | `02-walk-03-capture-empty` |
| 4 | capture, after Add Fixture Vinyl | still on capture | `02-walk-04-capture-with-vinyl` |
| 5 | the new crate's detail | **CRATE-03** | `02-walk-05-new-crate-detail` |
| 6 | Friday Warehouse, sequenced | CRATE-03, **SEQ-07** | `02-walk-06-crate-detail-sequenced` |
| 7 | the bucket, expanded | **SEQ-07** | `02-walk-07-not-included-expanded` |
| 8 | edit mode | affordances real, not just a caption flip | `02-walk-08-detail-edit-mode` |
| 9 | manual order | **CRATE-04** | `02-walk-09-detail-manual-order` |
| 10 | restored | **CRATE-04** | `02-walk-10-detail-restored` |
| 11 | Add More on the SAME crate | **CRATE-05** | `02-walk-11-add-more-capture` |
| 12 | after removing a vinyl | **CRATE-06** | `02-walk-12-detail-after-remove-vinyl` |
| 13 | Sunday Chill | **CRATE-07**, **SEQ-11** | `02-walk-13-second-crate-different-selection` |
| 14 | crate list after a delete | **CRATE-06** | `02-walk-14-crate-list-after-delete` |
| 15 | the empty state | CRATE-01 | `02-walk-15-crate-list-empty` |

`ls Artifacts/screenshots/02-walk-*.png | wc -l` → **15**, against a recorded manifest of 15.

## Test results — actual output, not paraphrased

```
Test Case '-[VinylSetBuilderUITests.CrateWalkUITests
  test_givenTheStubbedApp_whenTheWholeCrateFlowIsWalked_thenEveryStateRendersAndIsPhotographed]'
  passed (110.055 seconds).
Test Case '-[VinylSetBuilderUITests.SmokeUITests
  test_givenTheApp_whenLaunched_thenTheCrateListRendersTheFixtureCrates]' passed (10.959 seconds).
   Executed 2 tests, with 0 failures (0 unexpected) in 121.014 (121.019) seconds
** TEST SUCCEEDED **
```

Both test classes ran. No `XCTAssert` failure anywhere in the log. Run 2, from a clean purge of
both stale sources, was identical: `Executed 2 tests, with 0 failures (0 unexpected) in 121.019`,
`** TEST SUCCEEDED **`.

| # | Gate | Command | Result |
|---|---|---|---|
| 1 | XCUITest | `./Scripts/ui-test.sh` | `** TEST SUCCEEDED **`, 2 tests, 0 failures — **twice** |
| 2 | screenshot count | `ls Artifacts/screenshots/02-walk-*.png \| wc -l` | **15** = recorded state count |
| 3 | Pillow probe | see table below | exit 0, `SUSPECT: none` |
| 4 | Core suite | `./Scripts/test.sh` | `Test run with 113 tests in 0 suites passed after 0.017 seconds` |
| 5 | device-SDK build | `./Scripts/build-app.sh` | `** BUILD SUCCEEDED **` |
| 6 | scope | `git status --short App/ VinylSetBuilderCore/ project.yml` | empty |
| 7 | hygiene | `grep -rn "TODO\|FIXME" UITests/` | no output |

Gate 6 note: `Scripts/` is deliberately **not** empty — see deviation 1. `App/`,
`VinylSetBuilderCore/` and `project.yml` are untouched, which is the constraint that matters.

## What the walk measured, printed from the running app

Every line below is from the xcodebuild log, not inferred:

```
WALK record-count-Friday Warehouse at launch = 4 records
WALK ordering-mode-label (sequenced) = 'Running order'
WALK fridayTitles = ["1, Source Direct — Snake Style, 170, 5A", "2, Photek — Ni Ten Ichi Ryu, 172, 8A"]
WALK not-included collapsed cells=4 texts=12 -> expanded cells=6 texts=20
WALK detail list buttons 2 -> 4 on entering edit mode
WALK DRAG RECIPE FIRED: 1: press-and-drag on the row, edit mode ON
WALK ordering-mode-label (manual) = 'Custom order'
WALK sundayRow = '1, Photek — The Hidden Camera, 174, 9A'
WALK sunday badges = ["174", "9A"]
WALK COMPLETE — recorded state count = 15
```

**CRATE-07 on screen, which is the one the phase was written for.** The same physical vinyl —
same `vinylID`, `F19ED000-…-000000000090` — renders `Photek — Ni Ten Ichi Ryu, 172, 8A` in
Friday Warehouse and `Photek — The Hidden Camera, 174, 9A` in Sunday Chill. The per-crate pin is
honoured in pixels, not only in `CrateDetailModelTests`.

## Which drag recipe fired

**Recipe 1**, on the first attempt, both runs:

```swift
app.staticTexts["sequenced-row-1"].press(forDuration: 1.0,
                                         thenDragTo: app.staticTexts["sequenced-row-2"])
```

with the `List` in edit mode. Recipes 2 (same gesture, edit mode off), 3 (coordinate drag onto
the trailing-edge handle at dx 0.93) and 4 (coordinate drag past the target) are in the file and
never executed. `02-walk-09-detail-manual-order.png` shows the result: header `Custom order`, a
blue `Restore`, and `Photek — Ni Ten Ichi Ryu` sitting above `Source Direct — Snake Style`.

The success signal is deliberately `restore-sequenced-order-button` appearing — an identifier —
and its `waitForExistence(timeout: 3)` doubles as the settle the reorder animation needs. The
recipes stop at the first that fires, because two successful drags on a two-row list return it
to where it started and the assertion would then fail for the opposite reason.

## Which query resolved the record count

`app.staticTexts["record-count-Friday Warehouse"]`, exactly as 02-03 recorded. Label `4 records`
at launch, `3 records` after the vinyl removal. The documented `app.buttons[…].label` fallback
was **not** needed.

Only the leading integer is read (`Int(label.prefix { $0.isNumber })`) and it is compared against
the value captured at step 1 — never a hardcoded 4 and 3 — so the fixture may grow without
breaking the test. The noun is never asserted on: V1 already proved that string moves.

## Identifier drift against 02-03's contract

**None. Zero drift.** All nineteen identifiers resolved on the element type 02-03 recorded, and
all four of its measured gotchas held exactly:

| 02-03 gotcha | Held? |
|---|---|
| record count is a `staticText`, label `1 record`; `1 records` does not exist | ✅ asserted both halves |
| `new-crate-button` / `back-to-crates-button` / `add-more-button` publish two elements each | ✅ every query is typed `app.buttons[…]`; no "multiple matching elements" throw |
| edit mode prefixes every row label with `Remove, ` | ✅ `fridayTitles` is recorded at step 6, out of edit mode |
| edit mode is not required to reorder | ✅ though recipe 1 fired *in* edit mode, so this was not exercised |

Two things worth handing to 02-05 that the contract did not record:

- **`.accessibilityElement(children: .combine)` joins a row's four Texts with `", "`.** So
  `"1, Photek — The Hidden Camera, 174, 9A"` splits cleanly and the last two components are the
  SEQ-11 badge pair. That is how the badges are asserted non-placeholder without asserting any
  wording.
- **Entering edit mode takes the detail list from 2 buttons to 4** (two `Reorder Remove`
  affordances). That count is what proves the `List` is genuinely editing. 02-03 measured
  `EditButton()` flipping its own caption while the `List` stayed inactive, so the caption alone
  is not evidence and the walk asserts on both.

## The photograph table — measured, all fifteen

| File | size | mean | min | max | bytes |
|---|---|---|---|---|---|
| `02-walk-01-crate-list.png` | 1206x2622 | 242.4 | 0 | 255 | 103,361 |
| `02-walk-02-new-crate-sheet.png` | 1206x2622 | 233.7 | 0 | 255 | 168,202 |
| `02-walk-03-capture-empty.png` | 1206x2622 | 251.1 | 0 | 255 | 92,320 |
| `02-walk-04-capture-with-vinyl.png` | 1206x2622 | 251.1 | 0 | 255 | 92,320 |
| `02-walk-05-new-crate-detail.png` | 1206x2622 | 241.1 | 0 | 255 | 147,997 |
| `02-walk-06-crate-detail-sequenced.png` | 1206x2622 | 240.5 | 0 | 255 | 187,135 |
| `02-walk-07-not-included-expanded.png` | 1206x2622 | 241.5 | 0 | 255 | 234,084 |
| `02-walk-08-detail-edit-mode.png` | 1206x2622 | 241.7 | 0 | 255 | 244,411 |
| `02-walk-09-detail-manual-order.png` | 1206x2622 | 241.6 | 0 | 255 | 247,903 |
| `02-walk-10-detail-restored.png` | 1206x2622 | 241.7 | 0 | 255 | 244,410 |
| `02-walk-11-add-more-capture.png` | 1206x2622 | 250.7 | 0 | 255 | 95,447 |
| `02-walk-12-detail-after-remove-vinyl.png` | 1206x2622 | 240.5 | 0 | 255 | 163,689 |
| `02-walk-13-second-crate-different-selection.png` | 1206x2622 | 240.9 | 0 | 255 | 154,119 |
| `02-walk-14-crate-list-after-delete.png` | 1206x2622 | 242.4 | 0 | 255 | 102,924 |
| `02-walk-15-crate-list-empty.png` | 1206x2622 | 252.8 | 0 | 255 | 91,808 |

`SUSPECT: none`, probe exit 0. Every frame has a genuinely black pixel (`min 0`) and a white
ground (`max 255`) — no V2-style launch-fade artefact anywhere in the set. Run 1's numbers were
identical to within 0.1 mean and a few hundred bytes of PNG entropy, so the walk is deterministic
as well as green.

**One honest caveat on that table: states 3 and 4 are byte-identical** (md5
`ab046e5f0af917698ecf6504878a8ecf` on run 1). That is correct behaviour, not a capture failure —
`CapturePlaceholderView` renders the crate name and two buttons and nothing that reflects the
crate's contents, so adding a fixture vinyl is genuinely invisible on that screen. It does mean
state 4's photograph is not independent evidence; the vinyl's arrival is proven by state 5,
where `sequenced-row-1` exists on the new crate's detail. Logged as `D-02-04-1` in
`deferred-items.md` rather than fixed, because `App/` is out of this plan's scope and Phase 3
replaces that screen with the real camera anyway.

## How each assertion was shown to be able to fail

02-02 nearly shipped an `NSPredicate` matcher that went green while matching nothing. Three
negative controls are therefore built into the walk itself and run on every execution:

1. **Step 1** — `XCTAssertFalse(app.staticTexts["record-count-Wednesday Nonexistent"].exists)`.
   If the `record-count-*` family resolved a nonsense identifier, every count assertion would be
   matching something other than what it names.
2. **Step 5** — `XCTAssertFalse(app.staticTexts["sequenced-row-99"].exists)`. `sequencedRowLabels()`
   counts the running order by walking upward until a row is absent, so the whole row-count
   mechanism (CRATE-06's "one fewer row") depends on row 99 not resolving.
3. **Step 13** — the CRATE-07 membership check is `XCTAssertFalse(fridayTitles.contains(sundayRow))`.
   An always-false `contains` would pass that vacuously, so it is paired with
   `XCTAssertTrue(fridayTitles.contains(fridayTitles[0]))` — the same check applied to a known
   member. Both must hold.

Two further places where a weaker test would have passed on nothing:

- **Edit mode (step 8)** asserts the caption changed *and* that the list's button count rose.
  02-03 measured `EditButton()` flipping its caption while the `List` stayed inactive; the
  caption alone would have gone green on exactly that bug.
- **SEQ-07 (step 7)** asserts `textsExpanded > textsCollapsed + (cellsExpanded - cellsCollapsed)`.
  Rows appearing with only a label would satisfy a naive cell-count check but fail this one —
  and the reason line is the half of SEQ-07 that actually matters. Measured 4 cells / 12 texts
  collapsed → 6 cells / 20 texts expanded.

## Holding the identifier line across all fifteen states

The bar was "never assert on a display string a later phase might reword". Every assertion in the
walk is on an identifier, a count, or a value captured earlier in the same run. The exceptions
are four, each deliberate:

| Assertion | Why it is safe |
|---|---|
| `capture-crate-name == "Test Crate"` / `"Friday Warehouse"` | crate *names*, from `FixtureCrates`. 02-02 established these as the stable thing to match on. CRATE-05's whole proof is that this name is the existing crate's. |
| `label.contains("1 record")` + `!contains("1 records")` | V1 itself. The string IS the defect; asserting on it is the point. |
| `staticTexts["No Crates Yet"]` | `ContentUnavailableView`'s title carries no identifier. Kept as a *secondary* check — the primary empty-state assertion is that no `crate-row-*` of any fixture name resolves. |
| badge `!= "—"` | `TrackBadges.placeholder`, a Core constant, not UI copy. |

`ordering-mode-label` is the interesting one. Its *value* is the thing CRATE-04 is about, so it
cannot be avoided — but it is never hardcoded. `"Running order"` is captured at step 6 into
`runningOrderLabel`, the drag asserts the label **changed**, and Restore asserts it is **back to
the captured value**. The identifier-based half (`restore-sequenced-order-button` appears, then
disappears) carries the real weight. Renaming those captions in a later phase will not redden
this test. The same trick is used for `Edit`/`Done`: the inactive caption is read once into
`editLabelWhenInactive` and edit state is derived relative to it.

## Deviations from Plan

### 1. [Rule 3 — Blocking] `Scripts/collect-screenshots.sh` header rewritten, and my first rewrite was wrong

- **Found during:** Task 2's setup, before the first run.
- **Issue:** The plan forbids touching `Scripts/`, but the orchestrator explicitly put it in
  scope to correct the container-freshness comment 02-03 flagged as wrong. It was blocking in the
  literal sense: the count gate is only meaningful if the caller knows what to purge.
- **What I measured, and how it changed my answer twice.** Before the first run I resolved the
  runner's data container and found **twelve** PNGs in it — all eight of 02-03's screenshots plus
  the four `02-03-probe-*.png` files that plan had deleted from the host. `collect-screenshots.sh`
  would have copied those strays straight back in. I purged them and wrote a comment saying the
  container survives across runs, i.e. 02-03 was right and 02-02 was wrong.
  **That was an overclaim, and the second run caught it.** Three consecutive `xcodebuild test`
  runs produced three *different* container UUIDs — `1CE93729…` → `498F1B2B…` → `F69EAB81…` —
  each holding only its own run's output. **02-02 was right: the container is recreated every
  run.** What 02-03 saw was the *previous run's complete output* still sitting in the last
  container, which is accumulation across plans, not across runs.
- **Fix:** the comment now records the re-measurement, names both readings and why 02-03's was a
  misdiagnosis, and states the hazard that is actually real — (a) the host directory accumulates
  and nothing clears it, so the glob must be purged before a counting run, and (b) this script
  copies whatever is in the current container, so running it *without* a preceding test run
  silently re-copies the previous run's PNGs and they look like current evidence.
- **Files modified:** `Scripts/collect-screenshots.sh` (comment only — not one line of executable
  shell changed; `bash -n` clean).
- **Commit:** `a3fb5dd`

### 2. [Deliberate] `02-smoke-crate-list.png` was NOT deleted

- **The plan says** to delete it if `02-walk-01-crate-list.png` covers the same state. It does
  cover the same state.
- **It was kept anyway**, for a reason the plan could not have known: `02-02-SUMMARY.md` records
  it as the luminance baseline **02-05 compares its A/B launch-fade captures against**
  (`mean 242.4 min 0 max 255`, 104,593 bytes). Deleting it would remove 02-05's control.
  Secondarily, `SmokeUITests` rewrites it on every run, so deleting it from `Artifacts/` just
  makes it reappear on the next `collect-screenshots.sh` as an untracked file — churn, not
  hygiene.
- The freshly captured copy from this run was `git checkout`-ed back to 02-02's committed bytes,
  so another plan's artefact is left exactly as its owner committed it. **If 02-05 disagrees, it
  owns that file's fate — deleting it then is a one-liner.**

### 3. [Minor] The drag is attempted in the order the measurements justify

The plan's recipe 1 is `a.press(forDuration: 1.0, thenDragTo: b)` with `a = cells[1]`,
`b = cells[0]` — row 2 dragged above row 1. The walk instead drags `sequenced-row-1` onto
`sequenced-row-2`, which is the **exact gesture 02-03 measured working** on this SDK, and targets
the frozen identifiers rather than `cells` bound-by index (02-03 measured that crate-list rows do
not resolve as `cells` at all, so the index route is not uniformly reliable). On a two-row list
both gestures produce the same swap, and the assertion is on `ordering-mode-label` changing and
`restore-sequenced-order-button` appearing, which is satisfied either way. It fired first try.

## Requirements proven on screen

| Requirement | How, in this walk |
|---|---|
| CRATE-01 | states 1, 14, 15 — the list, a delete, the empty state |
| CRATE-02 | state 3 — `capture-crate-name` reads `Test Crate`; create routes to the camera, not back to the list |
| CRATE-03 | states 5, 6 — `sequenced-row-1` exists on both a brand-new crate and the fixture crate |
| CRATE-04 | states 9, 10 — drag flips the header off `Running order` and raises `Restore`; Restore puts both back |
| CRATE-05 | state 11 — Add More reaches capture showing **`Friday Warehouse`**, the same crate |
| CRATE-06 | state 12 (running order 2 → 1 rows, list count 4 → 3 records) and states 14/15 (crate deletes) |
| CRATE-07 | state 13 — the shared vinyl renders `The Hidden Camera` here and `Ni Ten Ichi Ryu` there |
| SEQ-07 | states 6, 7 — one bucket, collapsed by default, expanding to rows that each carry a reason |
| SEQ-11 | state 13 — two badge strings, `174` and `9A`, neither the em-dash placeholder |

## Known Stubs

None introduced by this plan. `CapturePlaceholderView` is Phase 1 scaffolding that Phase 3
replaces; its only consequence here is the identical states 3/4 recorded above as `D-02-04-1`.

## What FAILED

Nothing is left failing, and nothing was weakened to get green. Two things are worth stating
plainly rather than buried:

1. **I got the container-freshness question wrong on the first pass** and wrote a confident,
   incorrect comment into `collect-screenshots.sh` claiming 02-02 was wrong. The second run's
   container UUID contradicted it and the comment was rewritten to the measurement. The original
   claim never reached a commit, but the near-miss is the point: I reproduced exactly the error
   02-03 made — one observation, a confident causal story, no second sample.
2. **State 4's photograph is not independent evidence** (states 3 and 4 are byte-identical). The
   count gate still reads 15 because fifteen distinct states were *visited* and photographed; but
   anyone reading the pictures should know two of them look the same, and why. Recorded in
   `deferred-items.md`.

## Self-Check: PASSED

```
FOUND: UITests/CrateWalkUITests.swift              (401 lines, >= 120 required)
FOUND: Artifacts/screenshots/02-walk-01-crate-list.png ... 02-walk-15-crate-list-empty.png  (15/15)
FOUND: .planning/phases/02-crate-screens-stubbed/deferred-items.md
FOUND: commit ae37a91  test(02-04): the fifteen-state crate walk, unattended
FOUND: commit a3fb5dd  chore(02-04): fifteen settle-delayed photographs of the crate walk
```

Plan `key_links` verified in the file, precisely:

- `ScreenshotRecorder.capture` appears **once**, and that is deliberate — all fifteen states go
  through a single private `capture(_:settle:)` helper, so the mandatory settle and the
  "app must be in the foreground" guard exist in exactly one place and cannot be skipped on one
  state out of fifteen. Fifteen call sites reach that one line.
- `XCUIScreen` appears once, on line 381, **inside a doc comment** saying not to use it. There is
  no direct `XCUIScreen.main.screenshot()` call anywhere in the file.
- `add-more-button` appears twice — 02-03's contract is queried, not re-derived.
