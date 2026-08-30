import SwiftUI
import VinylSetBuilderCore

/// SEQ-11's pixels: a BPM badge and a Camelot badge, always both present. `isIncomplete`
/// dims them — it never hides them, so a missing value still occupies its row's space.
struct BadgePairView: View {
    let badges: TrackBadges

    var body: some View {
        HStack(spacing: 6) {
            badge(badges.bpm)
            badge(badges.key)
        }
        .foregroundStyle(badges.isIncomplete ? .secondary : .primary)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }
}
