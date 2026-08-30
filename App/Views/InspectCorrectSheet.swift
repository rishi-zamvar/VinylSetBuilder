import SwiftUI
import VinylSetBuilderCore

/// SEG-07 (correct a segmentation result) and OCR-04 (read the text the OCR actually produced),
/// presented from a tap on a thumbnail in the capture strip.
///
/// **This is a routine path, not an error path.** Six of the owner's twelve records read cleanly;
/// the rest are white labels and dubplates that are in no database, so somebody is going to sit
/// here often. That single fact decides the whole layout:
///
/// - **Every operation is one tap.** No cursor placement, no multi-select, no drag, no
///   confirmation dialog, and no mode to enter first. Split and merge are visible buttons on the
///   row rather than swipe actions, because a swipe action is one gesture *plus* one tap.
/// - **The track lines come first and the raw text sits below**, collapsed. The lines are the
///   thing being corrected; the raw text is reference material for when a line is wrong.
/// - **The draft arrives over-split, by design** (D-03-4): Act I emits one line per trusted
///   observation, so merge is the first control most records need and it is the easiest to hit.
///
/// The sheet holds **no rules**. Split, merge-up, hand-type, add and the raw-text projection were
/// all built and tested in Core in plan 03-02; this view calls them and renders what comes back.
struct InspectCorrectSheet: View {
    let model: AppModel
    let crateID: UUID
    let item: CaptureItem

    @Environment(\.dismiss) private var dismiss

    /// The edit in progress. A value, local to this sheet, exactly like `CrateDetailModel` on the
    /// crate screen — which is what makes "Close writes nothing" true by construction rather than
    /// by remembering to undo something.
    @State private var draft: SegmentationDraft

    /// Collapsed by default: reference material, not the task. Defect V3 was found only because
    /// somebody expanded a collapsed section and looked, so 03-05 photographs it open.
    @State private var showRawText = false

    init(model: AppModel, crateID: UUID, item: CaptureItem) {
        self.model = model
        self.crateID = crateID
        self.item = item
        let candidates = model.store.crate(crateID)?
            .vinyls.first { $0.id == item.id }?
            .orderedCandidates ?? []
        _draft = State(initialValue: SegmentationDraft(vinylID: item.id, tracks: candidates))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    lines
                    addLineButton
                    rawTextSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            Divider()
            footer
        }
        // `.contain` publishes the sheet itself as one `other` element while leaving every
        // control inside it individually queryable — the pattern `FlipSidePromptView` already
        // proved against the live accessibility tree.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspect-sheet")
    }

    // MARK: Header and footer — always on screen, so Close and Apply are never scrolled away

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button("Close") { dismiss() }
                .accessibilityIdentifier("inspect-close-button")

            Spacer(minLength: 12)

            // Named from the record's own trusted OCR text (D-03-6). The vinyl entry's own
            // `label` property is never called from this screen: it demands a resolved
            // candidate and nothing resolves in Act I, so it would title every sheet "Vinyl N"
            // (defect V3, the owner's call, tracked as U8).
            Text(item.displayLabel)
                .font(.headline)
                .lineLimit(1)
                .accessibilityIdentifier("inspect-title")

            Spacer(minLength: 12)

            // A spacer the width of the Close button, so the title sits centred without a
            // second real control competing with it.
            Button("Close") { }.opacity(0).disabled(true).accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        Button {
            apply()
        } label: {
            Text("Apply").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(16)
        .accessibilityIdentifier("inspect-apply-button")
    }

    // MARK: SEG-07 — the editable lines

    private var lines: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track lines")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.top, 4)

            ForEach(Array(draft.lines.enumerated()), id: \.element.id) { index, line in
                LineRow(number: index + 1,
                        text: textBinding(for: line.id),
                        canMergeUp: index > 0,
                        onSplit: { draft.splitLine(line.id) },
                        onMergeUp: { draft.mergeUp(line.id) })
            }
        }
    }

    /// Typing is the third of SEG-07's operations and it is available on every line at all
    /// times — there is no "edit" mode to enter, because entering one would make hand-entry two
    /// taps. Writes go through `setText`, which owns the rule that clearing a line to nothing
    /// **removes** it: that is how a junk read is deleted.
    ///
    /// **The equality guard is load-bearing, and it was measured, not anticipated.** A text
    /// field re-publishes its current value through the binding when it takes focus, so tapping
    /// into a freshly added — and therefore empty — line sent `""` straight into `setText`,
    /// deleted the line out from under the cursor, and the keyboard never appeared at all.
    /// Observed three times: once on this plan's first UI run, and twice more after a mutation
    /// revert silently took this guard back out. Writing only on a real change makes an echo
    /// harmless while leaving a deliberate clear-to-delete working exactly as Core tested it.
    private func textBinding(for id: DraftLine.ID) -> Binding<String> {
        Binding(
            get: { draft.lines.first { $0.id == id }?.text ?? "" },
            set: { newText in
                guard let current = draft.lines.first(where: { $0.id == id })?.text,
                      current != newText else { return }
                draft.setText(id, to: newText)
            }
        )
    }

    private var addLineButton: some View {
        // The path for `IMG_0507`: three junk reads and nothing usable, so that record is only
        // enterable by hand. It is representative of the white-label half of the crate, not an
        // exceptional case.
        Button {
            draft.addLine()
        } label: {
            Label("Add a line", systemImage: "plus.circle")
                .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .padding(.top, 12)
        .accessibilityIdentifier("inspect-add-line-button")
    }

    // MARK: OCR-04 — the raw text, below the lines and collapsed

    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A plain button and an `if`, rather than a `DisclosureGroup`, so that
            // `inspect-raw-text-section` resolves as exactly one `button` — a disclosure group
            // publishes its header through a control this app does not otherwise use, and the
            // identifier contract names a button.
            Button {
                showRawText.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showRawText ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                    Text("Raw recognised text (\(item.observations.count))")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(Color.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
            .accessibilityIdentifier("inspect-raw-text-section")

            if showRawText {
                RawObservationListView(observations: item.observations)
            }
        }
        .padding(.top, 16)
    }

    // MARK: The one write path

    /// Replace this vinyl's candidates with the corrected lines and commit the whole crate back
    /// through `CrateStore.update`, which is the same single write path `CrateDetailView.commit`
    /// already uses for a manual reorder. There is no second candidate-replacing mutator, and
    /// there is no second caller of this one.
    private func apply() {
        defer { dismiss() }
        guard var crate = model.store.crate(crateID),
              let index = crate.vinyls.firstIndex(where: { $0.id == item.id })
        else { return }
        crate.vinyls[index].candidates = draft.tracks()
        model.store.update(crate)
    }
}

