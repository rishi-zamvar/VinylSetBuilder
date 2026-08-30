#!/usr/bin/env python3
"""Act I sign-off gate S7, made executable.

S7 is the one sign-off gate that has been judged by reading: *every open V-row in
VISUAL-DEFECTS.md is either closed with an evidence path, or carried with a named owner
phase and a written reason.* Phase 4's whole argument is that reading is not a gate, so
this script is that sentence, decidable by one command, and it runs as gate G9 of
Scripts/hygiene.sh.

It parses ONLY the pipe-separated block under "## Ledger — machine-readable" and ignores
everything above it. The human table is prose with struck-through cells and multi-sentence
evidence; parsing it reliably is more work than it is worth, and restructuring it would
break the many documents that quote it.

    ID | SEVERITY | STATUS | OWNER | EVIDENCE_OR_REASON

Checks
  1. every row parses into exactly five pipe-separated fields
  2. STATUS is exactly CLOSED or CARRIED — there is no third state
  3. SEVERITY is Medium, Low, Informational or the em-dash
  4. CLOSED  => EVIDENCE_OR_REASON carries a re-runnable evidence path
  5. any row citing a .png => that .png exists under Artifacts/screenshots/
  6. CARRIED => OWNER names a phase (Phase N)
  7. CARRIED => EVIDENCE_OR_REASON is a reason, not "still open" (length floor)
  8. no duplicate IDs, and the block's IDs match the human table's exactly
  9. the ledger's headline count line agrees with the block it summarises

The accepted evidence forms are deliberately narrow, and there are five of them:

    a .png basename          — a photograph, checked for existence
    SomethingTests.swift     — a named test file
    test_something           — a named test function
    a 7+ character SHA       — a commit
    NOT-A-DEFECT             — the ONE named exception, and it is named rather than
                               letting arbitrary prose through. V2 closed because the
                               pallor was the launch fade: it was never a defect, so
                               there is no fix to photograph and no commit to cite.
                               Widening the regex to accept prose would let "Fixed"
                               through, which is exactly what this gate exists to reject.

The Medium-or-above count is PRINTED whether it is zero or not, and a non-zero value is
never treated as a failure. S7 is about adjudication being complete, not about the count
being zero — two Medium rows are legitimately carried. Whether a non-zero count changes
the verdict is 04-05's decision, made against rules CONTEXT.md fixed in advance. This
script reports the number and does not editorialise on it.

Usage:  ledger-check.py [--ledger PATH] [--shots DIR] [--selftest]
"""

import os
import re
import sys

LEDGER_DEFAULT = ".planning/VISUAL-DEFECTS.md"
SHOTS_DEFAULT = "Artifacts/screenshots"
SECTION = "## Ledger — machine-readable"

STATUSES = ("CLOSED", "CARRIED")
SEVERITIES = ("Medium", "Low", "Informational", "—")
MEDIUM_OR_ABOVE = ("Medium",)
MIN_REASON_CHARS = 30

ROW = re.compile(r"^(V\d+)\s*\|")
HUMAN_ROW = re.compile(r"^\| ~{0,2}(V\d+)~{0,2} \|")
PNG = re.compile(r"[\w.\-]+\.png")
HEADLINE = re.compile(
    r"\*\*(\d+) rows: (\d+) closed, (\d+) carried, "
    r"of which (\d+) (?:is|are) Medium or above\.\*\*"    # grammar only; the number is the gate
)
EVIDENCE_FORMS = (
    ("a .png basename", PNG),
    ("a named test file", re.compile(r"\b[A-Za-z][A-Za-z0-9]*Tests\.swift\b")),
    ("a named test function", re.compile(r"\btest_\w+")),
    ("a commit SHA", re.compile(r"\b[0-9a-f]{7,40}\b")),
    ("the NOT-A-DEFECT exception", re.compile(r"\bNOT-A-DEFECT\b")),
)


def parse(text):
    """Return (human_ids, rows, headline) — rows are lists of raw pipe-split fields."""
    if SECTION not in text:
        return [], None, None
    above, below = text.split(SECTION, 1)
    human_ids = [m.group(1) for line in above.splitlines()
                 for m in [HUMAN_ROW.match(line)] if m]
    rows = [line.split("|") for line in below.splitlines() if ROW.match(line)]
    m = HEADLINE.search(below)
    headline = tuple(int(g) for g in m.groups()) if m else None
    return human_ids, rows, headline


