---
phase: 04-act-i-signoff
plan: 03
subsystem: crate-detail-presentation
tags: [visual-defects, accessibility-identifiers, pixel-measurement, navigation-title, fixtures]
requires:
  - "Scripts/probe-frames.py (04-01)"
  - "Scripts/screenshots.sh (04-01)"
  - "Scripts/screenshot-audit.py (04-01)"
  - "Scripts/hygiene.sh (04-02)"
provides:
  - "badge-pair-notincluded-{n} / badge-pair-seq-{n} / not-included-row-{n} accessibility identifiers"
  - "UITests/BadgeContrastUITests.swift — SEQ-11 asserted on real pixels, both halves"
  - "VinylSetBuilderCore .../FixtureCratesTests.swift — label + position uniqueness, every crate"
  - "FixtureCrates.all — one list, and demoStore is built from it"
  - "probe-frames.py --region / --ink"
  - "V9's corrected repro and three rejected hypotheses, in VISUAL-DEFECTS.md"
affects:
  - ".planning/VISUAL-DEFECTS.md (V3 citation, V4 closed, V5 closed, V9 rewritten and carried)"
  - "Artifacts/screenshots/ (8 frames changed materially, 2 added)"
tech-stack:
  added: []
  patterns:
    - "element screenshots (XCUIElement.screenshot()) as the crop, so no coordinate arithmetic enters a pixel measurement"
    - "the same pixels measured by two independent implementations (in-test Swift histogram, host Pillow probe) that must agree"
    - "one fixture list (FixtureCrates.all) feeding both the app and its tests, so neither can drift"
key-files:
  created:
    - UITests/BadgeContrastUITests.swift
    - VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/FixtureCratesTests.swift
    - Artifacts/screenshots/04-badge-placeholder.png
    - Artifacts/screenshots/04-badge-complete.png
  modified:
    - App/Views/BadgePairView.swift
    - App/Views/SequencedRowView.swift
    - App/Views/NotIncludedSectionView.swift
    - App/Views/CrateDetailView.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureCrates.swift
    - Scripts/probe-frames.py
    - Scripts/screenshot-audit.py
    - Scripts/screenshots.sh
    - .planning/VISUAL-DEFECTS.md
decisions:
  - "V4's fix was applied, but the plan's own CONTRAST_MIN = 60 gate is reported as UNABLE to have caught it — it measures 125 on the defective badge. The threshold was NOT moved."
  - "A second gate (WCAG 2.2 AA, 4.5:1) was added, with its provenance and its after-the-fact selection stated in the source, because its number comes from the published standard and not from this repo's data."
  - "V9's stated rule is FALSE and was replaced by a measured one. V9 carried to Phase 11 with three rejected hypotheses and their numbers."
  - "RootView was NOT restyled. All three V9 experiments were reverted."
metrics:
  duration_minutes: 61
  tasks: 3
  ui_runs: 14
  completed: 2026-08-30
---

# Phase 04 Plan 03: Close V4 and V5, One Bounded Attempt at V9 — Summary

V4 and V5 are closed with re-runnable evidence and numbers; V9's two-phase-old rule was
**disproved by the first deliberate repro ever run on it**, replaced with a measured one, and
carried to Phase 11 with three hypotheses rejected and priced.

---

## What happened, at a glance

| Defect | Outcome | Decided by |
|---|---|---|
| **V4** placeholder badges near-invisible | **CLOSED** — 4.01:1 → **7.96:1**, complete pair still ahead at 18.27:1 | pixels, three independent AFTER runs |
| **V5** two fixture vinyls share `position: 2` | **CLOSED** — red before, red under the restored duplicate, naming `["Vinyl 3"]` and `[2]` | a test that was red first |
| **V9** no navigation title after the first sheet | **CARRIED to Phase 11** — with a *corrected* repro and 3 rejected hypotheses | a two-session A/B, four times |

---

## Task 1 — V4

### The four numbers, and the fifth one that matters more

Measured on element screenshots (`XCUIElement.screenshot()`, so the crop **is** the badge pair).

| | contrast (`mode − min`) | WCAG 2.2 ratio |
|---|---|---|
| placeholder, **before** | **125** | **4.01:1** |
| placeholder, **after** | **167** | **7.96:1** |
| complete, **before** | **245** | **19.30:1** |
| complete, **after** | **239** | **18.27:1** |

