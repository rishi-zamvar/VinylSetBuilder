# Visual defects — found by looking at screenshots, not by tests

These are real and visible in `Artifacts/screenshots/`. Unit tests pass on all of them,
which is exactly why the screenshot matters.

| # | Defect | Evidence | Severity | Owner |
|---|--------|----------|----------|-------|
| V1 | **"1 records"** — pluralisation not handled | `01-06-crate-list.png`, row "Sunday Chill — 1 records" | Low, but it is the first thing anyone notices | Phase 1 polish |
| V2 | **Whole UI washed out to near-invisible grey** — title, rows and values all render at very low contrast against a white ground | `01-06-crate-list.png` — "Crates", both crate names and both counts are pale grey, not label-black | **Medium — an accessibility problem, not a taste one.** Fails contrast guidance and is hard to read on a bright screen, which is exactly where a DJ uses it | Phase 1 polish |

## V1 fix

Use an inflected format rather than string interpolation:

```swift
Text("^[\(count) record](inflect: true)")   // "1 record" / "4 records"
```

Automatic-grammar-agreement markdown; correct across locales without a manual branch.

## V2 — diagnose before fixing

The pallor is uniform across every text element, which points at an inherited modifier
rather than per-view styling. Check in this order:

1. A `.foregroundStyle(.secondary)` / `.opacity()` applied to a container and inherited.
2. A `.disabled(true)` on an enclosing view — disabled content renders dimmed, and it would
   also mean **the rows are not tappable**, which would be a functional bug wearing a
   cosmetic disguise. Check this first; it is the one with real consequences.
3. Mid-transition capture — the screenshot may have been taken during the launch fade. If so
   it is an artefact of the harness, not the app. **Re-screenshot after a short settle delay
   to rule this out before changing any code.**

Do not restyle anything until cause 3 is excluded — otherwise you would be fixing a
screenshot-timing artefact by damaging correct code.

## Standing instruction

Every phase that renders UI must capture a screenshot into `Artifacts/screenshots/` **after
a settle delay**, and any defect visible in it gets recorded here. Passing tests say the logic
is right; only the picture says the product is usable.
