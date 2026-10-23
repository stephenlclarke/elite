# Track exact NPC missile and launcher identities

## Motivation

[Issue154](https://github.com/stephenlclarke/elite/issues/154) identifies a positional test oracle invalidated by legitimate native station population after the launcher is removed.

## Implementation

Capture the original launcher and missile physical identities, remove only that launcher and resolve the same missile after flight. Keep separate finite-ammunition/second-refusal assertions and all original impact, damage, no-kill and cash checks. Tests only; no launcher, projectile, station or ownership policy changes.

## Validation

Formatting and diff hygiene pass. The unchanged original method is part of the current bounded151/154 focused selection. Execution and independent actual-source/result review are pending. Preserve the original failed result and incomplete XML; no aggregate pass is inferred.

## Compatibility and remaining limits

No save schema or player behavior changes. The mission crash remains separate151 and historical144 origins remain unknown. Full VM/quality/native M01/release remain separate.

Thec581 result reaches the exact retained missile and proves original owner equality, but impact and shield assertions fail and the hard-coded credits1000 oracle is invalid for the authored starting commander. The energy clause was not evaluated after the shield clause failed; no damage pass is claimed. Capture initial actual cash and assert it remains unchanged. Split owner, impact, shield, energy, kills and cash assertions so later failures cannot hide another oracle. Keep the original impact/damage requirements and add only a termination diagnostic; no extra elapsed time or production change is guessed. Evidence remains the failed c581 raw log. Scope154 is still open pending actual corrected execution and source-backed impact resolution.

The single NPC motion-fact invocation at8ea34c63 failed after59.802815s (compile47.47s), with complete one-method XML and the same three impact/damage assertions. The missile actually moved to world(0,0,-3608), with lastUpdatedAt2/current physicalTime2 and ordinary unlawful-attack notification. It is still active; there is no clock stall, collision-refusal message or justification for extra ticks. The original axial fixture crossed the camera reference point but not the current authored player mesh.

Source GameplayWeapons.nativePlayerSurfaceAim explicitly recognizes that the camera origin can lie in a hull opening. The authored fresh-start SH025 uses its original calibrated mesh with openings, while the old test assumes the reference-axis shot hits physical hull. Correct only the fixture: choose a nondegenerate front triangle centroid from the actual current player mesh, place the launcher radially outside it at1000metres, require clearance outside the hull and actual nearestMissionCollision confirmation of a player/front-surface hit from the same muzzle/trajectory before launch. Then retain the same2second elapsed time, exact launcher/missile identities, impact, front-shield/energy loss, finite ammunition, second refusal and unchanged kills/cash assertions. No production geometry, aim, damage or hit policy changes; no fake collider or fixed array position.

Only the original NPC method is re-executed after this source-backed setup correction. Original mission151 and parent preflight/pause passes remain retained without rerun;154 stays open until actual impact/damage passes and independent review.
