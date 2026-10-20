# Fuel storage and paid-shop fixture context

## Motivation

Observed CI955 failures assume a 70-unit stock tank, seven-LY native reach, independent work-tool slots and the former technology of system seven. The approved SH025 starter instead has a 130-unit tank, nine-LY native reach and no declared independent work tools. Current Avenor is TL12, while the private positive shop selector can choose TL10 despite stock items requiring TL11 or higher. A full SH025 tank also prevents the test's intended transfer to a 70-unit hull.

## Bounded correction

Keep generic storage assertions independent of the starter hull by reading its catalogue base and applying the declared 70-unit storage increment, exact purchase price and refuelling debit. Navigation assertions retain the native hull floor, declared seven-LY computer steps and published search-radius rules. Fund the controlled automatic-refill scenario for its actual full refill cost.

The paid-shop fixture explicitly selects the real SH023 work hull before preparing any inventory. Require its declared work-tool support and four weapon facings, initialize its stock resources, and choose an authenticated ordinary shop satisfying the real equipment technology requirements. The negative availability case selects a real shop below the tested item's requirement. Preserve paid history, item identity, prices, no-free-fuel, stale-quote refusal, transaction rollback, transfer and resource-fraction assertions.

## Acceptance and boundaries

Exactly two test files and their companion notes change. Qualify all thirteen equipment methods and three affected fuel-storage methods: sixteen methods, twenty-two cases. No earlier pass is retained for a changed private-fixture consumer. Production, catalogue, defaults, unsupported-slot policies and other test families remain unchanged. Companion: [PR-storage-shop-fixture-context.md](PR-storage-shop-fixture-context.md).
