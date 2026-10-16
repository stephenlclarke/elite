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

The current exact provider API is G2 pin `62fe35d38ba69d7cf2f3238d737daa1f348e69c0`, imported only through its owned `MissionNativeBridge.swift` dependency. MC1's `ScriptNativeBridge.swift` projects existing authored and retained facts into those exact descriptors. These factories grant no native attack authority by themselves.

`Game.currentMissionActorDescriptor(bodyID:)` joins the unique current live body to its actual Mission instance, revision, digest, installed pack, encounter, admitted presence, alias and durable UUIDs. The immutable NPC fit matches the retained record, actual authored declaration and installed geometry referenced by its saved hashes. Retained actor bodies are anchor-relative and can contain older mutable condition, so they must not be compared wholesale to current live bodies. The descriptor carries the actual current body. G1 must resolve this join again at use, then let G2 seal and validate the actual native binding, role and protection.

`Game.missionWeaponDescriptor(_:source:component:muzzle:direction:)` joins the exact authored weapon to its live actor and actual living component, recomputes the transformed muzzle and preserves authored values. MC1 supplies per-frame cooling and aim through `advanceScriptNPCWeapons(delta:)`; G2 owns the discharge through the actual `fireMissionNativeWeapon(bodyID:weaponID:componentID:)`, including budgets, charging, shot count and firing event. Each weapon re-reads its live body and writes only the selected cooled/aimed gun before that call. There is no captured NPC or body write after firing. Native laser/impact target-event capacity precommit integration remains pending. Re-read the current body before each discharge: a previously captured body becomes stale when an earlier weapon spends energy. No full scene copy, additional gun owner, allocator or geometry encoding belongs on this path.

`ScriptNPCShot.missionDescriptor` preserves the existing eleven physical fields without requiring the historical owner to remain present. Its optional `nativeAttribution: MissionLaunchArchive?` uses the actual provider archive and G1's real native `MissionLaunchJudgement`; firing and projectile motion delegate to the actual native provider; final native event-capacity integration and validation remain pending. Descriptor tests use real pack acceptance, encounter admission, authored weapon facts and legacy shot coding. All are uncompiled and unexecuted.

## Shot archives and physical persistence

`ScriptNPCShot` retains a public immutable optional archive with an explicit initializer preserving its eleven existing arguments and default-nil compatibility. Only an absent old field is unknown history. A present null, malformed archive or mismatched shot, instance, source or component refuses decoding. The saved engine additionally joins the archive to the actual retained instance digest and original system. No missing current physical owner recreates an origin, and decoded data never becomes a native impact capability.

`persistScriptShots(anchor:unloading:)` and `recordScriptShotRemoval(_:)` retain the complete shot and unchanged archive while transforming only position, orientation and velocity through the actual station anchor. Dead shots remove their record; living shots leaving the bubble preserve their actual outside state even before their first published save. These consumers neither allocate nor append native actors. Restoration calls G1's actual `admitRetainedMissionProjectile(_:)` helper and updates only the committed record address and presence from its real receipt. Temporary native refusals retain pending records; missing, invalid and malformed evidence propagates through the throwing restoration boundary. The pure preflight checks all eligible retained source records before actor restoration. G1 owns game-boundary error handling and the native allocator; the old shot allocator path is excluded.

Archive fixtures use a real accepted actor, native binding, native emission allocator and actual pure launch adjudication, explicitly as law/codec staging without an atomic-fire or impact-proof claim. They cover modern exact coding, legacy absence, malformed present values and source-version/system joins. Runtime format-21 admission, idempotent restoration, resave/reload, actual native capacity refusal and hashed-chunk corruption regressions are authored. The early preflight now calls G1's actual native batch validation, which shares one read-only context and checks later hard failures even after earlier temporary refusals. This runs before actor restoration and again before the shot consumer, without adopting or allocating native state. The ordered two-shot regression covers both an admissible first shot and a temporarily outside first shot, followed by a malformed real current binding. Source review has closed that identified gap; execution remains pending. The authored firing loop now delegates to the actual native firing and projectile-step APIs. Native target-event capacity integration and scheduled validation remain pending. No test has been executed.

## Projection of real native impact receipts

`Game.projectScriptMissionImpact(_:)` consumes G1's actual `NativeMissionImpactReceipt` once immediately after the native kernel and before body culling or event draining. It preserves the original admitted damage in `actor.damaged`, the actual component alias and UUID in component events, and the genuine Script source UUID even when historical native adjudication is unknown. The real player path emits `player = true` and a null `attacker_id`.

The projection requires the actual kernel's `damageAdmitted` flag before emitting damage or component events. Immune native targets retain their ordinary immunity. It removes the actual terminal shot record and delegates actual hull terminal recording to the existing retained actor and world-resource routines. It applies no physical damage, hostility, credits or crime effects. The receipt initializer is private to G1's provider file.

Four authored test methods (six declared cases) now exercise actual sealed NPC laser proofs, actual native player contact, and restored legacy plasma proofs through G1's real kernel and the event projector. They check original damage exceeding the remaining target condition, component versus hull terminals, replay refusal, genuine absent source UUIDs without native credit, and player attribution with a null Script attacker. A real admitted classic Mission Constrictor exercises the positive damage amount with `damageAdmitted = false`, unchanged health and no damage or terminal events. These tests remain uncompiled and unexecuted; they do not establish atomic firing, event-capacity integration or a completed validation gate.

