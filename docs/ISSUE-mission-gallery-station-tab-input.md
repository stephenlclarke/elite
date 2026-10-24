# Use the actual flight station-selection key in mission gallery fixtures

## Recorded failures and contract

Root identified two terminal failures in validation 352: `nativeCourierAllSixPaintedAcceptTravelAndDeliverOnce` after 1.106 seconds and `campaignGalleryRootTrialFliesItsOwnedPatrolAndRestoresLiveSaveBytes` after 156.097 seconds. Their station-selection loops still sent flight key `r`. The documented native contract uses Tab; R has no flight-targeting action. Validation 349 already retained the actual Tab/R-no-action proof. This leaf does not claim either mission method has rerun or passed.

## Exact correction and callers

Change only the literal in `ScriptCourierGalleryTests.physicallyDeliverCourier` from `runtime.key("r")` to `runtime.key("tab")`, and the corresponding literal in the campaign root-trial station loop. The private courier helper has exactly one source call site, inside `nativeCourierAllSixPaintedAcceptTravelAndDeliverOnce`, used only for rows zero and one. That existing test remains one Swift Testing case containing six internal rows; rows two through five retain their separate existing travel path. The campaign change belongs to its single root-trial method. Affected scope is two existing methods/two cases, not eight cases or a shared global input change.

All controls, deltas and iteration budgets remain unchanged, including actual launch/jump/station approach and campaign combat/docking. Preserve real ship/station selection, alignment, collisions, delivery, receipts, namespace return, people and saved bytes. Do not inject targets, teleport, dock manually or weaken assertions. Other R inputs may be menu/retry actions and are untouched. Reversing exactly the two approved literals must recover both original Swift files byte-for-byte.

## Scope and validation

The isolated parent is `25574f2e1ebfc26c52fa33700eaeac9e48db853b`. Only the two existing Swift files and this issue/PR pair change. Courier caller bodies, other helpers/methods, all production and the separate effective-equipment work remain unchanged. The approved module-template `81aca5a` and wording child `748e44d`, plus all prior refs, are preserved.

Only source parsing/strict lint, Markdownlint and exact two-literal/caller/scope/hash/selection checks run here. No compiler, discovery, tests, build, native/UI/media, GitHub or composition jobs run. G1 reported 352 terminal preservation; Root's independent review remains pending. Root reviews the frozen source before integration/execution. See the [PR handoff](PR-mission-gallery-station-tab-input.md).
