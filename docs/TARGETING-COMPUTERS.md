# Targeting computers, mining and salvage

The six core models below are implemented. The independent Mining Module, Salvage Module and Salvage Cutter described later are **pending**: their version-6 design is an implementation contract, not evidence of playable features. Existing Mining Lasers and Fuel Scoops do not yet enable that specialized automation.

## Installed core models

Buy equipment while docked: **3** opens Equip Ship, **Up/Down** or scrolling selects an item, and **Return** purchases it. Prices below are standard credits (CR); the shop stores tenths of a credit internally. Technology levels are the levels displayed to the player, including the shop's one-based numbering. [PLUGH](PLUGH.md) stocks supported equipment at its documented discount.

| Core model | Price (CR) | Minimum displayed TL | Capability added to preceding models | Other requirements |
| --- | ---: | ---: | --- | --- |
| Basic | 800 | 4 | Acquire front-visible ships; turn toward and track the selected ship | Cash and local availability |
| Advanced | 2,000 | 5 | Also acquire known offscreen ships | Cash and local availability |
| Docking | 4,000 | 7 | Also acquire stations and complete automatic docking | A live station and a safe approach |
| Identification | 6,000 | 9 | Live target preview, model name and Hostile/Neutral status | A selected target |
| Pirate | 10,000 | 10 | Cargo, origin and destination fields | These fields currently report unavailable/unknown |
| Military | 12,000 | 11 | Missile/ECM information and conditional ECM-confirmed return fire; additional resource fields | Return fire needs ECM confirmation, ammunition and a forward lock |

You may buy a higher model directly; buying each intermediate model is not a prerequisite. One effective highest core is installed, and it includes the lower models' capabilities. An upgrade costs its full listed shop price. Rebuying the same model or buying a lower one is blocked. Neither Military nor any lower core alone grants the pending Mining or Salvage Module.

### Select, track and dock

In a cockpit view, **Tab** or **R** selects the next eligible target and switches to the front view. Front-visible ships come first, nearest first; Advanced and above then include offscreen ships, nearest first. Docking and above place stations after those ship groups. Equal distances use target ID order. A cycle keeps its order as ships move; changes to the available targets, fitted tier or viewport reconcile the cycle, and a complete wrap takes a fresh snapshot. Partly visible hulls count using the actual front-view renderer, even when you start from a rear or side view. Cargo, asteroids and missiles are excluded from this core cycle.

A cyan lock marker and offscreen cue identify the selected target. Ship tracking turns toward the target at your existing cruising speed; it does not fire your weapons. Selecting a station with Docking or better engages full docking guidance: safe approach waypoints, braking, entrance alignment, spin matching and physical entry through the doorway. Guidance controls speed during docking. **Q**, **P** or manual steering cancels; manual throttle also cancels station guidance. Pause, focus loss or a Spin Hold action cancels station guidance. Ordinary ship tracking can coexist with Spin Hold.

The yellow station compass works without any computer. It shows the station's bearing in your current cockpit view, including behind you and beyond scanner range. The compass and cyan selected-target marker serve different purposes.

### Read the target panel

**I** expands or collapses the upper-right panel. It defaults to expanded at viewport widths of at least 1,100 points. Below Identification, it shows only a target ID. Identification and above show a live preview of the actual target's pose without moving the flight camera.

| Information | Current disclosure |
| --- | --- |
| Identification ship model/status | Actual model and Hostile/Neutral state |
| Pirate cargo | Actual ordinary manifest, with commodity units; `Unknown` until recorded |
| Pirate origin/destination | Recorded route; generated or inferred routes are labelled; cross-galaxy destinations show their galaxy |
| Military shields, laser heat, fuel | Actual selected-craft readings, with front/rear shield banks separate; unrecorded legacy fuel remains `Unknown` |
| Military missiles | Actual remaining NPC missile count |
| Military ECM equipped/active | Actual fitting and whether that target owns the active enemy ECM field |
| Identification+ station | Entrance Ready/Aligning, rotation rate and range; ship resource fields do not apply |

### ECM and Military return fire

**E** activates a fitted E.C.M. System when undocked, with more than 10 energy and no ECM field already active. Activation spends 10 energy. The system costs **600 CR**, normally available from displayed **TL3**. Military does not include this hardware or turn on automatic ECM. Automatic ECM requires XYZZY's separate Auto ECM preference as well as fitted hardware and the normal activation checks.

