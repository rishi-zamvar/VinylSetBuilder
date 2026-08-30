import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - Parsing (ported from walkman-dj/tests/test_rekordbox_import.py)

@Test("Camelot code passes through unchanged")
func test_givenCamelotCode_whenParsed_thenPassesThrough() {
    #expect(Camelot.parse("4A")?.code == "4A")
    #expect(Camelot.parse("12B")?.code == "12B")
}

@Test("Musical key converts to Camelot")
func test_givenMusicalKey_whenParsed_thenConvertsToCamelot() {
    #expect(Camelot.parse("Am")?.code == "8A")
    #expect(Camelot.parse("C")?.code == "8B")
    #expect(Camelot.parse("F#m")?.code == "11A")
    #expect(Camelot.parse("Ebm")?.code == "2A")
}

@Test("Garbage input returns nil, with the bare-'B' exception")
func test_givenGarbage_whenParsed_thenReturnsNil() {
    #expect(Camelot.parse(nil) == nil)
    #expect(Camelot.parse("") == nil)
    #expect(Camelot.parse("nonsense") == nil)
    #expect(Camelot.parse("13A") == nil)
    #expect(Camelot.parse("0A") == nil)
    #expect(Camelot.parse("A") == nil)
    #expect(Camelot.parse("8C") == nil)

    // Deliberate exception: "B" is a valid musical key (B major) and must parse,
    // not be swallowed by the "bare Camelot letter" garbage rule above.
    #expect(Camelot.parse("B")?.code == "1B")
}

// MARK: - Distance (D1: flat hops, +1 for a letter change)

@Test("Same key has zero distance")
func test_givenSameKey_whenDistanceComputed_thenZero() {
    #expect(Camelot("8A")!.distance(to: Camelot("8A")!) == 0)
}

@Test("Adjacent hour is one hop")
func test_givenAdjacentHour_whenDistanceComputed_thenOne() {
    #expect(Camelot("8A")!.distance(to: Camelot("9A")!) == 1)
    #expect(Camelot("8A")!.distance(to: Camelot("7A")!) == 1)
}

@Test("Relative major/minor is one hop")
func test_givenRelativeMajorMinor_whenDistanceComputed_thenOne() {
    #expect(Camelot("8A")!.distance(to: Camelot("8B")!) == 1)
    #expect(Camelot("11B")!.distance(to: Camelot("11A")!) == 1)
}

@Test("The wheel wraps to the shortest arc")
func test_givenWheelWrap_whenDistanceComputed_thenShortestArc() {
    #expect(Camelot("12A")!.distance(to: Camelot("1A")!) == 1)
    #expect(Camelot("1A")!.distance(to: Camelot("12A")!) == 1)
    #expect(Camelot("11A")!.distance(to: Camelot("2A")!) == 3)
}

@Test("Hour and letter change add together")
func test_givenHourAndLetterChange_whenDistanceComputed_thenHopsPlusOne() {
    #expect(Camelot("12B")!.distance(to: Camelot("1A")!) == 2)
    #expect(Camelot("8A")!.distance(to: Camelot("2B")!) == 7)
}

@Test("Six hops is the maximum on the 12-ring, exhaustively")
func test_givenOppositeHours_whenDistanceComputed_thenSixIsTheMaximumHopCount() {
    #expect(Camelot("1A")!.distance(to: Camelot("7A")!) == 6)

    let allCodes = (1...12).flatMap { hour in ["A", "B"].map { "\(hour)\($0)" } }
    let allCamelots = allCodes.compactMap { Camelot($0) }
    #expect(allCamelots.count == 24)
    for a in allCamelots {
        for b in allCamelots {
            #expect(a.distance(to: b) <= 7)
            #expect(a.distance(to: b) >= 0)
        }
    }
}

// MARK: - Ported table spot checks

@Test("Ported major/minor tables match walkman-dj's camelot.py value for value")
func test_givenPortedTables_whenSpotChecked_thenMatchPython() {
    #expect(Camelot.majorTable["C"] == 8)
    #expect(Camelot.minorTable["A"] == 8)
    #expect(Camelot.minorTable["F#"] == 11)
    #expect(Camelot.minorTable["Eb"] == 2)
}