def check(text, shots_dir):
    """Return (problems, counts). Every problem names the row it is about."""
    problems = []
    counts = {"rows": 0, "closed": 0, "carried": 0, "medium_open": 0}

    human_ids, rows, headline = parse(text)
    if rows is None:
        return ["no '%s' section in the ledger" % SECTION], counts
    if not rows:
        return ["the '%s' section has no V-rows in it" % SECTION], counts

    seen = []
    for raw in rows:
        rid = raw[0].strip()
        fields = [f.strip() for f in raw]

        # 1. exactly five fields
        if len(fields) != 5:
            problems.append("%s: %d pipe-separated fields, expected exactly 5 "
                            "(ID | SEVERITY | STATUS | OWNER | EVIDENCE_OR_REASON)"
                            % (rid, len(fields)))
            continue
        _, severity, status, owner, ev = fields
        counts["rows"] += 1

        # 8a. no duplicate IDs
        if rid in seen:
            problems.append("%s: duplicate ID — it appears more than once in the block" % rid)
        seen.append(rid)

        # 2. status
        if status not in STATUSES:
            problems.append("%s: STATUS is '%s' — a row is CLOSED or CARRIED, there is no "
                            "third state. A row that is neither is what S7 forbids." % (rid, status))
            continue

        # 3. severity
        if severity not in SEVERITIES:
            problems.append("%s: SEVERITY is '%s' — expected one of %s"
                            % (rid, severity, ", ".join(SEVERITIES)))

        if status == "CLOSED":
            counts["closed"] += 1
            # 4. a re-runnable evidence path
            if not any(rx.search(ev) for _, rx in EVIDENCE_FORMS):
                problems.append(
                    "%s: CLOSED with no re-runnable evidence path — %r cites no .png, no "
                    "Tests.swift, no test_ function, no commit SHA and is not NOT-A-DEFECT. "
                    "'Fixed' is not evidence." % (rid, ev[:60]))
        else:
            counts["carried"] += 1
            if severity in MEDIUM_OR_ABOVE:
                counts["medium_open"] += 1
            # 6. a named owner phase
            if not re.search(r"\bPhase \d+", owner):
                problems.append(
                    "%s: CARRIED to OWNER '%s', which names no phase. A carry to a phase "
                    "that never re-opens the artefact is an abandonment wearing a due date; "
                    "a carry to no phase at all is not even that." % (rid, owner))
            # 7. a reason, not a restatement
            if len(ev) < MIN_REASON_CHARS:
                problems.append(
                    "%s: CARRIED with a %d-character reason, under the %d-character floor — "
                    "%r. 'Still open' is not a reason." % (rid, len(ev), MIN_REASON_CHARS, ev))

        # 5. every cited .png exists. This is what makes an evidence path RE-RUNNABLE
        #    rather than decorative: a row citing a frame a later regeneration renamed or
        #    dropped is a broken evidence path and should be loud. Applied to CARRIED rows
        #    as well as CLOSED ones, because a carried row's evidence rots the same way.
        for name in dict.fromkeys(PNG.findall(ev)):
            if not os.path.isfile(os.path.join(shots_dir, name)):
                problems.append("%s: cites %s, which is not in %s/ — the evidence path is "
                                "broken, not re-runnable" % (rid, name, shots_dir))

    # 8b. the block and the human table name the same rows
    for rid in sorted(set(human_ids) - set(seen), key=lambda r: int(r[1:])):
        problems.append("%s: in the human table but ABSENT from the machine-readable block — "
                        "it has no adjudicated verdict" % rid)
    for rid in sorted(set(seen) - set(human_ids), key=lambda r: int(r[1:])):
        problems.append("%s: in the machine-readable block but ABSENT from the human table — "
                        "a verdict for a row no reader can find" % rid)

    # 9. the headline count line is derived, so it must agree with what it summarises
    if headline is None:
        problems.append("the ledger has no headline count line of the form "
                        "'**N rows: C closed, K carried, of which M are Medium or above.**'")
    else:
        want = (counts["rows"], counts["closed"], counts["carried"], counts["medium_open"])
        if headline != want:
            problems.append("headline count line says %s but the block is %s — the headline "
                            "is derived, not typed, so a disagreement means one of them is "
                            "hand-edited" % (headline, want))
    return problems, counts


# --------------------------------------------------------------------------- selftest
# Nine synthetic ledgers, one per rule class. The gate is proved able to fail here on
# every rule, in addition to the four negative controls run against the real committed
# ledger. probe-frames.py --selftest set this precedent in plan 04-01.

_HEAD = SECTION + "\n\n**%d rows: %d closed, %d carried, of which %d are Medium or above.**\n\n"


def _ledger(rows, human=None, counts=None):
    ids = [r.split("|")[0].strip() for r in rows]
    human = ids if human is None else human
    table = "".join("| %s | x | x | x | x |\n" % i for i in human)
    if counts is None:
        c = sum(1 for r in rows if " CLOSED " in r)
        k = sum(1 for r in rows if " CARRIED " in r)
        m = sum(1 for r in rows if " CARRIED " in r and "| Medium |" in r)
        counts = (len(rows), c, k, m)
    return ("# fake\n\n" + table + "\n" + _HEAD % counts + "```\n" + "\n".join(rows) + "\n```\n")


