public protocol Sequencing: Sendable {
    /// Pure function. Fully re-derives the sequence every call — no memory of prior runs.
    /// That is what makes SEQ-08 (rejoin on add) fall out for free.
    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult
}
