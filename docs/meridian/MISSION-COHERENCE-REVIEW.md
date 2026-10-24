# Mission coherence and gameplay progression review

This review checks the intended finished game against the [oracle](FINAL-GAME-ORACLE.md), all portable mission definitions and the later source contracts recorded in [the source evidence](references/mission-review-source-evidence.json). It covers all 39 campaigns and 368 stages, 15 general families, four tutorials, six Wayfarer families and the seven-step finale. It is a documentation and design review, not a runtime playthrough or a claim that the game implements these definitions. Implementation ownership and scheduling remain exclusively in the main project ledger; finding labels here identify evidence, not new work packets.

**Conclusion:** all seven issues now have explicit design resolutions. The supplied review's two principal concerns are addressed by guaranteed continuity inquiries for all64 sources and31 distinct C09-C39 interaction profiles, mission-specific activity phases and mostly concurrent witness journeys. This is a specification verdict: the new mechanisms still require native implementation, boundary tests and play balancing. The runtime audit remains separately scoped to its frozen source baseline.

## Verified structure

- All 368 campaign stages have unique stage identities within their campaign, the expected next transition and a reachable terminal. Every explicit branch variant refers to an earlier choice and covers its declared choice IDs.
- All stage galaxy/system/name/key joins match the original world snapshots. Each of the eight ordinary 256-system galaxies is connected through jumps of at most 7 LY. This permits intermediate refuelling stops; it does not promise a direct jump, funded fuel, station stock, safe passage or an eligible doorway.
- Declared campaign item-effect sequences neither remove an unheld item nor duplicate an issue, and release their declared loans. Peak declared protected mission-item overlap is1.008tonnes in C01 (one-tonne standard plus8kg original recorder); other declared serial loans peak at one tonne. This remains a static accounting result, not proof that every live physical operation is implemented.
- The 39 campaign clues, 15 general-family clues, six Wayfarer clues and four tutorial clues give exactly 64 unique source IDs and 64 unique clue IDs. Both required sets match the finale exactly. Its epilogue evidence is not its own prerequisite.
- All seven finale transitions agree: decode -> listener -> ring -> lanterns -> cradle -> credited Medusa destruction -> later PLUGH reconstruction. Purchase is a separate paid transaction. A lost/uncredited encounter retries the unlocked checkpoint without recollecting clues.
- Scope remains orbital/space operations and station receiving. No review correction introduces a surface visit or ground operation.

The [machine-readable structural receipts](MISSION-REVIEW-CHECKS.json) record each campaign definition hash and the exact scope of these checks.

## Findings, resolutions and remaining recommendations

### F01 - Resolved design: required clues always retain a completion path

[The continuity policy](missions/gameplay/recovery-policy.json) supplies all64 original sources with a real separately scoped inquiry available at a charter orbital desk and the missing-clue journal. It has no credit, rank, reputation, stock, purchased-tool, original station or surviving-person gate. It uses genuine pre-offer replicated observations, new actual measurements, a source-specific non-consumable physical test and independent receiving. Original failures, deaths, station loss, cargo loss and original fee/reward receipts persist. The original mission is never retrospectively successful. Failure itself awards no clue; the successful new inquiry commits the same canonical source clue once. This explicit alternative supersedes the earlier no-pacifist-shortcut restriction for clue recovery only.

The finite funded replacement/remedial option remains available separately, including an explicit mass-conserved G11 production generation. It cannot be the only path because resources or money may be exhausted. New native acceptance must verify that every missing clue retains a reachable eligible path after ordinary failure, cancellation, depletion, station loss, faction hostility and save/load. This is a design correction, not an implemented runtime feature.

### F02 - Resolved portable omission: Still Current's community transfer restriction

The earlier review treated permitted discharge and the fixed 300+600 settlement as an unresolved contradiction. The existing accepted Still Current contract already resolves it: line 11 permits only the 300-unit delivery and 600-unit retained buffer on the community route, forbidding optional discharge there. The material-recovery route accounts for storage and controlled discharge. The rule is now copied into the [portable energy rules](missions/definitions/still-current.json) and C07 reading view. Its exact source hash and excerpt remain in the [source evidence](references/mission-review-source-evidence.json). No balance value or accepted rule changed. The actual C07 native workflow remains unimplemented at the audited candidate.

