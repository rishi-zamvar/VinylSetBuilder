import Foundation
import Testing

private let bannedTokens = [
    "AVFoundation", "Vision", "UIKit", "AppKit", "SwiftUI", "SwiftData",
    "URLSession", "URLRequest", "URLProtocol",
]

private var sourcesDirectory: URL {
    URL(fileURLWithPath: #filePath)      // .../Tests/VinylSetBuilderCoreTests/CorePurityTests.swift
        .deletingLastPathComponent()      // .../Tests/VinylSetBuilderCoreTests
        .deletingLastPathComponent()      // .../Tests
        .deletingLastPathComponent()      // .../VinylSetBuilderCore
        .appendingPathComponent("Sources")
}

@Test("SETUP-02: Core links no camera and no network framework")
func test_givenCoreSources_whenScanned_thenNoCameraOrNetworkSymbolAppears() throws {
    let fm = FileManager.default
    let enumerator = try #require(fm.enumerator(at: sourcesDirectory,
                                                includingPropertiesForKeys: nil))
    var scanned = 0
    var violations: [String] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        scanned += 1
        let text = try String(contentsOf: url, encoding: .utf8)
        for token in bannedTokens where text.contains(token) {
            violations.append("\(url.lastPathComponent): \(token)")
        }
    }
    #expect(scanned > 0, "purity guard scanned no files — the path walk is wrong")
    #expect(violations.isEmpty, "Core purity violated: \(violations.joined(separator: ", "))")
}
