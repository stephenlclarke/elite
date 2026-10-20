# test(equipment): bind storage and shop fixtures to their intended hulls

## Behavior and implementation

Three fuel-storage tests derive capacity from the independent catalogue base plus 70 units per installed storage unit. They preserve the 20,000-decicredit unit price, unchanged fuel during storage purchases, exact two-decicredit refill debit, insufficient-cash refusal and fitted-tank removal refusal. Automatic trading receives exactly the required refill funds; its zero-balance and full-tank assertions remain. The navigation grid retains every tier, storage count, partial/full fuel input, reach-ring, target reachability, map and search assertion, applying the native hull jump floor and published navigation steps.

The private equipment fixture selects actual SH023 before creating owned fittings, requires its two declared work tools and four facings, and initializes stock fuel, energy and shields. Its ordinary shop meets the maximum actual non-reward stock requirement. Negative availability selects an authenticated ordinary world below each item's requirement; the PLUGH availability and discount branch remains unchanged. All purchase-price, history, rollback, stale-quote, identity, hull-transfer and resource-fraction oracles remain.

## Validation

Strict Swift formatting, scoped Markdown lint and whitespace checks pass. The owner reviewed fixture prerequisites and the exact two-file diff. The finite owner selection is all thirteen `EquipmentRuntimeTransactionTests` methods, including both tool-order and six stale-quote arguments, plus the three changed fuel-storage methods: sixteen methods and twenty-two cases. Every changed helper consumer requires qualification; no old pass is reused for those consumers.

No build, test or runtime probe was run while authoring. Owner-focused qualification and an independent coherent review remain pending. Actual CI955 failures remain preserved. G1 coordinates the shared warm build and runtime batch with the existing executor.

## Compatibility and remaining work

No production code, catalogue specification, fresh-start default, save schema, equipment slot policy or global fixture changes. The unchanged invalid-legacy and first-hop routing fuel tests are outside this correction. Other CI failures and final coverage, sanitizer, leak and release gates remain separate. No remote PR exists. Companion: [ISSUE-storage-shop-fixture-context.md](ISSUE-storage-shop-fixture-context.md).
