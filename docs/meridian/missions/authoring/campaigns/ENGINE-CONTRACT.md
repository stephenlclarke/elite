# L337 original campaign engine contract

The 39 campaign TOMLs use a private design schema, `l337-mission-design/1`. They are complete story and interaction specifications, not files claimed to work in the current app. An authorised implementation must translate them to the mission framework's supported format and add the contracts below where absent. All simulation state, receipts, mission entities and economic mutations belong to GameRuntime actor isolation; UI dialogs stay on the main actor and submit intents.

## Evidence and transitions

Every event carries pack ID, mission instance, stage ID, target identity and a persisted event receipt. Validate that the source entity, location and player action match the active objective. Accumulate distinct required targets; repeated scans cannot substitute for missing targets. Commit stage changes and their effects atomically. A replayed event after loading is a no-op. Destroying or culling a target does not imply a completed scan, recovery, repair or escort arrival.

| Event | Required evidence |
| --- | --- |
| `mission_contact_confirmed` | Player confirms the named contact at the correct docked station; capacity and any transfer requirements pass. |
| `entity_scan_completed` | The player targets the mission entity, maintains the advertised scan range and completes its scan; identity and location match. |
| `mission_item_recovered` | The uniquely identified physical item is within recovery range, the recovery action is confirmed and hold capacity passes. Data-only recorders consume zero tonnes. |
| `mission_action_confirmed` | The named repair, relay calibration or emitter shutdown completes against the correct mission entity. Each action has an explicit HUD prompt and progress indication. |
| `escort_arrived` | The unique escort survives and is accepted by station arrival control. A generic same-type ship or a despawn is insufficient. |
| `mission_choice_confirmed` | The player explicitly selects one advertised option and confirms it. Record the selected branch once and use it in later dialogs and gossip. |

Map sequence steps to normal gameplay: scans require a target, recoveries use normal scoop/recovery interaction, repairs and calibration use a contextual Confirm action, and escorts use flight and docking arrival. Display the destination, target, progress count and next action in the mission log and HUD. Confirm and Esc must follow the shared UI control scheme. No undisclosed keyboard commands or invented off-screen actions should be necessary.

## Item lifecycle

The Glass Meridian's timing standard occupies one tonne between `recover-standard` and completion of `rebuild-lane`; consume it into the last relay and release the reservation. The flight recorder and evidence ledger are data-only.

A Choir Beneath the Static's collector occupies one tonne between recovery and `interpret`; hand it to Vale at analysis and accept a one-tonne repair culture in the same confirmed transaction. Calculate capacity after both effects, so this exchange uses the same one tonne rather than demanding a second free tonne. Consume the culture once at `repair-probe`. Signal recordings are data-only. Never progress a culture transfer without custody of that mission item.

The Hollow Manifest's inspection kit occupies one tonne from `analyse-seals` through `return-equipment`. Each pack's `items` table defines the full acquire/consume lifecycle; a stage's `interactionItemMassTonnes` describes its interaction and does not reset existing reservations. The custody register and seal scans are data-only. Kit return removes it once; capacity never expands by removing the player's ordinary machinery. Marked mission items cannot be sold, stored, discarded or duplicated. If escape-pod use loses a physical item, its contact offers a replacement with the old instance invalidated; progress that genuinely requires the item waits for its reacquisition.

The Borrowed Voice reserves one tonne for the independent verifier from `collect-verifier` through `audit-access`. Renn retains it at Noserin if the player lacks capacity. Both operation variants require its custody. Return it at Aiven with the signed access record in one confirmed transaction; the subsequent beacon rekeying uses a zero-mass authorisation token from the audit. Never treat a similarly named commodity as the verifier. Witness statements, access records and the final clue are zero-mass journal evidence.

## Choices, combat and recovery

