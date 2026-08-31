import Foundation

/// Bytes in, samples out. The other half of BPM-08's seam: decoding needs a framework this
/// package may not import, so it is declared here and implemented in the app target.
public protocol AudioDecoding: Sendable {
    func decodeMono(_ data: Data) async throws -> (samples: [Float], sampleRate: Double)
}

/// BPM-01, BPM-06 and BPM-07 — the tempo half of the ladder.
///
///   1. the track already has a BPM   — nothing to do, and this IS the cache: a filled track
///                                      never asks again, so re-running the sequencer costs
///                                      nothing
///   2. the bundled tier-0 corpus     — free, local, offline
///   3. SoundCloud preview + analysis — 30 seconds of audio and the vDSP analyser
///
/// A track no rung can answer keeps its identity, keeps its place, and is surfaced for manual
/// entry. It is never dropped and it is never given a made-up number.
public struct BPMLadder: Sendable {
    private let corpus: TierZeroCorpus?
    private let soundCloud: SoundCloudClient?
    private let decoder: (any AudioDecoding)?
    private let analyser: any AudioAnalyzing
    private let keyConfidenceFloor: Double

    /// MEASURED, on the 29-track ground truth (Artifacts/bpm/analyser-run1.json).
    ///
    /// Confidence does predict correctness — usable keys averaged 0.76, wrong ones 0.64 — but
    /// only weakly, so the floor buys precision by throwing answers away:
    ///
    ///     floor 0.5   24 keys kept, 9 usable   38% precision
    ///     floor 0.6   21 keys kept, 9 usable   43%
    ///     floor 0.7   15 keys kept, 8 usable   53%
    ///     floor 0.8    7 keys kept, 5 usable   71%
    ///
    /// 0.8 is the choice: seven keys of which five are usable beats twenty-four of which nine
    /// are. A wrong key is worse than none, because the sequencer can order round a missing key
    /// and cannot know a wrong one is wrong. Everything below the floor becomes a manual field.
    public static let defaultKeyConfidenceFloor = 0.8

    public init(corpus: TierZeroCorpus?, soundCloud: SoundCloudClient? = nil,
                decoder: (any AudioDecoding)? = nil,
                analyser: any AudioAnalyzing = VDSPAudioAnalyzer(),
                keyConfidenceFloor: Double = BPMLadder.defaultKeyConfidenceFloor) {
        self.corpus = corpus
        self.soundCloud = soundCloud
        self.decoder = decoder
        self.analyser = analyser
        self.keyConfidenceFloor = keyConfidenceFloor
    }

    public func fill(_ track: Track) async -> Track {
        guard track.bpm == nil else { return track }
        guard let artist = track.artist, let title = track.title,
              !artist.isEmpty, !title.isEmpty else {
            return marked(track, ExclusionReason.noIdentity)
        }

        if let hit = corpus?.lookup(artist: artist, title: title) {
            return applied(track, bpm: hit.bpm, camelot: hit.camelot)
        }

        guard let soundCloud, let decoder else {
            return marked(track, "Not in the bundled corpus, and no audio route configured")
        }
        do {
            let candidates = try await soundCloud.search("\(artist) \(title)")
            guard let chosen = SoundCloudMatcher.best(among: candidates, artist: artist, title: title) else {
                return marked(track, ExclusionReason.noSoundCloudMatch)
            }
            // `data` and `decoded` are locals in this scope and nothing outside it ever holds
            // them: BPM-04's "the audio is not retained" is a property of never owning it.
            let data = try await soundCloud.preview(of: chosen.track.id)
            let decoded = try await decoder.decodeMono(data)
            let analysis = await analyser.analyse(monoSamples: decoded.samples,
                                                  sampleRate: decoded.sampleRate)
            guard let bpm = analysis.bpm else { return marked(track, "The audio yielded no tempo") }
            return applied(track, bpm: bpm,
                           camelot: analysis.keyConfidence >= keyConfidenceFloor ? analysis.camelot : nil)
        } catch {
            return marked(track, "Audio route failed: \(error)")
        }
    }

    /// BPM-06, applied here and only here: below 100 is a half-time read, doubled ONCE.
    ///
    /// **MAN-04 on the key.** A hand-typed tempo was already safe — `fill` returns at its first
    /// line when `bpm != nil` — but the key was not: this function used to assign `camelot`
    /// unconditionally, so a DJ who knew a white label was in 6A by ear and left the tempo for
    /// the app to find lost the key the moment the analyser answered. `??` closes that, and the
    /// mark survives so the next pass behaves the same way.
    private func applied(_ track: Track, bpm: Double, camelot: String?) -> Track {
        var filled = track
        filled.bpm = BPMRules.fold(bpm)
        filled.camelot = track.isManual ? (track.camelot ?? camelot) : camelot
        filled.failureReason = nil
        return filled
    }

    /// BPM-07. The identity survives; only the tempo is missing, and it says so.
    private func marked(_ track: Track, _ reason: String) -> Track {
        var marked = track
        marked.failureReason = reason
        return marked
    }
}
