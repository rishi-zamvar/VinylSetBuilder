# Locked decisions (§8 open items resolved)

| # | Item | Decision | Rationale |
|---|---|---|---|
| 1 | Camelot weighting | Flat hop count. `+1` for letter change only, no extra penalty. | Tuning knob for a problem not yet heard. Revisit only if a real set sounds wrong. |
| 2 | `BPM_TOLERANCE` | Default 4.0, slider 3–6. As spec'd. | No change. |
| 3 | Half/double time | Unconditional `if bpm < 100 { bpm *= 2 }` at resolution time. | Jungle/DnB-only app. Skipped a genre-aware normalizer. |
| 4 | unresolved vs excluded | ONE bucket, each row carries a `reason: String`. | Two UI sections buy nothing; the reason string already distinguishes them. |
| 5 | Sequencer search (§5 step 6) | Beam search, width 50. Do NOT attempt exact DP first. | "Visit each vinylID at most once" makes exact DP exponential. Spec's own fallback is the answer. |

## Test-fixture source
Real vinyl label photos are supplied by CEO directly into the Claude Code session
(iPhone camera → conversation). These become the golden fixture set under
`Tests/Fixtures/Labels/` for Phase 2 segmentation accuracy (8/10 track-count target)
and Phase 3 resolution accuracy (70%+ auto-resolve target).
