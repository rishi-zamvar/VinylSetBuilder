---
phase: 04-act-i-signoff
plan: 02
subsystem: build-hygiene
tags: [hygiene, gates, negative-controls, dead-code, carried-debt, ledger]
requires:
  - "Scripts/test.sh (SETUP-04)"
  - "CorePurityTests.swift (SETUP-02 purity guard)"
provides:
  - "Scripts/hygiene.sh — S5 and S6 decidable by one command, eight independently-exiting gates"
  - ".planning/phases/04-act-i-signoff/CARRIED-DEBT.md — the corrected 17-artefact monotonic-BPM inventory"
affects:
  - "04-05 (verdict) consumes hygiene.sh for S5/S6"
  - "Phase 9 inherits CARRIED-DEBT.md as its work list"
  - "Phase 7 inherits the MetadataResolving seam, now conformance-free"
tech-stack:
  added: []
  patterns:
    - "gate script uses set -uo pipefail, NOT -e, so one red gate cannot hide the other seven"
    - "self-match avoidance by fragment concatenation rather than --exclude"
    - "SKIP counts as failure; a skipped gate is not a passed gate"
    - "ledger rows keyed on matched text, line numbers pinned to a commit SHA"
key-files:
  created:
    - Scripts/hygiene.sh
    - .planning/phases/04-act-i-signoff/CARRIED-DEBT.md
  modified:
    - .planning/REQUIREMENTS.md
  deleted:
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/NaiveBPMSortSequencer.swift
    - VinylSetBuilderCore/Sources/VinylSetBuilderCore/Fixtures/FixtureMetadataResolver.swift
decisions:
  - "MetadataResolving kept despite zero references — it is a seam Phase 7 (RES-01..08) implements"
  - "The monotonic-BPM artefact count is 17, not the five or six previously recorded"
  - "Three green assertions defend the retired BPM rule, not the two that carry STALE markers"
  - "No artefact edited: Sequencing/ is untouched since 59e2f3c so Phase 9 starts clean"
metrics:
  duration: "~25 min"
  tasks: 3
  commits: 3
  completed: 2026-08-30
---

# Phase 4 Plan 02: Hygiene Gates and the Corrected Debt Ledger — Summary

`./Scripts/hygiene.sh` turns the roadmap's hygiene sentence into eight independently-exiting
gates, each observed red on a real mutation; two dead fixture stubs are gone; and the
monotonic-BPM ledger — which said "five places", listed six rows, and was missing the
enforcement itself — is corrected to **17 artefacts**, derived by two passes with two methods.

---

## Measurement counts, stated up front

Every claim below carries how many times it was measured. Most greps were run **once**, and
that is fine, provided it says so.

