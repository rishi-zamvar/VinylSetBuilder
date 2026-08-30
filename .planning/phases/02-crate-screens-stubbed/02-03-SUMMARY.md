---
phase: 02-crate-screens-stubbed
plan: 03
subsystem: crate-screens
tags: [crate-detail, swiftui, accessibility-identifiers, manual-order, xcuitest]
requires:
  - CrateDetailModel, OrderingMode (02-01)
  - CrateStore.addMore / update / removeVinyl / closeToList
  - SequencedRowView, NotIncludedSectionView, BadgePairView (Phase 1)
  - BeamSearchSequencer (Phase 1)
provides:
  - CrateDetailView (CRATE-03/04/05/06, SEQ-07, SEQ-11 pixels)
  - RootView with no placeholder left in it
  - the 19-identifier accessibility contract plan 02-04's walk is written against
affects:
  - plan 02-04 (writes the fifteen-state walk against the identifiers frozen here)
  - plan 02-05 (V2 diagnosis — the crate-list row structure is unchanged)
tech-stack:
  added: []
  patterns:
    - "The view holds no rules: every ordering decision is a CrateDetailModel call"
    - "Three private helpers own every store interaction (load / commit / removeVinyls)"
    - "Accessibility identifiers verified against the live tree, never assumed"
key-files:
  created:
    - App/Views/CrateDetailView.swift
    - Artifacts/screenshots/02-03-crate-detail.png
    - Artifacts/screenshots/02-03-crate-detail-custom-order.png
    - Artifacts/screenshots/02-03-crate-detail-edit-mode.png
    - Artifacts/screenshots/02-03-crate-detail-bucket-expanded.png
    - Artifacts/screenshots/02-03-crate-detail-empty.png
    - Artifacts/screenshots/02-03-crate-detail-after-delete.png
    - Artifacts/screenshots/02-03-crate-list-after-delete.png
    - Artifacts/screenshots/02-03-capture-stub.png
  modified:
    - App/Views/RootView.swift
    - App/Views/CrateListView.swift
    - App/Views/NewCrateSheet.swift
    - App/Views/CapturePlaceholderView.swift
decisions:
  - "A throwaway XCUITest probe measured the real accessibility tree rather than guessing at it — it found three functional defects no unit test could reach"
  - "EditButton() replaced by a plain Button: toolbar content is hosted outside this view's environment, so EditButton drove a binding the List never read"
  - "The .onMove/.onDelete ForEach must not sit inside a conditional or the List renders no edit affordances at all"
  - "Row accessibility is .combine'd, so one identifier resolves one element instead of four leaf Texts"
metrics:
  duration: ~55 min
  completed: 2026-08-30
  tests_before: 113 unit + 1 UI
  tests_after: 113 unit + 1 UI
---

# Phase 2 Plan 03: The Crate Detail Screen Summary

`CrateDetailView` — the sequenced running order with BPM/Camelot badges, drag-to-override with
one-tap restore, the single collapsed not-included bucket, Add More, and remove — plus the
19-identifier accessibility contract plan 02-04 is written against, every entry of which was
resolved against the live accessibility tree rather than assumed.

## What was built

`App/Views/CrateDetailView.swift` (144 lines). `RootView`'s `.crateDetail` case and its
`TODO(01-08)` marker are gone; `grep -rn "TODO\|FIXME" App/ VinylSetBuilderCore/Sources/ UITests/`
returns nothing.

The view holds no rules. Every ordering decision is a `CrateDetailModel` call
(`resequence`, `moveRows`, `clearManualOrder`), and every store interaction goes through exactly
three private helpers — `load()`, `commit(_:)`, `removeVinyls(_:)` — so a mutation cannot
silently skip the re-derivation.

## Test results — actual output

| Gate | Command | Result |
|---|---|---|
| Device-SDK build | `./Scripts/build-app.sh` | `** BUILD SUCCEEDED **`, no warnings from this plan's files |
| Core suite | `./Scripts/test.sh` | `✔ Test run with 113 tests in 0 suites passed after 0.015 seconds.` — 113 green, 0 failed, 0 skipped |
| XCUITest | `./Scripts/ui-test.sh` | `Executed 1 test, with 0 failures (0 unexpected) in 12.278s` → `** TEST SUCCEEDED **` |

