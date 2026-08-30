#!/bin/bash
# Act I sign-off gate S5/S6, made executable.
#
# The roadmap's Phase 4 criterion is a sentence: "no dead code, no unused protocol
# conformances, no TO-DO comments, consistent naming, and CorePurityTests still green."
# This script is that sentence, decidable by one command.
#
# set -u and pipefail, but deliberately NOT -e: every gate must run and report, so that
# one red gate cannot hide the state of the other eight.
set -uo pipefail
cd "$(dirname "$0")/.."

PASSES=0
FAILS=0
pass() { printf 'PASS %s  %s\n' "$1" "$2"; PASSES=$((PASSES + 1)); }
fail() { printf 'FAIL %s  %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); [ $# -ge 3 ] && printf '%s\n' "$3" | sed 's/^/         /'; }
skip() { printf 'SKIP %s  %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }   # a skipped gate is NOT a passed gate

CODE_TREES=(App VinylSetBuilderCore/Sources VinylSetBuilderCore/Tests UITests)
# Where a REFERENCE to a declaration may legitimately live. Tools/ is included from Phase 7:
# the acceptance-gate harnesses compile the SHIPPING transport, decoder and clients into a
# macOS binary and run them, which is exactly what ocr-score.sh has always done with the
# shipping recogniser. A caller that runs the code every gate run is not a dead reference.
# Declarations are still only SCANNED FOR under Core Sources and App — Tools declares nothing
# the app depends on.
REF_TREES=("${CODE_TREES[@]}" Tools)
# .build is gitignored SPM output; it retains dependency manifests naming files that were
# deleted from Sources, so an unscoped grep reports references that do not exist in source.
EXCL=(--exclude-dir=.build --exclude-dir=__pycache__ --exclude-dir=.git)

# grep exit 1 means "no match", which is a PASS for the absence gates. Only exit >1 is an
# error. Never let pipefail turn a clean gate into a failure.
absent() {  # absent <id> <what> <pattern> <paths...>
    local id="$1" what="$2" pat="$3"; shift 3
    local hits rc
    hits=$(grep -rInE "${EXCL[@]}" "$pat" "$@" 2>/dev/null); rc=$?
    if [ "$rc" -gt 1 ]; then fail "$id" "$what — grep errored (rc=$rc)"; return; fi
    if [ -n "$hits" ]; then fail "$id" "$what — $(printf '%s\n' "$hits" | wc -l | tr -d ' ') hit(s)" "$hits"
    else pass "$id" "$what"; fi
}

# ---------------------------------------------------------------- G1: no work markers
# This script lives inside Scripts/, which is inside the swept tree. A gate whose own
# pattern string contains the literal token it searches for matches itself and is
# permanently red. --exclude'ing its own filename would make the gate structurally unable
# to see a real marker in itself, so the pattern is built from concatenated fragments
# instead: the literal token never appears in this file.
# \b bounds are load-bearing on the third fragment — mktemp templates (.Secrets.swift.XXXXXX)
# are legitimate and are not work markers. \bXX''X\b does not match a run of six X.
MARKERS="$(printf '\\bTO''DO\\b|\\bFIX''ME\\b|\\bXX''X\\b|\\bHA''CK\\b')"
absent G1 "no work markers in the swept tree" "$MARKERS" "${CODE_TREES[@]}" Scripts

# ---------------------------------------------------------------- G2: Core purity
# Shells out to the one purity guard rather than re-implementing the scan. There is exactly
# one, and it lives in CorePurityTests.swift.
#
# Fallback: `swift test --filter` exits 0 on some toolchains when the filter matches NOTHING,
# which would make this gate vacuous. Assert the run reported exactly 1 test, not merely a
# zero exit code. A gate that passes when it ran nothing is the worst kind.
if [ ! -x Scripts/test.sh ]; then
    skip G2 "CorePurityTests — Scripts/test.sh not executable"
else
    G2_OUT=$(./Scripts/test.sh --filter CorePurity 2>&1); G2_RC=$?
    G2_N=$(printf '%s\n' "$G2_OUT" | sed -nE 's/.*Test run with ([0-9]+) tests? .*/\1/p' | tail -1)
    # rc is checked BEFORE parseability, deliberately. A mutation can CRASH the runner rather
    # than fail cleanly — `import UIKit` in a Core source stops the package compiling, so no
    # "Test run with N tests" line is ever printed. Reporting that as SKIP would describe a
    # broken build as a missing toolchain. A crashed runner is not a red assertion, but it is
    # certainly not a pass.
    if [ "$G2_RC" -ne 0 ]; then
        fail G2 "CorePurityTests did not pass (rc=$G2_RC, runner reported ${G2_N:-no} test count)" \
                "$(printf '%s\n' "$G2_OUT" | grep -E '✘|error:|Core purity violated' | grep -v '^ ' | head -10)"
    elif [ -z "$G2_N" ]; then
        skip G2 "CorePurityTests — exited 0 but printed no test count; no toolchain?"
    elif [ "$G2_N" -ne 1 ]; then
        fail G2 "CorePurityTests ran $G2_N tests, expected exactly 1 — the filter is wrong, so a green here proves nothing"
    else
        pass G2 "CorePurityTests green (exactly 1 test ran)"
    fi
fi

# ------------------------------------------- G3: no dependency on an uninstalled SDK
# MusicUnderstanding needs iOS 27. The toolchain is Xcode 26.0.1 / iOS 26 SDK and the
# framework is absent from both the SDK and the running system. PROJECT.md: no phase may
# be planned against an unavailable SDK.
absent G3 "no MusicUnderstanding reference" "MusicUnderstanding" App VinylSetBuilderCore UITests

# ----------------------------------------------- G4: the Phase 9 gap, now CLOSED and held open
# Plan 01-05 promised AsyncSequencer and BeamDivergenceCheck and was never executed; this gate
# used to RE-CONFIRM their absence. Phase 5 built both, so the gate is inverted: it now fails if
# either disappears, and it demands a real declaration rather than a passing mention, so a stray
# comment naming the type cannot hold the gate up on its own.
G4_ERR=""
for sym in AsyncSequencer BeamDivergenceCheck; do
    decl="VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/${sym}.swift"
    [ -f "$decl" ] || G4_ERR="${G4_ERR}${sym}: ${decl} does not exist"$'\n'
    grep -qE "^public struct ${sym}\b" "$decl" 2>/dev/null \
        || G4_ERR="${G4_ERR}${sym}: no 'public struct ${sym}' declaration in ${decl}"$'\n'
    # Referenced from somewhere OTHER than its own declaring file, or it is not wired in.
    n=$(grep -rl --include='*.swift' "${EXCL[@]}" "\b${sym}\b" "${CODE_TREES[@]}" 2>/dev/null \
        | grep -vc "^${decl}$")
    [ "${n:-0}" -eq 0 ] && G4_ERR="${G4_ERR}${sym}: declared but referenced nowhere else"$'\n'
done
if [ -n "$G4_ERR" ]; then
    fail G4 "SEQ-09/SEQ-10 seams missing (the Phase 5 gap has reopened)" "$(printf '%s' "$G4_ERR")"
else
    pass G4 "AsyncSequencer + BeamDivergenceCheck declared and referenced (SEQ-09, SEQ-10)"
fi

# ---------------------------------------------------------------- G5: no dead declarations
# For every public type/func/var under Core Sources and every type under App/, count files
# OTHER than its own declaring file that mention the identifier, across all four trees.
# Zero external references => dead, unless allowlisted below with a reason.
#
# App/Generated/ is skipped wholesale: it is gitignored, machine-written at build time from
# ~/.config/keys/, and is not part of the tree under audit.
#
# ALLOWLIST — a symbol with zero references that is KEPT needs a stated reason exactly as
# much as one that is deleted.
#   VinylSetBuilderApp  @main entry point. Unreferenced by definition.
#   OrderingMode        reachable only through CrateDetailModel.orderingMode, whose type is
#                       inferred at the call site, so a name-exact scan cannot see the use.
#                       ManualOrderTests.swift:56 exercises it.
#   MetadataResolving   HISTORICAL. It was allowlisted through Phases 4-6 as a seam with no
#                       conformance, on the rule "keep a protocol iff a NAMED future phase's
#                       requirements implement it". Phase 7 did: TrackResolver conforms to it
#                       and TrackResolverTests exercise it, so the entry is now inert and is
#                       kept only so the reasoning survives. It can go when someone tidies.
G5_ALLOW="^(VinylSetBuilderApp|OrderingMode|MetadataResolving)$"
g5_decls() {  # $1 = root, $2 = visibility prefix ("public " or "")
    local f
    while IFS= read -r f; do
        grep -oE "^ *${2}(struct|enum|final class|class|actor|protocol) +[A-Za-z_][A-Za-z0-9_]*" "$f" \
            | sed -E 's/.* //' | while read -r n; do printf '%s\t%s\n' "$n" "$f"; done
        grep -oE "^${2}(func|var|let) +[A-Za-z_][A-Za-z0-9_]*" "$f" \
            | sed -E 's/.* //' | while read -r n; do printf '%s\t%s\n' "$n" "$f"; done
    done < <(find "$1" -name '*.swift' -not -path '*/Generated/*')
}
G5_DEAD=$( { g5_decls VinylSetBuilderCore/Sources "public "; g5_decls App ""; } | sort -u | \
    while IFS=$'\t' read -r name file; do
        printf '%s' "$name" | grep -qE "$G5_ALLOW" && continue
        n=$(grep -rl --include='*.swift' "${EXCL[@]}" "\b${name}\b" "${REF_TREES[@]}" 2>/dev/null \
            | grep -v "^${file}$" | wc -l | tr -d ' ')
        [ "$n" -eq 0 ] && printf '%s  (%s)\n' "$name" "$file"
    done )
if [ -n "$G5_DEAD" ]; then
    fail G5 "unreferenced declaration(s): $(printf '%s\n' "$G5_DEAD" | awk '{print $1}' | paste -sd, -)" "$G5_DEAD"
else
    pass G5 "no unreferenced declarations outside the stated allowlist"
fi

# ---------------------------------------------------------------- G6: D-03-6 naming rule
# VinylEntry.label renders "Vinyl N". D-03-6 keeps it off the capture/correction screens;
# CaptureItem.displayLabel is the only naming rule those screens use. This is the same
# textual gate plan 03-01 enforced.
# Ceiling: matches the qualified name only. `someVinylEntry.label` on an inferred-type local
# would slip past. That is D-03-6's own enforcement ceiling, not a new one introduced here.
absent G6 "no VinylEntry.label reference in App/ (D-03-6)" "VinylEntry\.label" App

# ---------------------------------------------------------------- G7: the requirement count
# FOUR commands that must agree WITH EACH OTHER, not one command compared against a number
# written in a document. A previous count was wrong in two directions at once — it
# double-counted one reopened requirement and omitted three others — and the two errors
# cancelled into a plausible-looking total. A single command cannot see that, and neither
# can a command checked against a hand-written expectation.
REQ=.planning/REQUIREMENTS.md
G7_EXPECTED_TOTAL=67
if [ ! -f "$REQ" ]; then
    skip G7 "requirement count — $REQ not found"
else
    C=$(grep -c '^- \[x\] \*\*' "$REQ")
    O=$(grep -c '^- \[ \] \*\*' "$REQ")
    T=$(grep -cE '^- \[.\] \*\*' "$REQ")
    D=$(grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+' "$REQ" | sort -u | wc -l | tr -d ' ')
    DUP=$(grep -oE '^- \[.\] \*\*[A-Z0-9]+-[0-9]+' "$REQ" | sed -E 's/^- \[.\] \*\*//' | sort | uniq -d)
    G7_ERR=""
    [ $((C + O)) -ne "$T" ] && G7_ERR="${G7_ERR}complete($C) + outstanding($O) = $((C + O)), but total = $T"$'\n'
    [ "$T" -ne "$D" ]       && G7_ERR="${G7_ERR}total = $T but distinct IDs = $D"$'\n'
    [ -n "$DUP" ]           && G7_ERR="${G7_ERR}duplicate requirement ID(s): $(printf '%s' "$DUP" | paste -sd, -)"$'\n'
    [ "$T" -ne "$G7_EXPECTED_TOTAL" ] && G7_ERR="${G7_ERR}total = $T against $G7_EXPECTED_TOTAL expected (distinct = $D)"$'\n'
    if [ -n "$G7_ERR" ]; then
        fail G7 "requirement count disagrees" "$(printf '%s' "$G7_ERR")"
    else
        pass G7 "requirement count agrees four ways: $C complete + $O outstanding = $T total = $D distinct, no duplicate ID"
    fi
fi

# ------------------------------------ G8: the retired non-decreasing BPM rule stays retired
# SEQ-03 went bidirectional on 2026-08-30 and Phase 5 cleared all 17 artefacts that
# CARRIED-DEBT.md section 2a inventoried. That ledger was a device for CARRYING an open debt --
# it asserted "A-rows + N-rows == live sweep hits", which is the right shape while the debt is
# outstanding and the wrong shape once it is paid: every new sentence merely DESCRIBING the
# change would break the sum, and it did (the gate was already red at 34 hits against 32 rows
# before Phase 5 touched anything).
#
# With the debt paid the honest gate is structural, in three parts.
#
# (a) The retired rule has two unmistakable executable forms and one marker. None has any
#     legitimate use. Prose words like "monotonic" or "ascending" are NOT usable here any more,
#     because the codebase now legitimately DESCRIBES the retirement and searches ascending in
#     stage 1 -- an absence gate on those words would ban explaining the change.
#     The patterns are built from concatenated fragments so this file cannot match itself.
# (b) The specs may discuss the retired rule but may not state it as current: any line naming it
#     must carry a supersession marker on that same line.
# (c) A positive check. Absence alone cannot tell you the RIGHT rule is in place, and a gate that
#     only proves something is missing is half a gate.
G8_ERR=""

G8_DEAD="$(printf 'b >''= a|bpm! >''= |\xe2\x9a\xa0\xef\xb8\x8f ST''ALE')"
G8_HITS=$(grep -rInE "${EXCL[@]}" "$G8_DEAD" "${CODE_TREES[@]}" docs .planning/ROADMAP.md 2>/dev/null)
[ -n "$G8_HITS" ] && G8_ERR="${G8_ERR}the retired rule is still written down as code or flagged stale:"$'\n'"$G8_HITS"$'\n'

# Markers accepted: SUPERSEDED, retired/RETIRED. A line may name the dead rule only to bury it.
G8_UNMARKED=$(grep -rInE "${EXCL[@]}" "non-decreasing|nondecreasing|monotonic" docs .planning/ROADMAP.md 2>/dev/null \
              | grep -vE "SUPERSEDED|retired|RETIRED")
[ -n "$G8_UNMARKED" ] && G8_ERR="${G8_ERR}spec states the retired rule with no supersession marker:"$'\n'"$G8_UNMARKED"$'\n'

G8_GATE=VinylSetBuilderCore/Sources/VinylSetBuilderCore/Sequencing/BPMRules.swift
grep -qF 'abs(b - a) <= tolerance' "$G8_GATE" 2>/dev/null \
    || G8_ERR="${G8_ERR}${G8_GATE}: canFollow is not the symmetric form 'abs(b - a) <= tolerance'"$'\n'

if [ -n "$G8_ERR" ]; then
    fail G8 "the retired non-decreasing BPM rule has come back" "$(printf '%s' "$G8_ERR")"
else
    pass G8 "retired non-decreasing rule absent from code and marked superseded in the specs; gate is the symmetric form"
fi

# ------------------------------------------------- G9: the defect ledger is adjudicated
# Sign-off gate S7: every V-row in VISUAL-DEFECTS.md is either CLOSED with a re-runnable
# evidence path, or CARRIED with a named owner phase and a written reason. Nothing may sit
# in between. S7 was the one sign-off gate judged by READING, and Phase 4's whole argument
# is that reading is not a gate.
#
# Shells out to Scripts/ledger-check.py rather than re-implementing the parse, for the same
# reason G2 shells out to the purity guard: there is one checker and it lives in one file.
#
# The checker PRINTS the Medium-or-above open count and never fails on it being non-zero.
# Two Medium rows are legitimately carried; S7 is about adjudication being complete, not
# about the count being zero. What that count means for the verdict is plan 04-05's call,
# against rules CONTEXT.md fixed in advance.
if [ ! -f Scripts/ledger-check.py ]; then
    skip G9 "defect ledger (S7) — Scripts/ledger-check.py not found"
else
    G9_OUT=$(python3 Scripts/ledger-check.py 2>&1); G9_RC=$?
    G9_SUMMARY=$(printf '%s\n' "$G9_OUT" | grep -E '^ledger: [0-9]+ rows,' | tail -1)
    if [ "$G9_RC" -ne 0 ]; then
        fail G9 "defect ledger not fully adjudicated (S7)" "$(printf '%s\n' "$G9_OUT" | grep -v '^ledger: [0-9]* rows,')"
    elif [ -z "$G9_SUMMARY" ]; then
        # A zero exit with no summary line means the checker did not actually run the
        # ledger. Same hazard as G2's: a gate that passes having measured nothing is the
        # worst kind, and ui-test.sh has exited 0 having run zero tests twice on this repo.
        skip G9 "defect ledger — checker exited 0 but printed no summary; it measured nothing"
    else
        pass G9 "${G9_SUMMARY#ledger: }"
    fi
fi

# ----------------------------------------------------------------------------- summary
printf '\ngates: %d pass, %d fail\n' "$PASSES" "$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
