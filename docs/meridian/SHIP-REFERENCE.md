# New L337 ship definitions and images - final reference

[Return to the oracle contents](README.md). This reading view is extracted from [the complete single-file oracle](FINAL-GAME-ORACLE.md); its rules are the same.

This is the original L337 fleet, from Mule SH001 through Medusa SH171. It does not use the predecessor catalogue names, models or `main` branch ship GIFs. The exact authored specification and authenticated original model/material/UV data are included beside each record. Its role, flyability and purchase policy remain explicit; a familiar ID does not import a previous ship's crew, dimensions or weapons.

The three-view illustrations are source-geometry reference illustrations generated directly from the exact new original vertices, faces and material colours. They are not game-renderer screenshots or AI reconstructions. Their normalised display scale is not a physical-unit or docking-clearance measurement. Original texture assets and UV bindings are retained in the adjacent model/texture data. This reference deliberately reveals the Medusa for review; the game does not reveal it before the legitimate quest encounter.

Hull-native numerical values are used verbatim. Cargo is tonnes; fuel is stored in tenths of a light-year at standard cost; reach is light-years; spool is seconds; pitch/roll/yaw are radians per second; price is credits. Speed, acceleration, energy and shield fields use the original native gameplay unit system. Declared metre geometry stays in metres; uncalibrated source coordinates are not silently renamed metres. Equipment tables describe how actual installed devices modify these base figures.

**E01 - explicit original-fleet accommodation estimate.** Where an original hull has no independently authored crew/equipment capacity, use its own cargo C and authored size tier T. Set equipment budget E = 8 + ceil(C / 5). Use equivalent-volume proxy V = 0.5, 1, 4, 16 or 64 for T = 1, 2, 3, 4 or 5. Estimated operating complement including commander is max(1, 1 + floor(0.5 * max(0, sqrt(V) - 1) + max(E / 24, C / 200))). Reserve the same number of intrinsic crew places. These are labelled final-game design estimates, not historical complements or actual cubic metres. They use size, equipment and cargo without borrowing an unrelated old SH-ID profile. A specific authored original-hull accommodation contract overrides E01.

Initial passenger cabins are zero unless an explicit original-hull or mission grant says otherwise. Each purchased cabin consumes 5 tonnes and one equipment-budget unit; its grade supplies the declared actual places. The shown empty-fit ceiling ignores all other equipment/cargo, so it is a planning bound rather than instant free passenger accommodation. Actual jobs must reserve compatible empty fitted places; operating quarters cannot be counted again. Station/environment objects do not acquire invented player crew or fitting budgets.

The facing mask uses Front = 1, Rear = 2, Left = 4 and Right = 8. It declares supported combat mount positions, not a set of free fitted lasers. One supported forward combat mount, a normal hyperspace foundation and finite missile provision form the normal flyable baseline; mission-specific fitted loadouts and structural exceptions retain their own original definitions. Docking capability remains an explicit fitted computer capability, not a grant of later paid targeting history.

| ID | New L337 hull | Role | Flyable | Cargo t | Speed u/s | Energy | Shield per bank | Missiles | Jump LY | Price CR |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| SH001 | Mule | trader | yes | 64 | 34.8 | 270 | 240 | 5 | 9 | 216000 |
| SH002 | Gyrfalcon Assault | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH003 | Gyrfalcon Command | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH004 | Gyrfalcon Patrol | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH005 | Bison | transporter | yes | 1108 | 17.7 | 1120 | 590 | 7 | 7 | 690000 |
| SH006 | Bison Mk II | transporter | yes | 1220 | 17.4 | 1260 | 640 | 8 | 7 | 761000 |
| SH007 | Impala Voyager | leisure | yes | 38 | 38.6 | 230 | 220 | 5 | 10 | 208000 |
| SH008 | Goshawk Explorer | leisure | yes | 32 | 39.5 | 230 | 230 | 5 | 10 | 211000 |
| SH009 | Goshawk Mk II | military | yes | 20 | 41.5 | 400 | 330 | 8 | 8 | 281000 |
| SH010 | Goshawk Mk II Custom | military | yes | 20 | 41.5 | 400 | 330 | 8 | 8 | 281000 |
| SH011 | Goshawk Scout | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH012 | Sable Liner | leisure | yes | 28 | 40.7 | 220 | 220 | 5 | 12 | 212000 |
| SH013 | Buffalo | transporter | yes | 396 | 21.9 | 710 | 470 | 6 | 10 | 424000 |
| SH014 | Buffalo Mk II | transporter | yes | 436 | 21.5 | 800 | 510 | 7 | 10 | 465000 |
| SH015 | Raven | pirate | yes | 28 | 46.9 | 220 | 170 | 5 | 8 | 208000 |
| SH016 | Mole Miner | miner | yes | 108 | 26.7 | 340 | 310 | 5 | 8 | 242000 |
| SH017 | Mole Prospector | miner | yes | 108 | 26.7 | 340 | 310 | 5 | 8 | 242000 |
| SH018 | Donkey | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH019 | Gazelle Explorer | leisure | yes | 28 | 40.7 | 220 | 220 | 5 | 12 | 212000 |
| SH020 | Crow Prototype | pirate | yes | 22 | 49.5 | 210 | 170 | 5 | 10 | 216000 |
| SH021 | Zebra | trader | yes | 62 | 34.4 | 300 | 260 | 5 | 9 | 226000 |
| SH022 | Peregrine Mk I | trader | yes | 64 | 37.0 | 260 | 230 | 5 | 9 | 215000 |
| SH023 | Peregrine Mk III | trader | yes | 78 | 35.7 | 320 | 270 | 7 | 9 | 246000 |
| SH024 | Peregrine Mk IV | trader | yes | 84 | 35.0 | 350 | 290 | 8 | 9 | 261000 |
| SH025 | Peregrine Mk V | trader | yes | 92 | 34.3 | 380 | 300 | 9 | 9 | 274000 |
| SH026 | Harrier | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH027 | Ibex | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH028 | Lion Citadel | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH029 | Burro | trader | yes | 52 | 39.6 | 270 | 230 | 5 | 9 | 220000 |
| SH030 | Sparrowhawk | bountyHunter | yes | 22 | 49.8 | 300 | 250 | 5 | 9 | 250000 |
| SH031 | Kite Interceptor | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH032 | Panther Explorer | leisure | yes | 28 | 46.2 | 190 | 200 | 5 | 10 | 205000 |
| SH033 | Panther Scout | military | yes | 16 | 49.5 | 310 | 270 | 7 | 8 | 257000 |
| SH034 | Frog Station | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH035 | Stag Liner | leisure | yes | 26 | 44.9 | 230 | 220 | 5 | 10 | 217000 |
| SH036 | Zebu | trader | yes | 58 | 35.9 | 260 | 230 | 5 | 11 | 217000 |
| SH037 | Vulture Mk I | pirate | yes | 14 | 58.3 | 140 | 140 | 4 | 8 | 213000 |
| SH038 | Vulture Mk II | pirate | yes | 14 | 57.2 | 160 | 150 | 5 | 8 | 220000 |
| SH039 | Vulture Mk III | pirate | yes | 16 | 56.2 | 180 | 160 | 6 | 8 | 228000 |
| SH040 | Newt Escape Pod | capsule | yes | 0 | 18 | 70 | 30 | 0 | 0 | 0 |
| SH041 | Serval Fighter | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH042 | Saker | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH043 | Eagle Cruiser | military | yes | 172 | 22.8 | 1490 | 600 | 10 | 7 | 0 |
| SH044 | Harpy Assault | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH045 | Erne Corvette | military | yes | 18 | 41.9 | 400 | 330 | 7 | 8 | 276000 |
| SH046 | Harpy Dropship | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH047 | Harpy Gunship | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH048 | Lanner | bountyHunter | yes | 12 | 65.3 | 190 | 190 | 4 | 9 | 246000 |
| SH049 | Hyena | pirate | yes | 24 | 51.0 | 210 | 170 | 5 | 8 | 214000 |
| SH050 | Yak | trader | yes | 58 | 35.9 | 260 | 230 | 5 | 11 | 217000 |
| SH051 | Jackal | pirate | yes | 24 | 47.9 | 220 | 180 | 5 | 8 | 212000 |
| SH052 | Percheron | trader | yes | 58 | 40.7 | 230 | 210 | 5 | 9 | 208000 |
| SH053 | Percheron Prototype | military | yes | 16 | 49.5 | 310 | 270 | 7 | 8 | 257000 |
| SH054 | Hobby Fighter | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH055 | Condor | pirate | yes | 28 | 46.9 | 220 | 170 | 5 | 8 | 208000 |
| SH056 | Aplomado Interceptor | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH057 | Falconet | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH058 | Brabant | transporter | yes | 418 | 21.0 | 820 | 540 | 6 | 8 | 463000 |
| SH059 | Barbary | military | yes | 22 | 41.4 | 360 | 300 | 7 | 8 | 261000 |
| SH060 | Wombat | miner | yes | 72 | 31.0 | 340 | 290 | 5 | 8 | 235000 |
| SH061 | Haflinger | trader | yes | 78 | 34.0 | 270 | 230 | 5 | 9 | 216000 |
| SH062 | Moose Clipper | transporter | yes | 396 | 24.9 | 630 | 440 | 6 | 8 | 397000 |
| SH063 | Seriema Courier | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH064 | Arna Cutter | transporter | yes | 396 | 24.9 | 630 | 440 | 6 | 8 | 397000 |
| SH065 | Vulture Raider | pirate | yes | 14 | 58.3 | 140 | 140 | 4 | 8 | 213000 |
| SH066 | Rabbit Explorer | leisure | yes | 28 | 46.2 | 190 | 200 | 5 | 10 | 205000 |
| SH067 | Rhinoceros Trader | trader | yes | 52 | 39.6 | 270 | 230 | 5 | 9 | 220000 |
| SH068 | Badger | miner | yes | 108 | 26.7 | 340 | 310 | 5 | 8 | 242000 |
| SH069 | Baza Fighter | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH070 | Baza Mk II | bountyHunter | yes | 20 | 53.1 | 290 | 250 | 6 | 9 | 261000 |
| SH071 | Griffon | pirate | yes | 22 | 47.4 | 240 | 190 | 5 | 8 | 216000 |
| SH072 | Griffon Mk II | pirate | yes | 26 | 46.6 | 270 | 210 | 6 | 8 | 230000 |
| SH073 | Griffon Spectre | pirate | yes | 22 | 47.4 | 240 | 190 | 5 | 8 | 216000 |
| SH074 | Dzo | transporter | yes | 396 | 21.9 | 710 | 470 | 6 | 10 | 424000 |
| SH075 | Dzo Mk II | transporter | yes | 436 | 21.5 | 800 | 510 | 7 | 10 | 465000 |
| SH076 | Hog | transporter | yes | 418 | 21.0 | 820 | 540 | 6 | 8 | 463000 |
| SH077 | Tamaraw | transporter | yes | 396 | 21.9 | 710 | 470 | 6 | 10 | 424000 |
| SH078 | Oryx Voyager | leisure | yes | 32 | 39.5 | 230 | 230 | 5 | 10 | 211000 |
| SH079 | Carabao Carrier | transporter | yes | 786 | 19.6 | 970 | 550 | 7 | 7 | 580000 |
| SH080 | Carabao Highliner | transporter | yes | 786 | 19.6 | 970 | 550 | 7 | 7 | 580000 |
| SH081 | Jaguar | military | yes | 144 | 23.3 | 1480 | 620 | 10 | 7 | 0 |
| SH082 | Cheetah | bountyHunter | yes | 14 | 55.2 | 250 | 240 | 4 | 9 | 246000 |
| SH083 | Hare Explorer | leisure | yes | 32 | 39.5 | 230 | 230 | 5 | 10 | 211000 |
| SH084 | Llama | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH085 | Laggar | bountyHunter | yes | 18 | 54.1 | 260 | 230 | 5 | 9 | 249000 |
| SH086 | Alpaca | trader | yes | 62 | 34.4 | 300 | 260 | 5 | 9 | 226000 |
| SH087 | Elk | trader | yes | 62 | 34.4 | 300 | 260 | 5 | 9 | 226000 |
| SH088 | Springbok Starliner | leisure | yes | 38 | 38.6 | 230 | 220 | 5 | 10 | 208000 |
| SH089 | Antelope | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH090 | Elephant | trader | yes | 52 | 39.6 | 270 | 230 | 5 | 9 | 220000 |
| SH091 | Gopher | miner | yes | 108 | 26.7 | 340 | 310 | 5 | 8 | 242000 |
| SH092 | Aubrac | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH093 | Giraffe Liner | leisure | yes | 30 | 39.1 | 250 | 250 | 5 | 10 | 218000 |
| SH094 | Ictinia | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH095 | Ictinia X | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH096 | Wisent | transporter | yes | 188 | 26.5 | 410 | 360 | 5 | 8 | 286000 |
| SH097 | Wisent Mk II | transporter | yes | 206 | 26.0 | 460 | 390 | 6 | 8 | 311000 |
| SH098 | Anoa | transporter | yes | 396 | 24.9 | 630 | 440 | 6 | 8 | 397000 |
| SH099 | Ox | transporter | yes | 440 | 22.6 | 710 | 470 | 6 | 8 | 429000 |
| SH100 | Ox Mk II | transporter | yes | 484 | 22.2 | 800 | 510 | 7 | 8 | 472000 |
| SH101 | Dorcas Racer | leisure | yes | 26 | 44.9 | 230 | 220 | 5 | 10 | 217000 |
| SH102 | Dhole Haven | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH103 | Redtail Mk III | bountyHunter | yes | 22 | 54.7 | 370 | 270 | 7 | 9 | 287000 |
| SH104 | Wildebeest | trader | yes | 62 | 34.4 | 300 | 260 | 5 | 9 | 226000 |
| SH105 | Tapir Shuttle | transporter | yes | 440 | 21.3 | 730 | 500 | 6 | 8 | 440000 |
| SH106 | Tapir Mk II | transporter | yes | 484 | 20.9 | 820 | 540 | 7 | 8 | 482000 |
| SH107 | Magpie | pirate | yes | 22 | 49.5 | 210 | 170 | 5 | 10 | 216000 |
| SH108 | Besra | bountyHunter | yes | 20 | 49.3 | 330 | 270 | 5 | 9 | 258000 |
| SH109 | Hippo | trader | yes | 58 | 40.7 | 230 | 210 | 5 | 9 | 208000 |
| SH110 | Leopard Fighter | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH111 | Puma | military | yes | 16 | 49.5 | 310 | 270 | 7 | 8 | 257000 |
| SH112 | Larvaal Warden | alien | yes | 28 | 47.0 | 390 | 310 | 5 | 9 | 280000 |
| SH113 | Larvaal Ravager | alien | yes | 28 | 47.0 | 390 | 310 | 5 | 9 | 280000 |
| SH114 | Larvaal Sentinel | alien | yes | 24 | 47.9 | 350 | 290 | 5 | 9 | 271000 |
| SH115 | Larvaal Lancer | alien | yes | 24 | 47.9 | 350 | 290 | 5 | 9 | 271000 |
| SH116 | Larvaal Broodlord | alien | yes | 34 | 43.2 | 410 | 320 | 5 | 9 | 281000 |
| SH117 | Larvaal Provoker | alien | yes | 22 | 50.3 | 410 | 300 | 5 | 9 | 288000 |
| SH118 | Larvaal Reaver | alien | yes | 22 | 50.3 | 410 | 300 | 5 | 9 | 288000 |
| SH119 | Larvaal Wraith | alien | yes | 26 | 51.7 | 340 | 290 | 5 | 9 | 273000 |
| SH120 | Larvaal Seeker | alien | yes | 34 | 43.2 | 410 | 320 | 5 | 9 | 281000 |
| SH121 | Larvaal Mender | alien | yes | 26 | 43.7 | 450 | 350 | 5 | 9 | 295000 |
| SH122 | Larvaal Harvester | alien | yes | 22 | 50.3 | 410 | 300 | 5 | 9 | 288000 |
| SH123 | Larvaal Sovereign | alien | yes | 180 | 27.7 | 1660 | 620 | 8 | 8 | 0 |
| SH124 | Larvaal Warship | alien | yes | 28 | 47.0 | 390 | 310 | 5 | 9 | 280000 |
| SH125 | Larvaal Drone | alien | yes | 26 | 43.7 | 450 | 350 | 5 | 9 | 295000 |
| SH126 | Mangalica | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH127 | Gaur Trader | trader | yes | 56 | 37.7 | 230 | 220 | 5 | 9 | 209000 |
| SH128 | Boar Transport | transporter | yes | 374 | 23.1 | 640 | 450 | 6 | 8 | 396000 |
| SH129 | Warthog 10 Guard | military | yes | 36 | 36.8 | 560 | 380 | 8 | 8 | 320000 |
| SH130 | Marmot 11 Prospector | miner | yes | 180 | 23.7 | 530 | 390 | 6 | 8 | 317000 |
| SH131 | Warthog 6 | transporter | yes | 440 | 21.3 | 730 | 500 | 6 | 8 | 440000 |
| SH132 | Warthog 7 | transporter | yes | 440 | 21.3 | 730 | 500 | 6 | 8 | 440000 |
| SH133 | Warthog 8 | transporter | yes | 440 | 21.3 | 730 | 500 | 6 | 8 | 440000 |
| SH134 | Warthog 9 Heavy | transporter | yes | 440 | 21.3 | 730 | 500 | 6 | 8 | 440000 |
| SH135 | Javelina | trader | yes | 52 | 39.6 | 270 | 230 | 5 | 9 | 220000 |
| SH136 | Falcon Mk I | military | yes | 10 | 53.9 | 280 | 250 | 6 | 8 | 255000 |
| SH137 | Falcon Mk II | military | yes | 10 | 53.0 | 310 | 270 | 7 | 8 | 268000 |
| SH138 | Falcon Mk III | military | yes | 12 | 52.0 | 340 | 290 | 8 | 8 | 281000 |
| SH139 | Falcon Mk IV | military | yes | 12 | 51.0 | 380 | 310 | 9 | 8 | 295000 |
| SH140 | Chimango | bountyHunter | yes | 22 | 53.0 | 290 | 240 | 5 | 9 | 252000 |
| SH141 | Salamander Station | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH142 | Buzzard Mk II | bountyHunter | yes | 24 | 48.9 | 330 | 270 | 6 | 9 | 263000 |
| SH143 | Aardvark Miner | miner | yes | 86 | 27.0 | 380 | 340 | 5 | 8 | 253000 |
| SH144 | Razorback | trader | yes | 58 | 40.7 | 230 | 210 | 5 | 9 | 208000 |
| SH145 | Kestrel | military | yes | 18 | 45.0 | 350 | 290 | 7 | 8 | 263000 |
| SH146 | Merlin | military | yes | 18 | 45.0 | 350 | 290 | 7 | 8 | 263000 |
| SH147 | Hawk | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH148 | Morepork | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH149 | Owlet Mk II | bountyHunter | yes | 22 | 50.5 | 320 | 260 | 6 | 11 | 266000 |
| SH150 | Reindeer Freighter | transporter | yes | 528 | 20.8 | 740 | 480 | 6 | 8 | 456000 |
| SH151 | Lynx Escort | military | yes | 22 | 41.4 | 360 | 300 | 7 | 8 | 261000 |
| SH152 | Osprey Scout | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH153 | Osprey Strike | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH154 | Osprey Patrol | military | yes | 22 | 41.4 | 360 | 300 | 7 | 8 | 261000 |
| SH155 | Osprey Carrier | military | yes | 22 | 41.4 | 360 | 300 | 7 | 8 | 261000 |
| SH156 | Lion Bastion | platform | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH157 | Wolf Scout | military | yes | 18 | 41.9 | 400 | 330 | 7 | 8 | 276000 |
| SH158 | Wolf Mk I | military | yes | 14 | 48.2 | 360 | 280 | 7 | 8 | 268000 |
| SH159 | Wolf Mk II | military | yes | 16 | 47.3 | 410 | 310 | 8 | 8 | 288000 |
| SH160 | Wolf Cutter | military | yes | 16 | 43.6 | 350 | 290 | 7 | 10 | 265000 |
| SH161 | Wolf Citadel | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH162 | Larvaal Probe | other | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH163 | Lammergeier | pirate | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH164 | Toad Drug Factory | station | no | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| SH165 | Secretarybird | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH166 | Camel Rescue | transporter | yes | 352 | 24.2 | 740 | 460 | 6 | 8 | 416000 |
| SH167 | Secretarybird Survey | military | yes | 18 | 42.3 | 360 | 300 | 7 | 8 | 262000 |
| SH168 | Armadillo Miner | miner | yes | 80 | 31.9 | 290 | 280 | 5 | 8 | 224000 |
| SH169 | Caracara Mk I | military | yes | 16 | 45.9 | 320 | 280 | 7 | 8 | 259000 |
| SH170 | Caracara Mk II | military | yes | 16 | 45.1 | 350 | 300 | 8 | 8 | 272000 |
| SH171 | Medusa | alien | yes | 22 | 50.3 | 410 | 300 | 5 | 9 | 288000 |

