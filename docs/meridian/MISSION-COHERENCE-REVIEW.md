# Mission coherence and gameplay progression review

This review checks the intended finished game against the [oracle](FINAL-GAME-ORACLE.md), all portable mission definitions and the later source contracts recorded in [the source evidence](references/mission-review-source-evidence.json). It covers all 39 campaigns and 368 stages, 15 general families, four tutorials, six Wayfarer families and the seven-step finale. It is a documentation and design review, not a runtime playthrough or a claim that the game implements these definitions. Implementation ownership and scheduling remain exclusively in the main project ledger; finding labels here identify evidence, not new work packets.

**Conclusion:** the stories have intelligible causes, investigations and outcomes; stage ordering, world identities and the 64-clue membership are structurally sound. Progression cannot yet receive an unconditional implementation-ready verdict. The unresolved cases below concern real failure recovery, resource conservation and incomplete operation profiles. A valid graph alone cannot prove a mission is playable or balanced.

## Verified structure

- All 368 campaign stages have unique stage identities within their campaign, the expected next transition and a reachable terminal. Every explicit branch variant refers to an earlier choice and covers its declared choice IDs.
- All stage galaxy/system/name/key joins match the original world snapshots. Each of the eight ordinary 256-system galaxies is connected through jumps of at most 7 LY. This permits intermediate refuelling stops; it does not promise a direct jump, funded fuel, station stock, safe passage or an eligible doorway.
- Declared campaign item-effect sequences neither remove an unheld item nor duplicate an issue, and release their declared loans. Peak declared serial-loan mass is one tonne. This result excludes the C01 physical-recorder discrepancy in F03; it is not proof that every physical object has been represented.
- The 39 campaign clues, 15 general-family clues, six Wayfarer clues and four tutorial clues give exactly 64 unique source IDs and 64 unique clue IDs. Both required sets match the finale exactly. Its epilogue evidence is not its own prerequisite.
- All seven finale transitions agree: decode -> listener -> ring -> lanterns -> cradle -> credited Medusa destruction -> later PLUGH reconstruction. Purchase is a separate paid transaction. A lost/uncredited encounter retries the unlocked checkpoint without recollecting clues.
- Scope remains orbital/space operations and station receiving. No review correction introduces a surface visit or ground operation.

The [machine-readable structural receipts](MISSION-REVIEW-CHECKS.json) record each campaign definition hash and the exact scope of these checks.

## Unresolved findings and recommended resolutions

### F01 - Required clues can become permanently unavailable after finite-source failure

**Consequence:** a commander can lose access to the 64-clue finale through an honestly recorded failure. The general family text promises repeat work from actual new stock. The later G11 parent contract explicitly supplies only one lifetime original programmer/source pair and refuses a second acceptance after terminal failure or completion. Completion is harmless because its clue is retained; failure before first success is the unresolved case. Source: `gameplay-design/G11-P02-PARENT-ACCEPTANCE-AND-PROGRAMMER-CONTRACT-20261022.md`, especially Known initial-stock limit, identified in the source evidence.

**Recommended resolution:** author genuine replenishment, repair or separately funded replacement stock and a new contract instance while retaining original losses, obligations and identities. Exhausted C08 Ark/Rescue reserves and every named-person campaign need the same achievable-clue audit. Do not reset the lifetime guard, clone an original, revive casualties, award the clue on failure or quietly reduce the 64-source set. The exact funding/availability/recovery rule is unresolved, not supplied by this review.

### F02 - Still Current's fixed buffer outcome can exceed its remaining energy

**Consequence:** the array begins with 900 units and explicitly permits recorded safe discharge of up to 90 per operation. The community branch then requires exactly 300 delivered plus 600 retained. If any prior discharge or recovery removed charge, `300 + 600 + discharged + recovered > 900`. The material-recovery branch can instead account for the remainder. Sources: [energy rules and branch objective](definitions/missions/still-current.json), later Still Current contract evidence.

**Recommended resolution:** define before acceptance and branch confirmation whether the community route requires all 900 units intact, or whether its tested capacity of 600 differs from its actual remaining stored charge. If depleted, explain the unavailable branch and preserve an achievable authorised settlement. Resolve earlier permitted discharges and already chosen branches explicitly. Never refill from nowhere, erase discharge receipts or retain the phrase “buffer holds 600” when the measured balance is smaller. No numerical rule changed here.

