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

## Optional unwrap compiler correction

The actual 1242 build rejected consuming the borrowing optional in its existing guard. The same guard now explicitly copies that Copyable optional before binding its value. This intentionally retains one local copy inside the static helper while the outer retained tuple stays removed. Nested synchronous borrows, early guards and all remaining validation order and returns are unchanged. No test ran on the rejected build; G1 owns the matching corrected build and the same three existing cases. No frame-size or copy-performance benefit is claimed from this correction.

Actual pure-public corrected compilation1243 PASS67.46seconds. All three unchanged methods/cases1244 PASS, final20.584seconds, zero issues/unknown outcomes; runner25.467745seconds/outer27.442276seconds. All fourteen observed owned starts close naturally, source/preferences/2010 artifacts exact. Complete final three-path independent review CLEAN SHA2567c72b65ac57e62892761dfbbd967c15f6c15edc6d09a31f35c38bd19f2a95677, including the intentional local optional copy. Exact final source integrated at9381f2e4. Original1242 compile failure remains retained; no tests ran on that rejected source. Final public CI/review remain required; no frame, copy or hosted-repair benefit is inferred.