## SH001 - Mule

![SH001 Mule - new L337 source geometry](assets/ships/SH001.png)

**Family:** mule. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 64 | Cargo expansion / t | 25 |
| Speed / native u/s | 34.8 | Acceleration / native u/s2 | 9.6 |
| Energy capacity | 270 | Energy recharge / s | 3.78 |
| Shield capacity per bank | 240 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.88 | Pitch / rad/s | 0.77 |
| Yaw / rad/s | 0.72 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.811 x 1.027 x 3.411; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C06 The Tithe of Worlds; C07 The Still Current; C08 Wayfarer Exchange; C09 The Quiet Nursery; C10 Borrowed Dawn; C11 The Open Shadow; C12 Harbour Without Orders; C13 False Colours; C14 The Rubble Covenant; C15 A Garden in Transit; C16 The Warrant Ledger; C17 The Measure of Care; C18 The Long Return; C19 The Unfinished Map; C20 The Blue Reservoir; C21 Mutual Shelter; C22 The Listening Frontier; C23 An Assembly of Orbits; C24 Under Tow; C25 The Memory Atlas; C26 A Fleet of Neighbours; C27 Uncounted Names; C28 The Honest Circuit; C29 Small Lights; C30 The Passenger's Horizon; C31 The Kind Distance; C32 Cold Reserve; C33 The Magnetic Orchard; C34 Open Measure; C35 The Shared Pulse; C36 The Witness Window; C37 Public Record; C38 Signed Passage; C39 The Guiding Light

[Full definition](definitions/ships/SH001.json) / [Exact model/material/UV data](definitions/models/SH001.json).

## SH002 - Gyrfalcon Assault

![SH002 Gyrfalcon Assault - new L337 source geometry](assets/ships/SH002.png)

**Family:** gyrfalcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.890 x 8.449 x 28.116; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH002.json) / [Exact model/material/UV data](definitions/models/SH002.json).

## SH003 - Gyrfalcon Command

![SH003 Gyrfalcon Command - new L337 source geometry](assets/ships/SH003.png)

**Family:** gyrfalcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.890 x 8.449 x 28.116; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH003.json) / [Exact model/material/UV data](definitions/models/SH003.json).

## SH004 - Gyrfalcon Patrol

![SH004 Gyrfalcon Patrol - new L337 source geometry](assets/ships/SH004.png)

**Family:** gyrfalcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.890 x 8.449 x 28.116; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C06 The Tithe of Worlds

[Full definition](definitions/ships/SH004.json) / [Exact model/material/UV data](definitions/models/SH004.json).

## SH005 - Bison

![SH005 Bison - new L337 source geometry](assets/ships/SH005.png)

**Family:** bison. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 1108 | Cargo expansion / t | 445 |
| Speed / native u/s | 17.7 | Acceleration / native u/s2 | 4.0 |
| Energy capacity | 1120 | Energy recharge / s | 6.44 |
| Shield capacity per bank | 590 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.31 | Pitch / rad/s | 0.27 |
| Yaw / rad/s | 0.25 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 16 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 690000 | Not applicable | - |

**E01 accommodation estimate:** 12 operating crew including commander; 12 reserved intrinsic crew places; 230 equipment-budget units. Authored size tier 4, equivalent-volume proxy 16; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 221 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.039 x 0.987 x 4.784; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C06 The Tithe of Worlds; C08 Wayfarer Exchange

[Full definition](definitions/ships/SH005.json) / [Exact model/material/UV data](definitions/models/SH005.json).

## SH006 - Bison Mk II

![SH006 Bison Mk II - new L337 source geometry](assets/ships/SH006.png)

**Family:** bison. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 1220 | Cargo expansion / t | 490 |
| Speed / native u/s | 17.4 | Acceleration / native u/s2 | 3.9 |
| Energy capacity | 1260 | Energy recharge / s | 6.95 |
| Shield capacity per bank | 640 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.3 | Pitch / rad/s | 0.26 |
| Yaw / rad/s | 0.25 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 16 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 761000 | Not applicable | - |

**E01 accommodation estimate:** 13 operating crew including commander; 13 reserved intrinsic crew places; 252 equipment-budget units. Authored size tier 4, equivalent-volume proxy 16; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 244 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.074 x 0.987 x 4.951; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH006.json) / [Exact model/material/UV data](definitions/models/SH006.json).

## SH007 - Impala Voyager

![SH007 Impala Voyager - new L337 source geometry](assets/ships/SH007.png)

**Family:** impala. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 38 | Cargo expansion / t | 15 |
| Speed / native u/s | 38.6 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.01 | Pitch / rad/s | 0.89 |
| Yaw / rad/s | 0.83 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 16 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 7 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.300 x 11.376 x 41.390; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH007.json) / [Exact model/material/UV data](definitions/models/SH007.json).

## SH008 - Goshawk Explorer

![SH008 Goshawk Explorer - new L337 source geometry](assets/ships/SH008.png)

**Family:** goshawk. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 32 | Cargo expansion / t | 15 |
| Speed / native u/s | 39.5 | Acceleration / native u/s2 | 11.5 |
| Energy capacity | 230 | Energy recharge / s | 4.01 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 211000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 15 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.281 x 0.979 x 3.085; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH008.json) / [Exact model/material/UV data](definitions/models/SH008.json).

## SH009 - Goshawk Mk II

![SH009 Goshawk Mk II - new L337 source geometry](assets/ships/SH009.png)

**Family:** goshawk. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 20 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.5 | Acceleration / native u/s2 | 13.1 |
| Energy capacity | 400 | Energy recharge / s | 6.12 |
| Shield capacity per bank | 330 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.09 | Pitch / rad/s | 0.96 |
| Yaw / rad/s | 0.89 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 281000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.332 x 1.141 x 3.187; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH009.json) / [Exact model/material/UV data](definitions/models/SH009.json).

## SH010 - Goshawk Mk II Custom

![SH010 Goshawk Mk II Custom - new L337 source geometry](assets/ships/SH010.png)

**Family:** goshawk. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 20 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.5 | Acceleration / native u/s2 | 13.1 |
| Energy capacity | 400 | Energy recharge / s | 6.12 |
| Shield capacity per bank | 330 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.09 | Pitch / rad/s | 0.96 |
| Yaw / rad/s | 0.89 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 281000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.383 x 1.141 x 3.289; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH010.json) / [Exact model/material/UV data](definitions/models/SH010.json).

## SH011 - Goshawk Scout

![SH011 Goshawk Scout - new L337 source geometry](assets/ships/SH011.png)

**Family:** goshawk. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.434 x 1.141 x 3.391; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH011.json) / [Exact model/material/UV data](definitions/models/SH011.json).

## SH012 - Sable Liner