**Measurement counts.** BEFORE: measured **twice** (two independently captured runs) — contrast
125 / 245 on both, byte-for-byte agreement. AFTER: measured **three** times (the standalone run,
the post-fix full-suite run, and the final full-suite run) — 167 / 239 and 7.96 / 18.27 on all
three, identical to the unit. Cross-implementation: the in-test Swift histogram and
`python3 Scripts/probe-frames.py --ink 128` returned **the same integers** off the same PNGs, on
both the before and after sets, so neither implementation is only checking itself.

Both halves of SEQ-11 hold: legible (7.96 ≥ 4.5) **and** still quieter (167 < 239, 7.96 < 18.27).

### The finding the plan did not expect

`04-03-PLAN.md` fixed `CONTRAST_MIN = 60` in advance and forbade re-fitting it. It was not moved.
Measured on the **defective** badge it came back **125** — clearing its own floor by a factor of
two. **The plan's gate could not have caught V4 and never went red on it.** That is reported
rather than papered over, and the `≥ 60` assertion is still in the file, still at 60.

What does redden is **WCAG 2.2 §1.4.3 AA at 4.5:1** for text under 18 pt (the badge font is
`.caption`, 12 pt). This gate was chosen *after* the first proved non-discriminating, and the
source says so in as many words: its number comes from the published standard, would read the
same if no badge had ever been measured here, and is provably able to fail at 4.01:1.

### The fix

`App/Views/BadgePairView.swift`, two lines: `.background(.thinMaterial, in: Capsule())` →
`Color(uiColor: .tertiarySystemFill)`, and the incomplete foreground `.secondary` →
`.primary.opacity(0.7)`. The same "solid ground, not translucent material" move plan 03-03 made
for the capture strip's status pill — no third badge idiom. **No colour crossed into Core; D8
holds and `TrackBadges.placeholder` is untouched.**

### A root cause found on the way (Rule 1)

Step 1's identifiers did not work, and the reason was a real bug, not a typo.
`not-included-section` was applied in `CrateDetailView` to the **whole** `NotIncludedSectionView`,
and a container identifier propagates: the live accessibility dump showed **both bucket rows
coming back as `Other, identifier: 'not-included-section'`**, so `not-included-row-{n}` never
reached the tree at all and a typed query for the section matched three elements instead of one.
Moving it to the `DisclosureGroup`'s label fixes it at the source. Verified from a second dump:
`app.buttons["not-included-section"]` still resolves (the frozen contract the walk taps),
`not-included-row-1/2` resolve as `otherElements`, `badge-pair-notincluded-1/2` as `staticTexts`,
and the row's label and reason stay **separate leaf texts** — which is why `CrateWalkUITests`'
"rows appeared but carry no reason line" count keeps its meaning. `.contain` on the row rather
than `.combine`, for the same reason: a combined row swallows the badge pair's element.

The full UI suite was re-run immediately after the identifier step, before anything else, exactly
as the plan requires: **6 passed / 0 failed**, log and `build/ui.xcresult`. No walk assertion
broke, so no fallback was needed.

### Negative controls — both halves of SEQ-11, both provably able to fail

Committed before mutating, each time. Each produced a **clean assertion failure at a named line**,
confirmed from `build/ui.xcresult`'s failed-test list as well as the log — not a crashed runner.

| Mutation | Reddened | Evidence |
|---|---|---|
| `.thinMaterial` + `.secondary` restored | `BadgeContrastUITests.swift:143` — "reads at 4.01:1 … below WCAG 2.2 AA's 4.5:1" | xcresult `passed 0 / failed 1`. **The `≥ 60` assertion stayed GREEN at 125 throughout** — that is the direct evidence for the paragraph above. |
| incomplete style set to `.primary` (dimming removed) | `BadgeContrastUITests.swift:122` — "the complete badge pair's contrast (239) is not strictly greater than the placeholder's (239)" | xcresult `passed 0 / failed 1` |

Both reverted; `git status --short` empty after each.

---

## Task 2 — V5

`unresolvedVinyl` moved from `position: 2` to `3`. `FixtureCratesTests` asserts, over **every**
crate `FixtureCrates.all` exposes, that labels are unique and that positions are unique — the
label check first, because `"Vinyl \(position + 1)"` is only one of the routes to a duplicate
label and a position-only check would sail past any other.

**Red before the fix** (measured once, and it is deterministic arithmetic):

```
V5: crate 'Friday Warehouse' renders ["Vinyl 3"] on more than one vinyl.
    Labels were ["Vinyl 1", "Vinyl 2", "Vinyl 3", "Vinyl 3"].
V5: crate 'Friday Warehouse' reuses position(s) [2]. Positions were [0, 1, 2, 2].
```

