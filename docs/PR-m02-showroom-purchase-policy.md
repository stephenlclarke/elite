# fix(showroom): enforce declared hull purchase restrictions

The shared showroom quote now reports a refusal for `purchasePolicy = "never"`, even in XYZZY mode. A `xyzzyOnly` hull requires the existing commander's actual XYZZY flag. Confirmation already recomputes the same quote before publishing the copied transfer candidate, so losing access after opening the offer cannot debit cash or exchange equipment. The existing unpriced message is retained separately.

Three deterministic regression methods contain five cases. Both ordinary and XYZZY commanders attempt a physically compatible, positive-price Escape capsule purchase and must keep their full Commander unchanged; an ordinary eligible hull remains quotable. The Liberator cases compare denied ordinary access with allowed XYZZY access, including actual confirmation, finite resulting cash and retained portable item IDs, provenance and component history. The final method opens an allowed restricted offer, removes access before confirmation and verifies refusal preserves owned property.

Only these three new methods are enclosed in `ShipPurchasePolicyUnitTests`. The maintained isolated selector requires a suite/method boundary, which their original top-level declarations did not provide. Their bodies, parameters, assertions and five cases are unchanged; older top-level methods and the file-private fixture remain untouched. Source equivalence and formatting checks pass; native discovery is still unrun.

The existing portable-overflow, hull-bound item disposal, copied-candidate rollback, resource conservation and mission event-capacity rules are credited and unchanged. No inventory codec, metadata, blueprint provider, schema, save path, showroom display/comparison, controls, help, CI or shared ledger changes. The patch adds no item-count cap, price adjustment or acquisition grant.

Standalone Swift formatting and whitespace checks pass. Static catalogue inspection confirms the actual positive prices and declared restrictions used by the regressions. Scoped Markdown lint passes. The new Swift methods are **UNRUN**: no compiler, native test, sanitizer, process probe or profiling ran while G1 held the native executor. Static checks do not establish runtime acceptance. This frozen packet remains in development/validation pending independent review and G1's focused execution; it is not ready for integration or release. No push or merge is performed.

Related issue: [showroom purchase-policy bypass](ISSUE-m02-showroom-purchase-policy.md).
