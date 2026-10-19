# Original fleet specification reference

Authored capability and purchase policy are design data; they do not establish runtime readiness or a shipped feature.

All values remain unconverted. Raw authored units are used unless the supplied native field contract declares a unit. No historical balance or geometry is read.

## Index

| ID | Name | Family | Role | Authored flyable | Mesh | Runtime ready | Purchase policy | Cost (credits) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SH001 | Mule | mule | trader | true | true | false | blueprintFabrication | 216000 |
| SH002 | Gyrfalcon Assault | gyrfalcon | military | true | false | false | blueprintFabrication | 259000 |
| SH003 | Gyrfalcon Command | gyrfalcon | military | true | false | false | blueprintFabrication | 259000 |
| SH004 | Gyrfalcon Patrol | gyrfalcon | military | true | false | false | blueprintFabrication | 259000 |
| SH005 | Bison | bison | transporter | true | true | false | blueprintFabrication | 690000 |
| SH006 | Bison Mk II | bison | transporter | true | true | false | blueprintFabrication | 761000 |
| SH007 | Impala Voyager | impala | leisure | true | false | false | blueprintFabrication | 208000 |
| SH008 | Goshawk Explorer | goshawk | leisure | true | true | false | blueprintFabrication | 211000 |
| SH009 | Goshawk Mk II | goshawk | military | true | true | false | blueprintFabrication | 281000 |
| SH010 | Goshawk Mk II Custom | goshawk | military | true | true | false | blueprintFabrication | 281000 |
| SH011 | Goshawk Scout | goshawk | military | true | true | false | blueprintFabrication | 262000 |
| SH012 | Sable Liner | sable-liner | leisure | true | false | false | blueprintFabrication | 212000 |
| SH013 | Buffalo | buffalo | transporter | true | true | false | blueprintFabrication | 424000 |
| SH014 | Buffalo Mk II | buffalo | transporter | true | true | false | blueprintFabrication | 465000 |
| SH015 | Raven | raven | pirate | true | true | false | blueprintFabrication | 208000 |
| SH016 | Mole Miner | mole | miner | true | true | false | blueprintFabrication | 242000 |
| SH017 | Mole Prospector | mole | miner | true | true | false | blueprintFabrication | 242000 |
| SH018 | Donkey | donkey | trader | true | false | false | blueprintFabrication | 209000 |
| SH019 | Gazelle Explorer | gazelle | leisure | true | false | false | blueprintFabrication | 212000 |
| SH020 | Crow Prototype | crow | pirate | true | true | false | blueprintFabrication | 216000 |
| SH021 | Zebra | zebra | trader | true | true | false | blueprintFabrication | 226000 |
| SH022 | Peregrine Mk I | peregrine | trader | true | true | false | blueprintFabrication | 215000 |
| SH023 | Peregrine Mk III | peregrine | trader | true | true | false | blueprintFabrication | 246000 |
| SH024 | Peregrine Mk IV | peregrine | trader | true | true | false | blueprintFabrication | 261000 |
| SH025 | Peregrine Mk V | peregrine | trader | true | true | false | blueprintFabrication | 274000 |
| SH026 | Harrier | harrier | military | true | true | false | blueprintFabrication | 259000 |
| SH027 | Ibex | ibex | trader | true | false | false | blueprintFabrication | 209000 |
| SH028 | Lion Citadel | lion-citadel | station | false | true | false | never | not authored |
| SH029 | Burro | burro | trader | true | false | false | blueprintFabrication | 220000 |
| SH030 | Sparrowhawk | sparrowhawk | bountyHunter | true | false | false | blueprintFabrication | 250000 |
| SH031 | Kite Interceptor | kite | military | true | false | false | blueprintFabrication | 265000 |
| SH032 | Panther Explorer | panther | leisure | true | false | false | blueprintFabrication | 205000 |
| SH033 | Panther Scout | panther | military | true | false | false | blueprintFabrication | 257000 |
| SH034 | Frog Station | frog | station | false | true | false | never | not authored |
| SH035 | Stag Liner | stag | leisure | true | false | false | blueprintFabrication | 217000 |
| SH036 | Zebu | zebu | trader | true | false | false | blueprintFabrication | 217000 |
| SH037 | Vulture Mk I | vulture | pirate | true | true | false | blueprintFabrication | 213000 |
| SH038 | Vulture Mk II | vulture | pirate | true | true | false | blueprintFabrication | 220000 |
| SH039 | Vulture Mk III | vulture | pirate | true | true | false | blueprintFabrication | 228000 |
| SH040 | Newt Escape Pod | newt-escape-pod | capsule | true | true | false | never | 0 |
| SH041 | Serval Fighter | serval | military | true | false | false | blueprintFabrication | 262000 |
| SH042 | Saker | saker | military | true | false | false | blueprintFabrication | 265000 |
| SH043 | Eagle Cruiser | eagle | military | true | false | false | never | 0 |
| SH044 | Harpy Assault | harpy | military | true | false | false | blueprintFabrication | 265000 |
| SH045 | Erne Corvette | erne | military | true | false | false | blueprintFabrication | 276000 |
| SH046 | Harpy Dropship | harpy | military | true | false | false | blueprintFabrication | 265000 |
| SH047 | Harpy Gunship | harpy | military | true | false | false | blueprintFabrication | 265000 |
| SH048 | Lanner | lanner | bountyHunter | true | true | false | blueprintFabrication | 246000 |
| SH049 | Hyena | hyena | pirate | true | true | false | blueprintFabrication | 214000 |
| SH050 | Yak | yak | trader | true | true | false | blueprintFabrication | 217000 |
| SH051 | Jackal | jackal | pirate | true | true | false | blueprintFabrication | 212000 |
| SH052 | Percheron | percheron | trader | true | true | false | blueprintFabrication | 208000 |
| SH053 | Percheron Prototype | percheron | military | true | true | false | blueprintFabrication | 257000 |
| SH054 | Hobby Fighter | hobby | military | true | false | false | blueprintFabrication | 259000 |
| SH055 | Condor | condor | pirate | true | false | false | blueprintFabrication | 208000 |
| SH056 | Aplomado Interceptor | aplomado | military | true | false | false | blueprintFabrication | 262000 |
| SH057 | Falconet | falconet | military | true | false | false | blueprintFabrication | 262000 |
| SH058 | Brabant | brabant | transporter | true | false | false | blueprintFabrication | 463000 |
| SH059 | Barbary | barbary | military | true | false | false | blueprintFabrication | 261000 |
| SH060 | Wombat | wombat | miner | true | true | false | blueprintFabrication | 235000 |
| SH061 | Haflinger | haflinger | trader | true | true | false | blueprintFabrication | 216000 |
| SH062 | Moose Clipper | moose | transporter | true | false | false | blueprintFabrication | 397000 |
| SH063 | Seriema Courier | seriema | military | true | true | false | blueprintFabrication | 262000 |
| SH064 | Arna Cutter | arna | transporter | true | false | false | blueprintFabrication | 397000 |
| SH065 | Vulture Raider | vulture | pirate | true | false | false | blueprintFabrication | 213000 |
| SH066 | Rabbit Explorer | rabbit | leisure | true | true | false | blueprintFabrication | 205000 |
| SH067 | Rhinoceros Trader | rhinoceros | trader | true | true | false | blueprintFabrication | 220000 |
| SH068 | Badger | badger | miner | true | false | false | blueprintFabrication | 242000 |
| SH069 | Baza Fighter | baza | military | true | false | false | blueprintFabrication | 259000 |
| SH070 | Baza Mk II | baza | bountyHunter | true | false | false | blueprintFabrication | 261000 |
| SH071 | Griffon | griffon | pirate | true | true | false | blueprintFabrication | 216000 |
| SH072 | Griffon Mk II | griffon | pirate | true | true | false | blueprintFabrication | 230000 |
| SH073 | Griffon Spectre | griffon | pirate | true | true | false | blueprintFabrication | 216000 |
| SH074 | Dzo | dzo | transporter | true | false | false | blueprintFabrication | 424000 |
| SH075 | Dzo Mk II | dzo | transporter | true | false | false | blueprintFabrication | 465000 |
| SH076 | Hog | hog | transporter | true | true | false | blueprintFabrication | 463000 |
| SH077 | Tamaraw | tamaraw | transporter | true | false | false | blueprintFabrication | 424000 |
| SH078 | Oryx Voyager | oryx-voyager | leisure | true | false | false | blueprintFabrication | 211000 |
| SH079 | Carabao Carrier | carabao | transporter | true | false | false | blueprintFabrication | 580000 |
| SH080 | Carabao Highliner | carabao | transporter | true | false | false | blueprintFabrication | 580000 |
| SH081 | Jaguar | jaguar | military | true | false | false | never | 0 |
| SH082 | Cheetah | cheetah | bountyHunter | true | true | false | blueprintFabrication | 246000 |
| SH083 | Hare Explorer | hare | leisure | true | false | false | blueprintFabrication | 211000 |
| SH084 | Llama | llama | trader | true | false | false | blueprintFabrication | 209000 |
| SH085 | Laggar | laggar | bountyHunter | true | false | false | blueprintFabrication | 249000 |
| SH086 | Alpaca | alpaca | trader | true | true | false | blueprintFabrication | 226000 |
| SH087 | Elk | elk | trader | true | true | false | blueprintFabrication | 226000 |
| SH088 | Springbok Starliner | springbok | leisure | true | true | false | blueprintFabrication | 208000 |
| SH089 | Antelope | antelope | trader | true | true | false | blueprintFabrication | 209000 |
| SH090 | Elephant | elephant | trader | true | true | false | blueprintFabrication | 220000 |
| SH091 | Gopher | gopher | miner | true | false | false | blueprintFabrication | 242000 |
| SH092 | Aubrac | aubrac | trader | true | true | false | blueprintFabrication | 209000 |
| SH093 | Giraffe Liner | giraffe | leisure | true | false | false | blueprintFabrication | 218000 |
| SH094 | Ictinia | ictinia | military | true | true | false | blueprintFabrication | 265000 |
| SH095 | Ictinia X | ictinia | military | true | true | false | blueprintFabrication | 265000 |
| SH096 | Wisent | wisent | transporter | true | true | false | blueprintFabrication | 286000 |
| SH097 | Wisent Mk II | wisent | transporter | true | true | false | blueprintFabrication | 311000 |
| SH098 | Anoa | anoa | transporter | true | true | false | blueprintFabrication | 397000 |
| SH099 | Ox | ox | transporter | true | true | false | blueprintFabrication | 429000 |
| SH100 | Ox Mk II | ox | transporter | true | true | false | blueprintFabrication | 472000 |
| SH101 | Dorcas Racer | dorcas-racer | leisure | true | false | false | blueprintFabrication | 217000 |
| SH102 | Dhole Haven | dhole | station | false | true | false | never | not authored |
| SH103 | Redtail Mk III | redtail | bountyHunter | true | false | false | blueprintFabrication | 287000 |
| SH104 | Wildebeest | wildebeest | trader | true | true | false | blueprintFabrication | 226000 |
| SH105 | Tapir Shuttle | tapir | transporter | true | true | false | blueprintFabrication | 440000 |
| SH106 | Tapir Mk II | tapir | transporter | true | true | false | blueprintFabrication | 482000 |
| SH107 | Magpie | magpie | pirate | true | true | false | blueprintFabrication | 216000 |
| SH108 | Besra | besra | bountyHunter | true | false | false | blueprintFabrication | 258000 |
| SH109 | Hippo | hippo | trader | true | false | false | blueprintFabrication | 208000 |
| SH110 | Leopard Fighter | leopard | military | true | false | false | blueprintFabrication | 259000 |
| SH111 | Puma | puma | military | true | false | false | blueprintFabrication | 257000 |
| SH112 | Larvaal Warden | larvaal-warden | alien | true | false | false | blueprintFabrication | 280000 |
| SH113 | Larvaal Ravager | larvaal-ravager | alien | true | false | false | blueprintFabrication | 280000 |
| SH114 | Larvaal Sentinel | larvaal-sentinel | alien | true | false | false | blueprintFabrication | 271000 |
| SH115 | Larvaal Lancer | larvaal-lancer | alien | true | false | false | blueprintFabrication | 271000 |
| SH116 | Larvaal Broodlord | larvaal-broodlord | alien | true | false | false | blueprintFabrication | 281000 |
| SH117 | Larvaal Provoker | larvaal-provoker | alien | true | false | false | blueprintFabrication | 288000 |
| SH118 | Larvaal Reaver | larvaal-reaver | alien | true | false | false | blueprintFabrication | 288000 |
| SH119 | Larvaal Wraith | larvaal-wraith | alien | true | false | false | blueprintFabrication | 273000 |
| SH120 | Larvaal Seeker | larvaal-seeker | alien | true | false | false | blueprintFabrication | 281000 |
| SH121 | Larvaal Mender | larvaal-mender | alien | true | false | false | blueprintFabrication | 295000 |
| SH122 | Larvaal Harvester | larvaal-harvester | alien | true | false | false | blueprintFabrication | 288000 |
| SH123 | Larvaal Sovereign | larvaal-sovereign | alien | true | true | false | never | 0 |
| SH124 | Larvaal Warship | larvaal-warship | alien | true | true | false | blueprintFabrication | 280000 |
| SH125 | Larvaal Drone | larvaal-drone | alien | true | true | false | blueprintFabrication | 295000 |
| SH126 | Mangalica | mangalica | trader | true | false | false | blueprintFabrication | 209000 |
| SH127 | Gaur Trader | gaur | trader | true | true | false | blueprintFabrication | 209000 |
| SH128 | Boar Transport | boar | transporter | true | true | false | blueprintFabrication | 396000 |
| SH129 | Warthog 10 Guard | warthog-10-guard | military | true | false | false | blueprintFabrication | 320000 |
| SH130 | Marmot 11 Prospector | marmot | miner | true | false | false | blueprintFabrication | 317000 |
| SH131 | Warthog 6 | warthog-10-guard | transporter | true | false | false | blueprintFabrication | 440000 |
| SH132 | Warthog 7 | warthog-10-guard | transporter | true | false | false | blueprintFabrication | 440000 |
| SH133 | Warthog 8 | warthog-10-guard | transporter | true | false | false | blueprintFabrication | 440000 |
| SH134 | Warthog 9 Heavy | warthog-10-guard | transporter | true | false | false | blueprintFabrication | 440000 |
| SH135 | Javelina | javelina | trader | true | false | false | blueprintFabrication | 220000 |
| SH136 | Falcon Mk I | falcon | military | true | true | false | blueprintFabrication | 255000 |
| SH137 | Falcon Mk II | falcon | military | true | true | false | blueprintFabrication | 268000 |
| SH138 | Falcon Mk III | falcon | military | true | true | false | blueprintFabrication | 281000 |
| SH139 | Falcon Mk IV | falcon | military | true | true | false | blueprintFabrication | 295000 |
| SH140 | Chimango | chimango | bountyHunter | true | false | false | blueprintFabrication | 252000 |
| SH141 | Salamander Station | salamander-station | station | false | false | false | never | not authored |
| SH142 | Buzzard Mk II | buzzard | bountyHunter | true | true | false | blueprintFabrication | 263000 |
| SH143 | Aardvark Miner | aardvark | miner | true | true | false | blueprintFabrication | 253000 |
| SH144 | Razorback | razorback | trader | true | false | false | blueprintFabrication | 208000 |
| SH145 | Kestrel | kestrel | military | true | false | false | blueprintFabrication | 263000 |
| SH146 | Merlin | merlin | military | true | false | false | blueprintFabrication | 263000 |
| SH147 | Hawk | hawk | military | true | false | false | blueprintFabrication | 262000 |
| SH148 | Morepork | morepork | military | true | true | false | blueprintFabrication | 259000 |
| SH149 | Owlet Mk II | owlet | bountyHunter | true | true | false | blueprintFabrication | 266000 |
| SH150 | Reindeer Freighter | reindeer | transporter | true | true | false | blueprintFabrication | 456000 |
| SH151 | Lynx Escort | lynx | military | true | true | false | blueprintFabrication | 261000 |
| SH152 | Osprey Scout | osprey | military | true | true | false | blueprintFabrication | 265000 |
| SH153 | Osprey Strike | osprey | military | true | true | false | blueprintFabrication | 259000 |
| SH154 | Osprey Patrol | osprey | military | true | true | false | blueprintFabrication | 261000 |
| SH155 | Osprey Carrier | osprey | military | true | true | false | blueprintFabrication | 261000 |
| SH156 | Lion Bastion | lion-bastion | platform | false | true | false | never | not authored |
| SH157 | Wolf Scout | wolf | military | true | true | false | blueprintFabrication | 276000 |
| SH158 | Wolf Mk I | wolf | military | true | true | false | blueprintFabrication | 268000 |
| SH159 | Wolf Mk II | wolf | military | true | true | false | blueprintFabrication | 288000 |
| SH160 | Wolf Cutter | wolf | military | true | true | false | blueprintFabrication | 265000 |
| SH161 | Wolf Citadel | wolf | station | false | true | false | never | not authored |
| SH162 | Larvaal Probe | larvaal-probe | other | false | true | false | never | not authored |
| SH163 | Lammergeier | lammergeier | pirate | false | true | false | pendingFabrication | not authored |
| SH164 | Toad Drug Factory | toad-drug-factory | station | false | true | false | never | not authored |
| SH165 | Secretarybird | secretarybird | military | true | true | false | blueprintFabrication | 259000 |
| SH166 | Camel Rescue | camel | transporter | true | true | false | blueprintFabrication | 416000 |
| SH167 | Secretarybird Survey | secretarybird | military | true | true | false | blueprintFabrication | 262000 |
| SH168 | Armadillo Miner | armadillo | miner | true | true | false | blueprintFabrication | 224000 |
| SH169 | Caracara Mk I | caracara | military | true | true | false | blueprintFabrication | 259000 |
| SH170 | Caracara Mk II | caracara | military | true | true | false | blueprintFabrication | 272000 |
| SH171 | Medusa | medusa | alien | true | true | false | plughQuestFabrication | 288000 |

