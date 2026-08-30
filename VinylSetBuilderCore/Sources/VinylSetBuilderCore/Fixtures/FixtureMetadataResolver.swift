import Foundation

/// Placeholder MetadataResolving used until Phase 4's real resolver ships. Varies its
/// output by `track.position` so a UI list of stubbed tracks doesn't look like a rendering bug.
public struct FixtureMetadataResolver: MetadataResolving {
    public init() {}

    private static let fixtureArtists = ["Photek", "Dillinja", "Source Direct", "Bukem", "Ed Rush"]
    private static let fixtureTitles = ["Ni Ten Ichi Ryu", "Acid Trak", "Snake Style", "Horizon", "Bludclot Artattack"]
    private static let fixtureBPMs: [Double] = [172, 174, 170, 165, 176]
    private static let fixtureCamelots = ["8A", "9A", "8B", "6A", "9B"]

    public func resolve(_ track: Track) async -> Track {
        try? await Task.sleep(for: .seconds(1.5))
        var resolved = track
        let i = track.position % Self.fixtureArtists.count
        resolved.artist = Self.fixtureArtists[i]
        resolved.title = Self.fixtureTitles[i]
        resolved.bpm = Self.fixtureBPMs[i]
        resolved.camelot = Self.fixtureCamelots[i]
        resolved.matchConfidence = 0.75
        resolved.resolutionState = .resolved
        return resolved
    }
}
