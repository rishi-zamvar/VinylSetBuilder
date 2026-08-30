# Project Research Summary

**Project:** Vinyl Set Builder
**Domain:** On-device iOS scanner + constrained-search optimizer (camera → OCR → deterministic segmentation → networked/on-device metadata resolution → DAG/beam-search sequencing → local persistence), single-user, personal, undistributed
**Researched:** 2026-08-29
**Confidence:** MEDIUM-HIGH. HIGH on SwiftData mechanics, concurrency patterns, sequencer algorithm choice, GRDB bundling. MEDIUM on Vision-vs-curved-label behavior and on Music Understanding's exact accuracy on distorted/lo-fi jungle-DnB source material (both are the same open question — real fixtures haven't been run yet). LOW on GetSongBPM backlink viability (now moot — GetSongBPM is dropped).

## Superseded By Later Decisions

The five research files above were produced under an iOS 17 constraint and a GetSongBPM-centric BPM/key plan. **That constraint no longer holds.** The project has locked onto **iOS 27** as the deployment target specifically to use Apple's on-device Music Understanding framework. Treat the following as stale, not as live options to weigh:

- **STACK.md's entire Vision recommendation is inverted.** STACK.md correctly argued `VNRecognizeTextRequest` over the new `RecognizeTextRequest` *because* the deployment target was iOS 17. With the target now iOS 27, that argument's premise is gone: the Swift-native `RecognizeTextRequest` (iOS 18+) is available and is now the preferred API — async/await ergonomics, no completion-handler/`VNImageRequestHandler` boilerplate, same underlying detector otherwise. STACK.md's "Do NOT use the new Swift-native API" instruction is superseded; do use it.
- **All hand-written DSP paths are dead.** aubio (BPM-SOURCES.md D11) and Essentia (D12) were live fallback candidates in BPM-SOURCES.md; both are now explicitly out of scope per PROJECT.md. Music Understanding's `MusicUnderstandingSession` replaces them outright — no C library, no bridging header, no GPL/AGPL footnote to track.
- **GetSongBPM is fully dropped**, not merely deprioritized. BPM-SOURCES.md tier 2 and EMPIRICAL-FINDINGS.md's GitHub Pages investigation (README not server-rendered; Actions disabled account-wide) are now moot — there is no backlink to satisfy because there is no GetSongBPM integration. Do not resurrect the GitHub Pages fix as a project task.
- **Spotify audio-features is dead, confirmed empirically, not merely "check before relying on it."** BPM-SOURCES.md B4 correctly flagged this as needing a live test; EMPIRICAL-FINDINGS.md ran that test and got a 403. The owner's client is not grandfathered. Remove Spotify from the tier ladder entirely — do not code a Spotify resolution source, not even as a stub.
- **AcoustID is dead by construction**, and now for a second reason. Originally ruled out because it fingerprints known recordings and doesn't yield tempo/key. Now redundant on top of that: Music Understanding needs no fingerprint match at all, it analyzes the raw audio directly.
- **AcousticBrainz bundled-dump idea (BPM-SOURCES.md A1, tier 3) is downgraded from "good backlog item" to "skip."** It was already MBID-gated (same white-label coverage gap as everything else) and required a 589GB one-time off-device ETL. Music Understanding gives equal-or-better coverage on anything reachable via SoundCloud, for zero ETL effort. Not worth building.
- **ARCHITECTURE.md's `BPMKeySource.swift` file in the Resolution tier list should be read as "Music Understanding analysis step," not "GetSongBPM HTTP client."** The component boundary (a source that fills BPM/key fields, composed into the resolution ladder) is still correct — only its internal implementation changes from an HTTP call to a local `MusicUnderstandingSession` run against SoundCloud-fetched audio.
- **PITFALLS.md Pitfall 6 (BPM octave-fold rule) is likely obsolete, not just de-risked.** That pitfall exists because a *database-sourced or hand-typed* BPM number can carry an octave error with no way to disambiguate. Music Understanding computes BPM directly from audio and does not have this failure mode the same way (real tempo trackers still make octave errors, but not because a text/API field was ambiguous). Keep a lighter-weight sanity check (flag/allow-override if resolved BPM is under 100 for a jungle/DnB/garage record) but do not port the "fold to ×2" rule as designed — verify Music Understanding's real output distribution against fixtures before deciding whether any fold is needed at all.
- **PITFALLS.md Pitfall 9 (public-repo key exposure, throwaway-Discogs-account mitigation) still applies to Discogs and MusicBrainz** but the GetSongBPM-specific half of that pitfall (backlink-driven forced-public-repo tradeoff) no longer has a forcing function — the repo can stay public or go private on its own merits now that GetSongBPM isn't dictating it. PROJECT.md still says public repo; that's fine, just note the *reason* changed (no longer "required by GetSongBPM").
- **Everything else in STACK.md, ARCHITECTURE.md, FEATURES.md, and PITFALLS.md (SwiftData ordering gotchas, GRDB bundling recipe, TaskGroup throttling pattern, segmentation/sequencer split, beam-search-vs-DP tradeoff, curved-label OCR risk, feature landscape/competitor analysis) is unaffected by the pivot and should be read as written.**

