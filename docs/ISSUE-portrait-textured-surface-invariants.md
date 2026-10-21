# Full-rotation portrait checks exclude actual textured surfaces

## Observed evidence and cause

The active full CI checkpoint 222 reports 48 visibility assertions in `everyModelRemainsVisibleFiniteAndFramedThroughoutFullRotation`: SH169 and SH170 at all 24 angles. This is partial-run evidence, not a completed gate result. The test requires nonempty flat `shipPanels`; the renderer intentionally emits textured triangles instead of flat panels when a source texture is loaded. The existing flat-panel vertex check also does not exercise textured geometry.

## Required correction

Use the existing ship-surface presence query and retain the original flat-panel finite/in-viewport check. Check every actual textured triangle for exactly three valid vertices, points inside the portrait viewport and the same clipping rectangle. Keep all 171 models and all 24 angles; do not skip textured hulls, substitute models or alter texture/material/rendering code.

`shipPortrait` already sets its correct portrait viewport, unlike the previously corrected showroom clip. No renderer bug is established by these failures. See [the implementation](PR-portrait-textured-surface-invariants.md).

## Validation and limits

Strict source/Markdown lint and whitespace checks pass. Source reversal reconstructs the entire original test file. No compilation, rendering or test execution occurred in this worker; the integration owner will review and validate after checkpoint 222 closes.
