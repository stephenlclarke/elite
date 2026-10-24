# Meridian: the finished L337 game oracle

[Return to the oracle contents](README.md). This reading view is extracted from [the complete single-file oracle](FINAL-GAME-ORACLE.md); its rules are the same.

This is the complete, spoiler-rich definition of the intended finished L337 game. Its subject is the game the player experiences: its universe, decisions, physical rules, equipment, ships, stories and endings. The campaign, family and ship identifiers are stable references. The numerical tables and mission-specific rules make the description suitable for checking whether the finished game behaves as intended.

All documents, definitions, models and images in this oracle live under `docs/meridian/`. The complete mission narratives follow the gameplay review; the new L337 ship reference is the final section. [Every mission graphic](MISSION-ARTWORK.md), [structured definitions](definitions/), [art provenance](ASSET-PROVENANCE.json) and [coverage inventory](COVERAGE.json) accompany this document. The artwork and finale reveal all spoilers; the player's in-game gallery obeys discovery and mission progress.

## The game the commander plays

L337 is a native macOS space-trading, exploration and adventure game. Commander Rowan Calder begins a personal career in the original eight-galaxy universe. The player flies a real fitted ship, trades finite goods, follows rumours, accepts contracts, explores orbital spaces, escorts other craft, helps living passengers, investigates conflicting evidence and learns why apparently unrelated records contain the same inward-curving trace.

The new-game definition starts Rowan Calder at Avenor, Galaxy 1/system 007, in SH025 Peregrine Mk V, with a full fitted tank, 720 CR, no accepted campaigns and no imported clue/discovery/fabrication history. The original world authoring configuration fixes this starting ID; an older prose reference to Peregrine Mk III does not change the starting definition. New Game, Continue, Open, Save and Save As state clearly which commander and durable file they affect. Continuing a saved career restores that career rather than reapplying new-game gifts.

The defining loop is **prepare at a station -> choose a reachable destination or job -> fly and act in space -> preserve the actual cargo, people and evidence -> return to the proper receiver -> receive the agreed outcome -> improve the ship and discover the next story**. The player may trade, mine, salvage, transport people, investigate or fight; a campaign can require more than one of these skills. A displayed waypoint is a guide to work, not proof that the work happened.

The game contains 39 original campaigns with 368 authored stages, 15 general repeatable contract families, six continuing Wayfarer service families, four tutorials and one seven-step concluding mystery. Successful completion of the 39 campaigns and the first success in each of the other 25 families supplies the exact 64-source clue collection for The Unwritten Route. The fleet reference contains 171 new L337 definitions, including explicitly nonflyable objects. Each definition keeps its own original identity and geometry.

All playable mission operations take place in space or at an orbital station. A story's planetside recipient, research office or expedition is represented by an authorised station handoff. The player does not land for a ground battle, walk through a settlement, disable ground turrets or complete an on-foot operation. Planets remain places to navigate around, observe, trade with through their stations, and understand through their economies and societies.

### Rule authority and explicit design resolutions

The oracle uses the latest explicit player-facing design decisions first, followed by the accepted component, targeting, cabin and upgrade contracts, then the independently authored L337 world, equipment, fleet and mission definitions. A hull-native number, an installed component's multiplier, a purchase prerequisite and a mission reward are different facts. They must not overwrite one another simply because their displayed labels resemble each other.

| Rule | Finished-game value or precedence | Definition source |
| --- | --- | --- |
| Original base shop prices and laser work rates | The 14-entry L337 equipment schedule below supplies original base values where no later component rule replaces it. | `references/original-equipment.json` |
| Energy module grades | Basic/Intermediate/Advanced/Elite recharge is 1/2/3/4 times hull-native recharge, with stock capacity 1 times hull-native energy. These values replace the older 1.65/2.35 energy-unit proposal. | `references/EquipmentModuleTemplates.swift` and `references/EQUIPMENT-MODULES.md` |
| ECM activation | 10 energy, fitted hardware, undocked, sufficient live reserve and no existing own ECM field. This supersedes the earlier 22-energy proposal. | `references/TARGETING-COMPUTERS.md` |
| Base laser rates | Pulse 38, Beam 62, Mining 22 and Military 91 damage units/s; their energy and heat rates are listed below. Mounted tool identity and mission shield factors remain separate. | `references/original-equipment.json` |
| Cabin unit | Each purchased module occupies 5 tonnes and one equipment unit. Packed stasis has 20 places; greater comfort provides fewer places. | `references/PassengerCabinGrades.swift` |
| Missing original-hull crew numbers | E01 is a labelled design estimate using the new hull's own size tier, cargo and equipment budget. A previous game's ship with the same SH number is never evidence for a new L337 hull. | Ship-reference estimate rule below |
| Physical model units | A declared metre contract is used as declared. Other model dimensions are source-geometry dimensions, not inferred metres. A normalised reference picture cannot author a physical clearance. | Exact model JSON and per-image source provenance |

These are finished-game design resolutions, not claims about historical Elite specifications. E01 and any other explicitly labelled estimate remain identifiable as authored balance choices. A change to an oracle rule must update its affected tables, mission consequences and structured definitions together.

## Career, universe and progress

The ordinary universe has 2,048 original systems: 256 in each of eight galaxies. Galaxy and system identity travel with a destination, contract, discovery, save and receipt. A displayed name or chart position is not an alternative identifier. Each galaxy also has its own hidden PLUGH port at system identity 256; it is additional to the 256 ordinary systems.

The Galactic Map browses all eight galaxies without moving the commander. Per-galaxy selection, search, planet facts, neighbours, route display and travel commands agree about which galaxy is being viewed. Returning to the current location changes the view only. Browsing a foreign galaxy cannot spend fuel or initiate a jump. A real galactic-hyperdrive journey is a separate action with its own fitting and consumption.

The system view combines a deterministic globe with government, economy, technology, market, discoveries and route information. Night lighting reflects population/economic development; greenery, industrial appearance, sparse rings and mining fields follow the original world data. The selected planet facts can be scrolled without hiding their controls. A station direction remains useful even when the station is outside the scanner's ordinary range.

