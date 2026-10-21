# Pledge preview passes a whole Commander to a read-only asset helper

## Actual failure and source trace

Public head c950c52ab06fe504bb56766a5a2c36583d8fb49c failed hosted CI39544576745. G1 verified all nineteen original artifact hashes. The live fault-thread link register0x110353d00 resolves to Game.pledgePreview(board:offer:)+1320 beneath chkstk, with retained image UUID9E03EE3A-C795-3588-8406-B9EF06483AE0. The raw unwinder shows its caller prepareValidatedContractAcceptance at ScriptContractCore.swift364, followed by contract quote/board refresh and the actual nonparameterized typedUnaffordableFoodPledgeRefreshesTrialBoardWithoutChangingProperty producer. This is a different caller from the previously corrected front-visibility reader. The exact failed allocation and copy size remain unproved.

pledgePreview calls pledgeAssets with the current Commander. That helper declares a by-value Commander parameter while only reading cash, Food, unreserved Food and station standing. The same helper reads the candidate before authority comparison and after the actual debit/standing update in applyPledgeCommand. None of these calls needs an owned Commander or retains a reference beyond the synchronous projection.

## Bounded correction and acceptance

Change only that parameter to borrowing Commander. Preserve all helper expressions, call sites, guard/error ordering, resource and admission checks, complete quote acceptance simulation, candidate transaction and rollback behavior. Do not move preflight checks or add storage, helper, API or inline attributes.

Use the unchanged actual typed refusal producer plus complete threshold, protected-asset, rejected-handler, filesystem retry and expired-courier regressions. G1 owns matching compilation and execution, followed by one complete independent three-path bugs/performance/style review before integration. Source-level borrowed intent removes the explicit by-value parameter contract; it does not measure emitted frame savings or guarantee hosted crash repair. See [the implementation handoff](PR-pledge-assets-borrow.md).
