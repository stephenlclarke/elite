# Ship design revision and visual review

All 93 existing project-authored recipes have been revised, together with the separate Liberator. All 74 imported geometries, their original blueprints/custody, gameplay values, IDs and source profiles are protected by a fixed pre-revision digest fixture. Face counts describe the implementation; they are not a quality quota. The table distinguishes armoured mechanical structures, intentional clean surfaces and smooth organic designs.

Krait variants use integral triangular wings; Vipers use slender angular wedges. Mandalay has a separate swept-wing explorer form. Alliance engine arms, Federal armour, Imperial streamlined nacelles and each Type cargo assembly have explicit family structures and variant differences. Lesser original designs use separate primary claws, keels, spars, aerofoils or drives rather than scaled duplicate templates. All 94 authored normalized geometries are distinct.

Mechanical refinement includes actual shallow armour wells, recessed floors and bevel rims, raised vent bars, separate canopies, hardpoints and nozzles. Liners and Imperial skins retain broad clean surfaces, with equipment detail concentrated in bays. Thargoids retain curved closed lobes, scalloped membranes and smooth carapaces; no mechanical panel/grille pass is applied. The [primary scout concept by Emilie Rinna](https://emilierinna.artstation.com/projects/Pxx5L) was visually inspected as design context. These are original project adaptations, not manufacturer meshes or claims of source texture fidelity.

All final geometry, recipes and named palettes are in the individual TOMLs. Uniform fitting to the longest stored envelope retains authored proportions; original dimensional/source fields are preserved. The ten coordinated default palettes and Liberator palette are explicitly authored native choices. Source raw RGB/texture/UV records are archival only. See [the schema](SHIP-FILES.md), [Liberator references](LIBERATOR.md) and [delivery evidence](DELIVERY-BACKLOG.md).

`make hull-designs` rebuilds the 93 existing authored hulls; `make liberator-design` rebuilds the Liberator. `make ships` renders all portraits/GIFs through the actual game, and `make readme-media` generates README media/icon. The pre-revision comparison checkpoint is `0d64f3dd9199eb7b4e60d51411650506d100ec0f`.

| Ship | Family / surface style | Before vertices / faces | Revised vertices / faces | Palette |
| --- | --- | --- | --- | --- |
| [SH002 Alliance Challenger](ships/SH002.gif) | alliance / armour | 52 / 42 | 3142 / 2245 | alliance-olive |
| [SH003 Alliance Chieftain](ships/SH003.gif) | alliance / armour | 56 / 44 | 3094 / 2135 | alliance-olive |
| [SH004 Alliance Crusader](ships/SH004.gif) | alliance / armour | 44 / 38 | 3410 / 2323 | alliance-olive |
| [SH006 Anaconda Mk II](ships/SH006.gif) | anaconda / armour | 44 / 36 | 2466 / 1615 | crimson-ceramic |
| [SH007 Argent's Quest](ships/SH007.gif) | wedge / armour | 40 / 40 | 1902 / 1275 | explorer-copper |
| [SH010 Asp Mk II Custom](ships/SH010.gif) | asp / armour | 60 / 48 | 2158 / 1443 | explorer-copper |
| [SH011 Asp Scout](ships/SH011.gif) | asp / armour | 56 / 56 | 2054 / 1383 | explorer-copper |
| [SH012 Beluga Liner](ships/SH012.gif) | liner / clean | 66 / 53 | 652 / 754 | imperial-pearl |
| [SH017 Bushmaster Elite-A](ships/SH017.gif) | wedge / armour | 48 / 52 | 1844 / 1243 | rescue-ivory |
| [SH018 Caiman](ships/SH018.gif) | wedge / armour | 44 / 36 | 2308 / 1647 | crimson-ceramic |
| [SH019 Caspian Explorer](ships/SH019.gif) | wedge / armour | 40 / 40 | 3692 / 2420 | explorer-copper |
| [SH024 Cobra Mk IV](ships/SH024.gif) | cobra / armour | 36 / 32 | 2088 / 1459 | naval-blue |
| [SH025 Cobra Mk V](ships/SH025.gif) | cobra / armour | 36 / 38 | 2296 / 1579 | rescue-ivory |
| [SH027 Copperhead](ships/SH027.gif) | wedge / armour | 64 / 48 | 1798 / 1229 | explorer-copper |
| [SH029 Corsair](ships/SH029.gif) | wedge / armour | 48 / 52 | 1780 / 1197 | rescue-ivory |
| [SH030 Cougar](ships/SH030.gif) | wedge / armour | 44 / 36 | 1800 / 1231 | crimson-ceramic |
| [SH031 Delta](ships/SH031.gif) | wedge / armour | 40 / 40 | 1906 / 1275 | explorer-copper |
| [SH032 Diamondback Explorer](ships/SH032.gif) | diamondback / armour | 26 / 22 | 2310 / 1557 | explorer-copper |
| [SH033 Diamondback Scout](ships/SH033.gif) | diamondback / armour | 52 / 42 | 2230 / 1509 | explorer-copper |
| [SH035 Dolphin](ships/SH035.gif) | liner / clean | 84 / 62 | 532 / 682 | imperial-pearl |
| [SH036 Drake](ships/SH036.gif) | wedge / armour | 36 / 32 | 2016 / 1357 | naval-blue |
| [SH041 F63 Condor](ships/SH041.gif) | fighter / armour | 42 / 40 | 1290 / 918 | rescue-ivory |
| [SH042 Falcon](ships/SH042.gif) | fighter / armour | 46 / 42 | 1510 / 1113 | crimson-ceramic |
| [SH043 Farragut-class Battle Cruiser](ships/SH043.gif) | carrier / armour | 120 / 84 | 4920 / 3171 | federal-slate |
| [SH044 Federal Assault Ship](ships/SH044.gif) | federal / armour | 44 / 38 | 2868 / 1895 | federal-slate |
| [SH045 Federal Corvette](ships/SH045.gif) | federal / armour | 48 / 40 | 3324 / 2169 | federal-slate |
| [SH046 Federal Dropship](ships/SH046.gif) | federal / armour | 52 / 42 | 2852 / 1885 | federal-slate |
| [SH047 Federal Gunship](ships/SH047.gif) | federal / armour | 56 / 44 | 2932 / 1943 | federal-slate |
| [SH054 Gu-97](ships/SH054.gif) | fighter / armour | 46 / 42 | 1472 / 1090 | crimson-ceramic |
| [SH055 Gyr](ships/SH055.gif) | wedge / armour | 40 / 40 | 1786 / 1219 | explorer-copper |
| [SH056 Harrier](ships/SH056.gif) | fighter / armour | 38 / 38 | 1426 / 1065 | naval-blue |
| [SH057 Harris Fighter](ships/SH057.gif) | wedge / armour | 52 / 42 | 1770 / 1205 | rescue-ivory |
| [SH058 Hauler](ships/SH058.gif) | freighter / armour | 94 / 73 | 2352 / 1598 | industrial-ochre |
| [SH059 Hawk Airfighter](ships/SH059.gif) | fighter / armour | 50 / 44 | 1258 / 969 | explorer-copper |
| [SH062 Imperial Clipper](ships/SH062.gif) | imperial / clean | 52 / 42 | 1256 / 1084 | imperial-pearl |
| [SH064 Imperial Cutter](ships/SH064.gif) | imperial / clean | 44 / 38 | 1456 / 1280 | imperial-pearl |
| [SH065 Imperial Eagle](ships/SH065.gif) | imperial / clean | 42 / 40 | 360 / 450 | imperial-pearl |
| [SH068 Keelback](ships/SH068.gif) | freighter / armour | 104 / 82 | 2352 / 1598 | industrial-ochre |
| [SH069 Kestrel Airfighter](ships/SH069.gif) | fighter / armour | 42 / 40 | 1296 / 989 | rescue-ivory |
| [SH070 Kestrel Mk II](ships/SH070.gif) | fighter / armour | 46 / 42 | 1338 / 1013 | crimson-ceramic |
| [SH072 Krait Mk II](ships/SH072.gif) | krait / armour | 44 / 38 | 2846 / 1899 | naval-blue |
| [SH073 Krait Phantom](ships/SH073.gif) | krait / armour | 48 / 40 | 2788 / 1821 | rescue-ivory |
| [SH074 Lanner](ships/SH074.gif) | freighter / armour | 112 / 86 | 2642 / 1768 | industrial-ochre |
| [SH075 Lanner II](ships/SH075.gif) | freighter / armour | 80 / 62 | 2838 / 1924 | industrial-ochre |
| [SH077 Lion](ships/SH077.gif) | wedge / armour | 48 / 52 | 2204 / 1565 | rescue-ivory |
| [SH078 Long Range Cruiser](ships/SH078.gif) | carrier / armour | 98 / 69 | 5120 / 3293 | federal-slate |
| [SH079 Lynx Bulk Carrier](ships/SH079.gif) | carrier / armour | 120 / 84 | 4376 / 2835 | federal-slate |
| [SH080 Lynx Highliner](ships/SH080.gif) | carrier / armour | 118 / 87 | 4872 / 3137 | federal-slate |
| [SH081 Majestic-class Interdictor](ships/SH081.gif) | carrier / armour | 92 / 66 | 4890 / 3131 | federal-slate |
| [SH083 Mandalay](ships/SH083.gif) | mandalay / armour | 56 / 44 | 2080 / 1500 | explorer-copper |
| [SH084 Mantis](ships/SH084.gif) | wedge / armour | 36 / 32 | 1912 / 1295 | naval-blue |
| [SH085 Merlin](ships/SH085.gif) | fighter / armour | 42 / 40 | 1384 / 1041 | rescue-ivory |
| [SH091 Nomad](ships/SH091.gif) | utility / armour | 40 / 28 | 1964 / 1360 | explorer-copper |
| [SH093 Orca](ships/SH093.gif) | liner / clean | 72 / 56 | 620 / 734 | imperial-pearl |
| [SH094 Osprey Attack Fighter](ships/SH094.gif) | fighter / armour | 46 / 42 | 1594 / 1161 | crimson-ceramic |
| [SH097 Panther Clipper Mk II](ships/SH097.gif) | freighter / armour | 90 / 71 | 4324 / 2800 | industrial-ochre |
| [SH100 Python Mk II](ships/SH100.gif) | python / armour | 52 / 44 | 2188 / 1557 | naval-blue |
| [SH101 Racer](ships/SH101.gif) | wedge / armour | 56 / 46 | 1528 / 1062 | rescue-ivory |
| [SH103 Saker Mk III](ships/SH103.gif) | fighter / armour | 50 / 44 | 1246 / 957 | explorer-copper |
| [SH106 Shuttle Mk II](ships/SH106.gif) | freighter / armour | 94 / 73 | 2488 / 1678 | industrial-ochre |
| [SH108 Skeet](ships/SH108.gif) | wedge / armour | 46 / 39 | 1912 / 1295 | naval-blue |
| [SH109 Spar](ships/SH109.gif) | wedge / armour | 30 / 24 | 1922 / 1287 | rescue-ivory |
| [SH110 Stowmaster](ships/SH110.gif) | fighter / armour | 46 / 42 | 1594 / 1161 | crimson-ceramic |
| [SH111 Taipan](ships/SH111.gif) | fighter / armour | 50 / 44 | 1470 / 1089 | explorer-copper |
| [SH112 Thargoid Basilisk](ships/SH112.gif) | organic / organic | 52 / 63 | 1100 / 2128 | alien-amber |
| [SH113 Thargoid Berserker](ships/SH113.gif) | organic / organic | 60 / 72 | 764 / 1504 | alien-jade |
| [SH114 Thargoid Cyclops](ships/SH114.gif) | organic / organic | 68 / 81 | 1100 / 2128 | alien-amber |
| [SH115 Thargoid Glaive](ships/SH115.gif) | organic / organic | 46 / 50 | 792 / 1552 | alien-jade |
| [SH116 Thargoid Hydra](ships/SH116.gif) | organic / organic | 46 / 55 | 1100 / 2128 | alien-amber |
| [SH117 Thargoid Inciter](ships/SH117.gif) | organic / organic | 54 / 64 | 764 / 1504 | alien-jade |
| [SH118 Thargoid Marauder](ships/SH118.gif) | organic / organic | 62 / 73 | 764 / 1504 | alien-amber |
| [SH119 Thargoid Medusa](ships/SH119.gif) | organic / organic | 70 / 82 | 1100 / 2128 | alien-jade |
| [SH120 Thargoid Orthrus](ships/SH120.gif) | organic / organic | 40 / 47 | 1100 / 2128 | alien-amber |
| [SH121 Thargoid Regenerator](ships/SH121.gif) | organic / organic | 48 / 56 | 816 / 1600 | alien-jade |
| [SH122 Thargoid Scythe](ships/SH122.gif) | organic / organic | 56 / 65 | 792 / 1552 | alien-amber |
| [SH123 Thargoid Titan](ships/SH123.gif) | organic / organic | 64 / 74 | 1178 / 2280 | alien-jade |
| [SH126 Tiercel](ships/SH126.gif) | wedge / armour | 44 / 36 | 2320 / 1659 | crimson-ceramic |
| [SH129 Type-10 Defender](ships/SH129.gif) | type10 / armour | 72 / 58 | 3578 / 2430 | industrial-ochre |
| [SH130 Type-11 Prospector](ships/SH130.gif) | type11 / armour | 94 / 73 | 2616 / 1765 | industrial-ochre |
| [SH131 Type-6 Transporter](ships/SH131.gif) | type6 / armour | 116 / 88 | 1720 / 1240 | industrial-ochre |
| [SH132 Type-7 Transporter](ships/SH132.gif) | type7 / armour | 68 / 56 | 2464 / 1672 | industrial-ochre |
| [SH133 Type-8 Transporter](ships/SH133.gif) | type8 / armour | 90 / 71 | 2736 / 1809 | industrial-ochre |
| [SH134 Type-9 Heavy](ships/SH134.gif) | type9 / armour | 112 / 86 | 3322 / 2266 | industrial-ochre |
| [SH135 Urutu](ships/SH135.gif) | wedge / armour | 64 / 48 | 1674 / 1149 | explorer-copper |
| [SH137 Viper Mk II](ships/SH137.gif) | viper / armour | 42 / 40 | 1692 / 1157 | naval-blue |
| [SH138 Viper Mk III](ships/SH138.gif) | viper / armour | 46 / 42 | 1700 / 1161 | naval-blue |
| [SH139 Viper Mk IV](ships/SH139.gif) | viper / armour | 50 / 44 | 1850 / 1263 | naval-blue |
| [SH140 Vulture](ships/SH140.gif) | fighter / armour | 38 / 38 | 1836 / 1277 | naval-blue |
| [SH141 Wheel station](ships/SH141.gif) | ring / armour | 240 / 178 | 3368 / 1872 | industrial-ochre |
| [SH144 Wyvern](ships/SH144.gif) | wedge / armour | 36 / 32 | 2172 / 1443 | naval-blue |
| [SH145 XG7 Trident](ships/SH145.gif) | fighter / armour | 42 / 40 | 1042 / 812 | rescue-ivory |
| [SH146 XG8 Javelin](ships/SH146.gif) | fighter / armour | 46 / 42 | 1094 / 848 | crimson-ceramic |
| [SH147 XG9 Lance](ships/SH147.gif) | fighter / armour | 50 / 44 | 1130 / 864 | explorer-copper |
| [SH171 Liberator DSV2](ships/SH171.gif) | Liberator / reference-led structured hull | New ship | 3868 / 3134 | liberator-pale-gold-green |