Sunday Chill passed in the same run, so the loop is not reddening indiscriminately.

**Negative control** (after committing): `position: 2` restored → **both** assertions red again,
the label one naming `["Vinyl 3"]` and the position one naming `[2]`, exactly as the plan
demanded of them. Reverted, `git status --short` empty, suite green again.

**Plan fallback used, and stated.** `FixtureCrates` exposed crates only as separate computed
properties, so `static var all: [Crate]` was added — and `demoStore` was **rebuilt from it**
rather than keeping a second hand-written list. A third test asserts the two have not drifted
(`demoStore.summaries.count == all.count`) and that the list is non-empty, because a uniqueness
assertion over an empty list is vacuously true.

**Core suite: 168 → 171 green.** Nothing asserted on a `Vinyl N` display string anywhere, exactly
as plan 03-05 predicted; the UI suite was unaffected.

---

## Task 3 — V9: the rule was wrong

### Step 1 — the band, calibrated before it was trusted

Derived once from `02-walk-01-crate-list.png` by row-profiling dark pixels between the status bar
and the first list row, then **held fixed**: `--region 0,383,1206,74 --ink 128`. The area holds
two dark runs — the `+` toolbar glyph (rows 226–278, x 1065–1117) and the title `Crates` (rows
383–456, x 52–359). The band excludes the button on purpose; that is what makes ink 0 mean *no
title* rather than *no toolbar*.

| Frame | recorded previously | measured here |
|---|---|---|
| `02-walk-01-crate-list.png` | ~9498 | **9677**, identically on **two independently captured copies** (pre-regeneration and regenerated) |
| `03-03-capture-empty.png` | 11753 | **11746** (Δ7, 0.06%) |
| any title-less frame | 0 | **0** |

The 1.9% gap on 02-walk-01 comes from a capture no longer on disk. It is recorded, not tuned
away: moving the band to hit 9498 would be fitting the instrument to the number.

### Step 2 — the deliberate repro, which FAILED

launch → capture → present `NewCrateSheet` → **Cancel** → capture. Expected 9677 → 0.
Got **9677 → 9677**, and the two PNGs were **byte-identical (same md5)**.
Measured once; superseded immediately by the sharper A/B below, which measured the same claim
four more times.

**This is the large finding the plan flagged in advance.** V9's rule — *presenting and dismissing
a `.sheet` removes the large navigation title* — is false.

### Step 3 — bisecting the whole route in one session

Seven captures: launch list **9677** · after Cancel **9677** · crate detail **26230** · list again
**9677** · capture after **Create** **11746** · detail after Create **17050** · list after Create
**9677**. Every frame keeps its title. Neither the sheet, nor Create, nor route switching is
sufficient. `zz-v9-3-detail-no-sheet.png` was **looked at**: the Friday Warehouse detail with its
large title, the same screen `02-walk-06` photographs with no title of any kind.

### Step 4 — the A/B that isolates it

Two app sessions in one run, differing in exactly one thing:

| Session | Route | Title band ink |
|---|---|---|
| **A** | launch → new-crate sheet → type → **Create** → capture | **0** |
| **B** | launch → crate detail → back → new-crate sheet → type → **Create** → capture | **11746** |

> **The corrected rule: the navigation title is lost for the rest of the session if and only if
> the FIRST `Route` change of the session is the one driven from inside the sheet's `Create`.
> Insert any prior route change and the identical Create keeps every title.**

Measured **four times** — the baseline A/B and all three hypothesis A/Bs returned 0 / 11746
without variation.

It also explains the original 33-frame split without the sheet being the cause:
`CaptureWalkUITests` test 1 enters capture through Create-first and its frames read **0**, while
test 2 enters through **Add More** and reads **11746** — same file, same class, same build, two
sessions. `CaptureScreenUITests` also enters via Add More, and all four `03-03-capture-*` frames
have their title.

`02-walk-06-crate-detail-sequenced.png` was cropped and looked at directly: the bar carries only
the `Crates` and `Edit` buttons and the crate's name is **nowhere on the screen** — the title is
not demoted to inline, it is absent. The row's wording was corrected accordingly.

### Three hypotheses, three rejections, with their numbers

