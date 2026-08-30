#!/usr/bin/env bash
# Copies the PNGs UITests/ScreenshotRecorder.swift wrote inside the simulator, into the test
# runner's own Documents directory, out onto the host at Artifacts/screenshots/.
#
# Run it after Scripts/ui-test.sh. The file route is used rather than exporting XCTAttachments
# out of build/ui.xcresult because xcresulttool's export subcommand has changed spelling across
# Xcode releases, whereas `simctl get_app_container` has not.
#
# CONTAINER FRESHNESS — re-measured 02-04, 2026-08-30, because 02-02 and 02-03 disagreed.
#
# 02-02 said the runner gets a brand new data container on every `xcodebuild test`. 02-03 said
# it observed PNGs persisting across five runs and called that claim wrong. 02-02 is right:
# three consecutive `xcodebuild test` runs produced three different container UUIDs
# (1CE93729… -> 498F1B2B… -> F69EAB81…), each holding only its own run's output.
#
# What 02-03 actually saw was the PREVIOUS run's complete output still sitting in the last
# container — including four `02-03-probe-*.png` files that plan had deleted from the host but
# not from the simulator. That is accumulation across PLANS, not across runs, and it matters
# for one specific reason: this script copies whatever is in the current container, so running
# it WITHOUT a preceding test run silently re-copies the previous run's PNGs onto the host and
# they look like the current run's evidence. Always run Scripts/ui-test.sh first.
#
# The gate hazard is at the HOST end, and it is real: Artifacts/screenshots/ accumulates and
# nothing here deletes from it. A caller whose gate counts files by glob — 02-04's is
# `ls Artifacts/screenshots/02-walk-*.png | wc -l` == 15 — MUST clear its own glob first:
#
#     find Artifacts/screenshots -name '02-walk-*.png' -delete
#
# or a run that captured only fourteen states still counts fifteen and passes on a leftover.
# Better still: assert on the filenames printed below, which are this run's real output.
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