_GOOD = [
    "V1 | — | CLOSED | Closed | fixed and photographed in real-frame.png, commit c81805d",
    "V2 | — | CLOSED | Closed | NOT-A-DEFECT — the pallor was the launch fade, not styling",
    "V3 | Medium | CARRIED | Phase 4 / U8 | blocked on U8: the two candidate fixes are a product call and the owner has not answered",
]


def selftest():
    import shutil
    import tempfile
    tmp = tempfile.mkdtemp(prefix="ledger-nc-")
    shots = os.path.join(tmp, "shots")
    os.makedirs(shots)
    open(os.path.join(shots, "real-frame.png"), "wb").close()

    def swap(i, new):
        rows = list(_GOOD)
        rows[i] = new
        return rows

    cases = [
        ("a well-formed ledger", _GOOD, True, ""),
        ("CLOSED with no evidence path",
         swap(0, "V1 | — | CLOSED | Closed | Fixed"), False, "V1"),
        ("CARRIED with no phase in OWNER",
         swap(2, "V3 | Medium | CARRIED | later | blocked on U8: the two fixes are a product call and unanswered"),
         False, "V3"),
        ("CLOSED citing a frame that is not on disk",
         swap(0, "V1 | — | CLOSED | Closed | photographed in does-not-exist.png"), False, "does-not-exist.png"),
        ("a status that is neither CLOSED nor CARRIED",
         swap(0, "V1 | — | OPEN | Closed | fixed and photographed in real-frame.png"), False, "OPEN"),
        ("CARRIED with a restatement instead of a reason",
         swap(2, "V3 | Medium | CARRIED | Phase 6 | still open"), False, "V3"),
        ("a row with the wrong field count",
         swap(1, "V2 | — | CLOSED | NOT-A-DEFECT"), False, "expected exactly 5"),
        ("a duplicate ID",
         _GOOD + ["V1 | — | CLOSED | Closed | again, real-frame.png"], False, "duplicate"),
        ("a severity outside the four", swap(1, "V2 | Critical | CLOSED | Closed | NOT-A-DEFECT"), False, "Critical"),
    ]

    ok = True
    for name, rows, want_green, expect in cases:
        problems, _ = check(_ledger(rows), shots)
        green = not problems
        hit = expect in " ".join(problems)
        good = (green == want_green) and (want_green or hit)
        ok &= good
        print("%s  %-46s  %s" % ("PASS" if good else "FAIL", name,
                                 "green" if green else "; ".join(problems)[:100]))

    # the human-table cross-check, both directions
    for name, human, expect in (
            ("a row in the table but not the block", ["V1", "V2", "V3", "V9"], "V9"),
            ("a row in the block but not the table", ["V1", "V2"], "V3")):
        problems, _ = check(_ledger(_GOOD, human=human), shots)
        good = any(expect in p and "ABSENT" in p for p in problems)
        ok &= good
        print("%s  %-46s  %s" % ("PASS" if good else "FAIL", name, "; ".join(problems)[:100] or "green"))

    # the headline must be derived, not typed
    problems, _ = check(_ledger(_GOOD, counts=(3, 2, 1, 0)), shots)
    good = any("headline count line" in p for p in problems)
    ok &= good
    print("%s  %-46s  %s" % ("PASS" if good else "FAIL", "a headline that disagrees with its block",
                             "; ".join(problems)[:100] or "green"))

    shutil.rmtree(tmp)
    print("selftest: %s" % ("all cases behaved as specified" if ok else "SOME CASES DID NOT"))
    return 0 if ok else 1


def main(argv):
    ledger, shots = LEDGER_DEFAULT, SHOTS_DEFAULT
    args = argv[1:]
    while args:
        a = args.pop(0)
        if a == "--selftest":
            return selftest()
        elif a == "--ledger":
            ledger = args.pop(0)
        elif a == "--shots":
            shots = args.pop(0)
        else:
            sys.stderr.write("unknown argument %r\n%s\n" % (a, __doc__.strip().splitlines()[-1]))
            return 2

    if not os.path.isfile(ledger):
        print("ledger: %s not found" % ledger)
        return 1
    problems, c = check(open(ledger, encoding="utf-8").read(), shots)
    for p in problems:
        print("ledger: %s" % p)
    print("ledger: %d rows, %d closed, %d carried, %d Medium-or-above open"
          % (c["rows"], c["closed"], c["carried"], c["medium_open"]))
    if problems:
        print("LEDGER CHECK FAILED — %d problem(s)" % len(problems))
        return 1
    return 0


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.exit(main(sys.argv))
