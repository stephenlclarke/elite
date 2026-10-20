# test(equipment): bind storage and shop fixtures to their intended hulls

## Behavior and implementation

Three fuel-storage tests derive capacity from the independent catalogue base plus 70 units per installed storage unit. They preserve the 20,000-decicredit unit price, unchanged fuel during storage purchases, exact two-decicredit refill debit, insufficient-cash refusal and fitted-tank removal refusal. Automatic trading receives exactly the required refill funds; its zero-balance and full-tank assertions remain. The navigation grid retains every tier, storage count, partial/full fuel input, reach-ring, target reachability, map and search assertion, applying the native hull jump floor and published navigation steps.

The private equipment fixture selects actual SH023 before creating owned fittings, requires its two declared work tools and four facings, and initializes stock fuel, energy and shields. Its ordinary shop meets the maximum actual non-reward stock requirement. Negative availability selects an authenticated ordinary world below each item's requirement; the PLUGH availability and discount branch remains unchanged. All purchase-price, history, rollback, stale-quote, identity, hull-transfer and resource-fraction oracles remain.

## Validation

Strict Swift formatting, scoped Markdown lint and whitespace checks pass. The owner reviewed fixture prerequisites and the exact two-file diff. The finite owner selection is all thirteen `EquipmentRuntimeTransactionTests` methods, including both tool-order and six stale-quote arguments, plus the three changed fuel-storage methods: sixteen methods and twenty-two cases. Every changed helper consumer requires qualification; no old pass is reused for those consumers.

No build, test or runtime probe was run while authoring. Owner-focused qualification and an independent coherent review remain pending. Actual CI955 failures remain preserved. G1 coordinates the shared warm build and runtime batch with the existing executor.

## Compatibility and remaining work

No production code, catalogue specification, fresh-start default, save schema, equipment slot policy or global fixture changes. The unchanged invalid-legacy and first-hop routing fuel tests are outside this correction. Other CI failures and final coverage, sanitizer, leak and release gates remain separate. No remote PR exists. Companion: [ISSUE-storage-shop-fixture-context.md](ISSUE-storage-shop-fixture-context.md).

## Qualification update - 20 October 2026

The pending and UNRUN statements above describe the author freeze. One necessary963 cold matching build recovered a missing ignored build cache; actual964 then passed the single combined22-method/28-case selection, including this component's 16 methods / 22 cases, with zero issues or unknown outcomes. The exact parameter arguments, source/artifact/preferences guards and owned-process closure were verified. One independent coherent four-path review is CLEAN and was reused without a second review. Exact reviewed paths were integrated at`6703af17eadf3f67609bfe120f5bc57c63902d04`; this dated documentation child records the later outcome. Evidence: `/tmp/elite-fixture-union-964/event-stream-qualification.json` and `/tmp/elite-storage-shop-qualified-canonical-integration/integration-receipt.json`. No previous passing cohort or changed-helper caller qualification is inferred; full CI, coverage, sanitizer, leak and release gates remain open.
