/// D-03-3 — the one seam between the capture screen and where photographs come from.
///
/// `async` from the very first day, before anything actually awaits, so that Phase 10's real
/// on-device capture is a body swap and no call site has to move. Act I's implementation is
/// `FixturePhotoSource`; Phase 10's wraps the camera framework in the app target.
///
/// There is deliberately **no** artificial delay. MVP-SPEC §3's fake 1.5 s spinner is dropped:
/// a timed transient is unphotographable behind the mandatory 3 s screenshot settle and makes
/// the UI walk flaky. Statuses here are steady.
public protocol PhotoCapturing: Sendable {
    /// One shutter press. Returns nil when the source has nothing left to give.
    func capture() async -> CaptureItem?
}
