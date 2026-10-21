# Station handoffs for former planetside stages

Owner instruction, 13 October 2026: missions with a planetside element now use a handoff at a station. This is a project adaptation, not historical gameplay. [Active scope](implementation-scope.md) still excludes the separately removed Frontier/First Encounters and Elite Dangerous Operations catalogues. All research permissions remain in force.

## Required mapping

For each retained mixed mission, record its canonical/profile ID, original ground entry/exit states and source, replacement handoff state, galaxy/system/station binding, carried items/passengers/equipment, requirements, choices, success/failure effects, deadline behaviour and reward identifiers. Preserve the surrounding recovered space encounters and branch outcomes. Do not simulate walking, atmospheric flight, surface landing, SRV use, ground combat or ground puzzles.

Use the original orbital station when established. If the original endpoint was a surface site, bind the handoff to that system's main orbital station; this fallback is an explicit project choice. If the system has no dockable orbital station, create a project mission rendezvous station in that system rather than silently relocating the objective. Use the existing game's standard station/docking profile, with a persistent mission-specific identity. Show the destination before acceptance. This does not claim an original station existed.

The handoff replaces the removed operation's successful exit, subject to its established mission prerequisites and the required items being present. Keep any established refusal, abandonment or overarching deadline failure that is meaningful from the ship. Ground combat deaths, puzzle failures and surface-only timers are reference-only. Do not invent a ground success roll. An original branch selecting different outcomes becomes an explicit station dialogue choice when it affects later space stages; record each choice and its effects. Unknown branch inventories still require research.

## Transaction and persistence

Docking makes the handoff available; it does not silently accept a new obligation or discard equipment. Show required transfers, rewards and the next destination, then provide Confirm and Back. Back has no mission, inventory or credit effect. Recheck station identity, mission stage, deadlines, cargo/passenger custody, equipment identities and capacity on confirmation.

Commit the state transition, item transfer, reward/payment and completion ID atomically in GameRuntime. AppKit only presents state and submits the choice. One completion ID covers every reward and quest-item grant for that handoff; revisiting, reloading or changing hull cannot duplicate them. Consumption transfers an existing item's custody rather than creating a copy. A handoff with insufficient capacity remains pending with a clear explanation. Personal equipment that does not fit goes into the commander's persistent surplus storage; mandatory mission cargo/passengers cannot be hidden there to bypass capacity checks.

Preserve the original overall deadline and clock domain when known. Remove a timer belonging solely to the deleted ground stage. Handoff confirmation itself adds zero game seconds unless the recovered stage specifies service time; retain that service time and label its origin. Missing deadline/reward numbers follow the estimate policy and must be filled in the individual profile, not guessed by the UI.

Migrate an older save already inside a removed ground sequence to the corresponding pending station handoff, preserving completed reward/item IDs and the original branch already chosen. Present the next required orbital destination. Do not award the removed operation's result until confirmation and prerequisite checks pass. Completed saves remain completed.

## Established mapping and acceptance

P01 Black Mesa maps original adventure entry stage 53 and exit 54 to the [space-station missile-supply transaction](implementation-scope.md#p01-flight-only-adaptation). Angeriri's stage 55 briefing and Balrog space encounter remain. Preserve personal missiles, grant only capacity-bounded quest Gravitons once, and remove only quest rounds on cleanup.

For each additional mapping, verify the correct and wrong station, arrival before/at/after deadline, missing/duplicate quest items, insufficient hold/berths/pylons, Back, double confirmation, reload before/after commit, hull switching and migration from every original ground state. The generic handoff contract is ready for implementation; it does not establish unidentified mission graphs or replace their individual mapping records.
