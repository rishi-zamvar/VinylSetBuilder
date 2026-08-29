# Architecture Research

**Domain:** On-device iOS scanner + optimizer (camera → OCR → deterministic segmentation → networked metadata resolution → offline constrained-search sequencing → SwiftData persistence), single-user, no server.
**Researched:** 2026-08-29
**Confidence:** HIGH for Swift/SwiftUI/Vision/SwiftData/Concurrency mechanics (stable, well-documented iOS 17 APIs, verified against Apple docs and current community sources). MEDIUM for the specific orchestration/threading design below — it is my synthesis for this spec, not a single canonical reference pattern; flagged where invented.

## Verdict on the Spec's Component Split (§4, §5)

**The split is correct. Ship it as specced, with three refinements, not restructures.**

1. **§4 Segmentation is correctly its own component, separate from OCR.** Vision gives you observations; deciding which observations form a track is a distinct algorithm with its own heuristics (radial clustering, marker parsing, parenthetical merging) that has nothing to do with recognizing text. Keeping OCR and segmentation as two protocol seams (not one "scan a label" mega-function) is exactly right and is what makes segmentation unit-testable without a camera.

2. **One gap worth naming: segmentation's radial-clustering heuristic (§4 step 3) is implicitly coupled to Phase 1's capture-guide overlay.** "Cluster by distance from label center" only works if the photo is framed so the label center ≈ image center — that assumption is enforced by the UI (the framing guide), not by segmentation itself. Don't smuggle this into segmentation as a hidden constant; document it as a stated convention (image center = normalized `(0.5, 0.5)`, matching Vision's own normalized bounding-box coordinate space) so a test can deliberately feed an off-center fixture and see the heuristic degrade predictably rather than silently.

3. **§5 Sequencer is correctly a stateless pure function, and "full re-optimization, not incremental" is the right call, not a shortcut.** It removes an entire class of incremental-diffing bugs (stale exclusion state, partial re-admittance logic) at the cost of a beam search that DECISIONS.md already confirms runs in milliseconds at this scale (<100 vinyls, <400 candidates). Do not build incremental sequencing. Agree with DECISIONS.md #5 (beam search width 50, no exact DP).

4. **BPM/key lookup is correctly NOT a separate top-level phase/component.** §6's pipeline folds it into Metadata Resolution, which is right — from the UI's perspective there is one thing that turns raw OCR text into a resolved track, and BPM/key is just one more field that pipeline fills. It should still be its own internally-composable step (see Protocol Seams below) so Phase 3 can test the BPM/key lookup and the identity lookup (artist/title match) independently, but the roadmap should not carry it as a separate phase.

One build-order suggestion beyond the phase *content* (see Build Order section): pull early, low-risk development of the Sequencer forward, because it has zero dependency on segmentation/resolution and is a direct port of already-working Python.

## System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              SwiftUI Views                                │
│   CratesListView · CaptureView · ThumbnailStripRow · SequencedListView    │
└───────────────────────────────┬────────────────────────────────────────--┘
                                 │ observes (@Observable)
┌───────────────────────────────▼──────────────────────────────────────────┐
│                     CrateSession (@MainActor @Observable)                 │
│  owns: [VinylEntry] (in-memory session state), triggers resequence        │
└───────┬───────────────┬────────────────┬───────────────┬──────────────---┘
        │ per capture    │ per candidate  │ debounced      │ on Done/AddMore
        ▼                ▼                ▼                │
┌───────────────┐ ┌─────────────┐ ┌──────────────────┐    │
│ LabelCapturing │ │LabelTextReco│ │ LabelSegmenting   │    │
│ (AVFoundation) │→│ (Vision)    │→│ (pure geometry)   │    │
└───────────────┘ └─────────────┘ └─────────┬─────────┘    │
                                              │ [Track] (pending)
                                              ▼                │
                                   ┌─────────────────────┐    │
                                   │ MetadataResolving    │    │
                                   │ (ladder-composed,    │    │
                                   │  bounded concurrency)│    │
                                   └──────────┬───────────┘    │
                                              │ [Track] (resolved/failed)
                                              ▼                ▼
                                   ┌─────────────────────────────┐
                                   │        Sequencing            │
                                   │   (pure fn, off-main Task)   │
                                   └──────────────┬───────────────┘
                                                  │ SequenceResult
                                                  ▼
                                   ┌─────────────────────────────┐
                                   │  SwiftData (Crate/VinylEntry/│
                                   │  Track @Model + cache table) │
                                   └─────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Depends on |
