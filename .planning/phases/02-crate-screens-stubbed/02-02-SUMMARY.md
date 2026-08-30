---
phase: 02-crate-screens-stubbed
plan: 02
subsystem: verification-harness
tags: [xcuitest, screenshots, simulator, xcodegen, scheme]
requires: []
provides:
  - XCUITest target `VinylSetBuilderUITests` (bundle.ui-testing)
  - shared scheme `VinylSetBuilder.xcscheme` with a real test action
  - `Scripts/ui-test.sh` — one-command unattended UI test run
  - `Scripts/collect-screenshots.sh` — PNGs out of the simulator onto the host
  - `ScreenshotRecorder.capture(_:settle:in:)` — the mandatory settle delay, in one place
affects:
  - 02-03 (adds accessibility identifiers the walk will use)
  - 02-04 (writes the 15-state walk on this harness)
  - 02-05 (uses the recorded luminance baseline to diagnose V2)
tech-stack:
  added: []
  patterns:
    - "screenshots are written twice: a file for collection, an attachment for debugging failures"
    - "UI assertions match crate names, never record-count strings — those get reworded"
key-files:
  created:
    - UITests/ScreenshotRecorder.swift
    - UITests/SmokeUITests.swift
    - Scripts/ui-test.sh
    - Scripts/collect-screenshots.sh
    - Artifacts/screenshots/02-smoke-crate-list.png
  modified:
    - project.yml
decisions:
  - "Declared the scheme in project.yml rather than relying on xcodebuild autocreation — the autocreated scheme has no test action"
  - "Smoke test asserts on crate names only; the record-count wording changed under it mid-run, which proved the point"
  - "Rejected an in-simulator stale-screenshot purge after measuring that the runner container is recreated every run"
metrics:
  duration: ~25 min
  tasks: 2
  files: 6
  completed: 2026-08-30
---

# Phase 2 Plan 02: UI Verification Harness Summary

An XCUITest target, a real shared scheme, and a settle-delay screenshot pipeline that puts a
committed PNG on the host from one shell command — proven end to end against the crate list
that already existed, before any later plan depends on it.

## The four facts 02-04 and 02-05 need

**1. The `xcodebuild test` invocation that worked** — first try, no fallbacks needed:

```bash
xcodebuild test \
  -project VinylSetBuilder.xcodeproj \
  -scheme VinylSetBuilder \
  -destination "id=4B4E1C1F-BED6-4812-9238-C151337265DA" \
  -resultBundlePath build/ui.xcresult \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

The `SYMROOT`/`OBJROOT` workaround from fallback 3 was **not** required — the 01-06
"Unable to find module dependency" defect does not reproduce under a scheme-based `test`
action, which has derived-data context that the bare target build lacks.

**2. The runner bundle identifier** `collect-screenshots.sh` resolved:

```
com.rishizamvar.VinylSetBuilderUITests.xctrunner
```

The primary guess was correct; the `simctl listapps` fallback path never executed.

**3. The capture signature:**

```swift
@discardableResult
static func capture(_ name: String,
                    settle: TimeInterval = ScreenshotRecorder.defaultSettle,  // 3.0
                    in testCase: XCTestCase) -> URL?
// ScreenshotRecorder.launchSettle == 4.0
```

**4. The luminance baseline** for `02-smoke-crate-list.png`, which is what 02-05 compares its
A/B launch-fade captures against:

```
size (1206, 2622)   mean 242.4   min 0   max 255
```

104,593 bytes. `min 0` means real black text pixels exist; `max 255` means a white ground. For
contrast, a screenshot caught mid-launch-fade — the V2 artefact — has its `min` far above 100.

## The accessibility tree, dumped 2026-08-30

Recorded because 02-03 must know what already carries an identifier and what does not. Elided
to the parts that matter:

```
NavigationBar, identifier: 'Crates'
  Other, identifier: 'plus', label: 'Add'
    Button, identifier: 'plus', label: 'Add'          <- FREE, already stable
  StaticText, label: 'Crates'
CollectionView
  Cell                                                 <- NO identifier; 02-03 must add one
    Button, label: 'Sunday Chill, 1 records'           <- merged row label
      StaticText, label: 'Sunday Chill'                <- children ALSO published
      StaticText, label: '1 records'
  Cell
    Button, label: 'Friday Warehouse, 4 records'
      StaticText, label: 'Friday Warehouse'
      StaticText, label: '4 records'
