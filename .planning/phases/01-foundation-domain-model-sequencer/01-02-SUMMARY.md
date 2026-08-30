---
phase: 01-foundation-domain-model-sequencer
plan: 02
subsystem: infra
tags: [xcodegen, ios26, xcodebuild, secrets, codesigning]

# Dependency graph
requires:
  - phase: 01-01
    provides: VinylSetBuilderCore SPM package (domain types, protocol seams, purity guard)
provides:
  - XcodeGen-generated app target (project.yml is the only committed project source)
  - App/ shell (@main entry point + placeholder RootView) that source-globs, so later
    plans add SwiftUI files without touching project state
  - Verified target-based build gate (Scripts/build-app.sh) against the installed iOS 26
    device SDK with signing off
  - Build-time Secrets.swift generation (Scripts/generate-secrets.sh) from
    ~/.config/keys/, gitignored, with a runnable anti-leak self-check
affects: [01-06, 01-07, phase-4-audio-analysis, phase-4-metadata-resolution]

# Tech tracking
tech-stack:
  added: [XcodeGen 2.44.1 (project.yml)]
  patterns:
    - "Target-based xcodebuild (-target, -sdk iphoneos), not scheme-based — scheme builds
      resolve a destination which requires an installed platform; target builds skip that"
    - "Xcode Run Script build phase for secrets, not an SPM plugin — plugins are sandboxed
      and cannot read ~/.config/keys/ outside the repo"
    - "sources: - path: App with no file list in project.yml — XcodeGen globs the folder"

key-files:
  created:
    - project.yml
    - App/VinylSetBuilderApp.swift
    - App/Views/RootView.swift
    - App/Resources/Info.plist (written by xcodegen generate from project.yml properties)
    - App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
    - App/Resources/Assets.xcassets/Contents.json
    - Scripts/generate-secrets.sh
    - Scripts/build-app.sh
    - Scripts/regenerate-project.sh
  modified:
    - .gitignore
    - .planning/UAT-PENDING.md

key-decisions:
  - "DEVELOPMENT_TEAM (373D7DZ9NM) was recovered from the local Apple Development signing
    identity's certificate OU field via `security find-certificate` + openssl, rather than
    left unset as the plan's fallback allowed, since it was genuinely available in the
    environment and pushes SETUP-01 automation strictly further (device-signed build now
    succeeds; only the physically-disconnected device blocks install)."
  - "Used the plan's AMENDED (verified-by-experiment) build-app.sh recipe verbatim:
    target-based, -sdk iphoneos, CODE_SIGNING_ALLOWED=NO — not the original task-1 draft
    scheme-based recipe, which the plan itself documents as failing on this machine."

patterns-established:
  - "XcodeGen source-globbing: any plan can drop a .swift file under App/ and it is picked
    up by the next `xcodegen generate` / `Scripts/regenerate-project.sh` with zero project
    edits, so parallel plans never conflict over project state."
  - "Secrets generation is idempotent and atomic (mktemp + mv, content-diffed before write)
    so it doesn't dirty every incremental build."

requirements-completed: [SETUP-01, SETUP-03]

# Metrics
duration: 20min
completed: 2026-08-30
---

# Phase 1 Plan 2: XcodeGen App Target + Build-Time Secrets Summary

**XcodeGen-driven app target compiles against the installed iOS 26 device SDK with signing off, and a Run Script build phase generates a gitignored Secrets.swift from `~/.config/keys/` — proven leak-proof by a runnable `git check-ignore` self-check, not an assumed `.gitignore` line.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T06:48Z (approx, per STATE.md handoff)
- **Completed:** 2026-08-30T06:55Z
- **Tasks:** 3/3
- **Files modified:** 11 (9 created App/Scripts/project.yml, 2 modified: .gitignore, UAT-PENDING.md)

## Accomplishments

- `project.yml` is now the sole committed project source; `VinylSetBuilder.xcodeproj` is
  generated and gitignored, proven by `git check-ignore -v`.
- `./Scripts/build-app.sh` (target-based, `-sdk iphoneos`, signing off) builds successfully
  with **BUILD SUCCEEDED** — no simulator runtime and no certificate required.
- `Scripts/generate-secrets.sh` writes real, non-placeholder `discogsToken`,
  `soundCloudClientID`, `soundCloudClientSecret` from `~/.config/keys/enrich.env` and
  `~/.config/keys/.env`; `--check` mode confirms `git check-ignore` and empty
  `git ls-files App/Generated/` both hold.