## Executive Summary

This is a personal, single-device iOS tool that turns photographs of vinyl labels into a sequenced, playable DJ set — camera and OCR are the input method, a one-track-per-record BPM/Camelot-optimizing sequencer is the actual product. Competitor research (FEATURES.md) confirms the OCR-to-metadata half is a solved, if immature, product category (VinylBPM ships almost this exact pipeline on the App Store, badly) — so effort should concentrate on the sequencer, which no competitor has: nothing else models "physical media forces exactly one selection per record" with full re-optimization on every addition.

The technical approach locked after research and a subsequent pivot is: Swift/SwiftUI only, targeting **iOS 27** to unlock Apple's on-device **Music Understanding framework** (`MusicUnderstandingSession`) for BPM and musical key — this replaces GetSongBPM, Spotify audio-features, AcoustID, and all hand-rolled DSP (aubio/Essentia) in one move, eliminating an entire class of licensing, rate-limit, and backlink-compliance problems the original research had to work around. OCR runs on-device via Vision, now using the modern Swift-native `RecognizeTextRequest` (available because the floor moved to iOS 18+ equivalent). SoundCloud (proven OAuth from the CrateDig project) supplies audio for tracks Music Understanding needs to analyze — fetched in-memory, analyzed, discarded, matching SoundCloud's own ToS carve-out for session-based caching. A bundled, read-only SQLite of the owner's own 7,010-row DSP-tagged library (`library.db`, same jungle/DnB/garage genres) is tier 0 of the resolution ladder: free, instant, offline, and unique to this owner.

The dominant risk is not the stack — it's whether the two hardest deterministic-geometry problems actually work on real labels: whether Vision (old or new API) can read text that curves around a label's circumference, and whether radial-distance clustering is even the right segmentation signal for a collection that the project's own PROJECT.md says is "heavy on white labels and dubplates" (i.e., mostly plain-paper, horizontal-text labels, not concentric major-label pressings). Both must be spiked against real fixture photos before segmentation logic is designed, not assumed. Every other risk (beam-search suboptimality, SwiftData array-ordering, BPM octave errors, fuzzy-match false positives) has a cheap, known mitigation and is a Phase-level concern, not an architectural one.

## Key Findings

### Recommended Stack (as pivoted)

