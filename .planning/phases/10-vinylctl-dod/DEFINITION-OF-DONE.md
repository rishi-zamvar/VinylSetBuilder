# MVP-SPEC §9 — the Definition of Done, walked

**Walked 2026-08-30, at the close of Phase 10, the last phase of v1.0.**

Every number below was measured on this date by a command anyone can re-run, and the command is
named beside it. A **NOT MET** here is a valid and useful answer; three of the five items are
met, one is partly met, and one is not met.

| # | Item | Verdict |
|---|------|---------|
| 1 | Create a crate, scan 20 vinyls without waiting on any screen | **MET on the simulator.** The camera half is unproven and is UAT **U13** |
| 2 | Metadata auto-resolves for most; hand-enter the rest in under 15 s each | **NOT MET on clause 1. MET on clause 2** under the stated cost model, marginal on wall clock |
| 3 | A sequenced set whose tempo steps stay inside the tolerance and whose harmonic neighbours make sense | **PARTIALLY MET.** Tempo clause holds, live. Harmonic clause is **not assessable** on real data |
| 4 | Add 5 more vinyls and watch the sequence re-optimise, including a previously excluded record rejoining | **MET**, evidenced three independent ways |
| 5 | Close the app, reopen it, find the crate intact | **MET.** 730/730 lines, 0 differing, through `simctl terminate` |

---

## 1. Create a crate, scan 20 vinyls without waiting on any screen — **MET on the simulator**

`./Scripts/ui-test.sh` — `CaptureWalkUITests`, both tests, re-measured today.

| What | Measured |
|---|---|
| shutter press → tile in the strip, 12 presses | `[11, 17, 12, 14, 14, 14, 15, 15, 16, 18, 18, 20] ms`, slowest **20 ms** |
| the same, 21 presses | `9 … 35 ms` |
| tiles observed still `Reading` while the shutter stayed live | **12 of 12** — the shutter did not wait for Vision |
| Vision's own cost, which the shutter does not pay | `831 … 1223 ms` per image |
| read latency, first-5 mean → last-5 mean over 21 captures | **1046 ms → 960 ms** — no degradation |
| tile width at 1 item vs at 21 | **104.0 pt → 104.0 pt** — the strip does not collapse |
| the 21st tile | reachable after 13 bounded drag steps |

**Why the shutter does not block is structural, not a tuning result.** `CaptureView.shoot()` is
two phases: `source.capture()` returns the instant bytes exist and puts a `.reading` tile in the
strip; `source.read()` follows and replaces it. There is no spinner in that function because
there is nothing to wait on.

**What is NOT proved, and is not claimed.** `SleeveCamera.makeIfAvailable()` returns nil on
every simulator, so not one line of `AVCapturePhotoOutput.capturePhoto` has ever executed. The
21 captures above are HEIC decodes of the owner's own photographs through the identical call
site. Memory and thermals cannot be observed on a machine that shares the Mac's envelope and
runs no camera pipeline. **This is CAP-04's outstanding half, and it is the one requirement of
67 still unticked** — UAT **U13**.

---

## 2. Metadata auto-resolves for most — **NOT MET.** Hand entry under 15 s — **MET, marginally**

### Clause 1: "auto-resolves for most" — NOT MET

`./Scripts/vinylctl.sh sequence Tests/Fixtures/Labels/*.HEIC`, committed at
`Artifacts/vinylctl/sequence-baseline.txt`. Twelve real photographs, live network.

| Rung | Measured on the owner's twelve |
|---|---|
| records yielding at least one track line | **11 of 12** |
| records carrying a readable catalogue number | **6 of 12** |
| catalogue-number resolution, on the records that have one | **6 of 6** (Phase 7) |
| **tier-0 bundled corpus hit rate on this collection** | **0** — measured, and expected |
| track lines given an artist AND a title | **17 of 21** |
| records with at least one identified line | **10 of 12** |
| **track lines given a tempo** | **7 of 21** |
| **records with any tempo at all** | **5 of 12** |
| track lines given a key | **1 of 21** |
| **records that made the set** | **2 of 12** |

**The 83% identity rate is the wrong number to quote and it is the flattering one.** Three
things have to be said about it plainly:

1. **Identity is not usable metadata. Tempo is.** The sequencer gates on tempo, so a record with
   a confident name and no BPM is in the bucket exactly like one with no name. On that measure
   the real auto-resolve rate is **5 of 12 — 42%**, which is not "most".
