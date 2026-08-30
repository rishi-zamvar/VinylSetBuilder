import Foundation
import Testing
@testable import VinylSetBuilderCore

/// SEQ-09: sequencing runs off the main thread, and is fast enough to feel instant at
/// 100 vinyls / 400 candidates.

// MARK: - The probe

/// Records which thread the wrapped work actually ran on. Asserting `Thread.isMainThread`
/// inside the test body would prove nothing — the test body is not the sequencer.
private final class ThreadProbeSequencer: Sequencing, @unchecked Sendable {
    private let inner = BeamSearchSequencer()
    private let lock = NSLock()
    private var recorded: Bool?

    var sawMainThread: Bool? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func sequence(candidates: [Track], bpmTolerance: Double) -> SequenceResult {
        lock.lock()
        recorded = Thread.isMainThread
        lock.unlock()
        return inner.sequence(candidates: candidates, bpmTolerance: bpmTolerance)
    }
}

/// 100 vinyls x 4 candidates = exactly the 400-candidate crate SEQ-09 names. `makeCrateFixture`
/// draws 1–4 candidates at random and would land near 250, which is not the stated load.
func makeDenseCrateFixture(vinylCount: Int, candidatesPerVinyl: Int, seed: UInt64) -> [Track] {
    var rng = SeededRandom(seed: seed)
    var tracks: [Track] = []
    let wheel = (1...12).flatMap { hour in ["A", "B"].map { "\(hour)\($0)" } }
    for n in 1...vinylCount {
        for i in 0..<candidatesPerVinyl {
            let bpm = 160.0 + Double(rng.next() % 261) / 10.0        // 160.0...186.0
            let key = wheel[Int(rng.next() % UInt64(wheel.count))]
            tracks.append(makeTrack(vinyl: n, bpm: bpm, camelot: key, position: i))
        }
    }
    return tracks
}

// MARK: - Off the main thread

/// `Thread.isMainThread` is unavailable from an asynchronous context, so the check is made in
/// a synchronous main-actor function. Same question, asked somewhere it is allowed to be asked.
@MainActor private func runningOnTheMainThread() -> Bool { Thread.isMainThread }

@MainActor
@Test("SEQ-09: the work leaves the main actor even when the caller is ON the main actor")
func test_givenAMainActorCaller_whenSequencedAsynchronously_thenTheWorkRunsOffTheMainThread() async {
    let probe = ThreadProbeSequencer()
    #expect(runningOnTheMainThread(), "this test must call FROM the main thread or it proves nothing")

    let candidates = makeCrateFixture(vinylCount: 10, seed: 7)
    _ = await AsyncSequencer(probe).sequence(candidates: candidates, bpmTolerance: 4)

    #expect(probe.sawMainThread == false,
            "the sequencer ran on the main thread — Task.detached is what stops that")
}

@Test("The async wrapper returns exactly what the synchronous sequencer returns")
func test_givenTheSameCrate_whenSequencedBothWays_thenTheResultsAreIdentical() async {
    let candidates = makeCrateFixture(vinylCount: 40, seed: 42)
    let sync = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let async = await AsyncSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(async == sync)
}

// MARK: - The measured load

@Test("SEQ-09 measured: 100 vinyls / 400 candidates completes inside the stated bound")
func test_given100VinylsAnd400Candidates_whenSequenced_thenItCompletesInsideTheBound() async {
    // The bound is stated for an UNOPTIMISED `swift test` debug build, which is what runs here.
    // The shipped app is compiled -O; this is deliberately the pessimistic number.
    let bound = Duration.seconds(10)

    let candidates = makeDenseCrateFixture(vinylCount: 100, candidatesPerVinyl: 4, seed: 2026)
    #expect(candidates.count == 400)
    #expect(Set(candidates.map(\.vinylID)).count == 100)

    let start = ContinuousClock.now
    let result = await AsyncSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let elapsed = ContinuousClock.now - start

    print("SEQ-09 measured: 100 vinyls / 400 candidates in \(elapsed) "
          + "(sequenced \(result.sequence.count), notIncluded \(result.notIncluded.count), "
          + "camelot distance \(result.totalCamelotDistance))")

    #expect(elapsed < bound, "took \(elapsed), bound \(bound)")
    // Presence is not evidence: a sequencer that returned nothing would also be fast.
    #expect(result.sequence.count > 1)
    for (a, b) in zip(result.sequence, result.sequence.dropFirst()) {
        #expect(abs(b.bpm! - a.bpm!) <= 4 + 1e-9)
    }
}