Unit-test count is unchanged at 113 on purpose: this plan adds no Core logic. Everything it
builds is view wiring, and it is proved by the accessibility tree and the screenshots below,
not by `swift test`.

### The plan's seven verification points

1. `./Scripts/build-app.sh` exits 0 against the iOS 26 device SDK with signing disabled. ✅
2. `./Scripts/test.sh` exits 0 — 113 green, Core untouched. ✅
3. `grep -rn "TODO\|FIXME" App/` → no output. ✅
4. `grep -rn "sorted(\|\.filter" App/Views/CrateDetailView.swift` → no output. ✅
5. `grep -rn "AsyncSequencer\|DispatchQueue\|Task {" App/Views/CrateDetailView.swift` → no output. D2-3 holds. ✅
6. `grep -rn "Slider" App/` → no output. D2-4 holds. ✅
7. `git diff --stat App/Views/CrateListView.swift` → `1 file changed, 6 insertions(+)`, zero deletions. **The `Button`, `.buttonStyle(.plain)` and the trailing `.foregroundStyle(.secondary)` are byte-for-byte unchanged. V2's evidence is intact for plan 02-05.** ✅

## The identifier contract — AS ACTUALLY IMPLEMENTED

Every row below was resolved against the live accessibility tree on UDID
`4B4E1C1F-BED6-4812-9238-C151337265DA`. **The "resolves as" column is measured, not predicted.**
Each identifier appears exactly once under `App/`.

| Screen | Element | Identifier | Resolves as | Measured label |
|---|---|---|---|---|
| Crate list | the `List` | `crate-list` | `app.collectionViews["crate-list"]` | — |
| Crate list | row `Button` | `crate-row-<name>` | **`app.buttons[...]`** | `Sunday Chill, 1 record` |
| Crate list | count `Text` | `record-count-<name>` | **`app.staticTexts[...]`** | `1 record` / `4 records` |
| Crate list | toolbar `+` | `new-crate-button` | `app.buttons[...]` | `Add` |
| New crate sheet | `TextField` | `new-crate-name-field` | `app.textFields[...]` | — |
| New crate sheet | Create | `new-crate-create-button` | `app.buttons[...]` | `Create` |
| New crate sheet | Cancel | `new-crate-cancel-button` | `app.buttons[...]` | `Cancel` |
| Capture stub | crate-name `Text` | `capture-crate-name` | `app.staticTexts[...]` | the crate's name |
| Capture stub | Add Fixture Vinyl | `capture-add-fixture-button` | `app.buttons[...]` | `Add Fixture Vinyl` |
| Capture stub | Done | `capture-done-button` | `app.buttons[...]` | `Done` |
| Crate detail | the `List` | `crate-detail-list` | `app.collectionViews[...]` | — |
| Crate detail | sequenced row | `sequenced-row-<indexLabel>` | **`app.staticTexts[...]`** | `1, Source Direct — Snake Style, 170, 5A` |
| Crate detail | ordering-mode `Text` | `ordering-mode-label` | `app.staticTexts[...]` | `Running order` / `Custom order` |
| Crate detail | Restore | `restore-sequenced-order-button` | `app.buttons[...]` | `Restore` |
| Crate detail | not-included disclosure | `not-included-section` | **`app.buttons[...]`** | `Not in the set (2)` |
| Crate detail | Edit | `edit-button` | `app.buttons[...]` | `Edit` / `Done` |
| Crate detail | Add More | `add-more-button` | `app.buttons[...]` | `Add More` |
| Crate detail | Crates (back) | `back-to-crates-button` | `app.buttons[...]` | `Crates` |
| Crate detail | empty placeholder | `empty-running-order` | `app.staticTexts[...]` | `Nothing sequenced yet` |

### Four gotchas 02-04 must know, all measured

1. **The record count resolves as `app.staticTexts["record-count-Sunday Chill"]`, label `1 record`.**
   No fallback is needed. The aggregated `app.buttons["crate-row-Sunday Chill"].label` also works
   and reads `Sunday Chill, 1 record`, so V1 can be asserted through either. `app.staticTexts["1 records"]`
   does **not** exist. `otherElements[...]` and `cells[...]` do **not** resolve the row — it is a
   `Button`.
