# Phase 3 Context — The Capture & Correction Screens, Stubbed

**Written:** 2026-08-30, at planning time, from the measured record — not from the spec's
assumptions. Where the spec and the 12 real photographs disagree, the photographs win, and the
line below says so.

Act I, Phase 3. Depends on Phase 2 (closed, 5/5). Requirements in scope: **CAP-02, CAP-03,
CAP-05, CAP-06, OCR-04, SEG-07**.

**Explicitly out of scope: CAP-01 and CAP-04.** They are live-camera behaviours. The simulator
has no camera; they are Act III Phase 10's and no plan here may import them.

---

## 1. The five facts that decide every shape in this phase

All five are measured, not assumed. Sources: `.planning/research/OCR-SPIKE.md`,
`.local/ocr/ocr2_out.json` (12 records, 104 observations, real).

1. **They are SLEEVES, not labels.** Whole 12" sleeves photographed flat. The record label is a
   die-cut circle under 10% of frame. → **CAP-02's framing guide is square and covers most of
   the frame's shorter edge.** A label-sized reticle would be the wrong object.
2. **One photo commonly captures BOTH sides** (`A:` and `AA:`). → **CAP-05's prompt must be
   suppressed** when two sides were already read, or it nags on a quarter of the collection.
3. **Side markers are not `A`/`B`.** Real: `A:`, `AA:`, `SIDE A`, `Side One`, `COLD SIDE:`,
   `STEEL SIDE:`. Jungle 12"s use A/AA.
4. **Confidence is binary** — 1.00 / 0.50 / 0.30, nothing between. 88 of 104 observations were
   1.00. → the trusted tier is `conf >= 1.0`, not a fraction.
5. **Only 6 of 12 read cleanly.** White labels and dubplates are absent from every database.
   → **SEG-07 correction is a first-class path, not an error path. The sheet must be FAST.**

---

## 2. Locked decisions

Non-negotiable. Every plan implements these; no plan revisits them.

| ID | Decision |
|---|---|
| **D-03-1** | **Fixture data is generated from the real OCR run, never hand-invented.** `Scripts/generate-ocr-fixtures.sh` reads `.local/ocr/ocr2_out.json` and emits a committed `FixtureObservations.swift`. Every string, confidence, angle and bbox in Act I traces to a real photograph of one of the owner's records. |
| **D-03-2** | **No photograph bytes enter the repo.** The 12 HEICs stay in `~/Desktop/test/` and stay gitignored (public repo). The thumbnail strip's tile is a **rendered sleeve-shaped card** carrying the item's name and status, not an image view. `CaptureItem` carries a `photoRef: String` that Phase 10 populates with a real image handle; the tile takes an optional image that is `nil` for the whole of Act I. Recorded as informational in `VISUAL-DEFECTS.md`, not smuggled past a reader. |
| **D-03-3** | **One seam, `PhotoCapturing`, and it is `async`.** The fixture source and Phase 10's `AVCapturePhotoOutput` implement the same protocol. No UI is rewritten at the swap. There is **no artificial delay** — the "fake 1.5 s spinner" of MVP-SPEC §3 is dropped, because a timed transient is unphotographable after a mandatory 3 s settle and makes XCUITest flaky. Statuses are steady. |
| **D-03-4** | **Act I does not segment.** The Act I `LabelSegmenting` stub emits **one track line per trusted observation, in reading order.** No angle clustering, no marker splitting, no noise filtering — all of that is Phase 6's SEG-01…06/08 and inventing a second implementation here would be work Phase 11 deletes. The consequence is deliberate and useful: the draft arrives **over-split**, so the correction sheet's **merge** is exercised on the first tap against real data. |
| **D-03-5** | **The status the strip shows is READ status, not resolution status.** Nothing resolves in Act I; resolution is Phase 7. `CaptureItemStatus` is `.read` / `.partial` / `.unread`, scored per fixture from the spike's own verdicts. Phase 11 extends it when the resolver lands. CAP-03's wording says "resolution status"; the honest Act I rendering of that is read status, and the divergence is written down rather than papered over. |
| **D-03-6** | **V3 is carried forward, not fixed — and it is kept out of the new screens.** The capture strip and the inspect sheet name an item from **its own OCR text**, never via `VinylEntry.label` (which requires `.resolved` and would render "Vinyl N"). V3's product call is U8 and belongs to the owner + Phase 4; this phase does not preempt it. See §6. |
| **D-03-7** | **Every plan is `autonomous: true`.** No blocking gates, no resume signals. Anything needing a person goes to `.planning/UAT-PENDING.md` and the run continues. |

