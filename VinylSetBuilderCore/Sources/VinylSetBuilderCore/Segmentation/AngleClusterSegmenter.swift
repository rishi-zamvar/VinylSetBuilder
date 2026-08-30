import CoreGraphics
import Foundation

/// SEG-01…06 and SEG-08 — the real segmenter.
///
/// It clusters by BASELINE ANGLE, because the record sits rotated inside its sleeve and each
/// physical surface therefore forms its own angle cluster (research/OCR-SPIKE.md, Finding 2:
/// IMG_0498 reads −90° for the sleeve against +13° for the label, IMG_0503 −90° against +150°).
/// There is no label-centre detection, no circle finding and no polar unwrapping here, and
/// none is wanted: the owner photographs whole 12" sleeves flat on a counter, so radial
/// clustering would be clustering around the wrong object.
public struct AngleClusterSegmenter: LabelSegmenting {
    /// Two observations join the same surface within this much baseline difference. 20° is
    /// comfortably wider than the ±3° a single printed line wanders and far narrower than the
    /// smallest surface separation the corpus contains (26°, IMG_0505). Measured: 10°, 15°, 20°
    /// and 25° all score 9 of 12; 30° and 40° score 8, where the two surfaces start to merge.
    public let angleTolerance: Double
    /// A line break is a perpendicular gap wider than this many median cap heights.
    ///
    /// **The one tuned constant in this phase.** Measured over the twelve fixtures with this
    /// implementation: 0.2 → 8 usable, 0.3 → 8, **0.4/0.5/0.6/0.7 → 9**, 0.8 → 7, 1.5 → 6. The
    /// chosen value sits in the middle of a four-wide plateau rather than on a spike, which is
    /// the only reason to trust a constant fitted to its own corpus at all — and it WAS fitted
    /// to these twelve, with no held-out set.
    ///
    /// (An earlier throwaway sketch of this pipeline scored 10 at 0.5. It differed on IMG_0500
    /// only, and the number that counts is this implementation's.)
    public let lineGapFactor: Double
    /// The EXIF orientation the observations were read at. Applied here and nowhere else
    /// (OCR-02). All twelve fixtures are `.right`, which is why that is the default.
    public let orientation: PhotoOrientation

    public init(angleTolerance: Double = 20 * .pi / 180,
                lineGapFactor: Double = 0.5,
                orientation: PhotoOrientation = .right) {
        self.angleTolerance = angleTolerance
        self.lineGapFactor = lineGapFactor
        self.orientation = orientation
    }

    // MARK: - the pipeline

    public func segment(_ observations: [TextObservation],
                        vinylID: UUID, side: Side) -> LabelSegmentation {
        var catalogueNumber: String?
        var kept: [TextObservation] = []
        for raw in observations where TrackTextFilter.isTrusted(raw) {          // SEG-08
            let upright = ObservationGeometry.upright(raw, orientation: orientation)  // OCR-02
            if catalogueNumber == nil,
               let number = TrackTextFilter.catalogueNumber(in: upright.text) {  // SEG-03
                catalogueNumber = number
                continue
            }
            if TrackTextFilter.isNoise(upright.text) { continue }                // SEG-03
            kept.append(upright)
        }

        var clusters = angleClusters(kept)                                        // SEG-02
        clusters = removingCrossClusterRepeats(clusters)
        clusters = clusters.map(collapsingNearDuplicates).filter { !$0.isEmpty }

        let sides = statedSides(in: clusters)                                     // SEG-04
        let lines = trackLines(clusters: clusters, kept: kept, sides: sides)
        let tracks = lines.enumerated().map { offset, text in
            Track(vinylID: vinylID, side: side, position: offset,
                  rawOCRText: text, resolutionState: .pending)
        }
        return LabelSegmentation(tracks: tracks, catalogueNumber: catalogueNumber,
                                 sides: sides.map(\.name))
    }

    // MARK: - SEG-02: clustering by baseline angle

    /// Gap clustering on a circle. Sorted by angle, split wherever the step exceeds the
    /// tolerance, then the first and last groups are merged if they meet across ±π.
    ///
    /// Takes RAW observations and returns upright ones, so a caller that wants to look at the
    /// clusters sees exactly what the pipeline saw.
    public func angleClusters(_ observations: [TextObservation]) -> [[TextObservation]] {
        let upright = observations.map { ObservationGeometry.upright($0, orientation: orientation) }
        return clusters(of: upright)
    }

    private func clusters(of upright: [TextObservation]) -> [[TextObservation]] {
        guard !upright.isEmpty else { return [] }
        let sorted = upright.sorted { $0.baselineAngle < $1.baselineAngle }
        var groups: [[TextObservation]] = [[sorted[0]]]
        for observation in sorted.dropFirst() {
            let previous = groups[groups.count - 1].last!.baselineAngle
            if abs(observation.baselineAngle - previous) <= angleTolerance {
                groups[groups.count - 1].append(observation)
            } else {
                groups.append([observation])
            }
        }
        if groups.count > 1,
           let first = groups.first?.first?.baselineAngle,
           let last = groups.last?.last?.baselineAngle,
           abs((first + 2 * .pi) - last) <= angleTolerance {
            groups[0] = groups.removeLast() + groups[0]
        }
        return groups
    }