Markets carry 17 typed commodities, their native mass units, finite available stock and original system-dependent prices. A quote binds the actual market revision and quantities. The market is not replenished by looking away, repeatedly opening the page or loading the same state. Buying, selling, refuelling and outfitting display the resulting cash and capacity before a transaction is committed. Kilograms of precious metals and grams of gemstones are not silently rounded into a tonne per unit. Protected mission property, living people, fitted equipment and stored equipment are distinct from sellable trade cargo.

The player can plan fuel-feasible journeys and compare profitable destinations. The first leg uses current fuel; later legs use the actual full-tank capability and any stated refill assumption. Fuel capacity, fuel cost, navigation reach and drive activation time appear as separate values. A long-range navigation computer does not create fuel. Extra storage increases the tank, not the drive's lawful jump cap.

The optional top-five profit scan presents up to five positive-profit destinations within the actual current reach. Gold rings and ranks 1-5 agree with the listed destinations and the current sellable cargo, available hold, affordable exports and finite market stock. These are disclosed estimates, excluding danger and fuel costs unless a specific quote says otherwise; scanning does not buy, sell or select travel. Ordinary markets recover 32 percent of the gap toward their production target per completed 24-hour simulation epoch, including excess-stock decay, using the same saved elapsed epochs exactly once. There is no routine production of Alien Items.

The career records visited worlds, discovered craft, earned blueprints, combat rank, legal status, completed jobs, permanent faction entitlements, the clue journal, fitted items and stored spares. These belong to the commander and survive changing ships. Losing a hull is not permission to duplicate a person, a mission tool, a cargo lot or an already paid reward.

### First flights and player learning

The four tutorials teach flight and receiving, safe gunnery, defensive flight, and navigation/trading. They use genuine accepted practice volumes and real input. Safe gunnery targets are identified inert, uncrewed practice bodies; an ordinary civilian cannot be substituted for one. The defensive lesson observes actual acquisition, lateral flight and disengagement without pretending an NPC attacked the player. The navigation lesson buys, carries and sells the exact small practice consignment rather than setting a completion flag.

Tutorials share the normal board, confirmation, input and receiving language. A failed or cancelled attempt can be retried through its stated recovery policy. Each first legitimate success grants its own clue, while replaying practice does not replace a missing campaign clue.

### Recommended learning and capability progression

Campaign numbers identify stories; milestone numbers describe finished-product capabilities. Neither is a compulsory order for the commander. An offer's explicit eligibility, real fitting, available stock and reachable route control acceptance. The guidance below recommends increasing complexity without inventing campaign-completion gates.

| Career phase | Suitable work and preparation | Transition to harder work |
| --- | --- | --- |
| Learn safely | T01 reception, T03 non-firing defensive flight, T02 inert-target gunnery and T04 actual small trade; lessons keep their own stated prerequisites. | Demonstrate the actual control, receiving and travel skills; tutorials grant no free combat rank or profitable fictitious trade. |
| Build a working reserve | Ordinary legal trading and G01 sealed dispatch; read fuel, cargo, fitting and cash before accepting. | Earn fuel and tools through genuine work. C01's physical recovery needs fitted Scoops; its offer is not proof that the starter already owns them. |
| Investigate and cooperate | C01, C03, C04, C08 and the regional evidence/infrastructure stories, whenever their own offer conditions qualify. C02 follows legitimate Larvaal identification. | Keep serial tools, actual witnesses and evidence; C08 accreditation opens its advanced service variants without requiring other campaigns. |
| Specialise | Passenger/care work uses purchased compatible places after crew and existing reservations; mining/salvage use actual fitted tools. G06/G07/G15 use attributed combat against the designated hostiles. | Spare hold alone grants no passenger place. Mission escorts carrying their own people do not require the player's cabins. Develop the needed funds, hardware and skills before accepting hazards. |
| Manage consequential operations | C05 debris disaster, C06 resource conflict and C07 charged lattice combine earlier skills. C06's permanent commission marking is disclosed before acceptance. | Confirm readiness only after reviewing real rescue/aid, finite stock, energy and heat. Story numbers do not make C05 a mandatory early combat lesson. |
| Explore the complete career | Use actual intergalactic travel and refuelling to visit all eight galaxies and complete all 64 distinct clue sources. | Trade, repeat services and fabrication remain available alongside stories. A collected source clue survives later failed jobs and hull changes. |
| Resolve the mystery | With all 64 clues, decode at PLUGH, complete the four flight objectives in order, defeat the unique Medusa, then obtain the later AI reconstruction. | Fabrication access precedes a separate paid shipyard purchase; neither the defeat nor reconstruction grants a free hull. |

The full 64-clue finale includes passenger, financial, mining/salvage, tutorial and designated hostile-combat work; the present base set does not define a wholly pacifist shortcut. No single hull is prescribed for the whole career. Affordable basic work must remain available before specialist purchases, and genuine failures must have an honest route to future eligible work; unresolved source-stock details are identified in the [mission coherence review](MISSION-COHERENCE-REVIEW.md), rather than assumed into existence.

Structured galaxy integers use zero-based identities (0-7); player labels and `G01`-`G08` location keys are one-based. System identities stay 0-255, with PLUGH separately at 256. For example, finale `galaxy: 4` means displayed Galaxy 5. A mission's original source ID, such as `l337.courier` for Signed Passage, is stable identity rather than another mission or an extra clue.

## Flight, cockpit and station interaction

The player controls pitch, roll, yaw, thrust and view, with keyboard, pointer and trackpad actions agreeing with contextual help. Multi-contact spin is a deliberate flight mode, with its recognition threshold, direction, speed and cancellation reflected by the same controls. Changing a contact mode cannot leave an unintended manoeuvre latched. Manual steering overrides automatic work guidance; it does not forge a completed approach.

