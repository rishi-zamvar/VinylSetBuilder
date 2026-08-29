# Stack Research

**Domain:** On-device iOS OCR + local persistence + bounded-concurrency network resolution app (personal, undistributed)
**Researched:** 2026-08-29
**Confidence:** HIGH on Vision API version choice, SwiftData ordering pitfall, GRDB recommendation, and structured-concurrency pattern. MEDIUM on `customWords` behavior and Xcode-26 concurrency defaults (fast-moving, sparsely documented). LOW on any hard numeric limit for `customWords` size — none is published.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.2 (Xcode 26 toolchain) | Language | Ships with Xcode 26; "Approachable Concurrency" mode makes Swift 6 the easy default, not a strict-mode fight |
| SwiftUI | iOS 17 SDK | UI | Locked by PROJECT.md constraints; single-target personal app |
| Vision (`VNRecognizeTextRequest`) | Legacy VN* API, current on iOS 17+ | OCR | See dedicated section below — this is the only correct choice at an iOS 17 deployment target |
| SwiftData | iOS 17.0+ | Persistence for mutable app data (Crate/VinylEntry/Track) | Already locked in PROJECT.md; native, zero extra dependency, fine at this data scale (<100 vinyls, <400 tracks) |
| GRDB.swift | 7.11.1 (latest tag, 2026-06-18) | Read-only bundled reference DB (`library.db`, 7,010 pruned rows) | See dedicated section below |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GRDB.swift | 7.11.1 | Query bundled `(artist, title, bpm, camelot)` SQLite | Tier-0 resolution lookup only — not for the mutable app model, that's SwiftData |
| URLSession (stdlib) | iOS 17 SDK | Discogs/MusicBrainz/GetSongBPM HTTP calls | Already locked as the only network layer; no Alamofire needed for 3 simple REST APIs |

No other third-party dependency is justified at this scope. Do not add a JSON/networking wrapper, a DI framework, or a state-management library — URLSession + Codable + structured concurrency covers three small REST integrations, and a single-screen-flow SwiftUI app does not need a DI container.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Local SPM package (in-repo, e.g. `VinylSetBuilderCore`) | Houses SwiftData models, resolver, sequencer, segmentation, GRDB wrapper | See "Xcode Project Layout" section — mirrors your existing CrateDigCore/CrateDigMac split |
| Xcode "Run Script" build phase | Generates gitignored `Secrets.swift` from dotenv at build time | See recipe below — do NOT use an SPM build-tool plugin for this |

## 1. Apple Vision Text Recognition: Which API

**Recommendation: `VNRecognizeTextRequest` + `VNImageRequestHandler` (the "legacy" VN* API). Do NOT use the new Swift-native `RecognizeTextRequest`.**

**Confidence: HIGH.** This isn't close — it's a hard version-gate, not a taste call.

- `RecognizeTextRequest` (the new `Sendable` struct with `perform(on:)` async/await) is **iOS 18.0+ / macOS 15.0+ only**. Your deployment target is iOS 17+ (PROJECT.md constraint). It is simply unavailable on iOS 17 devices, so there is no decision to make here — `VNRecognizeTextRequest` is the only API that runs on your floor.
- `VNRecognizeTextRequest` itself is **not deprecated**. Its documentation shows continued support through iOS 13.0+ up to current releases; only its older *revisions* (`VNRecognizeTextRequestRevision1`, `Revision2`) are marked deprecated in favor of `VNRecognizeTextRequestRevision3`, which is the current default revision. Do not pin an explicit older revision — let it default.
- If you ever raise the deployment target to iOS 18+, the two APIs are functionally near-identical for your use case (same `.accurate`/`.fast` recognition levels, same `customWords`, same confidence/bounding-box shape). The only real gain from switching would be async/await ergonomics (no completion handler, no separate `VNImageRequestHandler` object) — not new OCR capability. Not worth doing now; it would only matter if you later drop iOS 17 support.
- iOS 26 additionally introduced `RecognizeDocumentsRequest` (structured tables/lists/phone-number extraction). Not relevant here — vinyl labels are not structured documents, and it inherits the same 18+ floor.

**Usage pattern (this is the one to build against):**