## Integration dependency definitions

### approved-original-mesh-missing

No approved replacement hull with this exact ID was supplied. Spec remains staged without any joined mesh or legacy fallback.

### approved-original-native-geometry-adapter

The approved original hull's nativeDesign is retained only in original-hulls, not copied into joined runtime candidates or mapped to old nativeHull enums. Integrate this original geometry deliberately without preserving superseded NPC blueprints.

### authored-texture-adapter

Proposal design.textures/faceTextures are not current ShipDesign fields. Preserve them but implement the original asset/UV adapter and bundle declared original assets before claiming texture rendering; no bitmap assets were supplied here. Authored untextured -1 mappings can contain corner UV placeholders, unlike current archival sourceFaceTextures which require empty UVs for -1. Never blindly relabel them as archival imported sourceTextures/sourceFaceTextures.

### catalogue-metadata

Current CatalogueShip requires shipClass, appearances, evidence, refit, geometryContext, profiles and catalogue. Authored root family/role/playerFlyable/purchasePolicy are preserved but do not fill catalogue schemaVersion=2, access, habitat, encounter, collection or purchase gates. Original policy authoring/integration is required; no legacy defaults are copied.

### hull-spec-metadata-difference

The approved spec and hull proposal share the exact ID but differ in name/family metadata. Joined identity uses the spec authority; original hull metadata is preserved unchanged. Reconcile this explicit authored difference centrally without renaming IDs or inventing geometry.

### original-cargo-and-accommodation-contract

Current validEffectiveCargo requires exactly one historical project-refit-v1 or liberator-native-v1 profile; ShipAccommodationProfile also depends on those historical fields. An original authority/validator change is required. Do not manufacture historical profiles to bypass these guards.

### remove-legacy-SH171-exclusivity

Current catalogue validation hardcodes SH171 to xyzzyOnly and no normal discovery. This conflicts with the approved Medusa PLUGH-quest fabrication policy and requires coordinated native policy changes.

### unit-scale-authority

Preserve all authored game values verbatim. Specs provide no separate unit/scale declaration; central integration must confirm each native field's unit and balance scale. Do not apply historical source-refit ratios or catalogue&#95;balance.

### unsupported-purchase-policy

The authored policy is not in the current ShipCataloguePurchasePolicy enum. Implement the real policy gate; do not substitute blueprintFabrication/never/xyzzyOnly.

## SH001: Mule

Family: mule. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `510d7be41315c34f30108c4b07a21e88187db778529deddaa0206124f765d842`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 64 | t |
| speed | 34.8 | raw authored units |
| acceleration | 9.6 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.78 | raw authored units |
| roll | 0.88 | raw authored units |
| pitch | 0.77 | raw authored units |
| yaw | 0.72 | raw authored units |
| shield | 240 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH002: Gyrfalcon Assault

Family: gyrfalcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `995aae5486d05c6815c1dec0cc138796323643839dc6a86a023425b2da10abd4`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH003: Gyrfalcon Command

Family: gyrfalcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e9f6a1614993154546f9b3f9d5a6dbd6266d0400741c940624249d8b1c99fe6b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH004: Gyrfalcon Patrol

Family: gyrfalcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4da646ad6fdf1ad072257ec55bc72dbd5dbf3c7c6f9aaa34ed0813fc1bcd476d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH005: Bison

