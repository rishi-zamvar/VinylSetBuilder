# Carried debt entering Act I sign-off

**Written:** 2026-08-30, plan 04-02
**Line numbers pinned at commit:** `073228f` (unchanged from `ce31189` for every file named
below — none of them was touched between the two; proven by `git diff` in §3)
**Owner split:** Phase 4 owns this **ledger**. Phase 9 owns the **code**. Nothing in this
document edits an artefact, because Phase 9's rewrite depends on starting from an unmodified
baseline and editing a comment here would falsify the very claim §3 proves.

Line numbers drift. **Every row is keyed on its matched text**; the line number is a
convenience for finding it, not an identity.

---

## 1. `AsyncSequencer` and `BeamDivergenceCheck` do not exist

Plan `01-05-PLAN.md` was written and never executed. There is no async sequencing seam and no
beam-divergence check on disk.

**Re-confirmed by command** (gate G4 of `Scripts/hygiene.sh`, run 2026-08-30, and
independently by hand before the gate was written — two observations):

```
$ grep -rn --exclude-dir=.build "AsyncSequencer\|BeamDivergenceCheck" App/ VinylSetBuilderCore/ UITests/
$ echo $?
1
```

`rc=1` — grep found nothing. Both observations agreed.

**Consequence: SEQ-08, SEQ-09 and SEQ-10 are _wholly_ outstanding, not partly built.** The
Phase 1 record implies a seam that is not there. Do not plan against a file that does not exist.

Phase 9 inherits:
- `.planning/phases/01-foundation-domain-model-sequencer/01-05-PLAN.md` — the unexecuted plan
- `.planning/open-questions/RejoinTests.swift.wip` — its unfinished test file
- `.planning/open-questions/Q1-sequencer-determinism.md` — `BeamSearchSequencer`'s rank tuple
  ends in a position-derived `start-index asc`, so it may be order-dependent

---

## 2. SEQ-03 is REOPENED, and the previous inventory of its stale artefacts was wrong

The owner replaced the non-decreasing BPM rule with bidirectional adjacency on 2026-08-30
(`|bpm[i+1] − bpm[i]| ≤ tolerance`, in either direction — see `.planning/SEQUENCER-SPEC.md`).
The shipped Act I code and docs still assert, and in one place still *implement*, the retired
rule.

### How this inventory was derived — two passes, two methods

**Pass 1 — prose.** The word list specified at planning time, but run **case-insensitively**:

```bash
grep -rniE --exclude-dir=.build "non-decreasing|nondecreasing|monotonic|ascending" \
     VinylSetBuilderCore/ App/ UITests/ docs/ .planning/ROADMAP.md
```

