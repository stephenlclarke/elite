# Mission canonical adapter source seams

Initial source-only pin based directly on shared provider
`61b496d51c76156e07ae31e435b808ed97f03dd4`. This is uncompiled and unexecuted.
The complete accepted engine, native migration, sealed helpers and remaining
consumer adapters must be composed before validation. No canonical owner file
was imported from the old Mission branch or edited by MC1.

## Legacy migration input

`LegacyOwnedEquipmentInventory` is the old bag's read DTO, with `items: [OwnedGear]`.
Its canonical Commander decode property is `legacyOwnedEquipment`, preserving the
old JSON key `ownedEquipment`; G1 owns that property and omits the old bag in v2.
No live mutation or synchronizing/getter identity creation remains in this DTO.

`OwnedGear` retains its original `id`, `kind`, `preferredSlot`, `fittedSlot`,
`condition`, `modifications`, `issuedBy`, `sourceResource` and `loanOwner` fields.
`OwnedGearKind.canonicalNode: EquipmentNodeID?` and
`OwnedGearSlot.canonicalSlot: ComponentFittingSlot?` provide pure crosswalks.
Unsupported mappings return nil for explicit migration refusal.

`LegacyOwnedEquipmentInventory.validateIssues(in: ScriptEngineState) throws`
checks original v1 reciprocal rights without inventing consumption for historical
nonloan absence. Stored loans retain their valid condition/modifications. G1
owns physical migration and the explicit v2 record initializer call.

## Canonical issue and consumption

`Commander.equipmentIssueObligations() throws -> [EquipmentIssueObligationSnapshot]`
includes every retained issue, including missing content and settled/nonloan
records. It validates source, node, original order, statuses and both directions
of physical joins using narrow inventory/context checks, without `Commander.valid`
recursion. `issuedEquipmentValid` exposes the same check as a predicate.

`ScriptEngineState.gearConsumptionDelta(for: OwnedEquipmentItem) throws -> ScriptGearConsumptionDelta?`
returns nil only for nonmission provenance. Invalid mission provenance or rights
throw. The delta retains exact before/after records and `gear.consumed` values.
Its initializer is file-private.

`ScriptEngineState.applying(_: ScriptGearConsumptionDelta) throws -> ScriptEngineState`
returns staged state only after an exact old-record check. Only the identified
original's consumed set changes. It does not publish a Game, remove a device,
emit an event or count a virtual launch. G1 publishes the entire native operation
and these records together.

## Actual Mission sources for the native bridge

The first exact provider API is G2 pin `4eb86dd09cb737fa3a3d82b2f04d6eb4652028d7`, imported as the single new `MissionNativeBridge.swift` dependency. MC1's `ScriptNativeBridge.swift` projects existing authored and retained facts into those exact descriptors. These factories grant no native attack authority by themselves.

`Game.currentMissionActorDescriptor(bodyID:)` joins the unique current live body to its actual Mission instance, revision, digest, installed pack, encounter, admitted presence, alias and durable UUIDs. The immutable NPC fit matches the retained record, actual authored declaration and installed geometry referenced by its saved hashes. Retained actor bodies are anchor-relative and can contain older mutable condition, so they must not be compared wholesale to current live bodies. The descriptor carries the actual current body. G1 must resolve this join again at use, then let G2 seal and validate the actual native binding, role and protection.

`Game.missionWeaponDescriptor(_:source:component:muzzle:direction:)` joins the exact authored weapon to its live actor and actual living component, recomputes the transformed muzzle and preserves authored values. Existing simulation code supplies its actual transformed aim and owns all gun state. Re-read the current body before each discharge: a previously captured body becomes stale when an earlier weapon spends energy. No full scene copy, additional gun owner, allocator or geometry encoding belongs on this path.

`ScriptNPCShot.missionDescriptor` preserves the existing eleven physical fields without requiring the historical owner to remain present. The first provider pin contains no native attribution archive or law-freeze API; neither is invented here. Their actual provider types and atomic firing, impact and persistence consumers remain separate integration work. Descriptor tests use real pack acceptance, encounter admission, authored weapon discharge and legacy shot coding. All are uncompiled and unexecuted.