| Technology | Purpose | Why |
|---|---|---|
| Swift 6.2 / SwiftUI, **iOS 27+** | Language/UI, deployment floor | Locked to unlock Music Understanding; iPhone 14 Pro is fully supported |
| Vision `RecognizeTextRequest` (Swift-native, iOS 18+) | OCR | Now the preferred API given the iOS 27 floor — supersedes STACK.md's `VNRecognizeTextRequest` recommendation, which was correct only under the old iOS 17 constraint |
| **`MusicUnderstandingSession`** (Music Understanding framework, iOS 27+) | BPM (`RhythmResult.beatsPerMinute`) + key (`KeySignature`) from an `AVAsset` or live buffer | On-device, offline, free, Apple-maintained, Neural-Engine-accelerated. Replaces GetSongBPM, Spotify audio-features, AcoustID, aubio, Essentia — one API surface for both the SoundCloud-fetch path and a future/deferred microphone path |
| SwiftData | Mutable app persistence (Crate/VinylEntry/Track) | Native, zero dependency, fine at this scale (<100 vinyls, <400 tracks). Ordering gotcha below is load-bearing |
| GRDB.swift 7.11.1, readonly | Bundled `library.db` (7,010-row tier-0 lookup) | SwiftData cannot open a hand-built external SQLite schema; GRDB's fuzzy-match-friendly query interface is worth the one dependency |
| URLSession | Discogs / MusicBrainz / SoundCloud calls | Three simple REST integrations; no networking wrapper needed |
| Local SPM package (`VinylSetBuilderCore`) | Segmentation, sequencing, resolution, GRDB wrapper, domain models | Mirrors the owner's existing CrateDigCore/CrateDigMac split; makes "no camera, no network in tests" a compile-time fact by never linking AVFoundation/URLSession in the package's test target |

### Table Stakes vs Differentiators

**Table stakes (commodity — build to "good enough," not the innovation):**
- Continuous capture loop, no modal wait between shots
- On-device OCR + deterministic segmentation into candidate tracks
- BPM shown per track, Camelot code (not raw musical key) shown per track
- Manual correction of any resolved field
- Persistent crates across sessions
- Reorderable set list with drag override
- Exclusion visibility with a stated reason

**Label OCR → metadata resolution is explicitly commodity, not differentiator.** VinylBPM already ships label-photo OCR → Discogs/MusicBrainz resolution → Camelot suggestions on the App Store (rough, 1-star/1-review, but real and live). This validates the market need but means zero competitive credit accrues to doing OCR well — it's necessary, not sufficient.

**The uncontested differentiator, where build effort should concentrate:** the **one-track-per-vinyl, BPM-gated, Camelot-optimized sequencer with full re-optimization on every addition** (including readmitting previously-excluded records). No competitor — not VinylBPM, not SetFlow/Mixgraph/CrateHackers, not Rekordbox/Serato's own smart playlists — models the physical constraint that one vinyl can only contribute one track to a set, or re-solves the whole set when new physical media arrives. This is the Core Value in PROJECT.md and is confirmed by direct competitor analysis, not merely asserted.

