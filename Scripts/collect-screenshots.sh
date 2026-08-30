#!/usr/bin/env bash
# Copies the PNGs UITests/ScreenshotRecorder.swift wrote inside the simulator, into the test
# runner's own Documents directory, out onto the host at Artifacts/screenshots/.
#
# Run it after Scripts/ui-test.sh. The file route is used rather than exporting XCTAttachments
# out of build/ui.xcresult because xcresulttool's export subcommand has changed spelling across
# Xcode releases, whereas `simctl get_app_container` has not.
#
# MEASURED 2026-08-30, do not re-derive: the runner is reinstalled on every `xcodebuild test`
# and gets a BRAND NEW data container each time (verified by comparing container UUIDs across
# two consecutive runs). So the container's Documents holds exactly this run's screenshots and
# never a stale one — the names printed below are the run's real output.
#
# Artifacts/screenshots/ on the HOST is a different matter: it accumulates, and nothing here
# deletes from it. A caller whose gate counts files by glob — 02-04's is
# `ls Artifacts/screenshots/02-walk-*.png | wc -l` == 15 — must clear its own glob first, or a
# run that captured only fourteen will still count fifteen and pass on a leftover. Prefer
# asserting on what this script reports it copied.
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="4B4E1C1F-BED6-4812-9238-C151337265DA"   # VSB-Test, iPhone 16 Pro, iOS 26.0.1
RUNNER="com.rishizamvar.VinylSetBuilderUITests.xctrunner"

CONTAINER="$(xcrun simctl get_app_container "$UDID" "$RUNNER" data 2>/dev/null || true)"
if [ -z "$CONTAINER" ]; then
  # Xcode derives the runner's bundle id, so do not trust the guess above. Find it instead.
  RUNNER="$(xcrun simctl listapps "$UDID" | grep -o '"[^"]*xctrunner"' | tr -d '"' | head -1)"
  [ -n "$RUNNER" ] || { echo "no .xctrunner app installed on $UDID — run Scripts/ui-test.sh first" >&2; exit 1; }
  CONTAINER="$(xcrun simctl get_app_container "$UDID" "$RUNNER" data)"
fi

mkdir -p Artifacts/screenshots
COUNT=$(ls "$CONTAINER"/Documents/*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" -gt 0 ] || { echo "no screenshots in $CONTAINER/Documents" >&2; exit 1; }

cp "$CONTAINER"/Documents/*.png Artifacts/screenshots/
echo "collected $COUNT screenshot(s) from $RUNNER into Artifacts/screenshots/"
for f in "$CONTAINER"/Documents/*.png; do echo "  $(basename "$f")"; done
