import SwiftUI
import VinylSetBuilderCore

/// SEQ-11's pixels: a BPM badge and a Camelot badge, always both present. `isIncomplete`
/// dims them — it never hides them, so a missing value still occupies its row's space.
struct BadgePairView: View {
    let badges: TrackBadges

    /// The accessibility identifier for the PAIR, as one combined element. Without this the
    /// bucket's badges were unqueryable and V4 could only ever be argued from a photograph.
    let identifier: String

    var body: some View {
        HStack(spacing: 6) {
            badge(badges.bpm)
            badge(badges.key)
        }
        .foregroundStyle(badges.isIncomplete ? .secondary : .primary)
        // One element per pair, so `XCUIElement.screenshot()` crops exactly the thing being
        // measured and no coordinate arithmetic enters the measurement.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }
}