---

## 3. The fixture table — hand-scored from the real OCR, committed verbatim

This is the phase's ground truth. **Plan 03-01 commits it as data; plans 03-01 and 03-05 both
assert against it independently** (a Core unit test and an XCUITest — that is the two-observation
rule satisfied by construction, not by re-running the same check twice).

Fixture order is `ocr2_out.json`'s own order, which is ascending filename. Index is 1-based and
is what the strip's `capture-thumb-{n}` identifier uses.

| # | Fixture | Spike verdict | Status | Distinct side markers read | Flip prompt |
|---|---|---|---|---|---|
| 1 | IMG_0498 | clean | `.read` | — | **PROMPT** |
| 2 | IMG_0499 | clean | `.read` | `A`, `AA` | suppressed |
| 3 | IMG_0500 | partial | `.partial` | `ONE` (from `Gide One /` = "Side One") | **PROMPT** |
| 4 | IMG_0501 | partial | `.partial` | — | **PROMPT** |
| 5 | IMG_0502 | partial | `.partial` | — | **PROMPT** |
| 6 | IMG_0503 | clean | `.read` | `A`, `AA` (`SIDE A` + `A:` dedupe to one; `AAA:` is a misread `AA:`) | suppressed |
| 7 | IMG_0504 | clean | `.read` | — | **PROMPT** |
| 8 | IMG_0505 | clean | `.read` | — | **PROMPT** |
| 9 | IMG_0506 | clean | `.read` | `COLD`, `STEEL` | suppressed |
| 10 | IMG_0507 | fail | `.unread` | — | **PROMPT** |
| 11 | IMG_0508 | partial | `.partial` | — | **PROMPT** |
| 12 | IMG_0509 | partial | `.partial` | — | **PROMPT** |

**The two numbers this phase ships on:**

- **Status tally: 6 `.read` / 5 `.partial` / 1 `.unread`** — exactly the spike's 6 clean / 5
  partial / 1 fail. A different tally means the fixture wiring drifted from the measurement.
- **Flip prompt: fires on 9, suppressed on exactly {2, 6, 9}.** Not "fires sometimes" — a named
  set, asserted both ways.

**The rule, and it is the whole of CAP-05's logic:**

```
shouldPromptForFlip  ==  distinctSideMarkers.count < 2
```

`sideMarkers` is stored as a **hand-scored, normalised, de-duplicated** array on the fixture,
because deriving it from raw text is SEG-04/SEG-06 and belongs to Phase 6. Act I stores the
answer; Act II computes it. When Phase 6 lands, `sideMarkers` gets a producer and this rule does
not change.

---

## 4. Interfaces — frozen here so no executor has to go hunting

### Already on disk, unchanged, reused

```swift
// Domain/TextObservation.swift  — the input to everything in this phase
public struct TextObservation: Sendable, Hashable {
    public let text: String
    public let boundingBox: CGRect      // normalized [0,1]
    public let confidence: Float        // 1.0 | 0.5 | 0.3 — binary in practice
    public let baselineAngle: Double    // radians
}

// Domain/Track.swift
public struct Track: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID; public let vinylID: UUID
    public var side: Side; public var position: Int
    public var rawOCRText: String
    public var artist: String?; public var title: String?
    public var bpm: Double?; public var camelot: String?
    public var resolutionState: ResolutionState
    public var displayName: String      // artist — title, else rawOCRText, else "Unknown track"
}

// Domain/VinylEntry.swift        — `label` requires .resolved. That is defect V3. Do not call it
//                                  from any new screen (D-03-6).
// Segmentation/LabelSegmenting.swift
public protocol LabelSegmenting: Sendable {
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track]
}

// Crates/CrateStore.swift        — addVinyl(_:to:), addMore(to:), open(_:), crate(_:)
// Crates/Route.swift             — .crateList | .capture(crateID:) | .crateDetail(crateID:)
```

### Created by plan 03-01 (`VinylSetBuilderCore/Sources/VinylSetBuilderCore/Capture/`)

