# fix(render): avoid game captures in vertex transforms

Display.draw builds its transformed vertex and station-hatch arrays with reserved-capacity ordered loops. Each loop retains the same game.viewPosition(body.modelVector(vertex)) and center addition, in the same order. The ore lookup projects miningFields before its closure, which no longer captures Game. No signature, projection helper, axis transform or rendering policy changes; all remaining face/depth/material/clipping logic stays unchanged. This addresses the actual captured renderer closure boundary without claiming a proven native or hosted crash repair.

Only Display.swift, an appended independent regression in TargetingTests.swift and these paired notes change from source 99500a9f. All existing TargetingTests content, the full StationApproachTests and DisplayOptionsTests files, Game, TargetingComputer, AutoTargetControl, G09/W05 files and separately tracked assertion fixtures stay unchanged.

## Regression and matching owner selection

The new parameterized renderedVertexViewsPreserveIndependentNearPlaneAndViewportClipWitness method covers front, rear, left and right views. Explicit inverse-axis body bases and a nonzero center produce the same known asymmetric triangle in view space. Its A vertex is behind the near plane, both crossing edges intersect z=1 outside the viewport, and clipping yields three independently calculated exact wire segments. The expected coordinates are literals, not results from a copy of the production projection loop. The test checks full wire records and preserves screen/style/time; graphics rasterization is disabled to inspect retained primitives.

Matching owner selection is five methods/eight cases:

- narrowRefinementRefusesOversizeOrientationWallContactAndStaleAttainedMotion: unchanged exact crash route, one case.
- frontVisibilityUsesRenderedEdgesAndChangingMembershipNeverRepeatsVisitedShips: unchanged edge-based visibility and membership, one case.
- targetCameraIsLiveBoundedAndIndependentOfPlayerViewAndSimulation: unchanged camera/render/view isolation, one case.
- coloursPreserveWireGeometryAndPanelsAreOpaqueAndClipped: unchanged all-hull/angle/style geometry, including station drawing, one case.
- renderedVertexViewsPreserveIndependentNearPlaneAndViewportClipWitness(screen:): four view cases.

Author source parse/format/strict lint, exact existing-source preservation, paired Markdown and diff checks pass. Native compilation and all eight cases remain unrun by this author. G1 owns matching native qualification when available; real compiler/unit corrections precede one independent bugs/performance/style review of the passing freeze. Integration requires a clean review and later normal required CI. No native probe, changed test stack, concurrency, timeout, broad ABI audit or release-completion claim is included. See [the captured fault](ISSUE-display-vertex-stack.md).
