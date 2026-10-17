# Separate NPC contact verification from later impact lifetimes

## Change and motivation

The original test still creates the same fixture and passes its game by inout reference. Its verification helper now calls three sequential phases: original measured component contact checks, original ally hull laser impacts, then original destruction/bounty checks. Only target ID and initial kill count cross those phase boundaries. See [the diagnostic evidence](ISSUE-npc-contact-lifetimes.md).

Actual NPC laser proof construction moves into an inout helper returning the same proof. The source/target body, NPC fit and aiming temporaries belong to that helper; proof application and event projection remain in their original order in the calling helper. All existing users of this shared laser helper continue through the same proof checks and real impact pipeline.

## Compatibility and preservation

All original operations and assertions remain in order, including the fresh player contacts/origins, fitted laser damage, component identity/event/energy checks, measured miss and hull rays, actual ally weapon damage and impact count, final kill conservation and encounter presence checks. Only test helper boundaries change. No production code, assertion outcome, case selection, skip, heap wrapper or runtime option changes.

## Validation and risks

Strict Swift formatting, Markdown lint and diff checks pass. Reversing only the deliberate helper boundaries reconstructs the entire original test file exactly against `73ca30b5daba33b539e20d027cfd494356013036`. This worker has not compiled or executed the changes. The integration owner retains combined validation and required `make ci`; the lifetime hypothesis and crash resolution require runtime evidence.
