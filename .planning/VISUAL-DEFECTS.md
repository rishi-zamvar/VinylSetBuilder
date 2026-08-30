# Visual defects — found by looking at screenshots, not by tests

These are real and visible in `Artifacts/screenshots/`. Unit tests pass on all of them,
which is exactly why the screenshot matters.

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| ~~V1~~ | ~~**"1 records"** — pluralisation not handled~~ | **FIXED 2026-08-30 (plan 02-01).** `CrateListView` now uses `Text("^[\(count) record](inflect: true)")`. Verified on screen after a 5-second settle: `02-01-crate-list-pluralised.png` reads "Sunday Chill — 1 record" and "Friday Warehouse — 4 records". | — | Closed |
| ~~V2~~ | ~~Whole UI washed out to near-invisible grey~~ | **NOT A DEFECT — RESOLVED 2026-08-30.** Re-captured after a 4-second settle delay: `sim-settled-crate-list.png` shows correct label-black title and rows with grey secondary counts. The original capture caught the **launch fade animation**. | — | Closed |

## V1 fix — applied

Use an inflected format rather than string interpolation:

```swift
Text("^[\(count) record](inflect: true)")   // "1 record" / "4 records"
```

Automatic-grammar-agreement markdown; correct across locales without a manual branch.

## V2 — diagnosed, and the diagnosis mattered

The pallor is uniform across every text element, which points at an inherited modifier
rather than per-view styling. Check in this order:

1. A `.foregroundStyle(.secondary)` / `.opacity()` applied to a container and inherited.
2. A `.disabled(true)` on an enclosing view — disabled content renders dimmed, and it would
   also mean **the rows are not tappable**, which would be a functional bug wearing a
   cosmetic disguise. Check this first; it is the one with real consequences.
3. Mid-transition capture — the screenshot may have been taken during the launch fade. If so
   it is an artefact of the harness, not the app. **Re-screenshot after a short settle delay
   to rule this out before changing any code.**

**Outcome: cause 3 was correct.** The pallor was the launch fade, not styling.

This is why the rule exists. Restyling would have taken correct, well-contrasted code and
damaged it to satisfy an artefact of the capture harness — a real regression introduced to fix
an imaginary bug, and one that would have been very hard to trace back afterwards.

**Therefore, mandatory from here on: every screenshot is taken after a settle delay of at
least 3 seconds, and after confirming the app is actually running.** A screenshot taken during
a transition is not evidence.

## Standing instruction

Every phase that renders UI must capture a screenshot into `Artifacts/screenshots/` **after
a settle delay**, and any defect visible in it gets recorded here. Passing tests say the logic
is right; only the picture says the product is usable.
