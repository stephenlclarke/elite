# Enforce declared hull purchase restrictions in showroom quotes

M02.P03 already retains portable overflow, component and item identities, copied-candidate rollback, finite cash, resources and mission event reservation. The remaining admission gap is independent of those transfer rules: a showroom quote checks price and fit but ignores the selected hull's authoritative purchase policy.

The actual SH040 Escape capsule is player-flyable and has a positive 40,000 CR reference price, while its metadata says `purchasePolicy = "never"` and `normalPurchaseEligible = false`. A compatible empty commander can therefore exchange into it through the old quote and confirmation path. SH171 Liberator is `xyzzyOnly`, but the old quote also ignores the commander's current XYZZY access. A reference price and flyable mechanics do not grant purchase permission.

Refuse `never` purchases in every mode and require the existing `commander.xyzzyActive` flag for `xyzzyOnly`. Keep these checks in the shared quote used by both presentation and confirmation. Preserve the separate zero-price refusal, normal eligible hulls, all financial and physical compatibility checks, and atomic transfer behavior. This does not create blueprint ownership, fabrication authority, a new access mode or an equipment migration.

Scope is `ShipTrade.swift`, exact transaction regressions in `ShipTradeTests.swift` and this note pair. The branch starts at integrated main `e2910137`; the live M01 correction and validation stay with G1. Root owns the completion ledger and independent review. See [the patch handoff](PR-m02-showroom-purchase-policy.md).

The three added methods belong to `ShipPurchasePolicyUnitTests` so the maintained isolated selector can name their exact suite/method boundaries. Older top-level tests stay in place. This test-only follow-up preserves every new argument and assertion; actual Swift discovery remains unrun.