Secondary differentiators worth their (low) cost: provenance-tagged confidence per field (auto/low-confidence/manual — independently converges with VinylBPM's own pattern), a fast hand-entry sheet built as first-class UX rather than an error state (no competitor treats this seriously, and it's the necessary floor given how many white labels/dubplates won't resolve automatically), and the bundled `library.db` tier-0 lookup (literally unique to this owner, replicable by no one else).

**Deliberately not built (anti-features):** audio playback/cue points, cloud sync/multi-device, collection/valuation features, a general Rekordbox-style rule-builder, strict-monotonic-BPM relaxation at MVP, and — per the pivot — any microphone-listening BPM fallback (VinylBPM offers this; explicitly rejected here because it requires the record to be playing, contradicting the "scan without waiting" goal; may be revisited only if SoundCloud hit-rate proves too low).

### Architecture Approach

Four pure protocol seams carry the whole app: `LabelTextRecognizing` (Vision, DTO-converted immediately so segmentation never touches Vision's own types), `LabelSegmenting` (pure geometry, `[TextObservation] → [Track]`), `MetadataResolving` (ladder-composed: bundled DB → cache → MusicBrainz → Discogs → Music-Understanding-via-SoundCloud), and `Sequencing` (pure, stateless, full re-derivation every call — no incremental diffing). A `VinylSetBuilderCore` Swift package holds all four plus domain models and never imports AVFoundation/URLSession, making segmentation and sequencer tests fixture-driven and camera/network-free by construction. `CrateSession`, an `@MainActor @Observable` orchestrator, owns one cancellable `Task` per captured photo (not one shared `TaskGroup` spanning the session, which can't support per-item cancellation) and a bounded-concurrency (`max 3`) `TaskGroup` for the resolution stage only, with a 400ms-debounced resequence trigger.

**Major components:**
1. `LabelCapturing` (AVFoundation) — owns the capture session, returns a `CGImage` per shutter press, blocks on nothing
2. `LabelTextRecognizing` / `LabelSegmenting` — OCR and geometric segmentation, kept as two seams because "recognize text" and "decide which text forms a track" are genuinely different algorithms
3. `MetadataResolving` — the resolution ladder, composed of independently-testable `ResolutionSource` tiers, now including a Music-Understanding-via-SoundCloud tier in place of the original GetSongBPM tier
4. `Sequencing` — pure beam-search function (width 50, per PROJECT.md decision), called off-main, debounced, fully re-run rather than incrementally patched
5. SwiftData persistence — last to stabilize, dictated by final `Track`/`VinylEntry`/`Crate` shape

### Critical Pitfalls (ranked, top 5 of 10 identified)

1. **Curved-baseline OCR is the single highest risk in the project.** Neither the old nor the new Vision API models a baseline that curves within a single line of text (concentric label typography) — they only handle whole-line rotation. If this fails, segmentation, resolution, and sequencing never see real input. **Must be spiked against real fixture photos (both concentric major-label pressings and plain-paper white labels) before Phase 2 segmentation design locks.**
2. **Radial-distance-from-center clustering likely doesn't fit this collection.** PROJECT.md's own Context section says the crate is "heavy on white labels and dubplates" — typically plain paper with ordinary horizontal typed/stamped lines, not concentric text. A layout classifier (bucket by observed baseline angle: horizontal vs. arc-following) should decide the clustering strategy per label, not a single global radial assumption.
3. **Beam width 50 with no divergence check can silently drop the true best sequence.** Cheap guard: run beam search at two widths (50 and 150) and compare admitted-vinyl-count; disagreement signals the beam is too narrow. The spec's own DP fallback is exact and tractable at this scale (<100 vinyls) if beam search proves unreliable.
4. **SwiftData does not durably preserve array/relationship order.** `Crate.sequence`, `VinylEntry.candidates` must use explicit `Int` ordering fields or plain scalar (`[UUID]`) attributes, never trust to-many relationship fetch order. This must be locked into the model design before Phase 0's stubs harden into real `@Model` types — retrofitting later is a rewrite, not a patch.
5. **String matching to Discogs/MusicBrainz fails in predictable, genre-specific ways** — catalog numbers read as titles, VIP/dub/remix suffixes, featured-artist billing variants, short-string false-positive risk. Fix is pre-normalization (separate title/artist scoring, strip catalog-number patterns post-segmentation) not threshold-tuning.

## Riskiest Assumptions, Ranked (feeds directly into phase gating)

| Rank | Assumption | Why It's Risky | Phase That Must Test It |
|---|---|---|---|
| **1** | Vision (`RecognizeTextRequest`, iOS 18+ API) can read curved/concentric label text well enough to be useful | No curved-baseline text model exists in either Vision generation; failure here poisons every downstream phase | **Phase 1** — spike against 10-15 real label photos (mixed concentric + plain-paper) before any segmentation code is written; this is the #1 go/no-go gate for the whole project |
| 2 | Radial-distance-from-center is the right segmentation signal | Project's own collection is stated to be majority plain-paper/white-label, which is the case radial clustering fits worst | Phase 1's spike output feeds directly into **Phase 2** design — classify layout (horizontal vs. arc) before committing to one clustering strategy |
| 3 | SoundCloud has meaningful hit-rate on jungle/DnB/UKG white labels and promos that Discogs/MusicBrainz miss | The entire audio-analysis tier of the resolution ladder depends on SoundCloud actually having the obscure tracks; untested against this owner's real crate | **Phase 3** (Metadata Resolution) — measure real hit-rate on fixture tracks known to be Discogs-absent; if low, manual entry absorbs more volume than planned, which is fine (it's first-class) but should be known, not assumed |
| 4 | `MusicUnderstandingSession` produces accurate BPM/key on lo-fi, sub-heavy, deliberately-distorted jungle/DnB source audio (promos, rips) rather than clean studio masters | Framework is new (WWDC26); no published benchmark exists for this specific genre's audio characteristics (heavy bass, breakbeats, pitched/distorted basslines make key detection specifically hard per BPM-SOURCES.md) | **Phase 3** — run Music Understanding against a handful of fetched SoundCloud tracks from known BPM/key (cross-check against the bundled `library.db` ground truth) before trusting it as an unattended resolution tier |
| 5 | Beam search width 50 finds the true-best (or near-best) sequence at real crate scale | Silently drops a valid vinyl without looking "broken" — the output still looks plausible | **Phase 4** — two-width divergence check (50 vs 150) plus a regression fixture snapshot |
| 6 | SwiftData ordering can be made reliable via explicit index fields | Documented framework gap; retrofitting after UI assumes array order is a rewrite | **Phase 0** (model design, before Phase 5 build) — lock ordering-field design at domain-model definition time |
| 7 | Fuzzy string matching (post-normalization) hits ≥70% auto-resolve without false-positive wrong-match risk | Catalog numbers, remix suffixes, and billing variants are genre-specific failure modes that a naive threshold won't catch | **Phase 3** — sample-audit auto-resolves against physical labels, not just resolve-rate percentage |

