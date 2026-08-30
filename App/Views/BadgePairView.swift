import SwiftUI
import VinylSetBuilderCore

/// SEQ-11's pixels: a BPM badge and a Camelot badge, always both present. `isIncomplete`
/// dims them — it never hides them, so a missing value still occupies its row's space.
///
/// **Defect V4, closed by measurement** (`UITests/BadgeContrastUITests.swift`). The pair used
/// to render `.secondary` ink on a `.thinMaterial` capsule: light grey on light grey, on a
/// white List ground. Measured at **4.01:1**, under WCAG 2.2 AA's 4.5:1 for 12 pt text.
/// Both halves of SEQ-11's rule are asserted on real pixels, so neither can be satisfied at
/// the other's expense — legible AND still quieter than a complete pair.
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
        // Dimmed by the OPACITY OF REAL INK, not by a system colour that resolves to near-white
        // on a near-white ground. `.secondary` here IS defect V4.
        .foregroundStyle(badges.isIncomplete ? AnyShapeStyle(.primary.opacity(0.7))
                                             : AnyShapeStyle(.primary))
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
            // SOLID, not `.thinMaterial` — the same "solid ground, not translucent material"
            // move plan 03-03 already made for the capture strip's status pill. A translucent
            // capsule over a white List is a white capsule, and it takes the ink's contrast
            // with it. Do not reintroduce a material here.
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}
