# Pitfalls Research

**Domain:** On-device iOS vinyl-label OCR + constrained DJ-set sequencing
**Researched:** 2026-08-29
**Confidence:** MEDIUM-HIGH overall. HIGH on SwiftData, beam search, tempo octave error, AVCaptureSession, key-leakage mechanics (well-documented). MEDIUM on Vision's exact behavior on curved vinyl-label text specifically — no one has published a rigorous Vision-vs-circular-label benchmark, so this section combines documented Vision behavior with well-established OCR-on-curved-surfaces failure patterns (coins, bottle caps, badges) and flags itself as the one area needing an early spike, not a literature answer.

## Riskiest Spec Assumptions, Ranked

This is the blunt version the roadmap needs. Ordered by "how likely is this actually wrong, and how much does the rest of the app depend on it."

1. **Curved-baseline OCR works well enough with stock `VNRecognizeTextRequest`.** Highest risk in the whole project. If this fails, segmentation (§2), resolution (§3), and sequencing (§4) never get real input. See Pitfall 1.
2. **Radial-distance-from-center is the right primary clustering signal.** Likely wrong for the specific collection this app targets (jungle/DnB white labels, plain paper, horizontal type). The spec's own Context section says the collection is "heavy on white labels and dubplates" — that's a direct contradiction of the concentric-text premise being load-bearing. See Pitfall 2.
3. **"Fold anything under 100 BPM to double it" is a safe unconditional rule.** It is not unconditional-safe even within jungle/DnB/garage; it actively breaks on garage (130-140 halved to ~70) and on any real half-time/downtempo intro track. See Pitfall 6.
4. **Beam width 50 with no divergence check is "good enough."** Cheap to get wrong silently — beam search can drop the actual longest chain and no one will notice because the output still looks like a plausible ordered set. See Pitfall 5.
5. **Bundling live API keys in a public repo build is an acceptable, contained risk.** The spec already accepts this, correctly, for a personal non-distributed app — but the mitigation ("throwaway Discogs account") is a decision, not yet a fact on disk, and the git-history leak vector is not mentioned at all. See Pitfall 9.
6. **SwiftData will hold `sequence: [TrackID]`, `candidates: [Track]`, `photos: [ImageRef]` correctly ordered.** SwiftData does not reliably preserve array/relationship order across save/reload. This will bite quietly, well after Phase 5 looks "done." See Pitfall 7.
7. **Continuous rapid-fire still capture is fine on device.** True at MVP crate sizes (< 100 vinyls) but the failure mode (thermal throttling, capture stalls) shows up exactly when the user is deepest into a session — mid-crate, not at the start. See Pitfall 8.
8. **Normalized-Levenshtein at 0.75 is a good matching threshold for stylized/remix/white-label titles.** Reasonable starting point, but the specific failure modes (catalog numbers scraped as titles, VIP/dub suffixes, "feat." variants) need dedicated pre-normalization, not just a similarity threshold. See Pitfall 4.
9. **Reflective vinyl, glare, motion blur are "camera problems" solved by a framing guide.** Real, but this is the most controllable risk on the list — user is the photographer, on their own gear, motivated to get a clean shot. Lowest priority to over-engineer against.
10. **Running Vision concurrently on many images is safe by default.** Lowest risk on this list — well-documented patterns exist (serialize or cap concurrency, autoreleasepool) and the crate scale here is tiny compared to what Vision is used for elsewhere (live video frame analysis).

---

## Critical Pitfalls

### Pitfall 1: Vision cannot follow a curved baseline — only a rotated straight one

**What goes wrong:**
`VNRecognizeTextRequest` returns `VNRecognizedTextObservation`s as quadrilaterals with four corner points, i.e. it models each detected text line as a straight (or uniformly rotated/skewed) baseline. It has strong support for a whole line of text rotated at an arbitrary angle in the frame — a business card shot crooked, a street sign at 40°, or a label photographed slightly askew all recognize well, and Apple explicitly supports passing image orientation and lets `.accurate` handle skew. That is a different problem from a *single line of text whose own baseline curves*, which is what concentric label text actually is: each letter's local baseline angle changes continuously across the word. Vision has no curved-baseline text model. Evidence for the mechanism (not vinyl-specific, but the same underlying limitation): rotated-but-straight text is handled with the `.accurate` path, while text-recognition quality is documented to degrade sharply "at impossible angles" and bounding-box/font-size error is reported to grow with rotation angle even for rigid whole-line rotation — the failure mode gets worse, not better, once you add per-character curvature on top of rotation. This same curved-text failure is well established for other domains (bottle caps, coin rims, circular product labels), where the standard fix is *never* "just run OCR" — it's polar-to-Cartesian unwarping before OCR.
**Concretely on a vinyl label:** text that arcs across even 60-90° of the label's circumference (typical for a curved title line near the rim) will very likely come back as garbage, partial, or simply undetected, especially past `.accurate`'s tolerance once curvature compounds with the label's own rotation in the photo. Straight radial or near-radial short strings (catalog number, "SIDE A") sitting close to the center where curvature-per-character is small will read fine. The failure scales with (a) distance from the label center — outer rim text curves more per unit length than inner text — and (b) string length — a 3-character catalog code barely curves; a 25-character arced title curves a lot.

**Why it happens:**
Vision's text detector was built and tuned against real-world "flat plane with rotation/perspective" text (documents, signs, screenshots), not text wrapped on a physical cylinder/disc. There is no public API surface (`recognitionLevel`, `customWords`, orientation) that changes this — it is a structural limitation of the underlying line-detection model, not a tunable parameter.

