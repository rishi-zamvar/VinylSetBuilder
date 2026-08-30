import Foundation

/// SEQ-02/03/04/06: the app's differentiator. A width-50 beam search over BPM-sorted
/// candidates, gated by `BPMRules` and tie-broken by `Camelot` — never the other way round.
///
/// Beam search, not exact DP (D5): the "at most one track per vinylID" constraint means the
/// true state space is exponential in the number of vinyls (a visited-vinyl bitmask), so this
/// keeps only the best `beamWidth` partial paths at each step instead of exploring all of them.
/// Plan 01-05 adds a wider-beam divergence check as the safety net for this approximation.
public struct BeamSearchSequencer: Sequencing {
    public let beamWidth: Int

    public init(beamWidth: Int = 50) {
        self.beamWidth = beamWidth
    }

    /// One partial path through the beam. `visited` is D3 — at most one track per vinylID.
    private struct State {
        var path: [Int]            // indices into `sorted`
        var visited: Set<UUID>     // vinylIDs already used on this path
        var lastBPM: Double
        var lastKey: Camelot?
        var distance: Int
    }

    public func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        guard !candidates.isEmpty else { return .empty }
        let tolerance = BPMRules.clampTolerance(bpmTolerance)

        // First-appearance order of every vinylID, so notIncluded reads stable and testable.
        var firstAppearance: [UUID] = []
        var seenVinyl = Set<UUID>()
        for c in candidates where !seenVinyl.contains(c.vinylID) {
            seenVinyl.insert(c.vinylID)
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

        // Ascending by folded BPM; deterministic ties so plan 01-05's divergence check is
        // comparing like with like across beam widths.
        sorted.sort { a, b in
            if a.bpm! != b.bpm! { return a.bpm! < b.bpm! }
            let ak = a.camelot ?? "", bk = b.camelot ?? ""
            if ak != bk { return ak < bk }
            return a.id.uuidString < b.id.uuidString
        }

        let keys = sorted.map { Camelot.parse($0.camelot) }

        // Cost of a key transition never excludes a track — a missing/unparseable key on
        // either end simply contributes nothing to the tie-break sum.
        // ponytail: this mildly favours unknown-key tracks in an exact count tie; revisit only
        // if a real set actually sounds wrong, not before.
        func edgeCost(_ from: Camelot?, _ to: Camelot?) -> Int {
            guard let from, let to else { return 0 }
            return from.distance(to: to)
        }

        // D4: most vinyls wins, ties break on lowest total distance, then lowest start index
        // purely to make pruning/winner-selection deterministic.
        func rank(_ s: State) -> (Int, Int, Int) {
            (-s.path.count, s.distance, s.path.first ?? 0)
        }

        func prune(_ states: [State]) -> [State] {
            Array(states.sorted { rank($0) < rank($1) }.prefix(beamWidth))
        }

        // Sorted-ascending order is a topological order of the BPM-gate DAG (non-decreasing
        // gate), so a single left-to-right pass is sufficient — no revisiting needed.
        var beam: [State] = []
        for (i, track) in sorted.enumerated() {
            var next = beam
            next.append(State(path: [i], visited: [track.vinylID], lastBPM: track.bpm!,
                               lastKey: keys[i], distance: 0))
            for s in beam where !s.visited.contains(track.vinylID)
                && BPMRules.canFollow(s.lastBPM, track.bpm!, tolerance: tolerance) {
                var extended = s
                extended.path.append(i)
                extended.visited.insert(track.vinylID)
                extended.distance += edgeCost(s.lastKey, keys[i])
                extended.lastBPM = track.bpm!
                extended.lastKey = keys[i]
                next.append(extended)
            }
            beam = prune(next)
        }

        let winner = beam.min { rank($0) < rank($1) }
        let winningSequence = winner.map { w in w.path.map { sorted[$0] } } ?? []
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
                               totalCamelotDistance: winner?.distance ?? 0)
    }
}

/// Renders 4.0 as "4" and 4.5 as "4.5" — the exclusion reason reads like a human wrote it.
private func formattedTolerance(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
}
