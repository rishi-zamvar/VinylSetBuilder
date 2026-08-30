#!/bin/bash
# Act I sign-off gate S5/S6, made executable.
#
# The roadmap's Phase 4 criterion is a sentence: "no dead code, no unused protocol
# conformances, no TO-DO comments, consistent naming, and CorePurityTests still green."
# This script is that sentence, decidable by one command.
#
# set -u and pipefail, but deliberately NOT -e: every gate must run and report, so that
# one red gate cannot hide the state of the other seven.
set -uo pipefail
cd "$(dirname "$0")/.."

PASSES=0
FAILS=0
pass() { printf 'PASS %s  %s\n' "$1" "$2"; PASSES=$((PASSES + 1)); }
fail() { printf 'FAIL %s  %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); [ $# -ge 3 ] && printf '%s\n' "$3" | sed 's/^/         /'; }
skip() { printf 'SKIP %s  %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }   # a skipped gate is NOT a passed gate

CODE_TREES=(App VinylSetBuilderCore/Sources VinylSetBuilderCore/Tests UITests)
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

# ------------------------------------------- G4: the Phase 9 gap, re-confirmed not closed
# Plan 01-05 was written and never executed. This gate RE-CONFIRMS the absence; it does not
# close it. SEQ-08/09/10 are wholly outstanding. See phases/04-act-i-signoff/CARRIED-DEBT.md.
absent G4 "AsyncSequencer/BeamDivergenceCheck still absent (Phase 9 gap, confirmed not closed)" \
       "AsyncSequencer|BeamDivergenceCheck" App VinylSetBuilderCore UITests

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
#   MetadataResolving   a DECLARED SEAM, not dead code. It lost its only conformance when
#                       FixtureMetadataResolver was deleted (04-02 Task 1), so it now has
#                       zero references — but Phase 7 (RES-01..08) implements the real
#                       resolver against it. SETUP-02 exists to create seams like this.
#                       Deleting a seam because it currently has no caller is deleting the
#                       architecture. The rule: keep a protocol iff a NAMED future phase's
#                       requirements implement it. This one names Phase 7.
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
        n=$(grep -rl --include='*.swift' "${EXCL[@]}" "\b${name}\b" "${CODE_TREES[@]}" 2>/dev/null \
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

# ------------------------------------- G8: the monotonic-BPM inventory matches the tree
# SEQ-03 went bidirectional on 2026-08-30. The retired non-decreasing rule survives in the
# shipped Act I code and docs. Phase 4 owns the LEDGER; Phase 9 owns the CODE, and must
# start from an unmodified baseline, so nothing here edits an artefact.
#
# The gate: CARRIED-DEBT.md classifies EVERY hit of the two-pass sweep as either an
# artefact (A-rows: asserts or implements the retired rule) or a non-artefact (N-rows:
# matched the sweep for an unrelated reason). Deleting a row, or a new artefact appearing
# in the tree, breaks the sum.
#
# Pass 1 is prose and is case-INSENSITIVE: the case-sensitive form specified at planning
# time silently missed "Non-decreasing" and "Monotonic" in BPMRules.swift.
# Pass 2 is structural. It exists because the actual enforcement — `b >= a` in
# BPMRules.canFollow — contains no matching word at all and no prose pass can ever find it.
DEBT=.planning/phases/04-act-i-signoff/CARRIED-DEBT.md
DEBT_TREES=(VinylSetBuilderCore App UITests docs .planning/ROADMAP.md)
if [ ! -f "$DEBT" ]; then
    skip G8 "monotonic-BPM inventory — $DEBT not found"
else
    UNION=$( { grep -rniE "${EXCL[@]}" "non-decreasing|nondecreasing|monotonic|ascending" "${DEBT_TREES[@]}" 2>/dev/null
               grep -rnE  "${EXCL[@]}" "bpm! >= |b >= a|canFollow|⚠️ STALE"          "${DEBT_TREES[@]}" 2>/dev/null
             } | sort -u | wc -l | tr -d ' ')
    A=$(grep -cE '^\| A[0-9]+ \|' "$DEBT")
    N=$(grep -cE '^\| N[0-9]+ \|' "$DEBT")
    DECL=$(grep -oE 'ARTEFACT_COUNT=[0-9]+' "$DEBT" | head -1 | cut -d= -f2)
    G8_ERR=""
    [ -z "$DECL" ] && DECL=-1 && G8_ERR="${G8_ERR}no ARTEFACT_COUNT= declared in the inventory"$'\n'
    [ "$A" -ne "$DECL" ] && G8_ERR="${G8_ERR}inventory declares ARTEFACT_COUNT=$DECL but the table has $A A-rows"$'\n'
    [ $((A + N)) -ne "$UNION" ] && G8_ERR="${G8_ERR}A-rows($A) + N-rows($N) = $((A + N)), but the live two-pass sweep finds $UNION hits — $(( UNION > A+N ? UNION-A-N : A+N-UNION )) unaccounted"$'\n'
    if [ -n "$G8_ERR" ]; then
        fail G8 "monotonic-BPM inventory disagrees with the tree" "$(printf '%s' "$G8_ERR")"
    else
        pass G8 "monotonic-BPM inventory accounts for all $UNION sweep hits ($A artefacts + $N non-artefacts)"
    fi
fi

# ----------------------------------------------------------------------------- summary
printf '\ngates: %d pass, %d fail\n' "$PASSES" "$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
