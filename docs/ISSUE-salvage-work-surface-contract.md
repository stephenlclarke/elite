# Work guidance can authorize a ray outside its named salvage section

`FlightWorkSurface` retained an authored section's center, normal and identity but discarded its radius. `workRayReachesSurface` then accepted any nearest hit on the same body. The actual cutter additionally requires its nearest impact to be within `max(1, section.radius)` of the selected section's center and on its outward side. A hold could therefore be authorized despite failing the cutter's selected-surface contract.

The unchanged SH023 raw profile illustrates the conditional problem: its cargo section has radius 34.33882434494874, while guidance can request a 40-unit tangent collection offset. Every point on that ideal offset ray is at least 40 units from the section center. A same-body hit alone cannot prove a valid cargo cut. The actual collection offset and impact in timed-out validation 344 were not recorded; this source-backed defect is not a claim about that execution's particular guard failure or cutting progress.

Carry the authentic radius into the transient work surface and validate the actual nearest hypothetical impact against the cutter's same section-distance and outward-side predicates. Keep every first-hit, occlusion, current mesh and actor guard. A named surface without a finite positive radius must refuse. Preserve sectionless pickup/mining behavior and the existing 40-or-zero offset choice; do not enlarge the patch, alter the ship, weaken the cutter or invent a collection policy.

The retained named radius must also remain equal to current metadata alongside its section, point and normal. A changed patch must not borrow an older hold's authorization.

The first composed compilation (validation 347) found one existing synthetic work-status fixture still calling the old memberwise initializer. It requires an explicit nil radius for its existing nil section; every other fixture value and disclosure assertion must remain unchanged. No test executed in that failed compilation.

[PR handoff](PR-salvage-work-surface-contract.md).