|-----------|----------------|------------|
| `LabelCapturing` | Own `AVCaptureSession`, emit a `CGImage` per shutter press, return immediately | Nothing |
| `LabelTextRecognizing` | Wrap `VNRecognizeTextRequest(.accurate)`, convert `VNRecognizedTextObservation` → plain `TextObservation` DTO | Nothing (Vision only) |
| `LabelSegmenting` | Pure geometry: `[TextObservation] → [Track]` (candidates, unresolved) per §4 | Nothing — plain structs in, plain structs out |
| `MetadataResolving` | `Track (pending) → Track (resolved/failed/manual)`, composes the resolution ladder internally | Network, bundled DB, cache |
| `Sequencing` | Pure fn: `[Track] → SequenceResult` per §5 | Nothing — Track model only |
| `CrateSession` | Orchestration: owns in-flight capture state, fans OCR→segmentation→resolution per photo, bounds concurrency, debounces resequence | All protocols above (injected) |
| Persistence (SwiftData) | `Crate`/`VinylEntry`/`Track` `@Model` classes + `CachedResolution` table | Nothing — last to depend on stable domain shape |
| SwiftUI Views | Render `CrateSession`'s `@Observable` state, dispatch user actions | `CrateSession` only |

## Recommended Project Structure

```
VinylSetBuilder/
├── VinylSetBuilderCore/            # Swift Package: zero UIKit/SwiftUI/AVFoundation imports where possible
│   ├── Sources/
│   │   ├── Domain/                 # Plain Sendable structs: Track, VinylEntry, Crate, SequenceResult
│   │   ├── Segmentation/           # LabelSegmenting protocol + GeometricLabelSegmenter (pure, §4)
│   │   ├── Sequencing/             # Sequencing protocol + BeamSearchSequencer (pure, §5)
│   │   ├── Resolution/             # MetadataResolving protocol + LadderMetadataResolver
│   │   │   ├── Sources/BundledLibrarySource.swift   # tier 0: library.db
│   │   │   ├── Sources/CacheSource.swift            # tier 1: SwiftData cache
│   │   │   ├── Sources/MusicBrainzSource.swift      # tier 2
│   │   │   ├── Sources/DiscogsSource.swift          # tier 3
│   │   │   └── Sources/BPMKeySource.swift           # GetSongBPM, composed alongside identity lookup
│   │   ├── Vision/                 # LabelTextRecognizing protocol + VisionTextRecognizer
│   │   └── Fixtures/               # Stub implementations (FixtureMetadataResolver, NaiveBPMSortSequencer)
│   └── Tests/
│       ├── SegmentationTests/      # fixture TextObservation JSON → assert Track counts (NO Vision, NO image)
│       ├── SequencingTests/        # fixture Track arrays → assert SequenceResult (NO network)
│       └── ResolutionTests/        # URLProtocol-mocked network, one test target per ResolutionSource
├── VinylSetBuilderApp/             # App target: SwiftUI + AVFoundation + SwiftData
│   ├── Capture/                    # LabelCapturing (AVCaptureSession) — needs a device, not unit-testable
│   ├── Session/                    # CrateSession (@MainActor @Observable orchestrator)
│   ├── Persistence/                # @Model Crate/VinylEntry/Track, ModelContainer setup
│   └── Views/                      # SwiftUI screens
└── Tests/Fixtures/Labels/          # golden real-label photos + frozen OCR-output JSON (see Build Order)
```

### Structure Rationale

- **`VinylSetBuilderCore` as a separate Swift Package is the single highest-leverage structural decision here.** Segmentation and Sequencing (the two things the question asks to unit-test with no camera and no network) physically cannot import `AVFoundation` or `URLSession`-dependent app code if they live in a package that doesn't link those frameworks for its test target. This is a compile-time enforcement of the testability requirement, not just a convention — stronger than "please don't call the network from this class."
- **`Fixtures/` inside Core, not inside the app target.** Phase 0's stub `MetadataResolver`/`Sequencer` are real, shippable, protocol-conforming types — they belong in the library so Phase 0's UI target links against the exact same protocol the real implementation will satisfy later. Swapping is a one-line dependency-injection change, not a rewrite.
- **`Resolution/Sources/` as internal `ResolutionSource` implementations, not separate top-level phases.** Matches the verdict above — one public seam, several independently-testable internal tiers.