| Action | Player control and visible result |
| --- | --- |
| Choose a flight tool | W cycles Combat laser, Mining laser, Salvage cutter and EMP Pirate Blaster. Missing hardware is reported; a missing work tool never silently fires a combat laser. |
| Operate the selected tool | Hold Return; release stops the trigger but retains a safe target-relative hold. The persistent WEAPON indicator identifies the selected tool and actual readiness. |
| ECM | E activates fitted ECM subject to live energy and field conditions. |
| Release guidance | Q releases a work/target hold and invokes normal residual-motion/braking behaviour; it does not teleport the craft to rest. |
| Target class | F cycles Ships, Mining, Salvage and All. |
| Select target | Tab chooses the next eligible target in the chosen filter. Eligibility and missing fittings are explained. |
| Missile | T arms, M launches and U disarms/clears weapon lock and queued return fire. |
| Target details | I expands the panel; Option-Up/Down scrolls long manifests, resource facts or chart information in its relevant context. |
| Help/back | K or Command-K opens contextual help. Escape goes back or closes a preview without accepting it. |
| Confirm a station transaction | Return confirms the highlighted explicit action; Back/Cancel remains available. The same input has contextual menu semantics, not a hidden flight firing side effect. |

The cockpit presents scanner, target, speed, energy, independent front/rear shields, laser heat, cabin heat, fuel, cargo and ammunition with readable compact and fullscreen layouts. Warnings identify the actual event and are voiced as well as shown. A colour is never the sole statement of a target's status: hostile, disabled, recoverable, protected and unavailable states have text and consistent cues. White wireframe geometry remains white even when scanner/selection halos carry status colours.

Wireframe, shaded and textured presentation use the same actual source hull geometry and openings; appearance mode cannot alter collision, visibility or work eligibility. Original recessed details, palettes, texture materials and UV placement remain identifiable in flight, catalogue and comparison. Celestial objects appear in the correct current view and orientation. Smooth S/X travel pacing, normal scrolling, compact controls and fullscreen panels remain usable while the ordinary simulation is populated.

Docking is a physical entry through the actual moving doorway. Automatic docking follows approach, clearance and alignment, observes station rotation, obstacles, permissible hull size and residual momentum, and either completes a real docking receipt or explains refusal. Manual docking uses the same physical doorway. A denied docking permission cancels the automatic attempt rather than pressing against the entrance forever. Launch uses the real station exit and safe separation.

While docked, the station interface separates market, equipment, contracts, passenger/cargo receiving, status, inventory, ship catalogue, charts, rumours, mission journal and help. Status describes the commander and fitted craft; Inventory distinguishes trade cargo, mission property, fitted equipment and stored equipment. A button's caption and contextual help name its real action. Scroll/page hints appear only where there is actual further content. The main-station equipment shop is not silently available at every rescue-service dock.

### Ship catalogue, comparison and exchange

The ship catalogue contains the new L337 fleet, with its intended models, role, edition/family, discovered status and acquisition rules. Name/class/ID search, A-Z/power ordering, filter preservation and selection scrolling make all entries reachable. Each craft has a 3D view that the player can rotate through 360 degrees in any plane. The current and selected ships can be compared side by side; both use the same orientation, rotation direction and plane.

The primary comparison uses actual native capabilities plus the player's portable equipment on each hull. It distinguishes speed, acceleration, handling, front/rear shields, recharge, energy, lasers and mounts, missiles/pylons, tank, jump cap, spool, cargo, crew accommodation, cabin places and fitting restrictions. Better/Worse/Same is written as well as coloured. Hull-only values and modified fitted values are labelled separately. A station or environmental object is not advertised as a purchasable player ship.

Choosing a different ship opens a reviewable exchange quote: hull price, 75-percent trade-in allowance where the ordinary trade-in policy applies, net debit/credit, resulting cash, capacity changes, fitted transfers, stored overflow and any blocking people/cargo/fuel restriction. Compatible portable equipment transfers; excess missiles, incompatible portable fittings and other retained spares go into owned storage for later reuse. Returning to a larger hull offers those spares again rather than pretending that storage itself grants installed capability. Hull-bound parts stay with their proper hull. No exchange silently sells or deletes protected property, occupied cabins, people or trade cargo. If physical capacity still cannot be made valid, the quote refuses and explains what must change.

## Equipment, upgrades and their mission uses

Equipment is an owned physical item with a fitting location, provenance and condition. Owning a spare in storage does not enable it. A mission-issued programmer is a loaned original with a named receiving obligation; purchasing a lookalike does not discharge that obligation. Installing, storing, recovering, selling, upgrading and trading are explicit operations, with the relevant cash and mission state committed together.

Purchasable module families have predecessor graphs. A later purchase requires the earlier paid purchases specified in that family, not merely a higher-sounding fitted label. A reward or recovered item can provide a working capability without fabricating paid purchase history. Independent Mining and Salvage branches each require their declared core entitlement and installed core. Upgrade chains in shields, energy, navigation, drives and targeting do not substitute for one another.

### Original base equipment schedule

Prices are credits before a quoted station discount. Technology levels are the one-based levels shown to the player. The two energy-unit rows are replaced by the later energy module table, rather than being a second incompatible set of multipliers.

| Equipment | Base CR | Displayed TL | Intended capability and use |
| --- | ---: | ---: | --- |
| Fuel | 1.8 | 1 | Unit-priced tank replenishment; actual available capacity and travel fuel cost apply. |
| Standard missile | 180 | 2 | One finite round; original L337 damage budget 160. Pylon, targeting, clearance, attribution and ECM rules still apply. |
| Large Cargo Bay | 2,800 | 4 | The hull's declared cargo expansion; no universal extra capacity is assumed. Useful for freight, extraction and cabins. |
| E.C.M. System | 2,100 | 5 | Defeats susceptible incoming missiles; activation uses 10 live energy under the later ECM rule. |
| Pulse Laser | 1,450 | 3 | 38 damage/s, 9 energy/s, 12 heat/s; basic general combat on a supported mount. |
| Beam Laser | 4,700 | 7 | 62 damage/s, 19 energy/s, 24 heat/s; sustained combat with greater electrical/thermal demand. |
| Fuel Scoops | 1,900 | 4 | Actual compatible payload collection and stellar scooping, with aperture, temperature and hold limits. |
| Escape Pod | 3,600 | 6 | One fitted emergency escape device; occupied rescue capsules are people, not spare equipment. |
| Energy Bomb | 12,800 | 13 | Consumable attributed area weapon; original L337 activation budget 180 energy. Protection, distance and legal rules remain effective. |
| Intermediate Energy Module | 1,500 | 9 | Later module definition replaces the older Extra Energy Unit price/recharge proposal: recharge 2x, capacity 1x. |
| Galactic Hyperdrive | 28,500 | 15 | Separate real intergalactic journey; cannot be invoked by browsing another galaxy. |
| Mining Laser | 3,300 | 6 | 22 damage/s, 13 energy/s, 10 heat/s; specialised finite ore extraction rather than a cargo-creation command. |
| Military Laser | 16,400 | 14 | 91 damage/s, 34 energy/s, 39 heat/s; high demand combat hardware. |
| Advanced Energy Module | 4,500 | 12 | Later module definition replaces the older Naval Energy Unit price/recharge proposal: recharge 3x, capacity 1x. Also an explicit mission/PLUGH acquisition. |

