# Pr 210: Keep both selected showroom textures visible at actual native sizes

## Motivation

Required quality run [40062040085](https://github.com/stephenlclarke/elite/actions/runs/40062040085) at `a890a93c7e7d698fd8a308cbb39dad75fe892278` completed3395normal methods with99issue records across55distinct methods. All1879retained source/build inputs match the published head. The helper exited naturally with status1; no SIGBUS recurred. Coverage execution failed, so later sanitizer and leak gates were not established.

## Bounded correction and preserved behavior

SH169/SH170 showroom test sees empty textured triangle list in two width/height cases. Renderer images still proceed; identify which selected craft/viewport lacks visible textured faces, check current selection/detail/layout and material mapping. Preserve real textured rendering at both sizes and bitmap assertions; do not replace with nonempty unrelated graphics. Exact geometry/culling cause pending.

This is one cause group in the single M01 correction packet, not a separate execution or review gate. Confirmed fixture changes explicitly establish their intended hull stock, cash, shop eligibility, authored world or codec envelope. Unattributed paths retain their original assertions and bounded failure-only facts until actual evidence establishes the cause. The physical runner arrangement retains the hard GPU assertions and every required quality command; [its authorization design](NATIVE-QUALITY-RUNNER.md) keeps untrusted events and unapproved heads out of native execution.

Affected methods:

- `bothSelectedTexturedShipsRenderThroughActualShowroomAtNativeSizes()`

## Validation and compatibility

The coherent actual patch and one combined affected/direct-consumer batch are pending independent review and execution. No passing result or issue closure is claimed. Previous524maintained unit passes and the earlier qualified repair scopes remain separate. No original feature, authority, ownership, physics, custody, allocation, save schema, renderer parity, coverage threshold or branch protection is weakened. The independent [terminal receipt](evidence/M01-a890-terminal-quality-review.json), [complete cause mapping](evidence/M01-a890-blocker-packets.json) and [issue mapping](evidence/M01-a890-blocker-issues.json) preserve exact assertions and source confidence.

## Links and remaining risks

[Issue 210](https://github.com/stephenlclarke/elite/issues/210); [PR25](https://github.com/stephenlclarke/elite/pull/25). Remaining unknowns require actual bounded unit evidence in the same batch. Full final-head quality, protected merge, committed-main-only SonarQube with exact source SHA and signed/notarized release acceptance remain required. Issue185 stays open pending full quality; this terminal run is not a recurring stack crash.

## Source-attributed fixture correction

The fresh fixture ownsSH025 and has no encounter discovery forSH169/SH170. The native showroom deliberately selects silhouette mode for either unowned undiscovered ship, regardless of the display-style preference. At wide size, the separately owned comparison baseline can emit textures and satisfy a frame-wide assertion while the selected ship remains a silhouette. The corrected test constructs each selected hull as the actual owned ship with valid fuel, missiles and native equipment, asserts the real preview policy is shaded and disables comparison. Both selected ships, both native sizes, actual textured triangles, finite vertices and bitmap assertions remain. The negative undiscovered-silhouette policy is explicitly retained. No discovery record, encounter, entitlement or product visibility rule is invented.
