import Foundation
import Testing
@testable import VinylSetBuilderCore

/// A click track: a short decaying noise burst every beat. Deterministic — a seeded
/// generator, not `Float.random`, because a test that produces a different signal on every
/// run cannot be a regression test.
private func clickTrack(bpm: Double, seconds: Double, sampleRate: Double = 44100) -> [Float] {
    var samples = [Float](repeating: 0, count: Int(seconds * sampleRate))
    let period = Int(60.0 / bpm * sampleRate)
    let burst = Int(0.01 * sampleRate)
    var seed: UInt64 = 0x5EED
    func next() -> Float {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Float(Int32(truncatingIfNeeded: seed >> 33)) / Float(Int32.max)
    }
    var start = 0
    while start + burst < samples.count {
        for offset in 0..<burst {
            samples[start + offset] = next() * Float(exp(-Double(offset) / Double(burst) * 5))
        }
        start += period
    }
    return samples
}

private func chord(_ frequencies: [Double], seconds: Double, sampleRate: Double = 44100) -> [Float] {
    (0..<Int(seconds * sampleRate)).map { index in
        let t = Double(index) / sampleRate
        return Float(frequencies.map { sin(2 * .pi * $0 * t) }.reduce(0, +) / Double(frequencies.count))
    }
}

@Test("BPM-04: a 120 BPM click track measures 120 BPM")
func test_given120BPMClickTrack_whenAnalysed_thenTempoIs120() async {
    let analysis = await VDSPAudioAnalyzer().analyse(monoSamples: clickTrack(bpm: 120, seconds: 20),
                                                     sampleRate: 44100)
    let bpm = analysis.bpm ?? 0
    #expect(abs(bpm - 120) < 3, "measured \(bpm)")
}

@Test("BPM-04: a 172 BPM click track — jungle tempo — measures 172 BPM")
func test_given172BPMClickTrack_whenAnalysed_thenTempoIs172() async {
    let analysis = await VDSPAudioAnalyzer().analyse(monoSamples: clickTrack(bpm: 172, seconds: 20),
                                                     sampleRate: 44100)
    let bpm = analysis.bpm ?? 0
    // Octave-aware: the autocorrelation may lock to the half-time pulse, which is a correct
    // reading of the same groove and is what BPMRules.fold exists to undo.
    #expect(abs(bpm - 172) < 4 || abs(bpm * 2 - 172) < 4, "measured \(bpm)")
}

@Test("BPM-05: a C major triad reads as C major, which is Camelot 8B")
func test_givenCMajorTriad_whenAnalysed_thenCamelot8B() async {
    // C4 261.63, E4 329.63, G4 392.00
    let analysis = await VDSPAudioAnalyzer().analyse(
        monoSamples: chord([261.63, 329.63, 392.00], seconds: 5), sampleRate: 44100)
    #expect(analysis.camelot == "8B", "measured \(analysis.camelot ?? "nil")")
    #expect(analysis.keyConfidence > 0.3)
}

@Test("BPM-05: an A minor triad reads as A minor, which is Camelot 8A")
func test_givenAMinorTriad_whenAnalysed_thenCamelot8A() async {
    // A3 220.00, C4 261.63, E4 329.63
    let analysis = await VDSPAudioAnalyzer().analyse(
        monoSamples: chord([220.00, 261.63, 329.63], seconds: 5), sampleRate: 44100)
    #expect(analysis.camelot == "8A", "measured \(analysis.camelot ?? "nil")")
}

@Test("silence yields no answer rather than a made-up one")
func test_givenSilence_whenAnalysed_thenNothingClaimed() async {
    let analysis = await VDSPAudioAnalyzer()
        .analyse(monoSamples: [Float](repeating: 0, count: 44100), sampleRate: 44100)
    #expect(analysis.camelot == nil)
}

@Test("too little audio to measure yields no answer")
func test_givenAShortBuffer_whenAnalysed_thenNothingClaimed() async {
    let analysis = await VDSPAudioAnalyzer().analyse(monoSamples: [Float](repeating: 0.1, count: 100),
                                                     sampleRate: 44100)
    #expect(analysis.bpm == nil)
    #expect(analysis.camelot == nil)
}
