import Accelerate
import Foundation

/// BPM-04 and BPM-05, on-device and offline: tempo by onset envelope and autocorrelation, key
/// by chromagram and Krumhansl-Schmuckler profile matching, mapped to Camelot.
///
/// Accelerate is an Apple framework present on both the installed iOS SDK and macOS, and it is
/// not on the Core purity ban list — checked before a line of this was written, not assumed.
public struct VDSPAudioAnalyzer: AudioAnalyzing {
    public static let frameSize = 2048
    public static let hopSize = 512
    /// Jungle lives near 170 and the corpus reaches down to hip-hop tempi. Anything outside
    /// this is not a tempo, it is a measurement artefact.
    public static let bpmRange: ClosedRange<Double> = 60...200

    public init() {}

    public func analyse(monoSamples: [Float], sampleRate: Double) async -> AudioAnalysis {
        guard monoSamples.count >= Self.frameSize * 4, sampleRate > 0 else {
            return AudioAnalysis(bpm: nil, camelot: nil)
        }
        let spectra = Self.magnitudeSpectra(monoSamples)
        guard spectra.count > 8 else { return AudioAnalysis(bpm: nil, camelot: nil) }
        let bpm = Self.tempo(from: spectra, sampleRate: sampleRate)
        let (camelot, confidence) = Self.key(from: spectra, sampleRate: sampleRate)
        return AudioAnalysis(bpm: bpm, camelot: camelot, keyConfidence: confidence)
    }

    // MARK: - the shared front end

    /// Hann-windowed magnitude spectra, one per hop. Both halves of the analyser read these,
    /// so the FFT is paid for once.
    static func magnitudeSpectra(_ samples: [Float]) -> [[Float]] {
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

    static func tempo(from spectra: [[Float]], sampleRate: Double) -> Double? {
        var envelope = onsetEnvelope(spectra)
        guard envelope.count > 32 else { return nil }

        // Mean-removed, so the autocorrelation measures periodicity rather than loudness.
        var mean: Float = 0
        vDSP_meanv(envelope, 1, &mean, vDSP_Length(envelope.count))
        var negativeMean = -mean
        vDSP_vsadd(envelope, 1, &negativeMean, &envelope, 1, vDSP_Length(envelope.count))

        let envelopeRate = sampleRate / Double(hopSize)
        let shortestLag = max(2, Int((60.0 / bpmRange.upperBound) * envelopeRate))
        let longestLag = min(envelope.count - 1, Int((60.0 / bpmRange.lowerBound) * envelopeRate))
        guard longestLag > shortestLag else { return nil }

        var bestLag = shortestLag
        var bestScore = -Float.greatestFiniteMagnitude
        for lag in shortestLag...longestLag {
            var score: Float = 0
            vDSP_dotpr(envelope, 1, Array(envelope[lag...]), 1, &score,
                       vDSP_Length(envelope.count - lag))
            // Longer lags overlap fewer samples and would otherwise lose by arithmetic alone.
            score /= Float(envelope.count - lag)
            if score > bestScore { bestScore = score; bestLag = lag }
        }
        guard bestScore > 0 else { return nil }
        return 60.0 * envelopeRate / Double(bestLag)
    }

    // MARK: - key

    /// Ported from Krumhansl & Schmuckler's probe-tone profiles, index 0 = C.
    static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
                                         2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
                                         2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
    /// Spellings chosen to exist in both of `Camelot`'s ported pitch tables.
    static let pitchNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    /// Energy per pitch class over the whole window. Bounded to 65-2000 Hz: below that is
    /// kick drum, above it is cymbal, and neither carries the tonality.
    static func chromagram(from spectra: [[Float]], sampleRate: Double) -> [Double] {
        var chroma = [Double](repeating: 0, count: 12)
        guard let first = spectra.first else { return chroma }
        let binWidth = sampleRate / Double(frameSize)
        var pitchClasses = [Int](repeating: -1, count: first.count)
        for bin in 1..<first.count {
            let frequency = Double(bin) * binWidth
            guard frequency >= 65, frequency <= 2000 else { continue }
            let midi = 69 + 12 * log2(frequency / 440)
            pitchClasses[bin] = ((Int(midi.rounded()) % 12) + 12) % 12
        }
        for spectrum in spectra {
            for bin in 1..<spectrum.count where pitchClasses[bin] >= 0 {
                chroma[pitchClasses[bin]] += Double(spectrum[bin])
            }
        }
        return chroma
    }

    static func key(from spectra: [[Float]], sampleRate: Double) -> (String?, Double) {
        let chroma = chromagram(from: spectra, sampleRate: sampleRate)
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
