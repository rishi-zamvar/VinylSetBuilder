---
phase: 04-act-i-signoff
plan: 04
subsystem: defect-ledger
tags: [visual-defects, adjudication, gates, negative-controls, uat, s7]
requires:
  - "Scripts/hygiene.sh (04-02) — the eight-gate shape G9 joins"
  - "Scripts/screenshot-audit.py (04-01) — V14's arithmetic and V17's evidence"
  - "04-03's V4/V5 closures and V9's corrected rule"
provides:
  - "Scripts/ledger-check.py — S7 as an exit code, twelve-case --selftest"
  - "Scripts/hygiene.sh gate G9 — S7 checked by the same command as S5 and S6"
  - ".planning/VISUAL-DEFECTS.md — the adjudicated ledger, human table plus machine-readable block"
  - ".planning/UAT-PENDING.md — U11 filed; U8/U9/U10 brought true"
affects:
  - "04-05 (verdict) reads S7 from an exit code and the Medium-or-above count from G9"
  - "Phase 6 inherits V12, V15, V16"
  - "Phase 10 inherits V10"
  - "Phase 11 inherits V6, V9, V17"
tech-stack:
  added: []
  patterns:
    - "a separate machine-readable block beside the human table, rather than restructuring prose that many documents quote"
    - "the headline count is re-derived by the checker on every run and must agree with the block, so it cannot be hand-edited into agreement"
    - "a CLOSED row cites BOTH halves — a route back to the defect and a route to the fix"
    - "a --selftest that is itself proved non-vacuous by neutering the function it tests"
key-files:
  created:
    - Scripts/ledger-check.py
  modified:
    - .planning/VISUAL-DEFECTS.md
    - .planning/UAT-PENDING.md
    - Scripts/hygiene.sh
decisions:
  - "A CLOSED row must cite a re-runnable route to the DEFECT as well as to the fix. V1 and V8 gained photographs of their own defects; V8's ledger row carried a false claim and was corrected."
  - "V17 filed as a seventeenth row from 04-01's Finding 3. The plan expected sixteen; dropping a handed-off finding would have been an abandonment."
  - "The .png-existence check applies to CARRIED rows too, not only CLOSED ones — a carried row's evidence path rots the same way."
  - "V15's owner is Phase 6, not Phase 4: U9 blocks the judgement and SEG-03 changes the population of long lines before any layout fix would be designed."
metrics:
  duration_minutes: 24
  tasks: 3
  commits: 3
  negative_controls: 5
  completed: 2026-08-30
---

# Phase 04 Plan 04: The Defect Ledger, Adjudicated — Summary

Every V-row now has a verdict a command can check. **17 rows: 8 closed, 9 carried, 2 Medium or
above open.** `Scripts/ledger-check.py` is gate **G9** of `Scripts/hygiene.sh`, which now reports
**nine gates**, and it has been made red five times — once per rule class in its own selftest, and
four times on the real committed ledger.

**Seventeen, not sixteen.** Plan 04-01 handed this plan a finding it asked the ledger to carry,
and it is filed as **V17**. The plan's `<verify>` block expects 16; both independent derivations
now return 17 and agree with each other. Flagged here rather than quietly reconciled.

---

## The adjudication, row by row

