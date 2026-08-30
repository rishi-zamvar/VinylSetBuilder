# Rigor policy — revised 2026-08-30 (owner decision)

Target: **completion by end of day.** Reduce ceremony, keep everything that touches the product.

The split below is not a guess. It is what tonight's measured record shows.

## KEEP — this is what caught real bugs, and it is cheap

| Practice | What it caught |
|---|---|
| **TDD, tests before implementation** | the discipline the whole suite rests on |
| **XCUITest driving the real UI** | 3 bugs no unit test could reach — an unreachable tap target, dead edit affordances, a toolbar button wired to nothing |
| **Measure, don't count** | V18 (a drag that changed nothing committed a "Custom order"), and a thumbnail-width mutation that left *every* count assertion passing |
| **Run it more than once** | a non-deterministic walk; drag recipe 1 only genuinely reorders on 3 of 8 runs |
| **Measured acceptance gate per phase** | this IS the product working — OCR ≥ 6 clean/5 partial/1 fail, catalogue ≥ 5 of 6, SoundCloud ≥ 72% |
| **The 9 hygiene gates** | already built, run in seconds, keep Act I's guarantees enforced |
| **Screenshots after a settle delay** | V2 — and the settle rule stopped correct code being restyled to fix an artefact |

## CUT — expensive, and it mostly verified the verifiers

| Practice | Why it goes |
|---|---|
| Negative controls on **every** gate | 19 in Phase 4 alone; each needs commit → mutate → full run → verify → revert. **Now: only on brand-new gates**, not ones already proven |
| **Two independent observations for every claim** | **Now: only for the phase's headline acceptance number** |
| A **separate closure/audit plan** per phase | 02-05, 03-05 and *six* in Phase 4. **Now: folded into each phase's final plan** |
| **Three** screenshot regeneration runs | **Now: one, with a re-run only on failure** |
| Row-by-row ledger adjudication with two derivations | **Now: `ledger-check.py` runs as gate G9 and that is the adjudication** |
| A separate planner agent per phase | **Now: batch-planned, phases in parallel where they do not depend on each other** |

## The line that does not move

A phase still **fails** if its measured acceptance number is not met. Reducing ceremony does
not mean reducing the bar — it means we stop proving that the proof works.

And the three lessons stay in force, because they cost nothing:
1. **Presence is not evidence.** Assert the thing that carries the meaning.
2. **An exit code can lie.** `ui-test.sh` exited 0 having run zero tests, twice. Read the count.
3. **One observation is a story, two is a measurement.**
