#!/usr/bin/env bash
# Phase 2 ship criterion: the XCUITest walk, unattended, against the booted iOS 26 simulator.
#
# Not a replacement for Scripts/build-app.sh — that is the signing-free DEVICE-SDK gate and
# stays target-based. This one is scheme-based on purpose: only a scheme carries a test action.
# The scheme is declared in project.yml and written to
# VinylSetBuilder.xcodeproj/xcshareddata/xcschemes/ by xcodegen, so it never depends on Xcode
# having been opened.
#
# Extra xcodebuild arguments are forwarded, e.g.
#   ./Scripts/ui-test.sh -only-testing:VinylSetBuilderUITests/SmokeUITests
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="4B4E1C1F-BED6-4812-9238-C151337265DA"   # VSB-Test, iPhone 16 Pro, iOS 26.0.1

xcrun simctl boot "$UDID" 2>/dev/null || true   # already-booted is not an error
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

xcodegen generate --quiet
rm -rf build/ui.xcresult

xcodebuild test \
  -project VinylSetBuilder.xcodeproj \
  -scheme VinylSetBuilder \
  -destination "id=$UDID" \
  -resultBundlePath build/ui.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  "$@"
