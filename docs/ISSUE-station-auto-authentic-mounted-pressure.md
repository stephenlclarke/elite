# Two station entry fixtures seed pressure through the separate legacy emitter

Actual full-review qualification 667 retained missing unlawful-attack proof at StationAutoDefenceTests.swift759 and missing front-shield damage at line796. The affected methods are stationAutoCurrentNativeFleeAssessesEveryAttackerAndUnknownOrdnanceStaysConservative and stationAutoAuthenticEntryAttackUsesMountedGunAndPhysicalEvasionWithOneBudget.

Their shared attacker helper creates a default +Z orientation at positive-Z positions, so a real front gun points away from the player. Both methods nevertheless seed their prerequisite hits through emitLegacyNPCBeam, a separate target-centre emitter; that emitter ignores the forward axis. Aim-away alone therefore is not a proved explanation for the observed legacy seed failure. It is a concrete gap in the fixtures' intended authentic mounted-gun setup. The actual gameplay NPC ray now correctly uses its fixed forward axis under e17404f7.

These two controlled scenes must author an actual hostile mount aimed at the player's current view origin and emit through the existing gameplay NPC beam authority with fresh current context. They must still prove actual shield damage or both attackers' unlawful attack joins, and retain the original physical evasion, resource, ammunition, budget and station-entry assertions. Occlusion or other genuine product refusal remains a failure, not a reason to aim-assist, grant a hit or weaken native predicates.

This is bounded fixture support for the single stable playable-app delivery. No production beam, hull, fuel, invulnerability, source resources, stack/concurrency or unrelated physics changes are authorized. See PR-station-auto-authentic-mounted-pressure.md.