With Military and return fire enabled, an incoming enemy missile identifies its actual living launching ship and establishes a weapons lock. This does not take over steering or enable Spin Hold. If your own ECM confirms destruction of that missile, the computer can launch one retaliatory missile per attacker per ECM activation. It waits for the ECM field to end and the normal one-second missile cooldown, uses ammunition unless unlimited, and requires the source still to be alive and in the forward hemisphere. An order expires after three game seconds; a missing source, ammunition or lock reports failure rather than a launch.

**T** arms a missile, **M** fires it and **U** disarms, clears the weapons lock and cancels queued return fire. **Return** fires the laser fitted to the current view while held. Return fire defaults to enabled with Military; XYZZY's **B** preference can disable it and clears queued orders. These are combat controls, not pending cutter or mining-automation bindings.

## Pending independent work modules

**Everything in this section is intended behavior, awaiting integration and verification.** No new module price, technology gate, filter shortcut or tool selection key is claimed as shipped here. The implementation must expose its actual controls and costs in Equip Ship and contextual help before this section can become a playable guide.

| Planned fitting | Requires | Intended capability |
| --- | --- | --- |
| Mining Module | Basic-or-higher core | Asteroid/rock approach, motion-matched hold, fitted Mining Laser selection and ore collection |
| Salvage Module | Basic-or-higher core | Eligible ship/wreck hold, section work and generic loose-debris collection |
| Mining Laser | A usable supported mining fitting | Extract asteroid material; separate from module ownership |
| Salvage Cutter | A separate utility fitting | Detach attached ship/wreck sections without replacing the four combat laser fittings |
| Fuel Scoops | Physical scoop/cargo compatibility and free capacity | Collect released ore/salvage and single-scoop items |

The existing Mining Laser costs **800 CR** at displayed **TL11**; Fuel Scoops cost **525 CR** at displayed **TL6**. Those are shipped equipment prices, not prices for either new module. Buying a work module must not imply a free tool, scoops or the other module. Mining-only enables asteroid work and its ore collection; Salvage-only enables wreck work and generic debris collection. A missing module must report the requirement without engaging its controller through either keyboard or pointer selection. Manual tool use remains separate from automation.

### Intended example: asteroid mining

1. Fit a core, Mining Module, usable Mining Laser and Fuel Scoops; leave cargo space for ore. Select an asteroid using the implemented mining target controls.
2. The computer approaches with actual hull clearance, matches motion and establishes a safe hold. **Only on that stable-hold transition** does it select the usable Mining Laser and announce the choice. Selection does not fire.
3. Activate the selected tool yourself. Extraction then enables fitted scoops to recover released ore through the real capture volume. The Salvage Module is not required for this ore collection. Missing or inaccessible tools report the requirement while preserving a safe hold; no combat laser is substituted.

### Intended example: a large wreck

1. Fit a core, Salvage Module, Salvage Cutter and Fuel Scoops. Check the target's Abandoned/Claimed/Occupied/Mission protected state and available cargo space. A hostile or disabled ship is not automatically lawful salvage.
2. Select the eligible wreck. It becomes the persistent primary target. The computer approaches a safe surface work position, matches drift and spin, and holds there. Excessive motion, rotating protrusions or an unreachable surface must block the approach with a reason, without teleporting the ship.
3. After a stable hold, the fitted cutter is selected once and announced. Activate it to cut; that same activation enables fitted scoops. Released fragments remain children of the wreck: collection must not replace the parent lock. Safe local corrections collect reachable debris, then resume the work position and section queue. No second scoop key or collection confirmation is needed.
4. Release the cutter to stop cutting while retaining the hold and parent lock; already reachable debris may finish collection. Depleted sections have finite rewards. When none remain, show Salvage complete and retain the selectable, physically present wreck until cancellation or an explained interruption.

### Intended example: loose debris

1. Fit a core, the matching module and Fuel Scoops. Generic cargo, loose technology, detached modules, disabled drones and empty pods use Salvage; loose ore can use Mining. Check that the item fits the scoop aperture and cargo capacity.
2. Select a single-scoop item. Selection alone starts a safe drift-aware intercept, enables scoops and collects it through the actual capture volume. No cutter, tool fire or second confirmation is needed.
3. A successful one-item recovery stops safely and reports the collected item. It is not reported as Target lost. An attached or oversized object instead needs suitable section work or an incompatibility explanation.