### F03 - Glass Meridian's 8 kg recorder is absent from its generic custody effects

**Consequence:** the accepted later physical rule requires the original 8 kg recorder, Scoops recovery and retained custody through the booking audit. The portable generic stage still says zero interaction mass, has no recorder add/remove effect and declares only the one-tonne timing standard. Thus a generic evaluator can report correct item conservation while omitting a real physical object. Source: [C01 definition](definitions/missions/glass-meridian.json), later C01 reservation-audit evidence. The older data-only-recorder contract is superseded for this original.

**Recommended resolution:** make the physical recorder identity and 0.008 t accounting canonical, including source, issue/recovery, loss, audit retention and explicit final custodian. If it overlaps the standard, require 1.008 t rather than one tonne. If an authorised audit receiver keeps it, record that real handoff before releasing capacity. The final disposition is not invented by this review. The zero-mass clue remains distinct from the physical recorder.

### F04 - Cold-chain offers promise a budget without closing its default value

**Consequence:** C08's pickup promises an advertised integrity budget, but its portable definition gives no initial numerical budget, quality-loss rate or minimum usable threshold. Generic W01 text likewise cannot alone determine a concrete variant's perishability. Source: [C08 definition](definitions/missions/wayfarer-exchange.json), [Wayfarer services](definitions/missions/wayfarer-services.json).

**Recommended resolution:** author a closed route-specific initial budget, decay/thermal policy, usable threshold, pickup arming point and genuine replacement-stock rule. Preview them before collection. Its armed-flight clock remains distinct from C05's continuous emergency clock. No guessed timer was introduced.

### F05 - Story-complete templates are not complete native-operation profiles

**Consequence:** all 31 C09-C39 campaigns share a nine-stage survey/loan/work/witness/choice/proof/return/audit pattern. Their problems and branch objectives differ, but many exact scan envelopes, physical devices, acceptance tolerances, crew/fuel/reserve budgets and operation durations remain prose. Most family definitions are similarly broad; later accepted G01/G04/G05/G10/G11/T03/T04 and other handoffs contain additional constraints that the base family JSON alone does not reproduce. Do not implement each “mission_action_confirmed” as a dialog success.

**Recommended resolution:** preserve each branch's physical proof pair and attach its closed, approved native profile or clearly labelled necessary estimate. Resolve later-profile precedence and loss/receiving policies per source. Validate actual station entry, movements, people and resource transactions in the game before claiming playability. The existing action labels and illustrative art do not prove these operations exist.

### F06 - Witness Window's narrative expiry lacks an explicit clock boundary

**Consequence:** its premise threatens routine deletion of testimony, but shared preparation is untimed and no expiry operation/budget is defined. An unseen deletion clock would contradict the offer; pretending the deadline exists only in dialogue weakens the premise. Source: [C36 definition](definitions/missions/witness-window.json).

**Recommended resolution:** explicitly preserve the consented original recording while the accepted inquiry runs, or advertise a genuinely armed deadline with a recoverable failure outcome. State who holds the recording and when expiry resumes. No hidden timer or arbitrary new duration was added.

### F07 - Repeated structure and open offer gates need a pacing pass

**Consequence:** C09-C39 all unlock after one ordinary trade in their home region. Their numeric ordering and higher fees do not establish increasing difficulty. Thirty-one repeated return trips and similar two-proof settlements risk making the 64-source mystery feel like a checklist. Economic affordability, fatigue, equipment value and encounter difficulty have not been established by static review.