![SH012 Sable Liner - new L337 source geometry](assets/ships/SH012.png)

**Family:** sable-liner. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 40.7 | Acceleration / native u/s2 | 12.0 |
| Energy capacity | 220 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.05 | Pitch / rad/s | 0.92 |
| Yaw / rad/s | 0.86 | Fuel / 0.1 LY units | 160 |
| Hull jump reach / LY | 12 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 212000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 33.991 x 16.120 x 53.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH012.json) / [Exact model/material/UV data](definitions/models/SH012.json).

## SH013 - Buffalo

![SH013 Buffalo - new L337 source geometry](assets/ships/SH013.png)

**Family:** buffalo. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 21.9 | Acceleration / native u/s2 | 5.6 |
| Energy capacity | 710 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 470 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.43 | Pitch / rad/s | 0.38 |
| Yaw / rad/s | 0.35 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 424000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.968 x 1.801 x 3.200; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH013.json) / [Exact model/material/UV data](definitions/models/SH013.json).

## SH014 - Buffalo Mk II

![SH014 Buffalo Mk II - new L337 source geometry](assets/ships/SH014.png)

**Family:** buffalo. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 436 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.5 | Acceleration / native u/s2 | 5.5 |
| Energy capacity | 800 | Energy recharge / s | 5.65 |
| Shield capacity per bank | 510 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.41 | Pitch / rad/s | 0.36 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 14 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 465000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 87 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.038 x 1.833 x 3.312; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH014.json) / [Exact model/material/UV data](definitions/models/SH014.json).

## SH015 - Raven

![SH015 Raven - new L337 source geometry](assets/ships/SH015.png)

**Family:** raven. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 46.9 | Acceleration / native u/s2 | 13.8 |
| Energy capacity | 220 | Energy recharge / s | 3.1 |
| Shield capacity per bank | 170 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.39 | Pitch / rad/s | 1.22 |
| Yaw / rad/s | 1.14 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.510 x 0.947 x 2.521; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH015.json) / [Exact model/material/UV data](definitions/models/SH015.json).

## SH016 - Mole Miner

![SH016 Mole Miner - new L337 source geometry](assets/ships/SH016.png)

**Family:** mole. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 108 | Cargo expansion / t | 45 |
| Speed / native u/s | 26.7 | Acceleration / native u/s2 | 8.3 |
| Energy capacity | 340 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.67 | Pitch / rad/s | 0.59 |
| Yaw / rad/s | 0.55 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 242000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 30 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 21 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.916 x 1.242 x 2.748; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH016.json) / [Exact model/material/UV data](definitions/models/SH016.json).

## SH017 - Mole Prospector

![SH017 Mole Prospector - new L337 source geometry](assets/ships/SH017.png)

**Family:** mole. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 108 | Cargo expansion / t | 45 |
| Speed / native u/s | 26.7 | Acceleration / native u/s2 | 8.3 |
| Energy capacity | 340 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.67 | Pitch / rad/s | 0.59 |
| Yaw / rad/s | 0.55 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 242000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 30 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 21 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.951 x 1.242 x 2.818; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH017.json) / [Exact model/material/UV data](definitions/models/SH017.json).

## SH018 - Donkey

![SH018 Donkey - new L337 source geometry](assets/ships/SH018.png)

**Family:** donkey. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.400 x 13.460 x 31.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH018.json) / [Exact model/material/UV data](definitions/models/SH018.json).

## SH019 - Gazelle Explorer

![SH019 Gazelle Explorer - new L337 source geometry](assets/ships/SH019.png)

**Family:** gazelle. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 40.7 | Acceleration / native u/s2 | 12.0 |
| Energy capacity | 220 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.05 | Pitch / rad/s | 0.92 |
| Yaw / rad/s | 0.86 | Fuel / 0.1 LY units | 160 |
| Hull jump reach / LY | 12 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 212000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.600 x 13.800 x 38.290; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH019.json) / [Exact model/material/UV data](definitions/models/SH019.json).

## SH020 - Crow Prototype

![SH020 Crow Prototype - new L337 source geometry](assets/ships/SH020.png)

**Family:** crow. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 49.5 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 210 | Energy recharge / s | 3.1 |
| Shield capacity per bank | 170 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.45 | Pitch / rad/s | 1.28 |
| Yaw / rad/s | 1.19 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.954 x 1.055 x 3.800; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH020.json) / [Exact model/material/UV data](definitions/models/SH020.json).

## SH021 - Zebra

![SH021 Zebra - new L337 source geometry](assets/ships/SH021.png)

**Family:** zebra. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 62 | Cargo expansion / t | 25 |
| Speed / native u/s | 34.4 | Acceleration / native u/s2 | 9.4 |
| Energy capacity | 300 | Energy recharge / s | 3.33 |
| Shield capacity per bank | 260 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.84 | Pitch / rad/s | 0.74 |
| Yaw / rad/s | 0.69 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 226000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.750 x 1.319 x 3.000; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH021.json) / [Exact model/material/UV data](definitions/models/SH021.json).

## SH022 - Peregrine Mk I

![SH022 Peregrine Mk I - new L337 source geometry](assets/ships/SH022.png)

**Family:** peregrine. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 64 | Cargo expansion / t | 25 |
| Speed / native u/s | 37.0 | Acceleration / native u/s2 | 10.0 |
| Energy capacity | 260 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.9 | Pitch / rad/s | 0.79 |
| Yaw / rad/s | 0.74 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 215000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.386 x 1.147 x 2.950; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH022.json) / [Exact model/material/UV data](definitions/models/SH022.json).

## SH023 - Peregrine Mk III

![SH023 Peregrine Mk III - new L337 source geometry](assets/ships/SH023.png)

**Family:** peregrine. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 78 | Cargo expansion / t | 30 |
| Speed / native u/s | 35.7 | Acceleration / native u/s2 | 9.5 |
| Energy capacity | 320 | Energy recharge / s | 3.71 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 1.65 |
| Roll / rad/s | 0.84 | Pitch / rad/s | 0.74 |
| Yaw / rad/s | 0.69 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 13 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 246000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 24 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 15 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.444 x 1.147 x 3.049; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH023.json) / [Exact model/material/UV data](definitions/models/SH023.json).

## SH024 - Peregrine Mk IV

![SH024 Peregrine Mk IV - new L337 source geometry](assets/ships/SH024.png)

**Family:** peregrine. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 84 | Cargo expansion / t | 35 |
| Speed / native u/s | 35.0 | Acceleration / native u/s2 | 9.3 |
| Energy capacity | 350 | Energy recharge / s | 3.97 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 1.72 |
| Roll / rad/s | 0.81 | Pitch / rad/s | 0.71 |
| Yaw / rad/s | 0.66 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 14 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 25 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 16 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.502 x 1.147 x 3.148; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH024.json) / [Exact model/material/UV data](definitions/models/SH024.json).

## SH025 - Peregrine Mk V

![SH025 Peregrine Mk V - new L337 source geometry](assets/ships/SH025.png)

**Family:** peregrine. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 92 | Cargo expansion / t | 35 |
| Speed / native u/s | 34.3 | Acceleration / native u/s2 | 9.1 |
| Energy capacity | 380 | Energy recharge / s | 4.22 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.79 | Pitch / rad/s | 0.7 |
| Yaw / rad/s | 0.65 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 15 |
| Stock missile pylons | 9 | Laser facing mask | 15 |
| Hull price / CR | 274000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 27 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 18 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 9 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.556 x 1.147 x 3.247; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH025.json) / [Exact model/material/UV data](definitions/models/SH025.json).

## SH026 - Harrier

![SH026 Harrier - new L337 source geometry](assets/ships/SH026.png)

**Family:** harrier. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.258 x 1.050 x 4.192; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C01 The Glass Meridian; C04 The Borrowed Voice

[Full definition](definitions/ships/SH026.json) / [Exact model/material/UV data](definitions/models/SH026.json).

## SH027 - Ibex

![SH027 Ibex - new L337 source geometry](assets/ships/SH027.png)

**Family:** ibex. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 15.664 x 16.002 x 34.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH027.json) / [Exact model/material/UV data](definitions/models/SH027.json).

## SH028 - Lion Citadel

![SH028 Lion Citadel - new L337 source geometry](assets/ships/SH028.png)

**Family:** lion-citadel. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 3.400 x 3.024 x 3.104; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH028.json) / [Exact model/material/UV data](definitions/models/SH028.json).

## SH029 - Burro

![SH029 Burro - new L337 source geometry](assets/ships/SH029.png)

**Family:** burro. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 52 | Cargo expansion / t | 20 |
| Speed / native u/s | 39.6 | Acceleration / native u/s2 | 10.6 |
| Energy capacity | 270 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.95 | Pitch / rad/s | 0.84 |
| Yaw / rad/s | 0.78 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 220000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 19 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 10 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.000 x 10.040 x 34.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH029.json) / [Exact model/material/UV data](definitions/models/SH029.json).

## SH030 - Sparrowhawk

![SH030 Sparrowhawk - new L337 source geometry](assets/ships/SH030.png)

**Family:** sparrowhawk. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 49.8 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 300 | Energy recharge / s | 4.84 |
| Shield capacity per bank | 250 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 250000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 8.300 x 25.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH030.json) / [Exact model/material/UV data](definitions/models/SH030.json).

## SH031 - Kite Interceptor

![SH031 Kite Interceptor - new L337 source geometry](assets/ships/SH031.png)

**Family:** kite. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 13.340 x 13.000 x 39.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH031.json) / [Exact model/material/UV data](definitions/models/SH031.json).

## SH032 - Panther Explorer

![SH032 Panther Explorer - new L337 source geometry](assets/ships/SH032.png)

**Family:** panther. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 46.2 | Acceleration / native u/s2 | 12.5 |
| Energy capacity | 190 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 200 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.07 | Pitch / rad/s | 0.94 |
| Yaw / rad/s | 0.88 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 205000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 19.658 x 13.680 x 37.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH032.json) / [Exact model/material/UV data](definitions/models/SH032.json).

## SH033 - Panther Scout

![SH033 Panther Scout - new L337 source geometry](assets/ships/SH033.png)

**Family:** panther. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 49.5 | Acceleration / native u/s2 | 14.6 |
| Energy capacity | 310 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.17 | Pitch / rad/s | 1.03 |
| Yaw / rad/s | 0.96 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 257000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 19.658 x 13.680 x 37.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH033.json) / [Exact model/material/UV data](definitions/models/SH033.json).

## SH034 - Frog Station

![SH034 Frog Station - new L337 source geometry](assets/ships/SH034.png)

**Family:** frog. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 2.880 x 2.580 x 3.449; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH034.json) / [Exact model/material/UV data](definitions/models/SH034.json).

## SH035 - Stag Liner

![SH035 Stag Liner - new L337 source geometry](assets/ships/SH035.png)

**Family:** stag. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 44.9 | Acceleration / native u/s2 | 12.7 |
| Energy capacity | 230 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 217000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 26.496 x 26.500 x 69.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH035.json) / [Exact model/material/UV data](definitions/models/SH035.json).

## SH036 - Zebu

![SH036 Zebu - new L337 source geometry](assets/ships/SH036.png)

**Family:** zebu. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 58 | Cargo expansion / t | 25 |
| Speed / native u/s | 35.9 | Acceleration / native u/s2 | 10.0 |
| Energy capacity | 260 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.9 | Pitch / rad/s | 0.79 |
| Yaw / rad/s | 0.74 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 11 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 217000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 25.600 x 16.656 x 46.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH036.json) / [Exact model/material/UV data](definitions/models/SH036.json).

## SH037 - Vulture Mk I

![SH037 Vulture Mk I - new L337 source geometry](assets/ships/SH037.png)

**Family:** vulture. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 14 | Cargo expansion / t | 5 |
| Speed / native u/s | 58.3 | Acceleration / native u/s2 | 19.1 |
| Energy capacity | 140 | Energy recharge / s | 2.7 |
| Shield capacity per bank | 140 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 2.03 | Pitch / rad/s | 1.79 |
| Yaw / rad/s | 1.66 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 10 |
| Stock missile pylons | 4 | Laser facing mask | 15 |
| Hull price / CR | 213000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 4 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.639 x 1.104 x 3.055; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH037.json) / [Exact model/material/UV data](definitions/models/SH037.json).

## SH038 - Vulture Mk II

![SH038 Vulture Mk II - new L337 source geometry](assets/ships/SH038.png)

**Family:** vulture. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 14 | Cargo expansion / t | 5 |
| Speed / native u/s | 57.2 | Acceleration / native u/s2 | 18.7 |
| Energy capacity | 160 | Energy recharge / s | 2.92 |
| Shield capacity per bank | 150 | Shield recharge per bank / s | 1.68 |
| Roll / rad/s | 1.97 | Pitch / rad/s | 1.73 |
| Yaw / rad/s | 1.62 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 10 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 220000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.948 x 1.229 x 3.055; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH038.json) / [Exact model/material/UV data](definitions/models/SH038.json).

## SH039 - Vulture Mk III

![SH039 Vulture Mk III - new L337 source geometry](assets/ships/SH039.png)

**Family:** vulture. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 56.2 | Acceleration / native u/s2 | 18.2 |
| Energy capacity | 180 | Energy recharge / s | 3.13 |
| Shield capacity per bank | 160 | Shield recharge per bank / s | 1.76 |
| Roll / rad/s | 1.9 | Pitch / rad/s | 1.67 |
| Yaw / rad/s | 1.56 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 11 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 228000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.282 x 1.364 x 3.055; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH039.json) / [Exact model/material/UV data](definitions/models/SH039.json).

## SH040 - Newt Escape Pod

![SH040 Newt Escape Pod - new L337 source geometry](assets/ships/SH040.png)

