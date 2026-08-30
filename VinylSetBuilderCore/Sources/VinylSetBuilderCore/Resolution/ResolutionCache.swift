import Foundation

/// RES-06. Re-running the sequencer must issue ZERO network requests, which means misses are
/// cached as hard as hits: a lookup that found nothing yesterday will find nothing today, and
/// re-asking is exactly the quota spend the frugality rule forbids.
public actor ResolutionCache {
    private var entries: [String: ReleaseCandidate?] = [:]
    /// Counted, not inferred. A cache whose hit rate cannot be measured cannot be believed.
    public private(set) var hits = 0

    public init(_ seed: [String: ReleaseCandidate?] = [:]) {
        entries = seed
    }

    public func lookup(_ key: String) -> ReleaseCandidate?? {
        guard let entry = entries[key] else { return nil }
        hits += 1
        return .some(entry)
    }

    public func store(_ key: String, _ value: ReleaseCandidate?) {
        entries[key] = value
    }

    public var count: Int { entries.count }

    /// Every distinct lookup this cache holds, hits and misses alike. The gate harnesses read
    /// it to report WHICH rung answered — a ladder that cannot say where its answers came from
    /// cannot show that the free rung is carrying the work.
    public func snapshot() -> [String: ReleaseCandidate?] { entries }
}
