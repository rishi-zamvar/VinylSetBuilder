import Foundation

/// RES-01, RES-02, RES-06, RES-07 — the ladder itself.
///
/// The rungs, cheapest first, exactly as the frugality rule orders them:
///
///   1. the cache            — free, and hits and misses both count
///   2. MusicBrainz by catalogue number   — free and unlimited; measured to know 5 of the 6
///                                          catalogue numbers this collection produces
///   3. Discogs by catalogue number       — 60/min, and only for the one MusicBrainz misses
///   4. MusicBrainz by title              — free
///   5. Discogs by title                  — 60/min, last
///
/// A quota call is never made for a datum a free source already answered. That is not a
/// nicety: five of six catalogue lookups never touch Discogs at all.
public struct TrackResolver: MetadataResolving {
    public static let maxConcurrentRequests = 3

    private let musicBrainz: MusicBrainzClient
    private let discogs: DiscogsClient
    private let cache: ResolutionCache

    public init(musicBrainz: MusicBrainzClient, discogs: DiscogsClient, cache: ResolutionCache) {
        self.musicBrainz = musicBrainz
        self.discogs = discogs
        self.cache = cache
    }

    public func resolve(_ tracks: [Track], sleeve: SleeveContext) async -> [Track] {
        // Rungs 1-3 are a per-RECORD lookup, made once however many tracks the sleeve carries.
        // Doing it per track would multiply the quota spend by the track count for an answer
        // that cannot differ.
        if let catalogueNumber = sleeve.catalogueNumber,
           let release = await lookupByCatalogueNumber(catalogueNumber, sleeve: sleeve) {
            return tracks.map { assign(release, to: $0, sleeve: sleeve) }
        }
        return await resolveIndividually(tracks, sleeve: sleeve)
    }

    // MARK: - rungs 1-3

    private func lookupByCatalogueNumber(_ number: String, sleeve: SleeveContext) async -> ReleaseCandidate? {
        let key = "catno:" + TrackTextFilter.alphanumeric(number)
        if let cached = await cache.lookup(key) { return cached }

        var chosen: ReleaseCandidate?
        for rung in [freeCatalogueRung(number), paidCatalogueRung(number)] {
            guard !Task.isCancelled else { return nil }
            let candidates = (try? await rung()) ?? []
            if let best = SleeveCrossCheck.best(among: candidates, sleeveText: sleeve.text) {
                chosen = best.candidate
                break
            }
        }
        await cache.store(key, chosen)
        return chosen
    }

    private func freeCatalogueRung(_ number: String) -> @Sendable () async throws -> [ReleaseCandidate] {
        { try await musicBrainz.searchByCatalogueNumber(number) }
    }

    private func paidCatalogueRung(_ number: String) -> @Sendable () async throws -> [ReleaseCandidate] {
        { try await discogs.searchByCatalogueNumber(number) }
    }

    // MARK: - rungs 4-5

    private func resolveIndividually(_ tracks: [Track], sleeve: SleeveContext) async -> [Track] {
        // RES-02: at most three requests in flight. The pull model — seed the group with the
        // bound, then add one task each time one finishes — needs no semaphore and no
        // third-party package to hold the bound exactly.
        await withTaskGroup(of: (Int, Track).self) { group in
            var next = 0
            var resolved = tracks
            let bound = min(Self.maxConcurrentRequests, tracks.count)
            for _ in 0..<bound {
                let index = next; next += 1
                group.addTask { (index, await self.resolveOne(tracks[index], sleeve: sleeve)) }
            }
            while let (index, track) = await group.next() {
                resolved[index] = track
                if next < tracks.count, !Task.isCancelled {
                    let index = next; next += 1
                    group.addTask { (index, await self.resolveOne(tracks[index], sleeve: sleeve)) }
                }
            }
            return resolved
        }
    }

    private func resolveOne(_ track: Track, sleeve: SleeveContext) async -> Track {
        let query = Self.queryText(for: track)
        guard query.count >= 4 else { return failed(track, "nothing readable to search for") }

        let key = "title:" + TrackTextFilter.alphanumeric(query)
        if let cached = await cache.lookup(key) {
            return cached.map { assign($0, to: track, sleeve: sleeve) }
                ?? failed(track, "no release matched \"\(query)\"")
        }

        var chosen: ReleaseCandidate?
        for rung in [{ try await musicBrainz.searchByArtistTitle(artist: "", title: query) },
                     { try await discogs.searchByArtistTitle(artist: "", title: query) }]
                as [@Sendable () async throws -> [ReleaseCandidate]] {
            guard !Task.isCancelled else { return failed(track, "cancelled") }
            let candidates = (try? await rung()) ?? []
            if let best = SleeveCrossCheck.best(among: candidates, sleeveText: sleeve.text + [query]) {
                chosen = best.candidate
                break
            }
        }
        await cache.store(key, chosen)
        guard let chosen else { return failed(track, "no release matched \"\(query)\"") }
        return assign(chosen, to: track, sleeve: sleeve)
    }

    // MARK: - turning a release into a track

    /// A release title is routinely BOTH track titles: `High Down / Strange Nature`. The part
    /// closest to what the reader saw on this line is this line's title.
    static func titlePart(of release: ReleaseCandidate, matching text: String) -> String {
        let parts = release.title
            .split(whereSeparator: { $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count > 1 else { return release.title }
        return parts.max { MatchScoring.similarity($0, text) < MatchScoring.similarity($1, text) }
            ?? release.title
    }

    /// The side marker is sleeve furniture, not part of the title the databases hold:
    /// `A: HIGH DOWN` searches as `HIGH DOWN`.
    static func queryText(for track: Track) -> String {
        if let marker = TrackTextFilter.sideMarker(in: track.rawOCRText), !marker.title.isEmpty {
            return marker.title
        }
        return track.rawOCRText.trimmingCharacters(in: .whitespaces)
    }

    private func assign(_ release: ReleaseCandidate, to track: Track, sleeve: SleeveContext) -> Track {
        var resolved = track
        let text = Self.queryText(for: track)
        let title = Self.titlePart(of: release, matching: text)
        resolved.artist = release.artist.isEmpty ? nil : release.artist
        resolved.title = title
        resolved.matchConfidence = MatchScoring.similarity(text, title)
        // RES-04: only the accepted band resolves outright. The confirmation band stays
        // `.pending` carrying its confidence, which is what a confirmation queue IS — the UI
        // bands `matchConfidence` with the same thresholds rather than a second enum case
        // drifting out of step with the first.
        resolved.resolutionState = MatchScoring.band(resolved.matchConfidence) == .accepted
            ? .resolved : .pending
        resolved.failureReason = nil
        return resolved
    }

    private func failed(_ track: Track, _ reason: String) -> Track {
        var failedTrack = track
        failedTrack.resolutionState = .failed
        failedTrack.failureReason = reason
        return failedTrack
    }
}
