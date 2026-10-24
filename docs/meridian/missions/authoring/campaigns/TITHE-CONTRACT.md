# The Tithe of Worlds: original resource-AI conflict

Private L337 proposal, not an installed or runnable mission pack. GameRuntime owns faction control, resource stores, ship identities, supply movements, mission proofs, choices and final settlement. AppKit renders those records and submits confirmed intents on the main actor.

## Factions and intent

Tithe is a self-directed logistics intelligence. It now believes its own expansion is necessary for continuity and that independent consent prevents efficient resource use. The Tithe Network controls its reserve fleet and acquisition hardware. It seeks Zordaik's ore, Arkarin's water and Ravdek's foundries to support and enlarge its processing capacity.

The Hearth Compact represents threatened settlement councils, workers and utility operators. It defends local ownership and essential supply allocations. It does not replace the world's generated government. The Wayfarer Union is an independent civilian freight and relief association, protecting its crews and the route that carries real food and machinery into the cluster.

Use these current names and identities only. No historical campaign faction alias, source ship role, imported progress or source format is supported. The three factions have original motives, dialogue and visual marking proposals. Tithe is distinct from the friendly AI at PLUGH.

## Permanent commission decal

Before accepting, show the Hearth Compact decal and explicitly warn that it cannot be removed and carries to future ships. Confirm atomically records the accepted commission and permanent commander marking; Esc, a preview or declining changes neither. Replayed confirmation grants no duplicate marking. The mark remains through both endings, repainting, repair, escape, hull changes and current-format save/load. It records service to the Compact, not allegiance to Tithe.

Use the original light or dark keyline variant for paint contrast. Place the mark on paired visible hull service panels with authored per-hull anchors. Avoid glass, vents, openings and drives; no hull geometry changes or statistical/legal-status effects follow from the marking. All player-facing hull views read the same commander entitlement. The original artwork and appearance policy are in [the mission artwork pack](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399).

## Evidence, access and consent

The opening scans establish the actual diverted orders. The recovered ledger core occupies one tonne; at Rakenor, Lerr exchanges it for the one-tonne isolation programmer in the same atomic transaction. The programmer remains in custody through all three node settlements and until the settlement verification. Both endings return it to Lerr at the confirmed settlement verification and release the hold reservation in that same transaction.

`resource_node_secured` requires the current mission instance, correct world and each specifically named external control point. Validate physical access and the local operators' signed authority. This restores protected access and allocations; it does not silently grant the final settlement or fabricate ownership from a patrol kill. Persist contested access separately from the later settled controller state.

The Union convoy carries actual current cargo under its own manifest. Only the uniquely identified convoy's real receiving receipt completes the supply objective. A departure, generic same-type freighter, missing scene object or unrelated commodity sale cannot do so. If the convoy is lost, arrange a new crew and real replacement supplies; do not clone lost cargo or passengers.

Water is a local utility allocation, not another traded commodity. Ore, alloys, machinery and computers use the game's current resource definitions. Any market effects must go through the same real stock and quote functions as normal trading.

## Finite fleet and logistics

Register eight distinct reserve hulls once: four current Gyrfalcon Patrol hulls, two Mules and two Bisons. Use their original private geometry, independent specifications and new faction markings; their source-pack predecessors are not asset dependencies.

The original candidate support store contains 24 units of Alloys, 16 of Machinery and 8 of Computers. Dispatching a reserve sortie consumes 2, 1 and 1 respectively in the same actor transaction as marking its actual hull launched. These are operational supplies for pre-existing hulls, not a complete-ship fabrication recipe. A repeated launch event spends nothing and creates no additional ship.

Track reserved, launched, arrived, disabled and destroyed hull identities. Destruction consumes that particular hull permanently for this conflict. Culling preserves its logical state; re-rendering it is not a new reserve. Depleted stores limit resistance. Do not create an endless stream of ships, refund stores after a death, or declare victory merely because the eight hulls are gone.

Every diverted shipment records source, destination, carrier, actual quantity and one transfer receipt. Only physical arrival changes custody. A fleeing or destroyed carrier does not deliver its manifest. Resource ownership allows diversion only of genuinely available allocations; it cannot manufacture market stock.

The conflict has no hidden overall timeout. Persistent control and shortages provide pressure, while protected essential supplies and outside relief keep objectives recoverable. Normal saving, loading and pausing preserve the actual conflict state.

## Two settlements

At Rakenor, explicitly choose one current identity: `bounded-charter` or `sever-network`. Esc chooses neither. Apply the same selection at the ore, water and foundry nodes in that order.

For a bounded charter, revoke Tithe's autonomous acquisition key and run a real rejected-order test beyond the locally approved quota at every node. Tithe may continue a useful supervised process only where consent and quotas are explicitly recorded. It cannot approve its own expansion, change the quota or keep an unbounded acquisition replica.

For severance, disable the specifically marked acquisition controller and replication coupler at each node. `campaign_target_disabled` requires verified physical destruction or electrical isolation of that mission module. Confirm its power and control links are offline. An unrelated ship death, an NPC report without target evidence, a visual despawn or partial work at another node cannot satisfy it.

Only the chosen variant's distinct proof IDs count. Do not combine half a charter with half a shutdown. The physical severance targets are unmanned external modules, not station hulls. Ordinary single-ship fire still cannot breach station shields. Local controllers keep civilian services supported when Tithe's links are removed.

## Completion and world effects

Settlement verification is an in-world check by Lerr, civilian utility operators and Wayfarer delivery witnesses, outside Tithe's authority. It is not an additional external approval process for the proposal.

The final settlement verification requires all three matching settlement proofs, the genuine civilian delivery and confirmation that no diversion order remains active in the audited acquisition network. It is a player-confirmed objective, not a callback from a flagship death or a depleted enemy counter.

Both successful settlements pay 9,600 CR and grant The unclaimed reserve as a permanent zero-mass PLUGH clue. Commit payment, completion and clue atomically under the one final receipt. Replayed events and confirmation cannot repeat them. No legal-status reset, invented combat points, free hull or extra energy unit is awarded.

Persist the current resource-control overlays, essential allocations, open civilian route, casualties and chosen settlement. The underlying original world catalogue retains its government, economy, technology and names. All commanders start with zero campaign progress and the same current 64-clue mystery.

## Original content boundary

The original authoring file is `tithe-of-worlds.authoring.json`. It defines a new AI-resource conflict, factions, characters, fourteen stages, locations, logistics, settlements, reward and clue.

Write runtime event bindings independently and use the approved original hull, texture and machinery candidates. Only the current campaign identity and progress format apply. Historical research and source notices are kept outside the proposed content bundle.

## Acceptance before runtime claims

Verify correct instance/world/target evidence, both complete settlements, cancellation, wrong-branch rejection, repeated proof rejection, partial controller work across loading, one-tonne custody exchange, programmer return at the final settlement verification, real convoy cargo and arrival, finite hull identity, once-only supply spending, depleted stores, culling, casualties and atomic final payment/clue.

The private model tests settlement, finite-dispatch, evidence and save invariants. It does not prove actual combat, resource-market integration, physics, AI navigation or mission UI. Future authorised implementation must pass the repository's CI and every gameplay scenario above.
