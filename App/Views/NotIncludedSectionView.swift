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
            // One-based within the bucket. SEQ-07's rows had NO identifier at all until now,
            // which is why defects V3 and V4 both had to be argued from photographs rather
            // than queried. `.contain` and not `.combine`: a combined row would swallow the
            // badge pair's own element and the pair would stop being screenshot-able, which
            // is the whole point of giving it one.
            ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(row.label)
                        Spacer()
                        BadgePairView(badges: row.badges,
                                      identifier: "badge-pair-notincluded-\(offset + 1)")
                    }
                    Text(row.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("not-included-row-\(offset + 1)")
            }
        } label: {
            Text(header)
                .accessibilityIdentifier("not-included-section")
        }
    }
}
