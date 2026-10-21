# fix(mining): advance ordinary pending ore from timed snapshots

An ordinary ore payload refused by admission now retains its existing velocity and advances its proposal from the last canonical snapshot time. Same-time retries add no displacement, successive intervals compose, and culling resumes from the latest acknowledged actor snapshot rather than the original birth. Identity, amount, velocity, depletion and collection authority remain unchanged.

MiningLedger owns a bounded regularPayloadTimes map with exactly one finite nonnegative epoch per regular pending payload. Existing native motion or CombatIncident clocks anchor births. Both production updateOreMotion callers already supply the now-required clock. Timed actor writes reject stale actors and backwards/nonfinite time atomically; advancing only time is retained even when position/velocity are unchanged. Collect, destroy and departure clean up matching epochs; cull/reset preserve them. Current-format decode rejects missing or malformed clocks without compatibility or inferred-time fallbacks. Breakup descendants retain their existing clock authority and spawn-advection branch.

## Scope and tests

Only MiningLedger, four approved test files and these paired notes change. MiningOreMotionTests adds two pure ledger methods with no flight loop: regularOreRefusedReoffersAdvanceByPhysicalTimeAndSurviveColdLoad and regularOreCullResumesLatestTimedPoseAndRejectsStaleOrBackdatedWriter. The first genuinely releases a regular twenty-unit chunk and checks positions over four offers, including same-time retry and cold load, against unchanged birth identity/amount/velocity. Typed refusal receipts exercise the ledger protocol and do not represent observed G12 refusal diagnostics. The second checks current/stale/backdated writers, time-only snapshot updates, culling, collection, destruction and departure. The existing CR09 control also rejects missing, mismatched, duplicate, negative and oversized clock records.

Only the named admission fixture in MiningLedgerTests and named history fixture in AsteroidPresenceMigrationTests receive their required monotonic times. The latter reconstructs its identical context with time2 inside that method; other methods and the shared time0 helper remain unchanged. MiningOreMotion and CR09 local writer fixtures now supply explicit clock values.

## Validation and acceptance limits

MBA format/strict lint, copy hashes, exact seven-path scope, ASCII, Markdown and whitespace checks are recorded in the freeze packet. No author compiler/native/CI job runs, and no native PASS is claimed. G1 matching compilation and the focused short selection (12 methods / 12 cases, including the two new methods) are pending; full independent review follows focused owner PASS. Actual G12 run 1261 remains a natural ten-of-twelve failure with no observed per-original refusal cause. Neither its twelve-original target/deadline nor any admission, capacity, protection or geometry guard changes. A later unchanged automatic journey requires separate Root/G1 dispatch; no retry, new diagnostics or timeout increase is requested here.

Paired issue: docs/ISSUE-regular-ore-motion-clock.md. No PR has been created by this source author.
