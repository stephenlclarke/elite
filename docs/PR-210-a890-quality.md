# Pr 210: Keep both selected showroom textures visible at actual native sizes

## Motivation

Required quality run [40062040085](https://github.com/stephenlclarke/elite/actions/runs/40062040085) at `a890a93c7e7d698fd8a308cbb39dad75fe892278` completed3395normal methods with99issue records across55distinct methods. All1879retained source/build inputs match the published head. The helper exited naturally with status1; no SIGBUS recurred. Coverage execution failed, so later sanitizer and leak gates were not established.

## Bounded correction and preserved behavior

SH169/SH170 showroom test sees empty textured triangle list in two width/height cases. Renderer images still proceed; identify which selected craft/viewport lacks visible textured faces, check current selection/detail/layout and material mapping. Preserve real textured rendering at both sizes and bitmap assertions; do not replace with nonempty unrelated graphics. Exact geometry/culling cause pending.

This is one cause group in the single M01 correction packet, not a separate execution or review gate. Confirmed fixture changes explicitly establish their intended hull stock, cash, shop eligibility, authored world or codec envelope. The corrections retain their original behavioral assertions and bounded failure-only facts; the retained receipts establish their actual causes and scoped results. The physical runner arrangement retains the hard GPU assertions and every required quality command; [its authorization design](NATIVE-QUALITY-RUNNER.md) keeps untrusted events and unapproved heads out of native execution.

Affected methods:

- `bothSelectedTexturedShipsRenderThroughActualShowroomAtNativeSizes()`

## Validation and compatibility

The combined correction packet has independent source reviews and scoped executed results. Every original failing method (55 unique methods from 99 issue records) now has an individual passing result, with 12 additional direct consumers retained across the bounded follow-ups. This is a reconciled set of scoped passes, not a fresh aggregate full-suite run. The 14 native-runner fake units and both hard GPU methods also pass. The [combined focused receipt](evidence/M01-bb85-focused-qualification.json), [independent retained inventory](evidence/M01-bb85-retained-qualification-inventory.json) and [last four-phase save result](evidence/M01-bb85-terminal-verification.json) preserve source identity and limits. Final published-head checks, full `make ci`, committed-main SonarQube and release acceptance remain required. No issue closure or full quality/release pass is claimed.

## Links and remaining risks

[Issue 210](https://github.com/stephenlclarke/elite/issues/210); [PR25](https://github.com/stephenlclarke/elite/pull/25). Focused owner qualification is complete; Full final-head quality, protected merge, committed-main-only SonarQube with exact source SHA and signed/notarized release acceptance remain required. Issue185 stays open pending full quality; this terminal run is not a recurring stack crash.

## Source-attributed fixture correction

The fresh fixture ownsSH025 and has no encounter discovery forSH169/SH170. The native showroom deliberately selects silhouette mode for either unowned undiscovered ship, regardless of the display-style preference. At wide size, the separately owned comparison baseline can emit textures and satisfy a frame-wide assertion while the selected ship remains a silhouette. The corrected test constructs each selected hull as the actual owned ship with valid fuel, missiles and native equipment, asserts the real preview policy is shaded and disables comparison. Both selected ships, both native sizes, actual textured triangles, finite vertices and bitmap assertions remain. The negative undiscovered-silhouette policy is explicitly retained. No discovery record, encounter, entitlement or product visibility rule is invented.
