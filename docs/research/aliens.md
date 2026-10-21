# Deduplicated alien and inhabitant catalogue

This list distinguishes intelligent races, generated planetary inhabitants, creatures and artificial entities. A similar description is not proof of a shared biological species. Conversely, an adjective or colour is not enough to establish a new species. Version identifiers resolve in [versions](versions.md) and evidence in [sources](sources.md).

## Intelligent races and classic inhabitant categories

`Classic inhabitants` refers to the planetary-description system of original Elite and its derivatives, as documented by S24. The reference does not establish an independently verified binary mapping for every port. It must not be interpreted as proof that Dangerous contains those groups as spacefaring civilisations.

| ID | Canonical entry | Aliases | Supported versions or continuity | Classification | Evidence |
| --- | --- | --- | --- | --- | --- |
| AL01 | Humans | Human Colonials, humanity | Classic Elite, OOLITE, FE2, FFE, ED-LIVE, ED-LEGACY | Humans are included for continuity; colonials are not another species. | S24, D12 |
| AL02 | Humanoids | Humanoid inhabitants; Chemeliads (Ionics named population) | Classic inhabitants; OOLITE; OOLITE-OXP P18 1.3.1 | Generated category; Ionics describes Cevera's black furry humanoid population as Chemeliads. A named subpopulation does not establish a separately modelled species. | S24, O07 |
| AL03 | Avians | Birds, bird-forms | Classic inhabitants; OOLITE | Generated category. | S24 |
| AL04 | Batrachians | Frogs, amphibian forms | Classic inhabitants; OOLITE | Generated category. | S24 |
| AL05 | Felines | Cats, felinoids | Classic inhabitants; OOLITE; OOLITE-OXP P25 2.0 | Generated category; Love Cats uses feline characters without establishing an additional biological species. | S24, O07 |
| AL06 | Insectoids | Insects | Classic inhabitants; OOLITE | Do not merge automatically with Thargoids. | S24 |
| AL07 | Reptilians | Lizards, reptile forms | Classic inhabitants; OOLITE | Generated category. | S24 |
| AL08 | Lobstoids | Lobsters; Zskthak (Deposed character) | Classic inhabitants; OOLITE; OOLITE-OXP P09 2.1 | Generated category; Zskthak is a named blue horned lobster character, not another species. | S24, O07 |
| AL09 | Rodents | Rats | Classic inhabitants; OOLITE | Generated category. | S24 |
| AL10 | Thargoids | Thargoid race | BBC-TAPE, BBC-DISC, BBC-SP, BBC-MASTER, BBC-COMPACT, C64, APPLE2, NES; ARC, MSX-DISC, ZX128 reference, ST, AMIGA; ELITE-A, FFE, OOLITE, ED-LIVE, ED-LEGACY | Named intelligent alien species; histories differ by continuity. | S01, S07, S08, S19, S41, S42, D09 |
| AL11 | Guardians | Homo Custos | ED-LIVE, ED-LEGACY lore and ruins | Extinct intelligent species. Do not confuse the civilisation with human skimmers named Guardian. | D11, D12 |
| AL12 | Constructs | Guardian artificial intelligences | ED-LIVE, ED-LEGACY Guardian history | Artificial intelligence created by Guardians; not a biological species. | D11 |
| AL13 | Trumbles | Tribbles, Little Squeakys | C64, NES, PC-PLUS reported, OOLITE | Infestation creatures; a common mission identity with naming differences. | S06, S08, S34, S35, O05 |
| AL14 | Groigans | No additional alias established | ARC, ARC-GOLD, C12 | Named disease-affected population in mission reports; species taxonomy and visible model unresolved. | S40 |
| AL15 | Stellar Serpent | Space serpent | OOLITE-OXP P37 1.21 only | Fan expansion creature with articulated head/body/tail, recurring hunt and 500-credit scripted reward. Anatomical parts are not separate species or spacecraft models. | O07 |
| AL16 | Shrews | Shrew people; White-spot/Long-ear and other named individuals | OOLITE-OXP P34 0.8 only | Fan-defined emerging sapient population in Shrews' Rights. Named characters are not additional species; not automatically identical to the generated Rats category. Station/space campaign adaptation, with original ground scenes reference-only. | O07; [campaign graph](data/shrews-mission-graph.json) |

FE2 has no normally encountered Thargoid campaign; hidden/debug craft or manual references are not regular playable alien encounters. ELECTRON has no Thargoids. Presence of a race in prose does not prove a visible alien character model. [S01, S18, S21]

## Alien vehicles and artificial units

Alien spacecraft are listed once in [ships](ships.md), including Thargoid warship, Thargon, Scouts, Interceptors, Hunters and Titan. They are not extra species. Thargon describes a classic robot fighter and Dangerous swarm drone with separate game profiles. XG7 Trident, XG8 Javelin and XG9 Lance are Guardian-derived human-operated fighters, not three new alien races. [D08, D09]

| ID | Entity | Versions | Classification and behaviour | Evidence |
| --- | --- | --- | --- | --- |
| AX01 | Guardian Sentinel | ED-LIVE, ED-LEGACY Guardian sites | Autonomous defensive unit; hostile site security, not a living Guardian. | D02, D11 |
| AX02 | Thargoid Scavenger | ED-LIVE, ED-LEGACY structures | Alien maintenance unit; exact aggression depends on interaction. | D09 |
| AX03 | Thargoid Revenant | ED-LIVE | Surface combat machine associated with invaded settlements. | D09 |
| AX04 | Thargoid Banshee | ED-LIVE | Larger surface combat unit; not another race. | D09 |

## Non-sapient biological content

Dangerous also has a large exobiology inventory, separate from the spacefaring-race list. The inspected organism index includes Aleoida, Amphora Plant, Anemone, Bacterium, Bark Mounds, Brain Trees, Cactoida, Clypeus, Concha, Crystalline Shards, Electricae, Fonticulua, Frutexa, Fumerola, Fungoida, Osseus, Recepta, Stratum, Tubus and Tussock. Treat these as organism groups or genera, not individual species. A complete species-and-colour census is not supplied here. [D13]

Dolphins in FFE's Junior mission are terrestrial animals, not a new alien species. Classic planetary descriptions also mention local wildlife; named description tokens are not automatically implemented encounter creatures. Named Oric targets in the new campaign evidence are character instances, not proof of new species. Deposed 2.1's Peldorian Arachnid family is a fan-defined group named in the investigation, not an independently established extra biological species; its family members are not duplicate species rows. Zskthak is a blue horned lobster character within the existing lobster category. [O07](sources.md) Fan expansion races and creatures remain tied to their specific packs rather than silently added to official continuity.

## Requirements for faithful alien behaviour

Use a continuity identifier, biological/artificial classification, social role and per-version behaviour profile. Keep Thargoid hostility, diplomacy, cargo scanning, special technology interactions and vessel AI separate from species identity. FFE's diplomatic vaccine branch must not inherit Dangerous's combat response automatically. Classic animal-form inhabitants need a description generator; they do not justify inventing walking NPC models or faction politics.

Store generated descriptions as structured adjective/category selections when reproducing the original system, and preserve its seeds and vocabulary for the selected edition. If the new game instead creates genuinely separate named species, mark that as original design.