```swift
public struct FramingGuide: Sendable, Hashable {
    public let aspectRatio: Double        // 1.0 — a 12" sleeve is square
    public let insetFraction: Double      // fraction of the SHORTER preview edge, per side
    public var edgeCoverage: Double       // 1 - 2*insetFraction
    public static let sleeve: FramingGuide // aspectRatio 1.0, insetFraction 0.06 -> 0.88
}

public enum CaptureItemStatus: String, Sendable, Hashable, CaseIterable {
    case read, partial, unread            // D-03-5. NOT ResolutionState.
    public var label: String              // "Read" / "Partial" / "Unread"
}

public struct CaptureItem: Identifiable, Sendable, Hashable {
    public let id: UUID                   // == the VinylEntry id it will become
    public let index: Int                 // 1-based, strip position
    public let photoRef: String           // "IMG_0498.HEIC" in Act I; a real handle in Phase 10
    public let observations: [TextObservation]
    public let sideMarkers: [String]      // normalised, de-duplicated. Hand-scored in Act I.
    public let status: CaptureItemStatus
    public var displayLabel: String       // first trusted observation's text, else photoRef.
                                          // NEVER VinylEntry.label — that is V3 (D-03-6).
    public var shouldPromptForFlip: Bool  // sideMarkers.count < 2
}

public struct CaptureSession: Sendable, Equatable {
    public let crateID: UUID
    public private(set) var items: [CaptureItem]
    public private(set) var pendingFlipPrompt: CaptureItem.ID?
    public init(crateID: UUID)
    public mutating func append(_ item: CaptureItem)   // sets pendingFlipPrompt iff it should
    public mutating func dismissFlipPrompt()           // Skip AND Scan both clear it
    public var statusTally: [CaptureItemStatus: Int]
    public func vinylEntry(for itemID: CaptureItem.ID, segmenter: some LabelSegmenting) -> VinylEntry?
}

public protocol PhotoCapturing: Sendable {
    func capture() async -> CaptureItem?   // nil when the source is exhausted
}
```

### Created by plan 03-01 (`.../Fixtures/`)

```swift
public enum FixtureObservations {            // GENERATED — do not hand-edit
    public static let all: [(file: String, observations: [TextObservation])]  // 12 entries, 104 obs
}
public struct FixturePhotoSource: PhotoCapturing { // cycles the 12, wrapping past index 12
    public init(crateID: UUID)
}
public struct FixtureLineSegmenter: LabelSegmenting { } // D-03-4: one Track per trusted observation
```

### Created by plan 03-02 (`.../Correction/`)

```swift
public struct DraftLine: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var text: String
    public var isHandEdited: Bool
}

public struct SegmentationDraft: Sendable, Equatable {
    public let vinylID: UUID
    public private(set) var lines: [DraftLine]
    public init(vinylID: UUID, tracks: [Track])
    public mutating func splitLine(_ id: DraftLine.ID)          // at the word midpoint
    public mutating func mergeUp(_ id: DraftLine.ID)            // into the line above
    public mutating func setText(_ id: DraftLine.ID, to: String) // hand-type; sets isHandEdited
    public mutating func addLine()                              // a new empty hand-typed line
    public func tracks() -> [Track]                             // positions renumbered 0..n-1
}

public struct RawObservationRow: Identifiable, Sendable, Hashable {   // OCR-04
    public let id: Int            // 1-based, reading order
    public let text: String
    public let confidence: String // "1.00" / "0.50" / "0.30" — formatted once, en_US_POSIX
    public let isTrusted: Bool    // confidence >= 1.0 (spike finding 4)
}
public enum RawObservationRows {
    public static func make(_ observations: [TextObservation]) -> [RawObservationRow]
}
```

---

## 5. The frozen accessibility-identifier contract

**Never assert on a display string.** Every control the walk touches carries one of these. The
list is frozen at planning time so 03-03, 03-04 and 03-05 agree without negotiating.

**The trap, measured in Phase 2 and still live:** SwiftUI publishes some controls as **two**
elements. Always use a **typed** query — `app.buttons[id]`, `app.staticTexts[id]`,
`app.textFields[id]` — never `descendants(matching: .any)[id]`, which throws on a duplicate.

### Capture screen (`App/Views/CaptureView.swift`)

| Identifier | Element type | Requirement |
|---|---|---|
| `capture-crate-name` | staticText | (kept from Phase 2 — `CrateWalkUITests` asserts it) |
| `capture-framing-guide` | other | CAP-02 |
| `capture-shutter-button` | button | (replaces `capture-add-fixture-button`) |
| `capture-done-button` | button | CAP-06 (kept from Phase 2) |
| `capture-thumbnail-strip` | scrollView | CAP-03 |
| `capture-thumb-{n}` | button, 1-based **contiguous** | CAP-03 |
| `capture-thumb-status-{n}` | staticText, value is the status label | CAP-03 |
| `capture-session-count` | staticText | CAP-03 |
| `capture-flip-prompt` | other | CAP-05 |
| `capture-flip-scan-button` | button | CAP-05 |
| `capture-flip-skip-button` | button | CAP-05 |