2. **The artist+title rung produces confident wrong answers, and they are in the committed
   baseline where anyone can read them.** `fellowship` on a jungle white label resolves to
   **Lizz Wright — Fellowship**, a jazz vocalist. `"SMADON MIND` resolves to **Navene K — Mind**.
   `Da Lick` resolves to **Dirty Game Records — What da Lick Read?**. These are not failures the
   app knows about — they are answers it believes.
3. **The tier-0 corpus contributes nothing to this collection and that was predicted, not
   discovered.** It is the owner's house/techno library; this is a crate of jungle twelves, only
   12% of which sits in the corpus's band. It is consulted first because it is free, not because
   it is expected to answer.

**The honest sentence: the app auto-names most records and auto-*resolves* fewer than half.**
The gap between those two is what makes manual entry load-bearing rather than an error path,
which is why Phase 9 measured it as carefully as it did.

**One further consequence, and it is the reason U8 now matters more than when it was filed:**
of the 10 records not in the set, **8 read `Vinyl N`** rather than a name (defect V3). At a 0%
tier-0 rate, "unresolved" is the common case, so the bucket's naming is a common-case problem
rather than an edge-case one. **U8 is still unanswered and Phase 10 did not guess it.**

### Clause 2: hand-enter the rest in under 15 seconds each — MET under the cost model

`./Scripts/ui-test.sh` — `ManualEntryUITests`, re-measured today.

```
MAN-01 sequenced-list edit: taps=8 keystrokes=16 sheets=1 costed=13.3s wallclock=15.8s
MAN-05 bucket edit:         taps=5 keystrokes=6              costed=7.3s
MAN-03 prefill = '170'      (the crate's own folded median, not a global guess)
```

Cost model, stated once and applied everywhere: **1.0 s** a tap (the top of the measured
0.6–1.0 s band), **0.3 s** a keystroke (conservative against 25–40 wpm), **0.5 s** a sheet.

**13.3 s against a 15 s budget is a pass with 1.7 s of headroom, and the headroom is thin for a
stated reason: the budget is typing-dominated.** 16 keystrokes is 4.8 s of the 13.3. A realistic
full artist-plus-title correction of ~32 characters is **9.6 s of keystrokes alone**, which
leaves 5.4 s for every tap and the sheet together. The four-field correction measured here
therefore sits near the top of what the budget can carry, and a longer title would exceed it.

**The wall clock is 15.8 s, which is over.** It is reported rather than hidden, and it is not the
claim: the harness pays an accessibility snapshot per query that a person does not, and the
count is the thing the design controls. If the count changes, the claim changes with it.

---

## 3. A sequenced set inside the tolerance, with sensible harmonic neighbours — **PARTIALLY MET**

### The spec drifted, and the drift is reconciled rather than papered over

MVP-SPEC §9 item 3 originally read **"Get a sequenced set with ascending BPM and sensible
harmonic neighbors."** It was rewritten in commit `c73adf5` to **"whose consecutive tempo steps
stay inside the tolerance"**, because the owner **retired the non-decreasing BPM rule on
2026-08-30** and SEQ-03 went bidirectional: the only hard gate is now `|b − a| ≤ tolerance`, in
either direction.

**The original wording is not merely outdated — it is unsatisfiable by the current sequencer by
design.** A backward step is produced whenever the keys favour it, and
`SequencerAdjacencyTests` pins a fixture whose uniquely cheapest order opens with a step of
exactly −4.0. Hygiene gate **G8** now fails the build if the retired rule reappears as code or is
stated in a spec without a supersession marker. Reporting item 3 against "ascending" would be
reporting against a rule the project deliberately removed.

### Against the current wording

| Clause | Verdict | Evidence |
|---|---|---|
| consecutive tempo steps inside the tolerance | **MET, on live data** | The walk asserts `abs(b − a) ≤ 4.0` on every adjacent pair of the live set: `PIPELINE sequenced tempos = [136.0, 138.8]`, delta 2.8. Swept in Core over 4 tolerances × 5 seeds × 40 vinyls |
| harmonic neighbours make sense | **NOT ASSESSABLE** | **1 of 21 track lines came back with a key at all.** Total Camelot distance across the live set: 0 — but a 0 over one known key and one placeholder is arithmetic, not harmony |

