# PR handoff for issue 182: work scene geometry

## Resulting behavior

Use an explicitly compatible conventional work hull and a naturally RRS-free world for the deliberately single-target/small-obstacle scenes. Keep actual scoop, spin, actor, steering, cutter and clearance assertions.

## Implementation and review

This is part of the single M01 release-blocker packet in [PR25](https://github.com/stephenlclarke/elite/pull/25), linked to [issue 182](https://github.com/stephenlclarke/elite/issues/182). The paired [issue note](ISSUE-182-unfiltered-quality.md) records the observed failure and scope. Independent source review found two draft defects in component filler placement and stock-limited reservation assertions; both were corrected and reviewed again. No passing execution is claimed yet.

## Validation

Swift formatting and diff hygiene pass. The one combined normal affected-unit batch is pending on the frozen source. Existing unrelated reviewed/tested evidence is reused within its original scope. Required final-head make ci, main-only SonarQube with exact source SHA, signing/notarization and protected publication remain required.

## Compatibility and risks

No save schema, permissions, simulation authority, solver tolerance or quality threshold is weakened. Issue185 is still an unknown-cause terminal fault. The preserved moving-debris case may still fail and must supply actual geometric evidence before any solver correction.
