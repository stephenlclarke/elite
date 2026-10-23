# Current system identity storage projection repair

## Motivation

[Issue150](https://github.com/stephenlclarke/elite/issues/150) identifies a mapped stack fault in a complete current-context diagnostic. The original evacuation rollback test reaches the generic Commander callback while reading only the current system identity.

## Implementation

Game.storedSystemIdentity opens the existing synchronous commander storage borrow and calls the typed galaxy/system reader. GameplayScene.systemIdentity uses that bridge. Remove its now-unused private borrowed-Commander projection leaf. No pointer escapes, no actor ownership changes and no authority, validation or transaction rule changes.

## Validation

Formatting and diff hygiene pass. Independently verified diagnostic evidence and the original three-method/eleven-case focused selection are described in [the issue record](ISSUE-150-current-system-projection.md). Focused execution and actual source/result review are pending. No assertion, selector, concurrency or stack setting is changed.

## Compatibility and remaining limits

There is no save schema or player behavior change. The diagnostic is not normal qualification, and earlier issue144 SIGILL origins remain unproved. Full final-head VM and required quality checks, native M01 acceptance and release remain separate.

The first focused invocation at 56f5283de1f91cf7f9481ecff91cdc0781fa8950 failed compilation after 19.002449 seconds, before tests ran. The now-removed private leaf still had a second caller in finishGameplayContext. That exact caller now uses the same stored scalar bridge; encounter-context system values and read order remain unchanged. Original failed evidence remains at `/tmp/elite-system-identity-evacuation-units-result.json` and its raw log.
