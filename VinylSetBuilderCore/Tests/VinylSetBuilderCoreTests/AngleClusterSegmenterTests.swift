import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - the committed ground truth

private struct ExpectedFixture: Decodable {
    let file: String
    let tracks: Int
    let catalogue: String?
}

private struct ExpectedScores: Decodable {
    struct Baseline: Decodable { let usableTrackCounts: Int; let catalogueOf: Int }
    let fixtures: [ExpectedFixture]
    let baseline: Baseline
}

private func expectedScores() throws -> ExpectedScores {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // VinylSetBuilderCoreTests
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // VinylSetBuilderCore
        .deletingLastPathComponent()    // repo root
        .appendingPathComponent(".planning/phases/06-ocr-segmentation/expected-scores.json")
    return try JSONDecoder().decode(ExpectedScores.self, from: Data(contentsOf: url))
}

private func segmentation(for fixture: (file: String, observations: [TextObservation]))
    -> LabelSegmentation {
    AngleClusterSegmenter().segment(fixture.observations, vinylID: UUID(), side: .a)
}

// MARK: - SEG-01: the measured gate, on the recorded corpus

@Test("SEG-01: the segmenter returns the hand-scored track count on at least 9 of 12 fixtures")
func test_givenTheTwelveFixtures_whenSegmented_thenNineOrMoreTrackCountsAreUsable() throws {
    let expected = try expectedScores()
    var usable = 0
    var report: [String] = []
    for fixture in FixtureObservations.all {
        guard let row = expected.fixtures.first(where: { $0.file == fixture.file }) else {
            Issue.record("\(fixture.file) has no committed expectation"); continue
        }
        let count = segmentation(for: fixture).tracks.count
        if count == row.tracks { usable += 1 }
        report.append("\(fixture.file) expected \(row.tracks) got \(count)")
    }
    let detail = report.joined(separator: "\n")
    #expect(usable >= expected.baseline.usableTrackCounts, "usable \(usable)/12\n\(detail)")
}

@Test("SEG-03: a catalogue number is recovered on at least 5 of the 6 fixtures that carry one")
func test_givenTheTwelveFixtures_whenSegmented_thenTheCatalogueNumbersAreKept() throws {
    let expected = try expectedScores()
    var recovered = 0
    for fixture in FixtureObservations.all {
        guard let row = expected.fixtures.first(where: { $0.file == fixture.file }) else { continue }
        let found = segmentation(for: fixture).catalogueNumber
        if let wanted = row.catalogue {
            if found == wanted { recovered += 1 } else {
                Issue.record("\(fixture.file) wanted \(wanted) got \(found ?? "nil")")
            }
        } else {
            #expect(found == nil, "\(fixture.file) invented catalogue \(found ?? "")")
        }
    }
    #expect(recovered >= expected.baseline.catalogueOf, "recovered \(recovered)/6")
}

@Test("SEG-03: the catalogue number reaches the vinyl entry rather than dying in the segmenter")
func test_givenACapturedItem_whenTurnedIntoAVinylEntry_thenItCarriesItsCatalogueNumber() throws {
    let fixture = try #require(FixtureObservations.all.first { $0.file == "IMG_0503.HEIC" })
    var session = CaptureSession(crateID: UUID())
    let item = CaptureItem(index: 1, photoRef: fixture.file, observations: fixture.observations,
                           sideMarkers: ["A", "AA"], status: .read)
    session.append(item)
    let entry = try #require(session.vinylEntry(for: item.id, segmenter: AngleClusterSegmenter()))
    #expect(entry.catalogueNumber == "TYME012")
}

// MARK: - SEG-02: baseline angle separates physical surfaces

@Test("SEG-02: the sleeve and the record label land in different angle clusters")
func test_givenASleeveAndALabelAtDifferentAngles_whenClustered_thenTheyDoNotMix() throws {
    // IMG_0505: sleeve type at about -92 degrees, the rotated label at about -66. The spike
    // measured that separation on four of the twelve fixtures.
    let fixture = try #require(FixtureObservations.all.first { $0.file == "IMG_0505.HEIC" })
    let clusters = AngleClusterSegmenter().angleClusters(fixture.observations)
    #expect(clusters.count >= 2, "\(clusters.map { $0.map(\.text) })")
    for cluster in clusters {
        let angles = cluster.map(\.baselineAngle)
        let spread = (angles.max() ?? 0) - (angles.min() ?? 0)
        #expect(spread <= 20 * .pi / 180 + 1e-9, "cluster spread \(spread)")
    }
}

