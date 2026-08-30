import Foundation
import Testing
@testable import VinylSetBuilderCore

/// **Defect V5.** `FixtureCrates.mixedResultsCrate` gave `sharedVinyl` and `unresolvedVinyl`
/// the same `position: 2`, and `VinylEntry.label`'s fallback is `"Vinyl \(position + 1)"`, so
/// both rendered `"Vinyl 3"`. Only one of the two ever lands in the not-included bucket, which
/// is why no photograph in the committed set shows it — V5 was found by reading a fixture, not
/// by looking at a screen.
///
/// WHY THE LABEL ASSERTION AND NOT ONLY THE POSITION ONE
/// -----------------------------------------------------
/// V5's actual complaint is a **duplicate label**. `"Vinyl \(position + 1)"` is only one of the
/// routes to one — a future collision could arrive through two vinyls whose first resolved
/// candidate has the same `displayName`, and a position-only assertion would sail past it. So
/// the label check is the primary one and the position check backs it up, exactly the reasoning
/// that made plan 03-05's mutation J visible: measure the property you care about, not a proxy
/// that happens to correlate today.
///
/// Both run over **every** crate `FixtureCrates.all` exposes, not over `mixedResultsCrate`
/// alone, so the one crate that was wrong is not also the only one that is checked.
@Suite("FixtureCrates — V5: no two vinyls in a crate may render the same label")
struct FixtureCratesTests {

    @Test("Every fixture crate's vinyl labels are unique")
    func labelsAreUniqueInEveryCrate() {
        for crate in FixtureCrates.all {
            let labels = crate.vinyls.map(\.label)
            let duplicates = Set(labels.filter { label in labels.filter { $0 == label }.count > 1 })
            #expect(duplicates.isEmpty, Comment(rawValue:
                "V5: crate '\(crate.name)' renders \(duplicates.sorted()) on more than one "
                + "vinyl. Labels were \(labels)."))
            #expect(Set(labels).count == crate.vinyls.count, Comment(rawValue:
                "V5: crate '\(crate.name)' has \(crate.vinyls.count) vinyls but only "
                + "\(Set(labels).count) distinct labels"))
        }
    }

    @Test("Every fixture crate's vinyl positions are unique")
    func positionsAreUniqueInEveryCrate() {
        for crate in FixtureCrates.all {
            let positions = crate.vinyls.map(\.position)
            let duplicates = Set(positions.filter { p in positions.filter { $0 == p }.count > 1 })
            #expect(duplicates.isEmpty, Comment(rawValue:
                "V5: crate '\(crate.name)' reuses position(s) \(duplicates.sorted()). "
                + "D9 makes position the order WITHIN a crate, so a reused one is ambiguous "
                + "ordering as well as a duplicate label. Positions were \(positions)."))
            #expect(Set(positions).count == crate.vinyls.count, Comment(rawValue:
                "V5: crate '\(crate.name)' has \(crate.vinyls.count) vinyls but only "
                + "\(Set(positions).count) distinct positions"))
        }
    }

    /// A uniqueness assertion over an empty list is vacuously true, and a `FixtureCrates.all`
    /// that quietly stopped listing a crate would make both tests above pass while checking
    /// nothing. This is the standing negative control for that.
    @Test("FixtureCrates.all is what the demo store is built from, and is not empty")
    func theCratesUnderTestAreTheCratesOnScreen() {
        #expect(FixtureCrates.all.count >= 2, Comment(rawValue:
            "FixtureCrates.all lists \(FixtureCrates.all.count) crate(s) — the uniqueness "
            + "tests above would be near-vacuous"))
        #expect(FixtureCrates.all.contains { !$0.vinyls.isEmpty },
                "no crate in FixtureCrates.all holds a vinyl, so nothing is actually compared")
        // The demo store IS built from `all` (not from a second hand-written list), so a crate
        // added to the app is a crate added to these tests. Asserted rather than trusted.
        #expect(FixtureCrates.demoStore.summaries.count == FixtureCrates.all.count, Comment(rawValue:
            "the demo store shows \(FixtureCrates.demoStore.summaries.count) crates but "
            + "\(FixtureCrates.all.count) are under test — the two lists have drifted apart"))
    }
}
