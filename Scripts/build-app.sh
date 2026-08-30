#!/usr/bin/env bash
# Verified 2026-08-29: BUILD SUCCEEDED with no simulator runtime, no platform
# download, and no signing identity. Target-based, NOT scheme-based — scheme
# builds resolve a destination, which needs an installed platform; target
# builds skip destination resolution entirely. See 01-02-PLAN.md amendment.
#
# Verified 2026-08-30 (01-06): explicit SYMROOT/OBJROOT are required. Without them,
# bare `xcodebuild -project` (no derived-data context) computes a SEPARATE build
# directory for the local VinylSetBuilderCore package sub-project than for the app
# target, so the app's swiftc invocation never sees the package's built .swiftmodule
# and fails with "Unable to find module dependency: 'VinylSetBuilderCore'" even
# though the package itself compiles cleanly. Forcing both projects into the same
# build root fixes it.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project VinylSetBuilder.xcodeproj \
           -target VinylSetBuilder \
           -sdk iphoneos \
           -configuration Debug \
           CODE_SIGNING_ALLOWED=NO \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGN_IDENTITY="" \
           SYMROOT="$(pwd)/build" \
           OBJROOT="$(pwd)/build" \
           build