| Row | Sev | Verdict | Owner | Where the verdict came from |
|---|---|---|---|---|
| **V1** | — | **CLOSED** | Closed | 02-01's fix + 02-05's closure. **Changed by this plan:** it now cites `01-06-crate-list.png`, a photograph of the defect. 04-01's handoff |
| **V2** | — | **CLOSED** | Closed | 02-05, re-confirmed on 33 frames by 03-05. `NOT-A-DEFECT` |
| **V3** | Medium | **CARRIED** | Phase 4 / U8 | CONTEXT D-04-1, taken before any plan in the phase ran. Second sighting from 03-05 |
| **V4** | Low | **CLOSED** | Closed | 04-03 Task 1 — 4.01:1 → 7.96:1, complete pair still ahead at 18.27:1 |
| **V5** | Low | **CLOSED** | Closed | 04-03 Task 2 — `position: 2 → 3`, uniqueness across every `FixtureCrates.all` crate |
| **V6** | Low | **CARRIED** | Phase 11 | CONTEXT D-04-2. Roadmap Phase 11 ship criterion re-checked; **closure condition inherited, not assumed** |
| **V7** | — | **CLOSED** | Closed | 03-03, plus mutation D as the route back to the defect |
| **V8** | — | **CLOSED** | Closed | 03-03. **Changed by this plan:** the row claimed *"no frame anywhere says 'Camera arrives in Phase 3'"* — false, and corrected |
| **V9** | Low | **CARRIED** | Phase 11 | 04-03 Task 3. The old rule was **disproved**; the new one carries three rejected hypotheses |
| **V10** | Low | **CARRIED** | Phase 10 | 03-03/03-05 measurements; roadmap Phase 10 CAP-01/04 re-checked |
| **V11** | Informational | **CARRIED** | Phase 4 / U11 | D-03-3; **U11 filed by this plan** |
| **V12** | Medium | **CARRIED** | Phase 6 | 03-04/03-05. Roadmap Phase 6 criterion 2 names the currency/decimal filter verbatim |
| **V13** | — | **CLOSED** | Closed | 03-05 — closed by assessment, both halves measured on three runs |
| **V14** | Informational | **CLOSED** | Closed | 04-01 — closed by accounting, and re-measured once more here |
| **V15** | Low | **CARRIED** | Phase 6 | 03-05's measurement + U9. **Owner moved from Phase 4 to Phase 6** |
| **V16** | Low | **CARRIED** | Phase 6 | 03-05; SEG-03's filtering |
| **V17** | Low | **CARRIED** | Phase 11 | **NEW** — 04-01 Finding 3, handed over and filed here |

Every carry's owner phase was checked against `.planning/ROADMAP.md` §"Phase Details" before it
was written, per D-04-3. The audit table is in the ledger itself. Phase 6 criterion 2 names the
currency/decimal regex; Phase 10 CAP-01/04 replaces the flexible black rectangle with a camera
layer; Phase 11 criterion 2 re-runs both walks and regenerates the whole set after each of five
swaps. None of the three owners was assumed.

### The four verdicts that changed something rather than recording something

1. **V1's row cited no photograph of its own defect.** 04-01 found it and deleted the one frame
   that did (`sim-settled-crate-list.png`, an uncited orphan) before it could be re-cited. This
   plan opened `01-06-crate-list.png` at 1206×2622 and read `Sunday Chill — 1 records` directly.
   The evidence path is restored, and the rule behind it is written into the ledger.
2. **V8's row carried a false claim.** It said *"no frame anywhere says 'Camera arrives in
   Phase 3' any more."* `02-03-capture-stub.png` still says exactly that — looked at, at full
   resolution. It is a *historical* frame, not one the current suite writes, so the claim was
   true of the regenerable set and false as written. Corrected, and the frame is now V8's
   photograph of its own defect.
3. **V15's owner moved from Phase 4 to Phase 6.** Phase 4 does not re-open the correction sheet,
   so a carry to it would have been a carry to nobody. Phase 6's SEG-03 filter drops the
   price-sticker, address and URL fragments that make the longest lines long, so the population
   the defect is about changes before a layout fix would be designed.
4. **V17 was filed.** See below.

### V3's carry, written in full, because that was the point of it

Both fixes named, the asymmetry recorded, and the asymmetry explicitly **not** treated as a
reason to choose:

- **Fix A (code side):** give `VinylEntry.label` the first-candidate `Track.displayName` fallback
  that `SequencedRow.title` already has. Nothing measured moves.
- **Fix B (fixture side):** mark the fixture tracks `.resolved`. **This moves Phase 3's measured
  `6 Read / 5 Partial / 1 Unread` strip tally**, a committed baseline with a negative control
  behind it (mutation I reddens on exactly that tally).

