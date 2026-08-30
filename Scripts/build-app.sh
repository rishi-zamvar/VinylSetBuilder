#!/usr/bin/env bash
# Verified 2026-08-29: BUILD SUCCEEDED with no simulator runtime, no platform
# download, and no signing identity. Target-based, NOT scheme-based — scheme
# builds resolve a destination, which needs an installed platform; target
# builds skip destination resolution entirely. See 01-02-PLAN.md amendment.
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
           build