Family: bison. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d59be5b7ee17fc743ae384b82c48db3b6e07bb7136ced0456449be7d2f9d29a8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 1108 | t |
| speed | 17.7 | raw authored units |
| acceleration | 4.0 | raw authored units |
| energy | 1120 | raw authored units |
| recharge | 6.44 | raw authored units |
| roll | 0.31 | raw authored units |
| pitch | 0.27 | raw authored units |
| yaw | 0.25 | raw authored units |
| shield | 590 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 16 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 445 | t |
| price | 690000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH006: Bison Mk II

Family: bison. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `73e70dd42b5d5cef0608228b8e1b1a7621713fd025f17fbc7beeef229607117c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 1220 | t |
| speed | 17.4 | raw authored units |
| acceleration | 3.9 | raw authored units |
| energy | 1260 | raw authored units |
| recharge | 6.95 | raw authored units |
| roll | 0.3 | raw authored units |
| pitch | 0.26 | raw authored units |
| yaw | 0.25 | raw authored units |
| shield | 640 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 16 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 490 | t |
| price | 761000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH007: Impala Voyager

Family: impala. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `b5560012518198780994d5595a007f85fa73a20dea00287f8a699d7ec15cafb0`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 38 | t |
| speed | 38.6 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.01 | raw authored units |
| pitch | 0.89 | raw authored units |
| yaw | 0.83 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH008: Goshawk Explorer

Family: goshawk. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ccfdb95f0e0321841ddaab5bbdc7174d32af6e14319e4596441c8c706e7425d9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 32 | t |
| speed | 39.5 | raw authored units |
| acceleration | 11.5 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 4.01 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 211000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH009: Goshawk Mk II

Family: goshawk. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6c212f2f16260f3add54067e7f441fd89d476565791ef3e194a6ad0663489b34`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 20 | t |
| speed | 41.5 | raw authored units |
| acceleration | 13.1 | raw authored units |
| energy | 400 | raw authored units |
| recharge | 6.12 | raw authored units |
| roll | 1.09 | raw authored units |
| pitch | 0.96 | raw authored units |
| yaw | 0.89 | raw authored units |
| shield | 330 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 281000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH010: Goshawk Mk II Custom

Family: goshawk. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d17640b60c78d640c4ebd782009988dc388f7dca659860c5e9359ea41cf671ca`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 20 | t |
| speed | 41.5 | raw authored units |
| acceleration | 13.1 | raw authored units |
| energy | 400 | raw authored units |
| recharge | 6.12 | raw authored units |
| roll | 1.09 | raw authored units |
| pitch | 0.96 | raw authored units |
| yaw | 0.89 | raw authored units |
| shield | 330 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 281000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH011: Goshawk Scout

Family: goshawk. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `de8b301bd17a2d559b4bc72305c1534137e87fc0f2b465402e2e8860c809536d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH012: Sable Liner

Family: sable-liner. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `fdcf002013da0a024c478a8b9d6196930086e447e557345ba85aeeb424e50886`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 40.7 | raw authored units |
| acceleration | 12.0 | raw authored units |
| energy | 220 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.05 | raw authored units |
| pitch | 0.92 | raw authored units |
| yaw | 0.86 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 160 | 0.1 LY (raw tenths) |
| jump | 12 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 212000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH013: Buffalo

Family: buffalo. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `7978e6d0282ed28343f371d1d9f237687c726b7cd076f31080619d462d31e3d0`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 21.9 | raw authored units |
| acceleration | 5.6 | raw authored units |
| energy | 710 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.43 | raw authored units |
| pitch | 0.38 | raw authored units |
| yaw | 0.35 | raw authored units |
| shield | 470 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 424000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH014: Buffalo Mk II

Family: buffalo. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ffcfd14903bbe9198f1b56e7887b8d77b8957e9df8d621b347715ce306926954`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 436 | t |
| speed | 21.5 | raw authored units |
| acceleration | 5.5 | raw authored units |
| energy | 800 | raw authored units |
| recharge | 5.65 | raw authored units |
| roll | 0.41 | raw authored units |
| pitch | 0.36 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 510 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 14 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 465000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH015: Raven

Family: raven. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `362c79c6710997289128a3e7c2b33d041da82b2f3beed43cba28c2d799f650cf`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 46.9 | raw authored units |
| acceleration | 13.8 | raw authored units |
| energy | 220 | raw authored units |
| recharge | 3.1 | raw authored units |
| roll | 1.39 | raw authored units |
| pitch | 1.22 | raw authored units |
| yaw | 1.14 | raw authored units |
| shield | 170 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH016: Mole Miner

Family: mole. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `361599978c105b998cc38c7ffa990c212d43d9c66097baf9321e3b053a2df31a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 108 | t |
| speed | 26.7 | raw authored units |
| acceleration | 8.3 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.67 | raw authored units |
| pitch | 0.59 | raw authored units |
| yaw | 0.55 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 45 | t |
| price | 242000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH017: Mole Prospector

Family: mole. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `da8194998167607fe670f342c2f321e2d6ce369793c10f3a5b68c8a243abad40`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 108 | t |
| speed | 26.7 | raw authored units |
| acceleration | 8.3 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.67 | raw authored units |
| pitch | 0.59 | raw authored units |
| yaw | 0.55 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 45 | t |
| price | 242000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH018: Donkey

Family: donkey. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `831db059ba2a85c66f42aa23e1ff07eb43df50d4ef81671288ea9e18880af08b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH019: Gazelle Explorer

Family: gazelle. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `582ffc8d9f3345fd061fb8f0a595235bcd5b5391f562229ac78c948e167b4866`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 40.7 | raw authored units |
| acceleration | 12.0 | raw authored units |
| energy | 220 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.05 | raw authored units |
| pitch | 0.92 | raw authored units |
| yaw | 0.86 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 160 | 0.1 LY (raw tenths) |
| jump | 12 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 212000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH020: Crow Prototype

Family: crow. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6561fdea84a2ee55a5494f70145526d024e1ae7e6fce578a5bf65c3a86be1e0e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 49.5 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 210 | raw authored units |
| recharge | 3.1 | raw authored units |
| roll | 1.45 | raw authored units |
| pitch | 1.28 | raw authored units |
| yaw | 1.19 | raw authored units |
| shield | 170 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH021: Zebra

Family: zebra. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `60304ebb83d7d419e49f6abb4fd06954ebc02250ade5fa02f4b7f50de3a9f06e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 62 | t |
| speed | 34.4 | raw authored units |
| acceleration | 9.4 | raw authored units |
| energy | 300 | raw authored units |
| recharge | 3.33 | raw authored units |
| roll | 0.84 | raw authored units |
| pitch | 0.74 | raw authored units |
| yaw | 0.69 | raw authored units |
| shield | 260 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 226000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH022: Peregrine Mk I

Family: peregrine. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c79603873bdd9d74acca12dfc8601d3af76c9fa2469fd2cba5c50fa378bf1aa9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 64 | t |
| speed | 37.0 | raw authored units |
| acceleration | 10.0 | raw authored units |
| energy | 260 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.9 | raw authored units |
| pitch | 0.79 | raw authored units |
| yaw | 0.74 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 215000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH023: Peregrine Mk III

Family: peregrine. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `697d6d40afdcbd90ecc036780e2f1460ee5f0769cb22725d15df4c10f2deebd3`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 78 | t |
| speed | 35.7 | raw authored units |
| acceleration | 9.5 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 3.71 | raw authored units |
| roll | 0.84 | raw authored units |
| pitch | 0.74 | raw authored units |
| yaw | 0.69 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 1.65 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 13 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 30 | t |
| price | 246000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH024: Peregrine Mk IV

Family: peregrine. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `1e3fc20f20bc038f29a121306367076102a39cd073b45060808a4d34cf648725`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 84 | t |
| speed | 35.0 | raw authored units |
| acceleration | 9.3 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 3.97 | raw authored units |
| roll | 0.81 | raw authored units |
| pitch | 0.71 | raw authored units |
| yaw | 0.66 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 1.72 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 14 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 35 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH025: Peregrine Mk V

Family: peregrine. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `8c608e9f1a9a325b3c275f64a9428832c4f6890b7465f966c907daa70b4db313`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 92 | t |
| speed | 34.3 | raw authored units |
| acceleration | 9.1 | raw authored units |
| energy | 380 | raw authored units |
| recharge | 4.22 | raw authored units |
| roll | 0.79 | raw authored units |
| pitch | 0.7 | raw authored units |
| yaw | 0.65 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 15 | seconds |
| missiles | 9 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 35 | t |
| price | 274000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH026: Harrier

Family: harrier. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d8c6ad6b67cb7c7bdac765ece55b44f405c3702f70481d6d513910528922b7db`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter","hull-spec-metadata-difference"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;{"field":"family","spec":"harrier","hullProposal":null}&#93;

## SH027: Ibex

Family: ibex. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `61589fb3c7c9bc5a9bede2a9bc04f6f38171e18a9896c3be66fb4e13fc45c759`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH028: Lion Citadel

Family: lion-citadel. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `71b9d933d3f2c01f7002ee334dc15502716a6865edc37b5cd976fda64b7f2c17`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH029: Burro

Family: burro. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4eda0abb4d9a294f1a781d0ae917bcec3b6a06252d5edd7179fee3d0401bfab9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 52 | t |
| speed | 39.6 | raw authored units |
| acceleration | 10.6 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.95 | raw authored units |
| pitch | 0.84 | raw authored units |
| yaw | 0.78 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 220000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH030: Sparrowhawk

Family: sparrowhawk. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e540dc44721e73a79a86ae4b8d1e09744f426c8105fd5f8001fa24a7d1eb9173`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 49.8 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 300 | raw authored units |
| recharge | 4.84 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 250 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 250000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH031: Kite Interceptor

Family: kite. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `101dfd7831ddc895caf9ede9d8b185c804e23d983c35eb5da3ae330e567b4ee6`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH032: Panther Explorer

Family: panther. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `2f3cc48778e8341b9589f09af2b4936fcb55a0495568fef2015d3de9022ddd5f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 46.2 | raw authored units |
| acceleration | 12.5 | raw authored units |
| energy | 190 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.07 | raw authored units |
| pitch | 0.94 | raw authored units |
| yaw | 0.88 | raw authored units |
| shield | 200 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 205000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH033: Panther Scout

Family: panther. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e1f920a431078cc02de5979b206ff4c54b932344c937c0d19e30d3f0f78c63e2`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 49.5 | raw authored units |
| acceleration | 14.6 | raw authored units |
| energy | 310 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.17 | raw authored units |
| pitch | 1.03 | raw authored units |
| yaw | 0.96 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 257000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH034: Frog Station

Family: frog. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `168326281708a377e596ea5d02bf75e9a5676ae8c89147c3d5ae0512a073ce38`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH035: Stag Liner

