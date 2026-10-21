# fix(mining): advance ordinary pending ore from timed snapshots

An ordinary ore payload refused by admission now retains its existing velocity and advances its proposal from the last canonical snapshot time. Same-time retries add no displacement, successive intervals compose, and culling resumes from the latest acknowledged actor snapshot rather than the original birth. Identity, amount, velocity, depletion and collection authority remain unchanged.

MiningLedger owns a bounded regularPayloadTimes map with exactly one finite nonnegative epoch per regular pending payload. Existing native motion or CombatIncident clocks anchor births. Both production updateOreMotion callers already supply the now-required clock. Timed actor writes reject stale actors and backwards/nonfinite time atomically; advancing only time is retained even when position/velocity are unchanged. Collect, destroy and departure clean up matching epochs; cull/reset preserve them. Current-format decode rejects missing or malformed clocks without compatibility or inferred-time fallbacks. Breakup descendants retain their existing clock authority and spawn-advection branch.

## Scope and tests

Only MiningLedger, four approved test files and these paired notes change. MiningOreMotionTests adds two pure ledger methods with no flight loop: regularOreRefusedReoffersAdvanceByPhysicalTimeAndSurviveColdLoad and regularOreCullResumesLatestTimedPoseAndRejectsStaleOrBackdatedWriter. The first genuinely releases a regular twenty-unit chunk and checks positions over four offers, including same-time retry and cold load, against unchanged birth identity/amount/velocity. Typed refusal receipts exercise the ledger protocol and do not represent observed G12 refusal diagnostics. The second checks current/stale/backdated writers, time-only snapshot updates, culling, collection, destruction and departure. The existing CR09 control also rejects missing, mismatched, duplicate, negative and oversized clock records.

Only the named admission fixture in MiningLedgerTests and named history fixture in AsteroidPresenceMigrationTests receive their required monotonic times. The latter reconstructs its identical context with time2 inside that method; other methods and the shared time0 helper remain unchanged. MiningOreMotion and CR09 local writer fixtures now supply explicit clock values.

## Validation and acceptance limits

MBA format/strict lint, copy hashes, exact seven-path scope, ASCII, Markdown and whitespace checks are recorded in the freeze packet. No author compiler/native/CI job runs, and no native PASS is claimed. G1 matching compilation and the focused short selection (12 methods / 12 cases, including the two new methods) are pending; full independent review follows focused owner PASS. Actual G12 run 1261 remains a natural ten-of-twelve failure with no observed per-original refusal cause. Neither its twelve-original target/deadline nor any admission, capacity, protection or geometry guard changes. A later unchanged automatic journey requires separate Root/G1 dispatch; no retry, new diagnostics or timeout increase is requested here.

Paired issue: docs/ISSUE-regular-ore-motion-clock.md. No PR has been created by this source author.

## Completed focused qualification and integration

Owner dd503d59771cdb18183260079b4b0892521d29de integrates at64e909cea1e8cca240f22be3ce2a27f6149e2c60 with all seven reviewed blobs exact. Matching1286 compilation passes on23a3495bba050dc8009b7d9cfd3964f9b546ce40. Actual1287 all12methods12cases pass in8.795seconds, runner13.055056000128388/outer15.355366790900007seconds. Zero issues or unknown outcomes;11 observed starts close naturally with source/preferences/2010 artifacts exact. Raw SHA25661b04690d25629e5f94b6efd0615b581059385d9bdf108bc2e1cbd7f2a9ece86.

Complete independent seven-path bugs/performance/style review is CLEAN, SHA256dc73750db68be8b4b4c0d1046147d176bb31748da6ba75bef6766bd3c31253a1. No passing-case replay or full G12 flight loop runs for integration. Original ten-of-twelve G12 failure remains preserved; this short ledger qualification establishes neither full twelve-original recovery nor measured performance or hosted quality acceptance.
