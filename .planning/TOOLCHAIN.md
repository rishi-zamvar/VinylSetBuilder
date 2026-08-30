# Toolchain — verified facts

Every line here was measured on this machine. Do not re-derive; do not assume.
**Last verified: 2026-08-30.**

| Thing | Value |
|---|---|
| macOS | 26.6.2 |
| Xcode | 26.0.1 |
| Swift | 6.2 |
| SDKs | `iphoneos26.0`, `macosx26.0` |
| Deployment target | **iOS 26** — never 27 |
| `MusicUnderstanding.framework` | **ABSENT** from SDK and system. Never import it. |
| xcodegen | `/opt/homebrew/bin/xcodegen` |

## Simulator — INSTALLED 2026-08-30 ✅

Previously absent; downloaded (8.05 GB) and installed during the overnight run.

```
runtime   iOS 26.0 (26.0.1 - 23A8464)
          com.apple.CoreSimulator.SimRuntime.iOS-26-0
device    VSB-Test  —  iPhone 16 Pro
UDID      4B4E1C1F-BED6-4812-9238-C151337265DA
```

Boot it with:

```bash
xcrun simctl boot 4B4E1C1F-BED6-4812-9238-C151337265DA 2>/dev/null || true   # already-booted is not an error
```

### This changes what is verifiable

Before the simulator existed, UI could only be verified indirectly through Core value types.
Now the app can actually be built, installed, launched and screenshotted:

```bash
xcodebuild -project VinylSetBuilder.xcodeproj -scheme VinylSetBuilder \
           -destination "id=4B4E1C1F-BED6-4812-9238-C151337265DA" -configuration Debug build

xcrun simctl install 4B4E1C1F-BED6-4812-9238-C151337265DA <path-to-.app>
xcrun simctl launch  4B4E1C1F-BED6-4812-9238-C151337265DA <bundle-id>
xcrun simctl io      4B4E1C1F-BED6-4812-9238-C151337265DA screenshot shot.png
```

**Keep testing UI logic in Core value types anyway.** Those tests are fast, deterministic and
run without a simulator. The simulator adds *visual* confirmation and XCUITest; it does not
replace unit tests.

## Building for a real device (no signing, no device attached)

Still valid and still the right gate for "does the app target compile":

```bash
xcodebuild -project VinylSetBuilder.xcodeproj -target VinylSetBuilder \
           -sdk iphoneos -configuration Debug \
           CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

**Target-based, not scheme-based.** Scheme builds resolve a *destination*; target builds do
not. Before the runtime was installed, every scheme-based invocation failed with
"Found no destinations" / "iOS 26.0 is not installed". Now that a runtime exists, scheme +
`-destination "id=4B4E1C1F-BED6-4812-9238-C151337265DA"` also works — but the target-based command remains the correct
signing-free check for device-SDK compilation.

## Still requires the owner

Installing on the **physical** iPhone 14 Pro needs the paid developer Team ID, which is
deliberately absent from this public repo. That is UAT item U1 and cannot be automated.
