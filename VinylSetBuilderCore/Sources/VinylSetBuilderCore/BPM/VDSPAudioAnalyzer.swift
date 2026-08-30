import Accelerate
import Foundation

/// BPM-04 and BPM-05, on-device and offline: tempo by onset envelope and autocorrelation, key
/// by chromagram and Krumhansl-Schmuckler profile matching, mapped to Camelot.
///
/// Accelerate is an Apple framework present on both the installed iOS SDK and macOS, and it is
/// not on the Core purity ban list — checked before a line of this was written, not assumed.
public struct VDSPAudioAnalyzer: AudioAnalyzing {
    /// Two front ends, because tempo and key want opposite things from an FFT.
    ///
    /// Tempo wants TIME resolution: a short window hopped often, so the onset envelope is
    /// sampled finely enough that one lag step is a fraction of a BPM rather than three of
    /// them. Key wants FREQUENCY resolution: at 2048 samples a bin is 21.5 Hz, which is wider
    /// than a semitone anywhere below about 370 Hz — so every bass bin lands in the same few
    /// pitch classes and the chromagram answers the same key for everything. Measured: the
    /// first run of this analyser said 7B for 20 of 29 tracks.
    public static let onsetFrameSize = 1024
    public static let onsetHopSize = 256
    public static let chromaFrameSize = 8192
    public static let chromaHopSize = 4096
    /// Jungle lives near 170 and the corpus reaches down to hip-hop tempi. Anything outside
    /// this is not a tempo, it is a measurement artefact.
    public static let bpmRange: ClosedRange<Double> = 60...200

    public init() {}

    public func analyse(monoSamples: [Float], sampleRate: Double) async -> AudioAnalysis {
        guard monoSamples.count >= Self.onsetFrameSize * 8, sampleRate > 0 else {
            return AudioAnalysis(bpm: nil, camelot: nil)
        }
        let onsetSpectra = Self.magnitudeSpectra(monoSamples, frameSize: Self.onsetFrameSize,
                                                 hopSize: Self.onsetHopSize)
        guard onsetSpectra.count > 8 else { return AudioAnalysis(bpm: nil, camelot: nil) }
        let bpm = Self.tempo(from: onsetSpectra, sampleRate: sampleRate)
        let chromaSpectra = Self.magnitudeSpectra(monoSamples, frameSize: Self.chromaFrameSize,
                                                  hopSize: Self.chromaHopSize)
        let (camelot, confidence) = Self.key(from: chromaSpectra, sampleRate: sampleRate,
                                             frameSize: Self.chromaFrameSize)
        return AudioAnalysis(bpm: bpm, camelot: camelot, keyConfidence: confidence)
    }

    // MARK: - the shared front end

