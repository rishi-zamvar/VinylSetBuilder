#!/usr/bin/env bash
# PERS-01, measured: build a 20-vinyl crate, kill the app WITH simctl, relaunch, and diff the
# two canonical dumps field by field.
#
# **Deliberately not an XCUITest.** `XCUIApplication.terminate()` is the test harness asking the
# app to go away; `simctl terminate` is the operating system killing the process, which is what
# the requirement says and what actually happens when a phone reclaims memory. The XCUITest in
# UITests/ManualEntryUITests.swift makes the same claim through the harness — two independent
# observations of the one headline number, per the rigor policy.
#
# **Runs against the ALREADY-INSTALLED app.** It never invokes xcodebuild: two concurrent
# xcodebuilds is what filled this machine's disk during Phase 7. Run ./Scripts/ui-test.sh first
# (that installs the app), then this.
set -uo pipefail
cd "$(dirname "$0")/.."

UDID="4B4E1C1F-BED6-4812-9238-C151337265DA"
BUNDLE="com.rishizamvar.VinylSetBuilder"
OUT="Artifacts/persistence"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null)
if [ -z "$CONTAINER" ]; then
  echo "persistence-check: FAIL — $BUNDLE is not installed on $UDID." >&2
  echo "                  Run ./Scripts/ui-test.sh first; it installs the app." >&2
  exit 1
fi
DOCS="$CONTAINER/Documents"
rm -f "$DOCS/dump-1.txt" "$DOCS/dump-2.txt"

# ---- launch 1: wipe, seed the 20-vinyl probe, save, dump what is in memory
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" "$BUNDLE" vsb-seed20 "vsb-dump=1" >/dev/null || exit 1
# The dump is written during init, but the store save happens on the same run loop turn; give
# the process a moment to reach a quiescent state before the kill rather than racing it.
sleep 6

# ---- the kill. simctl, not the harness.
xcrun simctl terminate "$UDID" "$BUNDLE" || exit 1
sleep 2

# ---- launch 2: no seed, no reset. Everything below now comes off disk.
xcrun simctl launch "$UDID" "$BUNDLE" "vsb-dump=2" >/dev/null || exit 1
sleep 6
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

cp "$DOCS/dump-1.txt" "$OUT/dump-1.txt" 2>/dev/null
cp "$DOCS/dump-2.txt" "$OUT/dump-2.txt" 2>/dev/null

FAILS=0
report() { printf '%-8s %s\n' "$1" "$2"; [ "$1" = "FAIL" ] && FAILS=$((FAILS + 1)); return 0; }

for label in 1 2; do
  if [ ! -s "$OUT/dump-$label.txt" ]; then
    report FAIL "dump-$label.txt is missing or empty — the app wrote nothing"
  fi
done
[ "$FAILS" -gt 0 ] && { printf '\npersistence-check: FAILED\n'; exit 1; }

L1=$(wc -l < "$OUT/dump-1.txt" | tr -d ' ')
L2=$(wc -l < "$OUT/dump-2.txt" | tr -d ' ')
DIFFLINES=$(diff "$OUT/dump-1.txt" "$OUT/dump-2.txt" | grep -cE '^[<>]')

# A dump of an EMPTY store is also a clean diff, and that is the failure mode this gate exists
# to catch: "nothing survived" and "everything survived" both produce zero differing lines if
# nobody checks that there was something to survive.
VINYLS=$(grep -cE '^c0 v[0-9]+ id=' "$OUT/dump-2.txt")
TRACKS=$(grep -cE '^c0 v[0-9]+ t[0-9]+ id=' "$OUT/dump-2.txt")
MANUAL=$(grep -cE '^c0 v[0-9]+ t[0-9]+ state=manual$' "$OUT/dump-2.txt")
SELECTED=$(grep -cE '^c0 selected ' "$OUT/dump-2.txt")
UNSELECTED=$((TRACKS - SELECTED))

report "$([ "$DIFFLINES" -eq 0 ] && echo PASS || echo FAIL)" \
       "PERS-01 field-by-field diff = $DIFFLINES differing line(s) over $L1/$L2 lines"
report "$([ "$VINYLS" -eq 20 ] && echo PASS || echo FAIL)" \
       "PERS-01 the relaunched store holds $VINYLS vinyls (expected 20)"
report "$([ "$UNSELECTED" -gt 0 ] && echo PASS || echo FAIL)" \
       "PERS-03 $TRACKS candidate tracks survived, $SELECTED selected, $UNSELECTED UNSELECTED"
report "$([ "$MANUAL" -gt 0 ] && echo PASS || echo FAIL)" \
       "MAN-04 $MANUAL hand-entered track(s) kept the .manual mark across the kill"
# PERS-02: the ordering fields are present and the manual order — an ordered array of
# references, the exact shape a to-many relationship would scramble — came back intact.
ORDER_OK=$(grep -c '^c0 manualOrder=[0-9A-F]' "$OUT/dump-2.txt")
report "$([ "$ORDER_OK" -eq 1 ] && echo PASS || echo FAIL)" \
       "PERS-02 the scalar manualOrder array survived as one line"

printf '\npersistence-check: %d fail\n' "$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
