# Feature Research

**Domain:** Vinyl crate-digging / DJ set-building tool (personal iOS app)
**Researched:** 2026-08-29
**Confidence:** MEDIUM-HIGH (direct competitor evidence found via WebSearch/WebFetch; no Context7-tier docs exist for this consumer-app niche, so treat feature claims about specific apps as MEDIUM confidence unless cross-verified)

---

## Q1 — Does an app already do this? (Direct Answer)

**No single app does the full job this project wants, but the pieces exist separately, and one competitor (VinylBPM) is close enough that it must inform scope.**

Breaking the question apart:

**"Photograph a vinyl label and OCR-identify the record" — SOLVED, multiple times over.**
- **VinylBPM** (iOS, App Store, launched ~2026) is the closest analog to this entire project. Its pitch is literally "point your phone at any label or sleeve," OCRs the visible text (explicitly built for "hand-stamped promos, white labels, bootlegs, older releases" — i.e. exactly this owner's collection), resolves metadata via Discogs/GetSongBPM/MusicBrainz, and offers **Camelot mix suggestions** plus **CSV export for Rekordbox/Serato**. It is a freemium app ($9.99/mo or $99/yr Pro), iOS-only, and as of the last visible review (July 2026) had **1 rating at 1.0 stars** citing upload errors — i.e. it is real, live, doing almost exactly this, and currently rough/immature. Source: [vinylbpm.com](https://vinylbpm.com/), [App Store listing](https://apps.apple.com/us/app/vinylbpm/id6761032214).
- **CrateLog** (Android now, iOS "coming soon") identifies records from the center label via on-device machine vision + cloud recognition, explicitly working on worn/partial labels without barcodes — but it is a pure **collection/cataloging** tool (Discogs integration, price tracking, duplicate detection). It has **no BPM, no key, no DJ features of any kind**. Source: [cratelog.app](https://cratelog.app/).
- **VinylAI**, **Vinyl Value**, **VinylSnap** identify records primarily from **cover art photos** (not label OCR) for valuation/cataloging purposes — same category as CrateLog, not DJ tools.
- **Discogs' own app**: barcode scanning only, confirmed via forum threads and the app's own scan flow. It does **not** do label OCR. This is precisely the gap third-party apps (VinylBPM, CrateLog) exist to fill — validated need, not a hunch.

**"Sequence a full DJ set (ordered, BPM-gated, Camelot-optimized, one track per record, re-optimizes on add)" — NOT SOLVED by anything that also does label OCR.**
- VinylBPM stops at pairwise "which records mix harmonically" suggestions. It explicitly does **not** auto-build or sequence a complete ordered set — the user still manually picks and orders.
- Full-set sequencers that DO optimize a whole set (**SetFlow**, **Mixgraph**, theghostproduction's planner) all assume a **digital library already tagged with BPM/key** (imported from Rekordbox/Serato/Traktor, or a streaming catalog) and have **no path from a photograph of a physical object into that pipeline.** They also don't model "one track per physical unit" — that constraint doesn't exist in a digital library because nothing stops you playing two tracks off the same file.
- **CrateHackers** organizes an existing digital library by BPM/key/energy and suggests next-track matches within a set, but again assumes tracks are already digital/tagged, and is Mac/Windows desktop software integrating with Serato/VirtualDJ/Rekordbox, not a phone-camera-first tool.

**Verdict: the OCR-to-metadata half is a solved, competitive product category (VinylBPM proves it, badly). The physical-media-constrained sequencing half — one track per vinyl, full re-optimizing constraint solve — has no existing product.** That is the actual differentiator and the place to spend build effort; label OCR and metadata resolution should be built to a "good enough, get out of the way" bar rather than treated as the innovation, because a competitor already ships it (even if flakily). This validates the PROJECT.md core-value framing ("Scanning is only the input method").

---

## Feature Landscape

### Table Stakes (Users Expect These)

Pulled from what Rekordbox/Serato/Traktor/Engine DJ users take for granted, and what VinylBPM/CrateLog treat as baseline.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Continuous capture loop (shoot → auto-return to camera) | Every scanning app (VinylBPM, CrateLog, Discogs barcode scan) treats "one record = one fast tap" as baseline; a modal round-trip per record would feel broken scanning a real crate of 20+ records | LOW | Already in MVP-SPEC §2 step 3 |
| BPM shown per track, key shown as Camelot code | Rekordbox, Serato, Traktor, Mixed In Key, VinylBPM all surface these as the two headline fields for a track — DJs read a crate by BPM+key, not by title | LOW–MED | Already required; note MIK/Rekordbox both default to **Camelot notation**, not raw musical key (Am, C#m) — confirms Camelot-only display is correct, no need to also show musical key |
| Manual correction of any resolved field | Rekordbox/Serato both let you hand-edit BPM/key when analysis is wrong; VinylBPM explicitly tags every field "confirmed / inferred / user-entered" rather than presenting guesses as fact | LOW | Already in MVP-SPEC; adopt VinylBPM's confidence-labeling pattern (see Differentiators) |
| Persistent crates across sessions | Baseline expectation of literally every DJ library tool ever built | LOW | SwiftData, already scoped |
| Reorderable set list with drag-to-reorder override | Serato/Rekordbox playlists are always manually reorderable even after auto-sort; a sequencer that can't be hand-tweaked would be rejected by any working DJ | LOW–MED | MVP-SPEC §2 step 5 has this; important it's not just view-only |
| Exclusion/failure visibility with a stated reason | Rekordbox intelligent playlists show 0 results silently — a known complaint. VinylBPM tags every field's provenance. Good UX bar here is higher than Rekordbox's, not lower | LOW | MVP-SPEC already requires per-track exclusion reason string |
| BPM/key filter criteria akin to "intelligent playlists" | Rekordbox Intelligent Playlists and Serato Smart Crates both let a DJ define BPM range / key / genre rules that auto-populate — the mental model DJs already have for "a crate is a filtered, ordered view" | MED | Not in MVP scope explicitly; the BPM-tolerance slider + Camelot objective is a single global instance of this, which is sufficient for MVP — a general rule-builder is over-scope (see Anti-Features) |

### Differentiators (Competitive Advantage)

These are where this app should actually spend build effort — table stakes are commodity, differentiators are the reason it's worth building at all given VinylBPM exists.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **One-track-per-vinyl constrained sequencer with automatic re-optimization** | This is the feature nothing else has. VinylBPM gives pairwise suggestions; SetFlow/Mixgraph/CrateHackers assume infinitely-repeatable digital files. Nobody solves "physical media forces exactly one selection per record, and every new scan can reshuffle every prior selection." This is the actual product | HIGH | Already the Core Value in PROJECT.md; MVP-SPEC §5 beam-search/DAG approach is right-sized — confirmed correct scope, don't gold-plate |
| **Provenance-tagged confidence per field** (auto-resolved / low-confidence-match / manual) | VinylBPM validates this pattern ("confirmed, inferred, or user-entered") independently — converging evidence it matters when a meaningful fraction of records won't be in any database. Prevents the app quietly lying about a bad OCR-to-Discogs match | LOW–MED | Cheap to add on top of existing `matchConfidence` field already in the Track model (MVP-SPEC §1). Surface it as a badge, not just an internal threshold |
| **Fast hand-entry sheet designed as a first-class path, not an error state** | Nobody in this landscape treats manual entry as core UX — VinylBPM's marketing is entirely about *not* needing manual entry, which fails exactly on white labels/dubplates, i.e. this owner's actual collection | MED | See Q5 section below for concrete UX pattern |
| **Bundled offline personal library as tier-0 resolution (`library.db`)** | No competitor can do this — it's specific to this owner already having 7,010 DSP-tagged tracks in the same genre from a prior project. Zero-latency, zero-cost, offline-first resolution before any network call | LOW | Already decided in PROJECT.md Key Decisions; genuinely unique advantage, not replicable by a generic product |
| **Camelot distance as a soft cost function, not a hard filter, with BPM as the only hard gate** | Correctly reflects that jungle/DnB/UKG are rhythm-led genres where key mismatches are tolerated far more than tempo mismatches — most competitor tools (SetFlow scores "Camelot 35% weight") treat key and tempo as comparably weighted, which is a house/techno assumption that doesn't transfer to breakbeat genres | LOW (already speced) | Confirms MVP-SPEC §5 "Exclusion is BPM-driven only" is a genre-appropriate design choice, not a shortcut |
| **Flip-side capture prompt (auto-detect a scanned side implies an unscanned B-side)** | No general-purpose vinyl app needs this because most vinyl scanning is for cataloging (one side matters for identification), not for extracting every playable track off both sides | LOW–MED | Already speced in MVP-SPEC §4 |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Strictly non-decreasing BPM across the whole set | Reads as "simple, safe, deterministic" and matches the MVP-SPEC's current hard gate | **This is a real oversimplification and should be flagged, not silently kept** — see Q4 below. Real DJs use wave/undulating energy curves over long sets, deliberate BPM drops after a peak, and "BPM creep" (tiny non-monotonic steps) rather than a single monotonic ramp. A strict non-decreasing constraint also means a slower record scanned *after* the set has already ramped up can **never** be included, which will systematically bias the sequencer against certain records in ways a human DJ wouldn't accept | Keep non-decreasing as the **MVP default** (it's simpler to build, test, and reason about, and jungle/DnB sets often genuinely do ramp across a night) but log it explicitly as a known simplification with a stated upgrade path: a future "allow one deliberate BPM drop" or "sequence in independently-monotonic energy segments" mode. Don't build the general case now — YAGNI until the MVP proves the constraint actually feels wrong in practice |
| General-purpose rule-builder / intelligent-playlist engine (arbitrary AND/OR filters like Rekordbox's) | "Rekordbox has it, so parity" | Massive scope increase for a single-user app with one real use case (BPM+Camelot sequencing of a scanned crate). Rekordbox needs this because it manages a huge heterogeneous digital library across genres/moods; this app manages a fixed genre, physically-bounded crate | Hardcode the BPM-tolerance-slider + Camelot-cost sequencer as the one and only sequencing mode. Revisit only if a second genre/use-case actually shows up |
| Audio playback / cue points / mixing-in-app | Every DJ tool (Serato, Rekordbox, Traktor, Engine DJ) is built around this, so it's the "obvious" next feature | Explicitly out of scope per PROJECT.md — there is no audio anywhere in this pipeline (photographs of paper labels only), and playback duplicates Rekordbox/CDJs the owner already uses | None needed — Rekordbox does this already, downstream of this app's export (if ever built) |
| Cloud sync / multi-device / sharing | "Basic modern app expectation" | Single user, single device, no App Store distribution — adds auth, backend, and security surface for zero benefit | SwiftData on-device only, as already decided |
| Full Discogs-style collection/valuation features (grading, market pricing, want-lists) | CrateLog and VinylBPM both build substantial feature surface here — looks like "obviously good to have" | Completely orthogonal to the Core Value (a sequenced, playable set). Pure collection management is a different product with a different user need (the collector, not the DJ mid-set-prep) | Don't build. If ever wanted, that's a different app pointed at the same photos, not a feature of this one |
| Multiple tracks per vinyl in one sequence | Digital DJ tools have zero concept of "one file, one physical constraint," so a naive port of any digital sequencer would allow this | Already correctly identified as a hard non-negotiable rule in PROJECT.md — including it as an anti-feature here for completeness, since it's the single most tempting shortcut a lazy implementation could take (e.g. "just don't dedupe by vinylID, ship faster") | Enforce vinylID uniqueness in the sequencer's graph search, as already speced |
| Automatic BPM/key detection from audio (any AcoustID/microphone-listening feature, e.g. what VinylBPM offers as a fallback) | VinylBPM offers "play the record and let the app listen through the mic" as a fallback resolution path — looks like a reasonable answer to the "not in any database" problem | Explicitly ruled out in PROJECT.md ("There is no audio in it at any point... this also kills the spec's original AcoustID fallback"). Re-adding a microphone-listening BPM detector would be scope creep back into audio analysis territory the project deliberately excluded, and requires the record to actually be playing on a turntable at scan time, which breaks the "photograph only" capture model | Manual entry is the correct fallback, not audio listening — confirms PROJECT.md's decision was right, VinylBPM's approach is not one to imitate here |

---

## Q4 — Harmonic Mixing Conventions & the BPM-Monotonicity Question

**How Mixed In Key / Rekordbox present Camelot:** Both use the 12-hour-clock Camelot Wheel (1A–12A minor keys, 1B–12B major keys) rather than raw musical key names, specifically so DJs can do fast mental arithmetic on compatibility rather than needing music theory. Source: [Mixed In Key](https://mixedinkey.com/harmonic-mixing-guide/), [DJ.Studio](https://dj.studio/blog/camelot-wheel).

**What DJs actually treat as acceptable transitions** (converged across MIK, DJ.Studio, TrackScore, MixPrism — MEDIUM confidence, consistent across independent sources):
1. Same code (e.g. 8A→8A) — zero risk
2. ±1 on the same letter (8A→7A or 8A→9A) — a perfect-fifth shift, the most common "safe" move
3. Letter swap, same number (8A↔8B) — relative major/minor
4. ±2 or more, or a letter change *and* a number change simultaneously, is used deliberately for an energy jump/dramatic transition, not a default — treated as higher-risk, not "acceptable" in the default sense

This is consistent with the MVP-SPEC's `camelotDistance` design (0/1/1/hop-count+letter-penalty), which is a reasonable encoding of the above — no change recommended there.

**Is strictly non-decreasing BPM how real DJs build sets, or an oversimplification?**

**It is an oversimplification, and worth flagging plainly rather than treating as settled.** Evidence, independently converging across three source clusters (ZIPDJ, Mixgraph, SetFlow, HarmonySet):
- The textbook DJ set arc is **warm-up → build → peak → release → cool-down** — a curve with an explicit **descent** after the peak, not a single ramp.
- For longer sets, a **"wave" pattern** (alternating peaks and valleys) is described as the more sophisticated approach specifically because sustained monotonic energy exhausts a dance floor.
- Real tempo changes are usually **"BPM creep"** — 1–2 BPM per transition, cumulative — rather than large jumps, and skilled DJs explicitly retain the flexibility to **abandon a planned BPM curve** based on crowd reaction.
- That said: jungle/DnB/UKG sets, especially shorter warehouse/radio-style sets, commonly *do* run close to monotonic tempo — genre and set length matter. The owner's genre and typical set context should decide whether this matters in practice.

**Recommendation for this project specifically:** Keep non-decreasing BPM as the MVP hard gate — it is simpler, matches at least one common real practice in these genres, and the MVP-SPEC's beam-search/DAG design depends on it for tractability (a DAG requires a total order; a strict monotonic constraint is exactly what makes "visit each vinylID once" solvable in milliseconds per MVP-SPEC §5). But this is a genuine simplification with a real ceiling: it can never place a slower, well-matched record after a fast one, and it forecloses the classic peak→release drop. Document it as a known constraint to revisit once the owner has actually built and played a few real sets and can say whether it ever felt wrong — not something to generalize preemptively.

---

## Q5 — Manual-Entry UX for Records Not in Any Database

No competitor in this space treats manual entry as a first-class flow (VinylBPM's whole pitch is *avoiding* it), so there's no direct product to copy. General mobile data-entry UX research converges on patterns directly applicable here:

- **Select over type wherever possible.** Camelot key entry should be a 24-cell wheel/grid tap (12 numbers × 2 letters), never a text field — this alone likely accounts for most of the "under 15 seconds" budget.
- **Smart defaults from context, not blank fields.** BPM field should pre-fill from the previous track's BPM (since jungle/DnB white labels cluster tightly around 160–180) rather than starting empty; artist field can default to the previous vinyl's label/artist if OCR partially matched.
- **Progressive, single-field-at-a-time entry beats a full form.** For a record with zero resolved fields, presenting artist → title → BPM → key as one field at a time (each auto-advancing) is faster to complete under time pressure than a multi-field form requiring visual scanning.
- **Inline correction, not modal error states.** Don't block on a bad/ambiguous OCR read — flag the cell, let the user keep moving, return to fix later (matches the existing "queue 0.5–0.75 similarity for confirmation" design already in MVP-SPEC §6).
- **The raw OCR text should always remain visible/editable as a starting point**, not discarded once a structured guess is made — cheaper to correct 2 wrong characters in a name Vision already read than to retype the whole thing.

None of this requires new libraries — it's a SwiftUI form-flow design decision, LOW complexity, but worth calling out explicitly as a phase-worthy piece of work rather than an afterthought sheet, since PROJECT.md already flags manual entry as "a first-class path" and a meaningful fraction of scans will land here (white labels/dubplates).

---

## Q7 — Rekordbox Export: MVP or Later Milestone?

**Assessment: valuable, but correctly a post-MVP addition, not core MVP.**

Reasoning:
- **Competitive signal that it matters:** VinylBPM ships CSV export to Rekordbox/Serato as a headline feature — export is clearly seen as necessary to close the loop from "digitized crate" to "actually playable," which validates that the owner will eventually want this too.
- **The owner already has the hard part solved elsewhere:** per project memory, a working `rekordbox-load` skill exists (`pyrekordbox`, loads `.m3u8` sets directly into a live Rekordbox 6 `master.db`, handles playlist folders, is idempotent, backs up first). That means the actual Rekordbox-write mechanism is **already built and live-tested** on a separate machine (PC) — this app would only need to emit a compatible **ordered track list** (m3u8, or a CSV/XML the existing skill or Rekordbox's native XML import can consume), not reimplement Rekordbox interop from scratch.
- **Why not MVP anyway:** the app's Core Value is explicitly "the sequenced set," and PROJECT.md's Definition of Done stops at "get a sequenced set... on the phone." Rekordbox lives on a different machine than the iPhone in the owner's existing setup; wiring export requires deciding on a hand-off mechanism (AirDrop a file, iCloud Drive, etc.) that's a genuinely separate piece of scope from proving the sequencer itself works. Building export before the sequencer is validated risks polishing the wrong end first.
- **Recommendation:** Treat "export sequence as m3u8/CSV, hand off to the existing `rekordbox-load` skill" as the **first post-MVP milestone**, not a v1 requirement. It's low-complexity once the MVP's `Track`/sequence model is stable (it's a straight serialization of already-modeled data), and reuses infrastructure that already exists and is proven — so it shouldn't be deferred indefinitely, just sequenced after the harder, novel constrained-sequencer work ships and is validated against real crates.

---

## Feature Dependencies

```
Label OCR capture
    └──requires──> On-device Vision framework text recognition (Phase 1, already speced)

Multi-track segmentation
    └──requires──> Label OCR capture (needs raw text + bounding boxes first)

Metadata resolution (tier-0 library.db → MusicBrainz → Discogs → GetSongBPM)
    └──requires──> Multi-track segmentation (needs discrete candidate tracks to resolve)

Fast manual-entry sheet
    └──enhances──> Metadata resolution (catches the failure tail; not a separate feature, a required completion path)

One-track-per-vinyl constrained sequencer
    └──requires──> Metadata resolution (needs BPM + Camelot per candidate track to build the DAG)
    └──requires──> Manual-entry sheet (unresolved BPM tracks must be either manually filled or dropped to `unresolved` before sequencing can include them)

Re-optimization on add
    └──requires──> One-track-per-vinyl constrained sequencer (re-running the same solve, not a distinct algorithm)

Confidence/provenance badges (auto/low-confidence/manual)
    └──enhances──> Metadata resolution (surfaces existing matchConfidence field, no new resolution logic)

Rekordbox export
    └──requires──> One-track-per-vinyl constrained sequencer (needs a finalized, ordered sequence to serialize)
    └──enhances──> existing `rekordbox-load` skill (reuses proven pyrekordbox write path on the PC side)

Strict-monotonic-BPM relaxation (future)
    └──conflicts──> current DAG/beam-search tractability approach (MVP-SPEC §5 depends on total BPM ordering for the DAG construction; relaxing monotonicity requires revisiting the search algorithm, not just the constraint)
```

### Dependency Notes

- **Manual entry enhances metadata resolution, rather than being a separate feature:** every source in this research (VinylBPM's own field-provenance model, and PROJECT.md's own framing) treats "resolved automatically" and "resolved by hand" as two branches of the same pipeline, not two features. Build them together, not manual-entry-as-an-afterthought.
- **Rekordbox export requires the sequencer to be stable first:** exporting a half-finished, unvalidated sequence to a proven downstream tool (`rekordbox-load`) is premature — get the ordering logic right against real crates before serializing it out.
- **BPM-monotonicity relaxation conflicts with the current sequencing algorithm's core assumption:** this is the one place in the roadmap where a future feature isn't just additive — it would require re-deriving the DAG/beam-search approach (or accepting a segmented/multi-monotonic-run model), so it should be scoped as its own phase if ever pursued, not a quick toggle.

---

## MVP Definition

### Launch With (v1) — matches PROJECT.md/MVP-SPEC almost exactly; validated by this research, not changed by it

- [ ] Continuous label capture loop — table stakes, confirmed against every scanning competitor
- [ ] On-device OCR + deterministic geometric segmentation — the commodity half of the product; VinylBPM proves the market validates doing this via camera+OCR
- [ ] Tiered metadata resolution (bundled library.db → MusicBrainz → Discogs → GetSongBPM) with confidence tagging — confidence tagging specifically borrowed from VinylBPM's independently-converged pattern
- [ ] Fast manual-entry path, designed as first-class UX (select-over-type Camelot grid, pre-filled BPM defaults, inline correction) — the one place this research adds concrete UX detail beyond MVP-SPEC
- [ ] One-track-per-vinyl BPM-gated, Camelot-optimized sequencer with full re-optimization on add — **this is the actual differentiator**; nothing else in the landscape does it
- [ ] On-device persistence — table stakes

### Add After Validation (v1.x)

- [ ] Rekordbox export (m3u8/CSV/XML) — add once the sequencer has been validated against real scanned crates and produces sets the owner actually plays; reuses the existing `rekordbox-load` skill infrastructure
- [ ] Deliberate BPM-drop / segmented-monotonic sequencing mode — add only if the strict non-decreasing constraint is reported as actually wrong on a real set, not preemptively

### Future Consideration (v2+)

- [ ] General BPM/key filter rule-builder (Rekordbox-Intelligent-Playlist-style) — defer indefinitely; single-genre, single-user app doesn't need it
- [ ] Any collection/valuation features (grading, pricing) — different product, different user need; defer indefinitely unless the goal changes from "build a set" to "manage a collection"

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Continuous capture loop | HIGH | LOW | P1 |
| OCR + segmentation | HIGH | MED-HIGH | P1 |
| Tiered metadata resolution | HIGH | MED | P1 |
| Confidence/provenance badges | MED | LOW | P1 (cheap add-on to resolution) |
| Fast manual-entry sheet | HIGH | MED | P1 |
| One-track-per-vinyl sequencer | HIGH | HIGH | P1 — this is the product |
| Re-optimization on add | HIGH | LOW (same algorithm, re-run) | P1 |
| On-device persistence | HIGH | LOW | P1 |
| Rekordbox export | MED | LOW (once sequence model stable) | P2 |
| BPM-drop / segmented energy curve | LOW-MED (unproven need) | HIGH (algorithm change) | P3 |
| General rule-builder | LOW | HIGH | P3 (anti-feature, don't build) |
| Collection/valuation features | LOW (off-Core-Value) | HIGH | P3 (anti-feature, don't build) |

---

## Competitor Feature Analysis

| Feature | VinylBPM | CrateLog | SetFlow / Mixgraph | Rekordbox / Serato | This App |
|---------|----------|----------|---------------------|----------------------|----------|
| Label photo → OCR identification | Yes | Yes (label, not OCR text — machine vision match) | No (assumes digital library) | No | Yes |
| BPM/key auto-resolution | Yes (DB + audio-mic fallback) | No | Yes (from imported library) | Yes (own audio analysis) | Yes (DB-tiered, no audio) |
| Full ordered set sequencing (not just pairwise suggestion) | **No** — pairwise suggestions only | No | Yes, but digital-library-only | Manual, or basic smart-playlist filter | **Yes** |
| One-track-per-physical-unit constraint | Not addressed | N/A | Not applicable (digital) | Not applicable (digital) | **Yes — unique** |
| Re-optimize whole sequence on new input | No | N/A | No (one-shot generation) | N/A | **Yes — unique** |
| Manual entry as first-class fast path | No (positions manual entry as a fallback to avoid) | No | N/A | Basic manual tag editing | **Yes — designed for it** |
| Field-level confidence/provenance | Yes | No | No | No | Yes (adopted from VinylBPM) |
| Export to Rekordbox | Yes (CSV) | No | Yes (some) | N/A (native) | Planned, v1.x |
| Audio playback | No | No | No (planning tools) | Yes | No — explicitly excluded |
| Collection valuation/grading | Yes | Yes | No | No | No — explicitly excluded |

---

## Sources

- [VinylBPM — vinylbpm.com](https://vinylbpm.com/) — closest direct competitor; label OCR, tiered resolution, Camelot suggestions, Rekordbox/Serato CSV export
- [VinylBPM App Store listing](https://apps.apple.com/us/app/vinylbpm/id6761032214) — pricing, feature list, review evidence (1.0★, 1 rating, upload-error report, July 2026)
- [CrateLog — cratelog.app](https://cratelog.app/) — label machine-vision ID without barcode; pure cataloging, no DJ features
- [Discogs Forum — barcode scanner threads](https://www.discogs.com/forum/thread/227437) and [iOS barcode scanner thread](https://www.discogs.com/forum/thread/738647) — confirms Discogs app scope is barcode-only, no label OCR
- [Mixed In Key — Harmonic Mixing Guide](https://mixedinkey.com/harmonic-mixing-guide/) and [How to use the Camelot wheel](https://mixedinkey.com/workflows/how-to-use-the-camelot-wheel/)
- [DJ.Studio — The DJ's Guide to the Camelot Wheel](https://dj.studio/blog/camelot-wheel)
- [SetFlow — Best DJ Set Builder comparison](https://www.setflow.app/blog/best-dj-set-builder) and [Harmonic Mixing guide](https://www.setflow.app/blog/harmonic-mixing-camelot-wheel) — pairwise transition scoring weights (Camelot 35%, BPM 25%, energy 15%, genre 15%)
- [Mixgraph — AI DJ Set Builder](https://www.mixgraph.io/build) and [Energy Flow Guide](https://www.mixgraph.io/learn/energy-flow-guide) — wave energy pattern, non-monotonic curve evidence
- [ZIPDJ — How to Structure a DJ Set](https://www.zipdj.com/blog/how-to-structure-a-dj-set) — classic warm-up/build/peak/release/cool-down arc
- [SetFlow — How to Build Energy in a DJ Set](https://www.setflow.app/blog/dj-set-energy-flow) — BPM creep (1–2 BPM/transition), abandon-the-plan flexibility
- [Crate Hackers](https://www.cratehackers.com/) and [Crate Hackers support docs](https://help.cratehackers.com/support/solutions/articles/69000862877-building-crates-with-crate-hackers) — digital-library BPM/key/energy organization, Serato/VirtualDJ/Rekordbox integration
- [Rekordbox Intelligent Playlists tutorial — DeeJay Plaza](https://www.deejayplaza.com/en/articles/rekordbox-intelligent-playlist) and [Vibes — Smart Playlist Creation](https://vibesdj.io/learn/techniques/smart-playlist-creation) — rule-builder criteria list, confirms table-stakes filter model
- [We Are Crossfader — Serato DJ 4.0 Smart Crates](https://wearecrossfader.co.uk/blog/serato-dj-4-0/) — Smart Crate criteria and auto-analysis baseline
- General mobile data-entry UX pattern sources: [Designmodo — Hot User Input Patterns for Mobile](https://designmodo.com/user-input-patterns-mobile/), [Think360 — Input Data Fields](https://think360studio.com/blog/how-to-design-input-data-fields-to-improve-mobile-app-ux/) — select-over-type, smart defaults, inline-edit-without-blocking patterns

---
*Feature research for: Vinyl crate-digging / DJ set-building tool*
*Researched: 2026-08-29*
