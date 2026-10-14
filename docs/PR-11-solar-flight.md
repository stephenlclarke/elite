# feat(flight): add visible planets and solar fuel scooping

Delivered together in [PR #11](https://github.com/stephenlclarke/elite/pull/11). See [the integrated validation and release evidence](PR-11.md) and [request checklist](DELIVERY-BACKLOG.md).

## Behaviour

Launch and hyperspace arrival create a local planet and sun in the same moving coordinate frame as ships. World rendering interleaves spheres and ships by camera depth, uses the existing procedural planet renderer with transparent space, and draws a luminous sun. HUD bearings remain available off screen.

Cruising toward the sun inside three solar radii with Fuel Scoops collects up to seven fuel tenths per second, capped by the installed tank. Cabin heating depends on proximity and cooling on current temperature; the existing temperature instrument now reflects simulation. Critical heat and surface impacts destroy the ship regardless of shields or unlimited fuel. Nearby celestial masses block in-system jumps. Explicit HUD status distinguishes collection, full tanks, missing scoops, alignment and thermal danger.

## Compatibility

No commander save schema change. Existing saves restore docked; launch/arrival regenerate local positions, and docking/loading clear heat. Planet surfaces do not supply stellar fuel. Native envelope units, rates and thermal thresholds are chosen game calibrations, not SI astrophysics. Cargo scooping and mission bodies retain existing behaviour.

## Validation

Full isolated Swift suite: 248 tests passed. Eighteen focused simulation/rendering tests cover collection and fuel policies, fractional accumulation, viewing direction, motion, heat/death, lifecycle, surface/jump limits, default visibility, perspective, clipping, alpha, mixed-object depth and near-plane limb continuity in all four views. The existing starfield test now isolates stars from the solid sun disk, and extra flight help uses existing pagination in all contexts.

Final combined `make ci` passes 268 tests, 93.29% coverage, both sanitizers and zero leaks. Native fuel collection, retreat/cooling and rear-view sun checks pass; final renderer media is regenerated. The shared implementation branch is coordinated with the station/docking HUD change; `CockpitDisplay.extraLines` must include both owners' feedback.
