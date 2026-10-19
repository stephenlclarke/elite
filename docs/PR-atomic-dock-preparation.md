# fix: keep dock snapshot preparation atomic

## Changes

The existing NPC, cargo, ore, salvage and native salvage parking operations move unchanged into a private non-inlined preparation helper. It retains the entry Commander and the three native salvage observation caches. On NPC, salvage or parking refusal, a defer restores those values while retaining the original refusal notice. On success, the original dock sequence proceeds unchanged.

The boundary starts after native station observation, genuine death settlement and unsettled-death guards. It therefore preserves accepted death facts and body removal, rather than restoring persistent state underneath an already settled physical scene. It copies no whole Game and adds no stored Game or Commander fields. The non-inlined helper keeps its snapshot local out of the main docking frame; compiled stack size and runtime performance remain unverified.

The capacity fixture uses Escape to return from the gossip board. It retains all galaxy discovery, Commander validity, 257th/2056 capacity, 2057 refusal, duplicate, foreign-owner and universe-bound checks. No Commander oracle, validator or limit is weakened. Refusal fixtures retain their exact existing pre-action Commander snapshots and equality assertions.

## Validation

Author checks are strict Swift formatting, Markdown lint and git diff whitespace validation. No author compiler, native app, test, GUI, profiler or diagnostic job was run. G1 owns the reviewed coherent build, focused refusal/success/capacity tests and required make ci gates. The existing CI612 failures are the regression evidence, not corrected acceptance. Original station observation and physical death settlement intentionally remain authoritative on a later refused snapshot; this change addresses the subsequent snapshot preparation transaction only.

## Links and compatibility

See ISSUE-atomic-dock-preparation.md. Current formats and normal successful docking retain their existing behavior. No compatibility layer or predecessor-state acceptance is introduced. Courier and procurement diagnosis remain separately assigned.
