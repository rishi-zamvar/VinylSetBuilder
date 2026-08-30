import SwiftUI
import VinylSetBuilderCore

/// SEQ-07's one collapsed section. Unresolved and excluded records share this single view —
/// there is no second section — each row prints the sequencer's own `reason` verbatim.
/// The caller (plan 01-08) omits this view entirely when `CrateRows.showsNotIncludedSection`
/// is false; this view does not decide its own visibility.
struct NotIncludedSectionView: View {
    let rows: [NotIncludedRow]
    let header: String
    @State private var expanded = false      // "collapsed" per SEQ-07 — starts closed

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(row.label)
                        Spacer()
                        BadgePairView(badges: row.badges)
                    }
                    Text(row.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text(header)
        }
    }
}