## Implications for Roadmap

### Phase 0: Domain Models + Protocol Seams + UI Shell (pull sequencer in parallel)
**Rationale:** Every downstream phase depends on the four protocol seams (`LabelTextRecognizing`, `LabelSegmenting`, `MetadataResolving`, `Sequencing`) and stable domain model shapes (`Track`, `VinylEntry`, `Crate`, `SequenceResult`) existing first — and SwiftData's ordering gotcha (Pitfall 4 above) means ordering fields must be designed into the model from day one, not retrofitted.
**Delivers:** Compiling `VinylSetBuilderCore` package with fixture stubs (`FixtureMetadataResolver`, `NaiveBPMSortSequencer`), a real `CrateSession` orchestrator wired against the stubs (background-resolution/debounce/cancellation machinery built for real now, not deferred), and a thin SwiftUI shell.
**Recommendation — pull the sequencer forward here, not in Phase 4:** the beam-search sequencer (§5) has zero dependency on segmentation or resolution, only on the `Track` struct shape, and is a direct, already-validated port of the existing CrateDig Python beam search. Build and fully unit-test it in parallel with Phases 1-2 (camera/OCR/segmentation), which are the actual critical-path unknowns. This de-risks the one genuinely nontrivial algorithm in the app while schedule risk sits elsewhere. The Phase 4 *ship checkpoint* (wiring the real sequencer into the real UI, replacing the stub) stays where it naturally falls in the dependency chain; the *implementation and test suite* do not need to wait for it.