| # | Hypothesis | Change | A / B ink | Verdict |
|---|---|---|---|---|
| **H3** | inline/large inference latches after a presentation | `.navigationBarTitleDisplayMode(.large)` on the stack's content | **0 / 11746** | **REJECTED** |
| **H1** | view-identity churn — `.navigationTitle` re-applied to a new `_ConditionalContent` branch each swap | hoisted to ONE `.navigationTitle(title)` driven by `model.store.route`; removed from all three screens | **0 / 11746** | **REJECTED** — the title's application site is not the variable |
| **H2** | the sheet's own nested navigation container takes over title rendering | deleted `NewCrateSheet`'s `NavigationStack`, moved Cancel/Create into `Form` rows | **0 / 11746** | **REJECTED** |

All three reverted. **`RootView` was not restyled and carries no change from this plan** — the
rule V2 left behind, honoured.

### The carry

**V9 → Phase 11**, because Phase 11's criterion 2 re-runs the Phase 2 and Phase 3 walks and
regenerates the whole screenshot set after each of five stub swaps, so `RootView`'s navigation is
opened and re-verified there five times — and because what H1, H2 and H3 leave standing is the
navigation *bar's* own large-title state at the moment of the first root swap, a UIKit bridging
question rather than a modifier-placement one, worth opening once with the navigation code
already in hand rather than twice.

**Repro for Phase 11, one command.** Measure `--region 0,383,1206,74 --ink 128` on any frame from
a session whose first navigation was the sheet's Create → expect **0**. Do one crate-row tap and
back first → the same screen measures **11746**.

The probe test was throwaway and is **not** committed (plan 02-03's precedent).

---

## Screenshots — what changed and why

Every regenerable frame's md5 moved, because the simulator clock is in all of them. That number is
not the finding. Measured **below y=150**, the audit's own content band, against the previously
committed frames:

- **8 frames changed materially**, and they are exactly the 8 that render a badge pair:
  `02-walk-06` (21,900 px), `02-walk-07` (41,775), `02-walk-08` (41,762), `02-walk-09` (41,765),
  `02-walk-10` (41,761), `02-walk-12` (10,927), `02-walk-13` (10,934), `03-walk-07` (66,591).
- **26 frames changed ONLY in the clock**: 0 differing pixels below y=150, diff bbox entirely
  inside the status bar (e.g. `(168, 79, 276, 117)`).
- **10 historical frames byte-identical**, as the purge list intends.
- **2 files added**: `04-badge-placeholder.png`, `04-badge-complete.png` — V4's evidence.

`02-walk-07` was cropped old-against-new and **looked at**: `Vinyl 3` → `Vinyl 4` (V5), and the
placeholder dashes visibly darker on a solid capsule (V4).

Two scripts were taught about the new frames (Rule 3 — the audit would otherwise have called them
orphans and exited 1): `04-badge-` added to `REGENERABLE_PREFIXES` and to `screenshots.sh`'s purge
list, since the committed suite writes them on every run. The manifest's headline also stopped
claiming every frame is the same size — element screenshots are not full-screen ones, and a false
number in the document whose job is to carry true numbers is worse than a longer sentence.

---

## A tooling hazard worth more than the frame it was found on

`./Scripts/ui-test.sh -only-testing:…` **exited 0 having run zero tests** — twice, both times on
the first invocation after a UI-test source file was edited. `xcodebuild` printed
`Test Suite 'VinylSetBuilderUITests.xctest' passed` with no test cases inside it, and
`build/ui.xcresult` confirmed `passedTests 0, failedTests 0, totalTestCount 0`. Re-running the
identical command immediately afterwards ran the tests normally.

`Scripts/screenshots.sh` is already immune (it asserts `passed > 0` before collecting). A bare
`ui-test.sh` is not. **A green exit code from `ui-test.sh` is not evidence that anything ran.**

Relatedly, and contradicting `collect-screenshots.sh`'s header: the runner's data container is
**not** always fresh per `xcodebuild test`. One container was observed accumulating four separate
runs' output. Every measurement in Task 3 therefore purged its own frames from every simulator
container before running, and refused to collect if the run reported zero passes.

---

## Verification — every command run, with its result

| Command | Result |
|---|---|
| `./Scripts/test.sh` | **171 passed** (168 + 3 new), rc 0 |
| `./Scripts/build-app.sh` | **BUILD SUCCEEDED** (device SDK) |
| `./Scripts/ui-test.sh` | **7 passed / 0 failed**, log **and** `build/ui.xcresult` |
| `./Scripts/screenshots.sh` | rc 0, `route=test-results-summary passed=7 failed=0`, 36 collected |
| `python3 Scripts/screenshot-audit.py` | **AUDIT PASSED** — gates A, B, C green; 46 files, 44 distinct, 0 orphan |
| `python3 Scripts/probe-frames.py --check` | `SUSPECT: none (46 frames measured)` |
| `python3 Scripts/probe-frames.py --selftest` | all 8 cases pass, including the 4 new `--region`/`--ink` ones |
| `./Scripts/hygiene.sh` | **gates: 8 pass, 0 fail** |

Full UI suite run **three** times over this plan (after the identifier step: 6/0; after the V4
fix: 7/0; final: 7/0), all confirmed from the result bundle as well as the log. Fourteen UI runs
in total including the probes and mutations.

---

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 — Bug] `not-included-section`'s identifier was overwriting the new row identifiers**
- **Found during:** Task 1, Step 1, on the first live accessibility dump
- **Issue:** applied to the whole `NotIncludedSectionView`, it propagated onto both bucket rows,
  which came back as `Other, identifier: 'not-included-section'`. `not-included-row-{n}` never
  reached the tree, and a typed section query matched three elements instead of one.
