/// SEQ-01: the two BPM primitives the beam search in plan 01-04 gates on.
public enum BPMRules {
    public static let defaultTolerance: Double = 4.0
    public static let toleranceRange: ClosedRange<Double> = 3.0...6.0

    /// D6: this app only ever sees jungle/DnB, so a read below 100 is a half-time read —
    /// an 87 BPM read is a 174 BPM track. Applied once, not iteratively (50 -> 100, not 200).
    public static func fold(_ bpm: Double) -> Double { bpm < 100 ? bpm * 2 : bpm }

    /// D2: the sequence's only hard gate. Non-decreasing AND within tolerance of the
    /// previous track. Monotonic BPM is an MVP simplification — a real set arcs
    /// warm-up -> peak -> cool-down; that's SEQ2-01, not a truth this gate enforces.
    ///
    /// The `1e-9` epsilon absorbs binary-floating-point slack from a tolerance dragged on a
    /// slider (e.g. 4.0 that lands as 4.0000000000000004), without masking a genuine excess.
    public static func canFollow(_ a: Double, _ b: Double, tolerance: Double) -> Bool {
        b >= a && (b - a) <= tolerance + 1e-9
    }

    public static func clampTolerance(_ t: Double) -> Double {
        min(max(t, toleranceRange.lowerBound), toleranceRange.upperBound)
    }
}
