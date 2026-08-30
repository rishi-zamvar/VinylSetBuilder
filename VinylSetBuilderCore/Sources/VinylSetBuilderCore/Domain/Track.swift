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
