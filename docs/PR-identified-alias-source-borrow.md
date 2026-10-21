# Read identified alias inputs through synchronous borrows

Remove the owned source/instances tuple from the identified salvage alias reader. Nested existing commander and script-state readers pass borrowed data directly to the static authority helper, whose optional source parameter becomes borrowing.

Keep every original guard and returned alias expression, with no state mutation, pointer escape, storage or gameplay-rule change. The static helper body and adjacent readers remain byte-exact.

## Validation

MBA formatting, strict lint and whole-file inverse checks pass. Exact copied hashes, ASCII, Markdown lint, diff and scope checks are required at freeze. No author native probe or compiler job runs.

G1 owns these existing three methods and three cases:

- stationAutoResponseKeepsCurrentActorWhenNearestDistancesCross
- NativeIdentifiedSalvageRecoveryTests/actualAliasReaderKeepsBothOriginalsAndCradleAuthorityAndRejectsUnprovedBodies
- NativeIdentifiedSalvageJourneyTests/actualTwoOriginalJourneyReservesOnceAndPaysOnlyAtSameOwner

A full independent review of all three paths follows actual owner PASS, then integration. The retained public fault evidence is separate from focused qualification; hosted CI repair is not yet claimed.
