# fix(contracts): retain Original offers until native work changes

## Motivation and behavior

Original contract boards retain their cached listings across clock hours, page reopening and reload. A shared policy derives a checked generation from the cached floor and validated matching retained native jobs. Acceptance contributes R+1 and native terminal settlement contributes R+2. Declining a row does not replenish it. Existing legacy providers retain their hourly behavior.

## Implementation

Generation/reuse, acceptance, decline, visible rows and page fingerprints use the same family policy. Accepted terms and native cargo identity derivation remain immutable. Overflow refuses before acceptance or settlement changes state. Existing reservation-cap and provider-group guards remain in place. Contract validation bounds Original historical revisions without requiring the currently cached board to equal an older accepted job.

## Validation

Owner PASS: one run of all seven selected methods/cases on source `bcd361dbc462a136f701f363176221716eb39b0b`, using the existing stable MBA source/build roots and normal worker defaults. Tests passed in 17.594 seconds; bounded supervisor completed in 21.753 seconds. The matching build passed in 68.421 seconds. Source hashes, preferences and test binary stayed unchanged, with no timeout, cleanup or remaining owned processes. The initial optional-owner test compile failure and its owned cancellation are preserved, as is one pre-compiler mistyped-SHA refusal. G2 independent bugs/performance/style review is CLEAN on final source87527e1c with no findings; review SHA256 `5a8d7e83a23399e2ad5fd09d59f8df00088c245a62616694b2e8c56f2dee2300` binds the eight reviewed paths and retained seven-case owner PASS. No broad CI, flight, PR publication or merge is claimed.

## Compatibility and remaining work

No save field, schema, Lua provider, digest, Wayfarer stock or live quote token changes. Existing cached listings are adopted as the floor. Retained native history supports the current no-pruning implementation; future pruning must retain its floor before deleting evidence. A native Original restock producer and the Wayfarer service-board consumer remain separate open work. Generic admission tests exercise actual sample issuance and abandonment; freight unit assertions cover native identity derivation only and claim no freight journey.

## Links

Companion: [ISSUE-original-stable-offers.md](ISSUE-original-stable-offers.md). No remote issue or PR has been created.
