# G09: complete identified salvage return journey

Candidate for final Root approval, 20 October 2026. Root has approved the routine content/custody/settlement and conditional51/52 queue policy; the concrete geometry/physics follow-up below requests one additional bounded path. G10 is active; this is its proposed successor, not an implementation assignment. Source examined: canonical **2304d602a64820049af6e77acf709f7c46c55c20**, /Users/sclarke/.codex/worktrees/canonical-integration-recovery/elite. No canonical, app-code or ledger changes and no runtime job.

## Authored target and proposed ordinary content

**G09 / M08 / F26-F28 / F35 / K09**, exact `l337.contract/identified-salvage`.

Authority: this UX workspace's original-missions/original-families.json and .md, exact G09, and original-missions/ENGINE-CONTRACT.md. Existing service/clue artwork is referenced there.

Authored: locate two tonnes of uniquely registered recoverable equipment in an orbital wreck cradle, recover those exact physical items, and hand them to their consenting owner. Two tonnes of actual capacity; zero berths, deposit or donation; untimed. Reward **650 + 115L + 80H CR**. Final genuine receiving settlement alone commits **identified-salvage-family-trace**, once. A matching commodity name is not provenance.

The following ordinary defaults were **approved by Root on20October2026**; they remain distinct from the authored requirements:

- Issuer and legal property custodian: the actual Avenor G0/S7 main orbital station's recovery depot, represented by the authored **PELL** contact. The native station resource is the authority; PELL is its contact label, not a new simulated person or player-selected ownership flag.
- Collection source: one finite depot-owned wreck cradle in Renas G0/S185, with two already detached, packed equipment units. No cutter task, timer, station destruction, invented ship kill or living crew.
- Batch **avenor-pell-cradle-01**, serials **PELL-01** and **PELL-02**, each one tonne. Proposed labels: sealed utility controller and sealed power regulator. Neither is a fit-able player upgrade or ordinary Machinery stock.
- Return both to the same actual Avenor depot. Native round trip [7,185,7], L2/H0, frozen **880 CR / 8800 native**. Validate the real route/fitting/reach at review; no granted fuel or equipment.
- Require the existing fitted targeting core, Salvage targeting module and Fuel Scoops for the proposed guided recovery. No cutting tool for already loose packages. Use existing F/Tab recovery selection, automatic scoop approach, W/Return/E/Q; no new shortcut or forced firing.
- One initial finite incident. Later legitimate jobs need actual new available source stock, not re-created originals.

## Resolved geometry, poses and one exact physics gap

Source-only follow-up at the same2304d602 checkpoint. Existing original MIT assets suffice; no new mesh, texture or asset path is required. The selection below replaces the earlier open template/mass question.

| Declared G09 NPC template | Model and scale | Actual mesh | Native collision mass |
| --- | --- | --- | --- |
| pell-wreck-cradle | catalogue:SH141, scale1 | Existing wheel-shaped solid fixture;3368vertices/1872faces;radius60.13930557966478 | Existing profiled coarse hull.cobra policy:100000kg |
| pell-return-package, used for PELL-01 and PELL-02 | catalogue:SH058, scale0.2 | Existing original boxlike Hauler geometry;2352vertices/1598faces;radius6.322963883093118 after scale | Existing cargo policy:1000kg EACH, requiring the closed G09 collision-frame join below |

All three are nonhostile profiled actors, energy100, recharge/speed/acceleration/pitch/yaw/roll/fuel0, missiles0, ECMfalse, no weapons/components. The cradle is a depot recovery fixture, not an active native station, dockable port, occupied craft or a ship-destruction receipt. Its ring is treated as actual solid mesh; no interior or central opening is used for recovery.

The package model reuses project-owned geometry as a packed equipment container, not a tiny flyable Hauler or an inventory upgrade. Its scaled local bounds are X[-2.257902,2.257902], Y[-1.56284,1.56284], Z[-6,6]. The cradle bounds are X/Z[-60,60], Y[-8.11182,8.11182].

**Exact source fingerprints:**

