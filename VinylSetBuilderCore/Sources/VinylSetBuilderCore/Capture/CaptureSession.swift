import Foundation

/// How well the sleeve READ. Not how well it resolved — resolution is a property of a track
/// and is shown on the crate screen, where a person is looking at tracks.
///
/// **`.reading` is CAP-01, made into a state rather than a spinner.** The shutter returns the
/// instant the photograph exists; recognition takes a beat longer and the tile says so. A
/// blocking wait would be the thing CAP-01 exists to forbid, and a spinner over the whole
/// screen would be the same wait wearing a hat.
public enum CaptureItemStatus: String, Sendable, Hashable, CaseIterable {
    case reading, read, partial, unread

    public var label: String {
        switch self {
        case .reading: return "Reading"
        case .read: return "Read"
        case .partial: return "Partial"
        case .unread: return "Unread"
        }
    }

    /// A verdict, as opposed to "the reader has not answered yet". Anything that tallies or
    /// scores a session has to be able to tell those apart.
    public var isVerdict: Bool { self != .reading }
}

/// One shutter press: the photograph's reference, what came off it, and what that means.
public struct CaptureItem: Identifiable, Sendable, Hashable {
    /// Becomes the `VinylEntry` id verbatim, so nothing has to be re-keyed later.
    public let id: UUID
    /// 1-based position in the thumbnail strip. `capture-thumb-{index}` uses it.
    public let index: Int
    /// `"IMG_0498.HEIC"` through Act I; a real image handle once Phase 10 lands (D-03-2).
    public let photoRef: String
    public let observations: [TextObservation]
    /// Normalised and de-duplicated. Hand-scored in Act I: deriving markers from raw text is
    /// SEG-04/SEG-06 and belongs to Phase 6 (D-03-4). Act I stores the answer.
    public let sideMarkers: [String]
    public let status: CaptureItemStatus
    /// OCR-02. The EXIF orientation the observations were read at, carried so the segmenter
    /// can be built with it instead of assuming the corpus's. `.right` is the default because
    /// all twelve of the owner's photographs are orientation 6, and a caller that genuinely
    /// does not know should say so by passing one rather than by leaving a field nil.
    public let orientation: PhotoOrientation

    public init(id: UUID = UUID(), index: Int, photoRef: String,
                observations: [TextObservation], sideMarkers: [String],
                status: CaptureItemStatus, orientation: PhotoOrientation = .right) {
        self.id = id
        self.index = index
        self.photoRef = photoRef
        self.observations = observations
        self.sideMarkers = sideMarkers
        self.status = status
        self.orientation = orientation
    }

    /// D-03-6 — the ONLY naming rule the capture screens use. Never the vinyl entry's own
    /// `label` property, which demands a resolved candidate and so renders "Vinyl N" for
    /// everything in Act I (defect V3, owner's call, tracked as U8).
    ///
    /// An all-whitespace reading is treated as no reading: a blank thumbnail label is a defect,
    /// not a name.
    ///
    /// **V12.** It takes the first trusted reading the SEG-03 noise filter KEEPS, not simply the
    /// first trusted reading. Text order out of the reader is spatial, not semantic, so whatever
    /// scrap sits highest-left on the sleeve arrives first — and on IMG_0503 that is `Zzz.`, a
    /// shard of a shop price sticker, which titled that record on three separate screens for the
    /// whole of Act I. The next kept reading is `Cause 4 Concern-`.
    ///
    /// The filter is shared with the segmenter on purpose: one definition of "not a track line",
    /// used by the thing that names records and by the thing that lists them.
    public var displayLabel: String {
        for observation in observations
        where TrackTextFilter.isTrusted(observation) && !TrackTextFilter.isNoise(observation.text) {
            let trimmed = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return photoRef
    }

    /// CAP-05, and this is the whole of its logic. One photograph of a flat sleeve commonly
    /// reads both sides (`A:` and `AA:`), and prompting there would nag on a quarter of the
    /// owner's collection.
    public var shouldPromptForFlip: Bool { sideMarkers.count < 2 }
}

/// CAP-03 — what has been shot so far in one visit to the capture screen.
public struct CaptureSession: Sendable, Equatable {
    public let crateID: UUID
    public private(set) var items: [CaptureItem] = []
    /// The item the inline flip prompt is currently about, if any. Always the most recent
    /// capture: a fresh shutter press supersedes whatever the last one was asking.
    public private(set) var pendingFlipPrompt: CaptureItem.ID?

    public init(crateID: UUID) {
        self.crateID = crateID
    }

    /// A freshly captured item has not been read yet, so it states no sides and cannot be
    /// asked about a flip. The prompt is raised by `replace(_:)` when the read lands.
    public mutating func append(_ item: CaptureItem) {
        items.append(item)
        pendingFlipPrompt = item.status.isVerdict && item.shouldPromptForFlip ? item.id : nil
    }

    /// CAP-01's other half: the read catches up with the shutter. The item keeps its id and
    /// its place in the strip; only what the reader learned about it changes.
    ///
    /// The flip prompt is decided HERE, because that is the first moment the sides are known.
    /// It is raised only for the LATEST capture — recognition is concurrent, so a slow read
    /// can land after two further shutter presses, and prompting about a record from three
    /// shots ago would be asking the wrong question about the wrong sleeve.
    public mutating func replace(_ item: CaptureItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        guard index == items.count - 1 else { return }
        pendingFlipPrompt = item.status.isVerdict && item.shouldPromptForFlip ? item.id : nil
    }

    /// Both "Scan the other side" and "Skip" clear it — the prompt is advisory, and the screen
    /// never blocks on it. Calling this with nothing pending is a no-op.
    public mutating func dismissFlipPrompt() {
        pendingFlipPrompt = nil
    }

    /// Keys with a zero count are absent, so the tally reads as what was actually shot.
    public var statusTally: [CaptureItemStatus: Int] {
        items.reduce(into: [:]) { tally, item in tally[item.status, default: 0] += 1 }
    }

    /// True once every capture has a verdict. A caller that wants to score a session has to
    /// wait for this, or it is scoring how fast the reader is.
    public var isFullyRead: Bool { items.allSatisfy { $0.status.isVerdict } }

    /// The handoff into the crate: one captured item becomes one vinyl entry whose candidate
    /// lines are whatever the supplied segmenter made of its text. Returns nil for an id this
    /// session does not hold.
    public func vinylEntry(for itemID: CaptureItem.ID,
                           segmenter: some LabelSegmenting) -> VinylEntry? {
        guard let item = items.first(where: { $0.id == itemID }) else { return nil }
        let segmentation = segmenter.segment(item.observations, vinylID: item.id, side: .a)
        return VinylEntry(id: item.id,
                          photoRefs: [item.photoRef],
                          candidates: segmentation.tracks.enumerated().map { offset, track in
                              var renumbered = track
                              renumbered.position = offset
                              return renumbered
                          },
                          position: item.index - 1,
                          catalogueNumber: segmentation.catalogueNumber)
    }
}
