# Phase 4 — Act I Sign-off: Every Screen, Photographed

**Planned:** 2026-08-30
**Owns:** zero feature requirements. Its deliverables are **a verdict** and **a clean ledger**.
**Standing instruction:** quality is the focal point, time is not a constraint.

---

## What this phase is

Act I claimed one thing: *every screen exists, is navigable in the simulator on stubbed data,
and is photographed.* This phase proves that claim or refuses it.

It is the act-level gate. It builds no feature. It closes what it can close with evidence,
carries what it cannot with a named owner and a written reason, and then computes a verdict
against rules fixed **before** the checks are run.

---

## The verdict rule — fixed in advance, so it cannot be fitted to the result

A gate you write after you have seen the output is not a gate. So the three possible verdicts
and the conditions for each are locked here, before plan 04-01 runs a single command.

### The seven sign-off gates

| ID | Gate | How it is proven |
|---|---|---|
| **S1** | Every state in MVP-SPEC §2's user flow has ≥ 1 committed photograph | a flow-coverage table in `Artifacts/screenshots/MANIFEST.md`, every row citing a filename |
| **S2** | Screenshot count equals **distinct screen-state count**, compared by **content hash** | md5 of every frame; every duplicate group named and explained (V14 is one such group) |
| **S3** | `./Scripts/screenshots.sh` regenerates the whole set from a purged host in **one command**, and the regenerated set matches the manifest's coverage rows | run twice, from a purged `Artifacts/screenshots/` both times |
| **S4** | `test.sh`, `build-app.sh`, `ui-test.sh` all exit 0 — `ui-test.sh` verified from **`build/ui.xcresult`** as well as from the log | two independent full runs, four numbers each (log rc, log count, xcresult passed, xcresult failed) |
| **S5** | Hygiene: zero `TODO`/`FIXME`; `CorePurityTests` green; zero `MusicUnderstanding`; zero `AsyncSequencer`/`BeamDivergenceCheck`; zero unreferenced symbols in `App/` and `VinylSetBuilderCore/Sources/` | `./Scripts/hygiene.sh`, every gate individually shown able to fail |
| **S6** | The requirement count is **re-derived by four independent commands** that must agree | see "Recounting" below |
| **S7** | Every open V-row in `VISUAL-DEFECTS.md` is either **closed with an evidence path** or **carried with a named owner phase and a written reason** | the rewritten ledger table |

Every gate in S1–S6 must additionally have been **shown able to fail** by a real negative
control. A gate that has never been red is a decoration.

### The three verdicts

- **SIGNED OFF** — S1 through S7 all hold, *and* `VISUAL-DEFECTS.md` has zero rows at Medium
  or above still open.
- **SIGNED OFF WITH NAMED CARRY** — S1 through S7 all hold, but one or more Medium-or-above
  rows remain open **and every one of them is provably outside Claude's authority to close**
  (blocked on an unanswered owner question, or on a capability a later phase builds). Each
  carry is named, owned and reasoned in the verdict document. The roadmap's phase-level
  criterion is then reported as **NOT MET**, in those words, rather than quietly re-worded.
- **REFUSED** — any of S1 through S7 fails. The verdict names exactly what is missing.
  A false sign-off is worth less than an honest failure.

**No gate may be narrowed, filtered or re-thresholded to change which verdict is reached.**
That is the rule V2 left behind, applied to this phase's own gates. If a gate is red, it is red.

### The one thing that is expected, and is not a licence

Two Medium rows are open today: **V3** (blocked on owner question U8) and **V12** (Phase 6
owns the fix). If both are still open at 04-05 and everything else holds, the verdict is
**SIGNED OFF WITH NAMED CARRY** — not SIGNED OFF. The distinction is the whole point.

**This is not permission to assume that outcome.** 04-05 evaluates S1–S7 from the evidence it
actually produces, and REFUSED is a live outcome for any of them.

---

## Locked decisions

These are decided here so no plan re-litigates them mid-execution.

### D-04-1 — V3 is NOT fixed in this phase

The not-included bucket names records `Vinyl 1…8` while the capture strip named the same
records `HIGHER` / `Zzz.` / `inckatecks*` four frames earlier in the same session
(`03-walk-07-done-sequenced.png` against `03-walk-04-strip-twelve.png`, three runs).

Two fixes are defensible — give `VinylEntry.label` the same first-candidate `Track.displayName`
fallback `SequencedRow.title` already has, or mark the fixture tracks `.resolved`. **Which one
is right is a product call about the owner's own workflow, asked as U8, and unanswered.**