- Went further than the plan's stated ceiling for SETUP-01: found `DEVELOPMENT_TEAM`
  (`373D7DZ9NM`) from the local Apple Development signing identity and confirmed a full
  device-signed build (`xcodebuild -destination 'generic/platform=iOS'
  -allowProvisioningUpdates build`) **succeeds** with real codesigning. Updated
  `.planning/UAT-PENDING.md` U1/U3 to reflect that only the physically-unavailable device
  now blocks install (U3 is fully resolved — the Run Script phase was confirmed to fire
  inside a real `xcodebuild` run, log line: "Run script build phase 'Generate Secrets.swift'
  will be run during every build").

## Task Commits

1. **Task 1: XcodeGen project definition and app shell** - `ae96471` (feat)
2. **Task 2: Build-time Secrets.swift generation, with an anti-leak test** - `db9a811` (feat)
3. **Task 3: Push SETUP-01 as far as automation reaches, then hand off the physical-device step** - `01066a6` (docs)

_No plan metadata commit separate from Task 3 — Task 3's own deliverable IS the
UAT-PENDING.md handoff, so it doubles as documentation of the plan's outcome._

## Files Created/Modified

- `project.yml` - XcodeGen project definition: app target sourced from `App/` (globbed, no
  file list), depends on local `VinylSetBuilderCore` package, `ENABLE_USER_SCRIPT_SANDBOXING:
  NO`, `DEVELOPMENT_TEAM: 373D7DZ9NM`, preBuildScripts wired to `generate-secrets.sh`
- `App/VinylSetBuilderApp.swift` - `@main` SwiftUI entry point
- `App/Views/RootView.swift` - 5-line placeholder (`NavigationStack` + `Text`); Plan 01-06
  replaces its body
- `App/Resources/Info.plist` - written by `xcodegen generate` from `project.yml`'s `info:`
  block; tracked (it's the template, variables like `$(PRODUCT_NAME)` resolve at build time)
- `App/Resources/Assets.xcassets/{,AppIcon.appiconset/}Contents.json` - empty asset catalog
  + AppIcon set so the build doesn't warn
- `Scripts/build-app.sh` - the verified build gate: target-based, `-sdk iphoneos`,
  `CODE_SIGNING_ALLOWED=NO` — the AMENDED recipe from the plan, not the original scheme-based
  draft (which the plan documents as failing: "iOS 26.0 is not installed" on destination
  resolution)
- `Scripts/regenerate-project.sh` - `xcodegen generate` wrapper for plans 01-06/01-07 to run
  after adding files under `App/`
- `Scripts/generate-secrets.sh` - parses (never sources) `~/.config/keys/{enrich.env,.env}`,
  writes `App/Generated/Secrets.swift` atomically/idempotently; `--check` mode is the
  runnable anti-leak proof
- `.gitignore` - added `VinylSetBuilder.xcodeproj/` and `App/Generated/`
- `.planning/UAT-PENDING.md` - U1 updated with the literal device-build outcome and the
  Team ID discovery; U3 marked resolved

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, no missing critical functionality, no blocking issues encountered.

### Decisions Made (not architectural, logged per plan's own "if available" clause)

**1. Set `DEVELOPMENT_TEAM` from a locally-discoverable signing identity, not left blank**
- **Found during:** Task 3
- **Detail:** The plan's Task 3 said "if `DEVELOPMENT_TEAM` is available in the environment
  or in `~/.config/keys/`, set it... If it is not, leave `CODE_SIGN_STYLE: Automatic` with
  no team." It was in neither of those two exact locations, but `security find-identity -v
  -p codesigning` showed one valid identity, and its certificate's OU field
  (`security find-certificate -p | openssl x509 -noout -subject`) is the 10-char Team ID
  format the plan describes. This is squarely within "push SETUP-01 as far as automation
  reaches" — it is not a new credential, just a different (and equally legitimate) place to
  read the same fact from. No secret was written to a tracked file: the Team ID is not
  sensitive (it's public in every certificate/provisioning profile) and lives in `project.yml`
  intentionally, unlike the three real API secrets in `App/Generated/Secrets.swift`.
- **Files modified:** `project.yml`
- **Commit:** `ae96471`

Plan otherwise executed exactly as written, using the AMENDED (verified-by-experiment) build
recipe rather than the original Task 1 draft, per the plan's own instruction to trust the
amendment.

## Known Stubs

- `App/Views/RootView.swift` is an intentional placeholder per the plan's own instruction
  ("Keep it to five lines; do not build UI here") — Plan 01-06 replaces its body with the
  crate list. Not a gap; explicitly deferred by this plan's design.

## Self-Check: PASSED

Verified after writing this summary:
- `project.yml` FOUND
- `App/VinylSetBuilderApp.swift` FOUND
- `App/Views/RootView.swift` FOUND
- `Scripts/build-app.sh` FOUND (executable)
- `Scripts/generate-secrets.sh` FOUND (executable)
- `Scripts/regenerate-project.sh` FOUND (executable)
- Commit `ae96471` FOUND in `git log --oneline`
- Commit `db9a811` FOUND in `git log --oneline`
- Commit `01066a6` FOUND in `git log --oneline`
- `./Scripts/build-app.sh` re-run: **BUILD SUCCEEDED**
- `./Scripts/generate-secrets.sh --check`: exit 0, "Leak check passed"
- `git ls-files App/Generated/`: empty
- `git check-ignore -v VinylSetBuilder.xcodeproj App/Generated/Secrets.swift`: both ignored
