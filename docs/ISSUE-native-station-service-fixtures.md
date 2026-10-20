# Native station service fixtures retain authenticated markets

## Motivation

CI955 records failures in NativeStationServiceTests, including the valid-Commander prerequisite in stationServiceApproach. That helper overwrites G04-S149 Food's immutable ask with 12. OriginalLiveMarkets.valid requires both prices to equal the authenticated seed. The original-main/PLUGH service helper repeats that overwrite and assumes a buy/sell round trip restores all cash, although native sales pay the separate bid.

## Scope and acceptance

Change only this test file and its paired notes. Retain fuel 10, cash 1000000, cargo one, native hull, source station identities, doorway crossing and all service/authority/receipt/load/fitting/refusal checks. Mutate live stock only. Require authenticated prices and valid market/Commander before service evaluation. Require actual buy debit, sale credit and stock conservation at both original-main and discovered PLUGH shops.

The changed approach helper has five direct test methods and 19 expanded cases; the original-service helper adds one method and two Boolean cases. Qualify those six methods and 21 cases, retaining no prior pass for any changed-helper consumer. The three other methods and seven cases use unchanged setup. Matching owner compilation, focused qualification and one independent review remain pending. Companion: [PR-native-station-service-fixtures.md](PR-native-station-service-fixtures.md).

## Prior fixture correction record

### Evidence and required correction

Checkpoint 216 reports launch/manual-cancel cases still docked and a missing directory enumerator in the main-arrival test. Space only dismisses the title/game-over screen; docked launch is key 0. The temporary storage constructor creates only its root, and the original main doorway receipt path does not automatically write a save generation, so its nested save directory need not exist.

Use the actual launch input, retaining manual cancellation and every stale-authority assertion. Explicitly create the exact main-arrival test directory for the existing strict file snapshot. Keep genuine doorway entry, typed destinations and all guards; no Core geometry or authority bug is established by these failures.

### Validation and limits

Strict Swift/Markdown lint and diff checks pass. Source reversal verifies the bounded changes preserve the rest of the original test files. No compilation or execution occurred in this worker; checkpoint 216 remains failed evidence. Focused execution and required composed `make ci` remain with the integration owner. See [the implementation](PR-native-station-service-fixtures.md).

### Exact integration exit caller

The shared `verifyNativeEntryAndExit` integration helper uses the same Space input while asserting actual undocking, receipt departure, ten-minute calendar advance and the typed exit pose. Correct that one input to key 0 as well. Its physical entry, persisted receipt and every original exit assertion remain; no geometry or authority guard changes.