```

Three things follow, and 02-04 should not re-derive them:

- SwiftUI publishes **both** the merged `Button` label and each child `StaticText`. So a plain
  `app.staticTexts["Friday Warehouse"]` resolves — no substring matching needed for names.
- The toolbar `+` button already has `identifier: 'plus'` for free, from `Image(systemName:)`.
  02-04 can drive it today without 02-03 adding anything.
- The row `Cell`s carry **no** identifier. That is 02-03's job.

The rows were `isEnabled` and hittable in the dump, which independently re-confirms that V2 was
never a `.disabled(true)` bug.

## Deviations from Plan

### 1. [Rule 1 — Bug] The smoke test's first draft could have been vacuous

**Found during:** Task 1. The first version matched with
`app.descendants(matching: .any).matching(NSPredicate(...))`. It passed, but the xcodebuild log
rendered it only as `Waiting 10.0s for Any (First Match) to exist` — with no way to see whether
the predicate was actually applied. A green test that cannot be shown to discriminate is worth
nothing, and this one is the foundation of the phase's ship criterion.

**Fix:** Probed it two ways before trusting it — asserted a nonsense label
("Wednesday Nonexistent") was absent, which held, and dumped the full accessibility tree. The
tree then showed the exact-label `staticTexts` query resolves anyway, so the predicate helper
and its `XCUIElementQuery` extension were deleted as unnecessary. The shipped test is the
plan's original simpler form, now backed by evidence rather than assumption.

**Files modified:** `UITests/SmokeUITests.swift`. **Commit:** 6050300

### 2. [Rule 1 — Bug] Removed a stale-screenshot guard after measuring it was unnecessary

**Found during:** Task 2. I added a purge of the runner's `Documents` on the theory that stale
PNGs would survive between runs and let 02-04's `ls ... | wc -l == 15` gate pass on leftovers.

**Fix:** Measured it instead of believing it — compared the runner's data-container UUID across
two consecutive runs (`482ADB35-…` then `57F93CB4-…`). The runner is reinstalled every
`xcodebuild test` and gets a **brand new container each time**, so in-simulator staleness cannot
occur and the purge was dead code. Deleted it.

The hazard is real at the **host** end, though — `Artifacts/screenshots/` accumulates and
nothing clears it. That is documented at the top of `collect-screenshots.sh`, and the script now
prints the filenames it copied so a caller can assert on the run's actual output rather than on
a glob count. **02-04 must `rm -f Artifacts/screenshots/02-walk-*.png` before its run**, or a
run that captures fourteen states will still count fifteen and pass on a leftover.

**Files modified:** `UITests/ScreenshotRecorder.swift`, `Scripts/collect-screenshots.sh`.
**Commit:** b8ebb76

### 3. [Not a deviation, but load-bearing] The count string changed underneath the test mid-run

The accessibility dump taken at the start of this plan read `'1 records'`. The final screenshot
reads `'1 record'` — the concurrent executor fixed defect V1 while this plan was running. The
smoke test did not notice, because it asserts on crate names only. Had it followed the reflex of
matching on visible row text, it would have gone red for a reason that was not a regression.
**02-04 must hold this line for all fifteen states.**

## What was NOT done, deliberately

- **No accessibility identifiers were added.** The plan assigns every file under `App/` to
  02-03, and this plan touched none of them. `git status --short App/` is clean of my changes.
  The orchestrator's instruction that walk-driven controls carry stable identifiers is
  satisfied structurally rather than by code here: the smoke test asserts only on
  `FixtureCrates` names, which no later phase rewords, and the tree dump above hands 02-03 the
  exact list of elements still needing identifiers.
- **`Scripts/build-app.sh` untouched**, as required. `ui-test.sh` is a new, separate script.

## Blocked / failed

Nothing failed. One interruption, not a failure of this plan: a mid-run `xcodebuild test` went
red on
`VinylSetBuilderCore/Crates/CrateDetailModel.swift:103: value of type '[UUID]' has no member 'move'`
— uncommitted in-flight work from the concurrent 02-01 executor (`move(fromOffsets:toOffset:)`
is a SwiftUI API and Core's purity guard forbids SwiftUI). Out of scope, so it was not touched;
I polled until Core compiled again (~1 minute) and re-ran. It is fixed in their tree now.

## Verification, as actually run

| # | Gate | Result |
|---|---|---|
| 1 | `./Scripts/ui-test.sh` | exit 0, `** TEST SUCCEEDED **`, `Executed 1 test, with 0 failures` |
| 2 | shared scheme on disk | `VinylSetBuilder.xcodeproj/xcshareddata/xcschemes/VinylSetBuilder.xcscheme` exists |
| 3 | `./Scripts/collect-screenshots.sh` | exit 0, `collected 1 screenshot(s)` |
| 4 | Pillow probe | `size (1206, 2622) mean 242.4 min 0 max 255` — 104,593 bytes |
| 5 | `./Scripts/build-app.sh` | `** BUILD SUCCEEDED **` |
| 6 | `./Scripts/test.sh` | `Test run with 113 tests ... passed` |
| 7 | `git status --short App/` | empty |
| 8 | `grep -rn "TODO\|FIXME" UITests/ Scripts/` | no matches |

Gate 6 reads **113**, not the 88 recorded in the phase context — the concurrent 02-01 executor
added tests to Core during this run. All green; none of them are mine.

The harness ran green **six times** end to end during this plan, including the final clean
`./Scripts/ui-test.sh && ./Scripts/collect-screenshots.sh` chain with the artefact deleted
first. It is re-runnable and unattended.

## Known Stubs

None.

## Self-Check: PASSED

All five created files plus the generated shared scheme exist on disk; both commits
(6050300, b8ebb76) resolve; both new scripts are executable.
