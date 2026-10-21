# fix(pledges): borrow commander for asset projections

## Implementation and compatibility

pledgeAssets now accepts borrowing Commander. Its body remains exact: it reads cash, Food, sellable Food and station standing into the existing owned ScriptPledgeAssets value. The preview's current Commander and the command's inout candidate are borrowed only during each synchronous call; no closure, pointer or access escapes, and the candidate is mutated only after the prior read call returns.

Only ScriptPledge.swift and these paired notes change. There is no new helper, inline attribute, API, quote shortcut, storage representation or transaction/preflight reordering. All pledge validation, resource limits, receipts, candidate publication, rollback and actual side-effect simulation remain unchanged. All test files are preserved.

## Exact focused qualification

Six unchanged methods declare twenty-nine cases:

- typedUnaffordableFoodPledgeRefreshesTrialBoardWithoutChangingProperty: one actual fault-producing case, including funded credit quotes, unaffordable Food refresh, stale presentation and isolated live property/save bytes.
- pledgeFullNativeThresholdsNeverTransferPartialAmounts: eighteen cases, tiers1/2/3 x credits/Food x resource offsets-1/0/+1, including actual accepted before/after assets and repeated confirmation.
- pledgeAssistsAndProtectedPayloadsNeverSupplyFoodOrMoney: one case, reserved/protected stock and native resource accounting.
- pledgeRejectedAcceptedHandlersNeverPublishAnUnpaidAssignment: seven cases, omission/milestone/late-command/early-debit/fault/deferred/backlog, preserving unpaid-assignment refusal and original property.
- pledgeFilesystemFailureRetainsOfferAndOneValidRetryPublishesExactlyOnce: one case, refused durable publication and one valid retry.
- rejectedDirectAcceptanceStillSettlesAnAlreadyExpiredCourierExactlyOnce: one case, preserving terminal-resolution ordering before a later refusal.

Source-only formatting, strict lint, Markdown, diff and exact one-parameter/test preservation checks precede G1's one matching compile and this cohort. Native outcomes are pending; no author build, native test, debugger, symbolication replay or probe occurs. One complete independent three-path bugs/performance/style review follows owner PASS before integration, with required hosted CI still necessary. No measured copy/frame reduction or guaranteed hosted repair is claimed. See [the confirmed caller and uncertainty](ISSUE-pledge-assets-borrow.md).