/// One correctable line: the text, and the two structural operations, all on one row.
private struct LineRow: View {
    let number: Int
    @Binding var text: String
    let canMergeUp: Bool
    let onSplit: () -> Void
    let onMergeUp: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.primary)
                .frame(minWidth: 18, alignment: .trailing)

            // **V15.** A single-line field truncated the corpus's longest read at about 22
            // characters — measured at 237.3pt of field against a 44-character value, and the
            // real segmenter makes it WORSE, not better: joining a cluster's readings into one
            // line takes the longest draft line from 44 characters to 57 (IMG_0500). `axis:
            // .vertical` is the whole fix — the field grows to as many lines as the value needs
            // and the DJ can read what they are correcting without tapping into it first.
            TextField("Track line", text: $text, axis: .vertical)
                // **Not `.roundedBorder`, and that is measured.** With the rounded-border style
                // a vertical-axis field stops growing at two lines: the corpus's 29-character
                // control and its 57-character longest line both rendered at exactly
                // 44.00000000000003pt, so the long one was still cut off and V15 was still
                // open. Plain style plus an explicit range grows to the value; the border is
                // drawn here instead, which costs four lines and actually closes the defect.
                .lineLimit(1...10)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.55), lineWidth: 1))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("inspect-line-field-\(number)")

            Button(action: onSplit) {
                Image(systemName: "scissors")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Split line \(number)")
            .accessibilityIdentifier("inspect-split-\(number)")

            // Merging the first line is a no-op in Core, so the control is disabled there
            // rather than left looking live and silently doing nothing.
            Button(action: onMergeUp) {
                Image(systemName: "arrow.turn.left.up")
            }
            .buttonStyle(.bordered)
            .disabled(!canMergeUp)
            .accessibilityLabel("Merge line \(number) into the line above")
            .accessibilityIdentifier("inspect-merge-up-\(number)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspect-line-\(number)")
    }
}
