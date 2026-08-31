import Foundation

public struct Track: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public let vinylID: UUID
    public var side: Side
    public var position: Int            // D9: explicit ordering, never relationship order
    public var rawOCRText: String
    public var artist: String?
    public var title: String?
    public var bpm: Double?
    public var camelot: String?         // "8A", "11B" — parsed by Camelot in plan 01-03
    public var matchConfidence: Double
    public var resolutionState: ResolutionState
    public var failureReason: String?

    public init(id: UUID = UUID(), vinylID: UUID, side: Side = .a, position: Int = 0,
                rawOCRText: String = "", artist: String? = nil, title: String? = nil,
                bpm: Double? = nil, camelot: String? = nil, matchConfidence: Double = 0,
                resolutionState: ResolutionState = .pending, failureReason: String? = nil) {
        self.id = id
        self.vinylID = vinylID
        self.side = side
        self.position = position
        self.rawOCRText = rawOCRText
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.camelot = camelot
        self.matchConfidence = matchConfidence
        self.resolutionState = resolutionState
        self.failureReason = failureReason
    }

    /// **MAN-04.** A person put at least one of these fields here by hand. The automatic path
    /// may still FILL a gap on such a track — that is useful and nobody loses anything — but it
    /// may never overwrite a value that is already there, and the mark itself is permanent, so
    /// the next automatic pass respects the same fields this one did.
    ///
    /// The whole protection is two `??` in two functions (`TrackResolver.assign`,
    /// `BPMLadder.applied`) keyed on this one predicate. It is deliberately not a set of
    /// per-field flags: a person who opens the sheet at all is asserting authority over what
    /// they left in it, and a `nil` field is not something they typed.
    public var isManual: Bool { resolutionState == .manual }

    /// BPM-07. No route could establish a tempo, so a person has to. The track keeps its
    /// place in the crate and its identity; it simply cannot be sequenced until this is false.
    public var needsManualBPM: Bool { bpm == nil }

    /// Display name for a UI row. Falls back to raw OCR text when unresolved.
    public var displayName: String {
        if let artist, let title {
            return "\(artist) — \(title)"
        }
        if !rawOCRText.isEmpty {
            return rawOCRText
        }
        return "Unknown track"
    }
}