**Why the key rate is 1 of 21, stated rather than glossed.** The vDSP analyser's key confidence
floor is 0.8, chosen by measurement in Phase 7: at 0.8, 7 keys are kept of which 5 are usable
(71% precision), against 24 kept of which 9 are usable (38%) at 0.5. **A wrong key is worse than
no key, because the sequencer can order around a missing one and cannot know a wrong one is
wrong.** The floor is doing exactly what it was set to do. The consequence is that the harmonic
half of item 3 cannot be judged from this crate, and saying so is the honest verdict.

**And the deeper problem this run exposes, which no gate catches.** The two records in the set
are at **136** and **138.8 BPM**. This is a crate of jungle twelves, which run 160–180. Both
tempos are almost certainly wrong — they are SoundCloud matches against the wrong uploads,
downstream of the confident-wrong-answer problem in item 2. **The set obeys every rule it is
gated on and is still not a set the owner would play.** That is precisely UAT **U4/U6**, the
project's actual success criterion, and it is not something any assertion in this repository
could ever have answered.

---

## 4. Add 5 more, watch it re-optimise, including a previously excluded record rejoining — **MET**

Evidenced three independent ways, two of them on the live app.

**A. In Core, exhaustively** — `RejoinTests`, seven tests:
excluded-then-rejoins-when-a-bridge-is-added; the bridge removed again re-excludes it *with no
memory of the prior run*; the bridge found among a vinyl's **second** candidate, not only its
first; a **half-time** bridge (87 folds to 174) still bridging; and **two disjoint BPM islands
merging into one sequence** once bridged. The rejoin is a property of a full re-derivation, never
of a merge — `CrateDetailModel.apply` treats the sequencer as authoritative about membership on
every run.

**B. In the live app, by typing a tempo** — `ManualEntryUITests`:
`MAN-05 bucket edit: running order 2 -> 3`. A record sitting in the not-included bucket was given
a tempo by hand and **rejoined the set**, on screen, in 5 taps and 6 keystrokes.

**C. In the live app, by widening the window** — `SEQ05ToleranceUITests` (new this phase):
dragging the tolerance slider from 4 to 6 takes the fixture crate from **2 sequenced / 2 excluded
to 3 sequenced / 1 excluded** — the excluded record rejoins — and dragging back to 3 removes it
again, with the bucket's own sentence following the slider to `No track within 3 BPM of the set`.
Expectations derived in `ToleranceTests` through `CrateDetailModel.sequencerInput`, the same path
the screen uses.

**One honest note on the wording.** The spec says "add **5** more vinyls". Nothing in the system
is sensitive to the number five: re-optimisation is a full re-derivation on every mutation, so
one added record exercises the same path as five. The mechanism is proven; the specific count is
not a threshold anything depends on, and no test was contorted to hit it.

---

## 5. Close the app, reopen it, find the crate intact — **MET**

`./Scripts/persistence-check.sh`, re-run today. **Not an XCUITest**: `XCUIApplication.terminate()`
is the harness asking the app to leave, while `simctl terminate` is the operating system killing
the process, which is what a phone reclaiming memory actually does.

```
PASS  PERS-01  field-by-field diff = 0 differing line(s) over 730/730 lines
PASS  PERS-01  the relaunched store holds 20 vinyls (expected 20)
PASS  PERS-03  47 candidate tracks survived, 20 selected, 27 UNSELECTED
PASS  MAN-04   12 hand-entered track(s) kept the .manual mark across the kill
PASS  PERS-02  the scalar manualOrder array survived as one line
persistence-check: 0 fail
```

The 27 **unselected** candidates are the load-bearing number: a store that quietly kept only the
selected track per vinyl would look correct on screen and be wrong the moment a record was added,
because the sequencer needs every candidate on every re-run.

---

## Summary

**Three MET, one PARTIALLY MET, one NOT MET.**

The two that fall short fall short in the same place, and it is not the app's plumbing: **the
identity and tempo an unlabelled jungle twelve can be given from public databases.** Nine of the
owner's twelve records are white labels and dubplates. The pipeline reads them, segments them,
finds their catalogue numbers 6 of 6, asks four services in the right order and takes the first
free answer — and then there is no answer to take. Everything downstream of that is correct and
provably so; it is simply working on very little.

**The one requirement still unticked is CAP-04, and it needs the phone.** 66 of 67.