- Sources/EliteCore/Resources/Ships/SH058.toml SHA256 **18c2164967b0784d9fbb24ee7be27ffee43606a8ba150edf58c313977892fac3**.
- Its unscaled design vertices/faces JSON fingerprint: **e7c1aa775b20d8b48db5782cb0639d268cfcdf790b7a4c5b8a78c31ddd69fa62**.
- Sources/EliteCore/Resources/Ships/SH141.toml SHA256 **4a11f2328446bc808104b0ced34e92bd7169a76ad4f139e203b0b021a47a029a**.
- Its unscaled design vertices/faces JSON fingerprint: **5c213b3d399a3f8b3c70a3c98b256daec794d5f2c8336d854ce4d502b3c095ea**.

The geometry fingerprints use UTF-8 JSON of {vertices:design.vertices,faces:design.faces}, keys sorted, separators comma/colon without spaces, ensure_ascii=true, no trailing newline. They identify the read-only arithmetic input; they are NOT asserted Swift ScriptNPCFit canonical hashes. The actual loader/makeScriptNPC must still compute and retain its own canonical geometry hash. Both designs and appearance metadata declare MIT, and neither uses sourceTextures or resolvedTextures. catalogue:SH040 is not selected: its installed design is the older CC-BY-NC-SA capsule, distinct from its original showroom replacement.

**Fixed exterior poses** in the existing profiled encounter's station-local frame, Renas G0/S185, identity local orientation and zero initial velocity:

| Actor alias | NPC | X | Y | Z |
| --- | --- | ---: | ---: | ---: |
| pell-cradle | pell-wreck-cradle | 0 | 0 | 24000 |
| pell-01 | pell-return-package | -2000 | 0 | 24000 |
| pell-02 | pell-return-package | 2000 | 0 | 24000 |

Each package is2000units from the fixture centre; conservative sphere clearance is **1933.5377305372422units**, and packages are4000units apart. Collection is external: approach each along its own negative-Z corridor without crossing the cradle. At an identity-oriented capture pose the player centre is package position minus the current scoop offset(0,-45,55): (-2000,45,23945) or (2000,45,23945). These are geometric reference poses, not teleports or granted guidance outcomes. The actual controller must attain the pose, safe speed and player-hull clearance.

The centred package sphere leaves **9.677036116906882units** inside the unchanged16-unit aperture on every axis; its raw asymmetric half-extent checks also fit. The actual shape/motion predicate still decides collection. Do not shrink the native player hull, increase the aperture or waive relative-speed checks. Existing whole-cohort native admission still checks the current world/loaded-region/occupied space and must remain pending/refused on obstruction. These arithmetic clearances do not claim a live scene/flight PASS.

**Verified existing construction/render/scoop chain:**

- ScriptNPCAssets.swift: readNPCModels resolves catalogue:ID to the installed ShipCatalogue design; scriptGeometryValid permits up to4096vertices/8192faces, so both selected sources fit. makeScriptNPC hashes the exact installed geometry.
- ScriptNPCProfile.swift: ScriptNPCDefinition.valid permits both0.2 and1 scales (0.001...1000), the declared zero-motion/unarmed values and energy100.
- ScriptEncounters.swift: prepareScriptEncounterPlan constructs the profiled body from the declared NPC; validateMissionActorAdmissionFit retains coarse hull.cobra. constructMissionActorAdmissionParts / transformedMissionActorAdmissionMesh measure the same raw vertices at definition.scale. NativeMissionActorAdmission.swift allocates genuine actor/spawn bindings and checks the whole physical cohort.
- ScriptNPCRendering.swift: scriptNPCMesh assembles that same scaled raw mesh. Display.swift drawBody selects scriptNPCMesh before the fallback. G09's already-proposed WorkTargetRuntime/FlightWorkGuidance/recovery helper must use this exact assembled mesh, as G08 does, rather than the coarse Cobra fallback. Keep the existing aperture/relative-motion predicates.
- AsteroidDebrisContact.swift: AsteroidImpactPolicy.massKg(.cargo)=1000 and .cobra=100000; AsteroidContactFrame.init(game:startTime:stepDuration:stationReady:) currently snapshots mesh:gameplayMesh(for:body) and mass from hull. PhysicalActorState has no independent encoded mass, ScriptNPCDefinition has no mass field, and a profiled actor cannot simply declare hull.cargo under the current admission guards.

