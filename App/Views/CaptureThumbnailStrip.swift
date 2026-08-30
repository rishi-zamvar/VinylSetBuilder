import SwiftUI
import VinylSetBuilderCore

/// CAP-03 — every vinyl scanned so far in this session, each carrying its own status.
///
/// Fixed-width tiles inside a horizontal `ScrollView`, so twenty-one records scroll rather than
/// shrinking to twenty-one slivers.
struct CaptureThumbnailStrip: View {
    let items: [CaptureItem]
    let onTap: (CaptureItem) -> Void

    private static let tileWidth: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The inflection markup that closed V1, and it fires on this SDK — measured on the
            // crate list, not hoped for. "1 record" / "2 records".
            Text("^[\(items.count) record](inflect: true)")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .accessibilityIdentifier("capture-session-count")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(items) { item in
                        // D-03-2: no photograph bytes enter this repo, so the image is nil for
                        // the whole of Act I and the card renders the record's own OCR text.
                        // Phase 10 passes the real capture here and nothing else moves.
                        Tile(item: item, image: nil) { onTap(item) }
                            .frame(width: Self.tileWidth)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            .frame(height: Self.tileWidth + 34)
            .accessibilityIdentifier("capture-thumbnail-strip")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One record: a square card (a sleeve is square) with its status directly beneath.
    ///
    /// The status sits OUTSIDE the button on purpose. A SwiftUI `Button` merges its label's
    /// children into one accessibility element, which would swallow `capture-thumb-status-{n}`
    /// and leave 03-05 with no way to read the 6/5/1 tally back off the screen.
    private struct Tile: View {
        let item: CaptureItem
        let image: Image?
        let onTap: () -> Void

        var body: some View {
            VStack(spacing: 6) {
                Button(action: onTap) { card }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("capture-thumb-\(item.index)")

                Text(item.status.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(Self.statusColour(item.status), in: Capsule())
                    .accessibilityIdentifier("capture-thumb-status-\(item.index)")
            }
        }

        private var card: some View {
            ZStack {
                if let image {
                    image.resizable().scaledToFill()
                    Color.black.opacity(0.45)
                } else {
                    Color(.secondarySystemBackground)
                }
                Text(item.displayLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(image == nil ? Color.primary : Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(6)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
        }

        /// **V4, not repeated.** Phase 2's placeholder badges were `.secondary` on
        /// `.thinMaterial` — light grey on light grey, very nearly invisible. The one piece of
        /// information this strip exists to carry gets a solid, saturated ground and white
        /// text instead: each of the three is legible on its own and distinct from the others.
        static func statusColour(_ status: CaptureItemStatus) -> Color {
            switch status {
            // Neutral and unsaturated on purpose: `.reading` is not a verdict, and giving it
            // one of the three verdict colours would make a record look scored before it is.
            case .reading: return Color(red: 0.29, green: 0.29, blue: 0.31)
            case .read:    return Color(red: 0.09, green: 0.42, blue: 0.20)
            case .partial: return Color(red: 0.65, green: 0.37, blue: 0.02)
            case .unread:  return Color(red: 0.64, green: 0.10, blue: 0.10)
            }
        }
    }
}
