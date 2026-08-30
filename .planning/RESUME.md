# Resume here

**Paused:** 2026-08-29, machine restart.

## Where we got to

GSD scaffold is COMPLETE and pushed. Phase 1 planning was **in flight** when we paused.

| Artifact | State |
|---|---|
| `PROJECT.md`, `REQUIREMENTS.md` (65/65 mapped), `ROADMAP.md` (6 phases), `STATE.md`, `CLAUDE.md` | ✅ committed + pushed |
| `research/` — STACK, FEATURES, ARCHITECTURE, PITFALLS, BPM-SOURCES, SUMMARY, OCR-SPIKE, EMPIRICAL-FINDINGS | ✅ committed + pushed |
| `DEFERRED.md` — iOS 27 items with anti-forgetting mechanism | ✅ committed + pushed |
| `phases/01-…/CONTEXT.md` | ✅ committed |
| `phases/01-…/PLAN*.md` | ⚠️ **planner agent was still running — killed by the restart. Check the phase dir; if empty or partial, re-run the planner.** |

## First command on resume

```bash
cd ~/Documents/Projects/VinylSetBuilder
ls .planning/phases/01-foundation-domain-model-sequencer/
```

- **If only `CONTEXT.md` is there** → re-run `/gsd:plan-phase 1 --skip-research`.
  Research was deliberately skipped: this phase has no unknowns (see CONTEXT.md).
- **If PLAN files exist** → verify they cover all 22 requirements
  (`SETUP-01..04`, `SEQ-01..11`, `CRATE-01..07`), then `/gsd:execute-phase 1`.

## Preserved local artifacts (`.local/`, gitignored, 14 MB)

Do not rebuild these — they cost real API calls and are already validated:

| File | What | Why it matters |
|---|---|---|
| `bpmkey.db` | 6,608-row tier-0 corpus, 880 KB, `journal_mode=delete` | Bundle-ready |
| `mu_dataset.json` | 29 ground-truth tracks matched to SoundCloud (72% hit rate) | Phase 4 gate input |
| `mu_audio/*.mp3` | 29 × 30-second previews, 13 MB | Phase 4 gate input |
| `truth.tsv` | 40 sampled tracks, known BPM + Camelot | Ground truth |
| `ocr/ocr2.swift` + `ocr2_out.json` | Vision OCR probe (EXIF-correct) + results on all 12 fixtures | Segmentation baseline |

Fixture photos: `Tests/Fixtures/Labels/` (gitignored). Restore from `~/Desktop/test/*.HEIC`.

## Blocked on the owner

1. **macOS 27 update** → unblocks `Tools/mu-validate.swift`, the Phase 4 go/no-go gate.
   Everything else for it is already built: one compile, one run.
2. **GitHub Actions** disabled at account level → blocks the Pages backlink. **Cosmetic only**
   now that GetSongBPM was dropped. Nothing depends on it.

## Toolchain facts (verified, don't re-derive)

- Xcode 26.0.1, **iOS 26 SDK only** — `MusicUnderstanding` cannot link yet (DEFERRED D1/D2).
- `swift test` works standalone — smoke-tested, 5 Camelot tests green in 1 ms, no Xcode,
  no simulator. The Core package is buildable today.
- macOS 26.3.1, Swift 6.2.
