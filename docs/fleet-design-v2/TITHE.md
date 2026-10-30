# Rogue AI mission fleet - Tithe Network

Stephen clarified that blocky functional AI design refers to the rogue AI class in the missions. The exact source is C06, The Tithe of Worlds, `original-missions/tithe-of-worlds.toml`. It currently identifies SH001/SH004/SH005 and reserves four SH004, two SH001 and two SH005 vessels. Ictinia/Shikra is not automatically the rogue AI merely because older content once used an AI-related name.

## Conversion identities

| Variant | Parent lineage | Name | Use | Finite reserve | Assembly brief |
| --- | --- | --- | --- | ---: | --- |
| TN-01 | SH004 Gyrfalcon Patrol | Tithe Scout | Interception and protection of resource movements | 4 | [TOML](ai/TN-01.toml), [top-view block assembly](ai/TN-01.svg) |
| TN-02 | SH001 Mule | Tithe Utility | Resource collection/transfer | 2 | [TOML](ai/TN-02.toml), [top-view block assembly](ai/TN-02.svg) |
| TN-03 | SH005 Bison | Tithe Transport | Bulk resource logistics | 2 | [TOML](ai/TN-03.toml), [top-view block assembly](ai/TN-03.svg) |

The 171 base-hull registry remains intact. A conversion has an explicit variant identity under its parent, its own mesh/physical bounds and its own appearance/blueprint observation. A Tithe skin must never replace the ordinary Mule, Gyrfalcon or Bison throughout the universe. Actor control by the ordinary NPC AI is not sufficient: require both the Tithe faction and the conversion ID. Human Tithe contractors retain inhabited human hulls and actual human crews.

## Functional appearance

Build the conversion from rectangular armour/power/cargo modules around a straight service bus. Use orthogonal cuts and a small number of mechanically justified chamfers at access edges. Structural mass follows a task: protected power electronics, coolant trunks, sensors, processing blocks, finite magazines, docking/service clamps and accessible cargo sockets. Expose radiators where their sight/heat paths work; keep thrusters and weapon apertures clear. No canopy, windows, crew bridge, decorative wings, animal head, crest or ornamental hull sweep. A sensor is a recessed aperture or small gimballed unit, not a fake cockpit.

Use gunmetal, dark steel, restrained worn industrial panels and amber status indicators. Pipes and wiring follow service routes. Symmetry is useful for propulsion and interchangeable modules, but unused asymmetry need not be cosmetically corrected. Armour should protect valuable components, not wrap every empty volume. Keep readable connected silhouettes rather than a randomly scattered cloud of boxes. The three assembly SVGs describe original new construction; they are not traced external ships.

Each variant inherits the parent v2 functional performance, not an extra combat bonus. It has its own measured geometry and compatible aperture contract. The box coordinates are initial metre-authored module envelopes. Final attachments, drive/weapon parts, collision components and structural joints must be authored and validated by the geometry owner; the sketch is not a completed solid mesh. Do not force parent docking bounds onto a differently shaped conversion.

## Ownership, salvage and safe player conversion

The autonomous native conversion has zero human crew; disable/destruction must not create human escape pods or human kill claims. Ordinary finite cargo, magazine, fuel, power, damage and salvage rules still apply. No self-replication, infinite drones, free repairs or automatic reconstruction.

Encountering a conversion shows its wireframe; commander-attributed EMP disable and lawful physical salvage earn that variant's blueprint. The variant appears beneath its parent entry, with separate discovery location and evidence. It does not create a second base-hull completion credit. Owning a parent blueprint does not automatically grant its AI-conversion geometry, and salvaging a conversion must not falsely mark the ordinary parent as separately salvaged.

Purchased human operation requires PLUGH to remove the rogue controller and install enclosed crew/remote-vision compartments. Native AI conversions have no inhabited parent quarters; do not inherit those places as free crew accommodation. The conversion quote shows the inherited hull price plus the explicit retrofit service, 5t hold for each required crew place and two interface equipment units plus one equipment unit for each group of up to four crew places. Scout and Utility therefore consume 10t/three units each; Transport consumes 60t/five units. The retrofit's required real crew equals the parent complement and the fitted modules provide exactly those crew places, distinct from any passenger cabins. There is no externally added aesthetic cockpit; the crew use internal displays and proper life support. No rogue AI software or mission permissions transfer to the player. Refit cannot grant mission reserve resources or count as a campaign victory. Retrofit price is an explicit new design choice at 15% of the parent hull price, rounded to the nearest 1,000CR, not a claimed existing service.

## Exact mission edits

Keep the top-level C06 parent ship list for lineage. Add explicit conversion references for reserve instances: four `(SH004,TN-01)`, two `(SH001,TN-02)`, two `(SH005,TN-03)`. Their original eight stable actor identities remain conserved; never replenish them after destruction, escape or a reload. Replace the faction's visual text with this functional design language and point its three conversion portraits at newly rendered exact variant assets. Do not use ordinary base-hull artwork while claiming the AI conversion is visible.

Keep the exact resource nodes, source/destination receipts, support stores, supply delivery and both lawful endings. Expose and contain the acquisition process under consented quotas, or physically/electrically isolate the three controllers/couplers. Campaign victory still requires all three chosen settlement proofs, actual civilian supply receiving, no outstanding diversion orders and the final council report. Destroying eight ships is not a replacement victory predicate. Keep the permanent Hearth Compact commission marking and the Medusa clue.

No story branch, reward, deadline, station vulnerability, legal reset or finale entitlement changes as part of this visual/capability conversion. Frozen mission artwork remains preserved until the real revised renderer assets and their new provenance manifest are available.