| Claim | Times measured |
|---|---|
| Reachability table for the 8 named symbols | 1 (plus the plan's own planning-time run — agreed exactly) |
| Full unreferenced-declaration scan | 3 (standalone; then twice more via gate G5) |
| `./Scripts/test.sh` = 168 green | 3 (post-deletion, re-run with rc captured, final) |
| `./Scripts/build-app.sh` = BUILD SUCCEEDED | 2 |
| `./Scripts/hygiene.sh` = 8 pass, rc=0 | 4 (pre-REQUIREMENTS edit, post-edit, and twice at final verification) |
| Monotonic-BPM two-pass union = 32 hits | 2 (byte-identical `diff`, across an intervening commit from plan 04-01) |
| Requirement counts 23/44/67/67 | 2 (by hand, then by gate G7) |
| `Sequencing/` unmodified since `59e2f3c` | 2 (`git log`, `git diff --stat`) |
| Each of the 8 negative controls | 1 each (9 runs total — G2 was run twice, see NC-G2) |
| Naming-convention audit | 1 |

---

## Task 1 — dead code deleted, seams kept

### The plan's reachability table: re-derived, and it agreed exactly

All eight rows reproduced identically. **No disagreement to report** — the interface block was
not stale.

| Symbol | App/ | Sources/ | Tests/ | UITests/ | Verdict |
|---|---|---|---|---|---|
| `NaiveBPMSortSequencer` | 0 | 1 | 0 | 0 | dead — **deleted** |
| `FixtureMetadataResolver` | 0 | 1 | 0 | 0 | dead — **deleted** |
| `MetadataResolving` | 0 | 2 | 0 | 0 | seam + its one dead conformance |
| `LabelSegmenting` | 0 | 3 | 1 | 0 | live |
| `FixtureLineSegmenter` | 1 | 1 | 1 | 0 | live |
| `PhotoCapturing` | 1 | 2 | 0 | 0 | live |
| `Sequencing` | 0 | 4 | 0 | 0 | live inside Core |
| `BeamSearchSequencer` | 1 | 2 | 3 | 0 | live |

> **Process finding, worth recording.** The first attempt at this table ran under `zsh`, where
> unquoted `--include=*.swift` fails glob expansion. Every cell came back **`0`** — a table that
> looked like "everything is dead" and was entirely an artefact of the shell. It was caught only
> because `zsh` printed `no matches found` alongside the numbers. Re-run under `bash` with the
> pattern quoted. A measurement that returns a uniform answer deserves suspicion before it
> deserves belief.

### Every symbol the full scan flagged — including the ones kept

The scan covered every `public` type/func/var declared under `VinylSetBuilderCore/Sources/` and
every type under `App/`, counting referencing files other than the declaring file across all
four trees. It flagged **five** symbols, then a sixth after the deletions:

| Symbol | File | Refs | Judgement |
|---|---|---|---|
| `NaiveBPMSortSequencer` | `Fixtures/NaiveBPMSortSequencer.swift` | 0 | **DELETED.** Its own doc comment: *"Placeholder Sequencing used until plan 01-04's BeamSearchSequencer exists … so plan 01-06 doesn't block on plan 01-04."* Both plans shipped. It outlived its stated reason by name |
| `FixtureMetadataResolver` | `Fixtures/FixtureMetadataResolver.swift` | 0 | **DELETED.** Measurement confirmed zero external references. Phase 11 criterion 3 — *"fixture implementations remain only where a test needs them"* — brought forward |
| `OrderingMode` | `Crates/CrateDetailModel.swift` | 0 | **KEPT.** Reachable only through `CrateDetailModel.orderingMode`, whose type is inferred at the call site, so a name-exact scan structurally cannot see the use. `ManualOrderTests.swift:56` exercises it. Allowlisted in G5 with this reason |
| `Secrets` | `App/Generated/Secrets.swift` | 0 | **KEPT and excluded from the gate.** Gitignored (`.gitignore:27`), machine-written at build time from `~/.config/keys/`. Not part of the tree under audit; G5 skips `*/Generated/*` wholesale |
| `VinylSetBuilderApp` | `App/VinylSetBuilderApp.swift` | 0 | **KEPT.** `@main` entry point — unreferenced by definition. Allowlisted |
| `MetadataResolving` | `Resolution/MetadataResolving.swift` | 0 **after** the deletions | **KEPT.** See below |

### `MetadataResolving` — the distinction the plan said must not be collapsed, met in the wild

Deleting `FixtureMetadataResolver` removed the protocol's only conformance, so `MetadataResolving`
dropped to zero references and **gate G5 went red on it the first time the script ran**. That is
the plan's warning arriving as a live event rather than a hypothetical.

It is a **declared seam**, not dead code, and it is allowlisted in `hygiene.sh` with its owning
phase named in the comment. Every kept seam, with the phase that implements it:

| Seam | Implemented by | Refs today |
|---|---|---|
| `MetadataResolving` | **Phase 7, RES-01…08** | 0 — conformance-free until Phase 7 |
| `LabelSegmenting` | **Phase 6, SEG-01…06/08** | live |
| `PhotoCapturing` | **Phase 10, CAP-01/04** | live |
| `Sequencing` | **Phase 9, SEQ-05/08/09/10** | live |

The rule applied: *keep a protocol iff a NAMED future phase's requirements implement it; delete
a conformance nothing reaches.* A seam kept without naming its phase is indistinguishable from
dead code that survived on a hunch, so all four are named above.

### Naming consistency — no deviations, nothing renamed

- **174 / 174** test functions match `test_givenX_whenY_thenZ` (168 Core + 6 UITests, which
  reconciles exactly with `test.sh`'s 168 and `ui-test.sh`'s 6). Zero deviations.
- All 12 `App/Views` types match `{Thing}View` / `{Thing}Sheet` / `{Thing}Strip`.
- `Fixtures/` types match `Fixture{Thing}` — with the single exception of
  `NaiveBPMSortSequencer`, which was deleted in this task, so the exception is now moot.
- **Nothing was renamed.** The identifier contract is frozen; no rename was needed, so no
  `accessibilityIdentifier` string was put at risk.

### Deviation: the plan's dangling-reference verify was wrong as written

The plan expects `grep -rn "NaiveBPMSortSequencer\|FixtureMetadataResolver" App/ VinylSetBuilderCore/ UITests/`
to return **rc=1**. It returned **rc=0**, matching two files:

```
VinylSetBuilderCore/.build/arm64-apple-macosx/debug/VinylSetBuilderCore.build/NaiveBPMSortSequencer.d
VinylSetBuilderCore/.build/arm64-apple-macosx/debug/VinylSetBuilderCore.build/FixtureMetadataResolver.d
```

Both are stale SPM dependency manifests under gitignored `.build/` (`.gitignore:11`), naming
source files that no longer exist. `swift build` does not garbage-collect orphaned `.d` files.
Scoped to Swift sources the command returns **rc=1** with no hits. The two stale artefacts were
removed and the plan's exact command then returned **rc=1**. Every grep in `hygiene.sh` carries
`--exclude-dir=.build` for this reason, with a comment saying why.

Historical references in `.planning/` (`01-01-PLAN.md`, `02-05-SUMMARY.md`, `research/ARCHITECTURE.md`
and others) are **intentional record**, not dangling references, and were left alone. The one
`.planning/` reference that was a live claim — `REQUIREMENTS.md`'s artefact row for
`Fixtures/NaiveBPMSortSequencer.swift:2` — is corrected in Task 3.

`02-05`'s `deferred-items.md` asked Phase 4's sweep to *"confirm it is still unreferenced and
either delete it or record why it stays."* Confirmed, and deleted. **D-02-05-1 is closed.**

---

## Task 2 — `Scripts/hygiene.sh`, and eight proofs it can fail

`./Scripts/hygiene.sh` → **`gates: 8 pass, 0 fail`**, rc=0, 8 `PASS` lines. Run four times.

| ID | Gate | Result |
|---|---|---|
| G1 | no work markers across the five swept trees | PASS |
| G2 | `CorePurityTests` green, and **exactly 1 test ran** | PASS |
| G3 | no `MusicUnderstanding` (iOS 27 SDK, not installed) | PASS |
| G4 | `AsyncSequencer` / `BeamDivergenceCheck` still absent — re-confirming the Phase 9 gap, not closing it | PASS |
| G5 | no unreferenced declarations outside a reasoned allowlist | PASS |
| G6 | no `VinylEntry.label` in `App/` (D-03-6) | PASS |
| G7 | four requirement-count commands agree with each other | PASS — 23 + 44 = 67 = 67 distinct, no duplicate |
| G8 | the monotonic-BPM inventory accounts for every sweep hit | PASS — 17 artefacts + 15 non-artefacts = 32 |

**Design points that were load-bearing, not decoration:**

- `set -uo pipefail`, **not** `-e`. Every gate runs, so one red gate cannot hide the state of
  the other seven. Confirmed in every negative control: each showed 7 pass, 1 fail.
- **G1's self-match hazard**: the script lives in `Scripts/`, which it sweeps. The pattern is
  built by fragment concatenation (`printf '\\bTO''DO\\b|…'`) so the literal token never appears
  in the file and no `--exclude` of its own filename is needed — an exclusion would make the
  gate structurally unable to see a real marker in itself.
- **`\b` bounds on G1 are load-bearing**, discovered by running it: `\bXXX\b` is needed because
  `Scripts/generate-secrets.sh:73` and `generate-ocr-fixtures.sh:27` both use legitimate
  `mktemp` templates ending `XXXXXX`. Unbounded `XXX` reddened the gate on two innocent files.
- **G2 shells out** to `Scripts/test.sh --filter CorePurity` rather than re-implementing the
  purity scan. There is one purity guard and it lives in `CorePurityTests.swift`.
- **G2 asserts exactly 1 test ran**, not merely rc=0, because `swift test --filter` can exit 0
  on a filter that matches nothing. A gate that passes when it ran nothing is the worst kind.
- **SKIP increments the failure count.** A skipped gate is not a passed gate, and the script
  exits non-zero on one.
- **G6's ceiling is documented in the script**: it matches the qualified name `VinylEntry.label`
  only, so `someEntry.label` on an inferred-type local would slip past. That is D-03-6's own
  enforcement ceiling — the same textual gate plan 03-01 used — not a new one introduced here.
  Widening it to `.label` produces false positives on the compliant `row.label` and
  `item.status.label`.

### The eight negative controls — all eight red, each naming its violation

Task 1 and the script were **committed before any mutation** (`073228f`, `4a1e2fc`), per
mutation H's lesson that `git checkout --` also discards uncommitted work in the file.
Every control was reverted and `git status --short` confirmed clean on the paths this plan owns.

| # | Mutation | rc | Exact FAIL text | Reverted clean |
|---|---|---|---|---|
| NC-G1 | `App/Views/_nc.swift` with a `TO`+`DO` comment | 1 | `FAIL G1  no work markers in the swept tree — 1 hit(s)` / `App/Views/_nc.swift:1:// TODO: negative control for hygiene gate G1` | ✅ |
| NC-G2a | `import UIKit` in `Domain/Track.swift` | 1 | `FAIL G2  CorePurityTests did not pass (rc=1, runner reported no test count)` / `…/Domain/Track.swift:1:8: error: no such module 'UIKit'` | ✅ |
| NC-G2b | `// UIKit` in `Domain/Track.swift` | 1 | `FAIL G2  CorePurityTests did not pass (rc=1, runner reported 1 test count)` / `↳ Core purity violated: Track.swift: UIKit` | ✅ |
| NC-G3 | `// MusicUnderstanding` in a Core source | 1 | `FAIL G3  no MusicUnderstanding reference — 1 hit(s)` / `VinylSetBuilderCore.swift:3:// MusicUnderstanding` | ✅ |
| NC-G4 | `// AsyncSequencer` in a Core source | 1 | `FAIL G4  AsyncSequencer/BeamDivergenceCheck still absent … — 1 hit(s)` / `VinylSetBuilderCore.swift:3:// AsyncSequencer` | ✅ |
| NC-G5 | `public struct _NCUnused {}` in a Core source | 1 | `FAIL G5  unreferenced declaration(s): _NCUnused` / `_NCUnused  (…/VinylSetBuilderCore.swift)` | ✅ |
| NC-G6 | a `VinylEntry.label` line in `App/Views/CrateListView.swift` | 1 | `FAIL G6  no VinylEntry.label reference in App/ (D-03-6) — 1 hit(s)` / `CrateListView.swift:64:…VinylEntry.label` | ✅ |
| NC-G7 | duplicate the `**SEQ-01**` requirement line | 1 | `FAIL G7  requirement count disagrees` / `total = 68 but distinct IDs = 67` / `duplicate requirement ID(s): SEQ-01` / `total = 68 against 67 expected (distinct = 67)` | ✅ |
| NC-G8 | delete row `A11` from the inventory table | 1 | `FAIL G8  monotonic-BPM inventory disagrees with the tree` / `inventory declares ARTEFACT_COUNT=17 but the table has 16 A-rows` / `A-rows(16) + N-rows(15) = 31, but the live two-pass sweep finds 32 hits — 1 unaccounted` | ✅ |

**NC-G7 — both halves work.** The plan singled this out because it is the exact error class that
produced a plausible wrong count before, and asked whether the gate reddens on the duplicate,
the count mismatch, or both. It reddens on **both, independently**: one line names `SEQ-01` as
duplicated, a separate line reports `total = 68 but distinct IDs = 67`. Neither depends on the
other. The gate is not half-working.

> Minor plan inaccuracy: the plan specifies duplicating `- [ ] **SEQ-01**:`. `SEQ-01` is
> actually `- [x]` (complete, line 87). The mutation was applied to the line as it really is.
> The arithmetic is equivalent either way: with `[x]` it is 24 + 44 = 68; with `[ ]` it would
> be 23 + 45 = 68. `complete + outstanding == total` stays self-consistent under duplication,
> which is precisely why the *distinct-ID* check is the one that catches it.

### NC-G2 forced a real fix, and it is the plan's own hazard

The plan's NC-G2 mutation, `import UIKit` in `Domain/Track.swift`, **does not make
`CorePurityTests` go red.** UIKit does not exist for the macOS test triple
(`arm64-apple-macos14.0`), so the package stops compiling and the runner never prints a
`Test run with N tests` line at all. G2 parsed for that line first, found nothing, and reported
**SKIP** — describing a broken build as a missing toolchain. It still exited non-zero, but the
message was wrong.

This is `CONTEXT.md`'s own warning arriving in practice: *"a mutation can crash the runner
rather than fail cleanly, and a crashed runner is not a red assertion."*

**Fixed** (`026e77c`): G2 now checks the exit code **before** parseability, so a build failure
reports FAIL with the compiler's own error naming `Track.swift`. Both variants were then run,
because they prove different things:

- **NC-G2a** (`import UIKit`) — the **compiler** catches it. Proves the gate notices a broken
  build. Does **not** prove the purity guard works.
- **NC-G2b** (`// UIKit`) — compiles, so the **purity guard** catches it, and the FAIL detail
  reads `Core purity violated: Track.swift: UIKit`, naming the file and the token exactly as the
  plan required.

Only NC-G2b establishes that `CorePurityTests` can see a violation. Both were confirmed from
**two independent sources**: `hygiene.sh`'s summary and `./Scripts/test.sh`'s own output
(rc=1 in both cases, with the failing assertion named in NC-G2b's log).

---

## Task 3 — the corrected carried-debt ledger

`.planning/phases/04-act-i-signoff/CARRIED-DEBT.md`, pinned at commit `073228f`, every row keyed
on its **matched text** rather than its line number.

### 1. `AsyncSequencer` and `BeamDivergenceCheck` do not exist — re-confirmed

`grep -rn --exclude-dir=.build "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/`
→ **rc=1**, no hits. Measured twice (by hand, then as gate G4). Both agreed.

**SEQ-08, SEQ-09 and SEQ-10 are wholly outstanding, not partly built.** Phase 9 inherits
`01-05-PLAN.md`, `.planning/open-questions/RejoinTests.swift.wip`, and `Q1-sequencer-determinism.md`.

### 2. The artefact count is 17 — neither five nor six

**Both passes' numbers, as required, rather than quietly publishing the larger one:**

| Pass | Method | Hits |
|---|---|---|
| Pass 1, **as specified at planning time** (case-sensitive) | prose word list | **14** |
| Pass 1b, same word list run **case-insensitively** | prose word list | **20** |
| Pass 2 | structural — `bpm! >= `, `b >= a`, `canFollow`, `⚠️ STALE` | **13** |
| **Union of 1b and 2** | | **32** |

Of those 32 hits, **17 are artefacts** and **15 are non-artefacts**, each classified individually
and by name in `CARRIED-DEBT.md` §2a and §2b. That identity is gate G8.

**What the second pass found that the first could not:**

- **Case sensitivity cost three artefacts.** The specified grep is case-sensitive and silently
  missed `BPMRules.swift:10` (*"**N**on-decreasing AND within tolerance"*), `BPMRules.swift:11`
  (*"**M**onotonic BPM is an MVP simplification"*) and `BeamSearchSequencer.swift:51`
  (*"**A**scending by folded BPM"*) — three artefacts, all inside the sequencer itself, all lost
  to a capital letter.
- **The enforcement has no words in it.** `BPMRules.swift:17` is
  `b >= a && (b - a) <= tolerance + 1e-9`. The `b >= a` clause **is the retired rule, in
  executable code**. It contains not one word from any prose list, so no prose pass could ever
  find it. The old ledger claimed the rule survived in comments; it survives in code, and only
  pass 2 sees that.
- **A third stale test.** `test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending`
  (`BeamSearchSequencerTests.swift:61`, assertion at `:65`) asserts `b.bpm! >= a.bpm!` and is
  **not marked** `⚠️ STALE`. Its display name — *"Input order never matters — the output always
  ascends"* — reads as a determinism test, which is presumably how it escaped the `ce31189`
  sweep.

**Eleven distinct errors in the old inventory** are tabulated in `CARRIED-DEBT.md` §2d. Beyond
the case-sensitivity and enforcement misses above: `docs/MVP-SPEC.md:131` and `:223`,
`ROADMAP.md:304` and `:310` were all omitted; `ROADMAP.md:385` had **drifted to `:415`**, which
is why every row is now keyed on matched text and pinned to a SHA.

**One previously-listed row was resolved rather than carried.**
`Fixtures/NaiveBPMSortSequencer.swift:2` was deleted in Task 1, so Phase 9 inherits 17 artefacts,
not 18. Related correction: the plan states this artefact's wording *"sorts the rest ascending"*
would not match the pass-1 grep. It **would** have — `ascending` is in the word list. The real
reason it does not appear in the 32-hit sweep is simply that the file no longer exists.

**One row was reclassified rather than deleted.** `BPMRulesTests.swift:33` was a plain section
comment asserting the rule when the old inventory listed it — correct when written — and commit
`ce31189` rewrote it into a `⚠️ STALE` supersession marker. It is now `N08`, alongside the two
other supersession markers, since a marker warns about the rule rather than asserting it.

### The three green tests defending a retired spec, named individually

All 168 tests pass. **Three of those passes are worthless, and one of the three is not flagged
at all.**

1. **`test_givenSequence_whenInspected_thenBPMIsNonDecreasing`** —
   `BeamSearchSequencerTests.swift:37`, assertion at `:41`. Marked `⚠️ STALE` at `ce31189`.
   **It passes while defending a rule the owner retired on 2026-08-30.**
2. **`test_givenDecreasingBPM_whenGated_thenRejected`** — `BPMRulesTests.swift:47`, assertion at
   `:48`. Marked `⚠️ STALE` at `ce31189` via the section `MARK`. It asserts
   `canFollow(174, 170, tolerance: 4) == false`; under bidirectional adjacency `|174 − 170| = 4 ≤ 4`,
   so the correct expectation is **`true`**.
   **It passes while defending a rule the owner retired on 2026-08-30.**
3. **`test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending`** —
   `BeamSearchSequencerTests.swift:61`, assertion at `:65`. **UNMARKED.**
   **It passes while defending a rule the owner retired on 2026-08-30.**

> `CONTEXT.md` and `REQUIREMENTS.md` both say **two** assertions are marked `⚠️ STALE`. That is
> accurate about the *markers*, and inaccurate as a count of assertions defending the retired
> rule. **Phase 9 must rewrite three, not two.**

### The unmodified-baseline claim is TRUE

```
$ git log --oneline -- VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/
59e2f3c feat(01-04): implement BeamSearchSequencer (SEQ-02/03/04/06)
7b9a037 feat(01-03): implement BPMRules fold and gate (SEQ-01)
ab3566b feat(01-03): implement Camelot wheel, distance, and ported pitch tables (SEQ-01)
36ab5cf feat(01-01): add protocol seams and Phase-1 fixture stubs
```

Nothing after `59e2f3c`. `git diff --stat ce31189 HEAD -- …/Sequencing/` is **empty**. Two
observations, both agreeing. **No artefact was edited** — not the comment in
`BeamSearchSequencer.swift`, not the doc comment in `SequenceResult.swift`, not MVP-SPEC §5 or
§9, not any of the three stale tests.

`MVP-SPEC.md` still carries **no marker** saying `.planning/SEQUENCER-SPEC.md` supersedes its §5,
so a reader opening the spec is told the retired rule with nothing to warn them. **That marker
was deliberately not added**: MVP-SPEC §5 and §9 are artefacts A04 and A05, they belong to
Phase 9, and adding a marker would edit an artefact and falsify the baseline claim above.

### `REQUIREMENTS.md` corrected, and nothing else touched

*"five places"* → *"seventeen places"*, the missing rows added, the drifted line number fixed,
the resolved and reclassified rows struck through with reasons, and the commit SHA the line
numbers are valid at recorded. **The recount stays 04-05's and the SEQ-03 checkbox stays
unticked** — G7 still reports 23 complete / 44 outstanding / 67 total, unchanged.

---

## Verification

| Check | Result |
|---|---|
| `./Scripts/hygiene.sh` | rc=0, `gates: 8 pass, 0 fail` (4 runs) |
| `./Scripts/hygiene.sh \| grep -c "^PASS"` | **8** |
| Eight negative controls, each naming its violation, each reverted | **8/8 red** (9 runs; G2 twice) |
| `git status --short` on this plan's paths after every revert | empty |
| `./Scripts/test.sh` | rc=0, **168 green** — unchanged by the deletions (3 runs) |
| `./Scripts/build-app.sh` | rc=0, **BUILD SUCCEEDED** (2 runs) |
| `git diff --stat ce31189 HEAD -- …/Sequencing/` | **empty** |
| `grep -rn "NaiveBPMSortSequencer\|FixtureMetadataResolver" App/ VinylSetBuilderCore/ UITests/` | **rc=1** |
| `grep -q "MVP-SPEC" CARRIED-DEBT.md` | rc=0 |
| `grep -q "ce31189" CARRIED-DEBT.md` | rc=0 |
| `CARRIED-DEBT.md` row count vs live sweep | 17 + 15 = **32** = sweep hits |

---

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 — Bug] G2 reported SKIP for a build failure**
- **Found during:** Task 2, negative control NC-G2
- **Issue:** G2 parsed for the runner's test-count line before checking the exit code. The
  plan's own NC-G2 mutation stops the package compiling, so that line is never printed, and a
  broken build was reported as *"no toolchain"*.
- **Fix:** rc is checked first; a non-zero exit reports FAIL with the compiler's error naming
  the file. Both a compile-breaking and a compile-clean variant were then run, because only the
  latter proves the purity guard itself can see a violation.
- **Files modified:** `Scripts/hygiene.sh`
- **Commit:** `026e77c`

**2. [Rule 1 — Bug] G1's `XXX` matched legitimate `mktemp` templates**
- **Found during:** Task 2, baseline run
- **Issue:** unbounded `XXX` matched `mktemp "$OUT_DIR/.Secrets.swift.XXXXXX"` in
  `Scripts/generate-secrets.sh:73` and the equivalent in `generate-ocr-fixtures.sh:27`.
- **Fix:** `\b` word bounds on all four markers. `\bXXX\b` does not match a run of six X.
  Confirmed by direct test, and NC-G1 confirms the gate still catches a real marker.
- **Files modified:** `Scripts/hygiene.sh`
- **Commit:** `4a1e2fc`

**3. [Rule 3 — Blocking] stale `.build/` manifests broke the plan's verify command**
- **Found during:** Task 1
- **Issue:** two orphaned SPM `.d` files under gitignored `.build/` named the deleted sources,
  so the plan's dangling-reference grep returned rc=0 instead of rc=1.
- **Fix:** removed the two stale artefacts; every grep in `hygiene.sh` carries
  `--exclude-dir=.build` with a comment explaining why.
- **Commit:** `073228f`

### Findings reported, not fixed (all belong to Phase 9)

| Finding | Status |
|---|---|
| The plan's pass-1 grep is case-sensitive and misses three sequencer artefacts | Reported; corrected grep used and documented in `CARRIED-DEBT.md` §2 |
| The retired rule exists as **executable code** (`BPMRules.swift:17`), not only in comments | Reported as artefact **A11**. Not edited |
| **Three**, not two, green assertions defend the retired rule; the third is unmarked | Reported in `CARRIED-DEBT.md` §2c. Not edited |
| `ROADMAP.md:310` plans to *re-assert* the retired rule after fixing Q1 | Reported as artefact **A02**. Not edited |
| `MVP-SPEC.md` carries no supersession marker | Reported. Deliberately not added — it would edit an artefact and falsify the baseline claim |
| The plan states `NaiveBPMSortSequencer.swift:2` would not match the pass-1 grep | Incorrect — `ascending` is in the word list. It is absent because the file was deleted |
| The plan states `SEQ-01` is `- [ ]` | It is `- [x]`. NC-G7 applied to the real line; arithmetic equivalent |

### Authentication gates

None.

---

## Known Stubs

None introduced. Two pre-existing stubs were **removed** (`NaiveBPMSortSequencer`,
`FixtureMetadataResolver`). The remaining fixtures — `FixtureCrates`, `FixtureLineSegmenter`,
`FixtureObservations`, `FixturePhotoSource` — are all reachable from live tests or the app
target and are Phase 11's to retire.

`MetadataResolving` has **no conformance** until Phase 7 ships `RES-01…08`. That is a declared
seam, not a stub, and it is allowlisted in `hygiene.sh` with the phase named.

---

## Concurrency note

Plan 04-01 executed concurrently in the same working tree. It owns `Scripts/probe-frames.py`,
`Scripts/screenshots.sh` and `Artifacts/screenshots/`; none of those was touched here, and every
commit in this plan used precise `git add <path>`. The monotonic-BPM sweep was measured on both
sides of 04-01's commit `1505a0f` and the two results were byte-identical, so nothing in this
ledger depends on that plan's state.

---

## Self-Check: PASSED

| Claim | Verified |
|---|---|
| `Scripts/hygiene.sh` exists, executable, 205 lines (min 70) | ✅ |
| `.planning/phases/04-act-i-signoff/CARRIED-DEBT.md` exists, 230 lines, contains `MVP-SPEC` and `ce31189` | ✅ |
| `.planning/phases/04-act-i-signoff/04-02-SUMMARY.md` exists | ✅ |
| `NaiveBPMSortSequencer.swift` absent from disk | ✅ |
| `FixtureMetadataResolver.swift` absent from disk | ✅ |
| Commit `073228f` in history | ✅ |
| Commit `4a1e2fc` in history | ✅ |
| Commit `026e77c` in history | ✅ |
| key_link: `hygiene.sh` matches `test\.sh.*CorePurity` | ✅ |
| key_link: `REQUIREMENTS.md` matches `MVP-SPEC` | ✅ |
