# Deferred — must not be forgotten

**Revised 2026-08-29** after the decision to build against whatever toolchain is actually
installed. The former blockers are now **resolved by substitution**, not waiting.

## Verified toolchain (checked, not assumed)

```
macOS                     26.6.2   (sw_vers)
Xcode                     26.0.1
SDKs                      iOS 26.0, macOS 26.0   (xcodebuild -showsdks)
MusicUnderstanding in SDK          NOT PRESENT
MusicUnderstanding on system       ABSENT
```

**Governing rule: no phase may be planned against an SDK that is not installed.**
Re-verify with `xcodebuild -showsdks` before believing any claim to the contrary — an OS
update alone does not add an SDK; the SDK ships with Xcode.

## Resolved by substitution

| # | Was | Now | Status |
|---|-----|-----|--------|
| D1 | Raise deployment target to iOS 27 | **Target iOS 26** — the installed SDK | ✅ Resolved |
| D2 | Link `MusicUnderstanding` for BPM/key | **In-house Accelerate/vDSP analyser** behind `AudioAnalyzing` | ✅ Resolved |
| D3 | Run the accuracy gate (needed macOS 27) | **Runs today** against the in-house analyser and the cached ground truth | ✅ Unblocked |
| D4 | GitHub Pages backlink | Cosmetic — GetSongBPM was dropped, nothing depends on it | ⏸️ Ignorable |

## Optional future swap — not a blocker

| # | Item | Trigger | Notes |
|---|------|---------|-------|
| F1 | Swap in Apple Music Understanding behind `AudioAnalyzing` | Xcode 27 installed **and** `MusicUnderstanding.framework` present in the SDK | Drop-in. `BPM-08` exists precisely so no caller changes. Only worth doing if it measurably beats the in-house analyser on the same ground-truth set — compare, don't assume Apple wins. |
| F2 | Raise deployment target 26 → 27 | Only if F1 is taken | Nothing else needs it |

**Do not treat F1 as owed work.** If the in-house analyser hits acceptable accuracy, the
project is finished and F1 is a curiosity.

## The ground truth that makes this testable today

Already built and preserved in `.local/` (gitignored, 14 MB) — do NOT rebuild, it cost real
API calls:

| File | What |
|---|---|
| `truth.tsv` | 40 tracks sampled across four tempo bands, known BPM + Camelot from `walkman-dj/library.db` |
| `mu_dataset.json` | 29 of them matched to SoundCloud (72% hit rate, duration bound + similarity scored) |
| `mu_audio/*.mp3` | those 29 tracks' audio, 30 s each, 13 MB |
| `bpmkey.db` | the 6,608-row tier-0 corpus, 880 KB, `journal_mode=delete` |
| `ocr/ocr2.swift`, `ocr/ocr2_out.json` | EXIF-correct Vision probe + its results on all 12 fixtures |

`Tools/mu-validate.swift` already scores tempo (octave-aware) and Camelot distance. It needs
retargeting from `MusicUnderstandingSession` to the in-house `AudioAnalyzing` — that is
Phase 4's first task, and it is a small edit, not new work.

## Known ceilings carried forward

| Item | Ceiling | Revisit when |
|---|---|---|
| Non-decreasing BPM | Real sets arc (warm-up → peak → cool-down). Monotonic keeps the DAG tractable. | A real set sounds wrong |
| Beam width 50 | Unproven sufficient. Guarded by a divergence check against a wider beam. | The widths disagree |
| Tier-0 corpus | Skews house/techno — only 12% in the 160–184 BPM band | Measure the real hit rate in Phase 4 |
| 30-second previews | All SoundCloud returns. Ample for tempo; may miss the tonal centre for key | `BPM-09` measures exactly this |
