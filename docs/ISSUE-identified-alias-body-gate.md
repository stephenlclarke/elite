# Keep owned alias preparation behind body eligibility

Public CI39575883263 still faults in Game.identifiedSalvageAlias at a stack probe after the prior source/instances borrowing correction. The selected owned stack reaches it through station auto-target selection while stationAutoResponseReplacesCurrentActorAndResetsMotion is running. The original image/dSYM UUID and relevant source hashes match the published b183 candidate.

The outer reader still holds its owned SpaceBody copy and nested closure context in the same function as its early body-tag, hull and finite-pose checks. Source-level borrowing of the saved source removed the earlier tuple, but did not separate this remaining preparation from rejected bodies. The emitted frame size and exact failed body tags are not captured, so no guaranteed hosted repair is inferred.

Keep the existing eligibility guard and its order in the outer non-inlined reader. Move its unchanged body-copy, system projection and nested read tail into a separate private non-inlined helper called only after that guard succeeds. The static validation and intentional local optional copy remain unchanged. No actor, storage, schema, ownership policy, authority or gameplay rule changes.

## Validation

Formatting, strict lint and the inverse whole-file check precede the source freeze. G1 then uses one matching build and these existing three methods/four cases: stationAutoResponseReplacesCurrentActorAndResetsMotion (both declared conditions), actualAliasReaderKeepsBothOriginalsAndCradleAuthorityAndRejectsUnprovedBodies, and actualTwoOriginalJourneyReservesOnceAndPaysOnlyAtSameOwner. Complete three-path independent review follows actual owner PASS. Full CI, coverage, sanitizers, leaks and required PR review remain separate.
