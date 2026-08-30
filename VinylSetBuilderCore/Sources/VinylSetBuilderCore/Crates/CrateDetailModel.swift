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

    // MARK: CRATE-04 — the manual override

    /// **Membership is the sequencer's; arrangement is the user's.**
    /// `apply(_:)` re-derives which tracks are IN the set — always the sequencer's call, so a
    /// previously excluded record still rejoins the moment a new addition bridges the gap.
    /// `manualOrder` re-derives only the ORDER of the ones that are in: filter it down to IDs
    /// still present in `result.sequence`, then append any newly-sequenced IDs, in the
    /// sequencer's own order, at the end.
    ///
    /// ponytail: appending newcomers at the end is the predictable rule. Inserting each one at
    /// its computed slot inside a manual order is arguably nicer and strictly harder to reason
    /// about — revisit only if the owner asks for it.
    private mutating func rebuildRows() {
        let base = CrateRows.make(result: result, crate: crate)
        guard let manual = crate.manualOrder else { rows = base; return }

        let byID = Dictionary(uniqueKeysWithValues: base.sequenced.map { ($0.id, $0) })
        let survivors = manual.filter { byID[$0] != nil }
        let seen = Set(survivors)
        let order = survivors + base.sequenced.map(\.id).filter { !seen.contains($0) }

        // An override over nothing is not an override — collapse it so the screen does not
        // offer a "restore" for an empty list.
        crate.manualOrder = order.isEmpty ? nil : order

        let reordered = order.compactMap { byID[$0] }.enumerated().map { index, row in
            SequencedRow(id: row.id, vinylID: row.vinylID, indexLabel: String(index + 1),
                         title: row.title, badges: row.badges)
        }
        rows = CrateRows(sequenced: reordered, notIncluded: base.notIncluded)
    }
}

/// Which of the two orders the screen is currently showing (CRATE-04).
public enum OrderingMode: Sendable, Hashable {
    case sequenced
    case manual
}

extension CrateDetailModel {
    public var orderingMode: OrderingMode { crate.manualOrder == nil ? .sequenced : .manual }

    /// CRATE-04. Takes the shape a list's move handler hands over. Computed from the
    /// *currently displayed* order, so a drag on an already-manual list composes. Out-of-range
    /// offsets are ignored rather than trapping — a drag is not worth crashing over.
    ///
    /// **V18.** A drag that produces the order already on screen is a no-op, and a no-op may
    /// not commit anything: writing `manualOrder` for an identity move put the crate into
    /// `.manual` — *Custom order* header, *Restore* action — over the sequencer's own order,
    /// with nothing to restore. Leaving `manualOrder` untouched (rather than clearing it) is
    /// what makes the guard correct in BOTH directions: a sequenced list stays `nil`, and a
    /// list the user already arranged by hand keeps that arrangement. `ManualOrderTests`
    /// asserts each direction separately.
    public mutating func moveRows(fromOffsets: IndexSet, toOffset: Int) {
        let ids = rows.sequenced.map(\.id)
        guard !ids.isEmpty,
              fromOffsets.allSatisfy({ ids.indices.contains($0) }),
              (0...ids.count).contains(toOffset)
        else { return }

        let order = Self.moved(ids, fromOffsets: fromOffsets, toOffset: toOffset)
        guard order != ids else { return }

        crate.manualOrder = order
        rebuildRows()
    }

    /// The move the view layer's list hands over, done by hand: that framework's own
    /// `move(fromOffsets:toOffset:)` is not reachable from Core (D2-6).
    ///
    /// `toOffset` is an insertion index into the array *before* anything is removed — so the
    /// moved run lands immediately before whatever originally sat at `toOffset`, and the index
    /// has to be pulled back by however many moved elements were ahead of it.
    private static func moved(_ ids: [UUID], fromOffsets: IndexSet, toOffset: Int) -> [UUID] {
        let moving = fromOffsets.map { ids[$0] }
        let remaining = ids.enumerated().filter { !fromOffsets.contains($0.offset) }.map(\.element)
        var result = remaining
        result.insert(contentsOf: moving, at: toOffset - fromOffsets.count(in: 0..<toOffset))
        return result
    }

    /// Back to the algorithm's answer, in one call.
    public mutating func clearManualOrder() {
        crate.manualOrder = nil
        rebuildRows()
    }
}
