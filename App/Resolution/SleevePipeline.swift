import Foundation
import VinylSetBuilderCore

/// **Swap 3.** The resolution ladder and the BPM ladder, wired into the app for the first time.
///
/// Everything here was built and measured in Phase 7 — catalogue-number resolution 6 of 6,
/// SoundCloud match 85%, analyser tempo 41% usable — but only ever from a macOS harness in
/// `Tools/`. This is the composition root that puts the same objects behind the crate screen.
/// **Nothing is re-implemented; every line is a constructor call.**
///
/// The two throttles are separate on purpose: two services, two allowances, and sharing one
/// would make MusicBrainz pay Discogs' spacing. That is the harness's reasoning, kept.
///
/// One instance for the app (`shared`), because the ResolutionCache and the SoundCloud bearer
/// token are the whole point of RES-05 and BPM-03 — a per-screen pipeline would re-authenticate
/// and re-query for answers it already had.
actor SleevePipeline {
    static let shared = SleevePipeline()

    private let resolver: TrackResolver
    private let bpm: BPMLadder

    /// **One pipeline, two front ends (Phase 10).** The corpus URL is a parameter with the
    /// app's own `Bundle.main` lookup as its default, so `shared` behaves exactly as it did and
    /// `vinylctl` — which has no bundle to look in — passes `App/Generated/bpmkey.tsv` on disk.
    /// That one parameter is the entire difference between the CLI's pipeline and the app's;
    /// everything below is the same constructor call for both.
    init(corpusURL: URL? = Bundle.main.url(forResource: "bpmkey", withExtension: "tsv")) {
        let raw = URLSessionTransport()
        resolver = TrackResolver(
            musicBrainz: MusicBrainzClient(transport: ThrottledTransport(
                wrapping: raw, minimumInterval: ThrottledTransport.musicBrainzInterval)),
            discogs: DiscogsClient(transport: ThrottledTransport(
                wrapping: raw, minimumInterval: ThrottledTransport.discogsInterval),
                                   token: Secrets.discogsToken),
            cache: ResolutionCache())

        // BPM-02: the bundled tier-0 corpus, generated at build time next to Secrets.swift and
        // gitignored the same way. Phase 7 measured its hit rate on THIS collection at zero —
        // it is the owner's house library and this is a crate of jungle twelves — so it is
        // consulted first because it is free, not because it is expected to answer.
        let corpus = corpusURL.flatMap(TierZeroCorpus.init(contentsOf:))
        bpm = BPMLadder(corpus: corpus,
                        soundCloud: SoundCloudClient(
                            transport: ThrottledTransport(wrapping: raw, minimumInterval: 1.0),
                            clientID: Secrets.soundCloudClientID,
                            clientSecret: Secrets.soundCloudClientSecret),
                        decoder: AVAudioFileDecoder())
    }

    /// One photographed record, all the way down the two ladders.
    ///
    /// The sleeve's catalogue number goes in as the primary key (RES-08) and the candidate
    /// lines as the corroborating text, so `SleeveCrossCheck` can throw out the USSR Tchaikovsky
    /// pressing Discogs offers for `0-44904`.
    ///
    /// Tempo is filled per track AFTER identity, because the tier-0 corpus and SoundCloud are
    /// both keyed on artist and title — there is nothing to look a tempo up by until the
    /// resolver has answered. A track the ladder cannot answer comes back with its
    /// `failureReason` set and its identity intact (BPM-07); it is never dropped.
    func process(_ vinyl: VinylEntry) async -> [Track] {
        let candidates = vinyl.orderedCandidates
        guard !candidates.isEmpty else { return candidates }
        let resolved = await resolver.resolve(
            candidates,
            sleeve: SleeveContext(catalogueNumber: vinyl.catalogueNumber,
                                  text: candidates.map(\.rawOCRText)))

        var filled: [Track] = []
        filled.reserveCapacity(resolved.count)
        for track in resolved {
            if Task.isCancelled { return filled + resolved.dropFirst(filled.count) }
            filled.append(await bpm.fill(track))
        }
        return filled
    }
}
