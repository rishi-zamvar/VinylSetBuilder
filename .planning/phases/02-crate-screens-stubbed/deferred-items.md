# Deferred items — Phase 2

Out-of-scope discoveries logged rather than fixed, per the executor scope boundary.

| # | Found in | Item | Why deferred |
|---|----------|------|--------------|
| D-02-04-1 | plan 02-04, state 4 | `02-walk-03-capture-empty.png` and `02-walk-04-capture-with-vinyl.png` are **byte-identical** (md5 `ab046e5f0af917698ecf6504878a8ecf`). `CapturePlaceholderView` renders the crate name and two buttons and nothing that reflects the crate's contents, so adding a fixture vinyl is invisible on that screen. The photograph of state 4 is therefore not independent evidence; the vinyl's arrival is proven instead by state 5, where `sequenced-row-1` exists on the new crate's detail. | `App/` belongs to plan 02-03 under 02-04's constraints, and the capture screen is disposable scaffolding that Phase 3 replaces with the real camera. A vinyl count on the capture stub would be a one-line fix if Phase 3 wants the state visible before then. |
