import Foundation

/// CRATE-03/04/07 as a pure value type: the running order, the per-crate pin, and the manual
/// override. Holds no reference to the view layer (D8) and performs no work in `init` — a
/// caller sequences explicitly, because a caller is the one who knows what it can afford.
public struct CrateDetailModel: Sendable, Equatable {
    public private(set) var crate: Crate
    public private(set) var result: SequenceResult
    public private(set) var rows: CrateRows

    public init(crate: Crate) {
        self.crate = crate
        self.result = .empty
        self.rows = .empty
    }

    public var crateID: UUID { crate.id }
    public var crateName: String { crate.name }
    public var recordCount: Int { crate.recordCount }

    /// CRATE-07 (D2-2). A per-crate selection PINS which candidate the sequencer may use for
    /// that vinyl — that is what makes the same vinyl render differently in two crates. A pin
    /// naming a track the vinyl does not actually carry is ignored rather than trusted, so a
    /// stale selection can never erase a vinyl from the set.
    ///
    /// Deliberately not `crate.allCandidates`: that property offers every candidate
    /// unconditionally and would defeat the pin.
    public var sequencerInput: [Track] {
        crate.vinyls.flatMap { vinyl -> [Track] in
            let candidates = vinyl.orderedCandidates
            guard let pinned = crate.selectedTrackByVinyl[vinyl.id],
                  let track = candidates.first(where: { $0.id == pinned })
            else { return candidates }
            return [track]
        }
    }

    /// Apply a result computed elsewhere. The result is authoritative about MEMBERSHIP and is
    /// never mutated here — the sequencer stays pure and memoryless so SEQ-08's rejoin-on-add
    /// falls out of a full re-derivation rather than a merge.
    public mutating func apply(_ newResult: SequenceResult) {
        result = newResult
        rebuildRows()
    }

    /// Synchronous full re-derivation. Off-main-thread sequencing is SEQ-09, not this.
    public mutating func resequence(using sequencer: some Sequencing) {
        apply(sequencer.sequence(candidates: sequencerInput, bpmTolerance: crate.bpmTolerance))
    }

    private mutating func rebuildRows() {
        rows = CrateRows.make(result: result, crate: crate)
    }
}