Naval Laser is a distinct earned special fitting. Its mission-specific strengths and shielding interactions cannot be inferred from its zero shop placeholder price, and it is not an ordinary free shop purchase. The ship reference lists native mount compatibility; the selected installed weapon supplies its own strength, heat and electrical demand.

### Component progression

| Component | Stock grades | Stock mechanical result | Acquisition/use |
| --- | --- | --- | --- |
| Shields | Basic; Basic II; Intermediate; Intermediate II; Advanced; Advanced II; Elite | Capacity per front/rear bank is hull base x 1, 1.5, 1.8, 2, 2.3, 6.9, 9.2 respectively. Stock recharge is 1x. | Successive paid/earned progression; the Elite combat-rank reward is Advanced II. Upper stock grades are not fabricated by buying an unrelated laser. |
| Energy | Basic; Intermediate; Advanced; Elite | Capacity 1x; recharge 1/2/3/4x hull base. | Foundations; 1,500 CR Intermediate; 4,500 CR/TL12 Advanced; 13,500 CR/TL14 Elite, plus specific earned sources. |
| Navigation | Basic; Intermediate; Advanced | Nominal reach 7/14/21 LY, resolved with the hull's declared reach and actual fuel. | Basic foundation; 3,000/9,000 CR higher modules; search scope expands with the grade. |
| Hyperspace drive | Basic; Intermediate; Advanced | Activation 10/5/1 s; mass-lock scale 1/0.8/0.6. Reach, tank and fuel efficiency remain separate. | Basic foundation; 5,000 CR/TL10 Intermediate; 15,000 CR/TL13 Advanced. |
| Fuel Storage Unit | Up to four | Each adds 70 fuel units, equivalent to 7 LY at standard fuel cost. | 2,000 CR per physical unit; no free range-cap increase. |

Each purchasable shield booster costs 25 percent less than its matching laser, calculated once in internal tenths of a credit as `laserPrice * 3 / 4` with integer truncation. Basic II matches Pulse (1,087.5 CR), Intermediate matches Mining (2,475 CR), Intermediate II matches Beam (3,525 CR), and Advanced matches Military (12,300 CR). These amounts follow the original L337 laser prices above; the ratio is the controlling rule if those prices change. Advanced II is an earned special acquisition and Elite is reached through compatible component progression. Price, availability and paid prerequisites must all be disclosed at the shop. Advanced II and Elite naming is independent of combat rank naming.

A recovered compatible improvement adds its stated percentage of the component's immutable original statistics. Two distinct +10-percent items add 20 percent of that origin rather than compounding the already improved value. The item is consumed once, its receipt is retained, and a replay cannot apply it again. A component promotes when every required threshold is met, retaining excess progress; upgrading another useful axis need not promote the grade. Refitting preserves resource fractions instead of refilling shields, energy, missiles or fuel.

Ordinary terminal envelopes are shield capacity 11.96x and recharge 1.3x; navigation reach 27.3 LY with spool/fuel-cost ratios at least 0.7; energy capacity 1.3x and recharge 5.2x. These bound newly applied ordinary improvements. Distinct compatible features and the alien attachment system remain separately declared, rather than silently removing useful earned statistics.

### Targeting and specialist work

| Targeting core | Price CR | Displayed TL | Capability added |
| --- | ---: | ---: | --- |
| Basic | 800 | 4 | Acquire front-visible ships, turn and track. |
| Advanced | 2,000 | 5 | Acquire known offscreen ships. |
| Docking | 4,000 | 7 | Station selection and actual automatic docking. |
| Identification | 6,000 | 9 | Live model preview, identity and hostility/status. |
| Pirate | 10,000 | 10 | Recorded ordinary cargo manifest and origin/destination. Unknown data stays unknown. |
| Military | 12,000 | 11 | Missile/ECM/resources and the bounded return-fire capability; not free ECM or work modules. |

The Mining Module costs 2,000 CR at displayed TL6; Salvage Module costs 4,000 CR at TL8. Each is an independent add-on to an eligible fitted core, not a free side effect of Military. The Salvage Cutter is a separate 2,500 CR/TL7 utility. EMP Pirate Blaster is separate 3,000 CR/TL9 forward electronic equipment. The earlier original base schedule supplies the final Mining Laser/Fuel Scoops prices where generic guides contain older stock numbers.

Target details display actual hull identity, hostility, legal and custody information, recorded cargo and route, and the installed tier's permitted live resources. Station entrance readiness and rotation are station facts, not fake ship fuel or missile values. A target being red or hostile does not grant a lawful bounty or title to its cargo.

Military return fire uses the actual living launcher of an incoming missile. A player's ECM must genuinely destroy that missile before the bounded retaliatory missile order qualifies. There is at most one response per attacker per ECM activation, after the field ends and the normal cooldown, with valid lock/clearance and finite owned ammunition. It expires rather than firing at a vanished or unrelated source. Laser damage cannot impersonate an intercepted missile. Automatic target, automatic ECM and return-fire preferences remain distinct.

## Physical space, combat, security and NPC society

### How fittings open mission possibilities