### Phase 1: Camera + OCR — the #1 go/no-go spike
**Rationale:** This is where Risk #1 (curved-label OCR) must be resolved before any further design commitment. Everything downstream is worthless if this fails.
**Delivers:** Continuous capture loop (shutter returns immediately, per PROJECT.md), `RecognizeTextRequest`-based OCR wrapper, and — critically — a scored spike against 10-15 real fixture photos split across concentric-major-label and plain-paper-white-label types. Freeze the raw `[TextObservation]` output as committed JSON fixtures; this is what makes Phase 2 buildable without a camera from that point on.
**Avoids:** Pitfall 1 (curved-baseline OCR), Pitfall 3 (glare/motion blur/spindle confusion — mitigated by capture-time quality warnings, not clever image processing), Pitfall 8 (thermal/memory on rapid-fire capture — mitigated by immediate downscale-after-OCR as the default).
**If the spike shows curved text fails badly:** budget a polar-unwrap preprocessing step (detect label as a circle, unwarp the annulus into a rectangular strip) before Phase 2 segmentation design locks — this is a known, proven technique for OCR-on-circular-surfaces, not a novel idea, but it's real added scope that should be sized here, not discovered in Phase 2.

### Phase 2: Multi-Track Segmentation
**Rationale:** Cannot be meaningfully designed until Phase 1's spike shows what kind of observations actually come back for each label layout type.
**Delivers:** `LabelSegmenting` real implementation, tested purely against Phase 1's frozen JSON fixtures (no camera, no Vision call from this point forward). Must explicitly branch by detected layout (horizontal-line vs. arc-following baseline angle) rather than committing to radial-distance clustering as the only strategy.
**Avoids:** Pitfall 2 (radial clustering mismatched to majority white-label collection). Ship criterion should be stratified — measure accuracy separately per label type, not one blended 8/10 number that can mask a total failure on one type.