The ledger and `UAT-PENDING.md` both say, in those words, that the asymmetry is **evidence for
U8 and not a licence to choose for the owner** — a baseline being inconvenient to move is not an
argument about which product answer is right.

### V17 — the seventeenth row, and why the plan's count of sixteen is now wrong

04-01's handoff named two candidate rows: V1's evidence cell (folded into V1) and *"the walk's
run-to-run state instability"*, which had nowhere to live. It is a defect found by looking at
screenshots, it has evidence, and it bears directly on S3 — so it is filed rather than dropped.

**Severity Low**, and the rule that produced it is stated so it cannot be read as fitted to a
verdict: *product-visible defects are Medium or Low; harness and accounting defects are Low or
Informational.* V14, the other accounting defect, is Informational; V17 is one step above it
because it actually reddened a gate and made one frame photograph the wrong state. **The severity
was chosen from that rule, and the Medium-or-above count is unaffected by it either way** — what
a non-zero count means for the verdict is 04-05's call.

---

## G9 — what it does, and the five times it has been red

`python3 Scripts/ledger-check.py` → **rc=0**, printing

```
ledger: 17 rows, 8 closed, 9 carried, 2 Medium-or-above open
```

`./Scripts/hygiene.sh` → **`gates: 9 pass, 0 fail`**, rc=0, and `grep -c "^PASS"` → **9**.

Nine checks, in the checker's own words: five fields per row · `STATUS ∈ {CLOSED, CARRIED}` ·
`SEVERITY` one of four · CLOSED carries a re-runnable evidence path · every cited `.png` exists ·
CARRIED names a `Phase N` · CARRIED's reason clears a 30-character floor · no duplicate IDs and
the block matches the human table **both ways** · the headline count agrees with the block.

**The Medium-or-above count is printed whether it is zero or not and never fails the gate.** The
docstring and the G9 comment both say so, and both say why: S7 is about adjudication being
complete, not about the count being zero.

### Two additions beyond the plan's seven checks, both because a gate with a hole is decorative

- **The `.png`-existence check applies to CARRIED rows too**, not only CLOSED ones. A carried
  row's evidence path rots exactly the same way when a regeneration renames a frame.
- **The headline count line is re-derived on every run** and the gate fails if it disagrees with
  the block. The plan asks for the count to be derived rather than typed; deriving it once leaves
  it free to drift the moment someone edits a row. This makes it *checked*, not merely *derived*.

### The four negative controls, on the committed ledger

Task 1 and Task 2 were **committed before any mutation** (`597579d`, `91bbf44`), per mutation H's
lesson. Each control applied, run, recorded, reverted; `git status --short` **empty** after all
four.

| # | Mutation | rc | Exactly what it printed |
|---|---|---|---|
| **NC-L1** | V4's CLOSED evidence → the word `Fixed` | **1** | `ledger: V4: CLOSED with no re-runnable evidence path — 'Fixed' cites no .png, no Tests.swift, no test_ function, no commit SHA and is not NOT-A-DEFECT. 'Fixed' is not evidence.` |
| **NC-L2** | V12's OWNER `Phase 6` → `later` | **1** | `ledger: V12: CARRIED to OWNER 'later', which names no phase. A carry to a phase that never re-opens the artefact is an abandonment wearing a due date; a carry to no phase at all is not even that.` |
| **NC-L3** | V1's CLOSED evidence → `does-not-exist.png` | **1** | `ledger: V1: cites does-not-exist.png, which is not in Artifacts/screenshots/ — the evidence path is broken, not re-runnable` |
| **NC-L4** | V9's STATUS → `OPEN` | **1** | `ledger: V9: STATUS is 'OPEN' — a row is CLOSED or CARRIED, there is no third state. A row that is neither is what S7 forbids.` |

**NC-L3 is the load-bearing one** and it is the reason it was specified: it proves check 5 is a
regex that actually fires against the filesystem rather than one that never runs.

