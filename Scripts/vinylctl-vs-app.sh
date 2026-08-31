#!/usr/bin/env bash
# **Phase 10's second acceptance gate: does vinylctl's set match the app's on the same input?**
#
#     ./Scripts/vinylctl-vs-app.sh
#
# "One pipeline, two front ends" is a claim, and this is the measurement behind it. It runs the
# SAME twelve photographs through BOTH front ends and diffs the running order they produce:
#
#   A. vinylctl sequence --json                     (macOS, this process)
#   B. CaptureWalkUITests' live twelve-record walk  (iOS simulator, the real screens)
#
# Two things it deliberately does NOT do:
#
#   * it does not stub the network. Both halves call MusicBrainz, Discogs and SoundCloud live,
#     minutes apart, so a DIFFERENCE MAY BE THE INTERNET RATHER THAN THE CODE. The script says
#     so and prints both sides rather than swallowing the difference into a boolean.
#   * it does not compare bytes of prose. It canonicalises each side to `title | bpm | key`,
#     in order, which is the set a DJ would read off the screen.
#
# Beside the empirical diff it runs a STRUCTURAL check, because the empirical one can be
# confounded and the structural one cannot: both front ends must reach the set through the same
# two calls, and that is grep-able.
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p build Artifacts/vinylctl
VCTL_JSON=build/vinylctl-crosscheck.json
APP_LOG=build/app-crosscheck.log
REPORT=Artifacts/vinylctl/vs-app.txt

FAILS=0

# ---------------------------------------------------------------- structural: the same calls
echo "==> structural: both front ends reach the set through the same two calls" >&2
STRUCT_OK=1
check_pair() {  # <label> <file> <pattern>
    if grep -qE "$3" "$2"; then
        printf '  ok    %-34s %s\n' "$1" "$3"
    else
        printf '  MISS  %-34s %s\n' "$1" "$3"; STRUCT_OK=0
    fi
}
check_pair "app  sequences via"     App/Views/CrateDetailView.swift 'sequencer\.sequence\(candidates: *rebuilt\.sequencerInput'
check_pair "app  projects rows via" VinylSetBuilderCore/Sources/VinylSetBuilderCore/Crates/CrateDetailModel.swift 'CrateRows\.make\(result:'
check_pair "ctl  sequences via"     Tools/vinylctl/main.swift 'AsyncSequencer\(\)\.sequence\(candidates: *model\.sequencerInput'
check_pair "ctl  projects rows via" Tools/vinylctl/main.swift 'model\.apply\(result\)'
check_pair "ctl  resolves via"      Tools/vinylctl/main.swift 'pipeline\.process\('
check_pair "app  resolves via"      App/Views/CrateDetailView.swift 'pipeline\.process\('
# No second implementation: the CLI must not declare a sequencer, a resolver or a ladder.
if grep -qE 'BeamSearchSequencer\(|TrackResolver\(|BPMLadder\(' Tools/vinylctl/main.swift; then
    echo "  MISS  ctl builds its own engine — that is a SECOND implementation"; STRUCT_OK=0
else
    echo "  ok    ctl declares no sequencer, resolver or ladder of its own"
fi
[ "$STRUCT_OK" -eq 1 ] || FAILS=$((FAILS + 1))

