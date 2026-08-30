import SwiftUI
import VinylSetBuilderCore

/// CAP-05 — the inline "you only got one side" banner.
///
/// It is a banner and not a sheet, an alert or a push, because CAP-05's wording is "without
/// leaving the camera" and all three of those leave it. It also never blocks: the shutter and
/// Done stay live behind it, so a person who ignores it keeps shooting.
///
/// **Scan and Skip differ only in whether another photograph follows, and that is honest.**
/// Both dismiss the prompt. There is no second-side *targeting* in Act I because there is
/// nothing to target with: real side detection is Phase 6 (SEG-06, which derives side markers
/// from text instead of reading the hand-scored answer), and a real camera to point at the
/// flipped sleeve is Phase 10.
struct FlipSidePromptView: View {
    let item: CaptureItem
    let onScan: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Only one side read")
                    .font(.footnote.weight(.semibold))
                // Named from the record's own OCR text (D-03-6) — never the vinyl entry's
                // own `label`, which calls every one of these "Vinyl N" (defect V3).
                Text(item.displayLabel)
                    .font(.footnote)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button("Skip") { onSkip() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("capture-flip-skip-button")

            Button("Scan") { onScan() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("capture-flip-scan-button")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.accentColor, lineWidth: 2))
        // `.contain` keeps the two buttons individually queryable while still publishing the
        // banner itself as one element the walk can assert on.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("capture-flip-prompt")
    }
}
