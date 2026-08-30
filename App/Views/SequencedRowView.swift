import SwiftUI
import VinylSetBuilderCore

/// One row in the running order: position, title, trailing badges. Thin projection —
/// all the logic lives in `SequencedRow`/`TrackBadges` (Core), tested there.
struct SequencedRowView: View {
    let row: SequencedRow

    var body: some View {
        HStack {
            Text(row.indexLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .leading)
            Text(row.title)
            Spacer()
            BadgePairView(badges: row.badges)
        }
    }
}