### Intended limits, cancellation and persistence

Manual flight input, **Q**, a new primary target or an explicit Cancel ends the work controller immediately. Automatic tool choice occurs when a new stable hold is established; it must not overwrite a later manual tool choice every frame. Incoming attack interrupts cutting and warns without silently resuming it. Space remains live: police, pirates, missiles, collisions, heat and energy still matter. Existing menu/pause time rules remain in effect.

Missing scoops, full or reserved cargo capacity, an obstructed fragment or an unsafe work position must leave material in space and explain the blockage. Capacity is checked again at transfer. Ownership and mission protection apply before cutting; unauthorized damage is an attack. Occupied rescue capsules use mission/passenger custody, never spare-equipment or commodity rewards. Empty serviceable pods can be recoverable equipment. Loss or destruction of the actual parent must be distinguished from completed recovery of a child item.

Mining and Salvage must be independently saved installed entitlements, preserved when the core upgrades and when a compatible ship exchange transfers equipment. XYZZY must grant each module explicitly, alongside its tools and scoops; Military's inherited core capabilities must never substitute for these grants. This persistence and grant behavior is pending with the modules.

## Saves, ship changes and presentation

The implemented core is saved as equipment. Loading normalizes duplicate older core entries to the highest tier; legacy Docking Computers become at least Docking without downgrading a higher core. Loaded commanders start docked with transient locks, ECM activity and pending return-fire orders cleared. Compatible ship exchanges preserve the core and existing paid equipment; incompatible cargo, laser mounts, fuel or missile fits block exchange with an explanation.

Normal Commander Jameson starts without a targeting computer. XYZZY makes Commander Clarke's maximum fit include Military, ECM and Fuel Scoops. A Mining Laser equipment entry is also retained, but the maximum refit mounts Naval lasers on every supported facing; it does not supply a usable Mining Laser mount. Its Auto Target, Auto ECM and return-fire preferences are separate saved choices. Turning Auto Target off does not remove the core; explicit Tab/R can still request manual guidance. New module grants remain pending as described above.

Equip Ship currently groups the six cores under Targeting Computers, uses the small fixed game font, indents item names and right-aligns prices/status. The pending presentation must keep that alignment and show one Targeting Computer with named core capabilities and separate Mining/Salvage module rows. Commander Status must distinguish inherited lower capabilities from separately purchased add-ons, without duplicate paid entries. Contextual help and selected shop-row descriptions must agree with runtime prerequisites and controls, remain readable at compact/full-screen sizes, and scroll to every fitting. **K** or **Command-K** opens the current contextual key guide.

## Implementation references

Core behavior and prices: [TargetingComputer.swift](../Sources/EliteCore/TargetingComputer.swift), [AutoTargetControl.swift](../Sources/EliteCore/AutoTargetControl.swift), [TargetPanel.swift](../Sources/EliteCore/TargetPanel.swift), [RetaliationControl.swift](../Sources/EliteCore/RetaliationControl.swift), [ECMControl.swift](../Sources/EliteCore/ECMControl.swift), [Game.swift](../Sources/EliteCore/Game.swift), [Plugh.swift](../Sources/EliteCore/Plugh.swift), [ShipTrade.swift](../Sources/EliteCore/ShipTrade.swift), [EquipmentDisplay.swift](../Sources/EliteCore/EquipmentDisplay.swift) and [PlayerHelp.swift](../Sources/EliteCore/PlayerHelp.swift). The pending work follows the primary checkout's `SALVAGE-GAMEPLAY-DESIGN.json`, version 6, dated 2026-10-15; it does not replace those implemented sources.

Target details wrap within the cockpit panel. Use I to expand it and Option-Up/Down to page long manifests and resource readings. Legacy mission ships keep their original energy-only combat rules; zero shield capacity describes that profile and does not grant them modern shields.

On the gameplay development branch, ordinary NPC readings and provenance persist through save/load and scene re-entry. Culling keeps the craft in system coordinates; actual destruction settles its finite ordinary cargo once. Docking preserves nearby traffic, while actual system travel abandons that ordinary population. Failed save writes leave the live runtime unchanged. This is development work after the published 1.4.0 release; combined native and quality acceptance remains pending.