**Family:** newt-escape-pod. **Role:** capsule. **Player flyable:** yes. **Acquisition rule:** never.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 0 | Cargo expansion / t | 0 |
| Speed / native u/s | 18 | Acceleration / native u/s2 | 3 |
| Energy capacity | 70 | Energy recharge / s | 0.6 |
| Shield capacity per bank | 30 | Shield recharge per bank / s | 0.4 |
| Roll / rad/s | 0.55 | Pitch / rad/s | 0.48 |
| Yaw / rad/s | 0.45 | Fuel / 0.1 LY units | 0 |
| Hull jump reach / LY | 0 | Authored hull spool / s | 0 |
| Stock missile pylons | 0 | Laser facing mask | 0 |
| Hull price / CR | 0 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 8 equipment-budget units. Authored size tier 0, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 0 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings none; 0 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.081 x 1.002 x 1.900; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH040.json) / [Exact model/material/UV data](definitions/models/SH040.json).

## SH041 - Serval Fighter

![SH041 Serval Fighter - new L337 source geometry](assets/ships/SH041.png)

**Family:** serval. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.200 x 8.552 x 29.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH041.json) / [Exact model/material/UV data](definitions/models/SH041.json).

## SH042 - Saker

![SH042 Saker - new L337 source geometry](assets/ships/SH042.png)

**Family:** saker. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 16.136 x 14.512 x 41.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH042.json) / [Exact model/material/UV data](definitions/models/SH042.json).

## SH043 - Eagle Cruiser

![SH043 Eagle Cruiser - new L337 source geometry](assets/ships/SH043.png)

**Family:** eagle. **Role:** military. **Player flyable:** yes. **Acquisition rule:** never.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 172 | Cargo expansion / t | 70 |
| Speed / native u/s | 22.8 | Acceleration / native u/s2 | 5.2 |
| Energy capacity | 1490 | Energy recharge / s | 9.72 |
| Shield capacity per bank | 600 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 18 |
| Stock missile pylons | 10 | Laser facing mask | 15 |
| Hull price / CR | 0 | Not applicable | - |

**E01 accommodation estimate:** 6 operating crew including commander; 6 reserved intrinsic crew places; 43 equipment-budget units. Authored size tier 5, equivalent-volume proxy 64; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 34 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 10 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 58.000 x 33.910 x 112.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH043.json) / [Exact model/material/UV data](definitions/models/SH043.json).

## SH044 - Harpy Assault

![SH044 Harpy Assault - new L337 source geometry](assets/ships/SH044.png)

**Family:** harpy. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 9.212 x 33.290; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH044.json) / [Exact model/material/UV data](definitions/models/SH044.json).

## SH045 - Erne Corvette

![SH045 Erne Corvette - new L337 source geometry](assets/ships/SH045.png)

**Family:** erne. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 41.9 | Acceleration / native u/s2 | 13.2 |
| Energy capacity | 400 | Energy recharge / s | 4.99 |
| Shield capacity per bank | 330 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.07 | Pitch / rad/s | 0.94 |
| Yaw / rad/s | 0.88 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 276000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 26.000 x 20.732 x 63.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH045.json) / [Exact model/material/UV data](definitions/models/SH045.json).

## SH046 - Harpy Dropship

![SH046 Harpy Dropship - new L337 source geometry](assets/ships/SH046.png)

**Family:** harpy. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 12.612 x 33.290; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH046.json) / [Exact model/material/UV data](definitions/models/SH046.json).

## SH047 - Harpy Gunship

![SH047 Harpy Gunship - new L337 source geometry](assets/ships/SH047.png)

**Family:** harpy. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 10.112 x 33.290; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH047.json) / [Exact model/material/UV data](definitions/models/SH047.json).

## SH048 - Lanner

![SH048 Lanner - new L337 source geometry](assets/ships/SH048.png)

**Family:** lanner. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 12 | Cargo expansion / t | 5 |
| Speed / native u/s | 65.3 | Acceleration / native u/s2 | 19.3 |
| Energy capacity | 190 | Energy recharge / s | 3.57 |
| Shield capacity per bank | 190 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.68 | Pitch / rad/s | 1.48 |
| Yaw / rad/s | 1.38 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 10 |
| Stock missile pylons | 4 | Laser facing mask | 15 |
| Hull price / CR | 246000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 4 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.140 x 1.038 x 3.587; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH048.json) / [Exact model/material/UV data](definitions/models/SH048.json).

## SH049 - Hyena

![SH049 Hyena - new L337 source geometry](assets/ships/SH049.png)

**Family:** hyena. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 24 | Cargo expansion / t | 10 |
| Speed / native u/s | 51.0 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 210 | Energy recharge / s | 3.1 |
| Shield capacity per bank | 170 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.45 | Pitch / rad/s | 1.28 |
| Yaw / rad/s | 1.19 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 214000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.386 x 1.109 x 2.606; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C04 The Borrowed Voice; C07 The Still Current

[Full definition](definitions/ships/SH049.json) / [Exact model/material/UV data](definitions/models/SH049.json).

## SH050 - Yak

![SH050 Yak - new L337 source geometry](assets/ships/SH050.png)

**Family:** yak. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 58 | Cargo expansion / t | 25 |
| Speed / native u/s | 35.9 | Acceleration / native u/s2 | 10.0 |
| Energy capacity | 260 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.9 | Pitch / rad/s | 0.79 |
| Yaw / rad/s | 0.74 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 11 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 217000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.887 x 1.606 x 4.100; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH050.json) / [Exact model/material/UV data](definitions/models/SH050.json).

## SH051 - Jackal

![SH051 Jackal - new L337 source geometry](assets/ships/SH051.png)

**Family:** jackal. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 24 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.9 | Acceleration / native u/s2 | 14.4 |
| Energy capacity | 220 | Energy recharge / s | 3.66 |
| Shield capacity per bank | 180 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.42 | Pitch / rad/s | 1.25 |
| Yaw / rad/s | 1.16 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 212000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.342 x 0.758 x 2.877; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH051.json) / [Exact model/material/UV data](definitions/models/SH051.json).

## SH052 - Percheron

![SH052 Percheron - new L337 source geometry](assets/ships/SH052.png)

**Family:** percheron. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 58 | Cargo expansion / t | 25 |
| Speed / native u/s | 40.7 | Acceleration / native u/s2 | 10.4 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 210 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.92 | Pitch / rad/s | 0.81 |
| Yaw / rad/s | 0.75 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.678 x 0.836 x 3.322; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH052.json) / [Exact model/material/UV data](definitions/models/SH052.json).

## SH053 - Percheron Prototype

![SH053 Percheron Prototype - new L337 source geometry](assets/ships/SH053.png)

**Family:** percheron. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 49.5 | Acceleration / native u/s2 | 14.6 |
| Energy capacity | 310 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.17 | Pitch / rad/s | 1.03 |
| Yaw / rad/s | 0.96 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 257000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.734 x 1.004 x 3.434; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH053.json) / [Exact model/material/UV data](definitions/models/SH053.json).

## SH054 - Hobby Fighter

![SH054 Hobby Fighter - new L337 source geometry](assets/ships/SH054.png)

**Family:** hobby. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 16.000 x 9.664 x 24.690; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH054.json) / [Exact model/material/UV data](definitions/models/SH054.json).

## SH055 - Condor

![SH055 Condor - new L337 source geometry](assets/ships/SH055.png)

**Family:** condor. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 46.9 | Acceleration / native u/s2 | 13.8 |
| Energy capacity | 220 | Energy recharge / s | 3.1 |
| Shield capacity per bank | 170 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.39 | Pitch / rad/s | 1.22 |
| Yaw / rad/s | 1.14 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 31.808 x 10.700 x 31.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH055.json) / [Exact model/material/UV data](definitions/models/SH055.json).

## SH056 - Aplomado Interceptor

![SH056 Aplomado Interceptor - new L337 source geometry](assets/ships/SH056.png)

**Family:** aplomado. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 17.000 x 7.624 x 47.190; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH056.json) / [Exact model/material/UV data](definitions/models/SH056.json).

## SH057 - Falconet

![SH057 Falconet - new L337 source geometry](assets/ships/SH057.png)

**Family:** falconet. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 16.600 x 7.234 x 19.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH057.json) / [Exact model/material/UV data](definitions/models/SH057.json).

## SH058 - Brabant

![SH058 Brabant - new L337 source geometry](assets/ships/SH058.png)

**Family:** brabant. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 418 | Cargo expansion / t | 165 |
| Speed / native u/s | 21.0 | Acceleration / native u/s2 | 5.3 |
| Energy capacity | 820 | Energy recharge / s | 5.44 |
| Shield capacity per bank | 540 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.4 | Pitch / rad/s | 0.35 |
| Yaw / rad/s | 0.33 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 463000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 92 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 83 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 33.000 x 20.224 x 49.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH058.json) / [Exact model/material/UV data](definitions/models/SH058.json).

## SH059 - Barbary

![SH059 Barbary - new L337 source geometry](assets/ships/SH059.png)

**Family:** barbary. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.4 | Acceleration / native u/s2 | 12.9 |
| Energy capacity | 360 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.600 x 8.610 x 26.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH059.json) / [Exact model/material/UV data](definitions/models/SH059.json).

## SH060 - Wombat

![SH060 Wombat - new L337 source geometry](assets/ships/SH060.png)

**Family:** wombat. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 72 | Cargo expansion / t | 30 |
| Speed / native u/s | 31.0 | Acceleration / native u/s2 | 9.5 |
| Energy capacity | 340 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.73 | Pitch / rad/s | 0.64 |
| Yaw / rad/s | 0.6 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 235000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 23 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 14 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.462 x 1.242 x 2.422; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH060.json) / [Exact model/material/UV data](definitions/models/SH060.json).

## SH061 - Haflinger

![SH061 Haflinger - new L337 source geometry](assets/ships/SH061.png)

**Family:** haflinger. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 78 | Cargo expansion / t | 30 |
| Speed / native u/s | 34.0 | Acceleration / native u/s2 | 9.2 |
| Energy capacity | 270 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.86 | Pitch / rad/s | 0.76 |
| Yaw / rad/s | 0.71 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 24 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 15 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.077 x 1.785 x 4.000; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C05 The Shattered Wake; C07 The Still Current; C08 Wayfarer Exchange; C09 The Quiet Nursery; C10 Borrowed Dawn; C11 The Open Shadow; C12 Harbour Without Orders; C13 False Colours; C14 The Rubble Covenant; C15 A Garden in Transit; C16 The Warrant Ledger; C17 The Measure of Care; C18 The Long Return; C19 The Unfinished Map; C20 The Blue Reservoir; C21 Mutual Shelter; C22 The Listening Frontier; C23 An Assembly of Orbits; C24 Under Tow; C25 The Memory Atlas; C26 A Fleet of Neighbours; C27 Uncounted Names; C28 The Honest Circuit; C29 Small Lights; C30 The Passenger's Horizon; C31 The Kind Distance; C32 Cold Reserve; C33 The Magnetic Orchard; C34 Open Measure; C35 The Shared Pulse; C36 The Witness Window; C37 Public Record; C38 Signed Passage; C39 The Guiding Light

[Full definition](definitions/ships/SH061.json) / [Exact model/material/UV data](definitions/models/SH061.json).

## SH062 - Moose Clipper

![SH062 Moose Clipper - new L337 source geometry](assets/ships/SH062.png)

**Family:** moose. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 24.9 | Acceleration / native u/s2 | 5.8 |
| Energy capacity | 630 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 440 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.44 | Pitch / rad/s | 0.39 |
| Yaw / rad/s | 0.36 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 397000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 31.000 x 23.410 x 70.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH062.json) / [Exact model/material/UV data](definitions/models/SH062.json).

## SH063 - Seriema Courier

![SH063 Seriema Courier - new L337 source geometry](assets/ships/SH063.png)

**Family:** seriema. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.367 x 1.276 x 4.400; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH063.json) / [Exact model/material/UV data](definitions/models/SH063.json).

## SH064 - Arna Cutter

![SH064 Arna Cutter - new L337 source geometry](assets/ships/SH064.png)

**Family:** arna. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 24.9 | Acceleration / native u/s2 | 5.8 |
| Energy capacity | 630 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 440 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.44 | Pitch / rad/s | 0.39 |
| Yaw / rad/s | 0.36 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 397000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 32.000 x 18.980 x 56.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH064.json) / [Exact model/material/UV data](definitions/models/SH064.json).

## SH065 - Vulture Raider

![SH065 Vulture Raider - new L337 source geometry](assets/ships/SH065.png)

**Family:** vulture. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 14 | Cargo expansion / t | 5 |
| Speed / native u/s | 58.3 | Acceleration / native u/s2 | 19.1 |
| Energy capacity | 140 | Energy recharge / s | 2.7 |
| Shield capacity per bank | 140 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 2.03 | Pitch / rad/s | 1.79 |
| Yaw / rad/s | 1.66 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 10 |
| Stock missile pylons | 4 | Laser facing mask | 15 |
| Hull price / CR | 213000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 4 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 31.104 x 13.940 x 36.690; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH065.json) / [Exact model/material/UV data](definitions/models/SH065.json).

## SH066 - Rabbit Explorer

![SH066 Rabbit Explorer - new L337 source geometry](assets/ships/SH066.png)

**Family:** rabbit. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 46.2 | Acceleration / native u/s2 | 12.5 |
| Energy capacity | 190 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 200 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.07 | Pitch / rad/s | 0.94 |
| Yaw / rad/s | 0.88 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 205000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.140 x 0.788 x 2.548; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH066.json) / [Exact model/material/UV data](definitions/models/SH066.json).

## SH067 - Rhinoceros Trader

![SH067 Rhinoceros Trader - new L337 source geometry](assets/ships/SH067.png)

**Family:** rhinoceros. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 52 | Cargo expansion / t | 20 |
| Speed / native u/s | 39.6 | Acceleration / native u/s2 | 10.6 |
| Energy capacity | 270 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.95 | Pitch / rad/s | 0.84 |
| Yaw / rad/s | 0.78 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 220000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 19 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 10 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.510 x 1.139 x 3.263; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH067.json) / [Exact model/material/UV data](definitions/models/SH067.json).

