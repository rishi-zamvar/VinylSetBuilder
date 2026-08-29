# BPM & Key Acquisition Research

**Researched:** 2026-08-29
**Question:** Given only an artist/title string OCR'd off a vinyl label, how does this app get a BPM and Camelot key, on-device, no server, no hand-rolled DSP, heavy on jungle/DnB/UKG including white labels and dubplates?

## Executive Summary — The Ladder

0. **Bundled `library.db` subset** (already decided) — 7,010 rows, instant, offline, your own genres. Zero cost.
1. **MusicBrainz search → bundled AcousticBrainz-derived SQLite** — free, offline after a one-time ETL, but gated by MusicBrainz coverage (same white-label gap as everything else). Worth building, not a silver bullet.
2. **MusicBrainz search (free, unlimited-ish) + Discogs search (free, 60/min, has release metadata but NO bpm field) → GetSongBPM (needs a public backlink page, doable) → Deezer track lookup (has a `bpm` field, needs `fetchDetails=true`, free, unofficial-but-open)**. Catches anything with a commercial release under its own name.
3. **SoundCloud search + stream (you already have working OAuth) → analyse in-memory with Apple's on-device `MusicUnderstandingSession` (iOS 27+)** — the best route for exactly the stuff Discogs/MusicBrainz miss: promos, rips, DJ uploads of white labels that never got a Discogs entry.
4. **Microphone capture of the physical record → `MusicUnderstandingSession` on the live buffer** — the only route with 100% theoretical coverage, including true one-off dubplates. Slowest, last resort, but genuinely easy to build now that Apple ships the analysis for free.
5. **Manual entry** — floor, not a failure state, per your own spec.

**Biggest correction to your framing:** AcousticBrainz dumps are real and still downloadable, but they are keyed by MusicBrainz Recording ID. If a white label isn't in MusicBrainz, it isn't in AcousticBrainz either — the "AcousticBrainz could be the whole answer" hope doesn't hold. It's a good free tier-1 addition, not a silver bullet.

**Biggest opportunity you didn't ask about:** Apple announced a first-party **Music Understanding** framework at WWDC26 (June 2026) that does on-device tempo AND key extraction from any `AVAsset` or live audio buffer, free, no signal-processing code, Neural-Engine-accelerated. It requires **iOS 27**, which the iPhone 14 Pro fully supports. This is the "skip DSP entirely" answer for routes C and E — it replaces aubio/Essentia outright and should be preferred over both.

---

## Route Evaluations

### A. Datasets

