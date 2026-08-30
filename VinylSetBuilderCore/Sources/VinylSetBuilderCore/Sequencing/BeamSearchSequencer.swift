import Foundation

/// SEQ-02/03/04/06: the app's differentiator.
///
/// ## Why this is not a single forward pass any more
///
/// SEQ-03 was rewritten by the owner on 2026-08-30 (`.planning/SEQUENCER-SPEC.md`): the hard
/// gate is `|bpm[i+1] − bpm[i]| ≤ tolerance` **in either direction**. The retired non-decreasing
/// rule made the BPM-sorted order a topological order of a DAG, which is what licensed the old
/// implementation's single left-to-right pass. A symmetric gate destroys that: edges point both
/// ways, the space is a general graph, and a forward-only pass **cannot reach** a sequence that
/// steps down. `170 → 174 → 172` is now legal and is often the better set.
///
/// ## The theorem this is built on
///
/// **A set `S` admits a legal sequence iff its ascending-BPM ordering has every consecutive gap
/// `≤ tolerance`.**
/// *Proof.* (⇐) the sorted order is such a sequence. (⇒) if some sorted gap exceeds tolerance,
/// `S` splits into a low part and a high part with **no edge between them** — every cross pair
/// differs by at least that gap — yet a path over `S` must cross. Contradiction. ∎
///
/// Three things follow, and they are the whole architecture:
///
/// 1. The achievable vinyl **counts are identical** under the retired rule and the new one. The
///    BPM graph is a unit-interval graph; it breaks into islands separated by gaps wider than
///    the tolerance, and no path crossed an island boundary under either rule. "Most vinyls
///    wins", every exclusion reason and the rejoin-on-add behaviour survive the rewrite intact.
/// 2. Therefore **the count objective is best searched ascending**, where the space is a DAG and
///    progress along the BPM line is monotone. That is stage 1, and it is the old algorithm.
/// 3. What the rule change actually buys is **ordering freedom** — a feasible set may now be
///    visited in any Hamiltonian order, not only the sorted one. That is stage 2.
///
/// ## Why it is two stages, measured rather than argued
///
/// A single bidirectional beam gives the **primary** objective no search pressure at all. Every
/// state produced in one round has the same length, so rank-1 ties across the whole round and
/// the Camelot distance ends up doing all the pruning by itself; the beam fills with
/// distance-greedy prefixes that strand. Measured on the 40-vinyl fixture, tolerance 4, seeds
/// 7 / 42 / 1234:
///
/// | search | seed 7 | seed 42 | seed 1234 |
/// |---|---|---|---|
/// | one-stage bidirectional, width 50   | 40 | 34 | 34 |
/// | one-stage bidirectional, width 10   | 40 | 37 | 35 |
/// | two-stage (this file), any width    | 40 | 40 | 40 |
///
/// A search where a **narrower** beam finds **more** records is not an approximation, it is a
/// bug. Stage 1 prunes on count in the one space where count is monotone; stage 2 then has a
/// fixed set and can only rearrange it.
///
/// ## Stage 2 is 2-opt, and the new rule is exactly what makes that legal
///
/// Reversing a segment of the running order changes only the two edges at its ends — every edge
/// *inside* the reversed segment survives, **because the gate is symmetric**. Under the retired
/// non-decreasing rule that was false and the move would have been illegal. So the rule change
/// does not merely permit a backward step, it hands over the classic local-search move for
/// free. 2-opt starts from stage 1's ascending order, which is legal by the theorem, and only
/// ever accepts a move that keeps both new edges inside tolerance and strictly lowers the
/// Camelot sum — so the count can never regress and the distance can never rise.
///
/// A path and its reverse always cost the same, so the result is canonicalised to the
/// lexicographically smaller of the two. That is a real tiebreak, not decoration: without it
/// two equal-cost mirror answers would be equally valid and the output would not be a function
/// of its input.
///
/// `BeamDivergenceCheck` (SEQ-10) re-runs the whole thing at a wider beam as the safety net.
public struct BeamSearchSequencer: Sequencing {
    public let beamWidth: Int

    public init(beamWidth: Int = 50) {
        self.beamWidth = beamWidth
    }

    /// One link of a path, held in an arena. Extending a state appends one node instead of
    /// copying an array — the alternative is an O(length) copy on every extension.
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

    /// Everything both stages need, gathered once. Indices throughout are into the BPM-sorted
    /// candidate array.
    private struct Board {
        var bpms: [Double]
        var keys: [Camelot?]
        var slots: [Int]         // vinyl slot per track
        var slotCount: Int
        var tolerance: Double

