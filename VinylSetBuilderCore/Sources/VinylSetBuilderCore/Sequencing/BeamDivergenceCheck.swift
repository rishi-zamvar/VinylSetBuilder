import Foundation

/// SEQ-10: the safety net under the beam approximation.
///
/// `BeamSearchSequencer` keeps only the best `beamWidth` partial paths per round, so it can in
/// principle discard the prefix of the true optimum and return a silently suboptimal set. The
/// only honest way to find out is to run the same crate at a wider beam and compare.
///
/// This mattered more after 2026-08-30 than before it. Width 50 was chosen against the old
/// DAG — a single forward pass over BPM-sorted candidates. The bidirectional gate makes the
/// search space a general graph, so many more equal-ranked states now compete for the same 50
/// slots, and the width has to be re-validated rather than assumed.
///
/// **A wider beam is NOT guaranteed to be better, and that was measured, not assumed.** The
/// tempting induction — "the wide beam's survivors contain the narrow beam's, so its answer can
/// only improve" — is false. Pruning keeps the top `k` by rank; an element in the narrow beam's
/// top-`k` is beaten by at most `k−1` of its own peers, but in the wider pool it can be beaten
/// by more than `k'` newcomers and drop out entirely. Measured on the 40-vinyl fixture at
/// seed 7 / tolerance 3: widths 50, 400 and 1000 all return **40** vinyls, width 150 returns
/// **39**.
///
/// So the useful question is not "do the two agree" but **"is the shipped default the one
/// losing records"** — and `BeamDivergenceTests` asserts that it is not, across 20 runs against
/// width 150 and 20 against width 400.
public struct BeamDivergenceCheck: Sendable {
    public struct Report: Sendable, Hashable {
        public let narrowWidth: Int
        public let wideWidth: Int
        public let narrow: SequenceResult
        public let wide: SequenceResult

        /// The comparison is on **vinyl ID order**, not on `Track` structs and not on
        /// `SequenceResult` as a whole — `notIncluded` is ordered by input first-appearance for
        /// the UI's benefit, which is a presentation choice, not an algorithmic answer.
        public var agrees: Bool {
            narrow.sequence.map(\.vinylID) == wide.sequence.map(\.vinylID)
        }

        /// Vinyls the wider beam found that the narrow one missed. Must be 0.
        public var countDelta: Int { wide.sequence.count - narrow.sequence.count }

        /// Camelot distance the wider beam saved. Negative means the narrow beam was
        /// suboptimal; 0 means the approximation held.
        public var distanceDelta: Int { wide.totalCamelotDistance - narrow.totalCamelotDistance }

        public var summary: String {
            "beam \(narrowWidth) vs \(wideWidth): "
                + "\(agrees ? "agree" : "DIVERGE") "
                + "count \(narrow.sequence.count)/\(wide.sequence.count) (Δ\(countDelta)) "
                + "distance \(narrow.totalCamelotDistance)/\(wide.totalCamelotDistance) "
                + "(Δ\(distanceDelta))"
        }
    }

    public let narrowWidth: Int
    public let wideWidth: Int

    public init(narrowWidth: Int = 50, wideWidth: Int = 150) {
        self.narrowWidth = narrowWidth
        self.wideWidth = wideWidth
    }

    public func run(candidates: [Track], bpmTolerance: Double) -> Report {
        Report(narrowWidth: narrowWidth,
               wideWidth: wideWidth,
               narrow: BeamSearchSequencer(beamWidth: narrowWidth)
                   .sequence(candidates: candidates, bpmTolerance: bpmTolerance),
               wide: BeamSearchSequencer(beamWidth: wideWidth)
                   .sequence(candidates: candidates, bpmTolerance: bpmTolerance))
    }
}
