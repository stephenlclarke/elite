# CI955 script fixture assumptions

## Motivation

Three observed script tests assume the former 1,000-decicredit starting balance, although the approved Rowan Calder starter now has 7,200. Their intended assertions concern an exact 500-decicredit delivery payment or forfeiture of the frozen deposit. A fourth test requires an accepted courier job to exercise provider exclusivity, but its implicit starter/origin now generates an unavailable itinerary.

## Bounded correction

Use each affected test's existing pre-action balance to calculate its exact payment or deposit outcome. Use the already qualified seven-LY `CourierNativeFixture.rows[0]` setup for the provider-exclusivity test and verify its independent seed, all six draws, path, offer identity and calendar bound before acceptance. Preserve rollback, file-pointer, custody, zero-settlement, progress-review, actual travel and suspended-provider assertions.

## Acceptance and boundaries

Qualify the four affected methods in one bounded shared batch after the current executor closes. Retain the six qualified deadline cases only with an explicit dependency proof. Generic fixtures, fresh-start defaults, production, pinned witness data and deadline cases remain unchanged. No remote issue exists. Companion: [PR-ci955-script-fixture-context.md](PR-ci955-script-fixture-context.md).
