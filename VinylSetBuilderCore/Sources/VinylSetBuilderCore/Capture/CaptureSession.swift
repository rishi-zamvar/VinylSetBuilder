import Foundation

/// D-03-5 — READ status, not resolution status. Nothing resolves in Act I; the resolver is
/// Phase 7 and extends this then. CAP-03 words it "resolution status"; the honest Act I
/// rendering is how well the sleeve read, and the divergence is written down in CONTEXT.md.
public enum CaptureItemStatus: String, Sendable, Hashable, CaseIterable {
    case read, partial, unread

    public var label: String {
        switch self {
        case .read: return "Read"
        case .partial: return "Partial"
        case .unread: return "Unread"
        }
    }
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

    public init(id: UUID = UUID(), index: Int, photoRef: String,
                observations: [TextObservation], sideMarkers: [String],
                status: CaptureItemStatus) {
        self.id = id
        self.index = index
        self.photoRef = photoRef
        self.observations = observations
        self.sideMarkers = sideMarkers
        self.status = status
    }

    /// D-03-6 — the ONLY naming rule the capture screens use. Never the vinyl entry's own
    /// `label` property, which demands a resolved candidate and so renders "Vinyl N" for
    /// everything in Act I (defect V3, owner's call, tracked as U8).
    ///
    /// An all-whitespace reading is treated as no reading: a blank thumbnail label is a defect,
    /// not a name.
    public var displayLabel: String {
        for observation in observations where observation.confidence >= 1.0 {
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

    public mutating func append(_ item: CaptureItem) {
        items.append(item)
        pendingFlipPrompt = item.shouldPromptForFlip ? item.id : nil
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
