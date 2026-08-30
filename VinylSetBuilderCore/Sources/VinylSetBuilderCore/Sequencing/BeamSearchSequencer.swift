import Foundation

/// SEQ-02/03/04/06: the app's differentiator. A width-50 beam search over the FULL neighbour
/// set, gated by `BPMRules` and tie-broken by `Camelot` — never the other way round.
///
/// ## Why this is not a single forward pass any more
///
/// SEQ-03 was rewritten by the owner on 2026-08-30 (`.planning/SEQUENCER-SPEC.md`): the hard
/// gate is `|bpm[i+1] − bpm[i]| ≤ tolerance` **in either direction**. The retired non-decreasing
/// rule made the BPM-sorted order a topological order of a DAG, which is what licensed the old
/// implementation's single left-to-right pass. A symmetric gate destroys that: edges now point
/// both ways, the search space is a general graph, and a forward-only pass **cannot reach** a
/// sequence that steps down. So each round expands every surviving state by every unvisited
/// candidate, in both directions.
///
/// ## What did NOT change, and why that is provable rather than hopeful
///
/// **Theorem.** A set `S` admits a legal sequence iff its ascending-BPM ordering has every
/// consecutive gap `≤ tolerance`.
/// *Proof.* (⇐) the sorted order is such a sequence. (⇒) if some sorted gap exceeds tolerance,
/// `S` splits into a low part and a high part with **no edge between them** — every cross pair
/// differs by at least that gap — yet a path over `S` must cross. Contradiction. ∎
///
/// So the achievable vinyl **counts are identical** under the old rule and the new one: the BPM
/// graph is a unit-interval graph that decomposes into islands separated by gaps wider than the
/// tolerance, and no path crossed an island boundary under either rule. Rank-1 ("most vinyls
/// wins"), every exclusion reason, and the rejoin-on-add behaviour are therefore untouched by
/// this rewrite. What grows is the **ordering freedom**: a feasible set may now be visited in
/// any Hamiltonian order rather than only the sorted one, which is a strictly larger space for
/// the soft Camelot objective to minimise over. `SequencerAdjacencyTests` asserts the invariant
/// that falls out of the theorem — re-sorting any winning sequence by BPM is itself legal.
///
/// ## The approximation, stated
///
/// Beam search, not exact DP (D5): "at most one track per vinylID" makes the true state space
/// exponential in the number of vinyls (a visited-vinyl bitmask), so only the best `beamWidth`
/// partial paths survive each round. `BeamDivergenceCheck` (SEQ-10) is the safety net — it
/// re-runs at a wider beam and reports whether the answers diverge.
///
/// ponytail: beam width 50 was chosen against the old DAG and is re-validated against this
/// wider space by measurement, not argument. Raise it only if a divergence run says to.
public struct BeamSearchSequencer: Sequencing {
    public let beamWidth: Int

    public init(beamWidth: Int = 50) {
        self.beamWidth = beamWidth
    }

    /// One link of a path, held in an arena. Extending a state appends one node instead of
    /// copying an array, which is what keeps a 100-vinyl / 400-candidate crate cheap: the old
    /// `path: [Int]` copy-per-extension was O(length) on every one of ~600k extensions.
    private struct PathNode {
        let track: Int
        let parent: Int      // -1 at the root
    }

    /// D3 — at most one track per vinylID. A bitmask over vinyl slots rather than a `Set<UUID>`:
    /// two `UInt64` words cover 128 vinyls, and — critically — nothing about the answer may ever
    /// depend on set iteration order, because Swift's `Hasher` is seeded per process.
    private struct VisitedMask {
        private var words: [UInt64]

        init(slotCount: Int) {
            words = [UInt64](repeating: 0, count: max(1, (slotCount + 63) / 64))
        }

        func contains(_ slot: Int) -> Bool {
            words[slot >> 6] & (UInt64(1) << UInt64(slot & 63)) != 0
        }

        mutating func insert(_ slot: Int) {
            words[slot >> 6] |= UInt64(1) << UInt64(slot & 63)
        }
    }

    /// One partial path through the beam.
    private struct State {
        var node: Int            // index into the arena
        var first: Int           // first track index, carried so ranking never walks the path
        var last: Int            // last track index
        var length: Int
        var visited: VisitedMask
        var lastBPM: Double
        var lastKey: Camelot?
        var distance: Int
    }

    public func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        guard !candidates.isEmpty else { return .empty }
        let tolerance = BPMRules.clampTolerance(bpmTolerance)

        // First-appearance order of every vinylID, so notIncluded reads stable and testable.
        // This is the ONE place input array order is allowed to reach the output, and it reaches
        // only `notIncluded`'s ordering — never membership, and never the sequence.
        var firstAppearance: [UUID] = []
        var vinylSlot: [UUID: Int] = [:]
        for c in candidates where vinylSlot[c.vinylID] == nil {
            vinylSlot[c.vinylID] = firstAppearance.count
            firstAppearance.append(c.vinylID)
        }

        // A vinyl only counts as "unresolved" (D7's other bucket) if NONE of its candidates
        // carry a BPM. One resolved candidate is enough to make the vinyl BPM-eligible.
        let vinylsWithBPM = Set(candidates.compactMap { $0.bpm != nil ? $0.vinylID : nil })

        // Normalise: fold before anything else touches the number (gate and badge must agree).
        // Candidates with no BPM can never be scheduled and are dropped here.
        var sorted: [Track] = candidates.compactMap { track in
            guard let bpm = track.bpm else { return nil }
            var folded = track
            folded.bpm = BPMRules.fold(bpm)
            return folded
        }

