# Docked shipyard and ship comparison design

This retains the owner's shipyard specification requested on13October2026. The inspected checkout now has authoritative ship TOMLs, docked showroom/comparison and native purchase/flight/trade quotation; the [actual ship format](../SHIP-FILES.md) and runtime code are the maintained authority. The complete compatible-equipment/persistent-surplus-storage/crew/cabin contract below remains required and is not proved implemented by those existing features. Historical mission/NPC/source common profiles remain distinct from native calibrated game values.

## Entering the shipyard

Add a **Shipyard** option to the docked services screen. It opens the ship browser without launching the ship or changing the current loadout. The initial selection is the current ship. Leaving the browser without confirming keeps the current ship, cargo, equipment and saved state unchanged.

The future ship-switching phase should allow the player to choose any enabled playable refit with a model and capability profile. The catalogue distinguishes spacecraft from stations and components. Research availability, ownership, source historical prices and native purchase rules are separate. Preserve the actual reviewed native TOML prices and explicit exchange/trade-in quote, revalidate before confirmation and make any sale/exchange clear. An owned inactive-hull feature must preserve its own ownership and unique equipment receipts; it must not be inferred from ordinary quoted exchange. Show an unavailable hull's reason if it cannot yet be selected.

## Ship browser

Use a searchable ship list alongside a large 3D preview and a readable capability panel. Show ship name, role, standard cargo, usable cargo with the proposed equipment, speed, turning, hull/energy, shields and recharge, weapon mounts, installed lasers, missile capacity and fitted count, fuel/hyperspace range, and relevant equipment compatibility. Show actual equipment names and useful numerical values rather than a single unexplained combat score.

Default to the project's playable profile. Label estimated or borrowed values clearly, with a short explanation available on demand. Historical edition details belong in an expandable source/profile section; raw opcode numbers and resource keys do not belong in the main player interface. Preserve the distinction between standard, maximum supported and currently fitted values.

Controls: **Use this ship**, **Compare**, **Stored equipment** and **Back**. Use this ship first opens the transfer preview described below. Selecting a row only changes the preview.

## Full 3D inspection

Dragging the ship uses an unrestricted virtual trackball, allowing a full 360-degree turn in any plane. Supply horizontal, vertical and roll controls for keyboard and pointer users, plus zoom, optional continuous spin and **Reset view**. Avoid pitch clamps that prevent looking underneath or completing a vertical turn. Rendering must show the actual selected hull and fitted visible components where supported.

Normalize each model's forward/up alignment before applying the inspection orientation. Store orientation as a normalized quaternion to avoid gimbal lock; do not expose that implementation detail in the UI. Fit the model to the preview without changing its physical dimensions or cargo estimate. The preview must not advance gameplay time, fire weapons, consume fuel or alter mission state.

## Side-by-side comparison

Compare opens two equal columns: the current ship on the left and the selected alternative on the right. Either selection can then be changed. Each column has a 3D preview, ship name and the same capability rows aligned horizontally. Offer a **Differences only** filter and the three useful configurations: **Standard**, **With my equipment** and **Maximum supported**.

**Rotation is always linked in this comparison view.** Dragging either preview applies one shared orientation to both ships. Horizontal, vertical and roll controls, continuous spin and Reset view also update both. Both craft rotate in the same direction and plane, through complete 360-degree turns, with no independent orientation state. Apply the shared orientation after each model's forward/up correction, so a differently authored model does not appear to rotate about a different plane. Different ship sizes must not change rotation speed.

Use consistent framing and lighting. Fit each ship for a readable default view, and offer **Actual relative size** using one shared world scale when dimensions have a compatible basis. Do not imply a measured size comparison between unrelated raw model-unit systems. Zoom affects inspection only; it does not change the capability values or shared orientation.

| Comparison group | Aligned rows |
| --- | --- |
| Cargo and fit | Standard hold, maximum hold, equipment space used, usable hold after transfer, cargo currently aboard. |
| Flight | Maximum speed, acceleration, roll/pitch/yaw, fuel and hyperspace range, docking compatibility. |
| Defence | Hull/energy maximum, fore/aft shields, shield recharge, energy recharge, ECM and other defensive equipment. |
| Weapons | Mount positions/types, proposed lasers per mount, damage/range/energy/heat, missile capacity, missiles aboard and compatible missile types. |
| Transfer | Items fitted, items going into storage, stored items that could be reused, any cargo/passenger/mission restriction. |
| Provenance | Source, derived, borrowed or estimated indicator per value; concise explanation on demand. |

Compare the same units and loadout state. Do not rank a raw classic velocity parameter against an Oolite speed or compare NPC energy with a player shield pool. Show a dash with an explanation for an unresolved metric rather than zero. Highlight gains/losses with text or symbols as well as colour. Larger is not automatically better for turning radius, heat, energy consumption or cost.

## Equipment transfer preview

Before committing, show two explicit lists: **Fitted to the new ship** and **Stored for later**. Each stored item has a reason, such as no compatible mount, insufficient space, duplicate system or insufficient missile capacity. Show the resulting cargo space and final weapon/missile layout. All quantities, conditions, modifications and unique item identities remain visible and intact.