### Phase 3: Metadata Resolution (including Music Understanding tier)
**Rationale:** Needs discrete candidate tracks from Phase 2 to resolve. This is also where Risk #3 (SoundCloud hit-rate) and Risk #4 (Music Understanding accuracy on this genre) get tested empirically, and where the fast manual-entry sheet is built as a first-class completion path, not an afterthought.
**Delivers:** `LadderMetadataResolver` composing tiers in priority order — bundled `library.db` (tier 0, free/instant) → persisted resolution cache → MusicBrainz (identity only) → Discogs (identity/format only, confirmed to carry no BPM field) → SoundCloud-fetch-then-`MusicUnderstandingSession`-analyze (BPM + key for anything Discogs/MusicBrainz miss) → manual entry (floor, first-class UX: select-over-type Camelot grid, pre-filled BPM defaults from the previous track, inline correction, raw OCR text always visible).
**Addresses:** FEATURES.md's confidence/provenance badges (auto/low-confidence/manual), tiered resolution, fast manual-entry UX detail.
**Avoids:** Pitfall 4 (string-matching genre-specific failure modes — normalize before comparing, score title/artist separately), and validates or invalidates the BPM octave-fold question fresh given Music Understanding replaces database-sourced BPM as the dominant source (see Superseded section — don't port the old fold rule unexamined).
**Needs research during planning:** yes — Music Understanding's real-world accuracy profile on lo-fi/promo/distorted electronic audio has no published benchmark; this phase should budget explicit spike time against known-ground-truth tracks (cross-check against `library.db`) before trusting it unattended.

### Phase 4: Sequencer Ship Checkpoint
**Rationale:** By this point the real `BeamSearchSequencer` was already built and unit-tested in parallel back in Phase 0/1; this phase is specifically about wiring it into the real UI flow (replacing `NaiveBPMSortSequencer`) against real resolved data from Phase 3.
**Delivers:** Full one-track-per-vinyl, BPM-gated, Camelot-optimized sequence with re-optimization triggered on Done, on subsequent adds, and on any individual track resolving after the fact (debounced 400ms to absorb resolution bursts).
**Avoids:** Pitfall 5 (beam-search suboptimality) via the two-width divergence check and a regression fixture snapshot.

### Phase 5: Persistence
**Rationale:** Deliberately last — the one component whose implementation is dictated by the final, stabilized shape of `Track`/`VinylEntry`/`Crate`, per architecture research. (Note: the *ordering-field design* itself must be locked in Phase 0, not here — this phase is about the `@Model` mapping and migration path, not retrofitting order-safety.)
**Delivers:** SwiftData `@Model` classes, `CachedResolution` table (tier-1 resolution cache, keyed on normalized artist+title, shared across crates), restart-survival verified for both data *and* order (not just data existing).
**Avoids:** Pitfall 7 (SwiftData ordering) — verify explicitly, since "crates survive app restart" as a ship criterion is often satisfied by checking data exists, not that sequence/candidate order survived.

### Phase Ordering Rationale

- **OCR/segmentation before resolution before sequencing** is a strict data-dependency chain — you cannot resolve or sequence what hasn't been segmented into discrete candidate tracks.
- **Sequencer implementation pulled forward to run in parallel with Phases 1-2**, per architecture research's explicit build-order recommendation — it has zero dependency on the critical-path unknowns (camera hardware, OCR curved-text behavior) and is a direct algorithm port already proven in the CrateDig Python codebase. This is the single highest-leverage schedule optimization available: it de-risks a nontrivial algorithm while the team is blocked on fixture-photo spikes elsewhere.
- **Persistence last**, because the ordering-safety *design* must be locked at Phase 0 (cheap, before code assumes array order) while the ordering-safety *implementation* (actual `@Model` mapping, migrations) can safely wait until the domain shape stabilizes after Phase 4.
- **This ordering directly avoids Pitfalls 1, 2, 5, and 7** — each pitfall's "prevention phase" in PITFALLS.md's own mapping table lines up with this sequence, and each is addressed at the point where getting it wrong would otherwise be discovered latest and cost the most to fix.

### Research Flags

**Needs deeper research during planning (`/gsd:research-phase`):**
- **Phase 1** — curved-label OCR behavior has no rigorous published benchmark specific to vinyl labels; the "research" here is really an empirical spike against real fixtures, not a literature review. Flag for hands-on investigation, not desk research.
- **Phase 3** — Music Understanding framework is brand new (WWDC26, June 2026); sparse third-party documentation, no accuracy benchmarks on genre-atypical (bass-heavy, distorted, breakbeat) source material. SoundCloud fetch-then-analyze wiring (in-memory only, ToS-compliant, no persisted audio) is a new integration pattern for this project and should be researched/prototyped before the phase's main build.

**Standard patterns, skip deep research:**
- **Phase 0** — SwiftData model design, protocol-seam architecture, and TaskGroup throttling are all well-documented, stable patterns already fully specified in ARCHITECTURE.md.
- **Phase 2** — Once Phase 1's spike output exists, segmentation is pure deterministic geometry against frozen fixtures; well-scoped, no external API surface.
- **Phase 4** — Beam search / DP fallback is a known algorithm already ported from working code; the divergence-check mitigation is straightforward to implement.
- **Phase 5** — SwiftData is a mature-enough, well-documented API for this project's scale; the ordering gotcha is already fully characterized in PITFALLS.md with a concrete fix.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Core mechanics (SwiftData, GRDB, concurrency) verified against official docs and are HIGH confidence; the OCR-API recommendation itself needed correcting post-pivot (now done above), and Music Understanding's exact accuracy characteristics are unverified against real audio |
| Features | MEDIUM-HIGH | Direct competitor evidence (VinylBPM, CrateLog, SetFlow, Rekordbox/Serato conventions) is well-sourced; no Context7-tier docs exist for this consumer-app niche, so specific competitor-feature claims are cross-verified but MEDIUM on any single source |
| Architecture | HIGH on mechanics, MEDIUM on the specific orchestration design | Protocol-seam split and SwiftData/concurrency mechanics are HIGH (stable, well-documented iOS APIs); the exact `CrateSession` orchestration shape is the researcher's synthesis for this spec, not a single canonical reference pattern |
| Pitfalls | MEDIUM-HIGH | SwiftData ordering, beam search incompleteness, tempo octave errors, AVCaptureSession behavior are HIGH (well-documented); Vision-on-curved-labels specifically has no rigorous published benchmark and is flagged as needing an early spike rather than being answerable from literature |
| BPM/Key sourcing (post-pivot) | MEDIUM | The pivot to Music Understanding is well-justified by the original BPM-SOURCES.md research (it independently surfaced Music Understanding as "the strongest route you didn't ask about"), but its real-world accuracy on this specific genre's audio is unverified — no published benchmark exists for a framework that shipped in June 2026 |

**Overall confidence:** MEDIUM-HIGH. The stack and architecture decisions are sound and well-sourced; the two genuine unknowns (curved-label OCR, Music Understanding accuracy on lo-fi electronic source audio) are both correctly identified as spikes rather than assumptions, and both have clear, cheap ways to fail fast early in the roadmap (Phase 1 and Phase 3 respectively) rather than being discovered late.

### Gaps to Address

- **Curved-label OCR behavior is unverified against real photos** — must be spiked in Phase 1 before segmentation design locks (Risk #1). This is the single most important unresolved question in the whole project.
- **Music Understanding's accuracy on jungle/DnB/UKG source material (bass-heavy, breakbeat, occasionally deliberately distorted) is unverified** — no published benchmark exists for a framework that shipped weeks before this research. Cross-check against the bundled `library.db`'s known-good BPM/Camelot values in Phase 3 before trusting it unattended.
- **SoundCloud hit-rate on this owner's specific white-label/dubplate/promo material is unmeasured** — Phase 3 should measure this directly rather than assume BPM-SOURCES.md's qualitative "disproportionately where jungle/DnB producers upload promos" holds for this exact crate.
- **Radial-vs-horizontal segmentation split across the real collection is unmeasured** — PROJECT.md asserts the collection is "heavy on white labels," but the actual ratio of concentric-vs-horizontal-text labels in the real crate should be measured from Phase 1's fixture set, not assumed, since it determines how much segmentation-strategy branching (Pitfall 2) is actually needed.
- **The exact GetSongBPM-era Discogs/MusicBrainz identity-resolution logic in ARCHITECTURE.md and PITFALLS.md is unaffected by the pivot and can be built as designed** — no gap here, noted for completeness so the roadmapper doesn't second-guess it.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation (Vision, SwiftData, `ModelConfiguration`, WWDC23 structured concurrency, WWDC26 Music Understanding session) — official, multiply-verified
- Empirical tests run directly against the owner's own credentials (Spotify 403, GitHub Pages build failure, `library.db` row counts) — EMPIRICAL-FINDINGS.md, ground truth for this specific setup
- GitHub `groue/GRDB.swift` releases API — verified directly
- Direct competitor product pages/App Store listings (VinylBPM, CrateLog, SetFlow, Mixgraph, Rekordbox/Serato documentation) — FEATURES.md

### Secondary (MEDIUM confidence)
- Apple Developer Forums threads on `customWords` behavior and AVCaptureSession/Swift 6.2 concurrency wiring — live, unresolved community discussion, not a single blessed answer
- SwiftData pitfalls (Wade Tregaskis, Fatbobman) — consistent independent community reports on ordering/Sendable gaps
- Beam search incompleteness literature (Muthukrishnan, arXiv 2312.12554) — general algorithmic property, not vinyl-specific
- WWDC26 Music Understanding community digest (github.com/ivan-magda/wwdc26-notes) — session notes, not yet independently benchmarked against real audio

### Tertiary (LOW confidence, needs validation)
- GetSongBPM backlink interpretation ("GitHub README counts as a public listing") — moot post-pivot, GetSongBPM dropped entirely
- `customWords` numeric limits — no authoritative Apple documentation found; moot in practice since OCR strategy shifted to the new Vision API but the underlying uncertainty about bias-list effectiveness on stylized label fonts still applies
- Music Understanding accuracy on genre-atypical (bass-heavy, distorted) audio — no published benchmark exists at all; this is a Phase 3 spike, not a researchable question

---
*Research completed: 2026-08-29*
*Ready for roadmap: yes*
