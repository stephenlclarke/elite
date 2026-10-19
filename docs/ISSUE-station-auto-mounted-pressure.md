# Station AUTO pressure fixture seeds a different beam path

Candidate 630 failed the active-pressure and transit-goal assertions in `stationAutoUncoveredNativeBeamCannotHandOverToStationaryAlignment`. The fixture seeds its attack with `emitLegacyNPCBeam`, whose separate target-centre ray does not establish alignment of the ordinary gameplay front mount. Its Cobra starts at `(300, 0, -1000)` with the default forward axis.

Author a finite initial orientation toward the real player, prove the current forward ray reaches the player, and require damage and owner/victim/front-mount attribution from `emitGameplayNPCBeam`. Preserve the eight 0.1-second steps and every original behavior assertion. The hazard classifier does not directly read beam alignment: a source fleeing, gaining genuine station cover, dying or leaving the immediate range can change its result. The existing failure log does not identify which happened, so retain source-state diagnostics and do not claim this source repair proves a runtime fix.

## Qualification 633

The retained diagnostic now identifies step 1 as `hostile=false`, energy 99 and `flee(player)`. A clear hazard after a genuine source flee is legitimate; changing the production hazard or flee policy would hide that evidence. Initialize this sustained-pressure fixture's same Cobra from `ShipCatalogue.nativeShip` performance and `NPCResources.stock`, including its actual full native energy, and require that its pre-emission snapshot reports matching full energy and maximum. Keep the native aligned seed, all eight steps and all existing behavioral assertions. Any later genuine flee, death or cover remains visible; corrected runtime acceptance is unproven until G1 executes the affected test.