### Inspect / correct sheet (`App/Views/InspectCorrectSheet.swift`)

| Identifier | Element type | Requirement |
|---|---|---|
| `inspect-sheet` | other | OCR-04 / SEG-07 |
| `inspect-title` | staticText | — |
| `inspect-close-button` | button | — |
| `inspect-raw-text-section` | button (disclosure) | OCR-04 |
| `inspect-raw-obs-{n}` | staticText, 1-based **contiguous** | OCR-04 |
| `inspect-line-{n}` | other, 1-based **contiguous** | SEG-07 |
| `inspect-line-field-{n}` | textField | SEG-07 (hand-type) |
| `inspect-split-{n}` | button | SEG-07 |
| `inspect-merge-up-{n}` | button | SEG-07 |
| `inspect-add-line-button` | button | SEG-07 |
| `inspect-apply-button` | button | SEG-07 |

**`{n}` families are 1-based and contiguous by construction.** That is load-bearing twice: it
lets a test count by walking upward until absent, and it makes `…-99` a real negative control.

---

## 6. V3 — inherited, live, and explicitly contained

**The defect:** the not-included bucket renders `Vinyl 2` for a record whose badges read `178`
and `6A`. `VinylEntry.label` requires `resolutionState == .resolved`; `SequencedRow.title` does
not; **no fixture `Track` is ever `.resolved`.** Evidence: `02-walk-07-not-included-expanded.png`.
Severity Medium. Owner: Phase 4. Product call: U8, and it is **the owner's**, not this phase's.

**What this phase does about it — three things, all deliberate:**

1. **Does not fix it.** Two defensible fixes exist (mark fixtures `.resolved`, or let
   `VinylEntry.label` fall back to the first candidate's `displayName` the way `Track.displayName`
   already does). Choosing is a product call the owner has been asked to make. Preempting it
   would waste the question.
2. **Does not let it into the new screens.** `CaptureItem.displayLabel` and every sheet title
   name an item from **its own trusted OCR text**. `VinylEntry.label` is not called from
   `CaptureView` or `InspectCorrectSheet`. Plan 03-05 asserts this two ways: a grep gate, and a
   UI assertion that no `capture-thumb-{n}` label matches `^Vinyl \d+$` while its item has
   readable text.
3. **Photographs it where it genuinely does still appear, and says so.** CAP-06's Done lands on
   the crate detail. The vinyls the capture loop just added carry OCR text but no BPM, so they
   land in the not-included bucket — labelled "Vinyl N". That frame is captured, and it goes
   into `VISUAL-DEFECTS.md` as a **second, independent piece of V3 evidence** on a screen that
   did not exist when V3 was found. That strengthens U8 rather than hiding it.

**A free win, recorded so it is not mistaken for luck:** the same "no BPM" property means the
new crate's running order is genuinely **empty** after the shutter, which finally exercises and
photographs `empty-running-order` — **closing the V7 coverage gap** that Phase 2 recorded as
un-photographed.

---

## 7. Traps, each one paid for already

| Trap | The rule |
|---|---|
| **Core purity is a SUBSTRING scan** | `AVFoundation`, `Vision`, `UIKit`, `AppKit`, `SwiftUI`, `SwiftData`, `URLSession`, `URLRequest`, `URLProtocol` must not appear anywhere in `VinylSetBuilderCore/Sources/` — **including doc comments**. The generator in 03-01 emits OCR text into a Core file, so it **must assert its own output is clean** before writing. (Checked at planning time against all 104 real strings: no banned token. The check exists so that stays true.) |
| **`Array.move(fromOffsets:toOffset:)` is SwiftUI, not Foundation** | Not reachable from Core. `SegmentationDraft` needs no reordering, so it needs no equivalent; if one is ever wanted, `CrateDetailModel.moved(_:fromOffsets:toOffset:)` is the hand-rolled precedent. |
| **Screenshot count gates pass on leftovers** | `find Artifacts/screenshots -name '<your-glob>' -delete` **before** the run, every time. |
| **Settle ≥ 3 s, and confirm foreground** | Everything goes through `ScreenshotRecorder.capture`. Never call `XCUIScreen.main.screenshot()` directly. |
| **`Scripts/collect-screenshots.sh` copies the CURRENT container** | Running it without a preceding `ui-test.sh` silently re-copies the previous run's PNGs and they look like fresh evidence. |
| **Two elements per control** | Typed queries only. |
| **Phase 2's walk taps `capture-add-fixture-button`** | That button dies with `CapturePlaceholderView`. Plan 03-03 owns repairing `CrateWalkUITests` and re-running it green. Phase 2's 15 states are re-captured, not abandoned. |

