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
                // **Tempo and key first, identity second, and that order is measured rather
                // than aesthetic.** On the records this sheet actually gets opened for, the
                // artist and title are unknowable — white labels and dubplates are in no
                // database — and what the DJ supplies is the tempo and the key, because that is
                // all the sequencer needs to place the record. Putting them at the top also
                // keeps the 24-code grid above the fold, so MAN-02's one tap stays one tap
                // instead of one scroll and one tap.
                VStack(alignment: .leading, spacing: 20) {
                    tempoField
                    keyGrid
                    identityFields
                }
                .padding(16)
            }
            // Scroll-to-dismiss rather than a keyboard accessory bar, and that is MEASURED,
            // not a preference. A `ToolbarItemGroup(placement: .keyboard)` renders an accessory
            // bar directly above the keyboard — which on this sheet sat exactly over the field
            // BELOW the focused one, so the title field and its clear button were covered and
            // every tap on them went to the toolbar instead. XCUITest reported it as "neither
            // element nor any descendant has keyboard focus", which is the accessory bar
            // eating the tap. Save lives in the header and is never under the keyboard, so
            // there is nothing an accessory bar was needed for.
            .scrollDismissesKeyboard(.interactively)
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
            // **Save lives in the header, not on a bottom bar, and that is not a style choice.**
            // A bottom bar sits under the software keyboard: with the tempo field focused it is
            // either covered or pushed off, so committing an edit would cost an extra tap to
            // dismiss the keyboard first. Up here it is reachable at every moment the sheet is
            // open, which is one interaction off MAN-01's budget for free.
            Button("Save") {
                onSave(draft.applied(to: track))
                dismiss()
            }
            .fontWeight(.semibold)
            .accessibilityIdentifier("manual-save-button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            HStack(spacing: 8) {
                TextField(label, text: text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.55), lineWidth: 1))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier(identifier)
                // **MAN-01 arithmetic, not decoration.** The field arrives holding whatever the
                // resolver guessed, and a confident wrong guess is the common case on a record
                // with no catalogue number. Deleting it costs one keystroke per character — the
                // measured worst case went from 8 taps + 40 keystrokes (18.5 s under this
                // phase's cost model) to 8 taps + 16 (13.3 s) on this control alone. It is the
                // single cheapest thing in the sheet.
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear \(label)")
                .accessibilityIdentifier("\(identifier)-clear")
            }
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
