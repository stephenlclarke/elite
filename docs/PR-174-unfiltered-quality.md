# PR handoff for issue 174: authored market order

## Resulting behavior

Compare the next commodity ID in authored display order, preserving cargo IDs and actual buy/sell navigation checks.

## Implementation and review

This is part of the single M01 release-blocker packet in [PR25](https://github.com/stephenlclarke/elite/pull/25), linked to [issue 174](https://github.com/stephenlclarke/elite/issues/174). The paired [issue note](ISSUE-174-unfiltered-quality.md) records the observed failure and scope. Independent source review found two draft defects in component filler placement and stock-limited reservation assertions; both were corrected and reviewed again. No passing execution is claimed yet.

## Validation

Swift formatting and diff hygiene pass. The one combined normal affected-unit batch is pending on the frozen source. Existing unrelated reviewed/tested evidence is reused within its original scope. Required final-head make ci, main-only SonarQube with exact source SHA, signing/notarization and protected publication remain required.

## Compatibility and risks

No save schema, permissions, simulation authority, solver tolerance or quality threshold is weakened. Issue185 is still an unknown-cause terminal fault. The preserved moving-debris case may still fail and must supply actual geometric evidence before any solver correction.

## First combined normal execution

Source `6423e889ab76109f04821e4159fb110be0f9b779` compiled successfully in284.84seconds and completed135 methods in39.895seconds (326.039040208seconds overall). The actual XML records131 passing methods, four failing methods and six failure elements, with zero errors or skips. Every one of the original62 failure methods completed;60 passed. The [per-method receipt](evidence/M01-authored-fixture-unit-results.json) preserves exact selection, durations and status. This is a failed aggregate, not full quality or release qualification.

Remaining failures are the actual -3000 debris/NPC continuation, peaceful classic-frame shield normalization, recovered ECM baseline normalization and a bounded ore-recovery timeout interrupted by game over. Issue186 records the conservative affine-enclosure candidate; three fixture corrections accompany its focused follow-up. No SIGBUS occurred in this run. Issue185 remains unattributed and open, independent of these assertion results.
