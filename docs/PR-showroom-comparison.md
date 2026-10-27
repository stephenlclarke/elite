# Complete compact showroom comparison previews

Compact specification views now show the current or pinned baseline model beside the selected model. Compact browsing keeps its existing single preview. Wide comparison, shared rotation, discovery rendering, source-profile units, carried-fit projection and trade behavior retain their existing implementations.

Three focused `ShowroomComparisonUnitTests` methods in `ShowroomUXTests.swift` cover:

- Both preview titles and bounded captions at 512, 768, 1000 and 1512 logical pixels, current and pinned baselines, compare-off and compact browsing.
- Actual projected panel vertices for identical owned meshes at four angles, with identical pitch/roll/yaw up to horizontal translation, visible rotation and frozen/resumed geometry when paused.
- Selected values against an actual owned-equipment transfer, baseline values against the original fitted craft, price against the quote, Better/Worse/Same direction and unchanged original property.

Local validation: strict Swift formatting/lint, Python report-validation fixtures and `git diff --check` pass. No local Swift compilation, Swift unit execution, integration, GUI, performance or broad quality campaign was run. The maintained hosted selection includes all three methods (244 total methods), preserving clinic acceptance and custody selections. Hosted compilation and execution remain pending; MBA reviews the final PR head. Existing `ShipComparisonPrecisionUnitTests` retain rounding, lower-is-better and unavailable/incompatible-unit checks.

Compatibility: presentation-only change; no save, runtime, geometry, catalogue, equipment or purchasing schema changes. Visual usability is not claimed from source/unit checks. See the [issue](ISSUE-showroom-comparison.md). Ledger M02.P04 / F06.
