import Foundation

public struct NotIncluded: Sendable, Hashable, Codable, Identifiable {
    public var id: UUID { vinylID }
    public let vinylID: UUID
    public let reason: String           // D7: plain language, shown verbatim in the UI

    public init(vinylID: UUID, reason: String) {
        self.vinylID = vinylID
        self.reason = reason
    }
}

public struct SequenceResult: Sendable, Hashable {
    /// Ordered, one track per vinyl. Every adjacent pair is within BPM_TOLERANCE in EITHER
    /// direction (SEQ-03, revised 2026-08-30) — the order is NOT sorted by tempo, and must not
    /// be re-sorted by a caller: the arrangement is the sequencer's harmonic answer.
    public let sequence: [Track]
    public let notIncluded: [NotIncluded]     // D7: ONE bucket for unresolved + excluded
    public let totalCamelotDistance: Int

    public init(sequence: [Track], notIncluded: [NotIncluded], totalCamelotDistance: Int) {
        self.sequence = sequence
        self.notIncluded = notIncluded
        self.totalCamelotDistance = totalCamelotDistance
    }

    public static let empty = SequenceResult(sequence: [], notIncluded: [], totalCamelotDistance: 0)
}