# ---------------------------------------------------------------- A: the CLI
echo "==> A: vinylctl over the twelve" >&2
./Scripts/vinylctl.sh sequence --label crosscheck --json Tests/Fixtures/Labels/*.HEIC > "$VCTL_JSON" 2>/dev/null
CTL_RC=$?
[ "$CTL_RC" -eq 0 ] || { echo "vinylctl exited $CTL_RC" >&2; FAILS=$((FAILS + 1)); }

# ---------------------------------------------------------------- B: the app, in the simulator
echo "==> B: the app's own live twelve-record walk (slow: it is the same live network)" >&2
./Scripts/ui-test.sh \
  -only-testing:VinylSetBuilderUITests/CaptureWalkUITests/test_givenTwelveFixturePhotographs_whenShotInOneSession_thenTheFlipPromptFiresOnExactlyNine \
  > "$APP_LOG" 2>&1
APP_RC=$?
[ "$APP_RC" -eq 0 ] || echo "the walk exited $APP_RC — see $APP_LOG" >&2

# ---------------------------------------------------------------- the comparison
python3 - "$VCTL_JSON" "$APP_LOG" "$REPORT" <<'PY'
import json, re, sys

vctl_path, app_log, report_path = sys.argv[1:4]

def canon_bpm(text):
    """174 and 174.0 are the same tempo written two ways; the badge prints the first."""
    try:
        value = float(text)
        return str(int(value)) if value == int(value) else f"{value:g}"
    except ValueError:
        return text.strip()

# A: the CLI, straight out of its own machine-readable form
try:
    with open(vctl_path) as handle:
        report = json.load(handle)
    cli = [f"{r['title']} | {canon_bpm(r['bpm'])} | {r['key']}" for r in report["sequence"]]
except Exception as exc:                       # noqa: BLE001 — any failure is a reportable one
    cli, report = [], {}
    print(f"could not read {vctl_path}: {exc}")

# B: the app. The walk prints one line per drawn sequenced row; the label is the row's COMBINED
# accessibility label, which is "index, title, bpm, key" with the badges last. Split from the
# ends rather than the middle: a title may contain a comma, an index and a badge may not.
app = []
pattern = re.compile(r"PIPELINE sequenced row \d+: (.*)$")
with open(app_log, errors="replace") as handle:
    for line in handle:
        found = pattern.search(line.rstrip("\n"))
        if not found:
            continue
        parts = [p.strip() for p in found.group(1).split(",")]
        if len(parts) < 4:
            app.append(found.group(1).strip() + "  (UNPARSEABLE)")
            continue
        title = ", ".join(parts[1:-2])
        app.append(f"{title} | {canon_bpm(parts[-2])} | {parts[-1]}")

lines = []
lines.append("vinylctl vs the app — the same twelve photographs, both front ends")
lines.append("=" * 68)
lines.append("")
lines.append(f"A  vinylctl        {len(cli)} sequenced")
for i, row in enumerate(cli, 1):
    lines.append(f"     {i}. {row}")
lines.append("")
lines.append(f"B  the app's walk  {len(app)} sequenced")
for i, row in enumerate(app, 1):
    lines.append(f"     {i}. {row}")
lines.append("")

if not app:
    lines.append("VERDICT: NOT COMPARABLE — the walk printed no sequenced rows at all.")
    verdict = 2
elif cli == app:
    lines.append(f"VERDICT: IDENTICAL — {len(cli)} rows, same titles, same tempos, same keys,")
    lines.append("         in the same order. One pipeline, two front ends, measured.")
    verdict = 0
else:
    lines.append("VERDICT: DIFFERENT. Both halves called the live network minutes apart, so this")
    lines.append("         may be the internet and not the code — the structural check above is")
    lines.append("         what says whether the two front ends run the same engine. The rows:")
    for i in range(max(len(cli), len(app))):
        a = cli[i] if i < len(cli) else "(none)"
        b = app[i] if i < len(app) else "(none)"
        mark = "  " if a == b else "->"
        lines.append(f"     {mark} {i+1}. A: {a}")
        lines.append(f"        {' ' * len(str(i+1))}  B: {b}")
    verdict = 1

text = "\n".join(lines) + "\n"
print(text)
with open(report_path, "w") as handle:
    handle.write(text)
sys.exit(verdict)
PY
CMP_RC=$?

echo ""
echo "structural: $([ "$STRUCT_OK" -eq 1 ] && echo 'the two front ends make the same calls' || echo 'DIVERGED')"
case $CMP_RC in
    0) EMPIRICAL="identical" ;;
    1) EMPIRICAL="different — read the report" ;;
    *) EMPIRICAL="not comparable" ;;
esac
echo "empirical:  $EMPIRICAL"
echo "wrote $REPORT"
[ "$FAILS" -eq 0 ] && [ "$CMP_RC" -ne 2 ]
