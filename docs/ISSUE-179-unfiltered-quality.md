# Issue 179: documented save projection

## Motivation

The unfiltered quality run [40043514103](https://github.com/stephenlclarke/elite/actions/runs/40043514103) for PR25 head `ae97d337cb9cf25b58322a21946e9ece297dd60a` failed. Its saved evidence records 62 assertion-bearing methods and a separate terminal SIGBUS. The earlier 19-method and 524-method passes remain limited to their recorded scopes.

## Scope and correction

Reset both NPC and WantedCareer physical bindings in expected disk Commanders. Isolate pure NPC rejoining from the separately tested RRS rebinding lifecycle using an authentic world without an RRS station.

Original assertion locations for this group: NPCSceneRestorationTests.swift:220, NPCSceneRestorationTests.swift:226, NPCSceneRestorationTests.swift:227, NPCSceneRestorationTests.swift:236, NPCSceneRestorationTests.swift:237, NativeStationPersistenceTests.swift:135. The independent full inventory is recorded in `docs/evidence/M01-ae97-terminal-review.json`.

## Validation and compatibility

Source review is complete for the coherent correction batch. Unit execution is pending; these changes are not qualified for integration or release. One combined normal affected-unit batch must retain all 62 methods, including the unresolved moving-debris case. Swift actor ownership, save authority, original data, solver budgets and required quality gates stay unchanged.

## Links and remaining risks

[GitHub issue 179](https://github.com/stephenlclarke/elite/issues/179); [PR25](https://github.com/stephenlclarke/elite/pull/25). The moving-debris sweep remains unresolved; debug-only scalar refusal logging collects its actual query without changing the result. Issue185 remains unattributed. Full coverage, sanitizers, leaks, final review and protected release publication remain pending.
