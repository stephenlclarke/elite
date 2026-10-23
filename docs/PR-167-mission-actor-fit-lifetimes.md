# Borrow complete mission-actor fit authority inputs

## Motivation and evidence

[Issue167](https://github.com/stephenlclarke/elite/issues/167) records the one authorised existing-tool diagnostic on exact62315676 imageCF17E60A-9851-3BB8-A5AB-823B76623B06/SHA256a04942f52f13e77b29bf7dd02b316069d44d3a55124770ede19ef31b9c44309a. PID36284/start21:37:48UTC/full argv matched before attach. Driver exited1/debugger0 after14.290532292seconds; existing observer detached with handedBack true and no remaining owned test processes. Source/image hash stayed unchanged. `/tmp/elite-166-current-owned-capture` retains all command/identity/session/result/fault/offline symbolisation evidence.

Fault thread2 reaches chkstk and static missionActorFitMatches+452, then retained/current mission descriptor, combatMissionEntitlement, applyBodyHit/applyCombatHit, fireLaser, tick and CompletionFixture.completePatrol396 in original delayed report570. Offline exact-image atos slide0x1121c0000 derives from retained LR0x114d83b3c minus452 minus nm symbol0x2bc3978. No concrete guard mapping was retained, so guard bounds are not established. This is a current diagnostic fault, not attribution of the original92.930397084second normal run with unavailable matching report, and not a passing unit result. No selection/modelPose path is inferred.

## Implementation

Make the static fit matcher noninline and borrow all six existing body/retained actor/declaration/pack/instance/geometry inputs. Preserve exact nonNPC hull and both nil-NPC rules, then original npc existence/validity, retained fit equality, component identity matching, authoritative profile selection/definition equality and every installed-versus-retained model/design comparison. Separate noninline component/model helpers use equivalent sequential dictionary traversals to avoid capturing borrowed inputs in closures; preserve iteration, short circuit, empty-collection true results and lookup order. Explicitly copy the same pack/instance values only at the existing owned profiles/designs API boundaries. Keep profiles before models and each designs lookup at its original per-model position.

The full retained-owner uniqueness/admission/actor/physical/identity census and descriptor payload remain untouched. No cached acceptance, hash shortcut, generated geometry, authority relaxation or mutable shared state is introduced.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-diff review and one cached Swift6.1.2/SDK15.5 execution of the same four incomplete original methods are pending. No new selector, target capture/probe or replay is introduced. Earlier individual passes retain their source/results; current source alone establishes no stack savings or runtime success.

## Compatibility and remaining limits

No actor/state/save/schema, provider ordering, combat entitlement/reward, UI or quality threshold changes. All original incomplete methods, required coverage/sanitizer/leak checks, completed-save/reopen proof and release remain unqualified until actual results establish them.