### F03 - Resolved design: original recorder custody and final archive

The [C01 definition](missions/definitions/glass-meridian.json) now declares the original recorder as0.008tonnes, with exact recovery add effect, retained custody through the booking audit and later stages, and an atomic archive removal at `close-case`. Captain Venn at Avenor is its explicit final custodian. Peak overlap with the one-tonne timing standard is1.008tonnes. The source's8kg/Scoops rule is preserved; choosing the final archive is the new disclosed design resolution. A zero-mass clue/data copy cannot substitute for the original. Genuine loss uses independent continuity evidence without cloning it. Native pickup already accounted for8kg at the audited candidate; its later final archive remains new work.

### F04 - Resolved portable omission: existing native integrity allowances

The earlier review correctly found omitted numerical profiles in the portable definitions but had not checked the later native implementation. The game source already specifies C08's 1,800 armed-flight-second allowance, and the closed W01 cold-chain/W03 seed-transfer profiles independently specify 2,700 seconds. These existing terms are now in the [C08 definition](missions/definitions/wayfarer-exchange.json), [service definitions](missions/definitions/wayfarer-services.json) and reading views, with their original route/clock scope. See the [mechanics audit](GAME-MECHANICS-SUPPORT.md#correction-to-the-prior-coherence-review) for exact source links. No guessed timer was added. General variants still require their own closed terms, and real finite stock/failure recovery remains subject to F01/F05.

### F05 - Resolved design: distinct measurable operation profiles

[All31 C09-C39 profiles](missions/gameplay/campaign-profiles.json) now specify their actual survey/work/branch target joins, parameters, operating modes, functional tests, physical envelopes, finite apparatus and witness obligations. They use31 different interaction styles: piloted gates, optical alignment, pressure traces, tug coordination, berth arbitration, custody chains, accessible interfaces, signature replay, private consent, flow routing and bounded relay timing among them. A generic hover or contact confirmation cannot complete them. Several measured-event operations explicitly have no generic work countdown.

The [controlling specification](missions/gameplay/GAMEPLAY-SPECIFICATION.md) supplies persisted spatial fixtures, calibration requirements, normal input behaviour, measurements, failure feedback and positive/negative native acceptance obligations. New numerical defaults are estimates awaiting balancing. Original families retain their individually copied accepted closed operation contracts. Unsupported producers must be implemented before claiming playability; the bounded runtime schema does not automatically load authoring JSON.

### F06 - Resolved design: Witness Window preservation precedes its offer

The [C36 definition](missions/definitions/witness-window.json) requires a witness-consented original/version/hash preservation hold before the offer appears. It has no hidden preparation or investigation expiry, survives abandonment without granting a clue, and closes only through actual authorised archive receiving or consented anonymised publication. Privacy remains protected. Genuine archive loss invokes corroborated continuity evidence rather than invented surviving records. C37 separately arms its advertised local right-of-reply test and cannot erase preserved evidence on expiry.

### F07 - Resolved design: varied activities and shorter repetitive travel