## Event capacity before native commit

`Game.planScriptMissionImpactEvents(...)` is a pure bounded accounting helper. The native owner must supply its actual planned `damageAdmitted`, component and hull outcomes before any allocation or commit. It counts only events emitted to active instances, checks both the 4096 pending-event limit and the emitter's sequence limit, and returns ephemeral facts. It does not predict immunity, shield absorption or mining effects, reserve a persistent slot, clone the game or mutate the queue. Four authored methods cover actual queue occupancy, source and target event counts, terminal ownership and sequence overflow. Native precommit integration and its real refusal regressions still require G1/G2's exact API.

## Actor-owned world jobs at native culling

Two authored runtime regressions exercise a real active actor-owned job with a retained pending pulse and suspension. Living bubble departure must retain the latest hull and component condition and keep the job active through format-21 save and reload. Actual dead-body culling must cancel the job, clear its pulse and emit the terminal once; that positive case checks save/read consistency but does not claim reload coverage. G1 owns the native cull caller and its living-versus-dead distinction. Both methods remain uncompiled and unexecuted.

## Authored gun loop and native projectile delegation

The MC1 loop preserves accepted authored weapon order, transformed root and component muzzles, range and arc checks, cooldown and heat decay, and bounded spherical aim tracking. It resolves the current live body separately for every weapon and publishes only that weapon's gun state. The actual G2 entry point owns final eligibility, native allocation/admission, archive creation, resource debit, shot count, beam range, firing events and kernel invocation. `advanceScriptNPCShots(delta:)` delegates to `stepMissionNativeProjectile(projectileID:delta:)`, whose real native caller already projects its receipt once. Neither wrapper duplicates physical effects or event projection.

Typed temporary capacity and native admission refusals leave the weapon eligible for a later frame. Hard refusals record the owning instance's suspension without replacing an existing diagnostic. Both wrappers accept finite positive steps at most 60 seconds. The corresponding accepted NPC tests now use actual native collision/proof/kernel paths, actual fitted player and authored NPC damage, actual typed native budget admission and canonical equipment grants. Their weapon and plasma paths call these wrappers; compilation and execution remain pending. No legacy raw damage, caller-constructed hit, raw body allocation or separate resource owner is imported.

## Sealed actor admission sources and retention

`MissionActorAdmissionSource` and its template, part and retention-patch constructors are file-private to `ScriptEncounters.swift`. Prepared sources originate inside the actual command-candidate handler; retained sources read actual installed Commander ownership. Both join the exact source definition, version, digest, actor identity, immutable NPC fit, referenced installed geometry, component identities and source HP bounds. Prepared sources additionally require pristine authored placement and initial condition, and cannot reset an admitted cohort. World jobs pass their actual job UUID and pending pulse sequence; authority checks the installed definition, controlled encounter, world, active resource owner and pulse before any actor/model staging.

Templates preserve canonical spent condition while stripping historical scene/native identity from the proposed body. Measured root and component meshes, living solid bounds, native-unit counts and actual HP limits are read-only facts. Retained native AI/resources, velocity and cooldown are condition data for native policy to rebind. They do not grant historical attack or native identity authority. `validateMissionActorAdmissionSource(_:)` rechecks actual installed owner and authority, including the captured base encounter, without accepting an arbitrary caller snapshot or manufacturing a current live descriptor for a prepared actor.

`prepareRetentionPatch(sceneBodyIDs:)` validates native preparation's new addresses and stages only the selected record addresses/presence. Initial admission requires the complete eligible cohort. A patch matches exact instance ID, revision, digest, definition, version and expected encounter; `preparingInstance(_:)` completes fallible retention staging before native commit. The owned adapter must publish that already prepared retention immediately after native commit in the same actor turn, with no await or fallible lookup. The owned initial and restore adapters now use G2's actual `prepareMissionActorAdmission(_:)` and `commitMissionActorAdmission(_:)` APIs. Initial admission stages its private command-candidate retention before commit. Restoration first validates every available source and performs pure native preparation for every cohort before any mutation, then prepares each selected cohort again against fresh counters and directly publishes its staged retention after commit. Temporary pending and unchanged results preserve retained condition. Raw actor append and scene-ID allocation are removed. G1's actual `restoreNativeMissionStationIfEligible()` runs only after all hard preflight, before fresh cohort preparation; its current station identity and guards remain native-owner dependencies. These source changes and dependency fixes still require compilation and execution.

Eight authored source-seal methods (24 declared cases) cover actual initial handlers and retained ownership, wrong owner/content/revision/actor/component/condition/placement, changed installed geometry, later invalid cohort preflight, exact real world-job pulse authority and stale retention staging. The cross-cohort native regression preserves an eligible first cohort or an outside no-op, then breaks a later actual live owner join and requires refusal before any earlier publication. Obstruction and foreign-body fixtures use actual native allocation and admission receipts. They are uncompiled and unexecuted.

## Final terminal condition before persistence

The actual native kernel can project a hull terminal before the central persistence pass. Persistence skips records already marked destroyed, so terminal recording now retains the actual final body condition, including gun/component stocks, native death evidence and canonical pose/velocity, before changing presence. With no available station frame it retains the last canonical pose and velocity while preserving terminal condition. A real sealed laser/kernel regression checks exact final condition survives subsequent persistence and culling with one terminal event. It remains uncompiled and unexecuted; this change creates no death-credit authority.