**NC-L4 reddened twice, on two independent rules**, and that is reported rather than glossed:
the status rule fired, *and* the derived-headline rule fired, because changing a `CARRIED` to
`OPEN` also drops the carried count from 9 to 8. Not a weak gate — arithmetic. The same shape as
04-01's NC-P1, where a solid grey frame trips two probe rules at once.

**NC-L1 was additionally run through `./Scripts/hygiene.sh` in full**, to prove G9 reaches the
gate count rather than only the checker's own exit code:

```
FAIL G9  defect ledger not fully adjudicated (S7)
         ledger: V4: CLOSED with no re-runnable evidence path — 'Fixed' cites no .png, …
gates: 8 pass, 1 fail        rc=1
```

The other eight gates still reported, which is `set -uo pipefail`-without-`-e` doing its job.
After revert: **9 pass, 0 fail**.

### NC-L0 — the selftest proved non-vacuous

`ledger-check.py --selftest` builds twelve synthetic ledgers, one per rule class, and all twelve
behave as specified. A selftest that only ever passes is worth nothing, so `check()` was neutered
to `return []` and the selftest re-run: **11 of 12 cases went red**, the twelfth being the healthy
control, which correctly stayed green. Reverted; `git status --short` empty.

---

## Measurement counts — how many times each claim was measured

| Claim | Times measured | Result |
|---|---|---|
| `01-06-crate-list.png` shows the V1 defect (`1 records`) | **2** — read directly here at 1206×2622; independently confirmed by 04-01 before it deleted the orphan | agreed |
| `02-walk-01-crate-list.png` shows the fix (`1 record`) | **1** here, on top of 02-05's two | agreed |
| `02-03-capture-stub.png` reads `Camera arrives in Phase 3` | **1** — a static committed file, not a behaviour | confirmed |
| `crate walk: 15 files, 1 declared pair, 14 distinct states` | **4** — three by 04-01, once again here | identical every time |
| Ledger has 17 rows, block and human table agree | **2 independent derivations** — `awk`/`grep` on the block, and the checker's own parse | 17 = 17 |
| `ledger-check.py` exits 0 on the adjudicated ledger | **4** — after Task 1, after G9, after the NC reverts, at final verification | rc=0, same four numbers |
| `ledger-check.py` exits 1 on a broken ledger | **5** — NC-L1…L4 plus NC-L1 through hygiene | rc=1, each naming its row |
| `hygiene.sh` = 9 pass, 0 fail | **3** | rc=0 each time |
| `--selftest` all cases behave | **2** green, **1** red under NC-L0 | 12/12, then 1/12 |
| U-numbers reconcile between the two files | **2 directions**, run as set differences | 4 of 4 cited exist; 3 of 5 Phase-4 items cited, 2 named |
| No code file touched | **2** — working-tree diff, and diff against 04-03's close `771d391` | both empty |

---

## Task 3 — U11 filed, and nothing waited for it

**U11 exists.** Same shape as U8/U9/U10: the check (`0 records` on a four-record crate,
`02-walk-11-add-more-capture.png`), why it cannot be automated (every measurement can confirm 0 is
correct for the session; none can say 0 is the right number to *show*), and its phase (4). It
states plainly that an unanswered U11 blocks nothing, because Phase 11 re-photographs the screen
after every swap regardless.

**U8** carries Phase 4's finding as *input*, in a two-row table of the two candidate fixes and
what each costs elsewhere, immediately followed by the sentence saying it is not an argument for
either. **U9** is unchanged as a question and is now named as V15's blocker, so the two cannot
drift. **U10** says explicitly that Phase 4 changed nothing about it — recorded rather than left
silent, because a UAT item that stops being mentioned reads, a phase later, like one that was
resolved.

The section opens with the sentence the plan asked for: **nothing in Phase 4 stopped for a UAT
item.**

### The cross-reference audit, both directions