**The one real additional reservation requested is Sources/EliteCore/AsteroidDebrisContact.swift, only the G09 branch at AsteroidContactFrame's body snapshot.** For actual live G09 originals whose accepted source/owner permit, alias, logical/native binding and exact model/scale validate, snapshot the same scriptNPCMesh plus the existing massKg(.cargo) for the two packages. For the validated cradle use the same scriptNPCMesh and unchanged massKg(.cobra). No manifest/caller mass field, payload stamp, hull/population conversion or new physical state.

This single bounded join fixes BOTH actual collision mesh and mass: the current generic gameplayMesh for profiled actors otherwise falls back to the coarse Cobra. Preserve every unrelated actor/debris/station path, actual source geometry, false debris/asteroid flags for these ordinary fixture/property bodies, and all collision/impulse limits. Do not pass the package through asteroidDebrisMassKg: a non-nil result there classifies it as asteroid/debris. Invalid registered G09 source/binding cannot supply the special geometry/mass or a pickup proof.

Source anchors for this exact join: AsteroidDebrisContact.swift:11 (mass table), :183 (AsteroidContactFrame), :208 (initializer), :245 (actual body loop), :261 (current mesh/mass operands); GameplayScene.swift:137 (physical actor adoption); ScriptEncounters.swift:941 (profiled coarse-hull selector), :980 (measured NPC parts), :1244 (profiled body constructor); GameplayWeapons.swift:285 (coarse gameplayMesh fallback); ScriptNPCRendering.swift:5 and Display.swift:322 (actual renderer mesh); WorkTargetRuntime.swift:149 and :185 (scoop shape/mesh checks). The renderer/admission template selectors are already compatible with the two chosen model IDs and scales. The existing reserved WorkTargetRuntime/FlightWorkGuidance callers need the closed G09 assembled-mesh selection, not a new shared renderer/template API.

There is no already-working one-tonne profiled-package factory to claim. The new G09 source-bound read-only mesh/mass query belongs in the already-proposed NativeIdentifiedSalvageRecovery helper; the one additional physical-frame hunk connects it to actual collision construction. No other extra source/asset reservation is currently identified. Owner qualification must include both package snapshots reporting1000kg with the actual scaled mesh, cradle100000kg, and an unrelated same-model/non-G09 actor retaining its existing policy; this directly checks the discovered gap.

## What the existing providers actually supply

| Existing source | Reusable fact or boundary | Limit for G09 |
| --- | --- | --- |
| Native station dock/context and ContractBoard | Actual living main-station issuer/receiver, review identity, native arrival and durable Confirm | No G09 depot title, permission or inventory declaration exists yet. |
| OriginalConsentedFreightSupply.swift | Finite source stock, stable original IDs and allocation-to-mission conservation | Closed to ARLEN's ordinary freight; do not issue G09 property into the ship at acceptance or reuse its IDs. |
| ScriptEncounters.swift / NativeMissionActorAdmission.swift | Actual profiled actor admission, physical bindings, retained actors, real destroyed/outside states | Need G09-specific original source joins and consumed-item exclusion. Collection is not destruction. |
| CargoScooping.swift / NativeSalvageCollection.swift | Actual scoop pass, physical geometry and same-frame observation/publication | Ordinary collection yields commodity/player technology and is not protected owner-return custody. |
| NativeSalvageBodyOwnership.swift / NativeSalvageCollectionMutation.swift | Exact native lot ownership and finite physical acquisition | Native lots explicitly exclude mission actors; copying a salvage payload/metadata cannot admit a mission package or assign legal title. Do not coerce it into the Alien ledger. |
| NativeOriginalRescueCapsules.swift | Genuine fitted-tool/aperture/motion seal, post-motion candidate publication, non-death removal and original record custody pattern | Closed to G08 people/record, source and rescue tools. It is a pattern, not existing G09 capture authority. |
| ScriptOwnedCargoState.swift / CommanderCargoValidation.swift | Protected issuer-owned freight and checked reservation/payload capacity accounting | G03/G02 freight starts aboard at issue; it cannot prove G09's later physical pickup. Existing checked payload totals can account for G09 slots once a closed validator supplies the correct count. |
| WorkTargetRuntime/Selection, FlightWorkGuidance, TargetColourClassification | Actual selection/mesh/guidance and recoverable cues | Need a closed G09 authorised-item branch; generic abandoned metadata must not bypass ownership/protection. |

