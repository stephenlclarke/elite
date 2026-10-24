# The Shattered Wake: original hazard and station contract

Private L337 proposal; this is a new story and design, not an installed mission pack. All simulation, collision provenance, damage, entity ownership, mission evidence, rescue manifests, timers and rewards belong to GameRuntime actor isolation. AppKit displays the current state and submits confirmed intents on the main actor.

## Station protection

An ordinary single ship cannot overcome a station's shields with lasers, missiles or other carried weapons. Such fire may produce shield effects and normal legal consequences, but cannot reduce station structural integrity or count as a kinetic asteroid impact. Repeated firing, ship ramming, a weapon labelled as debris, and a scripted generic damage call must not bypass this rule.

Physical rocks are a separate hazard. The authoritative collision system identifies an actual asteroid or fragment, its mass, relative velocity and station intersection. Its independently balanced impact-energy load draws from a finite, recharging reserve. Unabsorbed load damages the station structure. Several heavy impacts, or a large body followed by enough fragments, can deplete the reserve and destroy the station. A single ordinary large body in this mission stays within a full station shield budget; the train makes the incident dangerous.

The private reference uses 100 shield units, 100 structural units and one shield unit of recovery per active simulation second. These are original normalised candidate budgets, not imported ship energy values. Runtime impact energy, station size and available weapons require playtesting. Do not replace the mission with a giant ship-shaped target, an artificial damage immunity counter or a special weapon-triggered station explosion.

## Preparation and clock

The commission begins at Loalaila in Galaxy 6. Its threatened station, Spindle Anchorage, is at Aermiori, 2.61 LY away. The mission supplies an original one-tonne coupler and uses normal equipment. Complete the survey, stop the mass driver, choose a defence and install its three nodes before the timed encounter.

The final deployment confirmation previews the full operation and starts a 900-second active-simulation passage. Cancelling starts nothing. Show the first impact estimate, following bands, time remaining, incoming load, shield reserve, structural integrity and evacuation status. Do not hide a clock behind the acceptance screen.

Once armed, closing a radio dialog, docking or leaving the system does not restart or freeze the hazard. Explicit game pause, the app's normal background pause and system sleep freeze simulation time. Saving and loading restore the same elapsed time, trajectories, mitigations, collision receipts and rescue accounting. No offline catch-up or freshly regenerated favourable wave is applied.

## Deflection and fragmentation

Tug deflection moves marked heavy bodies onto predicted miss paths while leaving most gravel. A fragment screen intercepts a finite gravel load while leaving heavy bodies. Both choices need three verified node actions, the coupler and one final readiness confirmation. Installing the last node, consuming the coupler and arming the incident are atomic.

Create a source-free trajectory recipe for the primary body, six secondary bodies and eighty fragments. Use an original deterministic seed and save the actual recipe at arming. Render both individual nearby fragments and bounded far-field groups from the same collision data; drawing fewer objects cannot change which masses arrive.

Weapons can split a rock without removing its mass or momentum. Child masses, velocities and the kinetic-energy budget must match the physical breakup; invalidate the parent before registering children. Each physical collider can impact once. A parent collision and its children cannot both be charged at their full intact mass. Mark unknown or merely culled objects as unresolved, not intercepted.

Inside 35 km, warn that breakup can leave the cloud on its station-bound course. Beyond that distance, show predicted miss paths after the intervention; distance alone does not grant success. A smaller fragment still on course remains a threat. NPC interceptions and tug actions use the same evidence and trajectory rules as the player's actions.

## Damage, loss and rescue

Only the registered anchorage is in the strike corridor. Shelter Dock lies outside it; Loalaila is the separate relief and inquiry destination. The global station rule can allow other genuine asteroid disasters, but this mission never invents a collision at an unrelated port.

At arming, register the full station population eligible for evacuation, including those not yet aboard a launch. At a clearly announced shield threshold, station control launches available craft before structural collapse. Every registered person has one current state: aboard a particular hull, in a particular capsule, rescued aboard a tender, safe at Shelter Dock or lost. A hull despawn is neither a rescue nor a passenger death. No save reload, replacement hull or repeated arrival can duplicate passengers or resurrect casualties.

## Warning neighbouring systems

After the three watcher scans, the player receives a zero-mass signed warning packet. Offer an optional warning tour in the mission log with plotted routes to Iraeth, Reilieli and Siamaeth. Iraeth and Reilieli require intermediate jumps at a 6 LY range; show the actual routes rather than implying all three are one jump from Aermiori. Any subset and any order are valid. The core emergency remains playable without these visits.

