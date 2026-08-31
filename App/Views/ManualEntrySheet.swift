import SwiftUI
import VinylSetBuilderCore

/// **MAN-01 through MAN-04 on screen.** Not an error dialog — the routine path.
///
/// Phase 7 measured the bundled corpus at 0 of 35 against this collection and the last
/// end-to-end run left 8 of 12 records out of the set, so this sheet gets opened more often than
/// the camera does. That single fact decides the layout, exactly as it decided the inspect
/// sheet's:
///
/// - **Every field arrives filled.** MAN-03: the tempo is pre-filled from the crate's own median
///   rather than starting empty, so the common case is *confirm*, not *type*.
/// - **The key is a grid, never a keyboard.** MAN-02: one tap out of 24, inside the two-tap
///   bound with one to spare. Typing "11B" is three keystrokes and a chance to enter "1B", and a
///   wrong key is worse than no key because the sequencer cannot know a wrong one is wrong.
/// - **No modes and no confirmations.** Save and Close are always on screen, never scrolled away.
///
/// The sheet holds **no rules**: prefill precedence, folding, trimming and the `.manual` mark all
/// live in `ManualEntryDraft` and were tested there.
struct ManualEntrySheet: View {
    let track: Track
    let neighbours: [Track]
    let onSave: (Track) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ManualEntryDraft

    init(track: Track, neighbours: [Track], onSave: @escaping (Track) -> Void) {
        self.track = track
        self.neighbours = neighbours
        self.onSave = onSave
        _draft = State(initialValue: ManualEntryDraft(track: track, neighbours: neighbours))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identityFields
                    tempoField
                    keyGrid
                }
                .padding(16)
            }
            Divider()
            saveButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("manual-entry-sheet")
    }

    // MARK: Always on screen

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button("Close") { dismiss() }
                .accessibilityIdentifier("manual-close-button")
            Spacer(minLength: 12)
            // The raw read, so the typist can see what the camera actually saw while correcting
            // it. Never `VinylEntry.label` (D-03-6) — it demands a resolved candidate, and an
            // unresolved record is the whole reason this sheet is open.
            Text(track.rawOCRText.isEmpty ? "New track" : track.rawOCRText)
                .font(.headline)
                .lineLimit(1)
                .accessibilityIdentifier("manual-entry-title")
            Spacer(minLength: 12)
            Button("Close") { }.opacity(0).disabled(true).accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var saveButton: some View {
        Button {
            onSave(draft.applied(to: track))
            dismiss()
        } label: {
            Text("Save").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(16)
        .accessibilityIdentifier("manual-save-button")
    }

    // MARK: MAN-01 — artist and title

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Artist", text: $draft.artist, identifier: "manual-artist-field")
            field("Title", text: $draft.title, identifier: "manual-title-field")
        }
    }

    private func field(_ label: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.55), lineWidth: 1))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(identifier)
        }
    }

    // MARK: MAN-03 — the tempo, never empty

    private var tempoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BPM")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
            HStack(spacing: 8) {
                // One tap for the correction actually made in practice — the prefill is a
                // neighbour's tempo, so it is usually right or one out. Typing is for when it
                // is nowhere near.
                stepper("minus", label: "Lower the tempo by one") { draft.nudgeBPM(by: -1) }
                TextField("BPM", text: $draft.bpmText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.55), lineWidth: 1))
                    .accessibilityIdentifier("manual-bpm-field")
                stepper("plus", label: "Raise the tempo by one") { draft.nudgeBPM(by: 1) }
            }
        }
    }

    private func stepper(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "\(symbol).circle")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("manual-bpm-\(symbol)")
    }

    // MARK: MAN-02 — the wheel as a grid

    private var keyGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
            // Six columns puts each twelve-code block on exactly two rows, so minor and major
            // stay visually separate without a second heading.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                      spacing: 6) {
                ForEach(ManualEntryDraft.camelotGrid, id: \.self) { code in
                    Button {
                        // Tapping the selected code clears it — a mis-tap is undone by the same
                        // control that made it, with no separate "clear" affordance to find.
                        draft.camelot = draft.camelot == code ? nil : code
                    } label: {
                        Text(code)
                            .font(.caption.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    // Solid fill, not `.thinMaterial` — the same move defect V4 forced on the
                    // badge pair. A translucent capsule over a white ground is a white capsule.
                    .background(draft.camelot == code ? Color.accentColor : Color(uiColor: .tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(draft.camelot == code ? Color.white : Color.primary)
                    .accessibilityIdentifier("manual-key-\(code)")
                }
            }
        }
    }
}