    /// Hann-windowed magnitude spectra, one per hop. Both halves of the analyser read these,
    /// so the FFT is paid for once.
    static func magnitudeSpectra(_ samples: [Float], frameSize: Int, hopSize: Int) -> [[Float]] {
        let n = frameSize
        let half = n / 2
        let log2n = vDSP_Length(log2(Float(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }

        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        var spectra: [[Float]] = []
        spectra.reserveCapacity(max(0, (samples.count - n) / hopSize + 1))
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var windowed = [Float](repeating: 0, count: n)
        var magnitudes = [Float](repeating: 0, count: half)

        var offset = 0
        while offset + n <= samples.count {
            vDSP_vmul(Array(samples[offset..<(offset + n)]), 1, window, 1, &windowed, 1, vDSP_Length(n))
            real.withUnsafeMutableBufferPointer { realPointer in
                imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                    var split = DSPSplitComplex(realp: realPointer.baseAddress!,
                                                imagp: imaginaryPointer.baseAddress!)
                    windowed.withUnsafeBufferPointer { source in
                        source.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
                }
            }
            spectra.append(magnitudes)
            offset += hopSize
        }
        return spectra
    }

    // MARK: - tempo

    /// Half-wave-rectified spectral flux: how much MORE energy this frame holds than the last,
    /// summed across bins. Rectification is what makes it an ONSET detector rather than a
    /// change detector — a note ending is not a beat.
    static func onsetEnvelope(_ spectra: [[Float]]) -> [Float] {
        guard spectra.count > 1 else { return [] }
        var envelope = [Float](repeating: 0, count: spectra.count - 1)
        for index in 1..<spectra.count {
            let previous = spectra[index - 1], current = spectra[index]
            var flux: Float = 0
            for bin in 0..<min(previous.count, current.count) {
                let rise = current[bin] - previous[bin]
                if rise > 0 { flux += rise }
            }
            envelope[index - 1] = flux
        }
        return envelope
    }

    /// Parabolic interpolation around the autocorrelation peak.
    ///
    /// Without it the answer is quantised to whole lags, and at jungle tempo one lag step at
    /// this hop is worth about 1.4 BPM — enough on its own to miss a +/-2 BPM tolerance. This
    /// is not a refinement, it is the difference between a right answer and a near miss.
    static func interpolatedPeak(_ scores: [Float], at index: Int) -> Double {
        guard index > 0, index < scores.count - 1 else { return Double(index) }
        let before = Double(scores[index - 1]), here = Double(scores[index]), after = Double(scores[index + 1])
        let denominator = before - 2 * here + after
        guard denominator != 0 else { return Double(index) }
        let shift = 0.5 * (before - after) / denominator
        return Double(index) + max(-0.5, min(0.5, shift))
    }

    static func tempo(from spectra: [[Float]], sampleRate: Double) -> Double? {
        var envelope = onsetEnvelope(spectra)
        guard envelope.count > 32 else { return nil }

        // Mean-removed, so the autocorrelation measures periodicity rather than loudness.
        var mean: Float = 0
        vDSP_meanv(envelope, 1, &mean, vDSP_Length(envelope.count))
        var negativeMean = -mean
        vDSP_vsadd(envelope, 1, &negativeMean, &envelope, 1, vDSP_Length(envelope.count))

        let envelopeRate = sampleRate / Double(onsetHopSize)
        let shortestLag = max(2, Int((60.0 / bpmRange.upperBound) * envelopeRate))
        let longestLag = min(envelope.count - 1, Int((60.0 / bpmRange.lowerBound) * envelopeRate))
        guard longestLag > shortestLag else { return nil }

        var scores = [Float](repeating: 0, count: longestLag + 2)
        var bestLag = shortestLag
        var bestScore = -Float.greatestFiniteMagnitude
        for lag in max(1, shortestLag - 1)...min(envelope.count - 1, longestLag + 1) {
            var score: Float = 0
            vDSP_dotpr(envelope, 1, Array(envelope[lag...]), 1, &score,
                       vDSP_Length(envelope.count - lag))
            // Longer lags overlap fewer samples and would otherwise lose by arithmetic alone.
            score /= Float(envelope.count - lag)
            scores[lag] = score
            if lag >= shortestLag, lag <= longestLag, score > bestScore {
                bestScore = score; bestLag = lag
            }
        }
        // MEASURED, and rejected: crediting each lag with its harmonics (a comb — score(lag) +
        // 0.5*score(2*lag) + 0.25*score(3*lag)) is the textbook fix for locking onto the bar
        // instead of the beat. On these 29 tracks it made tempo accuracy WORSE, 41% usable to
        // 34%. The bare peak stays. Recorded here so nobody re-adds it on principle.
        guard bestScore > 0 else { return nil }
        return 60.0 * envelopeRate / interpolatedPeak(scores, at: bestLag)
    }

    // MARK: - key

    /// Ported from Krumhansl & Schmuckler's probe-tone profiles, index 0 = C.
    static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
                                         2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
                                         2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
    /// Spellings chosen to exist in both of `Camelot`'s ported pitch tables.
    static let pitchNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    /// Energy per pitch class over the whole window.
    ///
    /// Bounded to 130-2000 Hz. Below 130 the kick drum dominates and the FFT bin is not
    /// narrower than a semitone even at 8192 samples; above 2000 it is cymbals and harmonics.
    /// Each frame is normalised before it is added, so a loud bar does not outvote a quiet one
    /// — the key of a passage is not a function of its volume.
    static func chromagram(from spectra: [[Float]], sampleRate: Double, frameSize: Int) -> [Double] {
        var chroma = [Double](repeating: 0, count: 12)
        guard let first = spectra.first else { return chroma }
        let binWidth = sampleRate / Double(frameSize)
        var pitchClasses = [Int](repeating: -1, count: first.count)
        for bin in 1..<first.count {
            let frequency = Double(bin) * binWidth
            guard frequency >= 130, frequency <= 2000 else { continue }
            let midi = 69 + 12 * log2(frequency / 440)
            pitchClasses[bin] = ((Int(midi.rounded()) % 12) + 12) % 12
        }
        for spectrum in spectra {
            var frame = [Double](repeating: 0, count: 12)
            for bin in 1..<spectrum.count where pitchClasses[bin] >= 0 {
                frame[pitchClasses[bin]] += Double(spectrum[bin])
            }
            let total = frame.reduce(0, +)
            guard total > 0 else { continue }
            for pitchClass in 0..<12 { chroma[pitchClass] += frame[pitchClass] / total }
        }
        return chroma
    }

    static func key(from spectra: [[Float]], sampleRate: Double, frameSize: Int) -> (String?, Double) {
        let chroma = chromagram(from: spectra, sampleRate: sampleRate, frameSize: frameSize)
        guard chroma.reduce(0, +) > 0 else { return (nil, 0) }
        var best: (correlation: Double, tonic: Int, minor: Bool) = (-2, 0, false)
        for tonic in 0..<12 {
            let rotated = (0..<12).map { chroma[($0 + tonic) % 12] }
            for (profile, isMinor) in [(majorProfile, false), (minorProfile, true)] {
                let correlation = pearson(rotated, profile)
                if correlation > best.correlation { best = (correlation, tonic, isMinor) }
            }
        }
        let camelot = Camelot.from(pitch: pitchNames[best.tonic],
                                   mode: best.minor ? "minor" : "major")
        return (camelot?.code, max(0, best.correlation))
    }

    static func pearson(_ a: [Double], _ b: [Double]) -> Double {
        let n = Double(a.count)
        let meanA = a.reduce(0, +) / n, meanB = b.reduce(0, +) / n
        var covariance = 0.0, varianceA = 0.0, varianceB = 0.0
        for index in 0..<a.count {
            let da = a[index] - meanA, db = b[index] - meanB
            covariance += da * db; varianceA += da * da; varianceB += db * db
        }
        guard varianceA > 0, varianceB > 0 else { return 0 }
        return covariance / (varianceA * varianceB).squareRoot()
    }
}