**How to avoid:**
- Treat this as a **spike, not an assumption**, before writing any segmentation code. Take 10-15 of the user's actual label photos (mix of major-label concentric pressings AND plain-paper white labels — both exist in the collection per PROJECT.md), run raw `VNRecognizeTextRequest` `.accurate`, and manually score: how much text comes back readable, unreadable, or missing entirely, bucketed by "text was straight/horizontal" vs. "text was on a visible arc."
- For labels where a meaningful share of text is arced, add a preprocessing step *before* Vision: detect the label as a circle (Hough-circle or simple bounding-circle-of-content-area), then unwrap the annulus into a rectangular strip via a polar transform (`atan2`/radius remap, doable with vImage or a simple pixel-remap in Core Image / Accelerate). This straightens curved baselines into ordinary horizontal lines that Vision handles natively. This is the standard, proven technique for OCR-on-circular-surfaces — not a novel idea, and not free (needs a reliable center + radius first, see Pitfall 2).
- Multi-angle whole-image rotation passes (rotate 15°, run Vision, repeat, keep highest-confidence per region) help with a *rotated-but-straight* label (the whole photo was crooked) but do **not** fix curvature within a single arced word — don't rely on this as the fix for curved text specifically, only for photo-angle skew.
- Cheapest fallback that should exist regardless of OCR quality: the spec already has one — the manual split/merge/type-correction sheet. Make sure that sheet is usable even when Vision returns *zero* usable observations for a label, not just wrong ones.

**Warning signs:**
Phase 1's own ship criterion ("raw text dumps onscreen for 10 real labels") is the warning sign generator — if a meaningful fraction of those 10 real labels show garbled/missing text specifically on curved regions of major-label pressings, that's the signal to stop and build the polar-unwrap step before Phase 2 segmentation logic is written on top of unreliable input.

**Phase to address:** Phase 1 (Camera + Vision OCR) — before Phase 2 is designed, not concurrently with it.

---

### Pitfall 2: Radial-distance clustering assumes a layout that much of this collection doesn't have

**What goes wrong:**
The spec's segmentation approach (§4.3 of MVP-SPEC) clusters text observations by radial distance from label center on the theory that "vinyl text runs concentrically." Several things go wrong with this as a *primary* signal:

1. **Finding the center reliably is itself unsolved in the spec.** Three plausible approaches, each fragile in a different way: (a) assume the label is centered in the photo frame — fails the moment the user's framing guide isn't perfectly aligned, which will be often, hand-held, mid-session; (b) detect the label as a circle via edge/Hough-circle detection — fails when the spindle hole or label edge is occluded by a finger, the tonearm, glare, or when the outer black vinyl edge isn't in frame; (c) use the centroid of all text bounding boxes as a proxy — fails whenever text is asymmetric on the label (very common: catalog number bottom-left, artist top-right, tracklist off-center), which biases the "center" toward wherever the text happens to sit, corrupting the very radii you're trying to cluster by.
2. **For text that IS genuinely centered and horizontal** (a common major-label layout: tracklist as ordinary stacked horizontal lines in the middle band of the label), radial distance from a correctly-found center reduces almost exactly to `|y - center_y|` when the horizontal offset is near zero — i.e. it degenerates into Y-clustering anyway, buying nothing over the simpler approach while adding a fragile center-finding dependency.
3. **For text that is horizontal but NOT centered** — offset toward one side, which is common on smaller/cheaper white-label pressings — radial distance actively *breaks* the clustering: a single horizontal line will have varying distance-from-center across its own length if it isn't left-right symmetric around the center, causing one physical line to fragment into multiple false radial clusters.
4. **The plain-paper case the spec's own Context section flags is the majority case, not the edge case.** PROJECT.md states the collection is "heavy on white labels and dubplates," and MVP-SPEC's own fallback section calls this "expect to use this [manual correction]... given your white-label and dubplate situation." Plain paper labels typically have typed or stamped text in ordinary left-aligned horizontal lines — not concentric at all. A segmentation strategy whose stated rationale is concentricity is, by the project's own admission, mismatched to most of the actual test set.
5. **No radius-bucket width is specified**, and there isn't a universal one: label diameter, font size, and photo zoom/resolution all vary per shot, so a fixed radial tolerance will over-merge on some labels and over-split on others without per-photo calibration.

**Why it happens:**
The concentric-text intuition is correct for *some* labels — mostly older major-label 45s/LPs with genuinely curved rim typography — and it's a reasonable-sounding generalization from that mental image. It doesn't hold up against the specific, stated composition of this user's actual crate.

**How to avoid:**
- Don't commit to one global clustering strategy. Classify layout first, cheaply: for each observation, Vision gives a bounding quad — compute the angle of its baseline relative to horizontal. If most observations on a label are near-0°/near-180° (horizontal), treat it as a **horizontal-line label** and cluster by Y-coordinate (the simpler, already-well-understood approach) rather than radial distance. Only fall back to radial/angular clustering when a meaningful share of observations show a consistent non-horizontal baseline angle indicating genuine arc-following text.
- If pursuing radial clustering at all, derive the center from the union of ALL detected bounding boxes' convex hull / minimum enclosing circle rather than from text centroid (less biased by asymmetric text placement) — but validate this against real photos before trusting it, per Pitfall 1's spike.
- Budget for the fact that segmentation ship criterion ("correct track count on 8/10 test labels" in Phase 2) will likely show a split result: high accuracy on horizontal-line white labels (simple case), lower on concentric major-label pressings (harder case) — don't let one type of label's success mask the other's failure in the 8/10 number. Break the metric down by label type when measuring.