Build a deterministic proposal from the current equipment. Preserve mounting position where compatible, then use other compatible empty mounts. Reserve mandatory systems first; fit the current forward weapon when supported, otherwise use the playable refit's baseline forward laser and store the incompatible weapon. When several items compete for a slot, prefer the current mounted item and let the player change the proposal. Never discard an item or silently sell, repair, downgrade or convert it.

Missile capacity and ammunition are separate. New playable refits support at least one missile and receive the requested initial minimum loadout. Keep ammunition expenditure when returning to an already owned hull; switching repeatedly must not refill spent missiles or create duplicate equipment. Built-in baseline systems are hull capabilities, not free saleable inventory generated on every visit. Transfer owned upgrades as owned instances and record any hull-bound system explicitly.

Storage is persistent commander equipment storage, available from docked shipyards for this development phase, with no expiry, automatic sale or arbitrary loss. Keep stored lasers, missiles and other equipment for reuse. Provide **Fit compatible stored equipment** and individual fit/remove actions, with an updated preview before applying changes. Remember the last loadout used on each hull as a preference, but only reinstall items that the commander still owns; a remembered layout is not a second copy of its equipment.

The user requested automatic storage for equipment. Cargo, passengers and mission payloads require their own fit check. If they cannot legally fit, keep the transfer preview open and explain the blocking quantity; do not silently warehouse a passenger, discard mission cargo or mark a delivery complete. Existing source-specific ship-change restrictions and cargo/equipment-space rules must be represented in the selected mission/project profile. A later cargo-storage feature can be specified separately.

## Confirming and saving

**Confirm ship change** applies the hull, transferred loadout and storage changes as one transaction. Validate fit and storage ownership again immediately before committing. Persist the result atomically, then return to the docked shipyard with the selected ship marked current. A failed validation or save leaves the old hull, inventory and storage intact; Cancel makes no change.

Retain commander identity, credits, rank/reputation, legal status, missions, unique cargo/passenger identities and source-profile flags. Retain the former hull as an owned inactive ship if ownership is enabled; never leave transferred items simultaneously fitted to it. Persist per-hull condition, current ammunition, equipped item IDs, storage item IDs and last-loadout preferences. Save reload must reconstruct the same allocation without rerunning starter-equipment grants or mission rewards.

GameRuntime owns authoritative ship, inventory, mission and storage state under Swift 6 actor isolation. AppKit remains on the main actor. The preview renderer consumes snapshots and owns temporary view orientation; it must not mutate simulation state. Share the comparison orientation between the two previews. On confirmation, send one validated transfer command to GameRuntime and refresh the UI from its resulting snapshot.

## Acceptance scenarios

1. Shipyard is available while docked; selecting or comparing hulls does not launch or mutate the commander. Back/Cancel preserves the starting state.
2. A single preview turns fully in horizontal, vertical and roll planes, including repeated turns and views from below, without clipping or orientation jumps.
3. In comparison, dragging either preview and every rotation control gives both ships the same direction and plane. Test different model alignments, sizes, reset and continuous spin; both use the same shared orientation throughout.
4. Capability rows align, units/loadout modes match, estimated values are labelled, and Differences only hides equal rows without losing ship identity. Compare a native player hull with a refitted NPC hull.
5. Switching from a four-laser/four-missile ship to a one-laser/one-missile craft transfers compatible gear and stores every surplus item exactly once. Switching back can refit those same items.
6. Modified or damaged equipment retains its identity, condition and modifications through transfer, storage, reuse and save/reload. Neither a remembered loadout nor the baseline creates a duplicate item.
7. A known zero-cargo hull remains zero unless its explicit project refit changes that value. Equipment-space reservations, cargo, passenger cabins and missile pylons use their respective constraints.
8. Oversized ordinary cargo, passengers or protected mission payloads prevent confirmation with a clear explanation. No mission advances merely because a new hull is selected.
9. Partial failure during validation or saving preserves the entire starting transaction. Repeating confirmation or loading the save does not repeat starter grants, payments or mission rewards.
10. A capital/alien refit receives the requested baseline, but its docking computer does not make its physical hull fit an undersized station aperture. Display docking requirements and keep unsafe launch/dock paths unavailable until supported.

## Final implementation handoff

When the research is ready, send the other session at codex://threads/01a131fd-24b4-79a1-aff2-a2c1618d2698 the mission specifications, ship datasets, estimate rules, this design and the remaining evidence limits. Explicitly include the linked three-axis comparison rotation and persistent surplus-equipment storage requirements. A progress message is not the final implementation-ready handoff. Completion must not be inferred from the presence of provisional estimates alone.

## Crew and passenger fit follow-up

Apply the [crew/passenger specification](crew-and-passenger-specifications.md) and [per-hull allocations](data/ship-crew-profiles.json). Show required crew, reserved crew quarters, fitted/occupied/free passenger berths and usable hold after cabins in both capability panels and linked comparisons. Required operating crew and optional flight seats do not become charter passenger berths. Each common fitted berth reserves 5 tonnes and 1 equipment unit. Block insufficient passenger transfers before confirmation; preserve people, mission reservations and owned cabin modules across reload/Back. Empty compatible surplus cabin modules go to equipment storage; occupied cabins require real accommodation on the destination hull. No new hiring/wage flow is required for the abstract assigned operating complement.
