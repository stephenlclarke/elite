# Define validated hyperspace drive profiles and sequential purchase policy

The pure hyperspace-drive catalogue provides three stable component grades and purchase nodes. Basic is included standard equipment, with no paid Basic offer. Intermediate and Advanced require the preceding fitted core and the genuine paid prerequisite history for nonstandard ancestors. Their activation times are 10, 5 and 1 seconds; mass-lock distance factors are 1, 0.8 and 0.6. Declared project balance defaults are 5,000 CR at displayed technology level 10 for Intermediate and 15,000 CR at displayed level 13 for Advanced.

The drive family uses jumpSpool in seconds. Its ordinary upgrade floor of 0.7 seconds is a project balance choice, distinct from navigation's dimensionless spool ratio. The normal resolver validates the supplied fitted component using ComponentProgression, reads actual earned seconds, and multiplies the resolved navigation ratio exactly once. It preserves upgrade receipts and does not mutate either device. The drive grade controls the mass-lock factor; subgrade spool improvements do not silently add another grade. A missing component describes the stock Basic policy but does not create a physical device or paid entitlement.

HyperspaceActivation distinguishes timed positive seconds from immediate. The alienFoundation describes immediate activation without mass lock as a typed integration foundation only. It cannot grant an alien drive, unlock a shop, consume salvage or initiate travel. No zero or epsilon is written into ShipPerformance.

## Central integration hooks

Coder 1 registers the family definition, catalogue nodes and drive slot in the actual equipment graph/context, migrates existing commanders to one real stock Basic item, supplies authenticated shop offers, and preserves sequential paid history through fitting and hull transfer. Runtime and display consumers resolve normal policy from the actual fitted drive and existing navigation multiplier. Mass lock scales both existing ship-distance and celestial-radius thresholds once. The central actor must branch explicitly for immediate travel only after actual alien salvage, PLUGH fitting and all existing fuel, range, mission, calendar, collision and durable save guards succeed. It owns Game, Commander, ShipPerformance, save schemas, UI and native travel verification.

## Validation and limits

Regression source covers exact grade times and thresholds, declared prices/technology, real ComponentProgression upgrade application followed by one navigation fold and save roundtrip, invalid statistics, explicit immediate policy, and the existing purchase planner's paid-plus-fitted sequential enforcement. The latter tests quote/apply outputs, not actual cash debit, physical fitting or native jump execution.

Only source formatting, strict Swift formatting lint, scoped Markdown lint and whitespace checks ran. No compiler, typecheck, tests, native process, media generation, CI or publishing ran. The source remains uncompiled and unexecuted. No shared runtime, catalogue registration, actor, save, shop or salvage files were edited. See [motivation](ISSUE-hyperspace-drive-profiles.md).
