import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

/// The twelve real photographs, transcoded by `Scripts/generate-ocr-fixtures.sh` from the
/// owner's own OCR run. These tests exist so a generator that emitted an empty, truncated or
/// placeholder table cannot pass — every assertion below names a real measured value.
///
/// Counts are measured from `.local/ocr/ocr2_out.json` (the second, 104-observation run).
/// The 88-trusted figure quoted in `OCR-SPIKE.md` finding 4 belongs to the FIRST run
/// (`ocr_out.json`, 101 observations, 88 at 1.00). The second run reads 104 / 89.
private let expectedFixtureCount = 12
private let expectedObservationCount = 104
private let expectedTrustedCount = 89

private let bannedPurityTokens = [
    "AVFoundation", "Vision", "UIKit", "AppKit", "SwiftUI", "SwiftData",
    "URLSession", "URLRequest", "URLProtocol",
]

@Test("CAP-03: the fixture table holds all twelve records in ascending filename order")
func test_givenTheGeneratedFixtureTable_whenListed_thenItHoldsTwelveRecordsInFilenameOrder() {
    let files = FixtureObservations.all.map(\.file)

    #expect(files.count == expectedFixtureCount)
    #expect(files.first == "IMG_0498.HEIC")
    #expect(files.last == "IMG_0509.HEIC")
    #expect(files == files.sorted(), "the table is no longer in ascending filename order")
    #expect(Set(files).count == expectedFixtureCount, "a filename is duplicated")
}

@Test("CAP-03: the table carries 104 observations, 89 of them trusted")
func test_givenTheGeneratedFixtureTable_whenCounted_thenItMatchesTheRealOCRRun() {
    let all = FixtureObservations.all.flatMap(\.observations)

    #expect(all.count == expectedObservationCount)
    #expect(all.filter { $0.confidence >= 1.0 }.count == expectedTrustedCount)
    // Two-sided: the untrusted remainder is the complement, so neither tier can drift alone.
    #expect(all.filter { $0.confidence < 1.0 }.count
            == expectedObservationCount - expectedTrustedCount)
    #expect(FixtureObservations.all.allSatisfy { !$0.observations.isEmpty },
            "a fixture came through with no observations at all")
}

@Test("D-03-1: real strings survive transcoding, quotes and all")
func test_givenTheGeneratedFixtureTable_whenSearched_thenItCarriesTheRealSpotCheckStrings() throws {
    func texts(_ file: String) throws -> [String] {
        let entry = try #require(FixtureObservations.all.first { $0.file == file })
        return entry.observations.map(\.text)
    }

    let f0499 = try texts("IMG_0499.HEIC")
    let f0503 = try texts("IMG_0503.HEIC")
    let f0500 = try texts("IMG_0500.HEIC")

    // Carries an embedded double quote — the escaper's own regression test.
    #expect(f0499.contains(#"AA "Elementz""#))
    #expect(f0503.contains("TYME 012"))
    // Non-ASCII must survive as UTF-8, not as mojibake or an escape sequence.
    #expect(f0500.contains("Invocación"))
}

@Test("D-03-1: angles are radians, and a skipped conversion reddens")
func test_givenTheGeneratedFixtureTable_whenAnAngleIsRead_thenItIsRadiansNotDegrees() throws {
    let first = try #require(FixtureObservations.all.first)
    #expect(first.file == "IMG_0498.HEIC")
    let observation = try #require(first.observations.first)

    let degrees = -93.94518796476527
    let radians = degrees * .pi / 180

    #expect(abs(observation.baselineAngle - radians) < 1e-6)
    // Negative control: the same value must NOT be the raw degree figure. Without this half
    // a generator that forgot the conversion would pass the assertion above on nothing.
    #expect(abs(observation.baselineAngle - degrees) >= 1e-6)
}

@Test("D-03-1: every bounding box is inside the unit square")
func test_givenTheGeneratedFixtureTable_whenBoxesAreRead_thenAllAreNormalized() {
    var offenders: [String] = []
    for entry in FixtureObservations.all {
        for observation in entry.observations {
            let box = observation.boundingBox
            if box.minX < 0 || box.minY < 0 || box.maxX > 1.0001 || box.maxY > 1.0001 {
                offenders.append("\(entry.file): \(observation.text) \(box)")
            }
        }
    }
    #expect(offenders.isEmpty, "bounding boxes outside [0,1]: \(offenders.joined(separator: ", "))")
}

@Test("SETUP-02: no OCR string smuggles a banned purity token into Core")
func test_givenTheGeneratedFixtureTable_whenScanned_thenNoTextCarriesABannedToken() {
    var violations: [String] = []
    for entry in FixtureObservations.all {
        for observation in entry.observations {
            for token in bannedPurityTokens where observation.text.contains(token) {
                violations.append("\(entry.file): \(token) in \(observation.text)")
            }
        }
    }
    #expect(violations.isEmpty, "banned token in fixture text: \(violations.joined(separator: ", "))")
}
