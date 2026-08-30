import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Deterministic UUID from a small integer, so failures are reproducible and readable.
func vinylID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

func makeTrack(vinyl: Int, bpm: Double?, camelot: String? = nil,
               position: Int = 0, title: String? = nil) -> Track {
    Track(id: vinylID(vinyl * 1000 + position), vinylID: vinylID(vinyl), position: position,
          title: title, bpm: bpm, camelot: camelot)
}

/// Builds one vinyl carrying several candidate tracks.
func makeVinyl(_ n: Int, bpms: [Double?], camelots: [String?] = []) -> [Track] {
    bpms.enumerated().map { i, bpm in
        makeTrack(vinyl: n, bpm: bpm, camelot: i < camelots.count ? camelots[i] : nil, position: i)
    }
}

/// A tiny seeded LCG so "40 random vinyls" means the same 40 every run.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xdead_beef : seed }
    mutating func next() -> UInt64 {
        // Numerical Recipes LCG constants — good enough for deterministic test fixtures.
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}

private let wheelCodes: [String] = (1...12).flatMap { hour in ["A", "B"].map { "\(hour)\($0)" } }

/// N vinyls, 1-4 candidates each, BPMs spread across 160...186, keys drawn from the wheel.
/// Used by the performance and divergence tests in plan 01-05.
func makeCrateFixture(vinylCount: Int, seed: UInt64) -> [Track] {
    var rng = SeededRandom(seed: seed)
    var tracks: [Track] = []
    for n in 1...max(vinylCount, 1) where vinylCount > 0 {
        let candidateCount = Int(rng.next() % 4) + 1
        for i in 0..<candidateCount {
            let bpm = 160.0 + Double(rng.next() % 261) / 10.0   // 160.0...186.0
            let camelot = wheelCodes[Int(rng.next() % UInt64(wheelCodes.count))]
            tracks.append(makeTrack(vinyl: n, bpm: bpm, camelot: camelot, position: i))
        }
    }
    return tracks
}

// MARK: - Determinism guard (plan 01-05 relies on this holding)

@Test("makeCrateFixture is byte-identical across two runs with the same seed")
func test_givenSameSeed_whenFixtureBuiltTwice_thenIdenticalTrackList() {
    let a = makeCrateFixture(vinylCount: 40, seed: 42)
    let b = makeCrateFixture(vinylCount: 40, seed: 42)
    #expect(a == b)
}