Dock at each system's main station and choose its emergency contact. Show the actual available offer and travel estimate before confirming: Iraeth's mining cooperative can release up to two tugs, Reilieli's patrol up to three interceptors, and Siamaeth's relief service up to two evacuation haulers. Availability comes from the local reserve recorded for this incident. A busy reserve may offer fewer ships or decline; a confirmed response is fixed and persisted. A rumour, an unconfirmed dialog or a repeated visit cannot dispatch ships.

Commit one dispatch identity and reserve the actual offered ships once. They must depart, travel and physically arrive at Aermiori's outer watch or Shelter Dock. Show separate warned, offered, departed, arrived and lost states, with arrival estimates. An ETA or a jump event alone cannot grant a contribution. Verify each arriving ship's identity and location; a lost ship cannot arrive later or be recreated as another free reinforcement.

Arrived tugs apply real deflection, interceptors act on fragment trajectories, and haulers transfer real passengers. Use the same mass conservation, collision and rescue ledgers as the rest of the encounter. Their presence can improve survival or evacuation, but does not automatically declare either outcome or give the player their combat kills.

The player can complete the tour during preparation before final arming. A warning trip after arming keeps the active passage clock running; compare its arrival estimate with the remaining threat window and display when help is likely to arrive too late. Reopening the map or radio does not pause the incident. No extra warning-specific keybinding, repeatable payment or separate clue is introduced.

On genuine station destruction, persist the loss, disable its services and docking, show wreckage and an exclusion marker, and update charts and gossip. Destroying the station grants no player combat kill, blueprint or ordinary bounty. Other objectives remain available at Shelter Dock and Loalaila. A destroyed relief tender can be replaced by a different crew and hull to recover still-reachable capsules and records; it does not recreate its lost passengers.

`hazard_encounter_resolved` requires the passage to end or the anchorage to be destroyed, with the registered collision ledger and station state committed. It is not a generic timer callback that automatically destroys a station. Afterwards, the unique relief tender must reach Shelter Dock, and the player must submit the manifest and complete the inquiry at Loalaila.

## Outcomes, payment and clue

Classify the outcome from final relief accounting:

| Outcome | Evidence | Total payment |
| --- | --- | --- |
| Station saved | The passage ends with positive station integrity. | 7,800 CR |
| Station evacuated | Station lost; every registered evacuee is safely accounted for at Shelter Dock. | 4,800 CR |
| Station lost | Station lost with recorded casualties or missing evacuees. | 1,800 CR |

Every row also requires the subsequent relief operation, manifest submission and completed inquiry. The 1,800 CR base is payment for that work, not for causing a disaster. Leaving, losing the station, shooting a rock or letting NPCs finish the defence grants neither a payout nor a clue by itself. Leaving creates no arbitrary fine, bounty or legal-status reset.

At the confirmed terminal, select exactly one bonus from the persisted outcome and commit it with the base payment, mission completion and The curve before the fall clue under one receipt. Replayed confirmation is a no-op. All completed relief/inquiry outcomes grant this same permanent zero-mass clue; the actual loss and casualties remain in the world. There is one current 64-clue collection and no older-format support.

## Original assets and authorship

The original story, contacts, dialogue, locations, stage sequence, defence choices, impact budgets, timing, rewards and clue are authored in `shattered-wake.authoring.json`. The private `procedural-rocks.py` generator creates new meshes and material colours from mathematical shapes and its own seeds. It reads no source-pack mesh, image or texture.

Use only the original authored story, procedural rock meshes, station shield policy and independently written event bindings. Historical research and source notices remain outside the proposed content bundle; none is a runtime dependency or progress alias.

## Acceptance before implementation claims

Verify single-ship fire cannot damage the station; repeated rock impacts can; authoritative collider identity and impact receipts are required; breakup conserves its budget; duplicate or parent/child impacts cannot multiply mass; and reload does not restore a destroyed station. Exercise both defence choices, cancellation before arming, active clocks while docked or away, explicit pause, off-screen collisions, all rescue manifest outcomes, relief-tender loss, all payouts, duplicate confirmation and the permanent clue.

The Python model checks damage budgets, collider identity, breakup, current-format save/load and terminal payment invariants. It does not prove the game renderer, physics, event delivery or UI is implemented. Future authorised implementation must pass the repository's required CI and every scenario above.
