# Arafura and inspection-craft player refits

SH166 and SH167 add two deduplicated whole hulls to the current catalogue. The [common player profiles](data/player-ship-adaptation.json) and [crew profiles](data/ship-crew-profiles.json) contain individually attributed fields. Mission NPCs retain their source definitions; selecting a player hull does not turn its commander into an RRS leader or police inspection authority. Apply [scope v4](implementation-scope.md), [crew/passenger rules](crew-and-passenger-specifications.md) and the [docked shipyard contract](player-shipyard-design.md).

## Sources and identity

SH166 is the Arafura Rescue Boat from P30 Rescue Stations 1.5.4, archive SHA256 `c3d6ba5b46e7d09865f57ec96d6741c4b53477cbdf641f9aaf44e601f3dea70c`. Its six general, mission, damaged, independent and player definitions share `rrsfl_arafura.dat`; they are configurations of one hull. The [source mechanics](data/rescue-family1-mechanics.json) retain their individual dictionaries. [Additional model provenance](data/rescue-model-source.json) hashes the recovered model files. The [author ship page](https://wiki.alioth.net/index.php/Arafura_Rescue_Boat) supplies an explicit maximum of 25 rescue passengers, but no crew number. That historical rescue interior is distinct from the second-hand player configuration with tools removed. Its published 92 by 60 by 123 metre dimensions differ from the selected 1.5.4 mesh envelope; preserve the discrepancy rather than stretching the mesh to match an older page.

SH167 is the GC Inspection Team craft from P46 Vector 1.7.2, definition `vector_inspection`, model `vector_inspection.dat`. [Shared Vector mechanics](data/vector-services-mechanics.json) retain the dictionary, AI and measured base envelope; [legacy recovery provenance](data/legacy-source-recovery.json) pins the archive. Its model SHA256 differs from the Vector SE and its geometry, speed and handling differ: it is a separate hull, not an additional Vector SE paint. No native player offer, crew total or passenger maximum was established. Its player conversion is explicitly a project adaptation.

The RRS EVA pod, `rescue_missile`, is a launched pylon payload with a rescue-contact script. Its 11 by 2.81387 by 10.99488 model-unit envelope, 25 energy, speed150, thrust18 and zero weapons/missiles remain mission mechanics. Its name does not establish a human-operated craft or charter cabin. Like other missiles/payloads, it is outside the whole-hull catalogue and is not assigned an invented commander or passenger capacity. No walking/EVA gameplay is enabled by the source name.

## Selected numerical player profiles

All speeds, energy and acceleration below use the common O08-style project units, not Elite Dangerous SI conversions. Required docking computer, drive and operating quarters are intrinsic. Initial ammunition/equipment are granted once on first acquisition and then persist with ownership, condition and spent stock.

| Field | SH166 Arafura | SH167 inspection craft | Evidence and boundary |
| --- | --- | --- | --- |
| Standard usable hold | 125 tonnes | 20 tonnes | Selected source max_cargo, adopted for common player fit |
| Optional extra hold | 15 tonnes | 0 tonnes | Arafura shipyard offers EQ_CARGO_BAY; missing extra_cargo uses O08 default15, also corroborated by author page. Inspector conversion has no expansion as a labelled project choice |
| Maximum speed | 300 | 230 | Source values |
| Acceleration | 160 | 95 | Source thrust32/19 times borrowed O08 factor5 |
| Roll/pitch/yaw radians per second | 1.5 / 0.8 / 0.8 | 0.5 / 0.4 / 0.4 | Source roll/pitch; missing yaw borrows O08 pitch fallback |
| Base hull energy / regeneration per second | 512 / 3.5 | 420 / 2 | Source inputs, before fitted equipment |
| Fore/aft shield maximum | 128 / 128 | 128 / 128 | Borrowed common O08 player baseline; not native NPC shields |
| Fore/aft shield regeneration per second | 2 / 2 | 2 / 2 | Borrowed common player baseline |
| Laser facings | Forward and aft, mask3 | Forward, mask1 | Arafura shipyard mask3 supersedes author page's fore-only summary. Inspector single-facing conversion is a labelled estimate based on its observed forward weapon |
| First forward weapon | Pulse | Beam | Native player shipyard for Arafura; adopted native forward beam for inspector conversion |
| Missile capacity / first stock | 6 / 3 | 1 / 1 | Arafura player shipyard stock3 overrides inherited shipdata stock6. Inspector native zero remains zero on NPC; player one is the owner's required conversion baseline |
| Equipment capacity | 33 units | 12 units | Labelled project estimate: 8+floor(standard hold/5), minimum8 |
| Fuel / range / spool | 70 tenths / 7 light years / 15 seconds | Same | Source fuel70 plus borrowed common range/spool |
| Operating crew, including commander | 2 | 1 | Labelled size/equipment/cargo estimates; no recovered numerical native crew count |
| Initial fitted charter berths | 0 | 0 | Project fit rule; published passenger maximum does not grant free cabins |

Arafura's native player standard extras are fuel scoops, advanced navigational array, advanced compass, missile-target scanner, heat shield and docking computer. The five non-intrinsic modules consume five common equipment units. The navigational array uses the selected O08 advanced-chart/navigation behaviour and an explicitly estimated one-unit common fit cost. The native player sale does not supply RRS escorts, two EVA pods, an operating medical bay or 25 fitted cabins. Inherited NPC flags for ECM/escape pods are not a substitute for the player shipyard's explicit standard equipment list.

Inspector's selected first player fit contains the required intrinsic systems, forward beam and one missile. Its source NPC ECM, scoops, escape pod and shield enhancer remain in the native dictionary and are available only through explicit compatible owned equipment in the player conversion. The NPC's selected O08 enhancer adds256 energy and multiplies regeneration by1.5, yielding676/3 after fitting; do not put those boosted NPC figures into the player base420/2 and apply the equipment again. Player shield effects use the player equipment adapter.

## Geometry and crew estimates

| Hull | Recovered base envelope X/Y/Z | Bounding-box volume | Model SHA256 |
| --- | --- | --- | --- |
| Arafura | 136.17125 / 44.82123 / 130.90198 | 798942.2903155215 cubic model units | `1c17fbcc5c1e6e24851a0b98aef3b79248cc4bbea72670f754198a8e8b2bd5c1` |
| Inspection craft | 88.2 / 54.31352 / 199.15336 | 954034.704125879 | `8f9f0a8116cce60eefb83a5bd9d693d15239658c624688118f2364926d79bca3` |

The JSON supplies exact min/max coordinates and computed volumes. These are same-scale source envelopes, not measured usable internal volume or proven docking clearance. Source model assets remain outside the repository. Rendered fidelity, collision and docking validation still require the dedicated geometry work; do not report a provisional surrogate as an exact likeness.

The labelled crew formula is `max(1,1+floor(0.5*max(0,sqrt(volumeRatio)-1)+max(equipmentCapacity/24,cargoTonnes/200)))`, using the common Cobra III source-envelope volume369874.0268262. Arafura uses ratio2.160038911547948 with cargo125/equipment33 and estimates two operating people. Inspector uses ratio2.5793503596676444 with cargo20/equipment12 and estimates one. Both reserve that many intrinsic operating quarters outside the published usable hold. These are normal operating complements, not an estimate of every optional doctor, engineer, boarding party or paying passenger a special mission might require. Extra mission personnel need separately reserved passenger accommodation unless their own explicit source adapter establishes a dedicated space.

## Passenger fit examples

Each common fitted berth consumes five tonnes and one equipment unit. Arafura with its five standard non-intrinsic modules can fit25 berths into its otherwise empty125-tonne hold, using30 of33 equipment units. It then has zero cargo tonnes left. One tonne of additional freight prevents that fit. With the source15-tonne extension actually installed, the hold is140 and the same five standard modules plus the one-unit fitted expansion leave27 equipment units for27 berths. That uses135 hold tonnes and all33 equipment units, leaving five tonnes of hold. Storing one nonessential standard module would allow28 berths and fill140 tonnes. The expansion module's one-unit cost is a labelled common-project estimate; its hold increase is an explicit fitted state, not a free assumption. The native RRS interior's25-passenger description does not establish the second-hand player's expanded28-berth layout; the latter is a labelled common-project fit calculation.

Inspector's baseline20-tonne hold permits four otherwise empty fitted berths, consuming four of12 units. This is a common-project conversion ceiling, not a recovered native passenger count. Four occupied berths plus its operating pilot are not five charter places. Any other cargo, equipment footprint, reserved mission party or incompatible life support reduces available capacity according to the common rules. Unfitted cabins give zero places on either hull.

## Shipyard, gallery and acceptance

Add both distinct hull IDs to docked selection and aligned side-by-side capability comparison. Show crew, reserved quarters, fitted/free passenger places, actual usable hold, weapon facings, pylon capacity/current stock and source/estimate details. Both previews use the same orientation, direction and plane including roll; view manipulation cannot alter simulation state. Selecting Arafura does not trigger its mission leader script or spawn free escorts; selecting inspector does not grant scan fines, police legal status or mission scanner ownership.

Propose compatible equipment transfer and persistent storage for surplus items; confirm atomically. Preserve occupied berths, mission cargo/pod custody and people. Block an insufficient destination fit rather than moving a passenger into equipment storage or deleting their mission. Back has no effect, and repeated confirmation/load/reselection cannot grant new weapons, cabins, ammo or rewards.

Gallery demonstrations must include Arafura25-passenger fit, freight refusal, unfitted-cabin refusal, inspector four-person fit/five-person refusal and occupied-cabin hull-swap refusal. A rescue escort where survivors remain aboard the rescued NPC ship requires no berths in the player's ship; a transfer aboard the player does require them. Gallery state stays isolated from the real commander. [Crew verification](data/crew-source-verification.json) checks all167 current canonical IDs,158 enabled refits,50 independent FFE source bindings and15 worked fit examples. Native implementation and renderer/docking checks remain separate from these research checks.