Family: stag. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `00bee93a339a423b1d4c4167797c390fbeeed53ea9b81b74e4f36cc336422e52`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 44.9 | raw authored units |
| acceleration | 12.7 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 217000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH036: Zebu

Family: zebu. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `14ffc1d3b110580e8282a430c36363f1566a2aafd75c2be7ac715b0e047ff454`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 58 | t |
| speed | 35.9 | raw authored units |
| acceleration | 10.0 | raw authored units |
| energy | 260 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.9 | raw authored units |
| pitch | 0.79 | raw authored units |
| yaw | 0.74 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 11 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 217000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH037: Vulture Mk I

Family: vulture. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `cdc690fd328482530fbe76a8af4936140d66f3a24bd26401df0a95c9ca21768b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 14 | t |
| speed | 58.3 | raw authored units |
| acceleration | 19.1 | raw authored units |
| energy | 140 | raw authored units |
| recharge | 2.7 | raw authored units |
| roll | 2.03 | raw authored units |
| pitch | 1.79 | raw authored units |
| yaw | 1.66 | raw authored units |
| shield | 140 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 10 | seconds |
| missiles | 4 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 213000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH038: Vulture Mk II

Family: vulture. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `3aa8a15457d307d363ab92a7383c8686709c49a8b2d6a212f70970b5b061a817`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 14 | t |
| speed | 57.2 | raw authored units |
| acceleration | 18.7 | raw authored units |
| energy | 160 | raw authored units |
| recharge | 2.92 | raw authored units |
| roll | 1.97 | raw authored units |
| pitch | 1.73 | raw authored units |
| yaw | 1.62 | raw authored units |
| shield | 150 | raw authored units |
| shieldRecharge | 1.68 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 10 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 220000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH039: Vulture Mk III

Family: vulture. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c823414f5cdcccfbab04866488b1d8777ff0a615dbd6ff4a3db9b8509e129ed8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 56.2 | raw authored units |
| acceleration | 18.2 | raw authored units |
| energy | 180 | raw authored units |
| recharge | 3.13 | raw authored units |
| roll | 1.9 | raw authored units |
| pitch | 1.67 | raw authored units |
| yaw | 1.56 | raw authored units |
| shield | 160 | raw authored units |
| shieldRecharge | 1.76 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 11 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 228000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH040: Newt Escape Pod

Family: newt-escape-pod. Role: capsule.

Authored playerFlyable: True. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e2cb4afe1fef0f6105cbcf09e809ac048522a7607e3fe3a0706160fba37d8a14`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 0 | t |
| speed | 18 | raw authored units |
| acceleration | 3 | raw authored units |
| energy | 70 | raw authored units |
| recharge | 0.6 | raw authored units |
| roll | 0.55 | raw authored units |
| pitch | 0.48 | raw authored units |
| yaw | 0.45 | raw authored units |
| shield | 30 | raw authored units |
| shieldRecharge | 0.4 | raw authored units |
| fuel | 0 | 0.1 LY (raw tenths) |
| jump | 0 | LY |
| spool | 0 | seconds |
| missiles | 0 | count |
| facings | 0 | facing bit mask |
| cargoExpansion | 0 | t |
| price | 0 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;"game.jump: current ShipPerformance requires finite (0, 100000&#93;","game.spool: current ShipPerformance requires finite (0, 100000&#93;","game.fuel: current ShipPerformance requires integer &#91;1, 10000&#93;","game.missiles: current ShipPerformance requires integer &#91;1, 32&#93;","game.facings: current ShipPerformance requires integer &#91;1, 15&#93;","game.price: current ShipPerformance requires integer &#91;1, 100000000&#93;"&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH041: Serval Fighter

Family: serval. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `56bdcf0c9b2b1a6f2e6fa9ebcaf1e4df1b21a90c7f59a8a31390cb3a96e254d6`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH042: Saker

Family: saker. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6023ebd2e908a9ebbf76bc35357208b22de214657cacdc93aea66839a3cc4e5a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH043: Eagle Cruiser

Family: eagle. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: never.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `5df95cf9abae60136592fefddc69d81d24857512f096d6b27c9246e0cd737ed2`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 172 | t |
| speed | 22.8 | raw authored units |
| acceleration | 5.2 | raw authored units |
| energy | 1490 | raw authored units |
| recharge | 9.72 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 600 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 18 | seconds |
| missiles | 10 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 70 | t |
| price | 0 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;"game.price: current ShipPerformance requires integer &#91;1, 100000000&#93;"&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH044: Harpy Assault

Family: harpy. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4a9e38a8ae98258dca2da72e0ba31b1e2f8c8ceaeb07f41bf2a865596e43eedc`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH045: Erne Corvette

Family: erne. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `7fa903d36dffbe4ff7f871685526e086eab77e39bd4d550ce911b20d5ca1ea1f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 41.9 | raw authored units |
| acceleration | 13.2 | raw authored units |
| energy | 400 | raw authored units |
| recharge | 4.99 | raw authored units |
| roll | 1.07 | raw authored units |
| pitch | 0.94 | raw authored units |
| yaw | 0.88 | raw authored units |
| shield | 330 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 276000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH046: Harpy Dropship

Family: harpy. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6189050947fcc6945e1084661c193c8f10d2ffb47dc9d14cce3c8fffc6fd0732`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH047: Harpy Gunship

Family: harpy. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `f3b9e067bdc8b932dc22f2b1a5d3295f5609437334859f9d589bbf2b2d873dcb`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH048: Lanner

Family: lanner. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `7ad3635f5e3cd6412d568d1c759e06a7087d7e0992e6c6afebfd5ea6491c5f28`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 12 | t |
| speed | 65.3 | raw authored units |
| acceleration | 19.3 | raw authored units |
| energy | 190 | raw authored units |
| recharge | 3.57 | raw authored units |
| roll | 1.68 | raw authored units |
| pitch | 1.48 | raw authored units |
| yaw | 1.38 | raw authored units |
| shield | 190 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 10 | seconds |
| missiles | 4 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 246000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH049: Hyena

Family: hyena. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d5d31cc76f6d01990bef42c15574c0adfe293990d6c12c1eb82237442f1107b2`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 24 | t |
| speed | 51.0 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 210 | raw authored units |
| recharge | 3.1 | raw authored units |
| roll | 1.45 | raw authored units |
| pitch | 1.28 | raw authored units |
| yaw | 1.19 | raw authored units |
| shield | 170 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 214000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH050: Yak

Family: yak. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `fb9d1fe8178045f5b5f22d908bf8cec400b05c15ea2358d9858f53f66439992c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 58 | t |
| speed | 35.9 | raw authored units |
| acceleration | 10.0 | raw authored units |
| energy | 260 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.9 | raw authored units |
| pitch | 0.79 | raw authored units |
| yaw | 0.74 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 11 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 217000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH051: Jackal

Family: jackal. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6bd84976f9e11f0325410aa970d8eedadce061140d45289288f7cded7776d6aa`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 24 | t |
| speed | 47.9 | raw authored units |
| acceleration | 14.4 | raw authored units |
| energy | 220 | raw authored units |
| recharge | 3.66 | raw authored units |
| roll | 1.42 | raw authored units |
| pitch | 1.25 | raw authored units |
| yaw | 1.16 | raw authored units |
| shield | 180 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 212000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH052: Percheron

Family: percheron. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `2456ea76f18821d66bf7df0aba4e215df105434f391de74fc016e3c541dcb958`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 58 | t |
| speed | 40.7 | raw authored units |
| acceleration | 10.4 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.92 | raw authored units |
| pitch | 0.81 | raw authored units |
| yaw | 0.75 | raw authored units |
| shield | 210 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH053: Percheron Prototype

Family: percheron. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e8d96b54bc63b15e1288f27bae9371a5233f32d9a461d5a33bad529e7e37aaaa`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 49.5 | raw authored units |
| acceleration | 14.6 | raw authored units |
| energy | 310 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.17 | raw authored units |
| pitch | 1.03 | raw authored units |
| yaw | 0.96 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 257000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH054: Hobby Fighter

Family: hobby. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `554c6d123f3d4cc1cd10cd0db6514e889b18f93749339df5c3456f52d244f4b8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH055: Condor

Family: condor. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4affc3d78baf0812c69867443af7c9328786b3806af115b2b1fb018f57309fb9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 46.9 | raw authored units |
| acceleration | 13.8 | raw authored units |
| energy | 220 | raw authored units |
| recharge | 3.1 | raw authored units |
| roll | 1.39 | raw authored units |
| pitch | 1.22 | raw authored units |
| yaw | 1.14 | raw authored units |
| shield | 170 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH056: Aplomado Interceptor

Family: aplomado. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `00519d8765d91bba56a1d0bb33820e25210be01f6868a6e0278c642b552862c4`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH057: Falconet

Family: falconet. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c05c9f35935da785a93866fc09d98bdcd38a4e6446e21bef907d4285c7dfe6fc`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH058: Brabant

Family: brabant. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `5c2803976cc9d4b4df9d142e9500306a5d8fabdc0c4885817d11016c40155dc9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 418 | t |
| speed | 21.0 | raw authored units |
| acceleration | 5.3 | raw authored units |
| energy | 820 | raw authored units |
| recharge | 5.44 | raw authored units |
| roll | 0.4 | raw authored units |
| pitch | 0.35 | raw authored units |
| yaw | 0.33 | raw authored units |
| shield | 540 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 165 | t |
| price | 463000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH059: Barbary

Family: barbary. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `7f460e9b37fafce40ba2690f456b8d334e75150a0fc95aeba8bb5f063a542451`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 41.4 | raw authored units |
| acceleration | 12.9 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH060: Wombat