```swift
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate          // already locked in PROJECT.md
request.usesLanguageCorrection = true         // default; test false too — label text isn't prose
request.customWords = ["Metalheadz", "Ram Records", "Congo Natty", ...] // your labels/artists

let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
try handler.perform([request])

guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

for observation in observations {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let text = candidate.string                  // recognized text
    let confidence = candidate.confidence         // Float 0...1, confidence lives on the candidate, not the observation
    let boundingBox = observation.boundingBox     // CGRect, normalized 0...1, ORIGIN BOTTOM-LEFT (Vision/CG convention)
}
```

**Gotcha to flag now for Phase 1/2 (segmentation):** `boundingBox` is normalized with a bottom-left origin (Vision/Core Image convention), not SwiftUI/UIKit's top-left. Your radial-clustering segmentation math (distance from label center) needs this flipped (`y' = 1 - y`) before it means anything visually, or you'll cluster upside-down.

## 2. `customWords` — Behavior and Limits

**Confidence: MEDIUM on behavior, LOW on limits — no authoritative numeric cap is published.**

- `customWords: [String]` is documented as supplementing the recognized-language dictionary "at the word-recognition stage." It is a **bias list, not a forced/verbatim dictionary** — it nudges the language model toward those strings, it does not guarantee an exact match will be returned, especially against a noisy or stylized vinyl label font.
- There is no Apple-documented hard size limit on the array. Community reports (Apple Developer Forums, going back to iOS 15/16 and still cited as unresolved) describe `customWords` sometimes appearing to have no measurable effect on recognition quality, particularly for unusual capitalization/stylized label typography. Treat it as "may help, verify against your golden fixture set, don't rely on it as a correctness guarantee."
- Practical recommendation: seed it with artist/label names likely to recur across your crate (a few dozen to low hundreds of strings is the range other developers report using without issue), but design your matching/manual-entry path (already planned in MVP-SPEC §6) assuming `customWords` is a minor accuracy nudge, not a solved problem. Your fixture-based ship criterion in Phase 1 (§"raw text dumps onscreen for 10 real labels") is the right way to actually measure whether it's helping on your fonts — don't take this on faith.

## 3. AVCaptureSession Still Capture in SwiftUI — Rapid Repeated Capture

**Confidence: HIGH on the capture pattern itself; MEDIUM on the exact Swift 6.2/Xcode 26 concurrency wiring (actively evolving, no single canonical answer yet even in Apple's own forums).**

Pattern (unchanged in substance for years, still Apple's own AVCam sample structure):

- `AVCaptureSession` + `AVCapturePhotoOutput`, session configuration and `session.startRunning()` run off the main thread (this call blocks). `AVCaptureVideoPreviewLayer` is wrapped in a `UIViewRepresentable` for the SwiftUI preview surface.
- For "shoot, then immediately shoot again without waiting on any screen" (your Phase-1 ship criterion), call `photoOutput.capturePhoto(with: settings, delegate: delegate)` again as soon as the previous capture's delegate callback (`photoOutput(_:didFinishProcessingPhoto:)`) fires — do not call it again before that callback fires, `AVCapturePhotoOutput` will reject/queue unpredictably on overlapping calls. Bridge the delegate callback into `async/await` with a `CheckedContinuation` so the SwiftUI call site is a simple `let photo = try await camera.capturePhoto()` in a loop, keeping the shutter button non-blocking from the UI's perspective — the thumbnail strip and per-item resolution spinner (already in your UI flow, §2) update independently as each capture/OCR pair completes.
- **Concurrency wiring, current (Xcode 26 / Swift 6.2):** new Xcode 26 projects default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` — most of your code is implicitly main-actor-isolated by default, which is *simpler* than Swift 6.0's original strict-everywhere mode. The one place you must be deliberate is exactly the AVFoundation boundary: encapsulate session setup, `startRunning()`, and the photo-capture delegate in a small dedicated type (an `actor CameraController` or an explicit `nonisolated` class with its own serial `DispatchQueue`) and mark the AVFoundation import `@preconcurrency` where the compiler complains about `Sendable` on delegate types Apple hasn't audited. This is unresolved-as-a-single-blessed-pattern even in the Swift Forums as of mid-2026 (real thread, real disagreement) — don't over-invest here. Given this is a single-target personal app, the pragmatic move is: build the actor-encapsulated `CameraController`, accept `@preconcurrency import AVFoundation` at that one boundary, and move on. Do not spend a phase fighting strict concurrency checker warnings that Apple's own sample code hasn't fully resolved either.

## 4. SwiftData on iOS 17+ — Ordered Relationships, Gotchas

