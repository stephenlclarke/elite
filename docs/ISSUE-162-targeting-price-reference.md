# Use the named Pulse Laser in the targeting price assertion

## Motivation and evidence

[Issue 162](https://github.com/stephenlclarke/elite/issues/162) records the directly attributed defect. The same required quality40016592456 reports the actual TargetingTests164 assertion: Basic8000 differs from twice Equipment.all[4].price12000. Equipment insertion makes index4 ECM at6000; the intended Pulse Laser remains4000. This is a stale fixture reference, separate from the pledge-preview crash.

## Implementation

Resolve Pulse Laser by its maintained name using #require, then retain the exact twice-laser Basic price expectation. Leave all tier purchase/debit, repeated purchase, effective-tier and save/load assertions unchanged. No production price or shop logic changes.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-diff review and focused execution are pending. One coherent cached Swift6.1.2/SDK15.5 build will run the original delayed-report, authentic station-entry, board-browsing and targeting price/persistence methods after all three bounded corrections. The three unaffected individual passes at `ec83d6f8` remain separate receipts. No new selector, broader campaign, diagnostic probe or synthetic aggregate result is introduced.

## Compatibility and remaining limits

No save/schema, actor isolation, authority or quality threshold changes. Required final-head coverage, sanitizer, leak and review gates remain; historical144 is not assigned a cause. Original incomplete methods, completed-save/reopen proof and release remain unqualified until actual results establish them.
