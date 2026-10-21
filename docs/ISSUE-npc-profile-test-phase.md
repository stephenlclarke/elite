# NPC profile rejection fixture lifetime

## Problem

The full coverage run at `7e474867618129cd66368d0fd483b4ea8755bcd5` recorded assertion failures and signal 10 before completion. A separate debugger probe of its unchanged binary stopped in `profileSceneSaveRejectsAlteredModelHashForeignShotOwnerAndDuplicateComponentIdentity`, during the real NPC admission geometry validation reached from `NPCFixture.game`. No matching original operating-system crash report was available, so the probe does not establish equivalence with the original signal.

The compiled test reserves four whole `Game` buffers before entering the fixture, including buffers needed only for subsequent rejection checks. Fixture setup needs one additional `Game` buffer while it runs the production admission path.

## Acceptance

Retain the real fixture, all original invalid-model, duplicate-component and foreign-projectile-owner checks, and their order. Keep post-fixture verification buffers out of fixture setup. Validate the original test, then the maintained full quality gate; a focused result alone does not accept the release.

## Related change

See [implementation and validation](PR-npc-profile-test-phase.md).
