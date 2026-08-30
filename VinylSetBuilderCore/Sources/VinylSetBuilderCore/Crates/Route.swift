import Foundation

/// Navigation state as data, so "creating a crate lands in the camera" is a `swift test`
/// assertion rather than something only visible by tapping through the app.
public enum Route: Hashable, Sendable {
    case crateList
    case capture(crateID: UUID)     // CRATE-02 lands here; CRATE-05 returns here
    case crateDetail(crateID: UUID)
}