Family: wombat. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6dbaf52099abbcfa8162859ab5b321ce3fe7808b6b8a8d33c77a9c984e196f25`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 72 | t |
| speed | 31.0 | raw authored units |
| acceleration | 9.5 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.73 | raw authored units |
| pitch | 0.64 | raw authored units |
| yaw | 0.6 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 30 | t |
| price | 235000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH061: Haflinger

Family: haflinger. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `9607a7ed0bc2b555ae511aacee4845320280ea2d66ebbd1c7133a94ca486fdd0`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 78 | t |
| speed | 34.0 | raw authored units |
| acceleration | 9.2 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.86 | raw authored units |
| pitch | 0.76 | raw authored units |
| yaw | 0.71 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 30 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH062: Moose Clipper

Family: moose. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `08e5f904936349a90b2986dfb1e8f3bc992608d06b7e53c756cb2b600f4cf6db`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 24.9 | raw authored units |
| acceleration | 5.8 | raw authored units |
| energy | 630 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.44 | raw authored units |
| pitch | 0.39 | raw authored units |
| yaw | 0.36 | raw authored units |
| shield | 440 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 397000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH063: Seriema Courier

Family: seriema. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `dce2b89b045142f68979182d58bf7564a71be69045c178b68f462e3874ca34eb`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH064: Arna Cutter

Family: arna. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `3c32b4def4e9edf52bc791a96fb9598175b28cde652137bb50780e23c3f5bc81`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 24.9 | raw authored units |
| acceleration | 5.8 | raw authored units |
| energy | 630 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.44 | raw authored units |
| pitch | 0.39 | raw authored units |
| yaw | 0.36 | raw authored units |
| shield | 440 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 397000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH065: Vulture Raider

Family: vulture. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `5dd52610f71c266331da80c49a2a647fc32e9967d06591721cc5f9af036d6352`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 14 | t |
| speed | 58.3 | raw authored units |
| acceleration | 19.1 | raw authored units |
| energy | 140 | raw authored units |
| recharge | 2.7 | raw authored units |
| roll | 2.03 | raw authored units |
| pitch | 1.79 | raw authored units |
| yaw | 1.66 | raw authored units |
| shield | 140 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 10 | seconds |
| missiles | 4 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 213000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH066: Rabbit Explorer

Family: rabbit. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `dfacee0c1f91661c47a2b9a35abd6a7d62d7ffb94e1e6347d10620ccc32fda5d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 46.2 | raw authored units |
| acceleration | 12.5 | raw authored units |
| energy | 190 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.07 | raw authored units |
| pitch | 0.94 | raw authored units |
| yaw | 0.88 | raw authored units |
| shield | 200 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 205000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH067: Rhinoceros Trader

Family: rhinoceros. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c5122172115753ddf707c0528dc11bc35d8b2ca984a240d0fa299645a344c1a4`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 52 | t |
| speed | 39.6 | raw authored units |
| acceleration | 10.6 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.95 | raw authored units |
| pitch | 0.84 | raw authored units |
| yaw | 0.78 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 220000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH068: Badger

Family: badger. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4b764e35643b6f9a605a368a06a6a1c170b12dddae178e812cdc91886cf13b8f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 108 | t |
| speed | 26.7 | raw authored units |
| acceleration | 8.3 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.67 | raw authored units |
| pitch | 0.59 | raw authored units |
| yaw | 0.55 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 45 | t |
| price | 242000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH069: Baza Fighter

Family: baza. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `74cd2d4b1f204369473740b91d38efc347c3e068572a23a70f2ee1e8a9697527`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH070: Baza Mk II

Family: baza. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `260d6f5a956173fda860c54f3b0a17eb305620e87d6399702dd58a5b278aa193`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 20 | t |
| speed | 53.1 | raw authored units |
| acceleration | 17.2 | raw authored units |
| energy | 290 | raw authored units |
| recharge | 4.43 | raw authored units |
| roll | 1.5 | raw authored units |
| pitch | 1.32 | raw authored units |
| yaw | 1.23 | raw authored units |
| shield | 250 | raw authored units |
| shieldRecharge | 1.99 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH071: Griffon

Family: griffon. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6ac1a99e4f3cb1e9f6fd3139ffac48a683f1c2321beb7890fa2b926eb4cdc0c5`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 47.4 | raw authored units |
| acceleration | 14.1 | raw authored units |
| energy | 240 | raw authored units |
| recharge | 3.22 | raw authored units |
| roll | 1.35 | raw authored units |
| pitch | 1.19 | raw authored units |
| yaw | 1.11 | raw authored units |
| shield | 190 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH072: Griffon Mk II

Family: griffon. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `600cc15839c29233e9fa99f8082271872f80710a645a9d8f50d5201360d727c4`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 46.6 | raw authored units |
| acceleration | 13.8 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.48 | raw authored units |
| roll | 1.3 | raw authored units |
| pitch | 1.14 | raw authored units |
| yaw | 1.07 | raw authored units |
| shield | 210 | raw authored units |
| shieldRecharge | 1.68 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 230000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH073: Griffon Spectre

Family: griffon. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `74689a6cacaf9060bb20e36ee7954be3e605f2eaaad5d28376216afe779f2450`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 47.4 | raw authored units |
| acceleration | 14.1 | raw authored units |
| energy | 240 | raw authored units |
| recharge | 3.22 | raw authored units |
| roll | 1.35 | raw authored units |
| pitch | 1.19 | raw authored units |
| yaw | 1.11 | raw authored units |
| shield | 190 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH074: Dzo

Family: dzo. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `049de494299a561e1cd109d81b04c7a0c0b50dafe6ae97061ae484f591b8d4cf`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 21.9 | raw authored units |
| acceleration | 5.6 | raw authored units |
| energy | 710 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.43 | raw authored units |
| pitch | 0.38 | raw authored units |
| yaw | 0.35 | raw authored units |
| shield | 470 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 424000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH075: Dzo Mk II

Family: dzo. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `cd4f918dc05d50673869c37fdf702226d1ccec11f9195aa683617552125bc2e6`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 436 | t |
| speed | 21.5 | raw authored units |
| acceleration | 5.5 | raw authored units |
| energy | 800 | raw authored units |
| recharge | 5.65 | raw authored units |
| roll | 0.41 | raw authored units |
| pitch | 0.36 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 510 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 14 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 465000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH076: Hog

Family: hog. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `1f8007fa31373732cec783713f46dd7a42b09223b7e8e20bfce066041cf96bab`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 418 | t |
| speed | 21.0 | raw authored units |
| acceleration | 5.3 | raw authored units |
| energy | 820 | raw authored units |
| recharge | 5.44 | raw authored units |
| roll | 0.4 | raw authored units |
| pitch | 0.35 | raw authored units |
| yaw | 0.33 | raw authored units |
| shield | 540 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 165 | t |
| price | 463000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH077: Tamaraw

Family: tamaraw. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `5d5660c6d28b94c08b80e4e0a4bf5cdb2945c3b6824b0f788a559dd0ccd4c411`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 21.9 | raw authored units |
| acceleration | 5.6 | raw authored units |
| energy | 710 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.43 | raw authored units |
| pitch | 0.38 | raw authored units |
| yaw | 0.35 | raw authored units |
| shield | 470 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 424000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH078: Oryx Voyager

Family: oryx-voyager. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6ed8371763a00d57b40919e9c7c8a20bb6fdab259def6881369a1332e39b8e98`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 32 | t |
| speed | 39.5 | raw authored units |
| acceleration | 11.5 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 4.01 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 211000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH079: Carabao Carrier

Family: carabao. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `797a2e69ee66d1233b277a2692060455bfc64f78fbf8441c7dda15d1b01b8627`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 786 | t |
| speed | 19.6 | raw authored units |
| acceleration | 4.8 | raw authored units |
| energy | 970 | raw authored units |
| recharge | 6.44 | raw authored units |
| roll | 0.37 | raw authored units |
| pitch | 0.33 | raw authored units |
| yaw | 0.3 | raw authored units |
| shield | 550 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 16 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 315 | t |
| price | 580000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH080: Carabao Highliner

Family: carabao. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `312eb0fcfce4b241bcf1791f73f942bc61fd83178d894e8dc0a1a8c2c79db9f2`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 786 | t |
| speed | 19.6 | raw authored units |
| acceleration | 4.8 | raw authored units |
| energy | 970 | raw authored units |
| recharge | 6.44 | raw authored units |
| roll | 0.37 | raw authored units |
| pitch | 0.33 | raw authored units |
| yaw | 0.3 | raw authored units |
| shield | 550 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 16 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 315 | t |
| price | 580000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH081: Jaguar

Family: jaguar. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: never.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4c37edc511bde5ac4fa23421ef7a0f4bae937322f95b7acc3c16d611c0e26dd4`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 144 | t |
| speed | 23.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 1480 | raw authored units |
| recharge | 11.47 | raw authored units |
| roll | 0.43 | raw authored units |
| pitch | 0.38 | raw authored units |
| yaw | 0.35 | raw authored units |
| shield | 620 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 7 | LY |
| spool | 18 | seconds |
| missiles | 10 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 60 | t |
| price | 0 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;"game.price: current ShipPerformance requires integer &#91;1, 100000000&#93;"&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH082: Cheetah

Family: cheetah. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a74e413c429e11e4c87468e3485885eb2ca49ae3e859ac0fea5b2a3716f2d6f5`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 14 | t |
| speed | 55.2 | raw authored units |
| acceleration | 17.4 | raw authored units |
| energy | 250 | raw authored units |
| recharge | 3.72 | raw authored units |
| roll | 1.53 | raw authored units |
| pitch | 1.35 | raw authored units |
| yaw | 1.25 | raw authored units |
| shield | 240 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 10 | seconds |
| missiles | 4 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 246000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH083: Hare Explorer

Family: hare. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `3f22a030ee9300803beba254a61fe460358a765272ac46f6cef09c3d01222436`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 32 | t |
| speed | 39.5 | raw authored units |
| acceleration | 11.5 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 4.01 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 211000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH084: Llama

Family: llama. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `14e13af9ac977b58ee48622a89d38fb4804469ce5a27f3ff2eac22ac839e908c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH085: Laggar

Family: laggar. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `1093c9563f0d84bc3210192b0eaf4afd921162b73abba2b0f6e59fa7fb9987f3`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 54.1 | raw authored units |
| acceleration | 17.6 | raw authored units |
| energy | 260 | raw authored units |
| recharge | 4.1 | raw authored units |
| roll | 1.55 | raw authored units |
| pitch | 1.36 | raw authored units |
| yaw | 1.27 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 249000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH086: Alpaca

Family: alpaca. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `8180f355bb0f835d5f98a0bca45449765fc603f0db5e8683233d2fb00c63b834`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 62 | t |
| speed | 34.4 | raw authored units |
| acceleration | 9.4 | raw authored units |
| energy | 300 | raw authored units |
| recharge | 3.33 | raw authored units |
| roll | 0.84 | raw authored units |
| pitch | 0.74 | raw authored units |
| yaw | 0.69 | raw authored units |
| shield | 260 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 226000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH087: Elk

Family: elk. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `78ad489be527fe0898d26b068cf0b0f1249b6bf1e040c95e555289f66bdd60db`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 62 | t |
| speed | 34.4 | raw authored units |
| acceleration | 9.4 | raw authored units |
| energy | 300 | raw authored units |
| recharge | 3.33 | raw authored units |
| roll | 0.84 | raw authored units |
| pitch | 0.74 | raw authored units |
| yaw | 0.69 | raw authored units |
| shield | 260 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 226000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH088: Springbok Starliner

Family: springbok. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `bdf75fad62bae4020ca233d0865e24e87dee87ce08e66813629793dad50f4560`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 38 | t |
| speed | 38.6 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.01 | raw authored units |
| pitch | 0.89 | raw authored units |
| yaw | 0.83 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH089: Antelope

Family: antelope. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `73cbec7290520c58d3c8b7f8b96c97cc1c7e068337a859c030134f887cfabb27`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH090: Elephant