The missing implementation is a **closed native G09 source/owner permission, physical-item acquisition and same-owner reception adapter**, not a generic salvage rewrite or a source-only proof model.

## Complete player journey

1. At actual Avenor, review PELL's depot authority, the two original serials, Renas cradle, required fittings/two-tonne capacity, round trip and880CR. Reading, Decline or Back changes nothing.
2. Confirm acceptance. In the existing durable candidate, register/allocate the finite depot batch and an actual native owner retrieval/return permission, bind the accepted job, and reserve two real hold tonnes. Both items remain physically at the cradle, not aboard. Enforce the existing maximum of three active Original contracts/services.
3. Launch and really travel to Renas. Admit the same original cradle/items through the existing native profiled-actor provider with one current physical binding per item. Show them as authorised recoverable property in the normal target filter and their exact names/serials in the job.
4. Select and physically approach each original package. The native collector alone seals actual fitted scoops, shape/aperture, relative motion, live item, carrier, owner permission, world/system/visit and operation/frame/epoch. It publishes custody and physical removal together. Merely targeting, clicking Recover, firing, passing a lookalike crate or supplying a payload ID collects nothing.
5. Carry both original protected items back to actual Avenor. Inventory/board show legal owner, serials, held0/1/2, still-reserved capacity and next action. They cannot enter the commodity market, be sold/stored/discarded as ordinary cargo, become owned fittings or be replaced by an upgrade.
6. At the genuine Avenor receiving office, the native owner provider consents to receive these same two serials under the current actual dock/review. Confirm both: transfer custody to that owner, remove their exact hold claim, close the job and atomically commit880CR plus the G09 clue once. One item, a wrong owner/dock, an old permit or another mission's evidence cannot settle.

The owner is the station recovery depot; the commander's equipmentOwnerID/world UUID is the save-world namespace and collecting carrier owner, **not a transfer of legal title**. Permission grants retrieval/custodial carriage, not ownership. Player Confirm requests the native operation; a Lua/player-supplied consent Boolean is never evidence.

## Original identities, custody and actual pickup

A closed finite source record in the existing ScriptEngineState tracks the actual owner station resource, batch, both serial IDs, cradle and allocation. Derive stable originals from the native world namespace plus owner resource/batch/serial, independently of a new mission, offer index, visit or pack digest. The job references that source. Reopen, reload, reinstall, cancel or a new pack version cannot replenish it.

Proposed G09 typed state lives in the existing ScriptInstance COW storage; do not insert these non-person items into NativePeopleCustodyState. It binds accepted permission, original serials, deployment/body bindings, actual captures, held/returned/lost disposition and final operation. Keep a bidirectional source-to-job join and one current custodian per item.

A new G09 recovery helper follows the genuine G08 original-record pattern, preserving its validators unchanged. Use the exact SH058/SH141 geometry and source-bound collision-mass join specified above; the additional physics hunk remains subject to Root reservation before implementation. Retain real fitted-equipment acquisition/physical authority rather than trusting a caller tool/elapsed parameter.

Reserve two tonnes at acceptance. While active, held tonnes plus unfilled reserved tonnes total two; physical pickup fulfils its reserved slot, never charges the slot and item twice. Reuse existing checked mission-payload accounting with a G09-only validated value. Inventory must distinguish held original property from an unused reservation. No extra mass in Alien technology storage or ordinary commodities.

