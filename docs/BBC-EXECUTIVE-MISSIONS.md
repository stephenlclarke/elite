# BBC Micro Executive mission profile

The starting reference is the repository research in [mission-specifications.md](research/mission-specifications.md), C01/C02, with its R1-core boundary in [coverage.md](research/coverage.md). This implementation selects BBC-EXEC, not C64, Oolite, MSX or a reconstructed campaign.

## Pinned primary evidence

The original Second Processor source is preserved by Mark Moxon in [elite-source-code-6502-second-processor](https://github.com/markmoxon/elite-source-code-6502-second-processor/tree/9080bd09c814b43c9c82571493c74bfb447aa607). The Executive variant is `_VARIANT = 2`; the mission routines used here are shared with that build.

| File | SHA-256 |
| --- | --- |
| `1-source-files/main-sources/elite-source.asm` | `66cc4bdedc1037efd82cc696aa8069ec66e80a9f7601c752a5db46294a60a0a2` |
| `1-source-files/main-sources/elite-build-options.asm` | `6261b445cd1fa7b4d344a8841463664066eec012b1dab79d38e72e1caa52f144` |

Relevant source routines are DOENTRY, BRIEF/BRIS, DEBRIEF, BRIEF2/BRIEF3/DEBRIEF2, THERE, PDESC, RUPLA/RUGAL/RUTOK, KILLSHP, FAROF, main-loop parts 2-4, GTHG, missile TACTICS and TACTICS parts 2/4/5/6. Resources are SHIP_CONSTRICTOR, SHIP_THARGOID and SHIP_THARGON. The maintained implementation is Swift; the assembly and commentary are not vendored.

## State and event rules

Galaxy numbers in this table are the player's one-based numbers. The code stores galaxies 0-7.

| TP nibble | Meaning | Transition |
| --- | --- | --- |
| 0 | Unstarted | Dock with at least 256 points in galaxy 1/2: set 1 and show Hunt briefing |
| 1 | Hunt active | Spawn one Constrictor at galaxy 2, coordinates 144/33 (Orarra), through the bounty-hunter branch |
| 3 | Target removed | Next docking anywhere: add 5,000 credits and 256 points, set 2 |
| 2 | Hunt finished | Dock in galaxy 3 with at least 1,280 points: set 6 and issue Ceerdi orders |
| 6 | Awaiting plans | Dock in galaxy 3 at 215/84 (Ceerdi): set 10 and collect encoded plans |
| 10 | Carrying plans | Dock in galaxy 3 at 63/72 (Birera): fit naval energy unit, add 256 points, set 14 |
| 14 | Both finished | No repeat rewards or mission pursuit |

DOENTRY performs one transition per docking. Receiving orders while already at Ceerdi does not also collect the plans on that same event. Clue visits are not prerequisites. No accept/refuse choice, cargo-tonnage payload, timer deadline or additional Executive campaign has been invented. An older JSON commander without mission storage starts at TP 0; an unknown nibble is rejected.

The source's two-second incoming-message wait is retained. The briefing/debrief stages are committed before the message is acknowledged, so menu navigation, saving or reopening help cannot duplicate a reward. Commander loading returns to a station without treating the load as a new docking event. Original DFS commander files are not supported.

## Source-specific combat and spawning

The Hunt clue systems are galaxy 1 indices 150/36/28; galaxy 2 indices 253/79/53/118/193 and the thirteen Errius-rumour systems 32/68/164/220/106/16/162/3/107/26/192/184/5; galaxy 3 index 101 gives the wrong-galaxy warning. Docked charts 4/5, or system-data key 6 in flight, show the relevant hint while TP bit 0 is set, including TP 3.

The Constrictor has 252 energy, speed limit 36, four missiles and no destruction bounty. Its military-laser damage is 23 shifted right twice, giving 5; pulse, beam and mining lasers inflict zero damage. It resists the energy bomb. Missile proximity is evaluated before the target's 16-in-256 ECM check, so ECM is not absolute missile immunity.

A mission spawning opportunity is scheduled once every 256 native flight updates. Carrying plans uses the source `random byte >= 200` test (56/256), independently of government. GTHG adds a Thargoid and then its companion, allocating each separately if slots remain. The Hunt uses the original government/90 and bounty-hunter/100 byte predicates, one target per bubble and the subsequent EV delay. Native station proximity and existing police presence suppress mission encounters.

The mothership has 240 energy, speed limit 39, a 50-credit bounty and six Thargon releases. Thargons have 20 energy, speed limit 30 and a 5-credit bounty. Native naval tactics recharge one unit and consider finite ordnance at or below half energy, using `random byte & 31 < remaining`; active ECM blocks launches. Drones stop attacking and lose ECM when the last mothership disappears. Naval energy replaces the standard unit, is unavailable in the shop, and uses the original recharge multiplier sequence 1/2/3.

Constrictor and Thargon vertices use numerical blueprint coordinates from the pinned source. The native renderer triangulates the rounded Thargon hull for closed panels and draws the Constrictor's underside markings when visible. Primitive hulls pass convexity and closed-edge checks. The detailed non-convex Oolite Cobra has independent welded-boundary rotation checks; title and flight silhouettes remain covered. BBC-derived blueprint material is excluded from the MIT grant because the reference repository supplies no reuse licence; see [licensing and provenance](../NOTICE.md).

## Preserved source quirks

- KILLSHP sets the Hunt completion bit on target removal, including FAROF culling. The Constrictor's boundary is any coordinate high byte greater than 224, represented here by an absolute axis coordinate of at least 57,600. Leaving via hyperspace, docking or loading resets the encounter without calling that removal path.
- Mission reward arithmetic retains the 16-bit tally and 32-bit cash wrap boundaries. C64's earlier combat-point bonus timing is not imported; Executive awards its 256-point bonus at debrief.
- Completing the Hunt in another galaxy does not immediately start Plans. Plans requires its own qualifying docking in galaxy 3. Repeated docking cannot pay either mission again.

## Fidelity boundary and validation

These are source-backed mission rules within this project's existing native simulation, not a claim of binary-level 6502 equivalence. The native random generator, frame cadence, station safe-zone model, ship steering, hit geometry, laser cadence, collision model and missile movement remain independent implementations. Not every original upstream world-spawn gate is present in the base game. Radio-message prose is independently worded and paged for this font; the full original token printer, 64-step ship-introduction animation and exact screen timing are not reproduced. Historical successful/failed original-binary outcome saves remain a separate parity task.

Tests use literal source thresholds, coordinates, reward amounts and wrapping boundaries. They exercise real docking, combat, mission removal, collection/delivery order, wrong-galaxy visits, commander persistence, repeated rewards, clue systems, spawn predicates, finite ordnance, ECM/proximity, orphan drones, energy-unit fitting, help, pause and message pages. The shared hull rotation regression includes both new ships. `make ci` runs overall coverage, thread/address sanitizers and native lifecycle leak checks.

## Requested native equipment extensions

The added XYZZY Naval Laser is grant-only and deals a prototype 64 damage, reduced to 16 by the Constrictor shield. Historical Military Laser damage remains 23/5. Capital shields, targeting tiers, automatic docking and ECM-confirmed Military retaliation are user-requested native extensions rather than original mission rules. They do not alter the saved TP stage mapping, offers, rewards, source encounter predicates or mission completion conditions.

## Mission-pack implementation

Campaign content and progression are maintained in `Sources/EliteCore/Resources/MissionPacks/` using the same validated [TOML schema](MISSION-PACKS.md) as external packs. Existing encounter/combat/custody primitives remain in Swift; legacy saved stages and unique targets retain their identities. Installing a new supported pack does not change this campaign or replay its rewards.
