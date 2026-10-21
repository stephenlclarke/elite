# Trade routes must respect reserved hold space

## Problem

Navigation trade estimates bound every commodity by the commander's nominal cargo capacity. That overstates tonne trades when cabins, protected mission payloads, marked firearms or collected salvage reserve part of the hold. Unlimited cargo can also mask the real hold limit imposed by fitted cabins or contracts. Conversely, non-tonne goods can be purchased even when the tonne hold is occupied.

## Acceptance

Estimate tonne trades using effective trade capacity after reserving occupancy that ordinary cargo sales cannot release. Continue to assume ordinary sellable tonne goods may be sold before the next purchase. Preserve non-tonne purchases, custody-aware cargo-sale values, route tie ordering, fuel legality and all monetary mutation paths. Scoring must remain finite for accepted large cargo quantities and must not mutate the commander.

## Validation and limits

Add focused navigation custody regressions for purchased cabins with and without unlimited cargo, marked firearms, accepted protected payloads, collected salvage, an occupied ordinary hold, non-tonne purchasing and maximum accepted tonnage. Compilation and runtime results remain pending central validation; formatting and source checks are recorded in the implementation handoff.

See [the implementation handoff](PR-navigation-trading-room.md).