        func mayFollow(_ a: Int, _ b: Int) -> Bool {
            BPMRules.canFollow(bpms[a], bpms[b], tolerance: tolerance)
        }

        /// A missing or unparseable key on either end contributes nothing — Camelot orders the
        /// survivors, it never excludes one.
        /// ponytail: this mildly favours unknown-key tracks in an exact count tie; revisit only
        /// if a real set actually sounds wrong, not before.
        func cost(_ a: Int, _ b: Int) -> Int {
            guard let from = keys[a], let to = keys[b] else { return 0 }
            return from.distance(to: to)
        }

        func totalCost(_ path: [Int]) -> Int {
            zip(path, path.dropFirst()).reduce(0) { $0 + cost($1.0, $1.1) }
        }
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
        // position-independent name for a track, which is what makes the tiebreakers sound.
        sorted.sort { a, b in
            if a.bpm! != b.bpm! { return a.bpm! < b.bpm! }
            let ak = a.camelot ?? "", bk = b.camelot ?? ""
            if ak != bk { return ak < bk }
            return a.id.uuidString < b.id.uuidString
        }

        let board = Board(bpms: sorted.map { $0.bpm! },
                          keys: sorted.map { Camelot.parse($0.camelot) },
                          slots: sorted.map { vinylSlot[$0.vinylID]! },
                          slotCount: firstAppearance.count,
                          tolerance: tolerance)

        var chosen = maximiseVinylCount(trackCount: sorted.count, board: board)
        while let grown = insertMissingVinyl(chosen, trackCount: sorted.count, board: board) {
            chosen = grown
        }
        let ordered = minimiseKeyDistance(chosen, board: board)

