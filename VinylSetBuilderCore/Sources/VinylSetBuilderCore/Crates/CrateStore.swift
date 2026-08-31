import Foundation

/// The crate-management reducer: CRATE-01 (list), CRATE-02 (create + route in one call),
/// CRATE-06 (delete crate / remove vinyl), and CRATE-07 (per-crate track selection) as a
/// pure value type. No view framework, no I/O — the app target owns the one `@Observable` wrapper.
public struct CrateStore: Sendable, Equatable {
    public private(set) var crates: [Crate]     // newest first
    public var route: Route

    public init(crates: [Crate] = [], route: Route = .crateList) {
        self.crates = crates
        self.route = route
    }

    // MARK: CRATE-01

    public var summaries: [CrateSummary] {
        crates.map { CrateSummary(id: $0.id, name: $0.name, recordCount: $0.recordCount) }
    }

    public func crate(_ id: UUID) -> Crate? {
        crates.first { $0.id == id }
    }

    // MARK: CRATE-02 — creating and routing are ONE operation, never two

    @discardableResult
    public mutating func createCrate(named rawName: String, now: Date = Date()) -> UUID {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Untitled Crate" : trimmed
        let crate = Crate(name: name, createdAt: now, bpmTolerance: BPMRules.defaultTolerance)
        crates.insert(crate, at: 0)   // newest first
        route = .capture(crateID: crate.id)
        return crate.id
    }

    // MARK: CRATE-06

    public mutating func deleteCrate(_ id: UUID) {
        crates.removeAll { $0.id == id }
        if case .capture(let crateID) = route, crateID == id { route = .crateList }
        if case .crateDetail(let crateID) = route, crateID == id { route = .crateList }
    }

    public mutating func removeVinyl(_ vinylID: UUID, from crateID: UUID) {
        withCrate(crateID) { crate in
            crate.vinyls.removeAll { $0.id == vinylID }
            crate.vinyls = crate.vinyls
                .sorted { $0.position < $1.position }
                .enumerated()
                .map { index, vinyl in
                    var vinyl = vinyl
                    vinyl.position = index
                    return vinyl
                }
            crate.selectedTrackByVinyl.removeValue(forKey: vinylID)
        }
    }

    // MARK: CRATE-07

    public mutating func addVinyl(_ vinyl: VinylEntry, to crateID: UUID) {
        withCrate(crateID) { crate in
            guard !crate.vinyls.contains(where: { $0.id == vinyl.id }) else { return }
            var vinyl = vinyl
            vinyl.position = crate.vinyls.count
            crate.vinyls.append(vinyl)
        }
    }

    public mutating func selectTrack(_ trackID: UUID, forVinyl vinylID: UUID, in crateID: UUID) {
        withCrate(crateID) { crate in
            guard crate.vinyls.contains(where: { $0.id == vinylID }) else { return }
            crate.selectedTrackByVinyl[vinylID] = trackID
        }
    }

    public func selectedTrack(forVinyl vinylID: UUID, in crateID: UUID) -> UUID? {
        crate(crateID)?.selectedTrackByVinyl[vinylID]
    }

    // MARK: Navigation

    public mutating func open(_ crateID: UUID) {
        route = .crateDetail(crateID: crateID)
    }

    public mutating func closeToList() {
        route = .crateList
    }

    // MARK: CRATE-05

    /// Re-enter capture for an EXISTING crate. Navigation only; mutates nothing else.
    /// The guard is the whole point: a stale ID must not navigate anywhere.
    public mutating func addMore(to crateID: UUID) {
        guard crate(crateID) != nil else { return }
        route = .capture(crateID: crateID)
    }

    // MARK: MAN-01 — the one write path for a hand-edited candidate

    /// Replace one candidate wherever it lives. Resolved by `track.vinylID` and then by
    /// `track.id`, so the caller never has to know which vinyl in which position holds it —
    /// and so a not-included row, which only ever knew a vinyl, can commit an edit through the
    /// same call the sequenced list uses. Unknown crate, unknown vinyl or unknown track are all
    /// no-ops; `position` is copied from the incoming value's original slot and never recomputed
    /// (PERS-02: the ordering field is data, not a side effect of writing).
    public mutating func updateTrack(_ track: Track, in crateID: UUID) {
        withCrate(crateID) { crate in
            guard let vinylIndex = crate.vinyls.firstIndex(where: { $0.id == track.vinylID }),
                  let trackIndex = crate.vinyls[vinylIndex].candidates
                      .firstIndex(where: { $0.id == track.id })
            else { return }
            crate.vinyls[vinylIndex].candidates[trackIndex] = track
        }
    }

    // MARK: SEQ-05 — the tolerance slider's one write path

    /// Clamped through `BPMRules.clampTolerance`, so a value from outside the slider's own
    /// 3...6 — a restored crate written by an older build, a hand-edited store, a future
    /// caller — cannot put the sequencer somewhere the UI could never have asked for.
    ///
    /// Nothing is re-sequenced here and that is deliberate: `CrateStore` is a pure reducer and
    /// the beam search is off-actor (SEQ-09). The caller re-derives, exactly as it does after
    /// `updateTrack`. The tolerance IS the input to that derivation, so storing it is the
    /// whole of this function's job.
    public mutating func setBPMTolerance(_ tolerance: Double, in crateID: UUID) {
        withCrate(crateID) { crate in
            crate.bpmTolerance = BPMRules.clampTolerance(tolerance)
        }
    }

    // MARK: Write-back

    /// The commit path for an edited crate value (a manual reorder). Replaces in place, so the
    /// newest-first list order is not disturbed by a write-back. Never inserts.
    public mutating func update(_ crate: Crate) {
        guard let index = crates.firstIndex(where: { $0.id == crate.id }) else { return }
        crates[index] = crate
    }

    // MARK: Private

    /// Every mutator resolves the crate through here. No-ops on an unknown ID rather than
    /// trapping — every unknown-ID test routes through this one guard.
    private mutating func withCrate(_ id: UUID, _ body: (inout Crate) -> Void) {
        guard let index = crates.firstIndex(where: { $0.id == id }) else { return }
        body(&crates[index])
    }
}