    /// A string read in two different angle clusters is the sleeve and the record saying the
    /// same name: the artist, or the label. It is never one of the record's tracks.
    ///
    /// Fuzzy, because the second reading is usually worse than the first — IMG_0505 returns
    /// `DRUMSOUND &` on the sleeve and `RUMSOUND &` on the label.
    private func removingCrossClusterRepeats(_ clusters: [[TextObservation]]) -> [[TextObservation]] {
        guard clusters.count > 1 else { return clusters }
        return clusters.enumerated().map { index, cluster in
            cluster.filter { observation in
                let key = TrackTextFilter.alphanumeric(observation.text)
                return !clusters.enumerated().contains { other, elsewhere in
                    other != index && elsewhere.contains {
                        FuzzyMatch.isClose(key, TrackTextFilter.alphanumeric($0.text))
                    }
                }
            }
        }.filter { !$0.isEmpty }
    }

    /// `Da Lick` read four times off one sleeve is one track. First reading wins.
    private func collapsingNearDuplicates(_ cluster: [TextObservation]) -> [TextObservation] {
        var unique: [TextObservation] = []
        for observation in cluster {
            let key = TrackTextFilter.alphanumeric(observation.text)
            if !unique.contains(where: { FuzzyMatch.isClose(key, TrackTextFilter.alphanumeric($0.text)) }) {
                unique.append(observation)
            }
        }
        return unique
    }

    // MARK: - SEG-04: side markers, in preference to geometry

    private func statedSides(in clusters: [[TextObservation]]) -> [SideMarker] {
        var found: [SideMarker] = []
        for observation in clusters.flatMap({ $0 }) {
            guard let marker = TrackTextFilter.sideMarker(in: observation.text) else { continue }
            if let existing = found.firstIndex(where: { $0.name == marker.name }) {
                // `SIDE A` then `A: High Down` — keep whichever reading carries the title.
                if found[existing].title.isEmpty { found[existing] = marker }
            } else {
                found.append(marker)
            }
        }
        return found
    }

    // MARK: - the track lines

    private func trackLines(clusters: [[TextObservation]],
                            kept: [TextObservation],
                            sides: [SideMarker]) -> [String] {
        // A record that names two or more sides has told you how many tracks it has, and it is
        // a better witness than any geometry. At least one side must carry a title, or the
        // sleeve merely printed two headers.
        if sides.count >= 2, sides.contains(where: { !$0.title.isEmpty }) {
            return sides.map { $0.title.isEmpty ? $0.name : "\($0.name): \($0.title)" }
        }
        guard let best = clusters.max(by: { left, right in
            (left.count, left.reduce(0) { $0 + $1.text.count })
                < (right.count, right.reduce(0) { $0 + $1.text.count })
        }) else { return [] }

        // ponytail: a fitted heuristic, and marked as one. IMG_0507's entire trusted, non-noise
        // reading is the single word `cemenic`; one scrap is not a track listing. The ceiling:
        // a genuine one-track white label whose only legible word is short would read as zero.
        // Upgrade path is Phase 7 — if the resolver matches the scrap to a release, keep it.
        if kept.count == 1, TrackTextFilter.alphanumeric(kept[0].text).count < 8 { return [] }

        var lines = groupIntoLines(best).map { line in
            line.map(\.text).joined(separator: " ")
        }
        // The artist is not a track. `DJ`, `MC`, `ft` and `feat` are the only markers in this
        // corpus that say so without a discography, and Phase 7 is what says so properly.
        lines = lines.filter { !TrackTextFilter.normalised($0).contains(/\b(DJ|MC|FT|FEAT)\b/) }
        var unique: [String] = []
        for line in lines where !unique.contains(where: {
            FuzzyMatch.isClose(TrackTextFilter.alphanumeric(line), TrackTextFilter.alphanumeric($0))
        }) {
            unique.append(line)
        }
        // SEG-05: `(VIP)`, `(Remix)`, `Dave Angel Mix` attach to the track above.
        var merged: [String] = []
        for line in unique {
            if !merged.isEmpty, TrackTextFilter.isVersionQualifier(line) {
                merged[merged.count - 1] += " \(line)"
            } else {
                merged.append(line)
            }
        }
        return merged
    }

    /// Project each box centre onto the perpendicular of the cluster's mean baseline and split
    /// where the gap exceeds `lineGapFactor` median cap heights. Within a line, order along the
    /// reading direction.
    private func groupIntoLines(_ cluster: [TextObservation]) -> [[TextObservation]] {
        guard !cluster.isEmpty else { return [] }
        let mean = cluster.reduce(0) { $0 + $1.baselineAngle } / Double(cluster.count)
        let across = CGPoint(x: -sin(mean), y: cos(mean))
        let along = CGPoint(x: cos(mean), y: sin(mean))
        func project(_ observation: TextObservation, _ axis: CGPoint) -> CGFloat {
            observation.boundingBox.midX * axis.x + observation.boundingBox.midY * axis.y
        }
        let heights = cluster.map {
            ObservationGeometry.capHeight(width: $0.boundingBox.width,
                                          height: $0.boundingBox.height,
                                          angle: $0.baselineAngle)
        }.sorted()
        let threshold = heights[heights.count / 2] * CGFloat(lineGapFactor)

        let ordered = cluster.sorted { project($0, across) > project($1, across) }
        var lines: [[TextObservation]] = [[ordered[0]]]
        for observation in ordered.dropFirst() {
            let previous = project(lines[lines.count - 1].last!, across)
            if abs(project(observation, across) - previous) <= threshold {
                lines[lines.count - 1].append(observation)
            } else {
                lines.append([observation])
            }
        }
        return lines.map { $0.sorted { project($0, along) < project($1, along) } }
    }
}