Note also that the two fixes are *not* equivalent in their side effects: marking fixtures
`.resolved` would move the capture strip's measured `6 Read / 5 Partial / 1 Unread` tally,
which is a Phase 3 baseline. That asymmetry is written down here as evidence for U8, **not** as
a reason to pick for the owner.

**Decision: carry V3, owner Phase 4/U8, unfixed.** Act I signs off with it open under the
NAMED CARRY verdict, and the verdict says so plainly. Guessing would waste the question.

### D-04-2 — V6 is carried to Phase 11, not closed

V6 (double-digit running-order index alignment against a `minWidth: 20` monospaced column) has
been "not assessable" for two phases running. Closing it needs a crate with ≥ 10 *sequenced*
rows. `03-walk-07` reaches twelve records but all twelve are excluded, so the running order is
empty.

Manufacturing one means adding a third fixture crate, which would rewrite Phase 2's committed
walk (it asserts the crate list's contents and deletes down to empty) and invalidate all
fifteen `02-walk-*` frames. **Rewriting the walk during the phase whose job is to audit the
walk is the wrong change at the wrong time.**

**Decision: carry V6, owner Phase 11.** Phase 11 runs the app on the 12 real photographs and
re-screenshots the whole set after every swap; 10+ sequenced rows is the normal case there.

### D-04-3 — Every carry names a phase that actually re-touches the artefact

A carry to a phase that never opens the file again is an abandonment wearing a due date.
Recommended owners, to be confirmed row by row in 04-04:

| Row | Recommended owner | Why that phase and not another |
|---|---|---|
| V3 | Phase 4 / U8 | blocked on the owner, not on code |
| V6 | Phase 11 | first phase where a crate exceeds 9 sequenced rows |
| V9 | Phase 11 if 04-03 does not root-cause it | Phase 11 re-verifies `RootView`'s navigation after each of five swaps |
| V10 | Phase 10 | needs a fixed-aspect camera layer |
| V11 | Phase 4 / new U11 | behaving as designed (D-03-3); which number to show is the owner's |
| V12 | Phase 6 | the currency/decimal filter is SEG-03's, already specified by the OCR spike |
| V15 | Phase 6, re-assess | real segmentation drops the price-sticker fragments that make lines long; blocked on U9 either way |
| V16 | Phase 6 | de-duplication is SEG-03's filtering |

### D-04-4 — The photometric probe becomes a committed script

The Pillow probe has been written ad-hoc and run six times across plans 02-05 and 03-05, and
has never been committed. That is a tool the project depends on, living nowhere.
`Scripts/probe-frames.py` lands in 04-01. Pillow 12.1.1 is present on this machine (verified).

### D-04-5 — Screenshots are classified, not merely counted

`Artifacts/screenshots/` holds 45 PNGs. Only 33 come from the current suite. The rest are
per-plan evidence from 01-06, 02-01 and 02-03. The manifest classifies every file as:

- **regenerable** — written by the current suite, reproduced by `Scripts/screenshots.sh`
- **historical evidence** — not regenerable, but cited by name in a `.planning/` or `docs/`
  document, so deleting it breaks a defect's evidence path
- **orphan** — neither. Deleted.

`sim-settled-crate-list.png` is cited in **0** documents and is the one current orphan
candidate (measured 2026-08-30). Every other file is cited at least once.

---

## The two mandatory disciplines

### 1. Two observations, and say how many

Every behavioural claim in every SUMMARY carries its sample count. **Say "once" when it is
once.** Plans 02-03 and 02-04 both reached a confident wrong conclusion from a single
observation and 02-04's second run disproved its own first reading; that is why this rule
exists and why it is not optional.

### 2. A passing check must be provably able to fail

Run real negative controls, and confirm each from **two independent sources**: the command's
own output *and*, where a test is involved, `build/ui.xcresult`'s failed-test list — because
**a mutation can crash the runner rather than fail cleanly**, and a crashed runner is not a
red assertion.

**Prefer assertions that MEASURE over assertions that CHECK PRESENCE.** The sharpest lesson so
far: mutation J shrank the thumbnail tiles from 101 pt to 41 pt and **every count and existence
assertion in the test still passed** — `capture-thumb-21` existed, `capture-thumb-22` did not,
`21 records` rendered, tile 21 was reachable. Only a dimension comparison saw it.

Applied to this phase:
- the screenshot audit compares **content hashes and dimensions**, never a filename count
- V4's fix is verified by a **contrast ratio measured on the badge's pixels**, not by
  "the badge exists"
- V5's fix is verified by a **uniqueness assertion across every fixture crate**, not by
  reading the one line that was wrong

### Procedural rule, learned the hard way (mutation H)

**Commit a fix before mutating the file it lives in.** Reverting a mutation with
`git checkout -- <file>` also discards uncommitted work in that file.

---

## Recounting — four commands that must agree

A previous count was wrong in two directions at once and the errors cancelled into a plausible
total. One command cannot detect that. Four can:

```bash
grep -c "^- \[x\] \*\*" .planning/REQUIREMENTS.md                     # complete
grep -c "^- \[ \] \*\*" .planning/REQUIREMENTS.md                     # outstanding
grep -cE "^- \[.\] \*\*" .planning/REQUIREMENTS.md                    # total, independently
grep -oE '^- \[.\] \*\* [A-Z0-9]+-[0-9]+' ... | sort -u | wc -l       # distinct IDs
```

All four must be consistent: `complete + outstanding == total == distinct IDs == 67`. Plus:
`... | sort | uniq -d` must print nothing (no duplicate ID), and the ROADMAP phase table must
sum to the same 67.

Measured at planning time: **23 / 44 / 67 / no duplicates.** 04-05 re-derives it rather than
copying this line.

---

## Carried debt that is NOT Act I's, and must not be silently absorbed

Phase 4 records these, verifies them by command, and fixes none of them.

1. **`AsyncSequencer` and `BeamDivergenceCheck` do not exist.** Plan 01-05 was never executed.
   **SEQ-08, SEQ-09 and SEQ-10 are wholly outstanding**, not partly built. Phase 9's.

2. **SEQ-03 is REOPENED.** The owner replaced non-decreasing BPM with bidirectional adjacency
   on 2026-08-30, so `BeamSearchSequencer` enforces a retired spec and two test assertions —
   marked `⚠️ STALE` in place at commit `ce31189` — **pass while defending a rule that no
   longer exists.** Phase 9's.

3. **The stale-artefact inventory in `REQUIREMENTS.md` is itself wrong.** It says the old rule
   survives in *"five places"* and then lists **six** table rows, and a grep at planning time
   found a seventh artefact the table omits: `docs/MVP-SPEC.md:131` (*"bpm sequence is
   non-decreasing"*). Phase 4 **corrects the inventory** — that is bookkeeping, which is this
   phase's job — and **does not touch the artefacts**, which are Phase 9's.

The distinction is exact: Phase 4 owns the *ledger*, Phase 9 owns the *code*.

---

## Autonomy

**Every plan in this phase is `autonomous: true`.** No `gate="blocking"`, no
`<resume-signal>`. Anything needing a person or real hardware goes to
`.planning/UAT-PENDING.md` and execution continues.

Known human-only items entering this phase: **U1** (device install), **U4/U6** (is the set one
you would play), **U8** (V3's product call), **U9** (is the correction sheet fast),
**U10** (does the guide frame a real sleeve). **U11** is filed by 04-04 for V11.

---

## Verified state at planning time (2026-08-30)

| Fact | Value | How verified |
|---|---|---|
| `./Scripts/test.sh` | 168 green | plan 03-05, three runs |
| `./Scripts/build-app.sh` | BUILD SUCCEEDED | plan 03-05 |
| `./Scripts/ui-test.sh` | 6 tests green | three runs, log **and** `build/ui.xcresult` |
| Screenshots on disk | 45 files | `ls` at planning time |
| Requirements | 23 of 67 complete | four-command recount above |
| `TODO`/`FIXME` | rc=1 (none) | plan 03-05 |
| Working tree | clean, HEAD `ce31189` | `git status --short` empty |
| Pillow | 12.1.1 | `python3 -c "import PIL"` |
| Simulator | `4B4E1C1F-BED6-4812-9238-C151337265DA` | `.planning/TOOLCHAIN.md` |

---

## Plan structure

| Plan | Wave | Owns |
|---|---|---|
| 04-01 | 1 | the screen-state inventory, content-hashed; the committed probe; one command that regenerates the set |
| 04-02 | 1 | the hygiene sweep as an executable gate; the carried-debt inventory corrected |
| 04-03 | 2 | V4 and V5 closed with measurements; one bounded root-cause attempt at V9 |
| 04-04 | 3 | the defect ledger adjudicated row by row; U11 filed; the record brought true |
| 04-05 | 4 | the clean double re-run, the four-command recount, and the verdict — sign-off or refusal |