2. **`new-crate-button`, `back-to-crates-button` and `add-more-button` each publish TWO elements**
   (an `Other` wrapper and the `Button` inside it) with the same identifier. `app.buttons[id]`
   disambiguates; a bare `app.descendants(matching: .any)[id]` throws
   *"Multiple matching elements found"*. Use the typed query or `.firstMatch`.
3. **In edit mode every row label gains a `Remove, ` prefix** — `1, Source Direct — Snake Style, 170, 5A`
   becomes `Remove, 1, Source Direct — Snake Style, 170, 5A`. Do not assert exact row labels while
   edit mode is active.
4. **`Scripts/collect-screenshots.sh`'s header comment is wrong about container freshness.** It
   claims the runner gets a brand-new data container on every `xcodebuild test`, so `Documents/`
   only ever holds the current run's PNGs. Observed across five consecutive runs today: PNGs from
   earlier runs *persisted* and were re-copied. 02-04's `ls Artifacts/screenshots/02-walk-*.png | wc -l == 15`
   gate can therefore pass on leftovers — clear both the host glob **and** the container's
   `Documents/` before the run, or assert on what the script reports it copied.

## Which edit-mode API made `.onMove` work

**Both a plain long-press drag on the row and the edit-mode grabber work — edit mode is not
required to reorder.** Measured twice:

- With the List *not* in edit mode: `sequenced-row-1.press(forDuration: 1.0, thenDragTo: sequenced-row-2)`
  → `ordering-mode-label` became `Custom order`, `restore-sequenced-order-button` appeared, row 1
  became `Photek — Ni Ten Ichi Ryu`.
- With edit mode on: two `Reorder Remove` buttons appear; dragging grabber 0 to grabber 1 produces
  the same result.

So 02-04 **does not have to tap Edit first** to satisfy CRATE-04. Tapping it is still supported
and gives the red remove circles for CRATE-06.

The environment wiring is `@State private var editMode: EditMode` + `.environment(\.editMode, $editMode)`
applied to the view's `Group`. The plan's listed fallbacks (`.constant(.active)`, `List(editActions:)`)
were **not** needed.

## Where Add More landed

**In the bottom bar, as planned.** `ToolbarItem(placement: .bottomBar)` renders and is hittable on
the iOS 26 SDK; the fallback placements were not needed. Identifier `add-more-button`, label
`Add More`.

## Deviations from Plan

### 1. [Rule 1 - Bug] A crate row only opened when the tap landed on its name

- **Found during:** Task 2's identifier verification, on the very first probe run.
- **Issue:** `app.buttons["crate-row-Friday Warehouse"].tap()` synthesised a tap at the row's
  centre (x≈201) — which falls in the `HStack`'s `Spacer()` gap between the name (ends x≈169) and
  the count (starts x≈297). Nothing happened; the app stayed on the crate list through a 10-second
  wait. **CRATE-03's only entry point was unreachable by a centre tap, which is where a thumb
  actually lands.**
- **Diagnosis, before any edit:** three discriminating taps in one run — button centre
  (`navigated=false`), the name `StaticText` (`navigated=true`), so the action and `@Observable`
  propagation were both fine and the fault was hit-testing alone.
- **Fix:** `.contentShape(Rectangle())` on the button's label `HStack`. Hit-testing only — no
  visual, structural or styling change, so the constraint protecting V2's evidence is honoured
  (`git diff --stat` shows 6 insertions, 0 deletions, and the `Button` / `.buttonStyle(.plain)` /
  `.foregroundStyle(.secondary)` triple is untouched).
- **Re-measured after:** `PROBE tap=button-centre navigated=true`.
- **Files modified:** `App/Views/CrateListView.swift`
- **Commit:** `7cb28b8`

### 2. [Rule 1 - Bug] `.onMove`/`.onDelete` inside an `if/else` disabled every edit affordance

- **Found during:** Task 1 verification in the simulator.
- **Issue:** The plan's shape puts the empty-state `Text` and the `ForEach` in an `if/else`. With
  the `ForEach` inside a conditional branch, the `List` section had no statically-discoverable
  movable `ForEach`: edit mode rendered **no reorder grabbers and no delete circles at all**, and
  cell geometry was byte-identical to non-edit mode ({370.0, 52.0} both ways).