## Protocol Seams (Concrete Signatures)

These four protocols are the entire public surface Phase 0 needs. Everything else (camera, Vision, networking, SwiftData) sits behind them.

```swift
// MARK: - Domain (plain, Sendable, no framework imports)

enum Side: Sendable { case a, b }

enum ResolutionState: Sendable {
    case pending, resolved, failed, manual
}

struct Track: Identifiable, Sendable, Hashable {
    let id: UUID
    let vinylID: UUID
    var side: Side
    var position: Int
    var rawOCRText: String
    var artist: String?
    var title: String?
    var bpm: Double?
    var camelot: String?
    var matchConfidence: Double
    var resolutionState: ResolutionState
    var failureReason: String?          // "no track within 4 BPM" / "not found in Discogs" — DECISIONS.md #4: one bucket
}

struct TextObservation: Sendable {
    let text: String
    let boundingBox: CGRect             // normalized [0,1], Vision's own convention. Label center is (0.5, 0.5) BY CONVENTION.
    let confidence: Float
}

struct SequenceResult: Sendable {
    let sequence: [Track]                              // ordered, one per vinyl, ascending BPM
    let notIncluded: [(vinylID: UUID, reason: String)]  // one bucket, per DECISIONS.md #4
}

// MARK: - Protocol seams

protocol LabelTextRecognizing: Sendable {
    func recognizeText(in image: CGImage) async throws -> [TextObservation]
}

protocol LabelSegmenting: Sendable {
    /// Pure function. No I/O. Label center assumed at (0.5, 0.5) in the observations' normalized space.
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track]
}

protocol MetadataResolving: Sendable {
    /// Takes a .pending Track, returns it with resolved fields filled or resolutionState set to .failed.
    func resolve(_ track: Track) async -> Track
}

protocol Sequencing: Sendable {
    /// Pure function. Fully re-derives the sequence from scratch every call — no memory of prior runs.
    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult
}
```

**Phase 0 stubs** (ship on day one, live in `Fixtures/`):

```swift
struct FixtureMetadataResolver: MetadataResolving {
    func resolve(_ track: Track) async -> Track {
        try? await Task.sleep(for: .seconds(1.5))     // spec: "fake 1.5s delay"
        var t = track
        t.artist = "Fixture Artist"; t.title = "Fixture Title"
        t.bpm = 174; t.camelot = "8A"; t.resolutionState = .resolved
        return t
    }
}

struct NaiveBPMSortSequencer: Sequencing {
    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        let resolved = candidates.filter { $0.bpm != nil }.sorted { $0.bpm! < $1.bpm! }
        return SequenceResult(sequence: resolved, notIncluded: [])
    }
}
```

Swapping `FixtureMetadataResolver` for `LadderMetadataResolver` and `NaiveBPMSortSequencer` for `BeamSearchSequencer` in Phase 3/4 is a dependency-injection change at `CrateSession`'s init site. Nothing in `Views/` or `CrateSession`'s orchestration logic changes, because both conform to the same protocol.

**Internal composition of `MetadataResolving`** (Phase 3, not part of the public seam):

```swift
protocol ResolutionSource: Sendable {
    /// Returns whatever fields this tier can fill, or nil if it has nothing.
    func lookup(artist: String?, title: String, rawText: String) async -> PartialResolution?
}

struct LadderMetadataResolver: MetadataResolving {
    let sources: [ResolutionSource]   // ordered: bundled DB, cache, MusicBrainz, Discogs, GetSongBPM

    func resolve(_ track: Track) async -> Track {
        var result = track
        for source in sources {
            if let partial = await source.lookup(artist: result.artist, title: result.title ?? "", rawText: result.rawOCRText) {
                result.merge(partial)                    // fills only nil fields, never overwrites a higher-priority hit
                if result.isFullyResolved { result.resolutionState = .resolved; return result }
            }
        }
        result.resolutionState = .failed
        result.failureReason = "not found in any source"
        return result
    }
}
```

Each `ResolutionSource` is independently unit-testable with `URLProtocol`-mocked responses — no live network in the default test suite, matching the project's existing convention (see `LiveSoundCloud`-style filtered live tests elsewhere in this account's projects) of gating real-network tests behind an explicit flag/filter.

## Background Per-Item Resolution (the "never blocks" requirement)

