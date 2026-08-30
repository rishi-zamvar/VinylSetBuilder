import Foundation

/// SEQ-11: one row per track that made the running order.
public struct SequencedRow: Identifiable, Sendable, Hashable {
    public let id: UUID              // the Track's id
    public let vinylID: UUID
    public let indexLabel: String    // "1", "2", ... — one-based
    public let title: String         // Track.displayName
    public let badges: TrackBadges
}

/// SEQ-07: one row per vinyl that did NOT make the running order — unresolved and
/// excluded share this single row type. D7: there is no second, differently-named row.
public struct NotIncludedRow: Identifiable, Sendable, Hashable {
    public let id: UUID              // the vinylID
    public let label: String         // VinylEntry.label
    public let reason: String        // D7: the sequencer's own words, verbatim
    public let badges: TrackBadges   // best-known candidate, or placeholders
}

/// A `SequenceResult` projected into rows a screen can render. Pure function of
/// (SequenceResult, Crate) — no view is instantiated to test this.
public struct CrateRows: Sendable, Hashable {
    public let sequenced: [SequencedRow]
    public let notIncluded: [NotIncludedRow]      // D7: ONE bucket. There is no second array.

    public var showsNotIncludedSection: Bool { !notIncluded.isEmpty }
    public var notIncludedHeader: String { "Not in the set (\(notIncluded.count))" }

    public static let empty = CrateRows(sequenced: [], notIncluded: [])

    public static func make(result: SequenceResult, crate: Crate) -> CrateRows {
        let sequenced = result.sequence.enumerated().map { index, track in
            SequencedRow(id: track.id, vinylID: track.vinylID, indexLabel: String(index + 1),
                         title: track.displayName, badges: TrackBadges(track: track))
        }

        let vinylsByID = Dictionary(uniqueKeysWithValues: crate.vinyls.map { ($0.id, $0) })
        let notIncluded = result.notIncluded.compactMap { entry -> NotIncludedRow? in
            guard let vinyl = vinylsByID[entry.vinylID] else { return nil }   // stale ID: skip, don't trap
            return NotIncludedRow(id: entry.vinylID, label: vinyl.label, reason: entry.reason,
                                  badges: Self.bestKnownBadges(for: vinyl))
        }

        return CrateRows(sequenced: sequenced, notIncluded: notIncluded)
    }

    /// The candidate whose tempo the exclusion is *about*: highest known BPM, falling back
    /// to the first candidate (so at least a key can show), falling back to placeholders.
    private static func bestKnownBadges(for vinyl: VinylEntry) -> TrackBadges {
        let candidates = vinyl.orderedCandidates
        if let best = candidates.filter({ $0.bpm != nil }).max(by: { $0.bpm! < $1.bpm! }) {
            return TrackBadges(track: best)
        }
        if let first = candidates.first {
            return TrackBadges(track: first)
        }
        return TrackBadges(bpm: nil, camelot: nil)
    }
}