Choices change evidence disposition, local gossip and the specified signal protocol. They reconverge at the next objective and pay the advertised base fee. If the player closes a choice screen, no default option is selected. The Choir's emitter can be shut down through certificate disclosure or destruction of the specifically marked unmanned transmitter; neither path grants a combat kill for a non-ship object. Generic enemy deaths never stand in for mission evidence.

The Borrowed Voice's `choose-operation` stores one stable `choiceID`: `open-revocation` or `quiet-decoy`. Keep the display labels separate from these identities. At `intercept-orders`, resolve `branchStage` and activate exactly its matching `branchVariants` entry. That variant overrides the summary objective, event, targets and dialog. The summary's `countermeasure-proof` is a logical completion marker, not a physical target that can bypass the variant. Require both distinct targets from the selected variant; reject unselected evidence, mixed half-completions and a missing choice. The public route obtains revocation and frozen-audit acknowledgements. The quiet route arms an empty beacon and retrieves a passive receiver's signed handshake; only then does rescue control revoke the key. Do not activate a real casualty as bait. Both converge at `audit-access`, use the same item and final receipts, and publish only the selected gossip and `dialogByChoice` text. Observer destruction alone never completes either route.

Neris Sol speaks through a private station terminal linked to the maintenance refuge at Noserin. This is a confirmed mission contact, not a requirement that the witness be physically aboard the station before extraction. The marked Harrier carries Sol to protected arrival. If its hull is lost, persist Sol's unique emergency capsule and station rescue-tug recovery, then offer another extraction from the refuge. The tug's arrival is not a successful escort receipt. Recreating a culled ship preserves the same instance; a replacement hull after rescue uses a new instance and invalidates the old one. Never resurrect a dead witness or replace escort evidence with a generic Harrier arrival.

Mission escorts and contacts use unique identities and can be reacquired after a load. An escort's destruction returns its stage to the briefing with a new launch, no fee and no completed arrival receipt. Missing/culling entities are re-created from saved mission state at the next safe spawn opportunity. Repairs or partial scans already confirmed remain confirmed. Save mid-objective, during transfer confirmation, after choice, after escort death and immediately before/after payment must all recover consistently.

Do not reset unrelated legal status, award artificial kill points, grant global faction immunity or unlock ship blueprints without the independently approved ship-discovery/fabrication rules. Campaign combat still observes the player's real legal consequences. The resonance-filter reward is a passive mission signal identification upgrade, not another energy unit. If its fitting is temporarily incompatible, retain an unclaimed equipment receipt and offer it later without repaying credits.

## Rewards and current saves

Each pack owns one final payment receipt. The completion flag, money transfer and equipment entitlement are one actor transaction. Re-entering the station, selecting the contact again or replaying a save event cannot repeat it. The two evidence/protocol choices do not create separate reward receipts.

Each successful terminal completion also commits the pack's distinct permanent clue for [The Unwritten Route](../finale/ENGINE-CONTRACT.md). The clue has zero cargo mass and survives ship loss, trade and loading. All successful story branches qualify. A pending optional fitting does not delay it. The completion transaction commits payment and clue together. Replaying it after loading changes neither. After the complete required collection, PLUGH's AI reveals the ordered trail to Medusa; its defeat and a subsequent PLUGH reconstruction unlock paid fabrication. Generic mission completion and ordinary blueprint ownership do not unlock Medusa directly.

All 39 campaigns use only their current mission identities and the current save and pack formats. Every new commander starts with zero campaign progress, items, final payments and clues. There are no retired-story restart choices, source-campaign aliases, imported completions or converted rewards.

Persist current mission stages, confirmed target evidence, selected branches, item custody and reward/clue receipts. Normal saving, loading and automatic restoration of the last game remain required. Every commander collects the same 64-clue base set before PLUGH decoding. The Borrowed Voice supplies one of those 64 clues on either successful operation.

## Acceptance before playability claims

Translate to the supported runtime schema and verify all needed events/actions. Exercise each branch and every cargo checkpoint, escort destruction/retry, scan duplicate, target removal, mission-item loss, capacity refusal, dialog cancellation, save/reload and final reward replay. Run the repository's required CI gates once implementation is authorised. The private validation only proves design-data parsing, references, stage graph structure and 6 LY route reachability; it does not claim these gameplay hooks already exist.