**Warning signs:**
If Phase 2's 8/10 test set happens to be drawn mostly from one label type, the ship criterion can pass while silently failing on the other type. Explicitly stratify the fixture set (some concentric major-label pressings, some plain-paper white labels) before declaring Phase 2 done.

**Phase to address:** Phase 2 (Multi-track segmentation). Should not be designed until Phase 1's OCR spike (Pitfall 1) shows what kind of observations actually come back for each label type.

---

### Pitfall 3: Glare, reflection, spindle hole, and motion blur degrade an already-fragile signal

**What goes wrong:**
Vinyl labels are frequently semi-glossy or reflective (especially post-vinyl-cleaning or under any point light source), which produces localized bright blowouts that erase text under the highlight — Vision will simply not detect text where pixels are blown out, and there's no OCR-level fix for information that isn't in the image. Motion blur from hand-held rapid-fire capture (the spec's core UX: "shutter returns immediately to camera," continuous scanning) softens character edges enough to drop `.accurate` confidence below the 0.3 threshold the spec plans to filter on, silently discarding real text as noise. The spindle hole and any center-label artwork/graphics (logos, color blocks) can produce spurious "text-like" detections or fragment genuinely concentric text runs by creating a hard visual break exactly where the OCR needs continuity.

**Why it happens:**
This is inherent to point-and-shoot phone photography of a physical, non-flat-lit, non-matte object under whatever ambient light the user has, done fast and hand-held by design (the spec explicitly wants no waiting on any screen between shots).

**How to avoid:**
- Cheapest mitigation: a live framing/quality guide during capture (the spec already plans a "label-framing guide overlay" in Phase 1) — extend it to flag obvious problems before the shot is taken: use `AVCaptureDevice`'s exposure/brightness metadata or a quick luminance-variance check on the live preview to warn on likely blown highlights, and rely on `AVCapturePhotoOutput`'s built-in stabilization/flash-if-needed rather than building custom blur detection.
- Don't over-engineer a bespoke glare-detection model — this is a personal app, the user controls their own lighting and can just retake a shot. The manual-correction sheet (already planned as first-class, not an error path) is the real safety net here, not a smarter capture pipeline.
- Do budget UI for "retake this side" as a near-zero-friction action in the capture loop, since a fast retake is cheaper than any image-processing fix for a blown-out region.

**Warning signs:**
If Phase 1's raw-text-dump ship criterion shows OCR gaps clustering specifically around the center of labels (spindle hole/artwork zone) or around specular highlights in the sample photos, that confirms this is a real, recurring issue worth a capture-time warning rather than a one-off.

**Phase to address:** Phase 1 (Camera + Vision OCR) for capture-time mitigation; the manual-correction UI (already planned) is the durable fix and should be treated as load-bearing, not cosmetic.

---

### Pitfall 4: String matching to a music database fails in genre-specific, predictable ways

**What goes wrong:**
Generic normalized-Levenshtein-with-a-threshold matching (the spec's plan: `>0.75` auto-accept, `0.5-0.75` confirm, `<0.5` reject) will produce specific, recurring failure classes on this exact genre:
- **Catalog numbers read as titles.** Jungle/DnB white labels frequently have the catalog code (e.g. `RUFF001`, `PHA004`) as the most prominent, cleanly-printed text on the label — more OCR-friendly than the handwritten or stylized track titles — and it can out-score the real title on confidence, especially post-segmentation if the regex-based catalog-number filter (spec §4, step 2) misses a format it wasn't seeded for.
- **Remix/VIP/dub suffixes splitting or merging incorrectly.** `(VIP Mix)`, `(Original Mix)`, `(Dubplate)` either need to be part of the match key (Discogs/MusicBrainz often store them as part of the canonical title) or stripped for fuzzy comparison depending on whether the *database entry itself* includes the suffix — inconsistent per-source, so a fixed strip-always or keep-always rule will mismatch roughly half the time.
- **Featured-artist and multi-artist billing variants.** `Artist feat. Other`, `Artist & Other`, `Artist X Other`, or the featured artist omitted entirely on the label but present in the database record (or vice versa) — straight Levenshtein on `artist + title` concatenation penalizes all of these as edit distance even when the actual track is right.
- **Stylized/mangled names.** All-caps, deliberately misspelled or symbol-substituted artist/label names (common self-branding in this scene) reduce string similarity below threshold even for an exact semantic match.
- **Short strings inflate false-positive risk.** Levenshtein-based similarity is known to produce more false positives on short strings (a few words), which is exactly the profile of most track titles — a two- or three-word title has much less room for the algorithm to distinguish "close" from "actually different."

**Why it happens:**
Levenshtein/threshold matching treats all edits as equally meaningful, but music-metadata edits are structured (suffixes, connectors, billing order) — a naive threshold can't tell "typo" from "semantically different but textually close" apart.

**How to avoid:**
- Normalize *before* comparing, not just lowercase/strip-punctuation: extract and separately handle parenthetical suffixes (remix/VIP/dub/edit tags), split multi-artist strings on common connectors (`feat.`, `ft.`, `&`, `x`, `vs`) and compare artist sets rather than raw concatenated strings, and run the catalog-number regex filter against the *segmented output*, not just against raw OCR text, since a segmentation miss can leave a catalog number looking like a bare title line.
- Score title-similarity and artist-similarity separately rather than one concatenated string — this alone fixes most of the featured-artist and billing-order failures, since a wrong-order-but-right-people artist match won't tank the title match too.
- Keep the queue-for-confirmation band (0.5-0.75) generous rather than narrow, given the genre's naming volatility — false "auto-resolved but wrong" is worse than an extra confirmation tap, especially since manual entry is already a first-class, fast path per the spec.
- Don't build genre-aware NLP for this — it's overkill for a personal tool. The above normalization is string-manipulation, not modeling, and fits the project's stated "deterministic, debuggable" preference.

**Warning signs:**
Phase 3's 70% auto-resolve ship criterion is the natural detector — if auto-resolves are landing on the wrong release (right label/BPM range but wrong catalog entry) rather than simply failing to match, that's the catalog-number/suffix confusion showing up, not a threshold-tuning problem, and needs the normalization fix rather than a threshold nudge.

**Phase to address:** Phase 3 (Metadata resolution).

---

### Pitfall 5: Beam width 50 on a constrained longest-path can silently return a materially worse set

**What goes wrong:**
Beam search is fundamentally incomplete: at each step it keeps only the top-W partial paths by current score and discards the rest, so a partial path that looks mediocre early (high cumulative Camelot distance so far, or simply ranked 51st by whatever ordering heuristic is used) but that would have unlocked a much better long-term continuation (more vinyls admitted, lower total weight) gets pruned and can never be recovered later, even though it was the actual optimum. This is a known, well-documented property of beam search, not an implementation bug — increasing beam width can even non-monotonically return a *worse* result in some formulations because of how ties and re-expansion interact, and a fixed width like 50 has no guarantee relative to the graph size. At the spec's own stated scale (<100 vinyls, <400 candidates) the DAG can have wide fan-out at each BPM-sorted step, so 50 survivors per step is not obviously enough to guarantee the true longest admissible chain survives — it's a plausible-sounding number, not a proven-sufficient one for this specific graph structure.

**Why it happens:**
Beam search trades completeness for speed by assuming locally-good partial solutions are more likely to lead to globally-good ones — a heuristic that holds often but not always, especially in graphs with many equally-plausible early branches and a hard structural constraint (one track per vinyl) that makes "sacrifice a slightly worse early pick to keep a rare vinyl's only viable option alive" a real, common scenario.

**How to avoid:**
- The cheapest guard, and the right one at this scale: run the actual DP the spec itself floats as the alternative ("a DP over BPM-sorted order with a visited-vinyl set") since at <100 vinyls / <400 candidates it is *not* exponential in practice — the state space is bounded by (last-track, bitmask-of-visited-vinyls) only in the worst theoretical case, but a simpler bounded-lookback / dominance-pruned DP (drop any partial state that is dominated by another state with the same or better vinyl-count-so-far and better-or-equal running weight, at the same BPM-sorted position) is exact and fast at this scale. Beam search is being reached for as the "obviously simpler" option but isn't actually cheaper to reason about correctness-wise than a small, exact DP with dominance pruning.
- If beam search is kept anyway (matches spec's explicit choice), add the cheapest correctness guard: run beam search twice with two different widths (e.g. 50 and 150) and compare vinyl-count-admitted; if they disagree, that's a direct, cheap signal the beam is too narrow for this crate size, and it costs one extra run, not a rewrite.
- Track a simple regression fixture: once a "good" sequence is produced for a known crate, snapshot it; changes to beam width or graph-construction logic that silently reduce admitted-vinyl-count on that fixture are the detectable signal, not a subjective "does this feel right" review.

**Warning signs:**
Excluded vinyls with a plausible-looking BPM-adjacent neighbor that *should* bridge them into the set but doesn't, especially ones that were previously admitted and then get excluded after an unrelated addition — that's the signature of beam-search path loss, not a real BPM-gate failure, and is worth distinguishing explicitly in debug tooling (log why a vinyl was excluded: "no BPM match" vs "had a candidate edge but wasn't kept in the surviving beam").

**Phase to address:** Phase 4 (Sequencer). Cheap to fix before it ships since the graph is small; expensive to diagnose after the fact because a suboptimal-but-plausible set doesn't look broken.

---

### Pitfall 6: The unconditional "fold everything under 100 BPM to double it" rule breaks on exactly the records this app needs to get right

**What goes wrong:**
Tempo/BPM detection (and by extension, a naive re-normalization rule applied to a possibly-misread BPM value) is famously subject to the "octave error" — a tempo estimate that's a whole-number multiple or fraction of the true tempo, because a stable pulse at, say, 80 BPM looks structurally identical to one at 40 or 160 BPM without additional cues (subdivision density, genre priors). The spec's proposed fix — "fold anything below 100 into the 160-180 range" — is a *blunt, unconditional* octave-correction that:
- **Breaks garage specifically**, which the spec's own tier-0 data source (walkman-dj library, same genres) covers alongside jungle/DnB: UK garage sits at ~130-140 BPM. A garage track whose BPM source (GetSongBPM/Discogs/tap-detected) misreads or reports it at ~65-70 (a legitimate half-time read of a 130-140 track) would be folded to 130-140 correctly by a *general* halving/doubling correction — but the spec's literal rule folds anything under 100 straight into 160-180, which would take a 65-70 BPM garage read and double it into the *jungle/DnB* range, landing on a wrong BPM for a real track, not fixing an error.
- **Breaks genuinely slow material** — DnB/jungle crates on white label often include intros, skits, or intentionally slower B-side cuts (downtempo, halftime-style jungle at true ~85-95 BPM is a real subgenre, not a misread) — folding these unconditionally corrupts a correct reading into a wrong one.
- The stated single-target range (160-180) assumes every folded track is DnB/jungle-tempo; it has no branch for "this was actually a 130-140 garage track misread as ~65-70," which is a realistic and common failure given the source data spans exactly those genres.

**Why it happens:**
The rule as stated treats "under 100" as a single bucket needing one fixed correction, when the real ambiguity is multi-modal (a low BPM reading could be a correct slow track, a half-time DnB read needing ×2, or a half-time garage read also needing ×2 but landing in a different target band).

**How to avoid:**
- Cheapest real fix: don't fold to a fixed target range — **fold by doubling** (`bpm < 100 → bpm * 2`, land wherever that lands) rather than "fold into 160-180." This alone fixes the garage-misread-as-70 case (70×2=140, correct) without any genre classification. It's a one-line change from the spec's stated wording ("fold anything below 100 into the 160-180 range") to the safer version already present in PROJECT.md's Key Decisions table ("Fold `bpm < 100` to `bpm * 2` unconditionally") — note PROJECT.md and MVP-SPEC actually disagree with each other here: PROJECT.md already has the safer unconditional-double rule, MVP-SPEC's Open Items section still poses the riskier "fold into 160-180" framing as an open question. Resolve this discrepancy explicitly before Phase 4 rather than let whichever doc gets read last win by default.
- Still doesn't fix genuinely-slow real tracks (the halftime-jungle-at-90 case) — for those, the only honest mitigation at MVP scope is surfacing the doubled BPM as editable/correctable in the same 15-second manual-entry flow already planned, rather than trying to build genre detection to distinguish "real 90" from "should-be-180" automatically. This is a deliberate, acceptable shortcut given the project's own no-audio-analysis constraint — there's no signal available (no waveform, no subdivision density) to disambiguate automatically once the only input is a database-sourced or hand-typed BPM number.
- Whatever rule ships, make the fold visible in the UI (e.g., a subtle "×2 applied" badge) so a wrong fold is a one-tap fix, not a silent corruption discovered only when the sequence sounds wrong on the decks.

**Warning signs:**
Any track landing suspiciously exactly on 2× or 0.5× another track's BPM in the resolved set is worth a debug log line; a cluster of resolved BPMs sitting suspiciously tight around 160-180 relative to the source library's actual BPM distribution (walkman-dj library BPM histogram, which the app already bundles) is a sign the fold is over-firing.

**Phase to address:** Phase 3 (Metadata resolution), where BPM values are first ingested — resolve the PROJECT.md/MVP-SPEC discrepancy before this phase starts, not during it.

---

### Pitfall 7: SwiftData does not reliably preserve the ordering this data model depends on

**What goes wrong:**
The core model (`Crate.sequence: [TrackID]`, `VinylEntry.candidates: [Track]`, `VinylEntry.photos: [ImageRef]`) leans on ordered arrays for information that matters: sequence order IS the DJ set order; candidates need stable indexing for the sequencer's re-run logic. SwiftData is documented to not durably persist array/to-many-relationship ordering — it can reorder elements on reload because ordering isn't stored as a first-class attribute in the underlying SQLite schema, only as opaque relationship keys. Beyond ordering specifically: SwiftData relationships are reported as fragile in several other ways relevant here — inverse relationships not triggering `@Observable`/`@Query` updates reliably, non-optional relationships silently behaving as optional, relationship constraints only enforced at save time (not at the point of mutation, meaning invalid intermediate states can exist in memory without error until save), and migrations involving optional-to-many relationships reported to crash in some configurations. Threading-wise, only `PersistentIdentifier` and `ModelContainer` conform to `Sendable` — passing `Track`/`VinylEntry` model instances themselves across actor/thread boundaries (e.g. background metadata-resolution `TaskGroup` work updating a model that the UI actor also touches) is not safe without funneling through `@ModelActor` or refetching by identifier on each context.

**Why it happens:**
SwiftData is a relatively young ORM layer (introduced iOS 17) built on Core Data's underlying storage model, which itself never had strong ordered-relationship guarantees — SwiftData inherits that gap without yet papering over it at the framework level.

**How to avoid:**
- Never rely on array position as the source of truth for anything that matters (sequence order, track position within a side). Add an explicit `Int` ordering/index field to every model that needs stable order (`Track.position` already exists in the spec's model for exactly this reason — extend the same pattern to `Crate.sequence` by storing order on a join-like field rather than trusting array order, and to `candidates` similarly) and always fetch with an explicit `sort:` descriptor rather than reading array order off a relationship.
- Do all background metadata-resolution work through a `@ModelActor`-backed context, passing `PersistentIdentifier` across the `TaskGroup` boundary rather than model instances, and re-fetch on the actor that will mutate — this sidesteps the Sendable gap entirely rather than fighting it.
- Given the sequencer re-runs the *entire* sequence on every add (spec's own design — "Full re-optimization, not incremental"), consider **not** persisting `Crate.sequence` as an ordered relationship at all: persist only the raw ingredients (vinyls, candidates, resolved metadata) and recompute the sequence in memory on load / on demand. This sidesteps the ordered-relationship problem for the one field where it would be most damaging to get wrong (the actual DJ set order), at the cost of a cheap recompute that the spec already does anyway on every add.
- Treat migrations as a real cost from Phase 5 onward: since this is a fast-moving personal project with a data model likely to change across phases/milestones, favor additive-only schema changes early and test a migration path explicitly before any schema change that touches a relationship, rather than discovering a crash-on-migrate only when a real crate's data is at stake.

**Warning signs:**
Sequence order or candidate order visibly scrambling after an app relaunch (not after a re-optimization, which is expected to change order) is the direct symptom — write this as an explicit manual or automated check as part of Phase 5's "crates survive app restart" ship criterion, not just "did the data exist," but "was the order preserved."

**Phase to address:** Phase 5 (Persistence) for the schema decisions, but the ordering-field design should be locked before Phase 0's model stubs harden into real `@Model` types, since retrofitting explicit ordering after UI code assumes array order is a rewrite, not a patch.

---

### Pitfall 8: Continuous rapid capture degrades exactly during the longest scanning sessions

**What goes wrong:**
The spec's core UX — "shutter returns immediately to camera," no waiting, scan a whole crate in one sitting — stacks three real `AVCaptureSession`/device constraints against each other: (1) rapid successive still-image capture requests are documented to have a queuing limit (historically ~10 outstanding requests) before the session pushes back; (2) holding many full-resolution captured images in memory (even briefly, before they're either processed or persisted/downscaled) risks memory pressure on a sustained scanning session — a 20+ vinyl crate at two photos each (A/B side) is 40+ full-res captures in one sitting; (3) sustained camera + Vision processing generates real heat, and iOS's system-pressure states (`AVCaptureSystemPressureState`) will throttle frame rate and, at the worst level, interrupt the capture session entirely (`.shutdown`) if unaddressed — this is a documented, real device behavior, not a hypothetical.

**Why it happens:**
Continuous camera + on-device ML inference is genuinely one of the more thermally and memory-intensive combinations an iOS app can run, and the spec's explicit design goal (never wait on a screen) maximizes exactly the sustained-throughput pattern that triggers these limits.

**How to avoid:**
- Downscale/compress each capture immediately after Vision has run on it (Vision needs reasonable resolution for `.accurate`, but does not need the full sensor resolution held around afterward) and discard or re-encode the full-res buffer promptly rather than retaining every original at full size for the whole session — most of the segmentation/resolution pipeline only needs the OCR output and a thumbnail, not the source pixels, once processing is done.
- Observe `AVCaptureDevice.systemPressureState` and respond by throttling: if a personal, casual scanning cadence naturally has gaps between "flip to next record" moments, this is likely a non-issue at MVP crate sizes (<100 vinyls) — but wire the observer anyway (cheap) so a real throttle event is visible/logged rather than manifesting as a mysterious capture stall the user can't diagnose.
- Don't build proactive thermal-prediction logic — that's solving a problem that likely won't manifest until crate sizes are much larger than the stated MVP scale. React to the documented pressure-state callback if and when it fires; don't pre-emptively slow the happy path for a device state that may never be hit in a 20-40 photo session.

**Warning signs:**
Capture stalls, dropped shutter presses, or a visible frame-rate drop specifically appearing only in longer scanning sessions (not the first few shots) is the signature — if this shows up in real use, that's the trigger to add the pressure-state observer, not a reason to build it defensively upfront.

**Phase to address:** Phase 1 (Camera + Vision OCR) for the immediate-downscale pattern (cheap, should just be the default from day one); the pressure-state observer can be deferred until real sessions show the symptom, given MVP crate scale.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Skip the polar-unwrap preprocessing, ship raw Vision output | Faster Phase 1 | Segmentation/resolution built on garbage input for concentric labels; discovered late | Only if Phase 1 spike shows curved text is rare in the actual crate — verify, don't assume |
| One global radial-clustering strategy for all labels | Simpler Phase 2 code | Systematically fails on the majority white-label case per the project's own stated collection composition | Never as the *only* strategy — branch by detected layout type instead |
| Beam search width 50, no divergence check | Ships faster, matches spec's stated choice | Silent suboptimal sets that "look fine" but drop a vinyl that should have made the cut | Acceptable if paired with the cheap two-width comparison check; not acceptable silently |
| Fixed BPM fold target range (160-180) instead of unconditional ×2 | Simpler statement of the rule | Actively corrupts garage-range misreads | Never — the ×2-only version costs nothing extra and is already the version in PROJECT.md |
| Trusting SwiftData array order for `sequence`/`candidates` | Less code upfront | Silent reordering after reload, hard to detect except by careful QA | Never for anything user-visible as "order"; fine for unordered bag fields only |
| Bundling live API keys via generated `Secrets.swift` in a public repo | No secret-management infrastructure needed | Any leaked token (even via git history or a build artifact accidentally committed) is fully public forever | Acceptable only for a personal, non-distributed, throwaway-account-scoped build — exactly this project's stated constraints |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| Discogs search API | Matching on raw OCR string including catalog numbers/suffixes | Normalize + strip suffixes/catalog codes before querying; score title and artist similarity separately |
| MusicBrainz fallback | Assuming its BPM/key coverage matches Discogs' release coverage | MusicBrainz has essentially no reliable BPM/key data of its own — it's a metadata (artist/title/release) fallback, not a BPM source; the spec's own pipeline routes BPM/key through GetSongBPM/Discogs release data, which is correct — just don't let a MusicBrainz identity match get treated as also resolving BPM |
| GetSongBPM | Treating a miss as equivalent to "no BPM exists" | A miss just means this specific source doesn't have it — fall through to manual entry per the spec's ladder, don't retry the same source repeatedly |
| Bundled `library.db` (walkman-dj) tier-0 | Matching against it with the same loose threshold as external APIs | This is the project's own curated, DSP-verified data for the exact same collection's genres — a stricter match threshold here is safe and should be preferred over a looser external-API match when both are plausible, since it's free and zero-latency |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Running Vision `.accurate` synchronously on the main/capture thread per shot | UI stalls between shots, breaks the "never wait" UX goal | Run `VNImageRequestHandler.perform` on a background queue per capture; Apple's own guidance is explicit that this can take seconds and must not block the main thread | Immediately, even at small crate sizes — this is a correctness issue for the UX goal, not a scale issue |
| Firing many `VNImageRequestHandler` instances concurrently without any cap | Elevated peak memory, possible duplicated/inconsistent observations reported when multiple requests hit one handler's `perform()` in a single call | Cap concurrency (a small `TaskGroup` limit, e.g. 2-3 concurrent, similar to the spec's own Discogs concurrency cap) and use `autoreleasepool` around each image's processing when looping over many captures | Not really a "breaks at N" scale issue at this project's size (<100 photos) — the mitigation is cheap enough to just always do it |
| Holding full-resolution `UIImage`/`CVPixelBuffer` for every captured side across a whole session | Memory growth proportional to session length | Downscale/compress immediately after OCR extraction, keep only what's needed for the manual-correction UI (a reasonable thumbnail, not the sensor-native image) | Noticeable by ~30-40+ full-res images in one uninterrupted session — i.e. roughly one full crate |
| Re-running full sequencer optimization on every single vinyl add without any early-out | Sequencer time grows with candidate count | Spec already scopes this fine at <100 vinyls/<400 candidates — no action needed at MVP scale, just don't add per-add incremental complexity prematurely | Not a concern until crate sizes are an order of magnitude beyond MVP scope |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing `Secrets.swift` (even once, even to a since-force-pushed branch) | Git history retains the blob indefinitely unless the whole history is scrubbed and force-pushed everywhere including any forks/clones — a public repo makes this trivially discoverable via any git-history scraper | Put `Secrets.swift` in `.gitignore` from the repo's very first commit, before any key generation ever runs locally; verify with `git log --all --full-history -- '**/Secrets.swift'` before ever pushing |
| Using the main/personal Discogs account token for a bundled key | Anyone who extracts the string from the IPA binary (trivial with `strings`/a decompiler — the spec's own risk note acknowledges this) gets a working token tied to a real account, not just API abuse but potential access to that account's own data/actions | Generate the token from the "throwaway account" the spec already recommends — actually create it, don't just note the intention |
| Assuming a public repo without a live keys folder is "safe enough" | Info.plist, build scripts, or CI config can leak a key just as easily as source if any generation step ever writes it somewhere non-gitignored | Audit every artifact the build produces (Info.plist, entitlements, any generated config) for accidental key inclusion, not just the Swift source tree |
| GetSongBPM backlink requirement forcing the repo to stay public forever | A public repo permanently means the above risks never go away as long as this key model is used | Accepted, explicit tradeoff per the spec — just don't let it quietly become "and therefore we stopped being careful about it" |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Treating a failed/garbled OCR read as a dead end rather than routing straight to manual entry | User has to notice something is wrong before they can fix it | Show the raw OCR text (even if garbled) alongside the segmentation result so the user can eyeball-correct against the label in hand, rather than a blank/failed state |
| Auto-folding BPM silently (Pitfall 6) | A wrong fold surfaces only when the set sounds wrong on the decks, far from the point of entry | Visible fold indicator, one-tap toggle to un-fold |
| Treating "excluded" vinyls as a dead-end section | User doesn't realize adding one more vinyl could readmit an excluded one (which the spec explicitly wants — "re-evaluates exclusions... can rejoin") | Surface the *reason* for exclusion specifically enough that the user understands what addition would fix it (e.g. "needs a track within 4 BPM of X"), not just a generic "excluded" label |

## "Looks Done But Isn't" Checklist

- [ ] **Phase 1 OCR ship criterion ("raw text dumps for 10 real labels"):** Often "done" by showing dumps exist, not by scoring them against label type (concentric vs. plain-paper) — verify the 10 labels include both types and score each separately, per Pitfall 1/2.
- [ ] **Phase 2 segmentation ship criterion ("8/10 correct track count"):** Often "done" without checking whether the 2 failures cluster on one label type — verify failure distribution, not just the aggregate pass rate.
- [ ] **Phase 3 auto-resolve ship criterion ("70%+ auto-resolve"):** Often "done" by counting resolutions without checking whether resolved entries are the *correct* release (right catalog match, not just a confident-looking wrong one) — spot-check a sample of auto-resolves against the physical label, not just the resolve rate.
- [ ] **Phase 4 sequencer ship criterion ("produces a set you'd actually play"):** Often "done" by eyeballing one output — verify against the beam-width divergence check (Pitfall 5) and confirm no plausible-looking excluded vinyl was dropped due to beam pruning rather than a genuine BPM-gate failure.
- [ ] **Phase 5 persistence ship criterion ("crates survive app restart"):** Often "done" by checking data exists after relaunch, not that array/relationship *order* survived — explicitly verify sequence order and candidate order, per Pitfall 7.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Vision fails on curved text (Pitfall 1) | MEDIUM | Add polar-unwrap preprocessing as a targeted fix for arced-text labels only, gated behind the layout classifier from Pitfall 2 — doesn't require redoing Phase 1's straight-text handling |
| Radial clustering wrong for white labels (Pitfall 2) | LOW-MEDIUM | Add the horizontal-vs-arc layout branch; existing Y-clustering logic for the horizontal case is a well-understood, easy addition alongside the radial path rather than a replacement |
| Beam search drops the true best path (Pitfall 5) | LOW | Swap in the dominance-pruned DP the spec itself already floats as the fallback — small, isolated change to one function |
| Bad BPM fold corrupts a track (Pitfall 6) | LOW | One-tap manual override already planned; switching the rule itself (range-fold to unconditional ×2) is a one-line change |
| SwiftData scrambles sequence order (Pitfall 7) | MEDIUM-HIGH if discovered late | Add explicit ordering fields and stop persisting computed sequence order as a relationship — cheap if done before Phase 5 ships, a real migration if discovered after |
| Leaked API key from bundled build (Pitfall 9) | LOW | Rotate/regenerate the throwaway account's token; since it's scoped to a non-primary account, blast radius is contained by design |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| Curved-baseline OCR limits (1) | Phase 1 | Spike against real labels (both concentric and plain-paper) before Phase 2 design locks; score by label type |
| Radial clustering mismatch (2) | Phase 2 | Stratified 8/10 test set across label types; explicit layout-classification branch in segmentation code |
| Glare/motion blur/spindle confusion (3) | Phase 1 | Capture-time quality warning is present; manual-correction path handles zero-OCR-result labels gracefully |
| String matching failure modes (4) | Phase 3 | Sample-audit auto-resolves against physical labels, not just resolve-rate percentage |
| Beam search suboptimality (5) | Phase 4 | Two-width divergence check present; regression fixture snapshot of a known-good sequence |
| BPM fold rule (6) | Phase 3 | PROJECT.md/MVP-SPEC discrepancy resolved to unconditional ×2 before this phase starts; fold visible/reversible in UI |
| SwiftData ordering (7) | Phase 0 (model design) / Phase 5 (persistence) | Explicit ordering fields from the first `@Model` definition; restart test checks order, not just existence |
| Capture session thermal/memory (8) | Phase 1 | Immediate downscale-after-OCR is default; pressure-state observer wired even if untested at MVP scale |
| Public-repo key exposure (9) | Phase 3 (first real key use) | Throwaway account actually created before first commit that generates `Secrets.swift`; `.gitignore` entry predates any key material touching disk |
| Vision concurrency (10) | Phase 1 | Concurrency cap + autoreleasepool present in the capture-to-OCR pipeline from the first implementation, not retrofitted |

## Sources

- [VNRecognizeTextRequest — Apple Developer Documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Recognizing text with the Vision framework — Create with Swift](https://www.createwithswift.com/recognizing-text-with-the-vision-framework/)
- [Detecting text with VNRecognizeTextRequest in iOS 13 — Ben Dodson](https://bendodson.com/weblog/2019/06/11/detecting-text-with-vnrecognizetextrequest-in-ios-13/)
- [Text Recognition in Vision Framework — WWDC19 Session 234](https://developer.apple.com/videos/play/wwdc2019/234/)
- [A Masked Bounding-Box Selection Based ResNet Predictor for Text Rotation Prediction (arXiv 2209.09198)](https://arxiv.org/pdf/2209.09198) — corroborates rotated-text bounding-box/font-size error growing with angle, general OCR behavior class Vision shares
- [SwiftData pitfalls — Wade Tregaskis](https://wadetregaskis.com/swiftdata-pitfalls/) — array/relationship ordering not durably persisted
- [SwiftData migration crashes when working with relationships — Apple Developer Forums](https://developer.apple.com/forums/thread/779790)
- [SwiftData Limitations — Fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — Sendable conformance limited to PersistentIdentifier/ModelContainer, threading guidance
- [An Unauthorized Guide to SwiftData Migrations — Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [Beam search — Muthukrishnan](https://muthu.co/beam-search/) — incompleteness/suboptimality properties, width tradeoffs
- [Rectangle Search: An Anytime Beam Search (arXiv 2312.12554)](https://arxiv.org/pdf/2312.12554)
- [Addressing Tempo Estimation Octave Errors in Electronic Music — TU Wien](https://www.ifs.tuwien.ac.at/~knees/publications/hoerschlaeger_etal_smc_2015.pdf) — octave-error mechanism, half/double/tempo-prior correction strategies
- [Tempo estimation as fully self-supervised binary classification (arXiv 2401.08891)](https://arxiv.org/pdf/2401.08891)
- [Technical Q&A QA1865 — rapid still image capture queue limit — Apple Developer](https://developer.apple.com/library/ios/qa/QA1865/_index.html)
- [Advances in Camera Capture & Photo Segmentation — WWDC19 Session 225](https://developer.apple.com/videos/play/wwdc2019/225/) — system pressure states, thermal throttling behavior
- [How to Extract API Keys from iOS Apps — KVProxy](https://kvproxy.com/blog/how-to-extract-api-keys)
- [How to extract an API key from a mobile app by static binary analysis — DEV Community](https://dev.to/exadra37/how-to-extract-an-api-key-from-a-mobile-app-by-static-binary-analysis-4gm6)
- [What is Fuzzy Matching? — Couchbase](https://www.couchbase.com/blog/fuzzy-matching/) — false-positive risk on short strings
- [Discogs Database Guidelines 12: Tracklisting](https://support.discogs.com/hc/en-us/articles/360005055373-Database-Guidelines-12-Tracklisting) — canonical title/suffix conventions relevant to matching
- Project documents: `/Users/rishizamvar/Documents/Projects/VinylSetBuilder/.planning/PROJECT.md`, `/Users/rishizamvar/Documents/Projects/VinylSetBuilder/docs/MVP-SPEC.md` — source of the two conflicting BPM-fold statements and the white-label/dubplate collection composition

---
*Pitfalls research for: on-device iOS vinyl-label OCR + DJ set sequencing*
*Researched: 2026-08-29*
