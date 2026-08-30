/// SEQ-01: the two BPM primitives the beam search gates on.
public enum BPMRules {
    public static let defaultTolerance: Double = 4.0
    public static let toleranceRange: ClosedRange<Double> = 3.0...6.0

    /// D6: this app only ever sees jungle/DnB, so a read below 100 is a half-time read —
    /// an 87 BPM read is a 174 BPM track. Applied once, not iteratively (50 -> 100, not 200).
    public static func fold(_ bpm: Double) -> Double { bpm < 100 ? bpm * 2 : bpm }

    /// D2 / SEQ-03, revised by the owner 2026-08-30: the sequence's only hard gate is
    /// `|b − a| ≤ tolerance`, **in either direction**. See `.planning/SEQUENCER-SPEC.md`.
    ///
    /// The gate is therefore symmetric, which is the whole change: it makes the search space a
    /// general graph rather than a DAG, and `BeamSearchSequencer` expands over the full
    /// neighbour set because of it. The name `canFollow` is kept because the caller still asks
    /// a directed question ("may b follow a?"); the answer simply no longer depends on which
    /// of the two is larger.
    ///
    /// This function is the ONLY place tolerance arithmetic lives. The sequencer asks it once
    /// per candidate pair rather than deriving a BPM window inline, so there is exactly one
    /// definition of the boundary to get wrong.
    ///
    /// The `1e-9` epsilon absorbs binary-floating-point slack from a tolerance dragged on a
    /// slider (e.g. 4.0 that lands as 4.0000000000000004), without masking a genuine excess.
    public static func canFollow(_ a: Double, _ b: Double, tolerance: Double) -> Bool {
        abs(b - a) <= tolerance + 1e-9
    }

    public static func clampTolerance(_ t: Double) -> Double {
        min(max(t, toleranceRange.lowerBound), toleranceRange.upperBound)
    }
}
