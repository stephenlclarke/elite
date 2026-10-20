# test(navigation): bind fixed route witnesses to their stock hull

## Implementation

The private navigation fixture explicitly selects actual SH023 before inventory or native-world preparation. It initializes actual stock fuel, energy and shields and requires the valid 70-unit/seven-LY fit. An optional initial computer preserves military setup for existing callers while allowing the paid-upgrade test to exercise its original standard-basic acquisition path.

The change affects setup and error propagation only. Every existing numerical, pricing, insufficient-funds, hop legality, path uniqueness, estimate, route progress and UI assertion remains. No expected value is replaced with an observed result. Fresh-start defaults and all production code remain unchanged.

## Validation and remaining work

Strict Swift formatting, scoped Markdown lint and whitespace checks pass. All eight methods consume the corrected fixture and require focused qualification; no prior pass is retained for them. No build, test or runtime probe was run while authoring. One bounded eight-method/eight-case qualification and independent coherent review remain pending, with G1 owning shared execution and integration.

The separate profit-bound witness investigation does not delay this packet and has no edits here. Final CI, coverage, sanitizer, leak and release acceptance remain separate. No remote PR exists. Companion: [ISSUE-navigation-stock-hull-fixture.md](ISSUE-navigation-stock-hull-fixture.md).