Family: elephant. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `2c15fae3af5993c5801cebf2eed2511d53fcb2b68832792335a4866470d4be18`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 52 | t |
| speed | 39.6 | raw authored units |
| acceleration | 10.6 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.95 | raw authored units |
| pitch | 0.84 | raw authored units |
| yaw | 0.78 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 220000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH091: Gopher

Family: gopher. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `78c2ebe71fd05cfab8b40062f22cc2ea3f7fed81092ef4c9eb4e3aa2544e8831`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 108 | t |
| speed | 26.7 | raw authored units |
| acceleration | 8.3 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.67 | raw authored units |
| pitch | 0.59 | raw authored units |
| yaw | 0.55 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 45 | t |
| price | 242000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH092: Aubrac

Family: aubrac. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `570db4e39937f172f12c914abdb20db53f73cbc4e88c374134936dbbcf91d498`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH093: Giraffe Liner

Family: giraffe. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `1300bb8af6dc9c66449f48e0fd96fba048a6aea33675de139f921dbf7353d5e8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 30 | t |
| speed | 39.1 | raw authored units |
| acceleration | 11.3 | raw authored units |
| energy | 250 | raw authored units |
| recharge | 3.54 | raw authored units |
| roll | 0.98 | raw authored units |
| pitch | 0.86 | raw authored units |
| yaw | 0.8 | raw authored units |
| shield | 250 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 218000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH094: Ictinia

Family: ictinia. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c20589dedc957c5bd9798cfff14d9ee9cc763459b29ab0bcf4a4cccecf0ef07e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH095: Ictinia X

Family: ictinia. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ef271876df13aea3baf2d0e29542f02530874bfb93698e8464f6cd1c2c96b31b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH096: Wisent

Family: wisent. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a1a7971280259b366f2c6f39a499f66cfff87e4af5cf730b71211e08cbafc3d9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 188 | t |
| speed | 26.5 | raw authored units |
| acceleration | 7.7 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.2 | raw authored units |
| roll | 0.63 | raw authored units |
| pitch | 0.55 | raw authored units |
| yaw | 0.52 | raw authored units |
| shield | 360 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 75 | t |
| price | 286000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH097: Wisent Mk II

Family: wisent. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `517cfa45ca7a8f2011b49dcec9671c4a5eb9d10278b045e7964b6787ac939bfb`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 206 | t |
| speed | 26.0 | raw authored units |
| acceleration | 7.5 | raw authored units |
| energy | 460 | raw authored units |
| recharge | 4.54 | raw authored units |
| roll | 0.61 | raw authored units |
| pitch | 0.54 | raw authored units |
| yaw | 0.5 | raw authored units |
| shield | 390 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 80 | t |
| price | 311000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH098: Anoa

Family: anoa. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `0d8aa7771b84d09bd82ec428d2670fb650e9d66521bc1a308e544b0db04047e2`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 396 | t |
| speed | 24.9 | raw authored units |
| acceleration | 5.8 | raw authored units |
| energy | 630 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.44 | raw authored units |
| pitch | 0.39 | raw authored units |
| yaw | 0.36 | raw authored units |
| shield | 440 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 160 | t |
| price | 397000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH099: Ox

Family: ox. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `914947cb7998289f542274e2a0afc19fa5bdae6753a95d180fd97b3bf99f339d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 22.6 | raw authored units |
| acceleration | 5.6 | raw authored units |
| energy | 710 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.43 | raw authored units |
| pitch | 0.38 | raw authored units |
| yaw | 0.35 | raw authored units |
| shield | 470 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 429000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH100: Ox Mk II

Family: ox. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `bb7886fb84598681b52e273bf542744625b8ebb936f108b5292233c2c54ce87d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 484 | t |
| speed | 22.2 | raw authored units |
| acceleration | 5.5 | raw authored units |
| energy | 800 | raw authored units |
| recharge | 5.65 | raw authored units |
| roll | 0.41 | raw authored units |
| pitch | 0.36 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 510 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 195 | t |
| price | 472000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH101: Dorcas Racer

Family: dorcas-racer. Role: leisure.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4eb8c867f5410db44fcbdae87fc8750c7e3e1fd421eff6fc126a7e87bee171a3`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 44.9 | raw authored units |
| acceleration | 12.7 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.4 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 217000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH102: Dhole Haven

Family: dhole. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4ce2e4e7b69d0806688fef2b57378bdaf6548eed7b8f2a141937c6ae8740323a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH103: Redtail Mk III

Family: redtail. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `33e20857283d586f5e9112af9a0f2be83a243bf5fbe7c1978581e9d4f12e160d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 54.7 | raw authored units |
| acceleration | 16.2 | raw authored units |
| energy | 370 | raw authored units |
| recharge | 4.76 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 2.09 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 13 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 287000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH104: Wildebeest

Family: wildebeest. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a2f32c6ca6dd171117de7545cb5bea6d30fcd0cf17adcb76caf00932add64343`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 62 | t |
| speed | 34.4 | raw authored units |
| acceleration | 9.4 | raw authored units |
| energy | 300 | raw authored units |
| recharge | 3.33 | raw authored units |
| roll | 0.84 | raw authored units |
| pitch | 0.74 | raw authored units |
| yaw | 0.69 | raw authored units |
| shield | 260 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 226000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH105: Tapir Shuttle

Family: tapir. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4d471634fdb69a2699a102f9fe958c922458af752e4e16934972b21b34e95d67`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 21.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 730 | raw authored units |
| recharge | 6.17 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 500 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 440000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH106: Tapir Mk II

Family: tapir. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a7e8baf52632fc2c0a75862d538988142e62de3a2465c2dbb030becc17f5795b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 484 | t |
| speed | 20.9 | raw authored units |
| acceleration | 5.2 | raw authored units |
| energy | 820 | raw authored units |
| recharge | 6.66 | raw authored units |
| roll | 0.41 | raw authored units |
| pitch | 0.36 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 540 | raw authored units |
| shieldRecharge | 1.78 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 195 | t |
| price | 482000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH107: Magpie

Family: magpie. Role: pirate.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `eb6c63cfb3cb341ae43a44c88ffd1992775b199e09d8e2f5dc4135537d0dec7d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 49.5 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 210 | raw authored units |
| recharge | 3.1 | raw authored units |
| roll | 1.45 | raw authored units |
| pitch | 1.28 | raw authored units |
| yaw | 1.19 | raw authored units |
| shield | 170 | raw authored units |
| shieldRecharge | 1.6 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 216000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH108: Besra

Family: besra. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a0c3ca7d95e9e74568e51c4aa8ac59378b394c547d62153cb4b15ea43c8b275c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 20 | t |
| speed | 49.3 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 330 | raw authored units |
| recharge | 4.26 | raw authored units |
| roll | 1.26 | raw authored units |
| pitch | 1.11 | raw authored units |
| yaw | 1.03 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 258000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH109: Hippo

Family: hippo. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ddda38e7b2467260d6f51fde81dc88aee7d6e3262b4bcc09a0efb89e8d5fa466`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 58 | t |
| speed | 40.7 | raw authored units |
| acceleration | 10.4 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.92 | raw authored units |
| pitch | 0.81 | raw authored units |
| yaw | 0.75 | raw authored units |
| shield | 210 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH110: Leopard Fighter

Family: leopard. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ec0b141d03d14f68eaa24e9e252952aeb57666bd3fdedf73d4fe8c36ca22bb09`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH111: Puma

Family: puma. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `f6719edce162e4bfa0bf56ca3b6c43f92a54a3987054359fc90d9b50ffff65c1`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 49.5 | raw authored units |
| acceleration | 14.6 | raw authored units |
| energy | 310 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.17 | raw authored units |
| pitch | 1.03 | raw authored units |
| yaw | 0.96 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 257000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH112: Larvaal Warden

Family: larvaal-warden. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `93110d0d26847b833ebfe1a9f496e82a0b618a1ff5216f53bfac09f1e4fee824`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 47.0 | raw authored units |
| acceleration | 17.0 | raw authored units |
| energy | 390 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.3 | raw authored units |
| pitch | 1.14 | raw authored units |
| yaw | 1.07 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 280000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH113: Larvaal Ravager

Family: larvaal-ravager. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c55f89d3d7b183a38155e6a6a5f4e2003e2a2f240371d101d2e97db3fdbb3c20`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 47.0 | raw authored units |
| acceleration | 17.0 | raw authored units |
| energy | 390 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.3 | raw authored units |
| pitch | 1.14 | raw authored units |
| yaw | 1.07 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 280000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH114: Larvaal Sentinel

Family: larvaal-sentinel. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a398c741c961674b3ee77fd665fe1bed7b1c572a40262bf87d54cbfa6fea6d4f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 24 | t |
| speed | 47.9 | raw authored units |
| acceleration | 18.7 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.49 | raw authored units |
| pitch | 1.31 | raw authored units |
| yaw | 1.22 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 271000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH115: Larvaal Lancer

Family: larvaal-lancer. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a3f7f60d82205bd0461ff1816f135eff770101b87c496e96f6946fdb7305cfb5`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 24 | t |
| speed | 47.9 | raw authored units |
| acceleration | 18.7 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.49 | raw authored units |
| pitch | 1.31 | raw authored units |
| yaw | 1.22 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 271000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH116: Larvaal Broodlord

Family: larvaal-broodlord. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `0b7d9180e0c37a9e64c0ac54686101ef84da096c98b67af1fc556dea55f0e952`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 34 | t |
| speed | 43.2 | raw authored units |
| acceleration | 15.6 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.25 | raw authored units |
| pitch | 1.1 | raw authored units |
| yaw | 1.02 | raw authored units |
| shield | 320 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 281000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH117: Larvaal Provoker

Family: larvaal-provoker. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `9dda73d322b59e802d665ed01ae53dc2993882836fbf59c609fb84ea105079ab`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 50.3 | raw authored units |
| acceleration | 18.0 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.37 | raw authored units |
| pitch | 1.21 | raw authored units |
| yaw | 1.12 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 288000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH118: Larvaal Reaver

Family: larvaal-reaver. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `9da5995152fb6aa4aa24cf32570cb3a750f1cfc0495ad2f706250920b91d8121`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 50.3 | raw authored units |
| acceleration | 18.0 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.37 | raw authored units |
| pitch | 1.21 | raw authored units |
| yaw | 1.12 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 288000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH119: Larvaal Wraith

Family: larvaal-wraith. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `cf67aec64b2ae7f49b5d674f9eabf1c148afb9aa50622da5cf2f0e65b523ab5e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 51.7 | raw authored units |
| acceleration | 17.7 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.33 | raw authored units |
| pitch | 1.17 | raw authored units |
| yaw | 1.09 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 273000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH120: Larvaal Seeker

Family: larvaal-seeker. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `259cfe78cb4013797c071cb0060fb952c372774bf9cf11fa67936f1fc5bf345b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 34 | t |
| speed | 43.2 | raw authored units |
| acceleration | 15.6 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.25 | raw authored units |
| pitch | 1.1 | raw authored units |
| yaw | 1.02 | raw authored units |
| shield | 320 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 281000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH121: Larvaal Mender

