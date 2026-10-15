# Gameplay ecology interface checkpoint

This feature starts from protected main `1ef005e0c73971a360a0e3bb52792a9286a761d3`. The contracts in `GameplayContracts.swift` are an implementation boundary, not a claim that gameplay is delivered. The route release and planet performance work remain separate. G1 owns integration and all central game, body, combat, save and presentation adapters; G2 owns independent traffic, geography, mining and typed ordinary payload modules plus their tests.

## Identity, coordinates and time

G1 allocates physical `ActorIdentity` values. Existing body integer IDs remain renderer/targeting compatibility identifiers. Actor identities include system and visit; they are never reused within a visit. Spawn requests carry request identities and receive admission receipts. Rock and ore payload identities omit visit, so leaving and returning cannot replenish ore. Wreck identities include the destroyed actor and cargo lot.

All context, anchor, spawn, payload and intent positions use canonical system space. G1 maintains the ship pose and converts to the existing ship-relative rendering/physics frame. Station, arrival, planet and sun anchors survive body culling. Launch and hyperspace arrival choose ship poses relative to those anchors; they do not regenerate fields around the camera. `ShipPose` supplies the conversion boundary.

`EncounterContext.physicalTime` is a dedicated persisted clock advanced at the actual flight physics admission point. It does not use `Game.time`, wall time, redraws or a UI timer. Existing pause, title, help, route planning, gallery, handoff, rumour and future mission-library exclusions remain intact. Context system, visit and revision must match before G1 accepts a returned plan.

## G2 module boundary

`EncounterDirector.advance(context:)` returns `EncounterPlan`. `acknowledge(receipts:)` records actual admission; it must not assume every request was admitted. Each finite pirate pack is an atomic `SpawnBatch`. Deferred ore pods may use individual requests. G1 owns the combined admission budget and enforces role caps, eight police reserve places and four mission reserve places. Ambient suppression and protected mission actors/payloads are explicit inputs. Ordinary police Vipers must not suppress Naval encounters by hull name.

NPC intents request navigation, combat, docking, mining or scooping. They cannot directly damage a body, credit cargo, extract ore or finish docking. G1 verifies the current identity, steering, orientation, range, cooldown, nearest intersection, occlusion and transaction preconditions. NPC roles and legal records are independent of hostility to the player. Director decisions use a dedicated persisted deterministic stream, never `Game.randomByte` or `Swift.Hasher`.

G2 owns `EncounterDirector.swift`, `EncounterGeography.swift`, `TrafficIntent.swift`, `MiningFields.swift`, `MiningLedger.swift`, `TypedCargoPayload.swift` and dedicated test files. It must supply concrete mining generation, hit, pending-payload admission and collection methods before its integration handoff. Any required shared contract change goes through G1.

## Combat and cargo

`AttackOrigin` preserves the original owner, emission identity/time and legal status even after the owner or ordnance disappears. `CombatIncident` captures the victim's legal status before mutation, first aggressor, attack/outcome, position and optional laser kind/facing. G1 assigns incident IDs and resolves lawful credit once. Interception/removal/culling is distinct from hull destruction. Hostility never creates bounty entitlement.

`CommodityIdentity` uses the existing seventeen market/save indices; native units derive from `Commodity.all`. Minerals and Alloys consume tonne capacity, Gold and Platinum are kilograms, and Gem-Stones are grams. Ordinary payloads exclude mission lots, people and equipment. G1 validates actual scoops and atomic cargo capacity/quantity bounds; a full tonne bay alone cannot reject kilograms. The separate mission engine's `Commander.sellableCargo` remains the future availability adapter.

The mining ledger terminalizes the rock and records pending fragments before physical admission. Rejected admission leaves pending ore. Collection credits cargo and terminalizes the payload in one runtime operation without suspension. Culling only clears physical bindings. Depletion and payload settlement survive docking, revisits and save/load. Use compact sparse records and terminal masks so the existing four-MiB save bound remains meaningful; never silently drop depletion or pending cargo to meet it.

## Delivery and validation

The orchestrator's gameplay design defines A01-A21 and explicitly labels new tuning as project choices. G1 and G2 must integrate the real player and NPC paths, preserve old saves and mission randomness/protection, show bounded HUD/voice events, and capture native scenarios with cheats disabled. Pure modules alone are incomplete. Focused deterministic tests precede integrated `make ci`; publish Sonar only from committed main with its exact SHA, and publish through the existing signed/notarized release workflow. README media comes only from `make readme-media`.
