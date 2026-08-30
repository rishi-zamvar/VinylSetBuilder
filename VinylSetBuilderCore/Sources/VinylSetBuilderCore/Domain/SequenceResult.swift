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
    public let sequence: [Track]              // ordered, one per vinyl, non-decreasing BPM
    public let notIncluded: [NotIncluded]     // D7: ONE bucket for unresolved + excluded
    public let totalCamelotDistance: Int

    public init(sequence: [Track], notIncluded: [NotIncluded], totalCamelotDistance: Int) {
        self.sequence = sequence
        self.notIncluded = notIncluded
        self.totalCamelotDistance = totalCamelotDistance
    }

    public static let empty = SequenceResult(sequence: [], notIncluded: [], totalCamelotDistance: 0)
}