---

## 8. The two disciplines, made concrete for this phase

**Every behavioural claim needs ≥ 2 independent observations, and the summary must say how many
times it was measured.** Two plans in a row published confident wrong conclusions from a single
sample. Where this phase makes a claim, the second observation is named in advance:

| Claim | Observation A | Observation B |
|---|---|---|
| The flip prompt fires on 9 fixtures and is suppressed on {2, 6, 9} | Core unit test over `FixturePhotoSource` (03-01) | XCUITest counting real prompts across a 12-shot session (03-05) |
| The status tally is 6 / 5 / 1 | Core `statusTally` test (03-01) | XCUITest reading `capture-thumb-status-{n}` labels (03-05) |
| Merge and split round-trip the line set | Core unit test (03-02) | XCUITest tapping the real buttons and counting `inspect-line-{n}` (03-05) |
| No frame carries the V2 pallor signature | Pillow probe on the 03-05 run | Pillow probe re-run after purge, per the V2 protocol |

**A passing test must be provably able to fail.** Required negative controls, by name:

- `capture-thumb-99` and `inspect-line-99` must **not** resolve. If they do, every `{n}`-family
  count in this phase is matching something other than what it names.
- Every count assertion is **two-sided**: the expected element exists **and** the one past the
  end does not. `contains("1 record")` is also true of `"1 records"` — that is exactly how V1
  survived a green test once.
- `FramingGuide` is asserted **sleeve-sized and not label-sized** in one test: `sleeve.edgeCoverage
  > 0.6` **and** a constructed label-sized guide (`insetFraction: 0.45`) `< 0.6`. Without the
  second half the assertion cannot discriminate and would pass on a reticle.
- `SegmentationDraft.splitLine` on a single-word line is a **no-op**, and a test asserts that
  explicitly rather than assuming it.

---

## 9. What goes to the owner instead of blocking

Appended to `.planning/UAT-PENDING.md` by plan 03-05. Nothing here stops the run.

| # | Check | Why a person is needed |
|---|---|---|
| U9 | **Is the correction sheet actually fast?** SEG-07 exists because 6 of 12 records will never resolve automatically. "Fast" is a stopwatch-and-thumb judgement on the sheet's real layout, and the DJ's own workflow decides whether merge-up + split + hand-type are the right three operations. |
| U10 | **Does the sleeve framing guide frame a real sleeve on a real counter?** The simulator has no camera, so `edgeCoverage 0.88` is verified as geometry, never against an actual 12" sleeve at arm's length. Phase 10 with a live `AVCaptureSession` is where this becomes answerable. |
| U8 | (already open) The V3 product call. Phase 3 adds a second screenshot as evidence and changes nothing else. |

---

## 10. Plans and waves

| Wave | Plan | What | Requirements |
|---|---|---|---|
| 1 | **03-01** | Capture Core: real-OCR fixture generator, `FramingGuide`, `CaptureItem`/`CaptureSession`, the flip rule, the `PhotoCapturing` seam, `FixtureLineSegmenter` | CAP-02, CAP-03, CAP-05 |
| 1 | **03-02** | Correction Core: `SegmentationDraft` (split / merge-up / hand-type / add) and `RawObservationRows` | OCR-04, SEG-07 |
| 2 | **03-03** | The capture screen: framing guide, shutter, thumbnail strip with status, inline flip prompt, Done — and repairing Phase 2's walk | CAP-02, CAP-03, CAP-05, CAP-06 |
| 3 | **03-04** | The inspect / correct sheet, presented from a thumbnail tap | OCR-04, SEG-07 |
| 4 | **03-05** | The 12-fixture session walk, the 21-item scroll test, every state photographed, the visual audit and the ship-criterion audit | all six |

03-01 and 03-02 are genuinely independent: 03-02 needs only `TextObservation` and `Track`, both
already on disk, and its unit tests construct their own minimal inputs rather than depending on
the 104-row fixture blob. Waves 2–4 are a real chain — the sheet is presented **by** the capture
screen, and the walk needs both — so no parallelism is claimed where none exists.
