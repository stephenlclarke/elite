# Targeting computers, mining and salvage

The current development source implements six cumulative targeting cores, independent Mining and Salvage modules, and separate work tools. This guide describes that source behavior; it does not claim these additions are in the published 1.4.0 app or that integrated native, save and quality acceptance has passed. Check the build identity of the app you are using.

## Installed core models

Buy equipment while docked: **3** opens Equip Ship, **Up/Down** or scrolling selects an item, and **Return** purchases it. Prices below are standard credits (CR); the shop stores tenths of a credit internally. Technology levels are the levels displayed to the player, including the shop's one-based numbering. [PLUGH](PLUGH.md) stocks supported equipment at its documented discount.

| Core model | Price (CR) | Minimum displayed TL | Capability added to preceding models | Other requirements |
| --- | ---: | ---: | --- | --- |
| Basic | 800 | 4 | Acquire front-visible ships; turn toward and track the selected ship | Cash and local availability |
| Advanced | 2,000 | 5 | Also acquire known offscreen ships | Cash and local availability |
| Docking | 4,000 | 7 | Also acquire stations and complete automatic docking | A live station and a safe approach |
| Identification | 6,000 | 9 | Live target preview, model name and Hostile/Neutral status | A selected target |
| Pirate | 10,000 | 10 | Cargo, origin and destination fields | Actual ordinary manifest and recorded route; unrecorded values remain unknown |
| Military | 12,000 | 11 | Missile/ECM information and conditional ECM-confirmed return fire; additional resource fields | Return fire needs ECM confirmation, ammunition and a forward lock |

One effective core is fitted, and its capabilities include the lower models. Ordinary shop upgrades require the recorded prerequisite purchases in the core lineage; a higher model cannot bypass unpaid prerequisites. Each purchase uses its listed price and the current cash, technology and fitting checks. Mining and Salvage are separate fittings: Military does not grant either module. Buying either module requires the Basic core entitlement and a fitted Basic-or-higher core.

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

**T** arms a missile, **M** fires it and **U** disarms, clears the weapons lock and cancels queued return fire. **Return** uses the selected flight tool while held; with Combat laser selected, it fires the laser fitted to the current view. Return fire defaults to enabled with Military; XYZZY's **B** preference can disable it and clears queued orders. **W** cycles Combat laser, Mining laser and Salvage cutter; choosing a missing tool reports the required fitting instead of substituting a combat weapon.

## Independent work modules and tools

The development shop and runtime use the following separate fittings. Prices are CR and technology levels use the shop's displayed one-based numbering. Hardware availability and fitting compatibility still apply; a module purchase does not include its tool, Fuel Scoops or the other module.

| Fitting | Price (CR) | Minimum displayed TL | Requirements and role |
| --- | ---: | ---: | --- |
| Mining Module | 2,000 | 6 | Basic entitlement and a fitted Basic-or-higher core; rock guidance and ore recovery |
| Salvage Module | 4,000 | 8 | Basic entitlement and a fitted Basic-or-higher core; eligible wreck and debris guidance |
| Mining Laser | 800 | 11 | Supported mining utility fitting or a usable forward Mining Laser; extracts rock material |
| Salvage Cutter | 2,500 | 7 | Supported cutter utility fitting; works on accessible wreck sections |
| Fuel Scoops | 525 | 6 | Compatible scoop fitting and available cargo capacity; collects physically reachable material |

**F** cycles Ships, Mining, Salvage and All filters. **Tab** or **R** selects the next eligible target in the current filter. Eligibility checks report missing cores, modules or compatible targets; single-scoop collection also requires Fuel Scoops. **W** cycles the selected tool; **Return** uses it while held. Manual tool use is separate from automatic guidance. The cutter and mining utility do not replace the four combat laser mounts.

### Rock work

Fit a core and Mining Module for guidance, plus a usable Mining Laser for extraction and Fuel Scoops for collection. Choose the Mining filter with F, then select a rock with Tab or R. Guidance approaches and establishes a hold; on the stable-hold transition it selects the appropriate tool unless you have overridden the tool choice. Selection alone does not fire. Use Return to work, keeping cargo capacity available for released ore. Salvage module ownership is not required for ore recovery.

### Wrecks and loose debris