**Confidence: HIGH.** This is a well-documented, consistently-reported limitation, not a training-data guess.

**The core limitation:** Core Data (SwiftData's backing store) represents to-many relationships as `NSSet` — unordered. SwiftData does not currently expose Core Data's separate "ordered relationship" feature. **Fetching a `@Relationship` to-many array through SwiftData does not guarantee stable order across fetches**, even if it happens to look stable in one run.

**This directly matters for your data model** (`Crate.sequence: [TrackID]`, `Crate.excluded: [TrackID]`, `VinylEntry.candidates: [Track]`) — and the good news is your MVP-SPEC data model in `docs/MVP-SPEC.md` already avoids the trap without knowing it:

- `Crate.sequence` and `Crate.excluded` are typed as `[TrackID]` — plain arrays of a `UUID`-like scalar, not `@Relationship` object arrays. **Keep them that way.** A `[UUID]` (or `[String]`) stored as a plain `@Attribute` on a `@Model` class is a single Codable/transformable value, not a Core Data to-many relationship, and Swift array order is preserved exactly as inserted. Resolve `Track` objects by fetching-by-id when you need the full object, using an `#Predicate` on `id`.
- `Track` already carries a `position: Int` field per your spec. Use that as the source of truth for in-vinyl track order (`candidates.sorted(by: \.position)` after fetch) rather than trusting relationship array order — this sidesteps the ordering bug entirely for the one place you do have a real object relationship (`VinylEntry.candidates: [Track]`, which likely should be `@Relationship(deleteRule: .cascade) var candidates: [Track]` for cascade-delete convenience, sorted by `position` at the call site, never relied on for order as fetched).

**Other SwiftData gotchas worth flagging into the roadmap for the persistence phase:**
- Relationship setup is finicky about insertion order: insert the parent (`Crate`/`VinylEntry`) into the `ModelContext` before appending children, and prefer optional relationship properties — several developers report intermittent failures with non-optional relationships set before the parent is in-context.
- SwiftData is measurably slower than raw Core Data on relationship-heavy workloads in synthetic benchmarks, but at this project's scale (<100 vinyls, <400 candidate tracks) this is a non-issue — do not pre-optimize for it.
- Migrations are less mature/flexible than hand-written Core Data lightweight migrations. At MVP with one schema version this doesn't matter; if you add a schema-breaking change later, budget time for a `VersionedSchema`/`SchemaMigrationPlan`, don't assume it's automatic like Core Data's lightweight migration.

## 5. Bounded-Concurrency Network Pipeline (max 3, backoff on 429)

**Confidence: HIGH.** This is a stable, well-established structured-concurrency idiom (the same "pull model" Apple itself demonstrated for bounded downloads), not a fragile new API.

**Pattern — TaskGroup with a pull model, no semaphore/actor needed for the bound itself:**

```swift
func resolveAll(_ tracks: [Track], maxConcurrency: Int = 3) async -> [ResolvedTrack] {
    var results: [ResolvedTrack] = []
    var iterator = tracks.makeIterator()

    await withTaskGroup(of: ResolvedTrack.self) { group in
        // Seed exactly maxConcurrency tasks up front.
        for _ in 0..<maxConcurrency {
            guard let track = iterator.next() else { break }
            group.addTask { await resolve(track) }
        }
        // Pull model: as each task finishes, add exactly one more.
        // This keeps concurrency pinned at maxConcurrency without a semaphore.
        while let result = await group.next() {
            results.append(result)
            if let next = iterator.next() {
                group.addTask { await resolve(next) }
            }
        }
    }
    return results
}
```

**Backoff on 429 lives *inside* `resolve(_:)`, not in the group plumbing** — keep the two concerns separate:

```swift
func resolve(_ track: Track) async -> ResolvedTrack {
    var attempt = 0
    while true {
        let (data, response) = try? await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            attempt += 1
            guard attempt <= 3 else { return .failed(track) }
            let retryAfter = (response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            let delay = retryAfter ?? min(pow(2.0, Double(attempt)), 8.0)  // exponential, capped, honor Retry-After if present
            try? await Task.sleep(for: .seconds(delay))
            continue
        }
        // ... parse and return
    }
}
```

This satisfies "TaskGroup, max 3 in flight, backoff on 429" exactly as specified in PROJECT.md/MVP-SPEC §6 without any third-party concurrency library. Do not reach for an `AsyncSemaphore` package (mentioned in some Swift Forums threads) — the pull-model `TaskGroup` above is fewer moving parts and is the pattern Apple's own WWDC structured-concurrency material demonstrates for exactly this shape of problem.

## 6. Bundled Read-Only SQLite: GRDB vs Raw SQLite3 vs SwiftData

**Recommendation: GRDB.swift 7.11.1, `readonly = true` configuration. Do not use SwiftData or raw SQLite3 for this.**

**Confidence: HIGH.**

- **SwiftData is disqualified outright** for this piece: SwiftData does not open an arbitrary hand-built SQLite file — it controls its own Core Data-derived on-disk schema/format. You cannot point `ModelContainer` at your pruned `library.db` and query it; you would have to reverse-engineer and replicate Core Data's private SQLite schema, which is unsupported and fragile. Use SwiftData only for the app's own mutable model (Crate/VinylEntry/Track), as already decided.
- **Raw SQLite3 C API works but costs more than it saves here.** It's viable for a single trivial `SELECT`, but this lookup needs normalized artist/title matching against 7,010 rows with fallback logic (§6 of MVP-SPEC: exact → fuzzy → miss) — GRDB's `FetchableRecord`/query interface and thread-safe `DatabaseQueue` remove a meaningful amount of manual `sqlite3_prepare_v2`/`sqlite3_step`/`sqlite3_column_*` boilerplate and manual memory/statement-lifecycle management for very little cost (one SPM dependency, well-maintained, MIT-licensed, by a single maintainer with a long track record).
- **Concrete bundling recipe** (the one real gotcha here, sourced from a documented real-world caveat, not guesswork): a database exported via GRDB's own `backup()` API inherits the *source* database's journal mode. Read-write SQLite databases default to WAL mode, which requires sidecar `.sqlite-wal`/`.sqlite-shm` files that cannot exist in a read-only app bundle — opening it read-only will fail with "unable to open database file." Before adding the pruned `library.db` to the Xcode project as a bundle resource:
  ```bash
  sqlite3 library.db "PRAGMA journal_mode=DELETE;"
  sqlite3 library.db "VACUUM;"
  ```
  Then open it in-app:
  ```swift
  guard let path = Bundle.main.path(forResource: "library", ofType: "db") else {
      fatalError("bundled library.db missing")
  }
  var config = Configuration()
  config.readonly = true
  let dbQueue = try DatabaseQueue(path: path, configuration: config)
  ```

**Installation:**
```
.package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1")
```
Add this to the local SPM package's `Package.swift` (see layout section below), not the app target directly — the resolution logic that queries it belongs in the package, not the app.

## 7. Generating Gitignored `Secrets.swift` at Build Time

**Recommendation: a plain Xcode "Run Script" build phase on the app target. Do NOT use an SPM build-tool plugin for this.**

**Confidence: HIGH on the recommendation, MEDIUM on the exact sandboxing build-setting name persisting unchanged through future Xcode point releases.**

**Why not an SPM plugin:** SPM build-tool plugins execute in a sandboxed process whose file-system access is restricted to the package's own directory tree and DerivedData — they cannot read arbitrary paths outside the package by default. Your secrets source (`~/.config/keys/enrich.env`, per PROJECT.md) is deliberately *outside* the repo entirely. Getting a plugin to read it means fighting the plugin sandbox for no benefit over a Run Script phase, which has none of these restrictions by default.

**One thing to know about Run Script phases specifically:** Xcode 15+ (carried into 26) turned on `ENABLE_USER_SCRIPT_SANDBOXING = YES` by default for new targets, which *also* sandboxes Run Script phases — reading undeclared files outside the declared Input Files will fail with a `Sandbox: bash deny(1) file-read-data` error. For a solo, never-distributed app, the simplest fix is to set `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the app target (Build Settings → search "User Script Sandboxing" → No). The alternative — declaring the external dotenv path as an explicit Input File — is more "correct" but fiddly for a path outside `$(SRCROOT)`; not worth the friction for a single-developer non-distributed build.

**Concrete recipe:**

1. Target → Build Phases → `+` → New Run Script Phase. Drag it **above** "Compile Sources."
2. Build Settings → set `ENABLE_USER_SCRIPT_SANDBOXING` = `No` for this target.
3. Script body:
   ```bash
   ENV_FILE="$HOME/.config/keys/enrich.env"
   OUT="${SRCROOT}/VinylSetBuilder/Generated/Secrets.swift"
   mkdir -p "$(dirname "$OUT")"

   source "$ENV_FILE"   # exports DISCOGS_TOKEN etc. as shell vars

   cat > "$OUT" <<EOF
   // Generated at build time. Do not edit. Do not commit.
   enum Secrets {
       static let discogsToken = "${DISCOGS_TOKEN}"
       static let getSongBPMKey = "${GETSONGBPM_KEY}"
   }
   EOF
   ```
4. In the Run Script phase's "Input Files" / "Output Files" fields, list `$OUT` as an output (and the env file as input if sandboxing stays on) so Xcode's new build system knows to re-run the script when the source dotenv changes rather than on every build.
5. Add `VinylSetBuilder/Generated/Secrets.swift` to `.gitignore`. Commit nothing from this path — this is what makes the public-repo constraint in PROJECT.md work.

## 8. Xcode Project Layout: Single Target vs App + Local SPM Package

**Recommendation: App target (thin, SwiftUI + AVFoundation glue only) + one local SPM package (e.g. `VinylSetBuilderCore`) holding everything else.**

**Confidence: HIGH.** This is the same structure you already use for CrateDig (CrateDigCore SPM package + CrateDigMac app) — reuse it rather than inventing a new convention for this project.

**What goes where:**
- **App target:** `App` entry point, SwiftUI `View`s, the camera capture UIViewRepresentable/actor, wiring/navigation. Nothing here needs unit testing in isolation — it's thin glue.
- **`VinylSetBuilderCore` package:** SwiftData `@Model` types, the segmentation heuristics (§4 of MVP-SPEC — this is the part most worth TDD-ing against fixture text), the sequencer (beam search, Camelot distance, BPM gate — ported from CrateDig's Python logic per PROJECT.md context), the metadata resolver (Discogs/MusicBrainz/GetSongBPM clients + bounded-concurrency pipeline from §5), and the GRDB wrapper around bundled `library.db`.

**Why this split earns its keep here specifically:** your two hardest, most fixture-driven pieces — segmentation (Phase 2 ship criterion: "correct track count on 8/10 test labels") and the sequencer (Phase 4) — are exactly the kind of pure-logic-against-fixtures code that benefits most from `swift test` running natively on the macOS host process, rather than an app-target XCTest bundle that has to build and launch the full app/simulator on every run. This is a real, measured difference (a documented case reports up to 60x faster iteration moving equivalent tests from an app-target bundle to a package), and given you're iterating against golden fixture photos across multiple phases, that iteration-speed difference compounds. SwiftData itself is available and testable on macOS (the package's test host), so this split costs nothing on that front either.

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
| `RecognizeTextRequest` (new Swift Vision API) | Requires iOS 18.0+; deployment target is iOS 17+ | `VNRecognizeTextRequest` |
| SwiftData for the bundled `library.db` | Can't open a hand-built external SQLite file/schema | GRDB.swift with `configuration.readonly = true` |
| `@Relationship` to-many arrays as an ordering mechanism | Core Data backs it with `NSSet` — order is not guaranteed to survive a fetch | Plain `[UUID]`/scalar-array attributes, or an explicit `position: Int` field sorted at read time |
| SPM build-tool plugin for secrets generation | Sandboxed; can't read `~/.config/keys/enrich.env` outside the package | Xcode Run Script build phase with `ENABLE_USER_SCRIPT_SANDBOXING = No` |
| Semaphore/third-party concurrency package for the max-3 bound | Unneeded complexity — TaskGroup's pull model gives you the exact same bound natively | `withTaskGroup` seeded with `maxConcurrency` tasks, refilled one-in-one-out |
| Alamofire / any networking wrapper | Three simple REST GETs with query params and JSON bodies; URLSession + Codable is already the whole job | `URLSession` (already locked in PROJECT.md) |

## Stack Patterns by Variant

**If deployment target is later raised to iOS 18+:**
- Migrate OCR to `RecognizeTextRequest` for async/await ergonomics.
- Because the completion-handler/`VNImageRequestHandler` boilerplate goes away and it composes more naturally with the rest of your structured-concurrency pipeline — but this is a nice-to-have refactor, not a correctness fix.

**If `library.db` ever needs to be writable (e.g., caching resolved tracks back into it):**
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

---
*Stack research for: on-device iOS OCR + local-persistence + bounded-concurrency resolution app*
*Researched: 2026-08-29*