#### A1. AcousticBrainz data dumps
- **Status: WORKS (dumps are live and downloadable)**, but the live query API is DEAD (shut down 2022). Verified directly on [acousticbrainz.org/download](https://acousticbrainz.org/download) — the download page is still served and links to dated dumps (`2022-07-06` is the last de-duplication note on the page).
- **Contents:** low-level JSON dumps and CSV feature dumps include `bpm`, `bpm_histogram_first_peak_bpm_mean/median`, key, scale, tuning frequency — confirmed on the live page. Each file is keyed by MusicBrainz Recording MBID.
- **Size:** low-level dumps ≈ **589 GB compressed**, high-level ≈ **39 GB compressed** (MetaBrainz blog, July 2022 dump announcement). Not bundleable as-is. A pruned `(mbid, bpm, key, scale)` extraction would likely land in the low hundreds of MB — feasible to bundle, but requires a one-time off-device ETL over hundreds of GB of source data.
- **Coverage for jungle/DnB/white labels: LOW, structurally.** Data is keyed by MBID — a recording must already exist in MusicBrainz *and* have had a user run the (now-dead) submitter tool against their own rip of it. Obscure dubplates that are absent from MusicBrainz are absent here by construction, for the exact same reason they're absent from Discogs. This does NOT fix the hard cases; it's a bonus source for anything with a proper release and an MBID.
- **Licence: CC0 (public domain)**, confirmed via MusicBrainz documentation. Zero encumbrance to bundle a derived subset.
- **Effort:** MEDIUM-HIGH. Requires downloading and parsing hundreds of GB once, off-device, to produce a small SQLite. Not a blocker for MVP; a good phase-2/backlog item.
- **Verdict: build later, not now.** Worth doing once the MVP ships, as a free supplemental tier-1, but size/effort and the MBID-gating mean it should not delay anything.

#### A2. MusicBrainz canonical dumps
- **Status: WORKS**, but **no BPM/key of any kind** — MusicBrainz's own metadata (artist, recording, release, MBID) contains no acoustic descriptors. AcousticBrainz existed specifically to add that layer as a separate project. Confirmed via MetaBrainz's dataset pages; no acoustic-attribute fields appear in the canonical dump schema.
- **Use here:** MusicBrainz is the *lookup key* generator (get an MBID from artist+title) that A1 and other MBID-keyed sources need. It is already implicitly in your resolution pipeline (per MVP-SPEC §6, MusicBrainz is already a fallback after Discogs). No incremental cost — you're already calling it.
- **Coverage:** free, unlimited-ish (1 req/sec courtesy limit, no key required, just a User-Agent — matches your existing plan). Coverage of white labels is the same story as Discogs: patchy, often absent.

#### A3. Other open datasets (FMA, MTG-Jamendo, Million Song Dataset)
- **FMA (Free Music Archive): DEAD for this purpose.** Its "Jungle"/"Drum & Bass" genre tags are populated by royalty-free stock-music uploads (e.g., "Energetic Jungle Breakbeat Drum & Bass" by generic production-music accounts), not the actual UK jungle/DnB scene. Zero artist/title overlap with pressed vinyl. Confirmed by browsing freemusicarchive.org's genre pages directly.
- **MTG-Jamendo: DEAD for this purpose.** 55k tracks, genre-tagged (`dnb` exists as a tag), but it's Creative-Commons-licensed Jamendo uploads — bedroom producers, not the commercial/white-label catalogue your vinyls come from. No artist/title match value, and the public dataset ships tags, not raw tempo/key.
- **Million Song Dataset: DEAD.** 2011-era, Echo Nest-derived (Echo Nest is defunct, folded into Spotify), covers "contemporary popular songs" of the 2000s with no jungle/DnB/UKG representation, and Echo Nest's tempo estimates were notoriously prone to octave errors (half/double time) even for the genres it did cover.
- **GiantSteps Key/Tempo datasets:** real EDM audio+annotations, but only ~1,000-ish tracks total, meant as ML training/eval sets, not an artist/title lookup service. Not a resolution route; only relevant if you were training a custom model (see D15 — not recommended).

### B. APIs that return tempo/key directly

#### B4. Spotify Audio Features
- **Status: RESTRICTED, but conditionally WORKS for you.** Spotify deprecated `/audio-features` and `/audio-analysis` for **new** integrations on 27 Nov 2024 (official: [developer.spotify.com/blog/2024-11-27-changes-to-the-web-api](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api)). The exact policy language: *"Applications with existing extended mode Web API access that were relying on these endpoints remain unaffected by this change."* Apps still in Development Mode without a pending extension request as of that date, and all new apps, get 403.
- **What this means for you specifically:** you need to check whether your existing Spotify client credentials were already in **Extended Quota Mode** with audio-features usage *before* 27 Nov 2024. If yes, it likely still works. If your Spotify app was created after that date, or was in Development Mode only, it does not work and there is no appeal path (community threads confirm no waitlist, no reinstatement).
- **Action item, not a research answer:** test the actual credentials against `/v1/audio-features/{id}` before relying on this tier. This is a 2-minute curl check, do it before designing around it.
- **Coverage:** if it works, excellent for anything with an official Spotify release; near-zero for true white labels/dubplates (they're not on Spotify).
- **Licence/cost:** free within Spotify's dev terms.

#### B5. GetSongBPM
- **Status: WORKS**, with a hard backlink requirement. Confirmed on [getsongbpm.com/api](https://getsongbpm.com/api) (indexed via search, page itself blocks scripted fetches): a link back to getsongbpm.com is **mandatory** on your app's public listing/site — "whether your project is under development, for private use, educational or commercial purposes... there is no way of getting around this restriction," and violation causes silent key suspension.
- **On your GitHub Pages blocker:** you don't need GitHub Pages. The requirement is a "publicly visible website or store listing." A public GitHub repository's rendered README **is** a publicly visible webpage on github.com and is the obvious substitute — put the GetSongBPM backlink in the README (which is already public per your constraint that the repo must stay public for exactly this kind of requirement). This is a reasonable reading of the term, not verified with GetSongBPM support directly — flag as MEDIUM confidence, cheap to just try and see if the key gets approved.
- **Data returned: BPM and key only** — no energy/danceability/etc. Good, that's all you need.
- **Coverage:** commercial/officially-catalogued tracks. Same story — misses dubplates.
- **Rate limits/cost:** free tier exists; exact numbers weren't independently re-verified beyond what's already in your plan.

#### B6. TuneBat / SongBPM / Musicstax / Chosic
- **TuneBat: RESTRICTED.** No official public developer API (verified — tunebat.com/API markets a product but there's no documented open REST endpoint). A third-party wrapper (Parse.bot) exists but that's scraping-as-a-service with its own cost/reliability risk, not an authoritative source.
- **Musicstax: RESTRICTED (paid, gated).** API exists but is manually provisioned per customer, described by Musicstax themselves as expensive infrastructure ("costs thousands of dollars a month to run") — not viable for a free personal project.
- **Chosic: RESTRICTED.** No public API; the site explicitly sources its BPM/key from Spotify's (now largely dead) audio analysis under the hood, so it's a proxy for a source you may already have more direct access to via B4.
- **SongBPM:** essentially the same GetSongBPM-family product line; same backlink constraint applies.
- **Verdict on this whole cluster: DO NOT BUILD.** They add scraping fragility and legal grey area for the same or worse coverage than GetSongBPM, which at least has an honest, documented API.

#### B7. Deezer, Tidal, Apple Music/MusicKit, Napster
- **Deezer: WORKS, and underrated.** The Deezer public API exposes a `bpm` field on the Track object. It's not populated in list/album responses by default but appears when you fetch full track details (`fetchDetails=true` equivalent — i.e., call the individual track endpoint, not the album listing). No official key needed for basic public catalogue reads; it's an openly documented public API. Coverage: commercial catalogue only, same white-label gap, but it's a genuinely free extra shot at the same tier as Deezer, cheap to add alongside GetSongBPM.
- **Tidal:** no evidence found of a public tempo/key field in their developer API; not worth pursuing given Deezer already covers this niche for free.
- **Apple Music/MusicKit: DEAD for this purpose.** MusicKit's public API does not expose tempo, key, or any audio-feature data — confirmed via Apple Developer Forums discussion: real-time buffers, FFT data, and beat markers are not exposed through the public API; that level of access is reserved for specially-entitled DJ-software partners (djay, Serato, rekordbox, Engine DJ), not general MusicKit consumers. Do not build against this.
- **Napster/Rhapsody:** no meaningful current developer ecosystem found; not investigated further, low expected value.

#### B8. Discogs
- **Status: CONFIRMED — no dedicated BPM field.** Discogs release/track schema does not include tempo as a first-class field (community forum discussion on discogs.com confirms this has been requested and rejected repeatedly — "BPM will not be given dedicated fields in Discogs"). Some releases carry BPM informally in free-text notes (DJ 12"s occasionally do), but this is unstructured and unreliable to parse programmatically.
- **Discogs' actual value in your pipeline is what your spec already uses it for:** artist/title/format/label resolution and confirming "yes this is a real vinyl release," not BPM/key. Keep it exactly where your spec already has it — metadata resolution, not tempo/key.

### C. Fetch-the-audio-then-analyse

#### C9. Which sources can legitimately be fetched from an iOS app
- **SoundCloud: WORKS, and is your best audio source for this genre.** You already have working OAuth credentials and a verified `/tracks/{id}/download` path (per your own prior work). SoundCloud is disproportionately where jungle/DnB/UKG producers and DJs upload promos, rips, and white-label-adjacent content that never gets a commercial release — genuinely better genre-fit than any of the APIs in section B.
- **Bandcamp: RESTRICTED.** Official developer API exists but is gated to labels/merch partners for sales reporting; it does not expose stream URLs to third-party consumer apps. No legitimate programmatic streaming path.
- **YouTube: RESTRICTED / fragile, factually.** Native Swift extractors (e.g. `YouTubeKit`) exist and do implement signature-cipher decoding, so it is technically achievable in pure Swift. But this decodes YouTube's obfuscated player logic outside any sanctioned API — it breaks whenever YouTube rotates its cipher, and it's a direct ToS violation regardless of App Store distribution status. Given the app is never distributed, App Store rejection risk is moot, but the maintenance fragility (silently breaking on YouTube's next cipher change, with no support channel) is real and ongoing. Treat as a last-resort, not a primary tier.
- **Internet Archive: DEAD for this genre.** Its large streamable-audio collections (the Great 78 Project, ~385k tracks) are pre-1960s 78rpm recordings — jungle/DnB is a 1990s genre, there is no overlap. IA does host scattered user-uploaded 90s rave/jungle rips in some collections, but there's no organized, queryable, artist/title-indexed corpus of them — not a reliable route.
- **Jamendo:** same problem as MTG-Jamendo above — Creative-Commons bedroom-producer catalogue, no overlap with your actual vinyl artists.

#### C10. Streaming-and-analysing-without-persisting vs. downloading
- **Factually, for SoundCloud specifically:** their API Terms of Use (developers.soundcloud.com/docs/api/terms-of-use) explicitly distinguish the two. Apps "must not include file-save functionality, or otherwise be designed to cache, download, or persistently store User Content," but **"apps may employ session-based caching, but only to the extent reasonably necessary for the operation of your app during that session."** In-memory fetch → analyse → discard (no bytes ever written to disk) sits squarely inside that permitted carve-out. Writing the MP3/WAV to disk for reuse would not. This matters for design: fetch into a `Data`/buffer, hand it to the analyser, drop the reference — don't cache the file to `Documents/`.
- This is a real, load-bearing distinction, not a technicality you're inventing — it's SoundCloud's own stated policy.

### D. Analysis libraries that compile for iOS

#### D11. aubio
- **Status: WORKS.** Builds for iOS/arm64 out of the box (`--with-target-platform=ios`), ships prebuilt `.framework` binaries for iOS/macOS, and its own docs include a direct Swift usage example — genuine, low-friction Swift interop.
- **Licence: GPL** (confirmed on aubio.org — explicitly "not MIT or BSD licensed"). For a personal, never-distributed app this is legally moot: GPL's source-disclosure obligations trigger on *distribution to third parties*, which this app will never do. Flag it, don't fear it.
- **Verdict: viable fallback, but see D14/D15 — Apple's own framework now does the same job for free with zero build/licence overhead.** Only worth reaching for if you specifically need this working *before* you're comfortable requiring iOS 27.

#### D12. Essentia
- **Status: WORKS but heavier.** C++ library, explicitly supports iOS as a build target, ships `RhythmExtractor2013` (tempo + BPM candidate distribution) and `KeyExtractor` (full key/scale pipeline) — exactly the two algorithms you'd want.
- **Licence: AGPLv3.** Same non-distribution reasoning as aubio applies (AGPL's network-service clause is also irrelevant — this isn't a server). Not a blocker for a personal build.
- **Effort:** meaningfully higher than aubio — C++ build toolchain, larger binary, more setup to wire into a Swift target (bridging header or a thin ObjC++ wrapper).
- **Verdict: skip.** Essentia's advantage over aubio is more algorithms and better key detection accuracy, but Apple's Music Understanding framework now supersedes both for this exact use case (D14). Don't build a C++ toolchain for something Apple ships for free.

#### D13. AudioKit / SoundpipeAudioKit / Swift-native beat detectors
- **Status: WEAK.** SoundpipeAudioKit itself doesn't expose ready-made tempo detection. Smaller community Swift packages exist (`TempiBeatDetection`, `BPMKit` — a Swift-only tempo estimator for iOS 15+/macOS 12+) but these are single-maintainer, unaudited hobby projects with no stated accuracy benchmarks against DJ-grade catalogue material, let alone jungle/DnB's syncopated breakbeats specifically (the hardest genre for naive onset-based tempo trackers — breakbeat rhythms confuse simple autocorrelation tempo estimators far more than four-on-the-floor house/techno).
- **Verdict: skip.** Neither the accuracy story nor the maintenance story beats aubio/Essentia (which are themselves superseded by D14).

#### D14. Apple's own frameworks — the actual answer
- **AVFoundation / Accelerate / SoundAnalysis (pre-2026): DEAD for this.** Confirmed no tempo/key estimation API exists in any shipped-prior-to-2026 Apple framework. SoundAnalysis does sound *classification* (is this a dog bark, applause, etc.), not tempo/key extraction.
- **Music Understanding framework (new, WWDC26, June 2026): WORKS — this is the real find.**
  - Announced at WWDC 2026, session "Meet the Music Understanding framework." Runs entirely on-device, Neural-Engine-accelerated, no network.
  - Analyses six dimensions from a single call: **key** (tonic + major/minor, as time ranges), **rhythm** (per-beat/per-bar timestamps + a global `beatsPerMinute`), structure, pace, instrument activity, loudness.
  - API surface: `MusicUnderstandingSession`, initialized from an `AVAsset` **or a custom audio buffer stream** (anything conforming to `AsyncSequence` yielding `AVReadOnlyAudioPCMBuffer`). This dual input path is exactly what routes C and E need — C hands it a fetched/streamed `AVAsset`, E hands it a live `AVAudioEngine` tap buffer, with the same API either way.
  - **Requires iOS 27.** Your target device, iPhone 14 Pro, is on the confirmed supported-devices list for iOS 27 (it loses some unrelated Apple Intelligence features reserved for iPhone 15 Pro+, but the OS and this framework run fully). Given WWDC26 already shipped in June 2026 and iOS 27 public betas are already out, GA is expected imminently (Apple's usual September cadence) — by the time this app is actually built, targeting iOS 27 as your deployment minimum for this single personal device is realistic, not speculative.
  - One documented caveat: `beatsPerMinute` is optional/`nil` until the framework has processed enough audio to detect at least two beats — for a full track this is a non-issue, but confirms you need a real span of audio (a couple of seconds minimum), not a single onset.
  - **This directly satisfies "skip DSP entirely."** It replaces aubio and Essentia outright for anything you can get audio for, with zero licence question, zero build complexity, and it's maintained by Apple going forward.

#### D15. CoreML-convertible tempo/key models
- **Status: NOT A REAL ROUTE.** No pretrained, ready-to-ship CoreML tempo/key model exists as an off-the-shelf download. What exists (`tempnetic`, BeatNet, madmom, Beat Transformer) are research training pipelines/architectures you'd have to train yourself on a dataset like GTZAN or GiantSteps and convert — real ML-engineering effort, squarely the kind of thing "skip DSP" was written to avoid.
- **Verdict: do not build.** D14 makes this entirely redundant — Apple already ships a trained, on-device model for exactly this task.

### E. The device's own microphone

#### E16. Recording the record playing
- **Status: WORKS, and is genuinely necessary for true dubplates** — it's the only route with unconditional coverage, because it needs nothing to exist in any database or on any streaming service.
- **Feasibility with D14:** feed an `AVAudioEngine` input tap directly into `MusicUnderstandingSession` as the custom-buffer-stream input. No file write, no DSP code, same API as the fetched-audio path in C.
- **Accuracy in a real room with a turntable:** tempo (rhythm/beat tracking) is comparatively robust to ambient noise for anything with a clear kick/snare pattern, which jungle/DnB/UKG all have in abundance — this is a genre where the microphone route should perform *well*, not marginally. Key estimation is more sensitive to noise floor and turntable rumble/hum bleeding into the low end, and jungle/DnB basslines (sub-heavy, often deliberately distorted/pitched) are a harder key-detection case than clean acoustic material in general — expect key accuracy on mic capture to be the weakest link of the whole ladder, not tempo.
- **Practical constraint:** needs ~20-30 seconds of clean playback per track, phone positioned near the speaker/monitor. This is real friction the user explicitly wanted to avoid ("i dont want to have to play all the songs") — which is exactly why it belongs at the bottom of the ladder, not the top: a genuine last resort for whatever survives after B, C, and the free datasets, not a default.

---

## Corrections To My Assumptions (the brief's framing)

1. **"AcousticBrainz dumps could be the whole answer" — wrong.** The dumps are real, CC0, and downloadable, but they're keyed by MusicBrainz Recording ID. Coverage for your actual hard cases (white labels absent from MusicBrainz) is structurally no better than Discogs' coverage of the same records. It's a legitimate free tier-1 addition once built, not a decisive fix, and building it means processing 589 GB of compressed dumps off-device — real but not urgent effort.
2. **Spotify audio-features status is not a flat yes/no — it depends on your specific app's history.** "Deprecated in Nov 2024" is true for new apps; whether *your* existing credentials survive depends on whether they were in Extended Quota Mode with a pending/approved extension before that date. This needs a direct API test, not a policy read, before you design around it.
3. **A route you didn't ask about turned out to be the strongest one: Apple's Music Understanding framework (iOS 27, announced WWDC26).** It directly and completely satisfies "skip DSP entirely" for both the fetch-audio and microphone paths, and makes aubio/Essentia (which you correctly identified as the fallback if no ready dataset existed) unnecessary rather than merely licence-awkward.
4. **Discogs BPM fields don't exist at all**, confirmed, not just "sometimes populated" — don't budget any resolution rate against Discogs for tempo/key, only for identity/format confirmation, exactly as your existing spec already uses it.
5. **FMA / MTG-Jamendo / Million Song Dataset are all dead ends for artist/title matching specifically** — their genre tags share vocabulary with jungle/DnB ("jungle," "dnb") but the actual catalogues are royalty-free stock music or CC-licensed bedroom-producer uploads with essentially zero overlap with the commercial/white-label vinyl catalogue you're scanning. Worth stating plainly since "jungle" as a search term returns false-positive hits in all three.

---

## Recommended Tier Ladder

| Tier | Route | Expected hit-rate contribution | Notes |
|---|---|---|---|
| 0 | Bundled `library.db` subset (7,010 rows) | High for anything already in your own collection's genres | Already decided, zero network, instant |
| 1 | MusicBrainz search (free) → Discogs search (free, format/identity only, no BPM) | Identity confirmation, feeds tier 2/3 lookups | You already planned this; keep it for metadata, not tempo |
| 2 | Deezer track BPM (free) + GetSongBPM (free, needs README backlink) + Spotify audio-features IF your credentials test as still-working | Catches anything with a real commercial digital release | Cheap, do all three in parallel per track, first hit wins |
| 3 | AcousticBrainz-derived bundled SQLite (built once, off-device, from the MBID you already got in tier 1) | Small but free incremental lift for anything with an MBID | Backlog item, build after MVP ships, not a blocker |
| 4 | SoundCloud search + stream (you have working OAuth) → `MusicUnderstandingSession` on the in-memory buffer (iOS 27) | Best genre-specific coverage for promos/rips/white-label-adjacent uploads that skip Discogs entirely | Requires iOS 27 deployment target on your device; session-based only, never persist the fetched audio (matches SoundCloud's own ToS carve-out) |
| 5 | Microphone capture → `MusicUnderstandingSession` on the live buffer | Only route with unconditional coverage — the true dubplate floor | Last resort by design; tempo should be solid on jungle/DnB's strong transients, key is the weaker link |
| 6 | Manual entry | 100% by definition | First-class UI per your own spec, not an error state |

**Practical sequencing note:** tiers 2 and 4 both benefit from resolving to an artist/title match confidence score first (you already have this in MVP-SPEC §6's Levenshtein threshold) — run tier 2's free APIs before ever touching tier 4's SoundCloud fetch, since a network audio fetch + on-device analysis is strictly more expensive than three parallel free API calls.

---

## What I Would Not Build

- **TuneBat/Musicstax/Chosic scraping or wrapper APIs.** No official access, or gated behind enterprise pricing, or just proxying Spotify anyway. Adds fragility for coverage you can already get more directly elsewhere.
- **A custom-trained CoreML tempo/key model (D15).** Apple's Music Understanding framework is a better, free, maintained version of exactly this. Training your own would be pure effort duplication.
- **aubio or Essentia as your primary analyser.** Both work technically and their GPL/AGPL licences are non-issues for a non-distributed app, but Apple's iOS 27 framework does the same job with zero build toolchain and zero licence footnote. Reach for them only if you specifically need audio analysis working on a device stuck below iOS 27 — not expected to be the case here.
- **YouTube extraction as anything but a break-glass last resort.** It works today in pure Swift, but it's fragile-by-nature (breaks on YouTube's next cipher rotation, no support channel) and a clear ToS violation independent of App Store distribution status. SoundCloud already covers this genre better and more legitimately.
- **Bandcamp and Internet Archive as active routes.** No viable streaming API (Bandcamp) or no relevant catalogue (Internet Archive — wrong era entirely for jungle/DnB).
- **FMA, MTG-Jamendo, Million Song Dataset as lookup sources.** Confirmed zero meaningful overlap with your actual vinyl catalogue despite genre-tag name collisions.

## Sources

- [AcousticBrainz Downloads page](https://acousticbrainz.org/download)
- [AcousticBrainz: Making a hard decision to end the project – MetaBrainz Blog](https://blog.metabrainz.org/2022/02/16/acousticbrainz-making-a-hard-decision-to-end-the-project/)
- [AcousticBrainz data dumps size discussion – MetaBrainz Community Discourse](https://community.metabrainz.org/t/acousticbrainz-data-dumps/591961)
- [MusicBrainz About/Data License](https://musicbrainz.org/doc/About/Data_License)
- [MusicBrainz Canonical Data Dumps](https://metabrainz.org/datasets/derived-dumps)
- [Spotify: Introducing some changes to our Web API (official, 2024-11-27)](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api)
- [Spotify Community: Access to deprecated Audio Features endpoint for personal apps](https://community.spotify.com/t5/Spotify-for-Developers/Access-to-deprecated-Audio-Features-endpoint-for-personal/td-p/7419715)
- [GetSongBPM API for webmasters](https://getsongbpm.com/api)
- [Deezer API usage docs (deezer-python)](https://deezer-python.readthedocs.io/en/stable/usage.html)
- [Discogs Forum: key and bpm listing](https://www.discogs.com/forum/thread/120839)
- [SoundCloud API Terms of Use](https://developers.soundcloud.com/docs/api/terms-of-use)
- [Bandcamp developer API scope discussion](https://github.com/api-evangelist/bandcamp)
- [YouTubeKit — native Swift YouTube extractor](https://swiftpackageregistry.com/alexeichhorn/YouTubeKit)
- [aubio — official site](https://aubio.org/) and [iOS build docs](https://aubio.readthedocs.io/en/latest/installing.html)
- [Essentia — GitHub (MTG/essentia)](https://github.com/MTG/essentia), [RhythmExtractor2013 reference](https://essentia.upf.edu/reference/std_RhythmExtractor2013.html)
- [Apple: Meet the Music Understanding framework — WWDC26 session video](https://developer.apple.com/videos/play/wwdc2026/253/)
- [WWDC26 session digest — Music Understanding framework (community notes)](https://github.com/ivan-magda/wwdc26-notes/blob/main/sessions/253-music-understanding-framework/digest.md)
- [iOS 27 supported devices list](https://www.iclarified.com/101122/ios-27-supported-devices-full-list-of-compatible-iphones)
- [Free Music Archive — Jungle genre page](https://freemusicarchive.org/genre/Jungle/) and [Drum & Bass genre page](https://freemusicarchive.org/genre/Drum_amp_Bass/)
- [MTG-Jamendo Dataset — GitHub](https://github.com/MTG/mtg-jamendo-dataset)
- [The Great 78 Project — Internet Archive](https://great78.archive.org/)