| Capability or owned item | Mission connection | What it cannot replace |
| --- | --- | --- |
| Fuel, storage, navigation and drive | Make quoted freight/passenger routes, campaign travel, the warning tour and the later intergalactic clue journey reachable. | A route preview is not travel; tank capacity is not jump cap; a drive in storage is not fitted. |
| Docking computer and ordinary flight | Real main-station/receiver arrivals, practice reception, courier settlements, private-passenger journeys and convoy receiving. | A marker approach or displayed Ready state cannot create the doorway/dock/receiving receipt. |
| Identification and measured scans | Glass Meridian's clocks, consented survey, alien signals, clue-trail echoes and custody/provenance inspection. | Opening a model preview cannot replace a continuous line-of-sight observation. |
| Cargo hold and Fuel Scoops | C01's original 8 kg recorder, timing-standard cargo, physical rescue pods/records, identified salvage, measured ore and W05 archive recovery. | A cargo commodity, duplicate object or zero-mass clue cannot replace the exact protected physical item. |
| Purchased compatible cabins | G04 cabin journey, G05 orbital outlook, G08 rescued people's onward transport, G14 four-person evacuation, C08 survivors and other authored care journeys. | Intrinsic operating quarters, an occupied module or an unfitted spare is not free passenger capacity. |
| Mining Module, Mining Laser and scoops | G12's actual 12-tonne extraction, finite ordinary mining and campaign resource work where explicitly specified. | Buying a module cannot count as extraction; a destructive combat blast cannot produce a second full ore yield. |
| Salvage Module, cutter and scoops | G09 original identified salvage, W05 recorder recovery and lawful accessible wreck/capital sections. | Selection cannot confer ownership; cutting an occupied hull cannot pretend that its crew already escaped. |
| Loaned programmers and reference instruments | G11's two real isolation operations, Still Current's baffles and campaign calibration/verification tasks. | Owning a similar purchased tool cannot replace the issuer's original serial or discharge its return obligation. |
| Combat mounts, finite missiles and ECM | Verified warrant/corridor/Larvaal defence, safe-gunnery practice, actual escort defence and the unique final encounter. | Ordinary police/crime rules, nearest-hit obstruction and unique player attribution still apply; unrelated hostility is not bounty entitlement. |
| EMP and compatible capture/care tools | Optional genuine disablement, living crew ejection and lawful recovery of an actually empty disabled hull. | G08's non-EMP rescue is not gated by an invented forced attack; a dead or empty capsule is not a living survivor. |
| Shield, energy and thermal upgrades | Survive hostile journeys, supply sustained tools, support EMP and maintain safety around actual hazard volumes. | Player upgrades do not alter Shattered Wake's independent station population/impact accounting or create Still Current energy. |
| PLUGH artefacts, alien fittings and seeker research | Turn actual recovered technology into compatible installed capability and owned purchasable ammunition. | An artefact picture or a free placeholder price cannot stand in for research, payment, ownership or fitting. |
| All earned hulls and portable equipment | Let the commander change role as cargo, cabin, combat, work and route needs change across the career. | Exchanging ships cannot erase a failed contract, discard people, refill resources or award a missing clue. |
| Permanent clues and faction marking | Every genuine first success contributes to The Unwritten Route; the Tithe commission mark survives its endings and later hulls. | Neither visual gallery nor a stored equipment item can forge an earned journal/entitlement receipt. |

Ships, stations, rocks, people, payloads and projectiles retain their identity through the operation being observed. Traffic and mission actors share one physical space and one attributed damage pipeline. Actual mount orientation, nearest solid mesh hit, obstruction, range, firing resources and target state determine an attack. A component hit is not automatically destruction of the whole craft. Leaving the scene, culling or turning an object into a marker is not a kill.

Front/rear shields absorb the appropriate facing hit before hull energy. Recharge follows the fitted equipment and real elapsed simulation time. Electrical reserve for EMP is distinct from hull survival energy. Heat limits sustained tool and weapon work; a cold replacement label cannot erase a hot physical component's consequences.

Clean, Offender and Fugitive records are independent of immediate hostility. An unlawful first hit or targeted attack is an offence even without a kill. A victim can defend against the actual unlawful aggressor; the right does not extend to unrelated ships. Bounty needs a pre-existing lawful entitlement and unique player-attributed destruction. A zero-bounty qualifying kill may advance combat rank without paying money. Rocks, cargo, component debris, duplicate death callbacks and ordinary scene removal do not award ship kills.

Station security uses actual sensor/witness/relay geography. The authored initial no-fire radius is 1,200 units, station relay 6,000, dispatch 10,000 and nearby police witness 2,500. A missed shot in the no-fire zone gives a warning; another discharge within 10 simulation seconds records the repeat offence. Real station hits raise an alarm even where ordinary ship weapons cannot damage station structure. A quiet remote crime is not instantly witnessed by every authority in the galaxy.

Police patrol, investigate, intercept, engage, search and return. They physically depart the station or approach as existing patrols. The initial station-attack response is three defenders after four seconds, with at most two more per ten seconds and at most eight active police. No unlimited reinforcement loop is implied. Civilian distress, government and witness geography govern ordinary reporting. Anarchy lacks normal patrols but its station can defend itself. Lawful defence does not reset the player's previous crimes.

Ordinary traders and miners use actual routes, cargo and work. Pirates favour valuable carriers and can attack NPCs, flee superior police or low resources, and take genuine dropped goods. The initial government pressure ordering is Anarchy 1.0, Feudal 0.85, Multi-government 0.65, Dictatorship 0.45, Communist 0.30, Confederacy 0.20, Democracy 0.12 and Corporate 0.08, modified by traffic region. These are authored population weights, not an attack guaranteed every few seconds. Admission reserves room for mission and defence actors and never deletes protected mission cargo to make ambient traffic fit.

The counter for uniquely credited player kills is persistent and does not wrap. Right on, Commander is an in-flight recognition at each positive multiple of 256 credited kills. It is separate from rank, legal bounty, mission pay and equipment rewards. Loading a tally, swapping ships or replaying a death never announces the same milestone again. Elite rank's 6,400 threshold and its one earned shield reward are separately recorded.

The Wanted board provides dossiers for recorded wanted actors, including their actual identity, known location/route, legal record and bounty evidence. The Top 10 selection has consistent purple board/HUD/world cues and does not overwrite red immediate hostility or orange disabled/work facts. Unknown travel facts remain unknown rather than inferred from an unrelated ship. An explicit legal reset in the optional XYZZY controls is separate from ordinary justice; missions and ship exchange never silently clear the record.

