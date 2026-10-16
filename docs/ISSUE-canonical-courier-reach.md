# Courier routes and canonical navigation

New courier plans currently validate against the original navigation tiers and
assume ten fuel units per light year. Canonical navigation can have a real
recovered reach or fuel-efficiency upgrade. The original proof rejects these
plans, while the acceptance check misjudges the fuel available for later legs.

New plans use reach revision `elite-canonical-native-reach-v2`, retaining the
existing fields and adding optional `jumpFuelMultiplier` and `fullTankReach`.
Both additions are required and coherent for v2. The proof freezes actual native
reach, current fuel, capacity, fuel cost, first-leg reach and full-tank reach.
Loaded proof validation does not depend on subsequent equipment changes.

Existing `elite-880d3a-native-reach-v1` records retain their exact original
validation and replay math. Their new optional fields must be absent. Generation
revision 1, six random draws, breadth-first route ordering, rewards, deadlines
and save-container version 21 remain unchanged. Acceptance checks every leg
against the current native first-leg or full-tank range.

## Validation status

Source preparation only: **uncompiled and unexecuted**. This branch starts from
the accepted Mission source and requires the central canonical equipment source
before compilation. No shared heavy validation lease was used.

The staged regression group is `ScriptCourierCanonicalReachTests`: four methods
and six declared cases covering actual purchased navigation and recovered drive
upgrades, efficient first and later legs, retained stock navigation refitting,
legacy board reload without rerolling, and malformed versioned facts. Source
formatting and whitespace checks passed. Composed focused tests and `make ci`
remain required before publication.
