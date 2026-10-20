# test: establish actual native surface hits in four controlled gun cases

## Station scenes

stationAutoCurrentNativeFleeAssessesEveryAttackerAndUnknownOrdnanceStaysConservative moves only the first authored attacker from(0,-20,600) to(600,-20,0), retaining its600.33range, sequence and player-facing mount. Source arithmetic intersects SH025 face231. The second attacker stays unchanged because its original ray already intersects the player. Both actual strict first-player contacts, attacks, all-attacker hazard transitions and conservative unknown-ordnance checks remain mandatory.

stationAutoAuthenticEntryAttackUsesMountedGunAndPhysicalEvasionWithOneBudget keeps the attacker at(0,0,180) and points its unchanged forward mount at the fixed SH025 face230 centroid. Source geometry proves the player intersection and the existing forward AUTO return ray's intersection with the actual raw Cobra NPC hull. Full traffic stays present; the existing strict native query must still prove first contact. Actual damage, unlawful origin, return fire, one-step manoeuvring budget, station clearance and all original assertions remain unchanged.

## Declared NPC gun scene

The new declaredNPCGunGame constructor uses the example's explicit SH023 hull,70fuel and its native energy/shields before typed equipment preparation, acceptance and launch. Only npcLasersAndPlasmaSpendActualEnergyHeatAndCooldownAndDamageRealColliders and plasmaHitsTheActualInterveningShipAndECMCannotDestroyOrClaimPlasma call it. Their original six-point laser hit, fifteen-point plasma hit, intervening target, energy, heat/cooldown, projectile profile and ECM assertions are unchanged. The first method is an unreported direct consumer of the same centre-ray assumption; it is not claimed as an actual db650 failure or an existing passing result.

NPCFixture.game, aimNPCAtPlayer, stationAutoRequireNativePressureLane and all other method bodies remain unchanged. No production geometry, traffic, save policy, automatic targeting or native gun rule changes.

## Source evidence and qualification

Four methods/four cases, exactly two test files plus these paired notes, based on db650c739fed9cffe65aae35bfda6e25eb42ac09. Source-only proof `/tmp/elite-db650-native-geometry-source-proof/SOURCE-PROOF.json` SHA256 `085c952eebaa6b616861c747d9a9194f555e2776734357ac42935a1c56fd1042` records original misses, the fixed side/aim intersections and declared SH023 normalization. Its evaluated second-attacker candidate is not used: the original second pose is preserved. Player-surface arithmetic does not prove an unobstructed full scene or a runtime pass.

Scoped strict Swift formatting, Markdown lint, diff checks and original-assertion/shared-helper conservation precede freeze. One independent complete-method/helper bugs/performance/style review and a matching warm build precede only this affected four-case union, optionally combined with the disjoint ready default-prerequisite batch. No passing unrelated cohort, full CI, diagnostic-only native campaign or extra manual docking attempt is repeated. Hosted50issues/23methods/SIGBUS, global gates and required review-service failure remain open. See [motivation](ISSUE-hosted-native-ray-fixtures.md).