Use the Salvage filter and module for eligible wrecks and generic debris. A hostile or disabled ship is not automatically lawful salvage: ownership, claimant and mission protection checks still apply. Section work needs a fitted cutter and an accessible work surface; loose compatible items can be collected without a cutter. Fuel Scoops, scoop aperture and cargo capacity constrain physical collection. Oversized or obstructed items remain in space rather than becoming virtual rewards.

Guidance keeps the work parent selected during section work and collection. Manual steering, Q, a new target or Spin Hold cancels guidance; incoming damage interrupts work. W records a manual tool override so stable guidance does not repeatedly replace your selection. Space remains live during work, including combat, collisions and resource use.

These source paths still need the composed build's end-to-end native acceptance: purchase and fit the prerequisites, approach and hold, use each tool, collect finite material, cancel safely, then save and reload. A source implementation or an authored test is not evidence that those checks have executed successfully.

## Saves, ship changes and presentation

The implemented core is saved as equipment. Loading normalizes duplicate older core entries to the highest tier; legacy Docking Computers become at least Docking without downgrading a higher core. Loaded commanders start docked with transient locks, ECM activity and pending return-fire orders cleared. Compatible ship exchanges preserve the core and existing paid equipment; incompatible cargo, laser mounts, fuel or missile fits block exchange with an explanation.

Normal Commander Jameson starts without a targeting computer. In the current source, XYZZY explicitly grants Military, both independent work modules, ECM and Fuel Scoops. It fits Naval lasers on supported combat mounts and separately grants the mining utility and cutter where the hull supports them. Auto Target, Auto ECM and return-fire preferences remain separate saved choices. Turning Auto Target off does not remove the core; Tab/R can still request guidance. The modules occupy independent inventory slots, so a core upgrade does not stand in for module ownership; ship exchange must pass actual fitting compatibility checks.

Equip Ship groups core choices and separate Mining/Salvage module rows under Targeting Computers. Commander Status shows the fitted core and separate Mining and Salvage summaries. **K** or **Command-K** opens contextual help, including F, W and Return. Compact/full-screen readability and agreement with the actual shop prerequisites remain part of integrated native acceptance.

## Implementation references

Core behavior and prices: [TargetingComputer.swift](../Sources/EliteCore/TargetingComputer.swift), [AutoTargetControl.swift](../Sources/EliteCore/AutoTargetControl.swift), [TargetPanel.swift](../Sources/EliteCore/TargetPanel.swift), [RetaliationControl.swift](../Sources/EliteCore/RetaliationControl.swift), [ECMControl.swift](../Sources/EliteCore/ECMControl.swift), [Game.swift](../Sources/EliteCore/Game.swift), [Plugh.swift](../Sources/EliteCore/Plugh.swift), [ShipTrade.swift](../Sources/EliteCore/ShipTrade.swift), [EquipmentDisplay.swift](../Sources/EliteCore/EquipmentDisplay.swift) and [PlayerHelp.swift](../Sources/EliteCore/PlayerHelp.swift). Work behavior is implemented in [WorkTargetRuntime.swift](../Sources/EliteCore/WorkTargetRuntime.swift), [FlightWorkGuidance.swift](../Sources/EliteCore/FlightWorkGuidance.swift), [FlightWorkTools.swift](../Sources/EliteCore/FlightWorkTools.swift) and [MiningWorkTool.swift](../Sources/EliteCore/MiningWorkTool.swift). Paid prerequisites and explicit maximum-hardware grants are defined in [EquipmentPurchaseProgression.swift](../Sources/EliteCore/EquipmentPurchaseProgression.swift) and [EquipmentMutations.swift](../Sources/EliteCore/EquipmentMutations.swift).

Target details wrap within the cockpit panel. Use I to expand it and Option-Up/Down to page long manifests and resource readings. Legacy mission ships keep their original energy-only combat rules; zero shield capacity describes that profile and does not grant them modern shields.

On the gameplay development branch, ordinary NPC readings and provenance persist through save/load and scene re-entry. Culling keeps the craft in system coordinates; actual destruction settles its finite ordinary cargo once. Docking preserves nearby traffic, while actual system travel abandons that ordinary population. Failed save writes leave the live runtime unchanged. This is development work after the published 1.4.0 release; combined native and quality acceptance remains pending.