## SH068 - Badger

![SH068 Badger - new L337 source geometry](assets/ships/SH068.png)

**Family:** badger. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 108 | Cargo expansion / t | 45 |
| Speed / native u/s | 26.7 | Acceleration / native u/s2 | 8.3 |
| Energy capacity | 340 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.67 | Pitch / rad/s | 0.59 |
| Yaw / rad/s | 0.55 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 242000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 30 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 21 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 10.308 x 39.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH068.json) / [Exact model/material/UV data](definitions/models/SH068.json).

## SH069 - Baza Fighter

![SH069 Baza Fighter - new L337 source geometry](assets/ships/SH069.png)

**Family:** baza. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.720 x 12.330 x 28.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH069.json) / [Exact model/material/UV data](definitions/models/SH069.json).

## SH070 - Baza Mk II

![SH070 Baza Mk II - new L337 source geometry](assets/ships/SH070.png)

**Family:** baza. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 20 | Cargo expansion / t | 10 |
| Speed / native u/s | 53.1 | Acceleration / native u/s2 | 17.2 |
| Energy capacity | 290 | Energy recharge / s | 4.43 |
| Shield capacity per bank | 250 | Shield recharge per bank / s | 1.99 |
| Roll / rad/s | 1.5 | Pitch / rad/s | 1.32 |
| Yaw / rad/s | 1.23 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.720 x 12.330 x 31.770; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH070.json) / [Exact model/material/UV data](definitions/models/SH070.json).

## SH071 - Griffon

![SH071 Griffon - new L337 source geometry](assets/ships/SH071.png)

**Family:** griffon. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.4 | Acceleration / native u/s2 | 14.1 |
| Energy capacity | 240 | Energy recharge / s | 3.22 |
| Shield capacity per bank | 190 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.35 | Pitch / rad/s | 1.19 |
| Yaw / rad/s | 1.11 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.502 x 0.936 x 3.111; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH071.json) / [Exact model/material/UV data](definitions/models/SH071.json).

## SH072 - Griffon Mk II

![SH072 Griffon Mk II - new L337 source geometry](assets/ships/SH072.png)

**Family:** griffon. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 46.6 | Acceleration / native u/s2 | 13.8 |
| Energy capacity | 270 | Energy recharge / s | 3.48 |
| Shield capacity per bank | 210 | Shield recharge per bank / s | 1.68 |
| Roll / rad/s | 1.3 | Pitch / rad/s | 1.14 |
| Yaw / rad/s | 1.07 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 230000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.555 x 0.936 x 3.215; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH072.json) / [Exact model/material/UV data](definitions/models/SH072.json).

## SH073 - Griffon Spectre

![SH073 Griffon Spectre - new L337 source geometry](assets/ships/SH073.png)

**Family:** griffon. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.4 | Acceleration / native u/s2 | 14.1 |
| Energy capacity | 240 | Energy recharge / s | 3.22 |
| Shield capacity per bank | 190 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.35 | Pitch / rad/s | 1.19 |
| Yaw / rad/s | 1.11 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.609 x 0.936 x 3.320; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH073.json) / [Exact model/material/UV data](definitions/models/SH073.json).

## SH074 - Dzo

![SH074 Dzo - new L337 source geometry](assets/ships/SH074.png)

**Family:** dzo. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 21.9 | Acceleration / native u/s2 | 5.6 |
| Energy capacity | 710 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 470 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.43 | Pitch / rad/s | 0.38 |
| Yaw / rad/s | 0.35 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 424000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 25.400 x 21.260 x 47.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH074.json) / [Exact model/material/UV data](definitions/models/SH074.json).

## SH075 - Dzo Mk II

![SH075 Dzo Mk II - new L337 source geometry](assets/ships/SH075.png)

**Family:** dzo. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 436 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.5 | Acceleration / native u/s2 | 5.5 |
| Energy capacity | 800 | Energy recharge / s | 5.65 |
| Shield capacity per bank | 510 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.41 | Pitch / rad/s | 0.36 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 14 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 465000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 87 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 28.280 x 22.064 x 52.610; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH075.json) / [Exact model/material/UV data](definitions/models/SH075.json).

## SH076 - Hog

![SH076 Hog - new L337 source geometry](assets/ships/SH076.png)

**Family:** hog. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 418 | Cargo expansion / t | 165 |
| Speed / native u/s | 21.0 | Acceleration / native u/s2 | 5.3 |
| Energy capacity | 820 | Energy recharge / s | 5.44 |
| Shield capacity per bank | 540 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.4 | Pitch / rad/s | 0.35 |
| Yaw / rad/s | 0.33 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 463000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 92 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 83 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.849 x 1.723 x 2.694; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH076.json) / [Exact model/material/UV data](definitions/models/SH076.json).

## SH077 - Tamaraw

![SH077 Tamaraw - new L337 source geometry](assets/ships/SH077.png)

**Family:** tamaraw. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 21.9 | Acceleration / native u/s2 | 5.6 |
| Energy capacity | 710 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 470 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.43 | Pitch / rad/s | 0.38 |
| Yaw / rad/s | 0.35 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 424000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.192 x 19.590 x 39.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH077.json) / [Exact model/material/UV data](definitions/models/SH077.json).

## SH078 - Oryx Voyager

![SH078 Oryx Voyager - new L337 source geometry](assets/ships/SH078.png)

**Family:** oryx-voyager. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 32 | Cargo expansion / t | 15 |
| Speed / native u/s | 39.5 | Acceleration / native u/s2 | 11.5 |
| Energy capacity | 230 | Energy recharge / s | 4.01 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 211000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 15 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.600 x 10.024 x 53.600; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH078.json) / [Exact model/material/UV data](definitions/models/SH078.json).

## SH079 - Carabao Carrier

![SH079 Carabao Carrier - new L337 source geometry](assets/ships/SH079.png)

**Family:** carabao. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 786 | Cargo expansion / t | 315 |
| Speed / native u/s | 19.6 | Acceleration / native u/s2 | 4.8 |
| Energy capacity | 970 | Energy recharge / s | 6.44 |
| Shield capacity per bank | 550 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.37 | Pitch / rad/s | 0.33 |
| Yaw / rad/s | 0.3 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 16 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 580000 | Not applicable | - |

**E01 accommodation estimate:** 9 operating crew including commander; 9 reserved intrinsic crew places; 166 equipment-budget units. Authored size tier 4, equivalent-volume proxy 16; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 157 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 36.000 x 23.200 x 77.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH079.json) / [Exact model/material/UV data](definitions/models/SH079.json).

## SH080 - Carabao Highliner

![SH080 Carabao Highliner - new L337 source geometry](assets/ships/SH080.png)

**Family:** carabao. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 786 | Cargo expansion / t | 315 |
| Speed / native u/s | 19.6 | Acceleration / native u/s2 | 4.8 |
| Energy capacity | 970 | Energy recharge / s | 6.44 |
| Shield capacity per bank | 550 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.37 | Pitch / rad/s | 0.33 |
| Yaw / rad/s | 0.3 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 16 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 580000 | Not applicable | - |

**E01 accommodation estimate:** 9 operating crew including commander; 9 reserved intrinsic crew places; 166 equipment-budget units. Authored size tier 4, equivalent-volume proxy 16; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 157 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 36.000 x 23.200 x 77.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH080.json) / [Exact model/material/UV data](definitions/models/SH080.json).

## SH081 - Jaguar

![SH081 Jaguar - new L337 source geometry](assets/ships/SH081.png)

**Family:** jaguar. **Role:** military. **Player flyable:** yes. **Acquisition rule:** never.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 144 | Cargo expansion / t | 60 |
| Speed / native u/s | 23.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 1480 | Energy recharge / s | 11.47 |
| Shield capacity per bank | 620 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 0.43 | Pitch / rad/s | 0.38 |
| Yaw / rad/s | 0.35 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 7 | Authored hull spool / s | 18 |
| Stock missile pylons | 10 | Laser facing mask | 15 |
| Hull price / CR | 0 | Not applicable | - |

**E01 accommodation estimate:** 6 operating crew including commander; 6 reserved intrinsic crew places; 37 equipment-budget units. Authored size tier 5, equivalent-volume proxy 64; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 28 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 10 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 50.000 x 30.510 x 94.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH081.json) / [Exact model/material/UV data](definitions/models/SH081.json).

## SH082 - Cheetah

![SH082 Cheetah - new L337 source geometry](assets/ships/SH082.png)

**Family:** cheetah. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 14 | Cargo expansion / t | 5 |
| Speed / native u/s | 55.2 | Acceleration / native u/s2 | 17.4 |
| Energy capacity | 250 | Energy recharge / s | 3.72 |
| Shield capacity per bank | 240 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.53 | Pitch / rad/s | 1.35 |
| Yaw / rad/s | 1.25 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 10 |
| Stock missile pylons | 4 | Laser facing mask | 15 |
| Hull price / CR | 246000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 4 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.048 x 0.926 x 4.324; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH082.json) / [Exact model/material/UV data](definitions/models/SH082.json).

## SH083 - Hare Explorer

![SH083 Hare Explorer - new L337 source geometry](assets/ships/SH083.png)

**Family:** hare. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 32 | Cargo expansion / t | 15 |
| Speed / native u/s | 39.5 | Acceleration / native u/s2 | 11.5 |
| Energy capacity | 230 | Energy recharge / s | 4.01 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 211000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 15 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 18.500 x 9.350 x 37.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH083.json) / [Exact model/material/UV data](definitions/models/SH083.json).

## SH084 - Llama

![SH084 Llama - new L337 source geometry](assets/ships/SH084.png)

**Family:** llama. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 21.600 x 18.660 x 43.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH084.json) / [Exact model/material/UV data](definitions/models/SH084.json).

## SH085 - Laggar

![SH085 Laggar - new L337 source geometry](assets/ships/SH085.png)

**Family:** laggar. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 54.1 | Acceleration / native u/s2 | 17.6 |
| Energy capacity | 260 | Energy recharge / s | 4.1 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.55 | Pitch / rad/s | 1.36 |
| Yaw / rad/s | 1.27 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 249000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 27.000 x 8.860 x 38.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH085.json) / [Exact model/material/UV data](definitions/models/SH085.json).

## SH086 - Alpaca

![SH086 Alpaca - new L337 source geometry](assets/ships/SH086.png)

**Family:** alpaca. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 62 | Cargo expansion / t | 25 |
| Speed / native u/s | 34.4 | Acceleration / native u/s2 | 9.4 |
| Energy capacity | 300 | Energy recharge / s | 3.33 |
| Shield capacity per bank | 260 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.84 | Pitch / rad/s | 0.74 |
| Yaw / rad/s | 0.69 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 226000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.600 x 0.788 x 2.940; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH086.json) / [Exact model/material/UV data](definitions/models/SH086.json).

## SH087 - Elk

![SH087 Elk - new L337 source geometry](assets/ships/SH087.png)

**Family:** elk. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 62 | Cargo expansion / t | 25 |
| Speed / native u/s | 34.4 | Acceleration / native u/s2 | 9.4 |
| Energy capacity | 300 | Energy recharge / s | 3.33 |
| Shield capacity per bank | 260 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.84 | Pitch / rad/s | 0.74 |
| Yaw / rad/s | 0.69 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 226000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.978 x 1.714 x 3.462; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH087.json) / [Exact model/material/UV data](definitions/models/SH087.json).

## SH088 - Springbok Starliner

![SH088 Springbok Starliner - new L337 source geometry](assets/ships/SH088.png)

**Family:** springbok. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 38 | Cargo expansion / t | 15 |
| Speed / native u/s | 38.6 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.01 | Pitch / rad/s | 0.89 |
| Yaw / rad/s | 0.83 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 16 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 7 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.508 x 0.788 x 4.107; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH088.json) / [Exact model/material/UV data](definitions/models/SH088.json).

## SH089 - Antelope

![SH089 Antelope - new L337 source geometry](assets/ships/SH089.png)

**Family:** antelope. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.232 x 0.788 x 3.068; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH089.json) / [Exact model/material/UV data](definitions/models/SH089.json).

## SH090 - Elephant

![SH090 Elephant - new L337 source geometry](assets/ships/SH090.png)

**Family:** elephant. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 52 | Cargo expansion / t | 20 |
| Speed / native u/s | 39.6 | Acceleration / native u/s2 | 10.6 |
| Energy capacity | 270 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.95 | Pitch / rad/s | 0.84 |
| Yaw / rad/s | 0.78 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 220000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 19 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 10 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.800 x 1.447 x 3.548; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH090.json) / [Exact model/material/UV data](definitions/models/SH090.json).

## SH091 - Gopher

![SH091 Gopher - new L337 source geometry](assets/ships/SH091.png)

**Family:** gopher. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 108 | Cargo expansion / t | 45 |
| Speed / native u/s | 26.7 | Acceleration / native u/s2 | 8.3 |
| Energy capacity | 340 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.67 | Pitch / rad/s | 0.59 |
| Yaw / rad/s | 0.55 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 242000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 30 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 21 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 19.800 x 15.800 x 33.390; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH091.json) / [Exact model/material/UV data](definitions/models/SH091.json).

## SH092 - Aubrac

![SH092 Aubrac - new L337 source geometry](assets/ships/SH092.png)

**Family:** aubrac. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.940 x 1.444 x 4.221; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH092.json) / [Exact model/material/UV data](definitions/models/SH092.json).

## SH093 - Giraffe Liner

![SH093 Giraffe Liner - new L337 source geometry](assets/ships/SH093.png)

**Family:** giraffe. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 30 | Cargo expansion / t | 10 |
| Speed / native u/s | 39.1 | Acceleration / native u/s2 | 11.3 |
| Energy capacity | 250 | Energy recharge / s | 3.54 |
| Shield capacity per bank | 250 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.98 | Pitch / rad/s | 0.86 |
| Yaw / rad/s | 0.8 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 218000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.496 x 24.480 x 59.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH093.json) / [Exact model/material/UV data](definitions/models/SH093.json).