## Mining, work guidance and finite salvage

Mining fields occupy deterministic safe space around worlds, avoiding interiors, station approaches and stellar danger envelopes. Normal fields contain finite rocks. Player and NPC mining share depletion; docking, a new visit or loading the same save cannot grow the same ore again. A field beacon makes the opportunity findable without requiring a new hidden prospecting item.

Selecting an eligible rock with the fitted Mining Module starts a genuine approach and target-relative hold. On reaching a safe stable hold the system selects a fitted Mining Laser once unless the player has used W to override it. It does not fire by itself. Return operates the chosen tool and Fuel Scoops collect genuinely released compatible material. Extraction retains the parent work target while the material is collected. Q, manual flight, a new target, unsafe geometry or actual incoming damage releases/intervenes appropriately. Guidance accounts for obstacles, current hull extent, momentum and the actual scoop aperture.

Mining Laser extraction releases finite typed ore and sometimes other metals according to the source profile. Destroying a rock destructively with the combat laser produces much smaller fragments with strictly less than five percent of the original mass remaining collectible. Most material is irretrievably lost. A combat blast is not a second full-yield mining operation. Precious-metal payloads retain kilograms; gemstones retain grams.

Salvage work uses a separate Salvage Module, a compatible cutter for sections and Fuel Scoops for collection. Accessible work surfaces, rotation, ownership, claimant, occupants and actual released-lot dimensions govern eligibility. A hostile ship is not automatically lawful salvage. Oversized or obstructed cargo stays outside rather than becoming a virtual inventory award. Capital wrecks have real sections, stores and finite release histories. The same original manifest cannot be both dropped and replaced with duplicate random loot.

Recovered items can be cargo, ready-to-fit hardware, a feature module, an origin-based equipment improvement, ammunition, a compatible hardpoint/pylon assembly, an empty escape pod or an alien artefact. The target/hold UI states exact effect, compatible slot, mass, condition, provenance, legality and sale value. Inspecting, retargeting and reloading do not reroll the contents or quality.

Initial source-weighted reward design favours illegal goods in an abandoned drug factory (70 percent of eligible rolls), weapon items/upgrades at a derelict platform (60 percent), cargo at an abandoned station (85 percent), ore from ordinary rocks (100 percent), and minerals at a rock hermit (90 percent). Commercial wrecks favour their real manifest/cargo (95 percent); military capital wrecks favour shield items/upgrades (55 percent). Larvaal salvage favours actual alien artefacts. A more specific source profile takes precedence; overlapping roles do not get multiple independent rolls. These are labelled authored balance weights, not a promise of an item on every wreck.

Structural hardpoint upgrades unlock only an absent declared compatible Front/Rear/Left/Right facing. Pylon additions respect the per-hull structural limit and start empty. Neither route creates a fifth generic weapon facing or unlimited ammunition. Stored empty escape pods are consumables; an occupied rescue capsule is never converted into one.

### EMP, rescue and living custody

The EMP Pirate Blaster requires a real eligible forward mesh target and a continuous ten-second charge. Releasing the trigger cancels; an actual attributed ECM field can cancel it. Fitting, range, reserve and the same target are rechecked at release. Base reach is 3,000 native units and base pulse power 32, multiplied by `1 + 0.5 * energyStage` under the declared effective energy profile. The struck shield drains before electrical reserve; EMP does not directly reduce hull energy. Release costs eight player electrical energy, adds 18 heat and has a 1.5-second cooldown.

The primary target receives full pulse power; eligible nearby targets can receive line-of-sight attenuated splash within one-third of the current range. The player can be affected. At zero electrical reserve a disabled craft cannot use drives, lasers or future missile launches, but retains actual drift and spin. Recovery after the declared thirty-second lifecycle does not resurrect destroyed components or clone expelled crew.

Occupied ships remain occupied until actual crew ejection/capture establishes otherwise. Each living escape pod is a protected person with identity, origin, consent and receiving obligations. A lethal attack records the unejected people's real loss; it does not produce rescue pods afterwards. Rescue and passenger jobs require actual life-support-compatible free places in the selected ship. A person's appearance in a log is not proof of boarding, and a recorder is cargo rather than a person.

## Crew, cabins, comfort and care

Operating complement, reserved crew quarters, fitted passenger places, free compatible passenger places, mission reservations and ordinary cargo are separate values. The commander is included in operating crew. Intrinsic operating quarters are reserved once, not subtracted again from cargo or sold as passenger places. The ship reference labels necessary crew/equipment estimates explicitly.

| Cabin module | Places | Awake travel | Cargo/equipment cost | Price CR | Purpose |
| --- | ---: | --- | --- | ---: | --- |
| Packed Stasis Cabin | 20 | No | 5 t + 1 unit | 1,000 | Dense stasis transport, not walk-around quarters. |
| Economy Cabin | 8 | Yes | 5 t + 1 unit | 2,500 | Shared economy places with stasis support. |
| Standard Cabin | 4 | Yes | 5 t + 1 unit | 5,000 | Shared standard comfort. |
| Luxury Cabin | 2 | Yes | 5 t + 1 unit | 10,000 | Shared luxury places. |
| Single Stateroom | 1 | Yes | 5 t + 1 unit | 20,000 | Private single with long-journey stasis. |
| Double Stateroom | 2 | Yes | 5 t + 1 unit | 20,000 | Private double with long-journey stasis. |

A cabin has its own owned identity and fixed complete layout. The same cabin cannot be fitted twice; its places cannot belong to two people. A private booking reserves the complete physical module even if only one of its places is used. Storing or selling an occupied or reserved module is refused. Failed life support or incompatible stasis prevents the corresponding mode; a more expensive cabin is not evidence of an unrecorded patient handoff.

Passengers and rescued people retain consent, identity, capacity reservation, health/integrity and living outcomes through travel and save/load. Mission care requires the actual equipment, intervention and named receiver. A thermal hazard is a real geometric volume applying normal cabin heat, and leaving it allows normal cooling. Pausing stops its simulation clock; opening a menu or loading cannot reset an advertised life-support or incident budget.