- **Fix:** the `ForEach` is unconditional; the empty-state `Text` follows it as a sibling row
  (an empty `ForEach` renders nothing, so the visual result is identical).
- **Re-measured after:** two `Button ... label: 'Reorder Remove'` elements, cells grown to
  {370.0, 72.3}, red remove circles visible in `02-03-crate-detail-edit-mode.png`.
- **Files modified:** `App/Views/CrateDetailView.swift`
- **Commit:** `7cb28b8`

### 3. [Rule 1 - Bug] `EditButton()` drove a binding the List never read

- **Found during:** the same investigation as deviation 2.
- **Issue:** `EditButton()` flipped its own label `Edit` → `Done`, and nothing else changed.
  `.toolbar` content is hosted in the navigation bar's own subtree, *outside* the
  `.environment(\.editMode, $editMode)` applied to this view — so `EditButton` toggled the
  navigation controller's edit binding while the `List` kept reading this view's `editMode`, still
  `.inactive`.
- **Discriminated, not assumed:** forcing `.environment(\.editMode, .constant(.active))` made the
  `List` render `Reorder Remove` grabbers immediately. So edit mode itself worked; only the
  binding was crossed.
- **Fix:** `EditButton()` replaced with `Button(editMode == .active ? "Done" : "Edit") { editMode = ... }`,
  driving the same state the `List` reads. The `edit-button` identifier and the `Edit`/`Done`
  labels are unchanged, so the frozen contract is unaffected.
- **Files modified:** `App/Views/CrateDetailView.swift`
- **Commit:** `7cb28b8`

### 4. Row accessibility is `.combine`d — a contract refinement, not a drift

- **Found during:** the first tree dump.
- **Issue:** `.accessibilityIdentifier` on `SequencedRowView`'s `HStack` propagated to all four
  leaf `Text`s (index, title, BPM, key), so `app.staticTexts["sequenced-row-1"]` matched **four**
  elements and any non-`.firstMatch` query threw.
- **Fix:** `.accessibilityElement(children: .combine)` before the identifier. One row is now one
  element labelled `1, Source Direct — Snake Style, 170, 5A` — which is also the only thing a drag
  can grab. The identifier string is exactly as the contract froze it.
- **Commit:** `7cb28b8`

### 5. V1 was already closed by plan 02-01

Task 2's V1 instruction was a no-op: `CrateListView` already read
`Text("^[\(summary.recordCount) record](inflect: true)")` from commit `c81805d`. Re-verified live
this run rather than taken on trust — `app.staticTexts["record-count-Sunday Chill"].label` is
`1 record` and `app.staticTexts["1 records"]` does not exist. No fallback branch was needed; the
inflected form works on this SDK.

### 6. A throwaway XCUITest probe was written, run, and deleted

