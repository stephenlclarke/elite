# Use the named Pulse Laser in the targeting price assertion

## Motivation and evidence

[Issue 162](https://github.com/stephenlclarke/elite/issues/162) records the directly attributed defect. The same required quality40016592456 reports the actual TargetingTests164 assertion: Basic8000 differs from twice Equipment.all[4].price12000. Equipment insertion makes index4 ECM at6000; the intended Pulse Laser remains4000. This is a stale fixture reference, separate from the pledge-preview crash.

## Implementation

Resolve Pulse Laser by its maintained name using #require, then retain the exact twice-laser Basic price expectation. Leave all tier purchase/debit, repeated purchase, effective-tier and save/load assertions unchanged. No production price or shop logic changes.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-diff review and focused execution are pending. One coherent cached Swift6.1.2/SDK15.5 build will run the original delayed-report, authentic station-entry, board-browsing and targeting price/persistence methods after all three bounded corrections. The three unaffected individual passes at `ec83d6f8` remain separate receipts. No new selector, broader campaign, diagnostic probe or synthetic aggregate result is introduced.

## Compatibility and remaining limits

No save/schema, actor isolation, authority or quality threshold changes. Required final-head coverage, sanitizer, leak and review gates remain; historical144 is not assigned a cause. Original incomplete methods, completed-save/reopen proof and release remain unqualified until actual results establish them.

## First combined execution

The four original methods ran at `fce2782b` on Swift6.1.2/SDK15.5. Compilation passed in75.03seconds; process exited1/rawSIGBUS10 after86.793152292seconds. All four methods only started, with no terminal pass or assertion result and unfinished52-byte XML. Retained `/tmp/elite-161-163-focused.log`, `-result.json`, `-crash.ips` and `-image.json` preserve exact source/result and loaded image19834FA1-FDB6-33B4-905C-7135D55C59D4/SHA256e6662a218eac6907ad0a33f2f78a82be25dec08f005700cbc4fefa96a7b38202. Independent actual-source review is clear; execution qualification and current fault attribution remain pending.

## Combined checkpoint result

The source-reviewed combined159-168 packet `eb5ab2d8` compiled successfully, then its one normal four-original-method batch failed signal10/exit1 after198.327703625seconds with zero completed methods/assertions. No matching normal report exists; the separate exact-image capture is diagnostic only. No issue is closed or runtime-qualified by source review. [The combined packet inventory](PR-25-M01-RELEASE-BLOCKERS.md) records exact source, evidence limits, retained unaffected passes and remaining required gates.