C09-C39 now collect their original reference before departure, perform their distinctive operation, and choose with authorised arrived delegates at the actual witness receiver before one final issuer audit. Most witness journeys run concurrently with field work; five retain explicit player accompaniment. Three to six mission-specific journal phases group nine internal receipt stages without forcing nine repeated dialogue screens. Course flight, listening, traffic/capacity trials, diagnosis, consent and cargo transfer have different primary controls and success feedback. Tier labels recommend preparation without inventing mandatory campaign order. Engagement and balance still need real playtesting; a distinct profile is not a claim about tested enjoyment.

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
| [C07 The Still Current](missions/C07.md) | Cell/programmer exchange, technician reception and isolation precede settlement/audit. F02 corrected: community-buffer forbids optional discharge; material recovery accounts for actual storage/discharge. The native C07 workflow is still missing. |
| [C08 Wayfarer Exchange](missions/C08.md) | Cold-chain, repair, seed and rescue receiving precede utility restoration and charter accreditation. F04 corrected: existing C08 native allowance is 1,800 flight seconds; Ark/Rescue finite failures still need the F01 recovery audit. |
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
| [C28 The Honest Circuit](missions/C28.md) | Beacon survey precedes actual corridor tests, calibration witness and efficiency/safety proof. Its new closed profile defines speed, ordered gates, traffic separation and abort; native implementation/play balancing remain required. |
| [C29 Small Lights](missions/C29.md) | Combined fault survey precedes module repair, maintenance arrival and pooled/reserved response proof. Each reserve requires actual funded stock. |
| [C30 The Passenger's Horizon](missions/C30.md) | Consented access measurements precede interface tests, assessment tender arrival and adaptable/reserved journey proof. The mission tender carries its own people; G04/G05 require player cabins. |
| [C31 The Kind Distance](missions/C31.md) | Private relay tests precede invitations, custodian reception and revocable reply proof. A successful settlement need not force either household to meet. |
| [C32 Cold Reserve](missions/C32.md) | Inventory evidence precedes dispatch isolation, inspection arrival and civilian conversion/dismantling proof. Expired authority is not a reason to manufacture reserve stock. |
| [C33 The Magnetic Orchard](missions/C33.md) | Passive field observation precedes consented human-tether release, witness arrival and protected boundaries/reserve proof. No living Larvaal organ is harvested. |
| [C34 Open Measure](missions/C34.md) | Independent loads precede actual fit tests, technician reception and open/reciprocal calibration proof. A matching label cannot substitute for a physical fit. |
| [C35 The Shared Pulse](missions/C35.md) | Independent listening precedes repair references, relay arrival and separated/shared acknowledgement proof. Finite reply budgets and actual cutoff prevent another feedback loop. |
| [C36 The Witness Window](missions/C36.md) | Authorised copies and keys precede witness reception and sealed/anonymised outcome. F06 resolved: a consented pre-offer preservation hold removes hidden expiry. |
| [C37 Public Record](missions/C37.md) | Independent routing evidence precedes comparison, witness arrival and anonymised release/right-of-reply proof. A reply deadline must not rewrite or erase the held evidence. |
| [C38 Signed Passage](missions/C38.md) | Allocation-time evidence precedes exact crate handoffs, witness arrival and receiving-lock/register proof. Stable l337.courier identity is separate from G01 dispatch. |
| [C39 The Guiding Light](missions/C39.md) | Shadow sight lines precede winter relay work, actual lit-berth arrival and maintenance/rota proof. Shadow geometry must be accessible during ordinary play without real-world seasonal waiting. |

## Each contract, lesson and continuing service reviewed

All these sources retain their own distinct clue. The common three-stage accept/perform/receive wrapper is structurally coherent; it must be joined to the actual operation below rather than accepting a generic success flag. Accepted closed source profiles are bundled; guaranteed clue continuity is specified separately under F01, and new native producers still require implementation.

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
| W01 Cold-chain clinic service | Sealed medical sample and preserved usable quality; Existing closed W01 allowance is 2,700 flight seconds; different variants require their own terms. |
| W02 Closed repair exchange | Failed unit goes to service and the same identified serviced unit returns to its owner; no duplicate replacement issue. |
| W03 Seed-bank transfer | Three tonnes of consented living seed; genuine donor/receiver custody and viability; not the C08 seed-ark clue. |
| W04 Remote utility relief | Four tonnes of real relief material and working utility receiving handoff; no promise creates installed repair. |
| W05 Crew record recovery | One actual flight/custody recorder received; recovering evidence never creates living survivors. |
| W06 Registered convoy watch | Actual registered convoy, finite cargo and real arrival; generic same-type hull or culling is insufficient. |

## Limits of this review

All mission premises, stage objectives, explicit branch alternatives, offer/reward conditions and declared custody sequences were reviewed. Static checks establish internal references and reachability, not safe flight, combat balance, stock availability, affordability across an entire career, collision clearance or useful UX. The 171 ship reference values and missing-stat estimates are not certified physical calibration. Implement the resolved designs and exercise real branch/failure/save/receiving journeys before calling overall gameplay progression verified.

## Supplied review and consolidation

The user supplied the external review text directly after its shared URL failed to expose readable content. Its two principal mission findings are resolved above as design decisions. Artwork roles remain distinct: cinematic briefing illustrations, contact portraits, simpler operational objects/evidence and technical ship references. No reference image is represented as a renderer screenshot. The implementation guide and read-only ledger copy live in [implementation/](implementation/README.md); the live ledger alone owns work packets.
