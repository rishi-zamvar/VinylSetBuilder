import SwiftUI
import VinylSetBuilderCore

/// OCR-04 — every text observation one photograph produced, verbatim, with the confidence it
/// came back with.
///
/// **The untrusted reads stay in, and that is the whole requirement.** The row worth looking at
/// when a record reads badly is precisely the one the segmenter threw away: `IMG_0498` came back
/// with `зali/ti| Fuck W` at 0.30 and `Remi:600` at 0.30, and neither appears anywhere else in
/// the app. Hiding them would hide the evidence a bad read is diagnosed from.
///
/// The projection — the 1-based numbering, the confidence string, the trusted tier — is
/// `RawObservationRows.make`, built and tested in Core in plan 03-02. This view formats nothing.
/// A second formatting rule in a view is how two screens start showing different numbers for the
/// same track, which is exactly the rule `TrackBadges` already follows.
struct RawObservationListView: View {
    let observations: [TextObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(RawObservationRows.make(observations)) { row in
                Row(row: row)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Row: View {
        let row: RawObservationRow

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(row.id)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 18, alignment: .trailing)

                Text(row.text)
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // **V4, not repeated.** Phase 2's placeholder badges were `.secondary` on
                // `.thinMaterial` — light grey on light grey, all but invisible, and no test
                // could see it. The confidence is the one number this screen exists to show, so
                // it gets a solid saturated ground and white text: legible on its own, and the
                // trusted/untrusted distinction is carried by colour AND by the number, never by
                // colour alone.
                Text(row.confidence)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Self.confidenceColour(row.isTrusted), in: Capsule())
            }
            .padding(.vertical, 6)
            // One leaf element carrying both halves, so `inspect-raw-obs-{n}` resolves as the
            // `staticText` the frozen contract names rather than as a container of three.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel("\(row.text) \(row.confidence)")
            .accessibilityIdentifier("inspect-raw-obs-\(row.id)")
        }

        static func confidenceColour(_ isTrusted: Bool) -> Color {
            isTrusted ? Color(red: 0.09, green: 0.42, blue: 0.20)
                      : Color(red: 0.64, green: 0.10, blue: 0.10)
        }
    }
}
