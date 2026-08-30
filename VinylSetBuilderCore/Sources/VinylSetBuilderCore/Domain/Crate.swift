import Foundation

public struct Crate: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var vinyls: [VinylEntry]
    public var bpmTolerance: Double                 // default 4.0, slider range 3...6
    public var manualOrder: [Track.ID]?             // non-nil once the user drags (CRATE-04)
    public var selectedTrackByVinyl: [UUID: UUID]   // CRATE-07: selection is per-crate, not per-vinyl

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now, vinyls: [VinylEntry] = [],
                bpmTolerance: Double = 4.0, manualOrder: [Track.ID]? = nil,
                selectedTrackByVinyl: [UUID: UUID] = [:]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.vinyls = vinyls
        self.bpmTolerance = bpmTolerance
        self.manualOrder = manualOrder
        self.selectedTrackByVinyl = selectedTrackByVinyl
    }

    public var recordCount: Int { vinyls.count }
    public var allCandidates: [Track] { vinyls.flatMap(\.orderedCandidates) }
}
