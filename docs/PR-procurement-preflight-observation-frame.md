# fix: separate procurement observation and baseline lifetimes

## Change

The test helper's preflight now crosses a non-inline, read-only borrowing-Game observation boundary. Every current actor/context/clock, threat, no-fire-zone, exact native forward-hit and lawful defence predicate is retained. The observer holds no Game, callback or authority and cannot mutate simulation state. GameRuntime remains the synchronous actor owner with no new suspension point.

The existing single Commander preservation baseline moves from a full value local in procurementMissileFallback to a private immutable reference owner. It holds the same complete Commander value, not a new Game snapshot or transaction framework. Construction occurs at the same point before arming, keeps the original missing-inventory refusal, and adds no native mutation or publisher. The fallback's active observation frame retains only the reference and the existing bounded facts/budget/stock values. Native publication returns before a separate borrowed post-launch comparison frame runs.

All original post-launch conditions remain: exact standard-missile owner/target/physical item/ordnance/time join; one actual live missile; the same inventory owner/hull and exact removal of the reserved original round; armed/ammunition state; unchanged credits, cargo, contracts, instances, mission/calendar ledgers and times, physical time and purchase history; and full current Commander validity. Tab/Q/T/M ordering, no-retry behavior, every intermediate target/stock/law/heat/ECM guard, native saves and emitted receipts remain unchanged. No production source, station memo, equality implementation, physics or runtime authorization is modified.

## Regression and validation

Reuse the actual crashed procurementMissileActiveNativeECMDefersWithoutSpendingOriginalStock method unchanged. Its independent inactive-ECM control must still physically launch and durably save one original round, while active native ECM must preserve the actual Commander/bodies/resources/targeting and zero pilot budget with no saved refusal result. The rest of the existing procurement missile tests retain their assertions and selectors. No new fixture or diagnostic-only reproduction is added.

Strict Swift formatting, Markdown lint and whitespace checks pass. ZERO compiler, native, GUI, test, CI, ABI, debugger or profiler jobs were run. Native frame allocation and corrected acceptance are not measured or claimed. G1 must execute the unchanged affected method on the integrated material change; no default stack/concurrency waiver or quality-gate bypass is part of this repair. This leaf is based on 54c9c3c3f74c0f9c10823db0a00cedd13a607df4 and composes independently of the later exact vertex certificate and other owned integration changes.

## Borrowed observation control flow

A mechanical child preserves the original ordered short-circuit evaluation using explicit if/else and comma-separated conditions for live/automatic state, front laser, front/rear shield gates, pulse heat and lawful forward defence. This avoids autoclosures capturing the newly borrowed Game parameter without eagerly evaluating a previously gated computed property. The borrowed post-launch join already uses ordered guard clauses and closures that capture only scalar identities, so it needs no predicate change. No test expectation, native action order or authority check changes. Strict source formatting and Markdown/whitespace checks only; no compiler or native execution.