## SH094 - Ictinia

![SH094 Ictinia - new L337 source geometry](assets/ships/SH094.png)

**Family:** ictinia. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.520 x 1.289 x 3.144; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH094.json) / [Exact model/material/UV data](definitions/models/SH094.json).

## SH095 - Ictinia X

![SH095 Ictinia X - new L337 source geometry](assets/ships/SH095.png)

**Family:** ictinia. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.573 x 1.289 x 3.250; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH095.json) / [Exact model/material/UV data](definitions/models/SH095.json).

## SH096 - Wisent

![SH096 Wisent - new L337 source geometry](assets/ships/SH096.png)

**Family:** wisent. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 188 | Cargo expansion / t | 75 |
| Speed / native u/s | 26.5 | Acceleration / native u/s2 | 7.7 |
| Energy capacity | 410 | Energy recharge / s | 4.2 |
| Shield capacity per bank | 360 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.63 | Pitch / rad/s | 0.55 |
| Yaw / rad/s | 0.52 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 286000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 46 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 37 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.248 x 1.535 x 4.500; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH096.json) / [Exact model/material/UV data](definitions/models/SH096.json).

## SH097 - Wisent Mk II

![SH097 Wisent Mk II - new L337 source geometry](assets/ships/SH097.png)

**Family:** wisent. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 206 | Cargo expansion / t | 80 |
| Speed / native u/s | 26.0 | Acceleration / native u/s2 | 7.5 |
| Energy capacity | 460 | Energy recharge / s | 4.54 |
| Shield capacity per bank | 390 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.61 | Pitch / rad/s | 0.54 |
| Yaw / rad/s | 0.5 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 311000 | Not applicable | - |

**E01 accommodation estimate:** 3 operating crew including commander; 3 reserved intrinsic crew places; 50 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 41 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.329 x 1.548 x 4.657; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH097.json) / [Exact model/material/UV data](definitions/models/SH097.json).

## SH098 - Anoa

![SH098 Anoa - new L337 source geometry](assets/ships/SH098.png)

**Family:** anoa. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 396 | Cargo expansion / t | 160 |
| Speed / native u/s | 24.9 | Acceleration / native u/s2 | 5.8 |
| Energy capacity | 630 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 440 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.44 | Pitch / rad/s | 0.39 |
| Yaw / rad/s | 0.36 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 397000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 88 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 79 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.488 x 2.484 x 3.600; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH098.json) / [Exact model/material/UV data](definitions/models/SH098.json).

## SH099 - Ox

![SH099 Ox - new L337 source geometry](assets/ships/SH099.png)

**Family:** ox. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 22.6 | Acceleration / native u/s2 | 5.6 |
| Energy capacity | 710 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 470 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.43 | Pitch / rad/s | 0.38 |
| Yaw / rad/s | 0.35 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 429000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.510 x 1.435 x 3.988; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH099.json) / [Exact model/material/UV data](definitions/models/SH099.json).

## SH100 - Ox Mk II

![SH100 Ox Mk II - new L337 source geometry](assets/ships/SH100.png)

**Family:** ox. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 484 | Cargo expansion / t | 195 |
| Speed / native u/s | 22.2 | Acceleration / native u/s2 | 5.5 |
| Energy capacity | 800 | Energy recharge / s | 5.65 |
| Shield capacity per bank | 510 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.41 | Pitch / rad/s | 0.36 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 472000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 105 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 96 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.558 x 1.435 x 4.123; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH100.json) / [Exact model/material/UV data](definitions/models/SH100.json).

## SH101 - Dorcas Racer

![SH101 Dorcas Racer - new L337 source geometry](assets/ships/SH101.png)

**Family:** dorcas-racer. **Role:** leisure. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 44.9 | Acceleration / native u/s2 | 12.7 |
| Energy capacity | 230 | Energy recharge / s | 3.4 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 217000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 10.832 x 5.616 x 40.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH101.json) / [Exact model/material/UV data](definitions/models/SH101.json).

## SH102 - Dhole Haven

![SH102 Dhole Haven - new L337 source geometry](assets/ships/SH102.png)

**Family:** dhole. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 3.072 x 2.067 x 3.488; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH102.json) / [Exact model/material/UV data](definitions/models/SH102.json).

## SH103 - Redtail Mk III

![SH103 Redtail Mk III - new L337 source geometry](assets/ships/SH103.png)

**Family:** redtail. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 54.7 | Acceleration / native u/s2 | 16.2 |
| Energy capacity | 370 | Energy recharge / s | 4.76 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 2.09 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 13 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 287000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.000 x 13.936 x 37.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH103.json) / [Exact model/material/UV data](definitions/models/SH103.json).

## SH104 - Wildebeest

![SH104 Wildebeest - new L337 source geometry](assets/ships/SH104.png)

**Family:** wildebeest. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 62 | Cargo expansion / t | 25 |
| Speed / native u/s | 34.4 | Acceleration / native u/s2 | 9.4 |
| Energy capacity | 300 | Energy recharge / s | 3.33 |
| Shield capacity per bank | 260 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.84 | Pitch / rad/s | 0.74 |
| Yaw / rad/s | 0.69 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 226000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 21 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 12 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.700 x 1.209 x 2.668; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH104.json) / [Exact model/material/UV data](definitions/models/SH104.json).

## SH105 - Tapir Shuttle

![SH105 Tapir Shuttle - new L337 source geometry](assets/ships/SH105.png)

**Family:** tapir. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 730 | Energy recharge / s | 6.17 |
| Shield capacity per bank | 500 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 440000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.008 x 2.080 x 2.440; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH105.json) / [Exact model/material/UV data](definitions/models/SH105.json).

## SH106 - Tapir Mk II

![SH106 Tapir Mk II - new L337 source geometry](assets/ships/SH106.png)

**Family:** tapir. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 484 | Cargo expansion / t | 195 |
| Speed / native u/s | 20.9 | Acceleration / native u/s2 | 5.2 |
| Energy capacity | 820 | Energy recharge / s | 6.66 |
| Shield capacity per bank | 540 | Shield recharge per bank / s | 1.78 |
| Roll / rad/s | 0.41 | Pitch / rad/s | 0.36 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 482000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 105 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 96 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.051 x 2.080 x 2.521; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH106.json) / [Exact model/material/UV data](definitions/models/SH106.json).

## SH107 - Magpie

![SH107 Magpie - new L337 source geometry](assets/ships/SH107.png)

**Family:** magpie. **Role:** pirate. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 49.5 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 210 | Energy recharge / s | 3.1 |
| Shield capacity per bank | 170 | Shield recharge per bank / s | 1.6 |
| Roll / rad/s | 1.45 | Pitch / rad/s | 1.28 |
| Yaw / rad/s | 1.19 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 216000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.174 x 0.967 x 2.432; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH107.json) / [Exact model/material/UV data](definitions/models/SH107.json).

## SH108 - Besra

![SH108 Besra - new L337 source geometry](assets/ships/SH108.png)

**Family:** besra. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 20 | Cargo expansion / t | 10 |
| Speed / native u/s | 49.3 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 330 | Energy recharge / s | 4.26 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.26 | Pitch / rad/s | 1.11 |
| Yaw / rad/s | 1.03 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 258000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.248 x 10.724 x 36.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH108.json) / [Exact model/material/UV data](definitions/models/SH108.json).

## SH109 - Hippo

![SH109 Hippo - new L337 source geometry](assets/ships/SH109.png)

**Family:** hippo. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 58 | Cargo expansion / t | 25 |
| Speed / native u/s | 40.7 | Acceleration / native u/s2 | 10.4 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 210 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.92 | Pitch / rad/s | 0.81 |
| Yaw / rad/s | 0.75 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 14.704 x 32.290; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH109.json) / [Exact model/material/UV data](definitions/models/SH109.json).

## SH110 - Leopard Fighter

![SH110 Leopard Fighter - new L337 source geometry](assets/ships/SH110.png)

**Family:** leopard. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 18.200 x 10.474 x 32.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH110.json) / [Exact model/material/UV data](definitions/models/SH110.json).

## SH111 - Puma

![SH111 Puma - new L337 source geometry](assets/ships/SH111.png)

**Family:** puma. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 49.5 | Acceleration / native u/s2 | 14.6 |
| Energy capacity | 310 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.17 | Pitch / rad/s | 1.03 |
| Yaw / rad/s | 0.96 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 257000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.484 x 11.678 x 38.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH111.json) / [Exact model/material/UV data](definitions/models/SH111.json).

## SH112 - Larvaal Warden

![SH112 Larvaal Warden - new L337 source geometry](assets/ships/SH112.png)

**Family:** larvaal-warden. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.0 | Acceleration / native u/s2 | 17.0 |
| Energy capacity | 390 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.3 | Pitch / rad/s | 1.14 |
| Yaw / rad/s | 1.07 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 280000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 39.000 x 29.000 x 27.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH112.json) / [Exact model/material/UV data](definitions/models/SH112.json).

## SH113 - Larvaal Ravager

![SH113 Larvaal Ravager - new L337 source geometry](assets/ships/SH113.png)

**Family:** larvaal-ravager. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.0 | Acceleration / native u/s2 | 17.0 |
| Energy capacity | 390 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.3 | Pitch / rad/s | 1.14 |
| Yaw / rad/s | 1.07 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 280000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 34.266 x 11.500 x 48.200; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH113.json) / [Exact model/material/UV data](definitions/models/SH113.json).

## SH114 - Larvaal Sentinel

![SH114 Larvaal Sentinel - new L337 source geometry](assets/ships/SH114.png)

**Family:** larvaal-sentinel. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 24 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.9 | Acceleration / native u/s2 | 18.7 |
| Energy capacity | 350 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.49 | Pitch / rad/s | 1.31 |
| Yaw / rad/s | 1.22 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 271000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 14.000 x 43.000 x 35.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH114.json) / [Exact model/material/UV data](definitions/models/SH114.json).

## SH115 - Larvaal Lancer

![SH115 Larvaal Lancer - new L337 source geometry](assets/ships/SH115.png)

**Family:** larvaal-lancer. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 24 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.9 | Acceleration / native u/s2 | 18.7 |
| Energy capacity | 350 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.49 | Pitch / rad/s | 1.31 |
| Yaw / rad/s | 1.22 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 271000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.739 x 9.600 x 52.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH115.json) / [Exact model/material/UV data](definitions/models/SH115.json).

## SH116 - Larvaal Broodlord

![SH116 Larvaal Broodlord - new L337 source geometry](assets/ships/SH116.png)

**Family:** larvaal-broodlord. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 34 | Cargo expansion / t | 15 |
| Speed / native u/s | 43.2 | Acceleration / native u/s2 | 15.6 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 320 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.25 | Pitch / rad/s | 1.1 |
| Yaw / rad/s | 1.02 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 281000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 15 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.407 x 21.000 x 42.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH116.json) / [Exact model/material/UV data](definitions/models/SH116.json).

## SH117 - Larvaal Provoker

![SH117 Larvaal Provoker - new L337 source geometry](assets/ships/SH117.png)

**Family:** larvaal-provoker. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 50.3 | Acceleration / native u/s2 | 18.0 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.37 | Pitch / rad/s | 1.21 |
| Yaw / rad/s | 1.12 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 288000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.020 x 9.800 x 38.200; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH117.json) / [Exact model/material/UV data](definitions/models/SH117.json).

## SH118 - Larvaal Reaver

![SH118 Larvaal Reaver - new L337 source geometry](assets/ships/SH118.png)

**Family:** larvaal-reaver. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 50.3 | Acceleration / native u/s2 | 18.0 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.37 | Pitch / rad/s | 1.21 |
| Yaw / rad/s | 1.12 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 288000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 18.400 x 12.800 x 39.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH118.json) / [Exact model/material/UV data](definitions/models/SH118.json).

## SH119 - Larvaal Wraith

![SH119 Larvaal Wraith - new L337 source geometry](assets/ships/SH119.png)

**Family:** larvaal-wraith. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 51.7 | Acceleration / native u/s2 | 17.7 |
| Energy capacity | 340 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.33 | Pitch / rad/s | 1.17 |
| Yaw / rad/s | 1.09 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 273000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 34.000 x 8.000 x 50.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH119.json) / [Exact model/material/UV data](definitions/models/SH119.json).

## SH120 - Larvaal Seeker

![SH120 Larvaal Seeker - new L337 source geometry](assets/ships/SH120.png)

**Family:** larvaal-seeker. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 34 | Cargo expansion / t | 15 |
| Speed / native u/s | 43.2 | Acceleration / native u/s2 | 15.6 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 320 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.25 | Pitch / rad/s | 1.1 |
| Yaw / rad/s | 1.02 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 281000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 15 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 6 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 26.200 x 38.200 x 29.500; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH120.json) / [Exact model/material/UV data](definitions/models/SH120.json).

## SH121 - Larvaal Mender

![SH121 Larvaal Mender - new L337 source geometry](assets/ships/SH121.png)

**Family:** larvaal-mender. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 43.7 | Acceleration / native u/s2 | 16.0 |
| Energy capacity | 450 | Energy recharge / s | 4.89 |
| Shield capacity per bank | 350 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.21 | Pitch / rad/s | 1.06 |
| Yaw / rad/s | 0.99 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 295000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 37.313 x 10.000 x 45.200; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH121.json) / [Exact model/material/UV data](definitions/models/SH121.json).

## SH122 - Larvaal Harvester

![SH122 Larvaal Harvester - new L337 source geometry](assets/ships/SH122.png)

**Family:** larvaal-harvester. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 50.3 | Acceleration / native u/s2 | 18.0 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.37 | Pitch / rad/s | 1.21 |
| Yaw / rad/s | 1.12 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 288000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.722 x 20.400 x 36.500; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH122.json) / [Exact model/material/UV data](definitions/models/SH122.json).

## SH123 - Larvaal Sovereign