- **VISUAL-DEFECTS → UAT:** U8, U9, U10, U11 cited; all four exist. **No dangling reference.**
- **UAT → VISUAL-DEFECTS:** the Phase-4 items are U4, U6, U8, U9, U11. U8 (V3), U9 (V15) and U11
  (V11) are cited by ledger rows. **U4 and U6 are not, and that is legitimate and is named rather
  than assumed:** *"is the produced set one you would actually play"* is not a visual defect, has
  no screenshot that could evidence it, and correctly has no V-row.
- U-row count unchanged at **11** (7 open, 4 struck through). No number was renumbered; U11 is the
  next free one.

---

## Deviations from Plan

**1. [Rule 2 — missing critical functionality] Seventeen rows, not sixteen — V17 filed**
- **Found during:** Task 1, reading 04-01-SUMMARY's Handoff section
- **Issue:** 04-01 explicitly handed the ledger *"the walk's run-to-run state instability"* as a
  candidate row. The plan's `<interfaces>` table lists sixteen rows and its `<verify>` expects 16.
  Dropping a handed-off, evidenced finding because a table did not anticipate it would be an
  abandonment — the exact failure D-04-3 exists to prevent, one level up.
- **Fix:** filed as **V17**, CARRIED, owner Phase 11, with both of 04-01's independent
  measurements in the row. The headline count is derived, so it absorbed the change; both
  independent derivations return 17 and agree.
- **Files modified:** `.planning/VISUAL-DEFECTS.md`
- **Commit:** `597579d`

**2. [Rule 1 — bug] V8's ledger row carried a false claim**
- **Issue:** *"No frame anywhere says 'Camera arrives in Phase 3' any more."* `02-03-capture-stub.png`
  does. Corrected rather than deleted, and the frame became V8's photograph of its own defect.
- **Commit:** `597579d`

**3. [Rule 2] The `.png`-existence check extended to CARRIED rows**
- The plan scopes check 4 to CLOSED rows. A carried row citing a frame a regeneration dropped has
  the same broken evidence path. Strictly stronger, and it is one predicate rather than two.
- **Commit:** `91bbf44`

**4. [Rule 2] The headline count line is re-checked, not merely derived once**
- The plan says derive it. Derived once, it drifts the first time a row is edited. Check 9 makes
  the checker re-derive it every run and fail on disagreement — which NC-L4 then demonstrated
  live.
- **Commit:** `91bbf44`

**5. [Rule 1] V4 and V5's severity cells were restored to `Low` in the human table**
- Closing them had overwritten the severity column with `—`, which under this ledger's stated rule
  means *never assigned* or *never a defect*. Both carried `Low` while open — recovered from
  `git show e7c1c23~1` rather than guessed — so the human table and the block now agree.
- **Commit:** `597579d`

**6. Method deviation: Task 2's TDD ran GREEN-then-RED, not RED-then-GREEN**
- `Scripts/ledger-check.py` was written complete, with its twelve-case selftest, and both were
  green on the first run. The RED half was then established two ways rather than one: the four
  live negative controls the plan itself specifies as the proof of failability, and **NC-L0**,
  which neuters `check()` and drives 11 of the 12 selftest cases red. The evidence a strict RED
  step would have produced — *this suite is not vacuous* — exists; it was produced in the other
  order and it is stated rather than dressed up.

**7. V15's owner is Phase 6, and the plan's `<interfaces>` table already recommended that**
- Recorded because the *human table* said Phase 4 and now says Phase 6. Phase 4 never re-opens the
  correction sheet, so the pre-existing owner was a carry to nobody.

**8. `requirements mark-complete S7` was deliberately NOT run**
- The plan's frontmatter says `requirements: [S7]`. **S7 is not a requirement ID** — it is a
  sign-off gate from `CONTEXT.md`, and `grep -c 'S7' .planning/REQUIREMENTS.md` returns **0**.
  Marking it complete would either be a no-op or would corrupt a file whose counts gate G7
  pins at 23 / 44 / 67 and whose recount is explicitly 04-05's. Verified after the state
  update: G7 still reads `23 complete + 44 outstanding = 67 total = 67 distinct`.