        let winningSequence = ordered.map { sorted[$0] }
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
                               totalCamelotDistance: board.totalCost(ordered))
    }

    // MARK: - Stage 1 — most vinyls wins (SEQ-04 rank 1)

    /// An ascending sweep, left to right along the BPM-sorted candidates, carrying the beam
    /// forward and seeding a fresh length-1 state at every position.
    ///
    /// The beam therefore holds paths of **mixed length**, and that is the entire point: rank-1
    /// is "length desc", so a longer path evicts a shorter one and the count objective gets real
    /// pruning pressure. Running this in rounds instead — every state the same length — dropped
    /// the 40-vinyl fixture from 40/40/40 vinyls to 27/14/17 on seeds 7/42/1234, because with
    /// length tied the distance tiebreak silently became the only selector. Measured, not feared.
    ///
    /// By the theorem this ascending search reaches every feasible SET, so nothing is given up
    /// by not stepping backwards here.
    private func maximiseVinylCount(trackCount m: Int, board: Board) -> [Int] {
        guard m > 0 else { return [] }

        var arena: [PathNode] = []
        arena.reserveCapacity(m * 16)

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
        // candidates arrived in. `first`, `last` and the path are indices into the BPM-sorted
        // array, whose own sort key ends in the track UUID; two distinct paths always differ
        // somewhere, so the lexicographic leg closes the order. Nothing reads input position.
        //
        // ponytail: that leg is O(length) and only runs when length, distance, first AND last
        // all tie. Cheap in practice; cache the path on the state if a profile ever says so.
        func rankLess(_ a: State, _ b: State) -> Bool {
            if a.length != b.length { return a.length > b.length }
            if a.distance != b.distance { return a.distance < b.distance }
            if a.first != b.first { return a.first < b.first }
            if a.last != b.last { return a.last < b.last }
            let pa = materialise(a), pb = materialise(b)
            for (x, y) in zip(pa, pb) where x != y { return x < y }
            return false
        }

        var beam: [State] = []
        beam.reserveCapacity(beamWidth * 2)

        for q in 0..<m {
            // `next` starts as the whole current beam, so a path that cannot be extended at
            // this position is carried forward rather than dropped.
            var next = beam
            arena.append(PathNode(track: q, parent: -1))
            var seeded = VisitedMask(slotCount: board.slotCount)
            seeded.insert(board.slots[q])
            next.append(State(node: arena.count - 1, first: q, last: q, length: 1,
                              visited: seeded, lastBPM: board.bpms[q], lastKey: board.keys[q],
                              distance: 0))

            for s in beam where !s.visited.contains(board.slots[q]) && board.mayFollow(s.last, q) {
                arena.append(PathNode(track: q, parent: s.node))
                var visited = s.visited
                visited.insert(board.slots[q])
                next.append(State(node: arena.count - 1, first: s.first, last: q,
                                  length: s.length + 1, visited: visited,
                                  lastBPM: board.bpms[q], lastKey: board.keys[q],
                                  distance: s.distance + board.cost(s.last, q)))
            }

            beam = Array(next.sorted(by: rankLess).prefix(beamWidth))
        }

        return beam.min(by: rankLess).map(materialise) ?? []
    }

    // MARK: - Stage 1b — repair: put back anything the beam left behind

    /// Try to splice one still-excluded vinyl into the running order at the cheapest legal
    /// position. Returns `nil` when nothing more will fit.
    ///
    /// This exists because "most records still win" is the product, and a beam is an
    /// approximation that can leave a record out for no better reason than which 50 partial
    /// paths happened to survive a prune. An insertion is checked against the same gate as
    /// everything else, so a repaired path is exactly as legal as an unrepaired one, and the
    /// count can only go up. Measured: it is also what stopped beam 50 and beam 150 returning
    /// different counts, because both widths now converge on the same repaired maximum.
    ///
    /// Deterministic: candidates are scanned in BPM-sorted index order and positions left to
    /// right, taking the strictly cheapest — so ties resolve to the earliest track and the
    /// earliest slot, never to whatever a `Set` happened to yield first.
    private func insertMissingVinyl(_ path: [Int], trackCount m: Int, board: Board) -> [Int]? {
        var used = [Bool](repeating: false, count: board.slotCount)
        for t in path { used[board.slots[t]] = true }

        var best: [Int]?
        var bestDelta = Int.max
        for t in 0..<m where !used[board.slots[t]] {
            for p in 0...path.count {
                let left = p > 0 ? path[p - 1] : nil
                let right = p < path.count ? path[p] : nil
                if let left, !board.mayFollow(left, t) { continue }
                if let right, !board.mayFollow(t, right) { continue }

                var delta = 0
                if let left { delta += board.cost(left, t) }
                if let right { delta += board.cost(t, right) }
                if let left, let right { delta -= board.cost(left, right) }

                if delta < bestDelta {
                    bestDelta = delta
                    var grown = path
                    grown.insert(t, at: p)
                    best = grown
                }
            }
        }
        return best
    }

    // MARK: - Stage 2 — fewest Camelot hops (SEQ-04 rank 2)

    /// 2-opt over the set stage 1 fixed. Reversing `path[i...j]` replaces exactly two edges and
    /// leaves the segment's interior untouched — legal only because the BPM gate is symmetric,
    /// which is precisely what SEQ-03's rewrite gave us.
    ///
    /// Deterministic by construction: candidate moves are scanned in index order and the first
    /// strictly-improving legal move is taken, so the walk depends on nothing but the path.
    /// Each accepted move lowers an integer cost that is bounded below by zero, so the loop
    /// terminates; the explicit budget is belt and braces, not the argument.
    private func minimiseKeyDistance(_ input: [Int], board: Board) -> [Int] {
        guard input.count > 2 else { return canonical(input) }
        var path = input
        var budget = board.totalCost(path) + 1

        while budget > 0 {
            budget -= 1
            var moved = false
            scan: for i in 0..<path.count {
                for j in (i + 1)..<path.count {
                    // Reversing the whole path changes no edge at all.
                    if i == 0 && j == path.count - 1 { continue }
                    var delta = 0
                    if i > 0 {
                        guard board.mayFollow(path[i - 1], path[j]) else { continue }
                        delta += board.cost(path[i - 1], path[j]) - board.cost(path[i - 1], path[i])
                    }
                    if j < path.count - 1 {
                        guard board.mayFollow(path[i], path[j + 1]) else { continue }
                        delta += board.cost(path[i], path[j + 1]) - board.cost(path[j], path[j + 1])
                    }
                    guard delta < 0 else { continue }
                    path.replaceSubrange(i...j, with: path[i...j].reversed())
                    moved = true
                    break scan
                }
            }
            if !moved { break }
        }
        return canonical(path)
    }

    /// A path and its reverse are always equally good — same edges, same cost, and both legal
    /// under a symmetric gate. Pick one by a rule that depends only on the tracks, so the output
    /// stays a function of its input.
    private func canonical(_ path: [Int]) -> [Int] {
        let mirrored = Array(path.reversed())
        for (a, b) in zip(path, mirrored) where a != b { return a < b ? path : mirrored }
        return path
    }
}

/// Renders 4.0 as "4" and 4.5 as "4.5" — the exclusion reason reads like a human wrote it.
private func formattedTolerance(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
}
