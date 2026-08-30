<!-- GSD:project-start source:PROJECT.md -->
## Project

**Vinyl Set Builder**

A personal-use iOS app for one DJ. You photograph the labels of the records in your
crate; the app reads the track listings off them, works out the BPM and musical key of
each track, and orders the whole crate into a set you could actually play — ascending
in tempo, harmonically sensible, one track per record.

It is a crate-digging tool, not a music player. There is no audio in it at any point.
It is not distributed and never will be.

**Core Value:** **The sequenced set.** If everything else is clumsy but the app hands back an ordered,
mixable run of records with sane tempo and key transitions that re-optimises when you
add more, it has done its job. Scanning is only the input method.

### Constraints

- **Tech stack**: Swift only, SwiftUI, **iOS 26**. No Python runtime, no embedded interpreter.
  URLSession covers every API call.
- **iOS 26 deployment target is deliberate**: it is what the installed toolchain
  (Xcode 26.0.1, iOS 26 SDK) can actually build. **Nothing in the project may depend on an
  SDK that is not installed.** The modern Swift-native Vision `RecognizeTextRequest` is
  iOS 18+, so it remains available. Apple's Music Understanding framework needs iOS 27 and
  is therefore NOT used — see the audio-analysis constraint below.
- **OCR**: Apple Vision, `.accurate` recognition level. On-device, free, no model bundling,
  no network. At the iOS 26 target the Swift-native `RecognizeTextRequest` (iOS 18+) is
  available and preferred over the older `VNRecognizeTextRequest`.
- **BPM + key**: the app's **own Accelerate/vDSP analyser**, on-device and offline —
  tempo via onset envelope + autocorrelation, key via chromagram + Krumhansl-Schmuckler
  profile matching, mapped to Camelot. No API key, no rate limit, no third-party licence.
  It sits behind an `AudioAnalyzing` protocol so Apple's Music Understanding can replace it
  as a drop-in when Xcode 27 ships, without touching any caller.
- **Persistence**: SwiftData, on-device only.
- **Device**: iPhone 14 Pro, paid Apple Developer account, 1-year provisioning.
- **Public repo**: the repo is public. (It was made public for a GetSongBPM backlink that is
  no longer needed, but it stays public.) Therefore **no secret may ever be committed** —
  keys are generated into a gitignored `Secrets.swift` at build time from `~/.config/keys/`,
  compiled into the binary as intended, never in version control. The bundled BPM corpus and
  the fixture photographs are likewise gitignored.
- **Rate limits**: Discogs 60 req/min authenticated. Max 3 concurrent requests, backoff
  on 429.
- **API call frugality**: resolution must climb the ladder — bundled corpus → local cache →
  free-unlimited (MusicBrainz) → free-limited (Discogs, SoundCloud). Never call a
  quota-limited source for a datum available cheaper.
