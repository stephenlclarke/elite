# test(navigation): bind fixed route witnesses to their stock hull

## Implementation

The private navigation fixture explicitly selects actual SH023 before inventory or native-world preparation. It initializes actual stock fuel, energy and shields and requires the valid 70-unit/seven-LY fit. An optional initial computer preserves military setup for existing callers while allowing the paid-upgrade test to exercise its original standard-basic acquisition path.

The change affects setup and error propagation only. Every existing numerical, pricing, insufficient-funds, hop legality, path uniqueness, estimate, route progress and UI assertion remains. No expected value is replaced with an observed result. Fresh-start defaults and all production code remain unchanged.

## Validation and remaining work

Strict Swift formatting, scoped Markdown lint and whitespace checks pass. All eight methods consume the corrected fixture and require focused qualification; no prior pass is retained for them. No build, test or runtime probe was run while authoring. One bounded eight-method/eight-case qualification and independent coherent review remain pending, with G1 owning shared execution and integration.

The separate profit-bound witness investigation does not delay this packet and has no edits here. Final CI, coverage, sanitizer, leak and release acceptance remain separate. No remote PR exists. Companion: [ISSUE-navigation-stock-hull-fixture.md](ISSUE-navigation-stock-hull-fixture.md).

## Qualification update - 20 October 2026

Earlier pending/UNRUN statements describe the author freeze. Matching965 incremental build passed. Actual966 completed the combined14-method/14-case run with zero issues or unknown outcomes, including this component's 8 methods / 8 cases. One independent coherent review is CLEAN. Exact reviewed paths integrate at`7bbc0d4c62841cd4a9aa45c95249f44fc922b7fd`; this documentation child records the later outcome. The original runner exited1 after treating four generated codecov outputs as immutable, and the nested command exit was not recorded. That failure remains preserved. Independent closure verified1925 actual compiled/resource artifacts, source/preferences and owned-process closure; Root accepted the evidence-classification correction and existing passing tests without rerun. No overall runner or CI success is claimed. Evidence: `/tmp/elite-navigation-shield-966/event-stream-qualification.json`, `/tmp/elite-navigation-shield-966/supplemental-guard-closure.json` and `/tmp/elite-navigation-qualified-canonical-integration/integration-receipt.json`. Broader CI, coverage, sanitizer, leak and release gates remain open; the signed preview runtime is unchanged.
