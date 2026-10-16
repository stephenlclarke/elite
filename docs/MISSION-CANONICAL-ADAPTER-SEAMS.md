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

The current exact provider API is G2 pin `666cc5eba43d101e13aef58ca3eea75aeff59b25`, imported only through its owned `MissionNativeBridge.swift` dependency. MC1's `ScriptNativeBridge.swift` projects existing authored and retained facts into those exact descriptors. These factories grant no native attack authority by themselves.

`Game.currentMissionActorDescriptor(bodyID:)` joins the unique current live body to its actual Mission instance, revision, digest, installed pack, encounter, admitted presence, alias and durable UUIDs. The immutable NPC fit matches the retained record, actual authored declaration and installed geometry referenced by its saved hashes. Retained actor bodies are anchor-relative and can contain older mutable condition, so they must not be compared wholesale to current live bodies. The descriptor carries the actual current body. G1 must resolve this join again at use, then let G2 seal and validate the actual native binding, role and protection.

`Game.missionWeaponDescriptor(_:source:component:muzzle:direction:)` joins the exact authored weapon to its live actor and actual living component, recomputes the transformed muzzle and preserves authored values. MC1 will supply per-frame cooling and aim through the agreed simulation loop; G2 owns the single atomic discharge, including budgets, charging, shot count and firing event. That exact firing API is still pending. Re-read the current body before each discharge: a previously captured body becomes stale when an earlier weapon spends energy. No full scene copy, additional gun owner, allocator or geometry encoding belongs on this path.

`ScriptNPCShot.missionDescriptor` preserves the existing eleven physical fields without requiring the historical owner to remain present. Its optional `nativeAttribution: MissionLaunchArchive?` uses the actual provider archive and G1's real native `MissionLaunchJudgement`; atomic firing and impact consumers remain separate integration work. Descriptor tests use real pack acceptance, encounter admission, authored weapon facts and legacy shot coding. All are uncompiled and unexecuted.

## Shot archives and physical persistence

`ScriptNPCShot` retains a public immutable optional archive with an explicit initializer preserving its eleven existing arguments and default-nil compatibility. Only an absent old field is unknown history. A present null, malformed archive or mismatched shot, instance, source or component refuses decoding. The saved engine additionally joins the archive to the actual retained instance digest and original system. No missing current physical owner recreates an origin, and decoded data never becomes a native impact capability.

`persistScriptShots(anchor:unloading:)` and `recordScriptShotRemoval(_:)` retain the complete shot and unchanged archive while transforming only position, orientation and velocity through the actual station anchor. Dead shots remove their record; living shots leaving the bubble preserve their actual outside state even before their first published save. These consumers neither allocate nor append native actors. Restoration calls G1's actual `admitRetainedMissionProjectile(_:)` helper and updates only the committed record address and presence from its real receipt. Temporary native refusals retain pending records; missing, invalid and malformed evidence propagates through the throwing restoration boundary. The pure preflight checks all eligible retained source records before actor restoration. G1 owns game-boundary error handling and the native allocator; the old shot allocator path is excluded.

Archive fixtures use a real accepted actor, native binding, native emission allocator and actual pure launch adjudication, explicitly as law/codec staging without an atomic-fire or impact-proof claim. They cover modern exact coding, legacy absence, malformed present values and source-version/system joins. Runtime format-21 admission, idempotent restoration, resave/reload, actual native capacity refusal and hashed-chunk corruption regressions are authored. The early preflight now calls G1's actual native batch validation, which shares one read-only context and checks later hard failures even after earlier temporary refusals. This runs before actor restoration and again before the shot consumer, without adopting or allocating native state. The ordered two-shot regression covers both an admissible first shot and a temporarily outside first shot, followed by a malformed real current binding. Source review has closed that identified gap; execution remains pending. Atomic firing/impact integration and scheduled validation remain pending. No test has been executed.

## Projection of real native impact receipts

`Game.projectScriptMissionImpact(_:)` consumes G1's actual `NativeMissionImpactReceipt` once immediately after the native kernel and before body culling or event draining. It preserves the original admitted damage in `actor.damaged`, the actual component alias and UUID in component events, and the genuine Script source UUID even when historical native adjudication is unknown. The real player path emits `player = true` and a null `attacker_id`.

The projection requires the actual kernel's `damageAdmitted` flag before emitting damage or component events. Immune native targets retain their ordinary immunity. It removes the actual terminal shot record and delegates actual hull terminal recording to the existing retained actor and world-resource routines. It applies no physical damage, hostility, credits or crime effects. The receipt initializer is private to G1's provider file.

Four authored test methods (six declared cases) now exercise actual sealed NPC laser proofs, actual native player contact, and restored legacy plasma proofs through G1's real kernel and the event projector. They check original damage exceeding the remaining target condition, component versus hull terminals, replay refusal, genuine absent source UUIDs without native credit, and player attribution with a null Script attacker. A real admitted classic Mission Constrictor exercises the positive damage amount with `damageAdmitted = false`, unchanged health and no damage or terminal events. These tests remain uncompiled and unexecuted; they do not establish atomic firing, event-capacity integration or a completed validation gate.

## Event capacity before native commit

`Game.planScriptMissionImpactEvents(...)` is a pure bounded accounting helper. The native owner must supply its actual planned `damageAdmitted`, component and hull outcomes before any allocation or commit. It counts only events emitted to active instances, checks both the 4096 pending-event limit and the emitter's sequence limit, and returns ephemeral facts. It does not predict immunity, shield absorption or mining effects, reserve a persistent slot, clone the game or mutate the queue. Four authored methods cover actual queue occupancy, source and target event counts, terminal ownership and sequence overflow. Native precommit integration and its real refusal regressions still require G1/G2's exact API.

## Actor-owned world jobs at native culling

Two authored runtime regressions exercise a real active actor-owned job with a retained pending pulse and suspension. Living bubble departure must retain the latest hull and component condition and keep the job active through format-21 save and reload. Actual dead-body culling must cancel the job, clear its pulse and emit the terminal once; that positive case checks save/read consistency but does not claim reload coverage. G1 owns the native cull caller and its living-versus-dead distinction. Both methods remain uncompiled and unexecuted.
