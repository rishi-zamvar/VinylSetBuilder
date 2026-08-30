# Deferred — must not be forgotten

Items intentionally postponed because a tool or OS is not yet available. Each names the
trigger that unblocks it and the phase that must action it.

| # | Item | Blocked on | Trigger | Owner phase |
|---|------|-----------|---------|-------------|
| D1 | Raise iOS deployment target 26 → **27** | Xcode 27 SDK. Current: Xcode 26.0.1, iOS 26 SDK only. | Xcode 27 released (~mid-Sept 2026, with iOS 27) | Phase 4 |
| D2 | Link `MusicUnderstanding`, implement `BPM-04` | Same — the framework is absent from the iOS 26 SDK | Xcode 27 installed | Phase 4 |
| D3 | Run `Tools/mu-validate.swift` accuracy spike | macOS 27 (framework needs the OS 27 wave) | Mac updated to macOS 27 | Phase 4 (gate) |
| D4 | GitHub Pages backlink page goes live | GitHub Actions disabled at **account** level — Pages builds on Actions | Owner re-enables Actions in GitHub billing settings | Cosmetic only — GetSongBPM was dropped, so nothing depends on it |

## D1/D2 — how this is kept honest

The app builds against **iOS 26** until Xcode 27 arrives. To guarantee the bump is not
silently skipped:

1. The BPM resolver ships behind a protocol seam from Phase 1, with the Music Understanding
   tier as a **stub that throws `unavailable`**, not as missing code.
2. Phase 4 ships a **skipped test** asserting the real Music Understanding tier returns a
   tempo — skipped with an explicit "requires iOS 27 SDK" reason, so it appears in every
   test run as a visible reminder rather than an absence.
3. `BPM-04` cannot be marked Complete while that test is skipped.

Rationale: a deferred integration with no failing or skipped test attached is a deferred
integration that gets forgotten. Recording the intent in prose is not sufficient.

## Ground truth already prepared (ready the moment D3 unblocks)

- 40 ground-truth tracks sampled across four tempo bands from `walkman-dj/library.db`
- **29 matched on SoundCloud (72%)** using a duration sanity bound + weighted
  artist/title similarity
- 13 MB of 30-second previews cached locally
- `Tools/mu-validate.swift` scores tempo (octave-error aware) and Camelot distance

So D3 is one compile and one run, not a research task.