![SH123 Larvaal Sovereign - new L337 source geometry](assets/ships/SH123.png)

**Family:** larvaal-sovereign. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** never.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 180 | Cargo expansion / t | 70 |
| Speed / native u/s | 27.7 | Acceleration / native u/s2 | 7.2 |
| Energy capacity | 1660 | Energy recharge / s | 9.52 |
| Shield capacity per bank | 620 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 0.52 | Pitch / rad/s | 0.46 |
| Yaw / rad/s | 0.43 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 18 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 0 | Not applicable | - |

**E01 accommodation estimate:** 6 operating crew including commander; 6 reserved intrinsic crew places; 44 equipment-budget units. Authored size tier 5, equivalent-volume proxy 64; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 36 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 3.570 x 1.188 x 4.410; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH123.json) / [Exact model/material/UV data](definitions/models/SH123.json).

## SH124 - Larvaal Warship

![SH124 Larvaal Warship - new L337 source geometry](assets/ships/SH124.png)

**Family:** larvaal-warship. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 28 | Cargo expansion / t | 10 |
| Speed / native u/s | 47.0 | Acceleration / native u/s2 | 17.0 |
| Energy capacity | 390 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.3 | Pitch / rad/s | 1.14 |
| Yaw / rad/s | 1.07 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 280000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.698 x 0.490 x 3.450; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C02 A Choir Beneath the Static

[Full definition](definitions/ships/SH124.json) / [Exact model/material/UV data](definitions/models/SH124.json).

## SH125 - Larvaal Drone

![SH125 Larvaal Drone - new L337 source geometry](assets/ships/SH125.png)

**Family:** larvaal-drone. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 26 | Cargo expansion / t | 10 |
| Speed / native u/s | 43.7 | Acceleration / native u/s2 | 16.0 |
| Energy capacity | 450 | Energy recharge / s | 4.89 |
| Shield capacity per bank | 350 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.21 | Pitch / rad/s | 1.06 |
| Yaw / rad/s | 0.99 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 295000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 14 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 5 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.993 x 1.300 x 1.993; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** C02 A Choir Beneath the Static

[Full definition](definitions/ships/SH125.json) / [Exact model/material/UV data](definitions/models/SH125.json).

## SH126 - Mangalica

![SH126 Mangalica - new L337 source geometry](assets/ships/SH126.png)

**Family:** mangalica. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.608 x 14.780 x 39.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH126.json) / [Exact model/material/UV data](definitions/models/SH126.json).

## SH127 - Gaur Trader

![SH127 Gaur Trader - new L337 source geometry](assets/ships/SH127.png)

**Family:** gaur. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 56 | Cargo expansion / t | 20 |
| Speed / native u/s | 37.7 | Acceleration / native u/s2 | 11.0 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 220 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 1.03 | Pitch / rad/s | 0.91 |
| Yaw / rad/s | 0.84 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 209000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.314 x 1.037 x 4.416; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH127.json) / [Exact model/material/UV data](definitions/models/SH127.json).

## SH128 - Boar Transport

![SH128 Boar Transport - new L337 source geometry](assets/ships/SH128.png)

**Family:** boar. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 374 | Cargo expansion / t | 150 |
| Speed / native u/s | 23.1 | Acceleration / native u/s2 | 6.2 |
| Energy capacity | 640 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 450 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.49 | Pitch / rad/s | 0.43 |
| Yaw / rad/s | 0.4 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 396000 | Not applicable | - |

**E01 accommodation estimate:** 4 operating crew including commander; 4 reserved intrinsic crew places; 83 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 74 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.989 x 0.987 x 2.788; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH128.json) / [Exact model/material/UV data](definitions/models/SH128.json).

## SH129 - Warthog 10 Guard

![SH129 Warthog 10 Guard - new L337 source geometry](assets/ships/SH129.png)

**Family:** warthog-10-guard. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 36 | Cargo expansion / t | 15 |
| Speed / native u/s | 36.8 | Acceleration / native u/s2 | 10.8 |
| Energy capacity | 560 | Energy recharge / s | 7.05 |
| Shield capacity per bank | 380 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 0.88 | Pitch / rad/s | 0.77 |
| Yaw / rad/s | 0.72 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 320000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 16 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 7 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.788 x 20.166 x 49.690; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH129.json) / [Exact model/material/UV data](definitions/models/SH129.json).

## SH130 - Marmot 11 Prospector

![SH130 Marmot 11 Prospector - new L337 source geometry](assets/ships/SH130.png)

**Family:** marmot. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 180 | Cargo expansion / t | 70 |
| Speed / native u/s | 23.7 | Acceleration / native u/s2 | 6.9 |
| Energy capacity | 530 | Energy recharge / s | 5.44 |
| Shield capacity per bank | 390 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.54 | Pitch / rad/s | 0.48 |
| Yaw / rad/s | 0.44 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 317000 | Not applicable | - |

**E01 accommodation estimate:** 3 operating crew including commander; 3 reserved intrinsic crew places; 44 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 36 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 26.732 x 17.980 x 54.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH130.json) / [Exact model/material/UV data](definitions/models/SH130.json).

## SH131 - Warthog 6

![SH131 Warthog 6 - new L337 source geometry](assets/ships/SH131.png)

**Family:** warthog-10-guard. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 730 | Energy recharge / s | 6.17 |
| Shield capacity per bank | 500 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 440000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.788 x 20.166 x 44.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH131.json) / [Exact model/material/UV data](definitions/models/SH131.json).

## SH132 - Warthog 7

![SH132 Warthog 7 - new L337 source geometry](assets/ships/SH132.png)

**Family:** warthog-10-guard. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 730 | Energy recharge / s | 6.17 |
| Shield capacity per bank | 500 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 440000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.788 x 20.166 x 47.990; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH132.json) / [Exact model/material/UV data](definitions/models/SH132.json).

## SH133 - Warthog 8

![SH133 Warthog 8 - new L337 source geometry](assets/ships/SH133.png)

**Family:** warthog-10-guard. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 730 | Energy recharge / s | 6.17 |
| Shield capacity per bank | 500 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 440000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.788 x 20.166 x 51.390; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH133.json) / [Exact model/material/UV data](definitions/models/SH133.json).

## SH134 - Warthog 9 Heavy

![SH134 Warthog 9 Heavy - new L337 source geometry](assets/ships/SH134.png)

**Family:** warthog-10-guard. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 440 | Cargo expansion / t | 175 |
| Speed / native u/s | 21.3 | Acceleration / native u/s2 | 5.4 |
| Energy capacity | 730 | Energy recharge / s | 6.17 |
| Shield capacity per bank | 500 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.42 | Pitch / rad/s | 0.37 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 440000 | Not applicable | - |

**E01 accommodation estimate:** 5 operating crew including commander; 5 reserved intrinsic crew places; 96 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 88 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 35.788 x 20.166 x 55.215; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH134.json) / [Exact model/material/UV data](definitions/models/SH134.json).

## SH135 - Javelina

![SH135 Javelina - new L337 source geometry](assets/ships/SH135.png)

**Family:** javelina. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 52 | Cargo expansion / t | 20 |
| Speed / native u/s | 39.6 | Acceleration / native u/s2 | 10.6 |
| Energy capacity | 270 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 230 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.95 | Pitch / rad/s | 0.84 |
| Yaw / rad/s | 0.78 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 220000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 19 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 10 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 22.000 x 12.082 x 36.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH135.json) / [Exact model/material/UV data](definitions/models/SH135.json).

## SH136 - Falcon Mk I

![SH136 Falcon Mk I - new L337 source geometry](assets/ships/SH136.png)

**Family:** falcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 10 | Cargo expansion / t | 5 |
| Speed / native u/s | 53.9 | Acceleration / native u/s2 | 17.2 |
| Energy capacity | 280 | Energy recharge / s | 4.18 |
| Shield capacity per bank | 250 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.47 | Pitch / rad/s | 1.29 |
| Yaw / rad/s | 1.21 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 10 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 255000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 10 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.833 x 1.251 x 2.821; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH136.json) / [Exact model/material/UV data](definitions/models/SH136.json).

## SH137 - Falcon Mk II

![SH137 Falcon Mk II - new L337 source geometry](assets/ships/SH137.png)

**Family:** falcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 10 | Cargo expansion / t | 5 |
| Speed / native u/s | 53.0 | Acceleration / native u/s2 | 16.8 |
| Energy capacity | 310 | Energy recharge / s | 4.52 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.42 | Pitch / rad/s | 1.25 |
| Yaw / rad/s | 1.16 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 10 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 268000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 10 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.879 x 1.251 x 2.918; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH137.json) / [Exact model/material/UV data](definitions/models/SH137.json).

## SH138 - Falcon Mk III

![SH138 Falcon Mk III - new L337 source geometry](assets/ships/SH138.png)

**Family:** falcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 12 | Cargo expansion / t | 5 |
| Speed / native u/s | 52.0 | Acceleration / native u/s2 | 16.4 |
| Energy capacity | 340 | Energy recharge / s | 4.85 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.2 |
| Roll / rad/s | 1.38 | Pitch / rad/s | 1.21 |
| Yaw / rad/s | 1.13 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 11 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 281000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.925 x 1.251 x 3.014; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH138.json) / [Exact model/material/UV data](definitions/models/SH138.json).

## SH139 - Falcon Mk IV

![SH139 Falcon Mk IV - new L337 source geometry](assets/ships/SH139.png)

**Family:** falcon. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 12 | Cargo expansion / t | 5 |
| Speed / native u/s | 51.0 | Acceleration / native u/s2 | 16.0 |
| Energy capacity | 380 | Energy recharge / s | 5.19 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 2.3 |
| Roll / rad/s | 1.33 | Pitch / rad/s | 1.17 |
| Yaw / rad/s | 1.09 | Fuel / 0.1 LY units | 110 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 9 | Laser facing mask | 15 |
| Hull price / CR | 295000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 1, equivalent-volume proxy 0.5; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 9 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.970 x 1.251 x 3.110; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH139.json) / [Exact model/material/UV data](definitions/models/SH139.json).

## SH140 - Chimango

![SH140 Chimango - new L337 source geometry](assets/ships/SH140.png)

**Family:** chimango. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 53.0 | Acceleration / native u/s2 | 16.0 |
| Energy capacity | 290 | Energy recharge / s | 4.1 |
| Shield capacity per bank | 240 | Shield recharge per bank / s | 1.9 |
| Roll / rad/s | 1.35 | Pitch / rad/s | 1.19 |
| Yaw / rad/s | 1.11 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 252000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 24.000 x 6.564 x 40.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH140.json) / [Exact model/material/UV data](definitions/models/SH140.json).

## SH141 - Salamander Station

![SH141 Salamander Station - new L337 source geometry](assets/ships/SH141.png)

**Family:** salamander-station. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 131.000 x 107.600 x 73.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH141.json) / [Exact model/material/UV data](definitions/models/SH141.json).

## SH142 - Buzzard Mk II

![SH142 Buzzard Mk II - new L337 source geometry](assets/ships/SH142.png)

**Family:** buzzard. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 24 | Cargo expansion / t | 10 |
| Speed / native u/s | 48.9 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 330 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 270 | Shield recharge per bank / s | 1.99 |
| Roll / rad/s | 1.28 | Pitch / rad/s | 1.13 |
| Yaw / rad/s | 1.05 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 263000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.324 x 1.746 x 3.055; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH142.json) / [Exact model/material/UV data](definitions/models/SH142.json).

## SH143 - Aardvark Miner

![SH143 Aardvark Miner - new L337 source geometry](assets/ships/SH143.png)

**Family:** aardvark. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 86 | Cargo expansion / t | 35 |
| Speed / native u/s | 27.0 | Acceleration / native u/s2 | 8.5 |
| Energy capacity | 380 | Energy recharge / s | 3.85 |
| Shield capacity per bank | 340 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.65 | Pitch / rad/s | 0.57 |
| Yaw / rad/s | 0.53 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 253000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 26 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 17 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.838 x 1.242 x 4.810; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH143.json) / [Exact model/material/UV data](definitions/models/SH143.json).

## SH144 - Razorback

![SH144 Razorback - new L337 source geometry](assets/ships/SH144.png)

**Family:** razorback. **Role:** trader. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 58 | Cargo expansion / t | 25 |
| Speed / native u/s | 40.7 | Acceleration / native u/s2 | 10.4 |
| Energy capacity | 230 | Energy recharge / s | 3.2 |
| Shield capacity per bank | 210 | Shield recharge per bank / s | 1.5 |
| Roll / rad/s | 0.92 | Pitch / rad/s | 0.81 |
| Yaw / rad/s | 0.75 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 208000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 20 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 11 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 21.664 x 14.878 x 37.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH144.json) / [Exact model/material/UV data](definitions/models/SH144.json).

## SH145 - Kestrel

![SH145 Kestrel - new L337 source geometry](assets/ships/SH145.png)

**Family:** kestrel. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.0 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 263000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 20.000 x 8.616 x 27.590; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH145.json) / [Exact model/material/UV data](definitions/models/SH145.json).

## SH146 - Merlin

![SH146 Merlin - new L337 source geometry](assets/ships/SH146.png)

**Family:** merlin. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.0 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 263000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 17.600 x 11.650 x 26.090; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH146.json) / [Exact model/material/UV data](definitions/models/SH146.json).

## SH147 - Hawk

![SH147 Hawk - new L337 source geometry](assets/ships/SH147.png)

**Family:** hawk. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 18.800 x 16.800 x 35.000; units: metres. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH147.json) / [Exact model/material/UV data](definitions/models/SH147.json).

## SH148 - Morepork

![SH148 Morepork - new L337 source geometry](assets/ships/SH148.png)

**Family:** morepork. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.594 x 1.150 x 2.521; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH148.json) / [Exact model/material/UV data](definitions/models/SH148.json).

## SH149 - Owlet Mk II

![SH149 Owlet Mk II - new L337 source geometry](assets/ships/SH149.png)