Exclude registered G09 actors from the generic cargo fallback. Only the native G09 same-turn collection seal can consume them. Use existing non-death actor removal and a consumed-original predicate at retained admission, so a collected actor cannot return as loot. Actual destruction remains destroyed; culling/unloading is neither recovery nor loss.

## Receiver, rollback and loss

At final receipt, independently validate the genuine native owner/depot permission, current arrival, accepted job, both original acquisition receipts, same carrier/custody and unchanged review. Persist a distinct G09 receiving/settlement operation. No generic docking flag, commodity total, G08 record, player-owned salvage lot or old receipt substitutes.

Acceptance, collection and final reception use existing candidate/writer publication. A failed pickup publication retains the attained physical frame and the same collectible item/source; it grants no custody and removes no body. A valid retry acquires that item once. A failed receiver publication retains both held originals, capacity, cash and clue unchanged.

Actual destruction of either world item permanently prevents full successful delivery. Retain its native destroyed actor history; never recreate a replacement after a later write failure. A surviving held mate remains real owner property and can be returned without mission payment/clue. Untouched property remains at its cradle.

Before collection, cancellation changes no original ownership. After collection, offer actual owner return/cancellation, never remote deletion of carried items. Failure/cancellation releases unused reservations, while any still-held original continues to consume its actual tonne until physically returned or genuinely lost. Returning a failed/incomplete batch pays no success reward/clue and cannot restock the same incident.

Hook genuine hull destruction and the existing successful Escape Pod transaction into G09 loss disposition. Only property actually aboard is lost; untouched items do not become ship casualties. Preserve real world-item death even when a later mission publication fails. Do not weaken occupied-berth escape restrictions, repair cargo by fiat or introduce an independent loss timer.

## Prospective ownership: 32 paths, one additional reservation requested

Root reserves exact post-G10 hunks before any implementation. G3 authors only in an isolated qualified integrated G10 base; G1 alone composes/publishes and writes the canonical ledger. No current edit permission. The names below are proposed, not existing APIs.

Four new helpers:

- Sources/EliteCore/NativeIdentifiedSalvage.swift
- Sources/EliteCore/NativeIdentifiedSalvageBoard.swift
- Sources/EliteCore/NativeIdentifiedSalvageRecovery.swift
- Sources/EliteCore/NativeIdentifiedSalvageSave.swift

Twenty-one existing bounded callers (the last physics path is newly requested):

- Sources/EliteCore/Game.swift
- Sources/EliteCore/ScriptMissionState.swift
- Sources/EliteCore/ContractBoard.swift
- Sources/EliteCore/ContractBoardDisplay.swift
- Sources/EliteCore/ScriptContractPageInput.swift
- Sources/EliteCore/ScriptPack.swift
- Sources/EliteCore/ScriptCommanderQuery.swift
- Sources/EliteCore/ScriptPersistence.swift
- Sources/EliteCore/ScriptSaveJSONPreflight.swift
- Sources/EliteCore/ScriptBundledPacks.swift
- Sources/EliteCore/ScriptBaseClueCatalog.swift
- Sources/EliteCore/CargoScooping.swift
- Sources/EliteCore/WorkTargetRuntime.swift
- Sources/EliteCore/WorkTargetSelection.swift
- Sources/EliteCore/FlightWorkGuidance.swift
- Sources/EliteCore/TargetColourClassification.swift
- Sources/EliteCore/NativeMissionActorAdmission.swift
- Sources/EliteCore/ScriptEncounters.swift
- Sources/EliteCore/InventoryInformation.swift
- Tests/EliteCoreTests/BundledScriptPackTests.swift
- Sources/EliteCore/AsteroidDebrisContact.swift

Seven new qualification/content/notes files:

- Tests/EliteCoreTests/NativeIdentifiedSalvageJourneyTests.swift
- Tests/EliteCoreTests/NativeIdentifiedSalvageRecoveryTests.swift
- Tests/EliteCoreTests/NativeIdentifiedSalvageSaveTests.swift
- Sources/EliteCore/Resources/ScriptPacks/l337-identified-salvage/manifest.toml
- Sources/EliteCore/Resources/ScriptPacks/l337-identified-salvage/scripts/main.lua
- docs/ISSUE-native-identified-salvage.md
- docs/PR-native-identified-salvage.md