## Orbital disaster and warning tour

[The Shattered Wake contract](SHATTERED-WAKE-CONTRACT.md) adds the authoritative rock-collision policy, conserved breakup, real station loss, active-simulation incident clock, registered evacuation manifest and outcome-dependent settlement. Its `hazard_encounter_resolved` event requires the actual registered encounter and committed collision ledger; a generic ship death, culling or timer callback cannot substitute.

The optional neighbouring-system warning tour requires the signed watcher packet and confirmation at the correct emergency contact. Persist each local offer and once-only dispatch, actual ship identities, travel, verified arrival and loss. Only arrived living ships contribute physical deflection, interception or evacuation. It is not a static bonus granted for visiting a menu.

All station outcomes continue to relief and inquiry at safe ports. Commit the base fee, exactly one outcome bonus and the permanent clue only at that completed terminal. Station loss alone awards none. Single-ship weapons cannot breach station shields; physical accumulated rock impacts can.

## Resource-AI conflict

[The Tithe of Worlds contract](TITHE-CONTRACT.md) defines the Tithe Network, Hearth Compact and Wayfarer Union, original resource-control objectives, finite reserve fleet, actual supply movements and two independently verified settlements.

`resource_node_secured` requires each named external control point, the correct mission instance and world, and verified local authority. `campaign_target_disabled` requires actual destruction or confirmed physical/electrical isolation of a specifically marked unmanned module. Neither event may be inferred from a generic ship death, culling, a faction name or a fleet-kill counter.

Apply the selected charter or severance at all three nodes. Preserve programmer custody, all partial proofs, launched/lost hull identities, once-only supply spending and actual civilian delivery. Require the final independent control audit before paying 9,600 CR and the permanent clue. Station shields remain protected from single-ship weapons; the external modules are distinct objectives.

## Dormant lattice investigation

[The Still Current contract](STILL-CURRENT-CONTRACT.md) defines measured reservoir conservation, ordinary physical cabin heat, real technician reception and both branch-specific settlements. Two operation stages resolve the same recorded settlement choice. A summary marker is not a target and cannot bypass required physical evidence. Return the serial programmer before the final audit; commit 8,400 CR and its clue together once.

## Cooperative freight and repeatable services

[Wayfarer Exchange](wayfarer-exchange.md) verifies the induction chain before issuing accreditation, 7,600 CR and its single completion clue. Live seed-ark and survivor reception cannot be inferred from a recorder, wreckage or a generic escort. Both capacity charters require three operator signatures and the real capacity ledger test.

The [service design](wayfarer-services.md) specifies six repeatable families with eighteen stages. Use the existing station contract board and shared arrows, Confirm and Esc. Persist each quoted offer identity until an actual stock/reservation change; reopening or loading never rerolls it. Reserve source stock and aggregate player hold across at most three active contracts atomically. Keep unique consignment custody through collection, verified work and receiver handoff. Canceling a collected load cannot recreate source stock without physical return. Recovery and convoy variants require the exact physical recorder or convoy identity; they cannot manufacture living crew or empty cargo receipts.

`service_pickup_confirmed`, `service_objective_verified` and `service_receipt_confirmed` carry current service instance, consignment, event receipt, actor and location. Validate real stage evidence before advancing; late, spoiled, lost and canceled outcomes persist honestly. Quoted quality/deadline budgets begin only after pickup, advance only during armed flight simulation, freeze on pause and restore the same remainder from current saves. Commit one quoted payment at verified final reception. Each repeatable family grants its own distinct first-success clue and never impersonates induction or another family.

The private reference models exercise conservation, custody, capacity, clock and receipt rules. They do not establish actor integration, live NPC behaviour or playable runtime support. Future implementation must test those contracts through the real game and required CI gates.