**Recommended resolution:** use the [recommended career progression](GAMEPLAY.md#recommended-learning-and-capability-progression) as guidance, show capability/risk requirements honestly, and preserve free choice. Review travel, distinct work and useful progression rewards in actual journeys. Vary mechanics only through explicit design; do not insert arbitrary kill quotas, hidden prior-campaign gates or a fake linear campaign order.

## Documentation corrections made during this review

- Generic recovery now preserves actual deaths and lost stock; only culling/unloading restores the same saved actor. A new escort cannot impersonate a dead named witness.
- Timer guidance names each clock domain. Opening a chart, gallery or radio dialog no longer promises a universal freeze; C05's explicitly armed continuous clock takes precedence.
- Campaign summary capability tags now describe actual objectives rather than detecting words such as “destruction” inside repeated recovery boilerplate.
- Career guidance distinguishes optional learning order, real ship/tool/cabin needs, independent offer gates, eight-galaxy travel and final reconstruction/purchase. Galaxy indices are labelled zero-based; player location keys remain one-based.
- All 43 structured references to the missing mission-artwork manifest now resolve to a portable 758-asset manifest. Its own hash is separate from the retained original source-manifest hash. No graphics were regenerated.
- SH163 Lammergeier is described as a pending pirate-hull design, not a station/environment object. Its authored nonflyable/pending access and missing statistics remain unchanged. Coverage byte metadata is computed from the final oracle rather than copied from an earlier version.

## Each campaign reviewed

“Coherent” below concerns cause, evidence, stage order and advertised alternatives. It does not waive F01/F05/F07 or establish native playability. The detailed concern in a row remains part of the verdict.

| Campaign | Narrative and progression check |
| --- | --- |
| [C01 The Glass Meridian](missions/C01.md) | Clock evidence precedes recorder audit, independent standard, calibration, clinic arrival and disclosure. **F03:** physical recorder custody is not fully represented in the generic item fields. |
| [C02 A Choir Beneath the Static](missions/C02.md) | Reference calibration precedes interpretation, consensual repair, listening and counterfeit shutdown. Peaceful shutdown and transmitter disable must both resolve the same named emitter proof; no ship kill is owed. |
| [C03 The Hollow Manifest](missions/C03.md) | Seal and wake evidence precede register reconciliation, live crew reception, remedy and kit return. The register is data; the existing one-tonne kit is not charged twice. |
| [C04 The Borrowed Voice](missions/C04.md) | Private witness contact legitimately precedes extraction. Both revocation and empty-decoy routes produce authenticated evidence before rekeying. Sol retry requires the actual surviving capsule, never resurrection. |
| [C05 The Shattered Wake](missions/C05.md) | Untimed warning/preparation precedes explicit arming, physical impacts, relief and inquiry. Both mitigation choices and all three station outcomes remain valid narrative endings. Runtime difficulty is unproven. |
| [C06 The Tithe of Worlds](missions/C06.md) | Informed permanent commission precedes resource proof, actual civilian delivery and three verified charter/severance settlements. Finite reserve losses and supplies must persist across travel. |
| [C07 The Still Current](missions/C07.md) | Cell/programmer exchange, technician reception and isolation precede settlement/audit. **F02:** fixed buffer settlement conflicts with permitted prior discharge. |
| [C08 Wayfarer Exchange](missions/C08.md) | Cold-chain, repair, seed and rescue receiving precede utility restoration and charter accreditation. **F04:** integrity budget lacks a numerical closed profile; later Ark/Rescue finite source rules also need the F01 recovery audit. |
| [C09 The Quiet Nursery](missions/C09.md) | Pressure observation precedes sealed culture test, grower arrival and independent/shared ventilation proof. Distinguish temporary culture installation from loan return. |
| [C10 Borrowed Dawn](missions/C10.md) | Illumination readings precede actuator stops, crew arrival and independent-segment/shared-rota proof. Publish the safe temperature envelope; do not arm a hidden parking countdown. |
| [C11 The Open Shadow](missions/C11.md) | Privacy and collision channels are measured separately before volunteer crossing and policy proof. Neither branch may suppress collision warning or expose private identities. |
| [C12 Harbour Without Orders](missions/C12.md) | External refusal evidence and temporary approach limits precede witness reception and restored authority. The emergency receiving berth must remain operational while ordinary allocators refuse access. |
| [C13 False Colours](missions/C13.md) | Cooperative identity evidence precedes verification escort and simultaneous revocation or supervised reissue. A transponder colour is never a lawful kill instruction. |
| [C14 The Rubble Covenant](missions/C14.md) | Mass/drift survey precedes anchors, actual clearance escort and pooled/bonded ownership proof. Tug work must conserve mass and momentum. |
| [C15 A Garden in Transit](missions/C15.md) | Climate readings precede test cradles, live seed-tender reception and custody/quarantine proof. Both receiving environments must suit actual living seed. |
| [C16 The Warrant Ledger](missions/C16.md) | Issuer signatures precede reconciliation, protected witness arrival and corrected warrants/hearing. The real suspect does not authorise violence against wrongly listed witnesses. |
| [C17 The Measure of Care](missions/C17.md) | Cold-chain readings precede sealed calibration, service crew arrival and local/shared calibration proof. No patient names need disclosure. |
| [C18 The Long Return](missions/C18.md) | Carrier evidence precedes handoff tests, reunion tender reception and shared/direct return proof. Consent can withhold a reunion; an escort arrival alone is not every carrier signature. |
| [C19 The Unfinished Map](missions/C19.md) | Dated records precede fresh boundary measurements, custodian reception and bounded-public/research archive proof. Published uncertainty must remain visible. |
| [C20 The Blue Reservoir](missions/C20.md) | Oxygen/flow measurements precede sealed bypass work, inspection arrival and distributed/shared containment proof. Do not solve low oxygen by silently deleting living filter material. |
| [C21 Mutual Shelter](missions/C21.md) | Physical berth survey precedes reservation, actual hauler reception and pooled/bonded reserve proof. The same berth cannot back two simultaneous obligations. |
| [C22 The Listening Frontier](missions/C22.md) | Independent human/Larvaal observations precede quiet windows, neutral witness and reciprocal acknowledgements. Migration is distinct from the designated hostile G15 force. |
| [C23 An Assembly of Orbits](missions/C23.md) | Consented occupancy/work records precede capacity tests, delegate arrival and worker-rota/bounded representation proof. Neither vote creates additional corridor capacity. |
| [C24 Under Tow](missions/C24.md) | Interface measurements precede coupling tests, genuine rescue reception and local-pairs/specialist service proof. Do not imply an unprovided player tractor tool. |
| [C25 The Memory Atlas](missions/C25.md) | Independent landmarks precede instrument comparison, custodian arrival and evidence/diary separation. Personal memories cannot silently become exact flight measurements. |
| [C26 A Fleet of Neighbours](missions/C26.md) | Actual hull/fuel commitments precede lane repair, dispatch arrival and arrived-hull rota/reserve proof. A promise or departed aid ship is not an arrived reinforcement. |
| [C27 Uncounted Names](missions/C27.md) | Private identity receipts precede permissions, living worker reception and protected/public register correction. People never become transferable commodities. |
| [C28 The Honest Circuit](missions/C28.md) | Beacon survey precedes actual corridor tests, calibration witness and efficiency/safety proof. Quantitative scoring/abort envelopes still require closed native profiles. |
| [C29 Small Lights](missions/C29.md) | Combined fault survey precedes module repair, maintenance arrival and pooled/reserved response proof. Each reserve requires actual funded stock. |
| [C30 The Passenger's Horizon](missions/C30.md) | Consented access measurements precede interface tests, assessment tender arrival and adaptable/reserved journey proof. The mission tender carries its own people; G04/G05 require player cabins. |
| [C31 The Kind Distance](missions/C31.md) | Private relay tests precede invitations, custodian reception and revocable reply proof. A successful settlement need not force either household to meet. |
| [C32 Cold Reserve](missions/C32.md) | Inventory evidence precedes dispatch isolation, inspection arrival and civilian conversion/dismantling proof. Expired authority is not a reason to manufacture reserve stock. |
| [C33 The Magnetic Orchard](missions/C33.md) | Passive field observation precedes consented human-tether release, witness arrival and protected boundaries/reserve proof. No living Larvaal organ is harvested. |
| [C34 Open Measure](missions/C34.md) | Independent loads precede actual fit tests, technician reception and open/reciprocal calibration proof. A matching label cannot substitute for a physical fit. |
| [C35 The Shared Pulse](missions/C35.md) | Independent listening precedes repair references, relay arrival and separated/shared acknowledgement proof. Finite reply budgets and actual cutoff prevent another feedback loop. |
| [C36 The Witness Window](missions/C36.md) | Authorised copies and keys precede witness reception and sealed/anonymised outcome. **F06:** threatened privacy expiry needs an explicit preservation/arming rule consistent with untimed preparation. |
| [C37 Public Record](missions/C37.md) | Independent routing evidence precedes comparison, witness arrival and anonymised release/right-of-reply proof. A reply deadline must not rewrite or erase the held evidence. |
| [C38 Signed Passage](missions/C38.md) | Allocation-time evidence precedes exact crate handoffs, witness arrival and receiving-lock/register proof. Stable l337.courier identity is separate from G01 dispatch. |
| [C39 The Guiding Light](missions/C39.md) | Shadow sight lines precede winter relay work, actual lit-berth arrival and maintenance/rota proof. Shadow geometry must be accessible during ordinary play without real-world seasonal waiting. |

## Each contract, lesson and continuing service reviewed

All these sources retain their own distinct clue. The common three-stage accept/perform/receive wrapper is structurally coherent; it must be joined to the actual operation below rather than accepting a generic success flag. Exact closed native profiles and finite failure recovery remain subject to F01/F05.

| Source | Progression and receiving check |
| --- | --- |
| G01 Sealed dispatch | Low-entry income: one actual tonne, no deposit/deadline; correct sender/receiver and real fuel costs. G01 later closed profile governs concrete rows. |
| G02 Consented freight supply | Eight actual tonnes from finite supplier stock; return to consenting receiver; reserve aggregate hold with other jobs. |
| G03 Bonded freight passage | Three tonnes and refundable 75 CR bond; separate principal refund from earned fee and preserve real liabilities. |
| G04 Consented cabin journey | Two consenting living passengers in compatible fitted places; G04 later Avenor-Renas route/610 CR profile; no cargo-as-cabin substitute. |
| G05 Orbital outlook journey | Two passengers, three ordered real viewing scans, living return to origin; later G05 round trip/870 CR profile; consent covers full itinerary. |
| G06 Verified hostile warrant | One specifically warranted armed aggressor and player-attributed destruction; innocent identity lookalikes do not qualify. |
| G07 Registered corridor defence | Three distinct designated hostile neutralisations and actual safe corridor reception; avoid treating arbitrary casualties as progress. |
| G08 Consented custody rescue | Two living rescued people, two compatible places and one-tonne record; capsule recovery, voluntary boarding and actual receiving are separate. |
| G09 Identified salvage return | Two tonnes of exact recoverable owned equipment; real tools/collection and owner handoff, not generic salvage cargo. |
| G10 Consented orbital survey | Three distinct 12-second consented scans; later G10 profile supplies actual geometry/observation requirements. |
| G11 External isolation work | Two actual external isolations and same-original programmer return; 970 CR closed route; F01 lifetime-source risk. |
| G12 Measured asteroid extraction | Twelve tonnes with real extraction/refinement provenance; capacity includes installed tools and other reservations. |
| G13 Mutual relief contribution | Real voluntary 500 CR donation to actual recipient; no cash reward; genuine acknowledgement grants its distinct clue. |
| G14 Registered orbital evacuation | Four living survivors and four compatible fitted places; actual boarding/reception and persistent losses. |
| G15 Designated hostile Larvaal defence | Two specifically hostile Larvaal actors and real civilian safe arrival; no blanket alien kill licence. |
| T01 Flight and reception practice | Safe flight/alignment and real training berth; no reset of career, payment or fictitious practice arrival. |
| T02 Safe gunnery practice | Three distinct uncrewed target hits and cease-fire; no bounty, legal offence or real combat score. |
| T03 Defensive flight practice | Manual centre acquisition, ordered lateral gates and safe withdrawal; no firing, AUTO/Tab substitute or T02 prerequisite. |
| T04 Navigation and trade practice | Actual affordable legal one-tonne buy, travel and sale; real fuel and price difference, no invented guaranteed profit. |
| W01 Cold-chain clinic service | Sealed medical sample and preserved usable quality; F04 numerical variant/decay needs closure. |
| W02 Closed repair exchange | Failed unit goes to service and the same identified serviced unit returns to its owner; no duplicate replacement issue. |
| W03 Seed-bank transfer | Three tonnes of consented living seed; genuine donor/receiver custody and viability; not the C08 seed-ark clue. |
| W04 Remote utility relief | Four tonnes of real relief material and working utility receiving handoff; no promise creates installed repair. |
| W05 Crew record recovery | One actual flight/custody recorder received; recovering evidence never creates living survivors. |
| W06 Registered convoy watch | Actual registered convoy, finite cargo and real arrival; generic same-type hull or culling is insufficient. |

## Limits of this review

All mission premises, stage objectives, explicit branch alternatives, offer/reward conditions and declared custody sequences were reviewed. Static checks establish internal references and reachability, not safe flight, combat balance, stock availability, affordability across an entire career, collision clearance or useful UX. The 171 ship reference values and missing-stat estimates are not certified physical calibration. Resolve the findings above and exercise real branch/failure/save/receiving journeys before calling overall gameplay progression verified.
