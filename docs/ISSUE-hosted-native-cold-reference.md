# Combat continuity must compare equivalent native station binding phases

## Actual mismatch and source policy

Hosted db650 reports full-body and full-Commander equality failures in resumedNativeCombatRNGAndTacticsMatchTheUninterruptedWorld. Existing raw output has eight bodies on each side and seven identical bodies. The remaining RRS station changes from body10 to15, with nextActor9to10 and nextSpawn3to4. This matches the documented native cold-load policy: rebindNativeStationsAfterLoad allocates a fresh station actor/spawn/body binding while preserving its stable native station identity. It does not establish a production combat RNG defect.

The old comparison puts the uninterrupted hot timeline against the early-resumed cold timeline. NativeStationPersistenceTests independently expects fresh RRS bindings after a load. A common genuine cold comparison phase can preserve the original complete-value oracles without discarding actors, copying observed values into expectations or adding a projection framework.

## Bounded scope

Only the one continuity method and its new private invariant guard change. The original uninterrupted and early-resumed hundred-step timelines remain. A second owned test file holds the uninterrupted endpoint; a fresh runtime loads it without advancing the game. Strong guards independently prove unchanged non-RRS combat bodies, clocks, RNG and loop state, together with exactly one authoritative fresh station binding. All original four complete bodies/Commander/RNG/loop assertions remain verbatim.

No production save, station, actor, tactics or RNG policy changes. No unowned files, normal player saves, new test campaign or diagnostic runtime. One complete independent review precedes the matching build and this existing one case. See [handoff](PR-hosted-native-cold-reference.md).