        // A TOTAL order — (folded BPM, camelot, track UUID). Because the final key is the UUID
        // and UUIDs are unique, `sorted` is a deterministic function of the candidate SET and
        // carries no trace of the input array's order. Every index below is therefore a stable,
        // position-independent name for a track, which is what makes the rank tiebreaker sound.
        sorted.sort { a, b in
            if a.bpm! != b.bpm! { return a.bpm! < b.bpm! }
            let ak = a.camelot ?? "", bk = b.camelot ?? ""
            if ak != bk { return ak < bk }
            return a.id.uuidString < b.id.uuidString
        }

        let n = sorted.count
        let bpms = sorted.map { $0.bpm! }
        let keys = sorted.map { Camelot.parse($0.camelot) }
        let slots = sorted.map { vinylSlot[$0.vinylID]! }

        // Cost of a key transition never excludes a track — a missing/unparseable key on
        // either end simply contributes nothing to the tie-break sum.
        // ponytail: this mildly favours unknown-key tracks in an exact count tie; revisit only
        // if a real set actually sounds wrong, not before.
        func edgeCost(_ from: Camelot?, _ to: Camelot?) -> Int {
            guard let from, let to else { return 0 }
            return from.distance(to: to)
        }

        var arena: [PathNode] = []
        arena.reserveCapacity(n * 16)

        func materialise(_ s: State) -> [Int] {
            var out: [Int] = []
            out.reserveCapacity(s.length)
            var i = s.node
            while i >= 0 {
                out.append(arena[i].track)
                i = arena[i].parent
            }
            return out.reversed()
        }

        // D4: most vinyls wins, ties break on lowest total Camelot distance.
        //
        // Q1: the remaining tiebreakers must make this a TOTAL order, or equal-ranked states
        // compete for beam slots and `sorted(by:)` — which is not stable — resolves them
        // arbitrarily, so the same crate could sequence differently depending on the order the
        // candidates arrived in. `first`/`last`/the path are indices into `sorted`, whose own
        // key ends in the track UUID; two distinct paths always differ somewhere, so the final
        // lexicographic comparison closes the order. Nothing here reads array position.
        //
        // ponytail: the lexicographic leg is O(length) and only runs when count, distance,
        // first AND last all tie. Cheap in practice; if a profile ever says otherwise, cache
        // the materialised path on the state.
        func rankLess(_ a: State, _ b: State) -> Bool {
            if a.length != b.length { return a.length > b.length }
            if a.distance != b.distance { return a.distance < b.distance }
            if a.first != b.first { return a.first < b.first }
            if a.last != b.last { return a.last < b.last }
            let pa = materialise(a), pb = materialise(b)
            for (x, y) in zip(pa, pb) where x != y { return x < y }
            return false
        }

        // Seeds are deliberately NOT pruned. Every length-1 state has the same count and the
        // same distance, so pruning them would keep 50 by tiebreak alone and could discard the
        // start of the longest chain in the crate before it ever gets to prove itself.
        var beam: [State] = []
        beam.reserveCapacity(n)
        for i in 0..<n {
            arena.append(PathNode(track: i, parent: -1))
            var visited = VisitedMask(slotCount: firstAppearance.count)
            visited.insert(slots[i])
            beam.append(State(node: arena.count - 1, first: i, last: i, length: 1,
                              visited: visited, lastBPM: bpms[i], lastKey: keys[i], distance: 0))
        }

        var best: State? = beam.min(by: rankLess)

        while !beam.isEmpty {
            var next: [State] = []
            for s in beam {
                // The full neighbour set, forward and backward. The gate is ASKED of the one
                // shared function rather than re-derived as a BPM window here — one definition
                // of the boundary means one place to get it wrong.
                for j in 0..<n where !s.visited.contains(slots[j])
                    && BPMRules.canFollow(s.lastBPM, bpms[j], tolerance: tolerance) {
                    arena.append(PathNode(track: j, parent: s.node))
                    var visited = s.visited
                    visited.insert(slots[j])
                    next.append(State(node: arena.count - 1, first: s.first, last: j,
                                      length: s.length + 1, visited: visited,
                                      lastBPM: bpms[j], lastKey: keys[j],
                                      distance: s.distance + edgeCost(s.lastKey, keys[j])))
                }
            }
            if next.isEmpty { break }
            beam = Array(next.sorted(by: rankLess).prefix(beamWidth))
            if let top = beam.first, best == nil || rankLess(top, best!) { best = top }
        }

        let winningSequence = best.map { materialise($0).map { sorted[$0] } } ?? []
        let winningVinyls = Set(winningSequence.map(\.vinylID))

        let notIncluded: [NotIncluded] = firstAppearance
            .filter { !winningVinyls.contains($0) }
            .map { vinyl in
                if !vinylsWithBPM.contains(vinyl) {
                    return NotIncluded(vinylID: vinyl,
                                        reason: "No BPM yet — resolve it or enter it by hand")
                }
                return NotIncluded(vinylID: vinyl,
                                    reason: "No track within \(formattedTolerance(tolerance)) BPM of the set")
            }

        return SequenceResult(sequence: winningSequence, notIncluded: notIncluded,
                               totalCamelotDistance: best?.distance ?? 0)
    }
}

/// Renders 4.0 as "4" and 4.5 as "4.5" — the exclusion reason reads like a human wrote it.
private func formattedTolerance(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
}