- **Fix:** applied to the `DisclosureGroup`'s label instead. Frozen contract preserved
  (`app.buttons["not-included-section"]` still resolves) and verified on a second dump.
- **Files:** `App/Views/CrateDetailView.swift`, `App/Views/NotIncludedSectionView.swift`
- **Commit:** `c1fad19`

**2. [Rule 2 — Missing critical functionality] A second, externally-defined V4 gate**
- **Found during:** Task 1, Step 2 — the BEFORE measurement
- **Issue:** the plan's `contrast ≥ 60` measures **125** on the defective badge. It cannot fail on
  V4, so closing V4 on it would have been closing a defect with a gate that never saw it.
- **Fix:** WCAG 2.2 AA at 4.5:1 added alongside. The plan's threshold was **not moved**; both are
  asserted, and the source states plainly that this one was chosen second and why its number is
  not fitted to this data.
- **Files:** `UITests/BadgeContrastUITests.swift`
- **Commit:** `3cddd7d`

**3. [Rule 3 — Blocking] The audit would have failed on the new element screenshots**
- **Found during:** Task 2's regeneration
- **Issue:** `04-badge-*.png` matched no regenerable prefix and no citation, so Gate C would have
  called them orphans and exited 1. The manifest also claimed a single frame size for the set.
- **Fix:** `04-badge-` added to `REGENERABLE_PREFIXES` and to `screenshots.sh`'s purge globs;
  the manifest now prints a size histogram.
- **Files:** `Scripts/screenshot-audit.py`, `Scripts/screenshots.sh`
- **Commit:** `4b8e2f8`

**4. [Rule 1 — Bug] V3's evidence citation named a label V5's fix renumbered**
- **Fix:** `02-walk-07`'s rows are cited as `"Vinyl 2" / "Vinyl 4"` with the pre-04-03 reading kept
  alongside. V3's complaint is untouched — the name is still a position.
- **Commit:** `e7c1c23`

### Deviations from the plan's method, stated because they change what a number means

- **Task 3 spent its budget differently than written.** The plan proposed three blind hypotheses.
  After the deliberate repro failed, a seven-frame bisection and a two-session A/B were run first
  to *locate* the variable, and only then were H3, H1 and H2 tried against it. The hypothesis
  count is unchanged at three; what changed is that each was tested against a known repro rather
  than against a frame.
- **The V4 element-screenshot fallback was not needed.** `XCUIElement.screenshot()` returned real
  images for the combined pairs (228×61 and 178×60), so no `--region` cropping was substituted and
  the measurement method never switched.
- **The `.combine` fallback was not needed.** No existing walk assertion broke.

### Nothing FAILED

No check in this plan was left red, skipped, or reported without being run.

---

## Known Stubs

None. Nothing in this plan renders placeholder data or leaves a data source unwired.

## Self-Check: PASSED

Files claimed created, verified present on disk:
`UITests/BadgeContrastUITests.swift`, `VinylSetBuilderCore/Tests/VinylSetBuilderCoreTests/FixtureCratesTests.swift`,
`Artifacts/screenshots/04-badge-placeholder.png`, `Artifacts/screenshots/04-badge-complete.png`.

Commits claimed, verified in `git log`:
`9dbbcd0`, `c1fad19`, `3cddd7d`, `4f32f04`, `05a1dd2`, `4b8e2f8`, `9ba4b43`, `e7c1c23`.
