# Elite feature request log

Created: 2026-10-17T16:53:56.533995+00:00. Maintained by the Elite Orchestrator.

This is the persistent record of new user requests and decisions. A request is not complete merely because it is assigned, designed, written, or compiled. Record source, verification and release evidence separately. Keep superseded decisions visible and link the replacement rather than silently removing them. Future suggestions must receive an ID and be logged before delegation.

The complete game-completion backlog remains in the user's companion request catalogue and the repository's [delivery backlog](DELIVERY-BACKLOG.md) and [mission-engine completion ledger](MISSION-ENGINE-COMPLETION.md). This log supplements those requirements; it does not replace or reduce them.

## Requests and decisions

| ID | Date | User request or confirmed decision | Owner | Current status |
| --- | --- | --- | --- | --- |
| FR-001 | 2026-10-17 | Add an EMP Pirate Blaster that disables ships without destroying them; crew may eject; include it in XYZzy mode. | Coder 2 source; Coder 1 integration and verification | Initial implementation composed. Runtime EMP acceptance remains pending after fixture-route failures. Weapons and captive handling are amended below. |
| FR-002 | 2026-10-17 | Salvageable and mineable objects should be orange on the HUD and have an orange glow in space. | Coder 2 / Coder 1 | Shared cues composed. Actual feature and native pixel acceptance pending. Escape-pod scope expanded by FR-006. |
| FR-003 | 2026-10-17 | Hostile objects should have red space glow and red HUD markers. | Coder 2 / Coder 1 | Shared cues composed. Apply all three drawing modes. Disabled EMP hulls are the explicit exception in FR-004. Already-fired hostile missiles remain red. |
| FR-004 | 2026-10-17 | EMP also disables weapons. A hostile ship changes immediately from red to orange HUD/glow once disabled, even while crew remain aboard. | Coder 2 implementation; Coder 1 integration and verification | Source-reviewed owned commit `d80ccce778475231eb9e24f25f8a59b294e6df44` is integrated; runtime and native pixel acceptance remain pending. Supersedes the earlier design that kept the disabled ship red until everyone ejected. Block future laser fire and missile launches; preserve missiles already in flight and legal/aggression history. |
| FR-005 | 2026-10-17 | Crew who fail to eject in time are taken as slaves. User explicitly selected a 30-second escape window after EMP. | Mission Coder 1 custody design and implementation; Coder 1 integration | Confirmed requirement; design in progress, implementation not yet delivered. Preserve original people, finite illegal cargo, once-only capture/sale, save/reload and crew census. Supersedes the absolute rule that salvage must always wait until every crew member ejects. |
| FR-006 | 2026-10-17 | Escape pods can be tracked and targeted for collection as a single unit of salvage. | Mission Coder 1 rescue/targeting implementation; Coder 1 integration | Confirmed requirement; design in progress, implementation not yet delivered. Include actual targeting, approach and fuel-scoop collection, not only a manual scoop demonstration. Preserve each occupant's identity and distinguish escaped people from FR-005 captives. |
| FR-007 | 2026-10-17 | Persist every new suggestion in a log so that it cannot be lost. | Orchestrator | This persistent repository log and the delivery-backlog navigation link are recorded alongside the Orchestrator recovery copy. Future suggestions will be appended here and to the repository log. |

## Current design interpretations requiring implementation review

- FR-005 capture occurs through the actual salvage interaction after the escape window; the timer alone must not remotely transfer people to the player's hold. Repeated EMP hits must not extend the original escape deadline. These are implementation interpretations of the user's requirement, not additional user-confirmed wording.
- FR-006 uses the existing salvage-targeting module and Fuel Scoops for automatic approach/collection. The existing rescue design reserves one tonne per sealed pod while retaining the occupant as a person. The user's wording confirms one pod as one salvage unit; one-tonne accounting is the existing project design and must remain distinct from five-tonne charter cabins.
- Occupied pods remain protected against ordinary weapon/cutter damage. Collection requires actual fit, space, physical approach and a durable custody transition. Failed saving must leave the person and pod in their current post-flight state. Escaped occupants are not automatically reclassified as slaves.
- Apply drawing cues to white wireframe, coloured wireframe and shaded panels. White hull lines retain their drawing style; the separate threat/salvage cue carries red or orange.

## Delivery and coordination evidence

- Coder 1 is the sole integration, heavy validation, merge and release owner. General source work prefers Coders 1 and 2. Mission/custody work belongs to Mission Coder 1 through this Orchestrator; avoid overlapping file ownership.
- Combined candidate 2706f2996440d83d59ad0ad68dc1e836d6320192 compiled under the thread sanitizer. Its focused run started 68 methods: 46 passed, 22 failed, with 25 issue headers and no observed sanitizer signal/warning. The two original long docking paths passed. These results do not establish EMP rendering acceptance, full CI, native performance or release readiness.
- Most EMP failures stopped in fixture setup because a 2-3 light-year neighbour was incorrectly assumed. Corrected reachable routes and real midpoint fuel purchases are source-reviewed in owned commit 22b63ccff5fa2da9e85210e342cd97c281022d7b, integrated by Coder 1 as 01c266b56254ea3717887b2c94b87f4a3e1bb44c. Correction execution is pending.
- Finance's 22 methods and the complete 2,056-main-station history roundtrip passed the focused run. The full original mission catalogue and game-completion backlog remain open.
- No new public release or playable build has been verified for these requests. Do not label a request released without its exact release/build evidence.

## Update protocol

1. Append a stable FR ID, date, user wording or faithful summary, and any confirmed answer before handing new work to a worker.
2. Record implementation choices separately from confirmed user requirements. Ask only when an unresolved choice materially changes the result.
3. Record superseding requests explicitly; update owners and dependent tests/docs without deleting prior decisions.
4. Update status with exact owned commits, actual validation results and release links. Keep source-only and failed/incomplete evidence qualified.
5. Keep the repository log, this recovery copy and the broader delivery/mission backlogs consistent. A failed sync is outstanding work, not successful persistence in the repository.
