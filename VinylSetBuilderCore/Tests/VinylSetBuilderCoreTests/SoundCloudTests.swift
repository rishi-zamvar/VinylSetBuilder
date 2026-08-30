import Foundation
import Testing
@testable import VinylSetBuilderCore

// Payload shapes taken from a live SoundCloud call on 2026-08-30.
private func searchPayload() -> [[String: Any]] { [
    ["id": 681384584, "title": "Home", "duration": 156343, "user": ["username": "Caribou."]],
    ["id": 999, "title": "Caribou Essential Mix 2024", "duration": 4740000, "user": ["username": "BBC R1"]],
] }

@Test("BPM-03: duration arrives in milliseconds and is read as seconds")
func test_givenSoundCloudPayload_whenParsed_thenDurationIsSeconds() {
    let tracks = SoundCloudClient.parse(try! JSONSerialization.data(withJSONObject: searchPayload()))
    #expect(tracks.count == 2)
    #expect(abs(tracks[0].seconds - 156.343) < 0.01)
    #expect(tracks[0].username == "Caribou.")
}

@Test("BPM-03: the 79-minute mix is excluded by the duration bound, however well it scores")
func test_givenADJMixInTheResults_whenRanked_thenNotChosen() {
    let tracks = SoundCloudClient.parse(try! JSONSerialization.data(withJSONObject: searchPayload()))
    let chosen = SoundCloudMatcher.best(among: tracks, artist: "Caribou", title: "Home")
    #expect(chosen?.track.id == 681384584)
    // And the mix on its own is no answer at all, not a fallback.
    #expect(SoundCloudMatcher.best(among: [tracks[1]], artist: "Caribou", title: "Home") == nil)
}

@Test("BPM-03: the artist is found in the TITLE when the uploader is a reposter")
func test_givenReposterUpload_whenScored_thenStillMatched() {
    // Measured: "Tory Lanez - Lavender Sunflower" uploaded by "Upnow #1". Comparing the wanted
    // title to the upload title WHOLE scores 0.65 and would be rejected; containment scores it.
    let candidate = SoundCloudTrack(id: 1174807888, title: "Tory Lanez - Lavender Sunflower",
                                    username: "Upnow #1", seconds: 200)
    #expect(SoundCloudMatcher.score(candidate, artist: "Tory Lanez", title: "Lavender Sunflower") == 1.0)
}

@Test("BPM-03: an unrelated upload is rejected rather than accepted as the best of a bad lot")
func test_givenUnrelatedResults_whenRanked_thenNothingChosen() {
    let junk = SoundCloudTrack(id: 5, title: "Deep House Mixtape 47", username: "somebody", seconds: 300)
    #expect(SoundCloudMatcher.best(among: [junk], artist: "Goldie", title: "Terminator") == nil)
}

@Test("the client authenticates once and reuses the token")
func test_givenTwoSearches_whenPerformed_thenOnlyOneTokenRequest() async throws {
    let token = json(["access_token": "abc"])
    let results = HTTPResponse(status: 200,
                               body: try JSONSerialization.data(withJSONObject: searchPayload()))
    let transport = RecordingTransport([{ $0.method == .post ? token : results }])
    let client = SoundCloudClient(transport: transport, clientID: "i", clientSecret: "s", sleeper: { _ in })
    _ = try await client.search("a")
    _ = try await client.search("b")
    let posts = await transport.sent.filter { $0.method == .post }.count
    #expect(posts == 1)
    #expect(await transport.count == 3)
}
