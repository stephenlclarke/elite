# fix(pledges): finish preflight before preparing admission buffers

## Behavior and implementation

prepareContractAcceptance evaluates pledgePreview once after the existing courier resource checks, then runs the same pledge resource, nil-admission and next-event guards in their original order with the original errors. It passes the validated optional ScriptPledgePreview to the existing private prepareValidatedContractAcceptance helper. That helper only constructs the unchanged pledge admission from that value; it no longer calls pledgePreview or repeats the preflight checks.

All earlier terminal, board, pack, revision, offer-status, provider, deposit and procurement/freight/courier checks remain exact. The later courier admission, freight issue, acceptance event drain, completed transaction validation and publication remain exact. Only pure nonthrowing clock/deadline/job/instance-identity construction moves after pledge checks. No await, clock advance or resource mutation intervenes, and complete funded acceptance simulation still occurs. This is neither a quote shortcut nor a new authorization.

Only ScriptContractCore.swift and these paired notes change. There is no new helper, inline annotation, public API, storage or schema. ScriptPledge.swift, the previous assets borrow, original relief reserve checks and every test file are preserved.

## Exact focused qualification

Seven unchanged methods declare thirty cases:

- typedUnaffordableFoodPledgeRefreshesTrialBoardWithoutChangingProperty: one actual fault-producing case, including funded credit quotes, typed refusal, stale presentation and live property/save isolation.
- pledgeFullNativeThresholdsNeverTransferPartialAmounts: eighteen cases, tiers1/2/3 x credits/Food x offsets-1/0/+1.
- pledgeAssistsAndProtectedPayloadsNeverSupplyFoodOrMoney: one case.
- pledgeRejectedAcceptedHandlersNeverPublishAnUnpaidAssignment: seven cases, omission/milestone/late-command/early-debit/fault/deferred/backlog.
- pledgeFilesystemFailureRetainsOfferAndOneValidRetryPublishesExactlyOnce: one case.
- rejectedDirectAcceptanceStillSettlesAnAlreadyExpiredCourierExactlyOnce: one case.
- pledgeSixFixedOffersQuotesAndBackPreserveActualProperty: one case covering all six funded/refusing offers and Back without property transfer.

MBA source authoring, formatting and strict lint, plus local Markdown, diff, exact guard/action parity and unchanged-test checks precede G1's matching build/cohort. Native outcomes and the one complete independent three-path review remain pending. No author native build, test, probe, debugger or duplicate symbolication occurs. The source proves preflight and job/admission call-lifetime separation; it does not measure emitted frames or establish hosted success. See [the actual repeated failure](ISSUE-pledge-preflight-lifetime.md).