> The version specified at planning time was **case-sensitive** (`"non-decreasing\|nonDecreasing\|monotonic\|ascending\|STALE"`)
> and returned **14 hits**. It silently missed `BPMRules.swift:10` (*"**N**on-decreasing AND
> within tolerance"*), `BPMRules.swift:11` (*"**M**onotonic BPM is an MVP simplification"*) and
> `BeamSearchSequencer.swift:51` (*"**A**scending by folded BPM"*) — three artefacts, all in the
> sequencer itself, all lost to a capital letter. Case-insensitive pass 1 returns **20 hits**.

**Pass 2 — structural.** Prose cannot find code that has no words in it:

```bash
grep -rnE --exclude-dir=.build "bpm! >= |b >= a|canFollow|⚠️ STALE" \
     VinylSetBuilderCore/ App/ UITests/ docs/ .planning/ROADMAP.md
```

Pass 2 returns **13 hits** and is the *only* pass that finds the thing that actually matters:
`BPMRules.swift:17`, `b >= a && (b - a) <= tolerance + 1e-9` — **the retired rule as executable
code**. It contains not one word from the pass-1 list. A prose-only inventory can never see it,
which is how a document could claim the rule survived only in comments.

**Union of both passes: 32 hits.** Measured twice (before and after commit `1505a0f` landed from
the concurrent plan 04-01); the two runs were byte-identical.

Every one of those 32 hits is classified below as an **artefact** (A) or a **non-artefact** (N).
Gate G8 of `Scripts/hygiene.sh` asserts `A-rows + N-rows == live sweep hits`, so deleting a row
here, or a new artefact appearing in the tree, breaks the sum.

### 2a. Artefacts — assert or implement the retired rule. Phase 9 removes these.

<!-- ARTEFACT_COUNT=17 -->

| # | File | Matched text | What it asserts | Found by |
|---|---|---|---|---|
| A01 | `.planning/ROADMAP.md:304` | `SEQ-03 (BPM gate, non-decreasing)` | states the retired rule as SEQ-03's definition | pass 1 |
| A02 | `.planning/ROADMAP.md:310` | ``` `SEQ-03`'s non-decreasing guarantee is re-asserted on the fixed sequencer ``` | plans to *re-assert* the retired rule after fixing Q1 | pass 1 |
| A03 | `.planning/ROADMAP.md:415` | `a sequenced set with ascending BPM and sensible harmonic neighbours` | Definition of Done demands an ascending set | pass 1 |
| A04 | `docs/MVP-SPEC.md:131` | `bpm sequence is non-decreasing` | **§5 states the hard gate in its retired form** | pass 1 |
| A05 | `docs/MVP-SPEC.md:223` | `Get a sequenced set with ascending BPM and sensible harmonic neighbors` | §9 Definition of Done demands an ascending set | pass 1 |
| A06 | `Domain/SequenceResult.swift:15` | `// ordered, one per vinyl, non-decreasing BPM` | doc comment on the public result type | pass 1 |
| A07 | `Sequencing/BeamSearchSequencer.swift:51` | `// Ascending by folded BPM; deterministic ties` | the pre-sort the single-pass algorithm depends on | pass 1 (case-insensitive only) |
| A08 | `Sequencing/BeamSearchSequencer.swift:81` | `// Sorted-ascending order is a topological order of the BPM-gate DAG (non-decreasing` | justifies the single left-to-right pass **by** the retired rule | pass 1 |
| A09 | `Sequencing/BPMRules.swift:10` | `/// D2: the sequence's only hard gate. Non-decreasing AND within tolerance of the` | doc comment on the gate | pass 1 (case-insensitive only) |
| A10 | `Sequencing/BPMRules.swift:11` | `/// previous track. Monotonic BPM is an MVP simplification` | doc comment on the gate | pass 1 (case-insensitive only) |
| A11 | `Sequencing/BPMRules.swift:17` | `b >= a && (b - a) <= tolerance + 1e-9` | **THE ENFORCEMENT. The `b >= a` clause _is_ the retired rule, in code.** | **pass 2 only** |
| A12 | `Tests/…/BeamSearchSequencerTests.swift:36` | `@Test("[STALE — retired spec, Phase 9 replaces] BPM is non-decreasing across the whole winning sequence")` | test display name | pass 1 |
| A13 | `Tests/…/BeamSearchSequencerTests.swift:37` | `func test_givenSequence_whenInspected_thenBPMIsNonDecreasing()` | test function name | pass 1 (case-insensitive only) |
| A14 | `Tests/…/BeamSearchSequencerTests.swift:41` | `#expect(b.bpm! >= a.bpm!)` | **stale assertion 1 — green, MARKED** (see §2c) | pass 2 |
| A15 | `Tests/…/BeamSearchSequencerTests.swift:61` | `func test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending()` | test function name | pass 1 (case-insensitive only) |
| A16 | `Tests/…/BeamSearchSequencerTests.swift:65` | `#expect(b.bpm! >= a.bpm!)` | **stale assertion 3 — green, UNMARKED** (see §2c) | pass 2 |
| A17 | `Tests/…/BPMRulesTests.swift:48` | `#expect(BPMRules.canFollow(174, 170, tolerance: 4) == false)` | **stale assertion 2 — green, MARKED** (see §2c) | **pass 2 only** |

**Count: 17.** Derived from this table's own row count, stated once.

### 2b. Non-artefacts — matched the sweep for an unrelated reason. Phase 9 leaves these.

| # | File | Matched text | Why it is not an artefact |
|---|---|---|---|
| N01 | `.planning/ROADMAP.md:515` | `Monotonicity is gone.` | the **amendment** announcing the new rule — a correction, not an assertion |
| N02 | `UITests/CaptureWalkUITests.swift:139` | `// Ascending-order array equality` | thumbnail index order, nothing to do with BPM |
| N03 | `UITests/CaptureWalkUITests.swift:211` | `// with fresh, still-ascending indices` | thumbnail index order |
| N04 | `Sequencing/BeamSearchSequencer.swift:89` | `&& BPMRules.canFollow(s.lastBPM, track.bpm!, tolerance: tolerance) {` | a **call site**. Survives the rewrite unchanged; the callee's body (A11) is the artefact |
| N05 | `Sequencing/BPMRules.swift:16` | `public static func canFollow(_ a: Double, _ b: Double, tolerance: Double) -> Bool {` | the **signature**, which survives; the body (A11) is the artefact |
| N06 | `Tests/…/BeamSearchSequencerTests.swift:30` | `// ⚠️ STALE — ASSERTS A RETIRED SPEC. DO NOT TRUST THIS GREEN.` | the supersession marker added at `ce31189` — warns about the rule, does not assert it |
| N07 | `Tests/…/BeamSearchSequencerTests.swift:31` | `// The owner replaced the non-decreasing rule on 2026-08-30 with bidirectional adjacency:` | same marker block |
| N08 | `Tests/…/BPMRulesTests.swift:33` | `// MARK: - Gate (⚠️ STALE: 'non-decreasing AND within tolerance' is a RETIRED spec.` | **was an artefact when the previous inventory listed it.** `ce31189` rewrote the plain section comment into a supersession marker. The row was correct when written; the artefact it named no longer exists in artefact form |
| N09 | `Tests/…/BPMRulesTests.swift:38` | `#expect(BPMRules.canFollow(170, 174, tolerance: 4) == true)` | tests tolerance, not direction — true under both the old and new rule |
| N10 | `Tests/…/BPMRulesTests.swift:43` | `#expect(BPMRules.canFollow(170, 174.01, tolerance: 4) == false)` | over tolerance — false under both rules |
| N11 | `Tests/…/BPMRulesTests.swift:53` | `#expect(BPMRules.canFollow(174, 174, tolerance: 4) == true)` | identical BPM — true under both rules |
| N12 | `Tests/…/BPMRulesTests.swift:58` | `#expect(BPMRules.canFollow(170, 173.5, tolerance: 3) == false)` | tolerance range — direction-neutral |
| N13 | `Tests/…/BPMRulesTests.swift:59` | `#expect(BPMRules.canFollow(170, 173.5, tolerance: 6) == true)` | tolerance range — direction-neutral |
| N14 | `Tests/…/FixtureObservationsTests.swift:22` | `ascending filename order` | fixture **filename** order |
| N15 | `Tests/…/FixtureObservationsTests.swift:29` | `the table is no longer in ascending filename order` | fixture **filename** order |

**17 artefacts + 15 non-artefacts = 32 = the live sweep's hit count.** That identity is gate G8.

### 2c. The green tests defending a retired spec — named individually

A green test defending a dead spec is worse than a red one, because **nothing about the suite's
output distinguishes it.** All 168 tests pass. Three of those passes are worthless, and one of
the three is not even flagged.

**1. `test_givenSequence_whenInspected_thenBPMIsNonDecreasing`** —
`BeamSearchSequencerTests.swift:37`, assertion at :41.
Marked `⚠️ STALE` in place at commit `ce31189`. Asserts `b.bpm! >= a.bpm!` across a 40-vinyl
fixture. **It passes while defending a rule the owner retired on 2026-08-30.**

**2. `test_givenDecreasingBPM_whenGated_thenRejected`** —
`BPMRulesTests.swift:47`, assertion at :48.
Marked `⚠️ STALE` at `ce31189` by the section `MARK` at :33. Asserts
`BPMRules.canFollow(174, 170, tolerance: 4) == false`. Under bidirectional adjacency
`|174 − 170| = 4 ≤ 4`, so the correct expectation is **`true`**. Its own display name —
*"A decreasing BPM is rejected even within tolerance"* — is a statement of the retired rule.
**It passes while defending a rule the owner retired on 2026-08-30.**

**3. `test_givenDescendingCandidates_whenSequenced_thenOrderIsAscending`** —
`BeamSearchSequencerTests.swift:61`, assertion at :65. **NOT MARKED.**

> **Finding.** `CONTEXT.md` and `REQUIREMENTS.md` both say **two** test assertions are marked
> `⚠️ STALE`. That is accurate as a statement about the *markers*. It is **not** the number of
> green assertions defending the retired rule: there are **three**, and the third carries no
> marker at all. Its display name, *"Input order never matters — the output always ascends"*,
> reads as a determinism test, which is presumably why it escaped the `ce31189` sweep — but its
> body asserts `b.bpm! >= a.bpm!`, which is the retired rule verbatim. Phase 9 must delete or
> rewrite **three** assertions, not two.

### 2d. What the previous inventory said, and what was wrong with it

`REQUIREMENTS.md` prose said the rule survived in **"five places"** and its table then listed
**six rows** — the prose and the table disagreed with each other inside one paragraph. The
corrected count is **17**, and it is neither five nor six. Errors found:

| # | Error in the previous inventory | Correction |
|---|---|---|
| 1 | Prose said "five places", table listed six rows | The prose/table disagreement is itself the finding; both were wrong |
| 2 | `docs/MVP-SPEC.md:131` omitted | Added as **A04** |
| 3 | `docs/MVP-SPEC.md:223` omitted (§9 Definition of Done) | Added as **A05** |
| 4 | `.planning/ROADMAP.md:304` omitted | Added as **A06**→**A01** |
| 5 | `.planning/ROADMAP.md:310` omitted — and it plans to *re-assert* the retired rule | Added as **A02** |
| 6 | `ROADMAP.md:385` — line number wrong | The text is at **:415**. Drifted by 30 lines, which is why every row here is keyed on matched text |
| 7 | `BPMRules.swift:10/11/17` all omitted — including **the enforcement itself** | Added as **A09/A10/A11**. The inventory claimed the rule survived in comments; it survives in executable code |
| 8 | `BeamSearchSequencer.swift:51` omitted | Added as **A07** |
| 9 | Two of the three stale test assertions were counted; the third was invisible | Added as **A15/A16**, see §2c |
| 10 | `BPMRulesTests.swift:33` listed as an artefact | Correct when written; `ce31189` converted it into a supersession marker. Reclassified **N08** |
| 11 | `Fixtures/NaiveBPMSortSequencer.swift:2` listed as an artefact | **Resolved by deletion**, see §2e. No longer exists |

### 2e. One previously-listed artefact was resolved, not carried

`Fixtures/NaiveBPMSortSequencer.swift:2` — *"filters out tracks with no BPM and sorts the rest
ascending"* — was row 5 of the previous table. **The file was deleted in this plan** (commit
`073228f`, Task 1) because it had zero references outside its own declaring file and its own doc
comment named the two shipped plans that superseded it.