**Family:** owlet. **Role:** bountyHunter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 50.5 | Acceleration / native u/s2 | 15.6 |
| Energy capacity | 320 | Energy recharge / s | 4.43 |
| Shield capacity per bank | 260 | Shield recharge per bank / s | 1.99 |
| Roll / rad/s | 1.3 | Pitch / rad/s | 1.14 |
| Yaw / rad/s | 1.07 | Fuel / 0.1 LY units | 150 |
| Hull jump reach / LY | 11 | Authored hull spool / s | 12 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 266000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.847 x 1.151 x 3.393; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH149.json) / [Exact model/material/UV data](definitions/models/SH149.json).

## SH150 - Reindeer Freighter

![SH150 Reindeer Freighter - new L337 source geometry](assets/ships/SH150.png)

**Family:** reindeer. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 528 | Cargo expansion / t | 210 |
| Speed / native u/s | 20.8 | Acceleration / native u/s2 | 5.2 |
| Energy capacity | 740 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 480 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.41 | Pitch / rad/s | 0.36 |
| Yaw / rad/s | 0.34 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 456000 | Not applicable | - |

**E01 accommodation estimate:** 6 operating crew including commander; 6 reserved intrinsic crew places; 114 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 105 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.415 x 0.987 x 3.680; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH150.json) / [Exact model/material/UV data](definitions/models/SH150.json).

## SH151 - Lynx Escort

![SH151 Lynx Escort - new L337 source geometry](assets/ships/SH151.png)

**Family:** lynx. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.4 | Acceleration / native u/s2 | 12.9 |
| Energy capacity | 360 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.510 x 0.926 x 2.521; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH151.json) / [Exact model/material/UV data](definitions/models/SH151.json).

## SH152 - Osprey Scout

![SH152 Osprey Scout - new L337 source geometry](assets/ships/SH152.png)

**Family:** osprey. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.344 x 1.355 x 3.712; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH152.json) / [Exact model/material/UV data](definitions/models/SH152.json).

## SH153 - Osprey Strike

![SH153 Osprey Strike - new L337 source geometry](assets/ships/SH153.png)

**Family:** osprey. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.389 x 1.355 x 3.832; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH153.json) / [Exact model/material/UV data](definitions/models/SH153.json).

## SH154 - Osprey Patrol

![SH154 Osprey Patrol - new L337 source geometry](assets/ships/SH154.png)

**Family:** osprey. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.4 | Acceleration / native u/s2 | 12.9 |
| Energy capacity | 360 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.435 x 1.355 x 3.952; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH154.json) / [Exact model/material/UV data](definitions/models/SH154.json).

## SH155 - Osprey Carrier

![SH155 Osprey Carrier - new L337 source geometry](assets/ships/SH155.png)

**Family:** osprey. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 41.4 | Acceleration / native u/s2 | 12.9 |
| Energy capacity | 360 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.1 | Pitch / rad/s | 0.97 |
| Yaw / rad/s | 0.9 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 261000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.481 x 1.355 x 4.072; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH155.json) / [Exact model/material/UV data](definitions/models/SH155.json).

## SH156 - Lion Bastion

![SH156 Lion Bastion - new L337 source geometry](assets/ships/SH156.png)

**Family:** lion-bastion. **Role:** platform. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 3.524 x 2.570 x 3.398; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH156.json) / [Exact model/material/UV data](definitions/models/SH156.json).

## SH157 - Wolf Scout

![SH157 Wolf Scout - new L337 source geometry](assets/ships/SH157.png)

**Family:** wolf. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 41.9 | Acceleration / native u/s2 | 13.2 |
| Energy capacity | 400 | Energy recharge / s | 4.99 |
| Shield capacity per bank | 330 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.07 | Pitch / rad/s | 0.94 |
| Yaw / rad/s | 0.88 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 276000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.881 x 0.995 x 3.424; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH157.json) / [Exact model/material/UV data](definitions/models/SH157.json).

## SH158 - Wolf Mk I

![SH158 Wolf Mk I - new L337 source geometry](assets/ships/SH158.png)

**Family:** wolf. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 14 | Cargo expansion / t | 5 |
| Speed / native u/s | 48.2 | Acceleration / native u/s2 | 14.8 |
| Energy capacity | 360 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.21 | Pitch / rad/s | 1.06 |
| Yaw / rad/s | 0.99 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 268000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 11 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 2 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.916 x 0.995 x 3.540; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH158.json) / [Exact model/material/UV data](definitions/models/SH158.json).

## SH159 - Wolf Mk II

![SH159 Wolf Mk II - new L337 source geometry](assets/ships/SH159.png)

**Family:** wolf. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 47.3 | Acceleration / native u/s2 | 14.5 |
| Energy capacity | 410 | Energy recharge / s | 5.18 |
| Shield capacity per bank | 310 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.17 | Pitch / rad/s | 1.03 |
| Yaw / rad/s | 0.96 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 288000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.951 x 0.995 x 3.655; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH159.json) / [Exact model/material/UV data](definitions/models/SH159.json).

## SH160 - Wolf Cutter

![SH160 Wolf Cutter - new L337 source geometry](assets/ships/SH160.png)

**Family:** wolf. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 43.6 | Acceleration / native u/s2 | 14.0 |
| Energy capacity | 350 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 290 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.15 | Pitch / rad/s | 1.01 |
| Yaw / rad/s | 0.94 | Fuel / 0.1 LY units | 140 |
| Hull jump reach / LY | 10 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 265000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 1.986 x 0.995 x 3.771; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH160.json) / [Exact model/material/UV data](definitions/models/SH160.json).

## SH161 - Wolf Citadel

![SH161 Wolf Citadel - new L337 source geometry](assets/ships/SH161.png)

**Family:** wolf. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 2.021 x 1.350 x 4.040; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH161.json) / [Exact model/material/UV data](definitions/models/SH161.json).

## SH162 - Larvaal Probe

![SH162 Larvaal Probe - new L337 source geometry](assets/ships/SH162.png)

**Family:** larvaal-probe. **Role:** other. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 1.384 x 0.440 x 2.060; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** C02 A Choir Beneath the Static

[Full definition](definitions/ships/SH162.json) / [Exact model/material/UV data](definitions/models/SH162.json).

## SH163 - Lammergeier

![SH163 Lammergeier - new L337 source geometry](assets/ships/SH163.png)

**Family:** lammergeier. **Role:** pirate. **Player flyable:** no. **Acquisition rule:** pendingFabrication.

**Special authored access boundary:** this original record has no granted player fabrication recipe and is not player-flyable in its authored definition. `pendingFabrication` is a reserved design authority, not a permanent never-fabricate rule, a free blueprint, or permission to erase the record from the fleet collection. Its encounter/fabrication-specific mechanics must be explicitly authored before an entitlement is granted; historical same-ID values supply none. Keep its reference/discovery identity distinct from any currently authorised player-acquisition set.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 2.017 x 0.724 x 4.300; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH163.json) / [Exact model/material/UV data](definitions/models/SH163.json).

## SH164 - Toad Drug Factory

![SH164 Toad Drug Factory - new L337 source geometry](assets/ships/SH164.png)

**Family:** toad-drug-factory. **Role:** station. **Player flyable:** no. **Acquisition rule:** never.

**Object rule:** station, installation or environmental catalogue object; no invented player drive, cargo, missile or accommodation statistics. Native personnel and population are mission/site resources, not zero human inhabitants.

**Geometry reference:** source envelope 2.880 x 2.335 x 2.636; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

- **Display / Purchasable:** no
- **Display / Specification:** Structural object; no fictional flight-performance values assigned

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH164.json) / [Exact model/material/UV data](definitions/models/SH164.json).

## SH165 - Secretarybird

![SH165 Secretarybird - new L337 source geometry](assets/ships/SH165.png)

**Family:** secretarybird. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.132 x 1.241 x 3.680; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH165.json) / [Exact model/material/UV data](definitions/models/SH165.json).

## SH166 - Camel Rescue

![SH166 Camel Rescue - new L337 source geometry](assets/ships/SH166.png)

**Family:** camel. **Role:** transporter. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 352 | Cargo expansion / t | 140 |
| Speed / native u/s | 24.2 | Acceleration / native u/s2 | 5.9 |
| Energy capacity | 740 | Energy recharge / s | 5.23 |
| Shield capacity per bank | 460 | Shield recharge per bank / s | 1.7 |
| Roll / rad/s | 0.45 | Pitch / rad/s | 0.4 |
| Yaw / rad/s | 0.37 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 14 |
| Stock missile pylons | 6 | Laser facing mask | 15 |
| Hull price / CR | 416000 | Not applicable | - |

**E01 accommodation estimate:** 4 operating crew including commander; 4 reserved intrinsic crew places; 79 equipment-budget units. Authored size tier 3, equivalent-volume proxy 4; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 70 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 6 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.116 x 1.111 x 2.728; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH166.json) / [Exact model/material/UV data](definitions/models/SH166.json).

## SH167 - Secretarybird Survey

![SH167 Secretarybird Survey - new L337 source geometry](assets/ships/SH167.png)

**Family:** secretarybird. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 18 | Cargo expansion / t | 5 |
| Speed / native u/s | 42.3 | Acceleration / native u/s2 | 13.4 |
| Energy capacity | 360 | Energy recharge / s | 5.66 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.13 | Pitch / rad/s | 0.99 |
| Yaw / rad/s | 0.93 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 262000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.174 x 1.241 x 3.809; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH167.json) / [Exact model/material/UV data](definitions/models/SH167.json).

## SH168 - Armadillo Miner

![SH168 Armadillo Miner - new L337 source geometry](assets/ships/SH168.png)

**Family:** armadillo. **Role:** miner. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 80 | Cargo expansion / t | 30 |
| Speed / native u/s | 31.9 | Acceleration / native u/s2 | 9.4 |
| Energy capacity | 290 | Energy recharge / s | 3.7 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 1.8 |
| Roll / rad/s | 0.71 | Pitch / rad/s | 0.62 |
| Yaw / rad/s | 0.58 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 224000 | Not applicable | - |

**E01 accommodation estimate:** 2 operating crew including commander; 2 reserved intrinsic crew places; 24 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 16 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.214 x 0.962 x 3.083; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH168.json) / [Exact model/material/UV data](definitions/models/SH168.json).

## SH169 - Caracara Mk I

![SH169 Caracara Mk I - new L337 source geometry](assets/ships/SH169.png)

**Family:** caracara. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.9 | Acceleration / native u/s2 | 15.4 |
| Energy capacity | 320 | Energy recharge / s | 4.8 |
| Shield capacity per bank | 280 | Shield recharge per bank / s | 2.0 |
| Roll / rad/s | 1.32 | Pitch / rad/s | 1.16 |
| Yaw / rad/s | 1.08 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 7 | Laser facing mask | 15 |
| Hull price / CR | 259000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 7 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.258 x 1.811 x 2.788; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH169.json) / [Exact model/material/UV data](definitions/models/SH169.json).

## SH170 - Caracara Mk II

![SH170 Caracara Mk II - new L337 source geometry](assets/ships/SH170.png)

**Family:** caracara. **Role:** military. **Player flyable:** yes. **Acquisition rule:** blueprintFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 16 | Cargo expansion / t | 5 |
| Speed / native u/s | 45.1 | Acceleration / native u/s2 | 15.0 |
| Energy capacity | 350 | Energy recharge / s | 5.18 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.28 | Pitch / rad/s | 1.13 |
| Yaw / rad/s | 1.05 | Fuel / 0.1 LY units | 120 |
| Hull jump reach / LY | 8 | Authored hull spool / s | 12 |
| Stock missile pylons | 8 | Laser facing mask | 15 |
| Hull price / CR | 272000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 12 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 3 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 8 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 2.303 x 1.851 x 2.881; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH170.json) / [Exact model/material/UV data](definitions/models/SH170.json).

## SH171 - Medusa

![SH171 Medusa - new L337 source geometry](assets/ships/SH171.png)

**Family:** medusa. **Role:** alien. **Player flyable:** yes. **Acquisition rule:** plughQuestFabrication.

| Hull-native property | Value | Hull-native property | Value |
| --- | ---: | --- | ---: |
| Cargo / t | 22 | Cargo expansion / t | 10 |
| Speed / native u/s | 50.3 | Acceleration / native u/s2 | 18.0 |
| Energy capacity | 410 | Energy recharge / s | 4.7 |
| Shield capacity per bank | 300 | Shield recharge per bank / s | 2.1 |
| Roll / rad/s | 1.37 | Pitch / rad/s | 1.21 |
| Yaw / rad/s | 1.12 | Fuel / 0.1 LY units | 130 |
| Hull jump reach / LY | 9 | Authored hull spool / s | 12 |
| Stock missile pylons | 5 | Laser facing mask | 15 |
| Hull price / CR | 288000 | Not applicable | - |

**E01 accommodation estimate:** 1 operating crew including commander; 1 reserved intrinsic crew places; 13 equipment-budget units. Authored size tier 2, equivalent-volume proxy 1; estimate uses this hull's own cargo, not an old ship occupying the same SH number. Initial passenger cabins: zero unless an explicit mission/hull grant says otherwise. The theoretical empty-fit cabin-module ceiling is 4 before fitted equipment, cargo and mission reservations; this is not the number of passengers available at acceptance.

**Weapon/fitting use:** supported facings Front, Rear, Left, Right; 5 finite stock pylons. Installed laser/module type determines damage, power and heat. Hull-native shields, energy and regeneration are multiplied by the actual fitted components and alien attachments; the table is not a free fully upgraded loadout.

**Geometry reference:** source envelope 224.487 x 140.563 x 311.600; units: authored model units; no physical scale inferred. Normalised illustrations do not set docking clearance or a physical metre conversion.

**Mission appearances:** Ordinary role/habitat, discovery and compatible mission use; no campaign appearance is invented.

[Full definition](definitions/ships/SH171.json) / [Exact model/material/UV data](definitions/models/SH171.json).