Family: larvaal-mender. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `caa73c7ad6c58b9794f3caac8318638f2b708058e645a4820d222a2ee96c0a35`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 43.7 | raw authored units |
| acceleration | 16.0 | raw authored units |
| energy | 450 | raw authored units |
| recharge | 4.89 | raw authored units |
| roll | 1.21 | raw authored units |
| pitch | 1.06 | raw authored units |
| yaw | 0.99 | raw authored units |
| shield | 350 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 295000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH122: Larvaal Harvester

Family: larvaal-harvester. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ae729e19bfe50c764ec5ff9a48a25bf672d6336fd02b595388e9ae624843fb91`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 50.3 | raw authored units |
| acceleration | 18.0 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.37 | raw authored units |
| pitch | 1.21 | raw authored units |
| yaw | 1.12 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 288000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH123: Larvaal Sovereign

Family: larvaal-sovereign. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `2b5cd6061a0d0670e513f2953af04ef2a1d8a0ca3961831133436634538ce177`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 180 | t |
| speed | 27.7 | raw authored units |
| acceleration | 7.2 | raw authored units |
| energy | 1660 | raw authored units |
| recharge | 9.52 | raw authored units |
| roll | 0.52 | raw authored units |
| pitch | 0.46 | raw authored units |
| yaw | 0.43 | raw authored units |
| shield | 620 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 18 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 70 | t |
| price | 0 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter","hull-spec-metadata-difference"&#93;

Current native range/field issues: &#91;"game.price: current ShipPerformance requires integer &#91;1, 100000000&#93;"&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;{"field":"family","spec":"larvaal-sovereign","hullProposal":"larvaal"}&#93;

## SH124: Larvaal Warship

Family: larvaal-warship. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c4b4889f79d088d10418ac50d2ca87e047d8f5cdbd03b8795bc5eb3fba025585`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 28 | t |
| speed | 47.0 | raw authored units |
| acceleration | 17.0 | raw authored units |
| energy | 390 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.3 | raw authored units |
| pitch | 1.14 | raw authored units |
| yaw | 1.07 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 280000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH125: Larvaal Drone

Family: larvaal-drone. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `af78004040f992fb46d7401d5eddbbc72b34e64ec6988ee498c49fb4030fd7c8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 26 | t |
| speed | 43.7 | raw authored units |
| acceleration | 16.0 | raw authored units |
| energy | 450 | raw authored units |
| recharge | 4.89 | raw authored units |
| roll | 1.21 | raw authored units |
| pitch | 1.06 | raw authored units |
| yaw | 0.99 | raw authored units |
| shield | 350 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 295000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-native-geometry-adapter","hull-spec-metadata-difference"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;{"field":"family","spec":"larvaal-drone","hullProposal":null}&#93;

## SH126: Mangalica

Family: mangalica. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `79e4d8e18b3809c43d6f4f6825259304d283de80c1980fc477d271de8c054005`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH127: Gaur Trader

Family: gaur. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `68ca7a0c3f04673b6226ae0fcd60085e2e432e102799fb48d08f4734f9016589`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 56 | t |
| speed | 37.7 | raw authored units |
| acceleration | 11.0 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 1.03 | raw authored units |
| pitch | 0.91 | raw authored units |
| yaw | 0.84 | raw authored units |
| shield | 220 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 209000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH128: Boar Transport

Family: boar. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e80538fc8b654b12a50759f223a4d4057f94c70d7daabce88b8120db3713e21d`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 374 | t |
| speed | 23.1 | raw authored units |
| acceleration | 6.2 | raw authored units |
| energy | 640 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.49 | raw authored units |
| pitch | 0.43 | raw authored units |
| yaw | 0.4 | raw authored units |
| shield | 450 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 150 | t |
| price | 396000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH129: Warthog 10 Guard

Family: warthog-10-guard. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `08d09dafc75b0708ed41b73f61ec51e57039740a92cda86d3a3ed8426767829a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 36 | t |
| speed | 36.8 | raw authored units |
| acceleration | 10.8 | raw authored units |
| energy | 560 | raw authored units |
| recharge | 7.05 | raw authored units |
| roll | 0.88 | raw authored units |
| pitch | 0.77 | raw authored units |
| yaw | 0.72 | raw authored units |
| shield | 380 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 15 | t |
| price | 320000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH130: Marmot 11 Prospector

Family: marmot. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `8ce74b6e502953ef22a13d9235a3d41d603e6294de86545a50eb6cb68a328d51`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 180 | t |
| speed | 23.7 | raw authored units |
| acceleration | 6.9 | raw authored units |
| energy | 530 | raw authored units |
| recharge | 5.44 | raw authored units |
| roll | 0.54 | raw authored units |
| pitch | 0.48 | raw authored units |
| yaw | 0.44 | raw authored units |
| shield | 390 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 70 | t |
| price | 317000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH131: Warthog 6

Family: warthog-10-guard. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e4d0672957ca7ae71400b9443d859280eeb6a395350ed82a0393d7fc4b3da9df`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 21.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 730 | raw authored units |
| recharge | 6.17 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 500 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 440000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH132: Warthog 7

Family: warthog-10-guard. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `3b1e731ab43ffcaa8d84c4ed0cffd4bc5192ce62ad344ca2502f4aed4adeea43`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 21.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 730 | raw authored units |
| recharge | 6.17 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 500 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 440000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH133: Warthog 8

Family: warthog-10-guard. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `b42705e6580d0e556b000c4f5e2349f47cb8f58d426b5583e7ce54dd6520de1f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 21.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 730 | raw authored units |
| recharge | 6.17 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 500 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 440000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH134: Warthog 9 Heavy

Family: warthog-10-guard. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4e7e64faca9b28045ebb9ce0e1e978c3591038154f035962f65ba83268cd01e8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 440 | t |
| speed | 21.3 | raw authored units |
| acceleration | 5.4 | raw authored units |
| energy | 730 | raw authored units |
| recharge | 6.17 | raw authored units |
| roll | 0.42 | raw authored units |
| pitch | 0.37 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 500 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 175 | t |
| price | 440000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH135: Javelina

Family: javelina. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ea1f51b9bc1795f8caab877ade2c5db0a91ea6ea449bcf3d84445cc202cb1a7c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 52 | t |
| speed | 39.6 | raw authored units |
| acceleration | 10.6 | raw authored units |
| energy | 270 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.95 | raw authored units |
| pitch | 0.84 | raw authored units |
| yaw | 0.78 | raw authored units |
| shield | 230 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 20 | t |
| price | 220000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH136: Falcon Mk I

Family: falcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ac20a0e324c59e4eb423755cb90eef9ea98365b630da7df497ef728400e3c3aa`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 10 | t |
| speed | 53.9 | raw authored units |
| acceleration | 17.2 | raw authored units |
| energy | 280 | raw authored units |
| recharge | 4.18 | raw authored units |
| roll | 1.47 | raw authored units |
| pitch | 1.29 | raw authored units |
| yaw | 1.21 | raw authored units |
| shield | 250 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 10 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 255000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH137: Falcon Mk II

Family: falcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d50c75cc0b37b7ef8c39f516f818576af75cafdbb05e4f74de3ab031248b1220`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 10 | t |
| speed | 53.0 | raw authored units |
| acceleration | 16.8 | raw authored units |
| energy | 310 | raw authored units |
| recharge | 4.52 | raw authored units |
| roll | 1.42 | raw authored units |
| pitch | 1.25 | raw authored units |
| yaw | 1.16 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 10 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 268000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH138: Falcon Mk III

Family: falcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `3412b1413e353f77bf2f9ee3cedcd31758bba9dca96f199f53520dd2ad87af3b`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 12 | t |
| speed | 52.0 | raw authored units |
| acceleration | 16.4 | raw authored units |
| energy | 340 | raw authored units |
| recharge | 4.85 | raw authored units |
| roll | 1.38 | raw authored units |
| pitch | 1.21 | raw authored units |
| yaw | 1.13 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.2 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 11 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 281000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH139: Falcon Mk IV

Family: falcon. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `69735ecb194eca6f96cb8d9d49dd0ac009335d63c2acbcdd485a28743f8a8969`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 12 | t |
| speed | 51.0 | raw authored units |
| acceleration | 16.0 | raw authored units |
| energy | 380 | raw authored units |
| recharge | 5.19 | raw authored units |
| roll | 1.33 | raw authored units |
| pitch | 1.17 | raw authored units |
| yaw | 1.09 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 2.3 | raw authored units |
| fuel | 110 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 9 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 295000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH140: Chimango

Family: chimango. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `03d9c9e1b628b26c7d93c130d858372f040700a69bb6e7c56008b17faccc4c6c`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 53.0 | raw authored units |
| acceleration | 16.0 | raw authored units |
| energy | 290 | raw authored units |
| recharge | 4.1 | raw authored units |
| roll | 1.35 | raw authored units |
| pitch | 1.19 | raw authored units |
| yaw | 1.11 | raw authored units |
| shield | 240 | raw authored units |
| shieldRecharge | 1.9 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 252000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH141: Salamander Station

Family: salamander-station. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `af7d68bdb9cae6df9631c377b798bad86c1b0fbade59b4906eb91a0c08b766e3`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH142: Buzzard Mk II

Family: buzzard. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ea4d5a8453ac0bfa415c59f526cd6e33a9396eea1582008072aea637ae0035de`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 24 | t |
| speed | 48.9 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 330 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 1.28 | raw authored units |
| pitch | 1.13 | raw authored units |
| yaw | 1.05 | raw authored units |
| shield | 270 | raw authored units |
| shieldRecharge | 1.99 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 263000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH143: Aardvark Miner

Family: aardvark. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `06c87bca58327483a6996f1fd11fae0c8204867847fccaa4aaaa222c6549b2ac`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 86 | t |
| speed | 27.0 | raw authored units |
| acceleration | 8.5 | raw authored units |
| energy | 380 | raw authored units |
| recharge | 3.85 | raw authored units |
| roll | 0.65 | raw authored units |
| pitch | 0.57 | raw authored units |
| yaw | 0.53 | raw authored units |
| shield | 340 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 35 | t |
| price | 253000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH144: Razorback