**Recommended shape: one `@MainActor @Observable` orchestrator (`CrateSession`) holding session state, one unstructured `Task` per captured photo, one bounded-concurrency worker for the network-bound resolution stage only.**

```swift
@MainActor @Observable
final class CrateSession {
    private(set) var vinyls: [VinylEntry] = []
    private var inFlight: [UUID: Task<Void, Never>] = [:]   // keyed by VinylEntry.id, cancellable

    let capture: LabelTextRecognizing
    let segmenter: LabelSegmenting
    let resolver: MetadataResolving
    let sequencer: Sequencing

    func didCapture(_ image: CGImage, into vinylID: UUID, side: Side) {
        // 1. Synchronous, instant: append entry in .pending state. UI gets its spinner row NOW.
        // 2. Shutter has already returned — this method itself must do no awaiting before returning to the caller.
        inFlight[vinylID] = Task {
            let observations = try? await capture.recognizeText(in: image)
            let tracks = segmenter.segment(observations ?? [], vinylID: vinylID, side: side)
            await resolveAll(tracks, into: vinylID)         // hands off to the bounded resolution queue
        }
    }

    private func resolveAll(_ tracks: [Track], into vinylID: UUID) async {
        await withTaskGroup(of: Track.self) { group in
            var iterator = tracks.makeIterator()
            var running = 0
            func addNext() {
                guard let track = iterator.next() else { return }
                group.addTask { await self.resolver.resolve(track) }
                running += 1
            }
            for _ in 0..<min(3, tracks.count) { addNext() }   // spec: Discogs max 3 concurrent
            while let resolved = await group.next() {
                running -= 1
                updateTrack(resolved, in: vinylID)            // main-actor hop is implicit: CrateSession is @MainActor
                if running < 3 { addNext() }
                scheduleResequence()                          // debounced — see below
            }
        }
    }
}
```

This is the standard "seed N workers, refill on `group.next()`" TaskGroup throttling idiom — it needs no third-party dependency and no manual semaphore/actor. `CrateSession` being `@MainActor` means every state mutation from inside these `Task`s is automatically main-actor-isolated on `await`, which is exactly what SwiftUI's `@Observable` needs to safely drive list updates — no `DispatchQueue.main.async` anywhere.

**Per-item live status in the list:** don't add a separate stored status enum on `VinylEntry`. Derive it from the `Track`s it owns:

```swift
extension VinylEntry {
    var displayState: ResolutionState {
        if tracks.isEmpty { return .pending }
        if tracks.contains(where: { $0.resolutionState == .pending }) { return .pending }  // still resolving → spinner
        return .resolved   // or worst-case among tracks, if you want partial-failure styling
    }
}
```

One derived property, no duplicated state to keep in sync — the SwiftUI row just reads `vinyl.displayState`.

**Cancellation:** deleting a scanned item before it resolves cancels `inFlight[vinylID]`. This is why the dictionary-of-`Task`s shape is preferable to a single shared `TaskGroup` spanning the whole capture session — a `TaskGroup` requires structured completion of all its children together, which doesn't fit "user can delete item #3 while items #1, #2, #4 are still resolving."

## Sequencer Placement and Threading

**The sequencer is a pure, stateless, synchronous function. It does not need an actor of its own — it needs to be called from a background context.**

```swift
struct BeamSearchSequencer: Sequencing {
    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        // §5 procedure: sort by BPM, build DAG, beam search width 50, one track per vinylID.
        // Synchronous. No await inside. Safe to call from any thread because it touches no shared state.
    }
}
```

Call it off-main explicitly, even though at this scale (<100 vinyls) it likely finishes in low single-digit milliseconds — never assume that holds as the crate grows, and never let a CPU-bound loop run inline on the actor driving the UI:

```swift
func scheduleResequence() {
    resequenceTask?.cancel()
    resequenceTask = Task {
        try? await Task.sleep(for: .milliseconds(400))   // debounce: many resolutions can land in a burst
        guard !Task.isCancelled else { return }
        let allTracks = vinyls.flatMap(\.candidates)
        let result = await Task.detached(priority: .userInitiated) {
            self.sequencer.sequence(candidates: allTracks, bpmTolerance: self.bpmTolerance)
        }.value
        self.currentSequence = result       // back on @MainActor automatically (awaited on CrateSession)
    }
}
```

