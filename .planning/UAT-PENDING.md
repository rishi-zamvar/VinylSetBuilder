# UAT pending — needs the owner physically present

Deferred out of the autonomous run so nothing blocks overnight. None of these are failures;
they are checks that require a human, a device, or a credential.

| # | Check | Why it can't be automated | Phase |
|---|-------|---------------------------|-------|
| U1 | App installs and launches on the physical iPhone 14 Pro | Needs the paid developer team identifier and a trusted device. The team ID is deliberately not in the repo (public). | 1 (SETUP-01) |
| U2 | Camera capture loop feels instant across 20 real records | Simulator has no camera; no simulator runtime is installed either. Requires the device and real records. | 2 (CAP-01..06) |
| U3 | `Secrets.swift` generation runs inside a real Xcode build | The Run Script phase only fires under `xcodebuild` with the app scheme. Scripted generation is verified; the build-phase wiring needs one real build. | 1 (SETUP-03) |
| U4 | The produced set is one you would actually play | Irreducibly a human judgement. This is the project's actual success criterion. | 4 |

## How to clear these

```bash
cd ~/Documents/Projects/VinylSetBuilder
open VinylSetBuilder.xcodeproj      # set your team in Signing & Capabilities, then ⌘R
```

What was automated instead, so the phases could still be verified:

- **U1** → `Scripts/build-app.sh` compiles against the iOS 26 device SDK with
  `CODE_SIGNING_ALLOWED=NO`. Proves the target builds; does not prove it installs.
- **U2** → segmentation and OCR are verified against the 12 committed fixture photographs
  rather than a live camera.
- **U3** → the generator script is unit-tested against a fixture dotenv; only the Xcode
  build-phase hook is unverified.
- **U4** → the sequencer is verified against hand-constructed fixtures with known-correct
  orderings, including the excluded-vinyl-rejoins case.