This is also the artefact the planning-time grep was noted as unable to match: its wording is
*"sorts the rest ascending"*, and the case-sensitive pass-1 word list did contain `ascending`,
so it **would** have matched had the file still existed. The stated reason for the miss was
wrong; the real reason it does not appear in the 32-hit sweep is that the file is gone.

Phase 9 therefore inherits **17** artefacts, not 18.

---

## 3. Phase 9 starts from an unmodified baseline — proven, and TRUE

```
$ git log --oneline -- VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/
59e2f3c feat(01-04): implement BeamSearchSequencer (SEQ-02/03/04/06)
7b9a037 feat(01-03): implement BPMRules fold and gate (SEQ-01)
ab3566b feat(01-03): implement Camelot wheel, distance, and ported pitch tables (SEQ-01)
36ab5cf feat(01-01): add protocol seams and Phase-1 fixture stubs
```

The newest commit touching `Sequencing/` is `59e2f3c feat(01-04)`. **Nothing after it.** The
claim holds.

```
$ git diff --stat ce31189 HEAD -- VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/
(empty)
```

Plan 04-02 did not touch `Sequencing/` either. Both observations agree.

---

## 4. What Phase 4 did and did not do

| | |
|---|---|
| **Did** | corrected this ledger; deleted two unreferenced fixture stubs; built `Scripts/hygiene.sh` so G4 and G8 re-check §1 and §2 on every run |
| **Did not** | touch `BeamSearchSequencer.swift`, `BPMRules.swift`, `SequenceResult.swift`, `MVP-SPEC.md` §5/§9, `ROADMAP.md`'s SEQ-03 rows, or any of the three stale test assertions |

`MVP-SPEC.md` carries **no marker** saying it is superseded. `.planning/SEQUENCER-SPEC.md`
claims to supersede MVP-SPEC §5, but a reader opening MVP-SPEC is told the retired rule with
nothing to warn them. **That marker is deliberately not added here** — MVP-SPEC §5 and §9 are
artefacts A04 and A05, and Phase 9 owns them. Adding a marker would edit an artefact and
falsify §3.