The plan said to confirm the record-count query "rather than guessing", but ruled out
`UITests/SmokeUITests.swift` (02-02's file) and suggested reading identifiers off a screenshot —
which a screenshot cannot show. I instead wrote `UITests/_IdentifierProbe.swift`, ran it eight
times to dump and re-dump the live accessibility tree, and **deleted it before committing**.
Nothing from it is in the repo: `ls UITests/` is `ScreenshotRecorder.swift`, `SmokeUITests.swift`,
exactly as 02-02 left them, and `git status` is clean of it. It is what found deviations 1–4, none
of which any unit test could have reached.

## Behaviour verified end-to-end on the simulator

Every one of these is a measured line from a probe run, not an inference:

| Requirement | Evidence |
|---|---|
| CRATE-03 | detail opens on `Running order`; row 1 = `1, Source Direct — Snake Style, 170, 5A` |
| SEQ-11 | BPM and Camelot badges on every row: `170`/`5A`, `172`/`8A`; placeholders `—`/`—` on the unresolved vinyl |
| SEQ-07 | one `Not in the set (2)` bucket, `collapsed` by default, expanding 4 → 6 cells |
| CRATE-04 | drag → `Custom order` + `Restore`; row 1 becomes Photek. Restore → `Running order`; row 1 back to Source Direct |
| CRATE-05 | Add More → capture showing `Friday Warehouse` → Done → back on the `Friday Warehouse` detail |
| CRATE-06 | swipe-delete row 1 → row 1 becomes Photek; back on the list, `record-count-Friday Warehouse` reads **`3 records`** (was `4 records`) |
| CRATE-07 | Friday Warehouse's pin shows `Photek — Ni Ten Ichi Ryu`, the crate's own selection |
| CRATE-02 | `+` → sheet fields resolve → Create `Probe Crate` → capture stub shows `Probe Crate` |
| Empty state | a crate with no vinyls shows `Nothing sequenced yet`, no not-included section |
| V1 | `1 record`, and `1 records` does not exist anywhere in the tree |

## Screenshots produced

All captured with the app confirmed running and a settle delay of ≥3 s, per the standing
instruction in `.planning/VISUAL-DEFECTS.md`.

| File | What it proves |
|---|---|
| `02-03-crate-detail.png` | CRATE-03 + SEQ-11 + SEQ-07 collapsed. Correct label-black contrast — independently corroborates V2 as a launch-fade artefact |
| `02-03-crate-detail-custom-order.png` | CRATE-04: header reads `Custom order`, blue `Restore` present, rows swapped |
| `02-03-crate-detail-edit-mode.png` | Edit mode genuinely active: red remove circles + reorder grabbers, `Done` in the bar |
| `02-03-crate-detail-bucket-expanded.png` | SEQ-07 expanded: `Vinyl 2` 178/6A *"No track within 4 BPM of the set"*, `Vinyl 3` —/— *"No BPM yet"* — two distinct verbatim reasons in one bucket |
| `02-03-crate-detail-empty.png` | the empty-order placeholder on a freshly created crate |
| `02-03-crate-detail-after-delete.png` | CRATE-06 on the detail screen |
| `02-03-crate-list-after-delete.png` | the crate list's count following the removal |
| `02-03-capture-stub.png` | CRATE-05's destination, now correctly signposted Phase 3 |

The four diagnostic `02-03-probe-*.png` files were deleted rather than committed — one of them was
captured from a temporarily hacked build (`.constant(.active)`) and keeping it would be misleading
evidence.

## What FAILED

Nothing is left failing. Three real defects were found and fixed (deviations 1–3); each is recorded
with the measurement that found it and the measurement that confirmed the fix. No assertion was
weakened, no test skipped, and no gate was declared green without being run.

Two honest limitations:

- **Unit-test count is unchanged (113).** This plan adds no Core logic, so there was nothing new to
  TDD in `VinylSetBuilderCore`. Its proof is the accessibility tree and the screenshots. The
  permanent regression test for this screen is plan 02-04's fifteen-state walk; until that lands,
  nothing in CI would catch a regression in `CrateDetailView` — the probe that verified it was
  deliberately thrown away because 02-04 owns `UITests/`.
- **`Scripts/collect-screenshots.sh`'s container-freshness claim is wrong** (gotcha 4 above). I did
  not fix it: `Scripts/` belongs to 02-02/02-04 under this plan's constraints. Flagged here so
  02-04 does not inherit a gate that can pass on leftovers.

## Self-Check: PASSED

Files verified present on disk:

- `App/Views/CrateDetailView.swift` — FOUND
- `App/Views/RootView.swift` (placeholder removed) — FOUND
- `Artifacts/screenshots/02-03-crate-detail.png` — FOUND
- `Artifacts/screenshots/02-03-crate-detail-custom-order.png` — FOUND
- `Artifacts/screenshots/02-03-crate-detail-edit-mode.png` — FOUND
- `Artifacts/screenshots/02-03-crate-detail-bucket-expanded.png` — FOUND
- `Artifacts/screenshots/02-03-crate-detail-empty.png` — FOUND
- `Artifacts/screenshots/02-03-crate-detail-after-delete.png` — FOUND
- `Artifacts/screenshots/02-03-crate-list-after-delete.png` — FOUND
- `Artifacts/screenshots/02-03-capture-stub.png` — FOUND
- `UITests/_IdentifierProbe.swift` — CORRECTLY ABSENT (throwaway, deleted before commit)

Commits verified in `git log`: `01027e7`, `94bdd39`, `7cb28b8`, `b7ed586` — all FOUND.
