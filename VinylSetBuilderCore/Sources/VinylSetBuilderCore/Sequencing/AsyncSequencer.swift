import Foundation

/// SEQ-09: sequencing runs off the main thread.
///
/// The whole content of this type is the **`Task.detached`**, and it is not incidental. Xcode 26
/// projects default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a plain `Task { }` created
/// from a screen inherits that screen's main-actor isolation and would run the beam search on
/// exactly the thread it was meant to leave. `Task.detached` does not inherit isolation, so the
/// work genuinely lands on the cooperative pool.
///
/// It is a wrapper rather than a change to `Sequencing` on purpose: the protocol stays a **pure
/// synchronous function** (`Sequencing`'s doc comment: fully re-derives every call, no memory of
/// prior runs), which is what keeps the algorithm trivially testable and what makes SEQ-08's
/// rejoin-on-add fall out for free. Concurrency is the caller's concern, applied here once.
public struct AsyncSequencer: Sendable {
    private let inner: any Sequencing

    public init(_ inner: any Sequencing = BeamSearchSequencer()) {
        self.inner = inner
    }

    /// Runs the wrapped sequencer off whatever actor the caller is on and awaits the answer.
    /// `Track` and `SequenceResult` are both `Sendable`, so nothing crosses the boundary that
    /// needs copying or locking.
    public func sequence(candidates: [Track], bpmTolerance: Double) async -> SequenceResult {
        let inner = self.inner
        return await Task.detached(priority: .userInitiated) {
            inner.sequence(candidates: candidates, bpmTolerance: bpmTolerance)
        }.value
    }
}
