import Foundation

/// D-03-4 — Act I does not segment. One track line per trusted observation, in reading order.
///
/// ponytail: deliberately dumb. No angle clustering, no side-marker splitting, no noise
/// filtering — that is Phase 6 (SEG-01…06/08), and a second half-implementation here would be
/// work Phase 11 deletes. The ceiling is real and useful: the draft arrives **over-split**, so
/// the correction sheet's merge is exercised on the first tap against real data.
public struct FixtureLineSegmenter: LabelSegmenting {
    public init() {}

    public func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> LabelSegmentation {
        // conf >= 1.0 is the whole trusted tier: the spike measured confidence as effectively
        // binary (1.00 / 0.50 / 0.30, nothing between), so a fractional threshold would be
        // inventing precision the reader does not have.
        let tracks = observations
            .filter { $0.confidence >= 1.0 }
            .enumerated()
            .map { offset, observation in
                Track(vinylID: vinylID, side: side, position: offset,
                      rawOCRText: observation.text, resolutionState: .pending)
            }
        return LabelSegmentation(tracks: tracks)
    }
}