Family: razorback. Role: trader.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `91f998359db7d648631ceffc109a5d43fe5b08ee9034c70e6f3e736df73ecb9e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 58 | t |
| speed | 40.7 | raw authored units |
| acceleration | 10.4 | raw authored units |
| energy | 230 | raw authored units |
| recharge | 3.2 | raw authored units |
| roll | 0.92 | raw authored units |
| pitch | 0.81 | raw authored units |
| yaw | 0.75 | raw authored units |
| shield | 210 | raw authored units |
| shieldRecharge | 1.5 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 25 | t |
| price | 208000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH145: Kestrel

Family: kestrel. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `2c6b5efb05ea6ce80873bd9355044f3389b1115893bc41d9379d99160460e8cd`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 45.0 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 263000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH146: Merlin

Family: merlin. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6dfbb1dd5cd186521a569f06418a5b7984aac4ec0d1fb22e1bef4c89ebcba2bd`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 45.0 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 263000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH147: Hawk

Family: hawk. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: False. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `10ea063080b62c95000bd77bb5332ae80b644e05585c5246a38a3727a3c79620`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","design","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","approved-original-mesh-missing"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;&#93;

Hull metadata differences: &#91;&#93;

## SH148: Morepork

Family: morepork. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `ebd489c910f9038e9209d5be6fc31b1a8ef0fcbc03688138a166aee49ce549d9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH149: Owlet Mk II

Family: owlet. Role: bountyHunter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `e52d3ef2327e66a38e999495d523228ba863a812fc109b34e1309f7d4091204f`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 50.5 | raw authored units |
| acceleration | 15.6 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.43 | raw authored units |
| roll | 1.3 | raw authored units |
| pitch | 1.14 | raw authored units |
| yaw | 1.07 | raw authored units |
| shield | 260 | raw authored units |
| shieldRecharge | 1.99 | raw authored units |
| fuel | 150 | 0.1 LY (raw tenths) |
| jump | 11 | LY |
| spool | 12 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 266000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH150: Reindeer Freighter

Family: reindeer. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `1de00521b98fc1d4b9e360a9565da0037fac2edcc7505b067ae56939ece5e9b9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 528 | t |
| speed | 20.8 | raw authored units |
| acceleration | 5.2 | raw authored units |
| energy | 740 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.41 | raw authored units |
| pitch | 0.36 | raw authored units |
| yaw | 0.34 | raw authored units |
| shield | 480 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 210 | t |
| price | 456000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH151: Lynx Escort

Family: lynx. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `884d0487008caf5f5833878748ca35f13483b8120867af045ba0af235cbe8cee`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 41.4 | raw authored units |
| acceleration | 12.9 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH152: Osprey Scout

Family: osprey. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `f66d26d4f7f9f502d52fc771edf0ccdf8f5120c7e991c53ce2b10105f3d10009`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH153: Osprey Strike

Family: osprey. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `41e24258bc2081f97c14637e66c48791a64042a0187a1cae3cec1cb2bf1cb206`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH154: Osprey Patrol

Family: osprey. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `96ceab69a0a2f990763c89f686baf8a120f82c0e5b3b72dcf87e4de2265f85a9`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 41.4 | raw authored units |
| acceleration | 12.9 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH155: Osprey Carrier

Family: osprey. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `71bad31603d9f279e072003860f51d5014c573ac6d99511d576a1f929ce4e05a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 41.4 | raw authored units |
| acceleration | 12.9 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.1 | raw authored units |
| pitch | 0.97 | raw authored units |
| yaw | 0.9 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 261000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH156: Lion Bastion

Family: lion-bastion. Role: platform.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `d254026ff1f1fe2defa4e3f2e9cae38d823859ce637d307bc9be922c374612fd`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH157: Wolf Scout

Family: wolf. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `89eab84d27345d09149fb4ad75fd608ece95fe3d73665eff5c72894a83b698e7`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 41.9 | raw authored units |
| acceleration | 13.2 | raw authored units |
| energy | 400 | raw authored units |
| recharge | 4.99 | raw authored units |
| roll | 1.07 | raw authored units |
| pitch | 0.94 | raw authored units |
| yaw | 0.88 | raw authored units |
| shield | 330 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 276000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH158: Wolf Mk I

Family: wolf. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `0a14f0d17d98474b212ff0e32657e1bc05470f84b476a34dc4db3c68c57189e8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 14 | t |
| speed | 48.2 | raw authored units |
| acceleration | 14.8 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.21 | raw authored units |
| pitch | 1.06 | raw authored units |
| yaw | 0.99 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 268000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH159: Wolf Mk II

Family: wolf. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `059e9fd94c6dfb686efadc0598cad0f2d39646fa204297668f449e69b8ff9c80`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 47.3 | raw authored units |
| acceleration | 14.5 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 5.18 | raw authored units |
| roll | 1.17 | raw authored units |
| pitch | 1.03 | raw authored units |
| yaw | 0.96 | raw authored units |
| shield | 310 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 288000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH160: Wolf Cutter

Family: wolf. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `f80c91f2bc06b003ccd5d7fb492e2f7b2f6ec10d66d2cfb1abf8149c0a67d343`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 43.6 | raw authored units |
| acceleration | 14.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.15 | raw authored units |
| pitch | 1.01 | raw authored units |
| yaw | 0.94 | raw authored units |
| shield | 290 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 140 | 0.1 LY (raw tenths) |
| jump | 10 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 265000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH161: Wolf Citadel

Family: wolf. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `289ac26fa01b66a0801345ffc27426a7b538f054ecb1eeaf6ce0f8c0c24238c8`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH162: Larvaal Probe

Family: larvaal-probe. Role: other.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a597ff8c679505e1b474f148a7bd0c7a5bc850312a55c1c95156f4932c1e575a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH163: Lammergeier

Family: lammergeier. Role: pirate.

Authored playerFlyable: False. Access: not authored. Purchase policy: pendingFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `a629eb2c13f1b41f7166db267b9e9af9d286827e88a14be22723269d44af11ee`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH164: Toad Drug Factory

Family: toad-drug-factory. Role: station.

Authored playerFlyable: False. Access: not authored. Purchase policy: never.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `5028093b27c9ce34d4ea5d70dc3e59e0724b15a08291073018cb2e2ae1042b86`.

| Field | Authored value | Unit |
| --- | --- | --- |
| Performance | Not authored (display object) | Not applicable |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"display","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH165: Secretarybird

Family: secretarybird. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `c65b4bb808b439d7f601833c2152a717e434f14ad2ce853c12ca6a7584df5695`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH166: Camel Rescue

Family: camel. Role: transporter.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `f4e204b6a745a985461e5c75353a97c049e4547deb39715e6db3e96220326327`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 352 | t |
| speed | 24.2 | raw authored units |
| acceleration | 5.9 | raw authored units |
| energy | 740 | raw authored units |
| recharge | 5.23 | raw authored units |
| roll | 0.45 | raw authored units |
| pitch | 0.4 | raw authored units |
| yaw | 0.37 | raw authored units |
| shield | 460 | raw authored units |
| shieldRecharge | 1.7 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 14 | seconds |
| missiles | 6 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 140 | t |
| price | 416000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH167: Secretarybird Survey

Family: secretarybird. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `214cb06eaf0b913bbd7ea18169654fadef81e7be514f14c0fb0dc7c00dcf3e38`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 18 | t |
| speed | 42.3 | raw authored units |
| acceleration | 13.4 | raw authored units |
| energy | 360 | raw authored units |
| recharge | 5.66 | raw authored units |
| roll | 1.13 | raw authored units |
| pitch | 0.99 | raw authored units |
| yaw | 0.93 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 262000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH168: Armadillo Miner

Family: armadillo. Role: miner.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `4c447765e1806dd25e805effdedc05eca3b8ed041f981c12d79712d9f841507a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 80 | t |
| speed | 31.9 | raw authored units |
| acceleration | 9.4 | raw authored units |
| energy | 290 | raw authored units |
| recharge | 3.7 | raw authored units |
| roll | 0.71 | raw authored units |
| pitch | 0.62 | raw authored units |
| yaw | 0.58 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 1.8 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 30 | t |
| price | 224000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH169: Caracara Mk I

Family: caracara. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `360ccadf49d8e326388e6a488bfa07406a18ec512a9c5cca38f012b3fee8f30e`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.9 | raw authored units |
| acceleration | 15.4 | raw authored units |
| energy | 320 | raw authored units |
| recharge | 4.8 | raw authored units |
| roll | 1.32 | raw authored units |
| pitch | 1.16 | raw authored units |
| yaw | 1.08 | raw authored units |
| shield | 280 | raw authored units |
| shieldRecharge | 2.0 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 7 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 259000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH170: Caracara Mk II

Family: caracara. Role: military.

Authored playerFlyable: True. Access: not authored. Purchase policy: blueprintFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `8dd301d3ea3cd11f67d4851b0c1b8f6dde26b502139cd8801d9aa4c407763305`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 16 | t |
| speed | 45.1 | raw authored units |
| acceleration | 15.0 | raw authored units |
| energy | 350 | raw authored units |
| recharge | 5.18 | raw authored units |
| roll | 1.28 | raw authored units |
| pitch | 1.13 | raw authored units |
| yaw | 1.05 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 120 | 0.1 LY (raw tenths) |
| jump | 8 | LY |
| spool | 12 | seconds |
| missiles | 8 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 5 | t |
| price | 272000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;

## SH171: Medusa

Family: medusa. Role: alien.

Authored playerFlyable: True. Access: not authored. Purchase policy: plughQuestFabrication.

Approved mesh available: True. Runtime ready: False. Current loader compatible: False.

Spec SHA-256: `6481d8b9e9ad906c31e1be5f0ad3deb790af20be490728e970b90e043f8d6b0a`.

| Field | Authored value | Unit |
| --- | --- | --- |
| cargo | 22 | t |
| speed | 50.3 | raw authored units |
| acceleration | 18.0 | raw authored units |
| energy | 410 | raw authored units |
| recharge | 4.7 | raw authored units |
| roll | 1.37 | raw authored units |
| pitch | 1.21 | raw authored units |
| yaw | 1.12 | raw authored units |
| shield | 300 | raw authored units |
| shieldRecharge | 2.1 | raw authored units |
| fuel | 130 | 0.1 LY (raw tenths) |
| jump | 9 | LY |
| spool | 12 | seconds |
| missiles | 5 | count |
| facings | 15 | facing bit mask |
| cargoExpansion | 10 | t |
| price | 288000 | credits |

Missing loader fields: &#91;"appearances","catalogue","evidence","geometryContext","profiles","refit","shipClass"&#93;

Dependencies: &#91;"catalogue-metadata","unit-scale-authority","original-cargo-and-accommodation-contract","unsupported-purchase-policy","remove-legacy-SH171-exclusivity","authored-texture-adapter","approved-original-native-geometry-adapter"&#93;

Current native range/field issues: &#91;&#93;

Unmapped spec fields: &#91;"balance","family","license","playerFlyable","purchasePolicy","role","status"&#93;

Unsupported design fields: &#91;"faceTextures","textures"&#93;

Hull metadata differences: &#91;&#93;
