# Native gun fixtures must aim at real surfaces of the intended hull

## Actual failures

The full db650 CI artifact records two strict station pressure queries returning no contact and one profiled-NPC interception method leaving the player's shield unchanged. Source geometry proves the station cases' original centre rays and the NPC forward ray miss SH025's open centre. These failures do not establish a production collision bug or locate the interleaved SIGBUS10.

The NPC example explicitly declares SH023 as its trial hull. Two methods call aimNPCAtPlayer and require the same real six-point forward hit; the second is a directly source-proven unreported consumer, not an additional observed hosted failure. A normal development start currently chooses SH025, so those controlled gun units need their declared classical hull before preparation, mission acceptance and launch.

## Bounded correction

Keep actual traffic, geometry, mounts, damage, energy, heat, plasma interception, ECM, attack provenance and native defence checks. Change only two selected station methods and the two NPC gun consumers. The shared station pressure helper, NPCFixture.game and aimNPCAtPlayer remain unchanged. The new constructor serves exactly the two intended NPC units. Production sources and assets are untouched.

One source-only geometric proof uses the authenticated ship vertices/faces and documented normalization. No engine, test, native probe, seed/ray search or traffic removal establishes the proposed scenes. One complete independent review precedes matching build and the four existing cases. See [handoff](PR-hosted-native-ray-fixtures.md).
