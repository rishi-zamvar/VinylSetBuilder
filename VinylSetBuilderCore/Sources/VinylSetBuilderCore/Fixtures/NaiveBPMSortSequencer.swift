/// Placeholder Sequencing used until plan 01-04's BeamSearchSequencer exists — filters out
/// tracks with no BPM and sorts the rest ascending. Exists so plan 01-06 (crate UI) doesn't
/// block on plan 01-04.
public struct NaiveBPMSortSequencer: Sequencing {
    public init() {}

    public func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        let sorted = candidates
            .filter { $0.bpm != nil }
            .sorted { $0.bpm! < $1.bpm! }
        return SequenceResult(sequence: sorted, notIncluded: [], totalCamelotDistance: 0)
    }
}