**Trigger rule** (this is a design decision the spec states loosely — "runs on Done and on every subsequent add" — and I'm making it precise): trigger a debounced resequence on (1) the Done button, (2) Add More's own eventual Done, and (3) **any individual track transitioning to `.resolved`/`.failed` once the crate has been sequenced at least once.** Rationale: resolution is async and slower than the beam search; if a track's Discogs lookup lands three seconds after Done was tapped, the sequence should reflect it without requiring another explicit user action — this is what "re-optimise on every record added, including readmitting previously excluded records" implies once you account for the fact that adding a record doesn't mean its data has resolved yet. The 400ms debounce absorbs the burst of near-simultaneous completions from the bounded-concurrency resolver so you don't beam-search on every single completion in a batch of 20.

## Data Flow and the Caching Boundary

```
CGImage (capture)
  │  LabelTextRecognizing
  ▼
[TextObservation]  (plain DTO — this is the point where Vision's types stop existing)
  │  LabelSegmenting (pure)
  ▼
[Track] state=.pending  (candidates, ALL kept — spec: "All candidate tracks stay cached even when unselected")
  │  MetadataResolving (async, ladder-composed)
  ▼
[Track] state=.resolved | .failed  (bpm/camelot/artist/title filled where possible)
  │  Sequencing (pure, full re-run, debounced)
  ▼
SequenceResult { sequence: [Track], notIncluded: [(vinylID, reason)] }
  │  persisted as Crate.sequence: [TrackID] + VinylEntry.selectedTrack
  ▼
SwiftData (Crate / VinylEntry / Track @Model)
```

**The caching boundary is entirely inside `MetadataResolving`, invisible to segmentation, sequencing, and UI.** Two caches, both behind the ladder, in priority order:

1. **Tier 0 — bundled read-only `library.db`** (the pruned `walkman-dj` SQLite, 7,010 rows with `(artist, title, bpm, camelot)`). Query directly via SQLite3 C API or a thin read-only wrapper — this is reference data, not app state, so it does not belong in the SwiftData store. Zero network, zero latency, ships in the bundle.
2. **Tier 1 — persisted resolution cache**, a `CachedResolution` SwiftData table keyed on the same normalized string the Discogs match already computes: `normalize(artist) + "|" + normalize(title)`. This must survive app restart and be shared across crates — the spec explicitly allows the same vinyl to appear in multiple crates, and a second scan of a record you already resolved should hit this cache before ever touching the network again. This is the frugality ladder from the project's own stated principle (cache before any free-unlimited or free-limited API call).
3. **Tiers 2+ — MusicBrainz, then Discogs, then GetSongBPM** as `ResolutionSource` implementations, called only when tiers 0–1 miss.

Segmentation and Sequencing never see cache, network, or SwiftData — they operate purely on in-memory `Track`/`TextObservation` value types. This is what makes them testable with fixture data and no camera/no network: there is no seam to mock because there is nothing to mock.

## Anti-Patterns to Avoid Here

### Anti-Pattern 1: A `CrateStore` protocol for SwiftData

**What people do:** wrap `ModelContext` behind a custom protocol "for testability," mirroring a repository pattern from server-side code.
**Why it's wrong:** SwiftData already ships the testability primitive you'd be reinventing — `ModelConfiguration(isStoredInMemoryOnly: true)` gives you a fast, isolated, real `ModelContainer` for tests with zero custom abstraction. A hand-rolled store protocol adds a translation layer between `@Model` objects and your domain structs that this single-user, no-backend-swap app will never need.
**Do this instead:** use `@Model` classes directly (`Crate`, `VinylEntry`, `Track`), and for persistence-layer tests, build an in-memory `ModelContainer` instead of mocking a protocol.

### Anti-Pattern 2: Coupling Segmentation to `VNRecognizedTextObservation`

**What people do:** pass Vision's own observation type straight into the segmentation function because "it's right there."
**Why it's wrong:** you cannot construct a `VNRecognizedTextObservation` by hand in a unit test (Apple gives you no public initializer with realistic geometry), so this silently makes segmentation untestable without running Vision on a real image — defeating the entire "fixture images, no camera" requirement in the question.
**Do this instead:** convert to the plain `TextObservation` struct immediately inside the `LabelTextRecognizing` implementation, before it ever reaches segmentation. Freeze real Vision output from the golden fixture photos into committed JSON once (end of Phase 1); segmentation tests load that JSON forever after and never invoke Vision again.

### Anti-Pattern 3: A shared `TaskGroup` spanning the whole capture session

**What people do:** one big `withTaskGroup` that all captured photos feed into, awaited once at "Done."
**Why it's wrong:** `TaskGroup` requires you to await all children as a structured unit; it doesn't support "cancel just this one item the user deleted" or "some items still resolving while I navigate away and come back" cleanly.
**Do this instead:** one independent, cancellable `Task` per captured item, tracked in a `[UUID: Task<Void, Never>]` dictionary on the session object; use `TaskGroup` only inside the bounded-concurrency resolution step for a single item's candidate tracks, where structured "wait for these N, in this scope" semantics are actually correct.

## Build Order

Dependency-driven, and it validates the spec's own phase order with one addition:

1. **Domain models + all four protocols** (`Track`, `VinylEntry`, `Crate`, `SequenceResult`, `TextObservation`, `LabelTextRecognizing`, `LabelSegmenting`, `MetadataResolving`, `Sequencing`). Zero dependencies. Do this before Phase 0 UI work starts, not as part of it.
2. **Phase 0 — UI shell + fixture stubs + real `CrateSession` orchestration** (the background-resolution/debounce/cancellation machinery described above, wired against the *stub* resolver and sequencer). Building the real orchestration now — not deferred to Phase 3/4 — is what actually proves the protocol seams work; there is nothing left to change in `CrateSession` or any View when the real implementations swap in later.
3. **Sequencer (§5) can be built and fully unit-tested in parallel with Phase 1/2**, ahead of its Phase 4 ship slot. It has zero dependency on segmentation or resolution — only on the `Track` struct shape — and it's a direct, already-validated port from the existing CrateDig Python beam search. Pulling it forward de-risks the one genuinely nontrivial algorithm in the app while the schedule's critical path is elsewhere (camera hardware, OCR tuning, API integration). The Phase 4 *ship* checkpoint (wired into the real UI flow) can stay where the spec puts it; the *implementation and test-suite* work does not need to wait.
4. **Phase 1 — Camera + Vision OCR**, as specced. At the end of this phase, run the OCR wrapper once over all 10 golden fixture photos and commit the `[TextObservation]` output as JSON fixtures. This is the step that makes Phase 2 possible without a camera.
5. **Phase 2 — Segmentation (§4)**, tested purely against the frozen JSON from step 4. No image, no Vision call, no camera in the test suite from this point forward.
6. **Phase 3 — Metadata Resolution**, built as `LadderMetadataResolver` composing independent `ResolutionSource` tiers (bundled DB, cache, MusicBrainz, Discogs, GetSongBPM), each tested with `URLProtocol`-mocked responses. The bundled `library.db` tier and the SwiftData cache tier have no external dependency and can be built first within this phase; live-network tests go behind an explicit flag, consistent with this account's existing convention for live integration tests elsewhere.
7. **Phase 4 — Sequencer ship checkpoint**: wire the already-built-and-tested `BeamSearchSequencer` from step 3 into the real UI flow, replacing `NaiveBPMSortSequencer`.
8. **Phase 5 — Persistence**, last, because it's the one component whose implementation is dictated by the final shape of `Track`/`VinylEntry`/`Crate` — those need to be stable before writing `@Model` mappings and migrations.

## Sources

- Apple Developer Documentation: [`ModelConfiguration.init(for:isStoredInMemoryOnly:)`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(for:isstoredinmemoryonly:)) — confirms in-memory `ModelContainer` for testing, HIGH confidence.
- WWDC23: [Beyond the basics of structured concurrency](https://developer.apple.com/videos/play/wwdc2023/10170/) — TaskGroup/throttling patterns, HIGH confidence.
- Swift Forums: [Understanding Task Groups and the limits in creating concurrent tasks](https://forums.swift.org/t/understanding-task-groups-and-the-limits-in-creating-concurrent-tasks/73500) — confirms no built-in throttle, seed-and-refill idiom is the community-standard workaround, MEDIUM confidence (community consensus, not an Apple API guarantee).
- Project docs read directly: `.planning/PROJECT.md`, `docs/MVP-SPEC.md`, `docs/DECISIONS.md` — primary source for all domain/model/algorithm specifics in this document.
- Vision framework `VNRecognizedTextObservation.boundingBox` normalized coordinate convention — HIGH confidence from training data (stable, unchanged API since iOS 11), not independently re-verified this session; low risk given API stability.

---
*Architecture research for: on-device iOS scanner/sequencer (VinylSetBuilder)*
*Researched: 2026-08-29*