## PLUGH, recovered technology and ship collection

Each hidden PLUGH port is discovered through actual rumours and its own galaxy discovery record. Before discovery it is excluded from ordinary charts/search/route destinations. The port's AI offers the intended compatible special services, discounts and research, not free quest completion. Normal revealed coordinates do not justify importing predecessor system names or records.

Four independent alien attachment types improve energy capacity, energy recharge, shield capacity and shield recharge. A stock attachment contributes ten percent to its own type. Same-type contributions add once, then multiply the resolved normal component; two stock capacity units give twenty percent, independently of recharge units. They have no arbitrary gameplay count limit, while physical ownership, fitting, meaningful storage and compatible source rules still apply. Individual recovered improvements belong to that physical attachment and cannot be reset/replayed by storing it.

Fitting/storing alien modules requires actual PLUGH service. It costs no refit charge and grants no free energy/shield refill. A compatible recovered alien hyperspace drive is a distinct actual owned fitting; it can supply its declared immediate/mass-lock-free alien policy only while fitted to the active owned hull. A human module or stored artefact does not impersonate it.

Alien Seeker Missile research consumes one authentic owned alien artefact and 1,500 CR, establishes the recipe once, and delivers one owned prototype round subject to real storage/pylon capacity. Later rounds cost 60 CR each and consume ordinary finite pylons/ammunition. The seeker is 25 percent faster and stronger than the corresponding standard missile; research, purchase, fit, launch and consumption are separate transactions. A zero-price or unavailable catalogue row cannot bypass the research prerequisite.

Discovery, blueprint ownership and paid fabrication are three different milestones. A discovered rare hull is recorded under its original identity. A qualifying genuine observation, docking, destruction or mission event grants only the declared discovery/blueprint entitlement. The appropriate local/PLUGH AI still checks technology, access, actual payment, resources and fit before constructing a player hull. Stations/environment objects keep their nonflyable/never-purchase rule. SH171 Medusa follows the exclusive finale; no showroom, unrestricted cheat or ordinary collection reward unlocks it early.

## Mission journal, gallery and reliable outcomes

Every accepted mission has an instance, original targets, current stage, evidence, choices, actual owned/loaned items, cargo/berth reservations, timers, outcomes and once-only receipts. The journal states where to go, what action is needed, what is missing and how to recover. It never claims that a specimen was delivered because its marker was inspected. Back/decline/failed save is an unchanged transaction, not a partial acceptance.

The gallery is a read-only view of legitimate current briefings, known contacts, discovered craft, earned clues and completed stage/outcome art. It explains progress and supplies accessible text for graphics. Browsing does not emit a scan, dialogue acceptance, kill, transfer or reward. Future cards and hidden hulls remain hidden until their actual visibility conditions qualify. The offline review contains every graphic so the final game can be checked against it without weakening the in-game spoiler rules.

Mission definitions can express offers, dialogue, conditions, physical scans, timed windows, cargo and people custody, native work, finance, escort, combat attribution, branches, failure/recovery and terminal settlement. Campaign-specific mechanics use actual world events. A script can request/interpret a supported operation, but cannot declare a physical action successful without the matching native evidence. A contact conversation cannot stand in for moving a convoy or collecting a person.

The player can explicitly choose and install a validated mission-pack folder without rebuilding the application. The pack declares its identity, supported engine contract, story, assets, requirements and operations. Invalid, conflicting or unsupported content is explained before it can become a misleading playable offer. A read-only reference preview does not grant playability or capability. Pack content obeys the same actor identity, transaction, physical-evidence, save, custody and reward rules as built-in stories. The active mission library, board and gallery distinguish installed content from already accepted instances and retained history.

The optional XYZZY toolkit offers maximum compatible hardware, explicit ship/refit choices, automatic-trade and targeting/ECM preferences, and separate fuel/cargo/ammunition conveniences. It preserves the commander's campaign and property records; a refit is not a repeat cash payout. Its explicit Clean action does not erase mission progress. The ordinary economy and finite fitting rules remain the normal career. Even in this toolkit, a hidden finale is not earned by manufacturing clues, a Medusa blueprint, a substitute kill or a false receiving record.

Financial work has real deposits, escrow, liabilities, finite stock, releases and receiver payments. Mission items remain protected from ordinary selling/duplicate issue. Loan tools must return to their actual issuer where required. Each accepted mission advertises its clock domain. Explicit simulation pause freezes simulation clocks; opening a help, chart, gallery or contact screen is not itself a universal pause. Shattered Wake's armed passage continues through active docking, radio dialogs and interstellar departure, while its documented background/sleep pause freezes it. A flight-only integrity budget advances only during its declared armed flight time. Screen and save/load handling preserve that mission-specific policy. Save/load retains the same progress, randomness, depleted resources, quoted obligations and history without duplicating payments or replenishing a wreck.

### Connections that define the campaigns

Human civilians, miners, freight operators, private escorts and police have roles and legal identities rather than a universal hostile/non-hostile script. The Hearth Compact is the explicitly joined coalition in The Tithe of Worlds; its permanent mark is an informed commitment. The Tithe Network is an autonomous resource-allocation AI with actual controlled assets and finite reserves. Larvaal ships and dispersed companions have their own signal/custody identities: a hostile designated force, a distressed probe and a companion are different mission situations, not permission to attack every alien. Medusa is the exclusive revealed craft of The Unwritten Route, not an ambient replacement for the Larvaal fleet.

The Glass Meridian connects scanning, original evidence, timing-standard cargo and a real clinic escort. A Choir Beneath the Static makes alien-contact interpretation an evidence problem, not a compulsory extermination. The Hollow Manifest and Borrowed Voice tie freight/relay identity to consent and public accountability. Shattered Wake combines an optional warning tour with finite allied response, physical impacts, station population, mitigation and real evacuation outcomes. The Tithe of Worlds makes a permanent explicitly accepted faction commission meaningful through two real resource-control endings. The Still Current ties measured energy conservation and actual cabin heat to rescue and isolation work. Wayfarer Exchange teaches a continuing career with real operators, logistics and service accreditation. The remaining original campaigns each keep their own problem, contacts, resource operation, independent witness and settlement alternatives; their shared stage pattern does not make their content interchangeable.

