
## From 01-07 execution (2026-08-30)

- **Out of scope / not fixed by this plan:** `VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateStore.swift` (plan 01-06 WIP, uncommitted at the time 01-07 ran) imports `SwiftUI`, which fails the SETUP-02 purity guard (`CorePurityTests.swift`). This file and its violation belong entirely to plan 01-06, not 01-07 — 01-07 touches only `Presentation/TrackBadges.swift` and `Presentation/CrateRows.swift`, both of which are purity-clean. Whoever lands 01-06 must resolve this before that plan is considered done.
