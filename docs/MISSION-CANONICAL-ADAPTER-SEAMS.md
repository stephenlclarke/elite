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
