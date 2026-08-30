import Foundation

/// What an analyser can say about a piece of audio. Both fields are optional because both are
/// genuinely unknowable from a bad thirty seconds, and inventing one is worse than admitting it.
public struct AudioAnalysis: Sendable, Hashable {
    public let bpm: Double?
    public let camelot: String?
    /// The winning Krumhansl-Schmuckler correlation, 0...1. Carried so a caller can treat a
    /// weakly-held key as no key at all.
    public let keyConfidence: Double

    public init(bpm: Double?, camelot: String?, keyConfidence: Double = 0) {
        self.bpm = bpm
        self.camelot = camelot
        self.keyConfidence = keyConfidence
    }
}

/// BPM-08. The seam that lets Apple's Music Understanding replace the in-house analyser as a
/// drop-in the day an iOS 27 SDK exists, without touching a caller.
///
/// It takes SAMPLES, not an asset, for two reasons. Decoding needs a framework this package may
/// not import; and samples are what a DSP analyser actually consumes, so the app-side adapter
/// that decodes a file is the same adapter that would hand Music Understanding an asset.
public protocol AudioAnalyzing: Sendable {
    func analyse(monoSamples: [Float], sampleRate: Double) async -> AudioAnalysis
}