## Finished-game milestone outcomes

These are user-facing completion criteria for the oracle, not a progress report or a new work queue.

| Milestone | What the finished game makes possible |
| --- | --- |
| M01 | A dependable complete flight/trade/mission/save loop with durable outcomes and usable installation. |
| M02 | An understandable Mac cockpit/station interface, consistent controls/help, and honest ship/equipment comparison. |
| M03 | Fresh starts, trading and travel in the original 2,048-world L337 universe with coherent original identities and finite markets. |
| M04 | The intended original 171-record fleet, actual materials/geometry, real physical scale contracts and only eligible player acquisitions. |
| M05 | Reachable original contracts and tutorials that accept, perform, receive, fail/recover and preserve their first-success outcomes. |
| M06 | Fuel-feasible exploration, useful station directions, solar refuelling, readable planets/night lighting and real mining geography. |
| M07 | Physical attributed combat, legal defence/bounties, real shield/ordnance/ECM/EMP behavior, crew consequences and combat learning. |
| M08 | Mining and finite salvage through genuine approach/work/collection, recoverable compatible upgrades and PLUGH alien services. |
| M09 | Real consenting passenger/rescue/care journeys with meaningful compatible spare accommodation and living outcomes. |
| M10 | Actual convoy departure/transit/formation/rejoin/docking and lawful escort defence, including Crimbo and its intended rare habitats. |
| M11 | All original investigation/evidence campaigns, distinct story beats, legitimate alternatives and one clue per successful source. |
| M12 | Physical orbital infrastructure/service/finance operations with conserved ownership and real settlement. |
| M13 | Optional neighbouring-system warning, finite aid and The Shattered Wake's physically determined saved/evacuated/lost outcomes. |
| M14 | Both Tithe settlements and the permanent, explicitly accepted Hearth Compact commission marking across later hulls. |
| M15 | The Still Current's finite energy accounting, heat, people and receiver outcomes. |
| M16 | Wayfarer accreditation and all six repeatable services with stable quotes, capacity/integrity limits and separate family clues. |
| M17 | Original rare-fleet discovery, the declared eligible collection set, earned blueprints and paid qualifying fabrication. |
| M18 | All 64 distinct clues, ordered decoded trail, exclusive Medusa encounter, player-credited destruction and later paid fabrication. |
| M19 | A correctly identified, signed/notarized distribution with coherent GitHub/Homebrew install, update, saved-game and removal behavior. |

## Mission and equipment relationship map

The following is a spoiler-complete review. A ship listed for a mission is a story actor, work vessel or encounter hull; it is not automatically the required player hull or a reward. A player can use another hull when its real fitting, cargo, range, accommodation and clearance meet the mission requirements. The detailed stage rules below take precedence over the summary tags.

| Campaign | Story hulls | Gameplay connections | Stages | Fee CR |
| --- | --- | --- | ---: | ---: |
| C01 The Glass Meridian | SH026 Harrier | beacon observation; physical recorder and timing-standard custody; relay calibration; clinic escort; evidence disposition | 9 | 4,800 |
| C02 A Choir Beneath the Static | SH124 Larvaal Warship, SH125 Larvaal Drone, SH162 Larvaal Probe | signal observation; collector/culture exchange; consensual probe repair; counterfeit-emitter shutdown; signal accord | 9 | 6,400 |
| C03 The Hollow Manifest | No named story hull | consented seal/wake scans; inspection-kit loan; data custody; crew-launch escort; fraud remedy | 10 | 5,600 |
| C04 The Borrowed Voice | SH026 Harrier, SH049 Hyena | distress verification; verifier loan; witness extraction; revocation or empty decoy; beacon rekeying | 10 | 7,200 |
| C05 The Shattered Wake | SH061 Haflinger | physical debris/fragmentation; optional finite aid; timed station defence; actual evacuation; outcome inquiry | 11 | 1,800 |
| C06 The Tithe of Worlds | SH001 Mule, SH004 Gyrfalcon Patrol, SH005 Bison | permanent commission consent; finite resource control and reserves; supply escort; charter or severance | 14 | 9,600 |
| C07 The Still Current | SH001 Mule, SH049 Hyena, SH061 Haflinger | finite energy and heat; serial tool exchange; technician escort; isolation; conserved settlement | 12 | 8,400 |
| C08 Wayfarer Exchange | SH001 Mule, SH005 Bison, SH061 Haflinger | serial consignments; cold-chain integrity; seed and rescue escorts; utility restoration; service accreditation | 14 | 7,600 |
| C09 The Quiet Nursery | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 4,600 |
| C10 Borrowed Dawn | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,800 |
| C11 The Open Shadow | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,400 |
| C12 Harbour Without Orders | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,600 |
| C13 False Colours | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,200 |
| C14 The Rubble Covenant | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,600 |
| C15 A Garden in Transit | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,100 |
| C16 The Warrant Ledger | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 8,200 |
| C17 The Measure of Care | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 5,900 |
| C18 The Long Return | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,800 |
| C19 The Unfinished Map | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,900 |
| C20 The Blue Reservoir | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,300 |
| C21 Mutual Shelter | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,100 |
| C22 The Listening Frontier | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 9,100 |
| C23 An Assembly of Orbits | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,700 |
| C24 Under Tow | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 8,300 |
| C25 The Memory Atlas | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,200 |
| C26 A Fleet of Neighbours | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 9,400 |
| C27 Uncounted Names | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,500 |
| C28 The Honest Circuit | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,000 |
| C29 Small Lights | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,400 |
| C30 The Passenger's Horizon | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,500 |
| C31 The Kind Distance | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 5,600 |
| C32 Cold Reserve | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 8,800 |
| C33 The Magnetic Orchard | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 9,200 |
| C34 Open Measure | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 7,900 |
| C35 The Shared Pulse | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 8,600 |
| C36 The Witness Window | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 8,100 |
| C37 Public Record | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 6,300 |
| C38 Signed Passage | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 4,300 |
| C39 The Guiding Light | SH001 Mule, SH061 Haflinger | distinct survey; serial reference loan and orbital work; consenting tender escort; two verified settlements | 9 | 5,700 |
