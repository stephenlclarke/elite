# Fix mission catalog replacement, resource updates and profit estimates

Historical source handoff: the validation statements below describe its original checkpoint. Subsequent integration and exact-source execution are recorded in the [current qualified ledger](WHOLE-APP-REMEDIATION.md); they do not rewrite the original evidence.

This change addresses [CR-03, CR-04, CR-08, CR-12 and CR-13](ISSUE-mission-economy-review.md) against central base `b2d882e719ff3906b6c390c0df1ae57cfabae6e3`. The production and regression source checkpoint is `2d683988e73e9b69b7435c4befb697fc85d94b34`.

Gallery replacement retains the selected mission by its stable state ID across installed and missing-content entries. Removed selections are clamped, and detail access safely handles stale or empty catalogs. Installation checks the prospective external-file count before writing, permits identical reinstall at the original filename, and refuses an unrelated filename collision. A failed installation preserves both the current catalog and existing file bytes.

Mission hardware transitions stage energy and both shield levels only after the final fallible candidate validation, using explicit old and new capacities. The validated Commander and scalar resources publish in the same synchronous method. Unchanged capacities preserve their levels exactly. The existing equipment resource helper retains its behavior through a shared scalar function; the mission path adds no whole-Game copy.

Navigation sale values and cargo-detour eligibility use actual sellable quantities, preserving marked firearms. Profit scan accumulates signed values exactly in Decimal and clamps only the final public Int value. Ranking uses the unsaturated total before the existing system-ID tie break. Ordinary budget, hold, pricing and trade behavior remain unchanged. The separate central route-score correction belongs to the integrator.

## Source slices

- `3ebd8a02526619724111b514f262a6a51381df3a`: catalog replacement, installation limits and four focused regressions.
- `ace13c0196007a72e995bc4d8af7a82ecfc69a83`: mission resource preservation, real recovered outgoing hardware, actual dock/reward behavior and partial-mutation rollback.
- `2d683988e73e9b69b7435c4befb697fc85d94b34`: custody-aware valuation, safe profit arithmetic and boundary/ranking regressions.

## Validation

This is a source-only handoff. The implementation and tests are uncompiled and unexecuted. Root source review closed without a concrete blocker and authorized central integration. Strict Swift formatting lint across all ten changed source/test files and the base-to-head whitespace check passed. Markdown lint is checked separately for this handoff pair.

The new focused filter is `MissionCatalogueReplacementTests|MissionResourceFractionTests|NavigationCustodyTests|ProfitScanBoundsTests`: 14 declared methods and 17 declared case invocations, pending actual test discovery and execution. Related checks include the existing mission-pack, mission-equipment, recovered-equipment, navigation and profit-scan tests. The complete composed coverage, thread/address sanitizer and leak gates remain required under an exclusive validation lease; no separate branch result substitutes for them.

The changes preserve the accepted Mission branch and its evidence. Canonical equipment/loan/ammunition integration, renderer refresh, formal PR review, final-head checks and merge remain central integration steps. No standalone PR, push, feature Sonar analysis or public merge was performed by this handoff.
