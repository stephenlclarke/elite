# test(market): expect the actual bid after a mission recovery sale

## Change

The existing native Mission Gallery fault-recovery regression compares the one-tonne sale credit with market.bidPrice instead of market.price. It still performs the same real mouse input, requires the same sold cargo and increased market stock, and preserves all retained mission, pending-event, capacity and payload assertions. No production market, quote, cargo or mission logic changes.

## Evidence and validation

Actual667 recorded the mismatched credit assertion during the full coverage phase before a separate mission-completion stack crash. This source-only correction retains that exact regression and does not add a new test or relax an assertion. Swift formatting, repository Markdown lint and patch applicability are checked separately; runtime acceptance remains pending on the central integrator's coherent affected-case run with the material crash repair.

## Scope and risk

One expectation in ScriptGalleryTrialTests changes. No old-format compatibility, price override, artificial reward or fixture cargo grant is introduced. Base is f5e3421e029b6f2fffbbd91f5ed91c3f43335e72. No GitHub issue or PR was created. See [the source issue](ISSUE-gallery-market-sell-bid.md).