Game hunks: only G09 validity/runtime retry reset, genuine post-motion collection and actual fatal/escape/save retry joins. ScriptMissionState hunks: closed finite source stock plus typed optional G09 state/accessors/Codable, preserving existing COW representation. Other caller hunks expose actual board/cargo/target/actor/save paths. Do not touch the Alien salvage collector or G08/G10 authority merely to obtain a reusable-looking API.

Remove unnecessary paths at preflight. The newly requested AsteroidDebrisContact.swift hunk is the only identified addition to the original31 paths. Any further actual guard or affected shared-test caller requires Root's exact reservation before editing. A copied metadata label is never a physical mass/mesh producer.

## Save implications and meaningful owner acceptance

Propose **51 Normal / 52 Alien**, subject to Root's live reservation after G10's conditional49/50. G09-only is independently genuine; composed G02/G04/G05/G08/G14/G10 and Alien claims retain their own proof. Never invent another family's state to select an envelope. Lower schemas reject G09 fields; no old-format migration or widening.

Persist original owner/source stock/allocation, accepted permission, exact actor/capture/held/return/loss states, capacity accounting and once terminal/clue. Current load keeps completed custody even if its live actor is gone, restores only genuinely uncollected originals and validates retained physical/equipment authority historically. A live epoch is not a cold-save oracle.

Focused complete-boundary acceptance:

1. Actual issuer/owner review and Back are read-only. Wrong/forced dock, missing paid fitting, fewer than two free tonnes, stale review or full shared contract allowance refuses. Valid acceptance registers exactly two finite originals without putting them aboard.
2. Actual native deployment and physical approach collect each real original once. Wrong serial/body/batch/owner/visit, ordinary commodity, G08 record, forged payload/proof, absent scoops, unsafe aperture/motion or protected unrelated object refuses.
3. Capacity remains two total held-plus-reserved tonnes across0/1/2 pickups. Exact inventory serials/custodian, lawful permission and generic-market/fitting refusal remain honest. Culling/readmission/reinstall cannot duplicate or restock.
4. Actual return to the consenting owner with both originals commits880CR and the exact clue once; partial, wrong-owner, stale, foreign or replayed receiving evidence cannot settle.
5. Actual writer refusal/retry at source allocation, pickup and receiving preserves the same source, actors/custody, cargo, cash and clue. No synthetic collected flag or lost-frame backfill.
6. Actual world-item destruction, held-item ship/escape loss and incomplete return conserve untouched and surviving originals without replacement or success payment.
7. G09-only and composed Normal/Alien cold reload before pickup, after one pickup and after final/failed return retain exact joins. Reject missing/orphan/duplicate/foreign/null/stripped/old-envelope claims, including a held serial with no genuine capture.

Meaningful focused owner unit PASS and actual pack CLI/digest precede one independent coherent bugs/performance/style CLEAN review, then G1 integration. Use the authorised isolated MBA cache/lease; no GUI, broad CI/profiling, unaffected-cohort repetition or playable release claim.

## Root decisions and next candidate

Routine depot/PELL authority, route/L2/H0/880CR, finite originals, fitted recovery, two-slot accounting, actual incomplete return/loss and conditional51/52 policy are Root-approved. Final approval now concerns the concrete SH058/SH141 selection/poses and the one source-bound AsteroidDebrisContact.swift collision mesh/mass hunk, taking the prospective boundary from31 to32. G09 remains queued after qualified integrated G10; no current implementation/edit permission or runtime qualification is claimed.

**W05 / l337.wayfarer-service/record-recovery remains the subsequent existing candidate, not assigned.** Its specific physical recorder/custodian/service source is separate; a G09 crate or receipt cannot impersonate a flight/custody recorder or living survivor.

Root alone dispatches. Do not start G09, message coders or revisit active G10 from this candidate.
