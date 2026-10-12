# Fix rotating ship wireframe gaps

## Change

Split each warped wing side into its two actual flat triangular facets. This gives hidden-face removal the correct surface normal for each visible segment and draws the wing creases. Move the title ship farther from the camera so its full rotating outline fits above the version text.

## Validation

The independent silhouette regression failed on Cobra, Viper, Sidewinder and missile orientations before the geometry fix. All eight hulls now pass 720 orientations each, covering five rolls and two pitch turns. Separate checks validate mesh planarity, convexity, outward normals and closed edge adjacency, plus title endpoint continuity and clearance from text.

Run `make ci`, `make readme-media` and `make sonar` for coverage, sanitizer/leak evidence, regenerated README media and exact-commit main-branch analysis. Inspect the rebuilt native app to confirm presentation.

## Compatibility and limits

Controls, save data and gameplay are unchanged. Hulls remain independent approximations; these checks establish geometric and rendering integrity rather than original blueprint fidelity. Deliberate viewport clipping in flight and hiding rear faces remain supported.

Problem: [ISSUE-ship-wireframe-segments.md](ISSUE-ship-wireframe-segments.md).