### Not deviated from, deliberately

- **Nothing was fixed.** No code file was modified: `git diff --stat App/ VinylSetBuilderCore/`
  is empty and so is the diff against 04-03's closing commit `771d391`. Every defect that gets
  fixed outside the plan that measured it is a defect fixed without a negative control behind it.
- **The human table was left in its existing shape** — a separate machine-readable block was added
  beside it rather than restructuring prose that many documents quote.
- **V6 was not closed on a guess**, and its closure *condition* is written into its own reason:
  if Phase 11's run still produces fewer than ten sequenced rows, it must be re-carried.
- **No threshold in the checker was fitted to this ledger.** The 30-character reason floor is the
  plan's own number; the five evidence forms are the plan's four plus the `NOT-A-DEFECT` exception
  the plan's fallback names.

---

## What FAILED, plainly

**Nothing in this plan was left red, skipped, or reported without being run.** The honest
qualifications:

1. **The plan's `<verify>` expects 16 rows in the block; there are 17.** Both independent
   derivations agree at 17 and the plan's arithmetic is what changed, not the ledger's. Named
   here so 04-05 does not read a stale 16 out of the plan file.
2. **Task 2's tdd order was inverted** — see deviation 6. The failability evidence exists; the
   sequence was not the specified one.
3. **V6 is closed by nobody and may not be closable by Phase 11 either.** The condition is
   recorded rather than the conclusion.
4. **`01-06-crate-list.png` is a *historical* frame**, not one `Scripts/screenshots.sh`
   regenerates. V1's route back to its defect therefore depends on that file staying committed —
   which is exactly what Gate C of `screenshot-audit.py` protects (it is cited, so it is not an
   orphan), but it is a dependency and it is stated.

**No row could not be adjudicated from the record.** S7 is not failing on that count.

---

## The number 04-05 asked for, stated and not characterised

**Medium-or-above rows still open: 2.**

They are V3 and V12. What that means for the verdict is 04-05's decision, made against the rules
CONTEXT.md fixed in advance.

---

## Commits

| Commit | What |
|---|---|
| `597579d` | the adjudicated ledger — 17 rows, the machine-readable block, V1/V8's evidence corrected, V17 filed |
| `91bbf44` | `Scripts/ledger-check.py` and gate G9 |
| `30cfe02` | U11 filed; U8/U9/U10 brought true; the both-directions reconciliation |

---

## Known Stubs

None. This plan wrote no product code and rendered no data.

---

## Self-Check: PASSED

Every claim re-verified against disk after the summary was written. One correction made: the
line count was written as 297 and measured 309.

| Check | Result |
|---|---|
| `Scripts/ledger-check.py` exists | FOUND, **309** lines (plan floor: 50) |
| `.planning/VISUAL-DEFECTS.md` contains `Ledger — machine-readable` | FOUND |
| `Scripts/hygiene.sh` matches `ledger-check` | FOUND (key_link) |
| `.planning/VISUAL-DEFECTS.md` matches `U8\|U9\|U11` | FOUND (key_link) |
| `python3 Scripts/ledger-check.py` | rc=0, `17 rows, 8 closed, 9 carried, 2 Medium-or-above open` |
| `./Scripts/hygiene.sh` | rc=0, `gates: 9 pass, 0 fail`; `grep -c "^PASS"` = 9 |
| Block rows = 17, statuses = 17, IDs reconcile with the human table | OK, set difference empty |
| Every cited `.png` exists under `Artifacts/screenshots/` | OK — enforced by check 5, proved by NC-L3 |
| `git diff --stat App/ VinylSetBuilderCore/` | empty |
| `git diff --stat 771d391..HEAD -- App/ VinylSetBuilderCore/ UITests/` | empty |
| Commits `597579d`, `91bbf44`, `30cfe02` | all 3 in `git log` |
| `git status --short` after all five negative controls | empty |
