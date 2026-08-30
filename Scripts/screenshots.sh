#!/usr/bin/env bash
# Regenerate the whole screenshot set from a purged host, in one command.
#
#     ./Scripts/screenshots.sh [extra xcodebuild args]
#
# Roadmap criterion 1 asks for one command. Until now it took three, in an order documented
# only inside a comment header, and getting the order wrong silently re-copies the PREVIOUS
# run's PNGs onto the host where they look like this run's evidence — see the CONTAINER
# FRESHNESS note in Scripts/collect-screenshots.sh. This script fixes the order in code.
#
# Order matters and each step has a stated fallback:
#   1. purge the host glob FIRST (never after: a leftover makes 14 states count as 15)
#   2. run the UI suite            — simctl boot of an already-booted device is not an error,
#                                    Scripts/ui-test.sh already swallows that specific case
#   3. verify from build/ui.xcresult, not only from the exit code — a runner that died before
#      asserting can still leave a zero somewhere. xcresulttool's subcommand spelling has
#      changed across Xcode releases, so there are two routes and the script PRINTS which one
#      it used. A tooling failure must never read as a pass.
#   4. collect out of the simulator container — Scripts/collect-screenshots.sh exits 1 with a
#      message if there is no container; that is not swallowed here
#   5. re-audit and rewrite the manifest
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE="build/ui.xcresult"

# The regenerable set. SOURCE OF TRUTH: REGENERABLE_PREFIXES in Scripts/screenshot-audit.py.
# Historical-evidence frames (01-06-*, 02-01-*, 02-03-*) are NOT purged — they are cited by
# defect rows in .planning/VISUAL-DEFECTS.md and no current test can reproduce them.
PURGE_GLOBS=(-name '02-smoke-*.png' -o -name '02-walk-*.png' -o -name '03-03-*.png'
             -o -name '03-04-*.png' -o -name '03-walk-*.png')

echo "==> 1/5 purging the regenerable set from the host"
mkdir -p Artifacts/screenshots
BEFORE=$(find Artifacts/screenshots -type f \( "${PURGE_GLOBS[@]}" \) | wc -l | tr -d ' ')
find Artifacts/screenshots -type f \( "${PURGE_GLOBS[@]}" \) -delete
AFTER=$(find Artifacts/screenshots -type f \( "${PURGE_GLOBS[@]}" \) | wc -l | tr -d ' ')
echo "    purged $BEFORE regenerable frame(s); $AFTER remain (must be 0)"
[ "$AFTER" -eq 0 ] || { echo "purge did not empty the glob — refusing to run" >&2; exit 1; }

echo "==> 2/5 running the UI suite"
./Scripts/ui-test.sh "$@"

echo "==> 3/5 verifying the run from $BUNDLE"
[ -d "$BUNDLE" ] || { echo "    $BUNDLE is missing — the run produced no result bundle." >&2
                      echo "    REFUSING to collect: the simulator container still holds the" >&2
                      echo "    previous run's PNGs and they would look like this run's." >&2
                      exit 1; }

read -r PASSED FAILED ROUTE <<<"$(
  if SUMMARY=$(xcrun xcresulttool get test-results summary --path "$BUNDLE" 2>/dev/null); then
    printf '%s' "$SUMMARY" | python3 -c \
      'import json,sys; d=json.load(sys.stdin); print(d["passedTests"], d["failedTests"], "test-results-summary")'
  else
    # Fallback for an Xcode whose subcommand spelling differs. Not silent: ROUTE says so.
    xcrun xcresulttool get --path "$BUNDLE" --format json --legacy 2>/dev/null | python3 -c \
      'import json,sys
d = json.load(sys.stdin)
m = d.get("metrics", {})
p = int(m.get("testsCount", {}).get("_value", 0))
f = int(m.get("testsFailedCount", {}).get("_value", 0))
print(p - f, f, "legacy-get-json")'
  fi
)"
echo "    route=$ROUTE passed=$PASSED failed=$FAILED"
[ "$FAILED" = "0" ] || { echo "    $FAILED test(s) FAILED — refusing to collect" >&2; exit 1; }
[ "$PASSED" -gt 0 ] 2>/dev/null || { echo "    passed=$PASSED — a run that asserted nothing is not a green run" >&2; exit 1; }

echo "==> 4/5 collecting from the simulator container"
./Scripts/collect-screenshots.sh

echo "==> 5/5 auditing and rewriting the manifest"
python3 Scripts/screenshot-audit.py --write-manifest
