# PR handoff for issue 185: unattributed terminal decoder fault

## Resulting behavior

Keep the actual SIGBUS open. Retained offline evidence identifies the decoder/freight/Commander-validation path but lacks actual fault address, mapped guard bounds and the caller beyond frame63. No speculative cause or production repair is claimed.

## Implementation and review

This is part of the single M01 release-blocker packet in [PR25](https://github.com/stephenlclarke/elite/pull/25), linked to [issue 185](https://github.com/stephenlclarke/elite/issues/185). The paired [issue note](ISSUE-185-unfiltered-quality.md) records the observed failure and scope. Independent source review found two draft defects in component filler placement and stock-limited reservation assertions; both were corrected and reviewed again. No passing execution is claimed yet.

## Validation

Swift formatting and diff hygiene pass. The one combined normal affected-unit batch is pending on the frozen source. Existing unrelated reviewed/tested evidence is reused within its original scope. Required final-head make ci, main-only SonarQube with exact source SHA, signing/notarization and protected publication remain required.

## Compatibility and risks

No save schema, permissions, simulation authority, solver tolerance or quality threshold is weakened. Issue185 is still an unknown-cause terminal fault. The preserved moving-debris case may still fail and must supply actual geometric evidence before any solver correction.