- **Build toolchain**: Xcode 26.0.1 / iOS 26 SDK, macOS 26.6.2. Verified by
  `xcodebuild -showsdks`. `MusicUnderstanding.framework` is absent from both the SDK and the
  running system — checked, not assumed. **No phase may be planned against an unavailable SDK.**
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.2 (Xcode 26.0.1, iOS 26 SDK — the target we build against) | Language | Ships with Xcode 26; "Approachable Concurrency" mode makes Swift 6 the easy default, not a strict-mode fight |
| SwiftUI | iOS 26 SDK | UI | Locked by PROJECT.md constraints; single-target personal app |
| Vision (`RecognizeTextRequest`) | Swift-native API, iOS 18+ | OCR | Available at the iOS 26 target and preferred. `VNRecognizeTextRequest` remains a valid fallback and is what the OCR spike used |
| SwiftData | iOS 17.0+ (target is 26) | Persistence for mutable app data (Crate/VinylEntry/Track) | Already locked in PROJECT.md; native, zero extra dependency, fine at this data scale (<100 vinyls, <400 tracks) |
| GRDB.swift | 7.11.1 (latest tag, 2026-06-18) | Read-only bundled reference DB (`bpmkey.db`, 6,608 deduped rows, 880 KB) | See dedicated section below |
| Accelerate / vDSP (stdlib) | iOS 8+ | **BPM + musical key** on-device — onset envelope + autocorrelation for tempo, chromagram + Krumhansl-Schmuckler for key → Camelot | Apple framework, zero dependencies, builds on the INSTALLED iOS 26 SDK. Sits behind `AudioAnalyzing` so Music Understanding can swap in if Xcode 27 ever lands. ~350 lines, TDD'd against 29 ground-truth tracks whose audio is already cached |
### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GRDB.swift | 7.11.1 | Query bundled `(artist, title, bpm, camelot)` SQLite — 6,608 rows | Tier-0 resolution lookup only — not for the mutable app model, that's SwiftData |
| URLSession (stdlib) | iOS 26 SDK | Discogs/MusicBrainz/SoundCloud HTTP calls | Already locked as the only network layer; no Alamofire needed for 3 simple REST APIs |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| Local SPM package (in-repo, e.g. `VinylSetBuilderCore`) | Houses SwiftData models, resolver, sequencer, segmentation, GRDB wrapper | See "Xcode Project Layout" section — mirrors your existing CrateDigCore/CrateDigMac split |
| Xcode "Run Script" build phase | Generates gitignored `Secrets.swift` from dotenv at build time | See recipe below — do NOT use an SPM build-tool plugin for this |
## 1. Apple Vision Text Recognition: Which API
- `RecognizeTextRequest` (the new `Sendable` struct with `perform(on:)` async/await) is **iOS 18.0+ / macOS 15.0+ only**. The deployment target is **iOS 26**, so it IS available and is the preferred API. `VNRecognizeTextRequest` is not deprecated and remains a valid fallback — it is what the OCR spike used on macOS, and the spike's findings (EXIF orientation must be passed explicitly; coordinates return in the ORIGINAL unrotated buffer space) apply to both APIs.
- `VNRecognizeTextRequest` itself is **not deprecated**. Its documentation shows continued support through iOS 13.0+ up to current releases; only its older *revisions* (`VNRecognizeTextRequestRevision1`, `Revision2`) are marked deprecated in favor of `VNRecognizeTextRequestRevision3`, which is the current default revision. Do not pin an explicit older revision — let it default.
- If you ever raise the deployment target to iOS 18+, the two APIs are functionally near-identical for your use case (same `.accurate`/`.fast` recognition levels, same `customWords`, same confidence/bounding-box shape). The only real gain from switching would be async/await ergonomics (no completion handler, no separate `VNImageRequestHandler` object) — not new OCR capability. Not worth doing now; it would only matter if you later drop iOS 17 support.
- iOS 26 additionally introduced `RecognizeDocumentsRequest` (structured tables/lists/phone-number extraction). Not relevant here — vinyl labels are not structured documents, and it inherits the same 18+ floor.
## 2. `customWords` — Behavior and Limits
- `customWords: [String]` is documented as supplementing the recognized-language dictionary "at the word-recognition stage." It is a **bias list, not a forced/verbatim dictionary** — it nudges the language model toward those strings, it does not guarantee an exact match will be returned, especially against a noisy or stylized vinyl label font.
- There is no Apple-documented hard size limit on the array. Community reports (Apple Developer Forums, going back to iOS 15/16 and still cited as unresolved) describe `customWords` sometimes appearing to have no measurable effect on recognition quality, particularly for unusual capitalization/stylized label typography. Treat it as "may help, verify against your golden fixture set, don't rely on it as a correctness guarantee."
- Practical recommendation: seed it with artist/label names likely to recur across your crate (a few dozen to low hundreds of strings is the range other developers report using without issue), but design your matching/manual-entry path (already planned in MVP-SPEC §6) assuming `customWords` is a minor accuracy nudge, not a solved problem. Your fixture-based ship criterion in Phase 1 (§"raw text dumps onscreen for 10 real labels") is the right way to actually measure whether it's helping on your fonts — don't take this on faith.
## 3. AVCaptureSession Still Capture in SwiftUI — Rapid Repeated Capture
- `AVCaptureSession` + `AVCapturePhotoOutput`, session configuration and `session.startRunning()` run off the main thread (this call blocks). `AVCaptureVideoPreviewLayer` is wrapped in a `UIViewRepresentable` for the SwiftUI preview surface.
- For "shoot, then immediately shoot again without waiting on any screen" (your Phase-1 ship criterion), call `photoOutput.capturePhoto(with: settings, delegate: delegate)` again as soon as the previous capture's delegate callback (`photoOutput(_:didFinishProcessingPhoto:)`) fires — do not call it again before that callback fires, `AVCapturePhotoOutput` will reject/queue unpredictably on overlapping calls. Bridge the delegate callback into `async/await` with a `CheckedContinuation` so the SwiftUI call site is a simple `let photo = try await camera.capturePhoto()` in a loop, keeping the shutter button non-blocking from the UI's perspective — the thumbnail strip and per-item resolution spinner (already in your UI flow, §2) update independently as each capture/OCR pair completes.
- **Concurrency wiring, current (Xcode 26 / Swift 6.2):** new Xcode 26 projects default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` — most of your code is implicitly main-actor-isolated by default, which is *simpler* than Swift 6.0's original strict-everywhere mode. The one place you must be deliberate is exactly the AVFoundation boundary: encapsulate session setup, `startRunning()`, and the photo-capture delegate in a small dedicated type (an `actor CameraController` or an explicit `nonisolated` class with its own serial `DispatchQueue`) and mark the AVFoundation import `@preconcurrency` where the compiler complains about `Sendable` on delegate types Apple hasn't audited. This is unresolved-as-a-single-blessed-pattern even in the Swift Forums as of mid-2026 (real thread, real disagreement) — don't over-invest here. Given this is a single-target personal app, the pragmatic move is: build the actor-encapsulated `CameraController`, accept `@preconcurrency import AVFoundation` at that one boundary, and move on. Do not spend a phase fighting strict concurrency checker warnings that Apple's own sample code hasn't fully resolved either.
## 4. SwiftData on iOS 17+ — Ordered Relationships, Gotchas
- `Crate.sequence` and `Crate.excluded` are typed as `[TrackID]` — plain arrays of a `UUID`-like scalar, not `@Relationship` object arrays. **Keep them that way.** A `[UUID]` (or `[String]`) stored as a plain `@Attribute` on a `@Model` class is a single Codable/transformable value, not a Core Data to-many relationship, and Swift array order is preserved exactly as inserted. Resolve `Track` objects by fetching-by-id when you need the full object, using an `#Predicate` on `id`.
- `Track` already carries a `position: Int` field per your spec. Use that as the source of truth for in-vinyl track order (`candidates.sorted(by: \.position)` after fetch) rather than trusting relationship array order — this sidesteps the ordering bug entirely for the one place you do have a real object relationship (`VinylEntry.candidates: [Track]`, which likely should be `@Relationship(deleteRule: .cascade) var candidates: [Track]` for cascade-delete convenience, sorted by `position` at the call site, never relied on for order as fetched).
- Relationship setup is finicky about insertion order: insert the parent (`Crate`/`VinylEntry`) into the `ModelContext` before appending children, and prefer optional relationship properties — several developers report intermittent failures with non-optional relationships set before the parent is in-context.
- SwiftData is measurably slower than raw Core Data on relationship-heavy workloads in synthetic benchmarks, but at this project's scale (<100 vinyls, <400 candidate tracks) this is a non-issue — do not pre-optimize for it.
- Migrations are less mature/flexible than hand-written Core Data lightweight migrations. At MVP with one schema version this doesn't matter; if you add a schema-breaking change later, budget time for a `VersionedSchema`/`SchemaMigrationPlan`, don't assume it's automatic like Core Data's lightweight migration.
## 5. Bounded-Concurrency Network Pipeline (max 3, backoff on 429)
## 6. Bundled Read-Only SQLite: GRDB vs Raw SQLite3 vs SwiftData
- **SwiftData is disqualified outright** for this piece: SwiftData does not open an arbitrary hand-built SQLite file — it controls its own Core Data-derived on-disk schema/format. You cannot point `ModelContainer` at your pruned `library.db` and query it; you would have to reverse-engineer and replicate Core Data's private SQLite schema, which is unsupported and fragile. Use SwiftData only for the app's own mutable model (Crate/VinylEntry/Track), as already decided.
- **Raw SQLite3 C API works but costs more than it saves here.** It's viable for a single trivial `SELECT`, but this lookup needs normalized artist/title matching against 7,010 rows with fallback logic (§6 of MVP-SPEC: exact → fuzzy → miss) — GRDB's `FetchableRecord`/query interface and thread-safe `DatabaseQueue` remove a meaningful amount of manual `sqlite3_prepare_v2`/`sqlite3_step`/`sqlite3_column_*` boilerplate and manual memory/statement-lifecycle management for very little cost (one SPM dependency, well-maintained, MIT-licensed, by a single maintainer with a long track record).
- **Concrete bundling recipe** (the one real gotcha here, sourced from a documented real-world caveat, not guesswork): a database exported via GRDB's own `backup()` API inherits the *source* database's journal mode. Read-write SQLite databases default to WAL mode, which requires sidecar `.sqlite-wal`/`.sqlite-shm` files that cannot exist in a read-only app bundle — opening it read-only will fail with "unable to open database file." Before adding the pruned `library.db` to the Xcode project as a bundle resource:
## 7. Generating Gitignored `Secrets.swift` at Build Time
## 8. Xcode Project Layout: Single Target vs App + Local SPM Package
- **App target:** `App` entry point, SwiftUI `View`s, the camera capture UIViewRepresentable/actor, wiring/navigation. Nothing here needs unit testing in isolation — it's thin glue.
- **`VinylSetBuilderCore` package:** SwiftData `@Model` types, the segmentation heuristics (§4 of MVP-SPEC — this is the part most worth TDD-ing against fixture text), the sequencer (beam search, Camelot distance, BPM gate — ported from CrateDig's Python logic per PROJECT.md context), the metadata resolver (Discogs/MusicBrainz/SoundCloud clients + the Music Understanding BPM/key tier + bounded-concurrency pipeline from §5), and the GRDB wrapper around the bundled `bpmkey.db`.
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `VNRecognizeTextRequest` | `RecognizeTextRequest` (Swift-native) | Only if you raise the deployment target to iOS 18+; even then it's an ergonomics win (async/await), not a capability win |
| GRDB.swift | Raw SQLite3 C API | Only if you want zero dependencies for a single trivial lookup query — not the case here given fuzzy-match fallback logic |
| GRDB.swift | SwiftData | Never for this specific bundled read-only file — SwiftData can't open a hand-built external SQLite schema |
| TaskGroup pull-model | `AsyncSemaphore`-style third-party package | Only if the bound needs to be dynamically adjustable at runtime; a fixed max-3 bound doesn't need it |
| `[UUID]` scalar arrays for ordering | `@Relationship` to-many with manual `sortIndex` | Never for anything you need reliably ordered — the scalar-array approach sidesteps the bug entirely rather than working around it |
| Xcode Run Script phase for Secrets.swift | SPM build-tool plugin | Only if the secret source lived inside the package directory itself (it doesn't — `~/.config/keys/` is outside the repo by design) |
| App + local SPM package | Single app target | Never here — you already have the CrateDig precedent proving the split pays off, and this project has two fixture-heavy logic cores that want fast native test iteration |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|--------------|
| ~~`RecognizeTextRequest`~~ | **No longer avoided** — the iOS 26 target makes it available and preferred | Use `RecognizeTextRequest`; `VNRecognizeTextRequest` is an acceptable fallback |
| SwiftData for the bundled `library.db` | Can't open a hand-built external SQLite file/schema | GRDB.swift with `configuration.readonly = true` |
| `@Relationship` to-many arrays as an ordering mechanism | Core Data backs it with `NSSet` — order is not guaranteed to survive a fetch | Plain `[UUID]`/scalar-array attributes, or an explicit `position: Int` field sorted at read time |
| SPM build-tool plugin for secrets generation | Sandboxed; can't read `~/.config/keys/enrich.env` outside the package | Xcode Run Script build phase with `ENABLE_USER_SCRIPT_SANDBOXING = No` |
| Semaphore/third-party concurrency package for the max-3 bound | Unneeded complexity — TaskGroup's pull model gives you the exact same bound natively | `withTaskGroup` seeded with `maxConcurrency` tasks, refilled one-in-one-out |
| Alamofire / any networking wrapper | Three simple REST GETs with query params and JSON bodies; URLSession + Codable is already the whole job | `URLSession` (already locked in PROJECT.md) |
## Stack Patterns by Variant
- Migrate OCR to `RecognizeTextRequest` for async/await ergonomics.
- Because the completion-handler/`VNImageRequestHandler` boilerplate goes away and it composes more naturally with the rest of your structured-concurrency pipeline — but this is a nice-to-have refactor, not a correctness fix.
- Don't. Keep it strictly read-only tier-0 lookup as designed. Write resolved/cached results into the SwiftData store instead (a `ResolvedCacheEntry` model), since that's already your app's mutable persistence layer and avoids re-triggering the WAL/journal-mode bundling gotcha on every app update.
## Version Compatibility
| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| GRDB.swift 7.11.1 | iOS 17.0+, Swift 6.2 / Xcode 26 | No conflict with SwiftData — they coexist as two separate storage layers (mutable app data vs. read-only reference data), which is the intended architecture here, not a smell |
| `VNRecognizeTextRequest` | iOS 13.0+ through current | Default revision (`Revision3`) auto-selected; don't pin `Revision1`/`Revision2`, both deprecated |
| SwiftData | iOS 17.0+ | Matches PROJECT.md's iOS 17+ floor exactly — no gap |
## Sources
- Apple Developer Documentation (via sosumi.ai mirror, verified against multiple independent fetches): `VNRecognizeTextRequest`, `VNRecognizeTextRequestRevision1/3`, `RecognizeTextRequest`, `RecognizedTextObservation`, `RecognizedText`, `BoundingBoxProviding` — HIGH confidence, official source
- Apple Developer Forums thread on `.customWords` behavior reports (2022, still cited as current in 2026 discussions) — MEDIUM confidence, single-source community report, no official numeric-limit documentation found
- Swift Forums: "Safely use AVCaptureSession + Swift 6.2 Concurrency" (forums.swift.org/t/83622) — MEDIUM confidence, live unresolved discussion among Swift concurrency experts, not a single blessed answer
- twocentstudios.com, "Caveats Using Read-only SQLite Databases from the App Bundle" (2025-06-07) — HIGH confidence, concrete documented WAL/journal_mode gotcha with working fix
- GitHub `groue/GRDB.swift` releases API (`v7.11.1`, published 2026-06-18) — HIGH confidence, verified directly via GitHub API, not training data
- donnywals.com, "Setting default actor isolation in Xcode 26" and mjtsai.com Swift 6.2 coverage — MEDIUM confidence on Xcode 26 default concurrency settings (`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY=YES`)
- justin.searls.co, "I made Xcode's tests 60 times faster" — MEDIUM confidence (single source, but directly on-point for the app-target-vs-package test speed claim)
- Existing project precedent: CrateDigCore/CrateDigMac split (this user's own prior shipped project, per memory) — HIGH confidence as an internally-consistent pattern to reuse
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
