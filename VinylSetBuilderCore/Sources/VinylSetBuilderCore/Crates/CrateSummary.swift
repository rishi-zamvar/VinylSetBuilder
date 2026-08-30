import Foundation

/// CRATE-01 projection: what a crate-list row needs, and nothing else. `recordCount` is
/// always derived from `Crate.recordCount` at read time, never stored/cached here.
public struct CrateSummary: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let recordCount: Int
}
