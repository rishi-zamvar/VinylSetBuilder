# Deferred items — Phase 3

Out-of-scope discoveries, logged rather than fixed.

## D1 — `move(fromOffsets` appears in a Core doc comment

Found during 03-02's verification (`grep -rn "move(fromOffsets" VinylSetBuilderCore/Sources/`,
which the plan expects to return nothing).

`Crates/CrateDetailModel.swift:108` contains the string inside a comment explaining that the API
is **not** reachable from Core (D2-6). There is no call and no import; the grep gate is matching
prose. Pre-existing, landed in plan 02-01, unrelated to 03-02's changes, so it was not edited.

Fix, when someone is in that file anyway: reword the comment, or tighten the gate to ignore
comment lines. Either is a one-line change.