@Test("SEG-02: clustering wraps around, so +179 and -179 are one surface not two")
func test_givenAnglesEitherSideOfPi_whenClustered_thenTheyAreOneCluster() {
    let subject = [observation("ONE TITLE", angle: 179 * .pi / 180),
                   observation("TWO TITLE", angle: -179 * .pi / 180)]
    #expect(AngleClusterSegmenter().angleClusters(subject).count == 1)
}

// MARK: - SEG-04 / SEG-05 / SEG-06

@Test("SEG-04: two side markers split the record in preference to any geometry")
func test_givenTwoSideMarkers_whenSegmented_thenEachSideBecomesOneTrack() throws {
    let fixture = try #require(FixtureObservations.all.first { $0.file == "IMG_0499.HEIC" })
    let result = segmentation(for: fixture)
    #expect(result.sides.count == 2)
    #expect(result.tracks.count == 2)
    #expect(result.tracks.map(\.rawOCRText).contains { $0.contains("DRAGSTAR") })
}

@Test("SEG-05: a version qualifier attaches to the track above instead of starting a new one")
func test_givenAVersionLineBelowATitle_whenSegmented_thenItJoinsTheTrackAbove() {
    let subject = [observation("SUPERSONIC", angle: 0, y: 0.60),
                   observation("Dave Angel Mix", angle: 0, y: 0.40)]
    let result = AngleClusterSegmenter().segment(subject, vinylID: UUID(), side: .a)
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].rawOCRText.contains("Dave Angel Mix"))
}

@Test("SEG-06: fewer than two sides read means a flip side probably exists")
func test_givenTheTwelveFixtures_whenSegmented_thenTheFlipSideInferenceFollowsTheSideCount() {
    for fixture in FixtureObservations.all {
        let result = segmentation(for: fixture)
        #expect(result.expectsFlipSide == (result.sides.count < 2), "\(fixture.file)")
    }
    // The three fixtures whose sleeves state both sides must NOT prompt for a flip.
    for file in ["IMG_0499.HEIC", "IMG_0503.HEIC", "IMG_0506.HEIC"] {
        let fixture = FixtureObservations.all.first { $0.file == file }!
        #expect(!segmentation(for: fixture).expectsFlipSide, "\(file)")
    }
}

// MARK: - SEG-08 and the empty case

@Test("SEG-08: untrusted observations never become track lines")
func test_givenOnlyUntrustedText_whenSegmented_thenNoTrackIsProduced() {
    let subject = [observation("SUPERSONIC", angle: 0, confidence: 0.5),
                   observation("DUBTRACK", angle: 0, confidence: 0.3)]
    #expect(AngleClusterSegmenter().segment(subject, vinylID: UUID(), side: .a).tracks.isEmpty)
}

@Test("SEG-01: an empty read segments to nothing rather than crashing")
func test_givenNoObservations_whenSegmented_thenTheResultIsEmpty() {
    let result = AngleClusterSegmenter().segment([], vinylID: UUID(), side: .b)
    #expect(result.tracks.isEmpty)
    #expect(result.catalogueNumber == nil)
    #expect(result.expectsFlipSide)
}

@Test("SEG-01: tracks carry the vinyl id, the side, and a dense ascending position")
func test_givenAFixture_whenSegmented_thenEveryTrackIsAddressable() throws {
    let fixture = try #require(FixtureObservations.all.first { $0.file == "IMG_0505.HEIC" })
    let vinylID = UUID()
    let tracks = AngleClusterSegmenter().segment(fixture.observations, vinylID: vinylID, side: .b).tracks
    #expect(tracks.map(\.position) == Array(0..<tracks.count))
    #expect(tracks.allSatisfy { $0.vinylID == vinylID && $0.side == .b })
    #expect(tracks.allSatisfy { !$0.rawOCRText.isEmpty })
}

// MARK: - helper

private func observation(_ text: String, angle: Double, y: CGFloat = 0.5,
                         confidence: Float = 1.0) -> TextObservation {
    // Built in RAW buffer space: the segmenter is what applies the orientation transform, and a
    // helper that pre-rotated would be applying it twice.
    TextObservation(text: text,
                    boundingBox: CGRect(x: y, y: 0.30, width: 0.02, height: 0.30),
                    confidence: confidence, baselineAngle: angle - .pi / 2)
}
