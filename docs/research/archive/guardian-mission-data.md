# Ram Tah objective data and replication rules

**Archived and excluded from implementation by owner instruction on13 October2026. See [active scope](../implementation-scope.md). Ship data may remain available separately.**

This supplement resolves the missing log-to-item mappings for mission:D01 and mission:D02. It uses Canonn's direct research records, accessed 12 October 2026, rather than inferring combinations from log titles. There are 101 distinct first-mission objectives and 28 distinct second-mission objectives. The tables are factual lookup data; original lore prose, audio and site artwork are not reproduced.

## Evidence and version scope

Sources: [D16, first-mission route](https://canonn.science/codex/ram-tah-mission-route/), [D17, second-mission lore locations](https://canonn.science/codex/decrypting-the-guardian-logs-lore-locations/), plus the mission guides D01 and D02 in [sources](../sources.md). The first route was revised on 16 August 2026; the second page's metadata reports 13 February 2024. These are observed lookup records, not Frontier server code or a binary-matched payout specification.

Machine-readable equivalents: [first-mission data](data/guardian-ruins.json) and [second-mission data](data/guardian-logs.json). Each includes the source URL and SHA-256 of the retrieved HTML. These hashes identify what was read; the source pages themselves are not bundled. The files preserve published site labels and coordinate ambiguity.

## Common objective interpreter

Use a set of credited log IDs scoped to the accepted mission instance. For an active obelisk, match its site/layout and obelisk ID, check the SRV cargo multiset, then credit its log only if not already credited. Item order is immaterial; two identical items require quantity two. Ship cargo cannot satisfy an SRV-cargo check remotely. Scanning with the wrong combination cannot increment progress. The scan does not consume the artefacts in the documented procedure. A second site offering the same log must not add a second reward. Inbox delivery and objective credit are separate: delayed or suppressed messages do not undo an already credited scan. The guides report a 30-second rescan timeout.

Accept automatically on qualifying docking at Felice Dock for D01, or Mitchell/Weber Dock for D02, without requiring engineer unlock. Save the accepting station as issuer; partial or complete hand-in belongs there. Use a 28-day expiry, preserve accepted time across saves, close the instance at hand-in, and clear its credited set before a later repeat. In the documented D02 profile, each unique log is worth 1,000,000 credits and all 28 add 30,000,000; D01's historic bonus must be selected by build rather than copied from D02. The observations do not establish current server rounding, expiry payout, death/abandonment penalties or concurrent-mission interference, so those remain unverified.

## D01: all 101 Ancient Ruins log combinations

Abbreviations: B = Biology, C = Culture, H = History, L = Language, T = Technology. Artefacts: Ur = Urn, To = Totem, Ca = Casket, Or = Orb, Ta = Tablet, Re = Relic. Obelisk H12 and log H12 are separate identifiers.

### Site locations

Coordinates are latitude, longitude in degrees. Where the source supplies one unlabelled pair, its Live/Legacy applicability is unresolved. GR28 has no published Live coordinates on this page. GS67 is the source's label for an Ancient Ruins stop; do not silently reinterpret it as a Guardian Structure for mission D02. The route says ten systems, but its eleven site rows contain nine distinct system names. Its intermediate progress counters also contain an error at GR131; objective set cardinality is authoritative for this transcription.

| Site | Published location and coordinate evidence |
| --- | --- |
| GR11 | SYNUEFE TP-F B44-0 / CD 1, POI: Ancient Ruins (1) (Alpha) @ 54.10, 141.15 (4.0/Live) or 31.86, -100.03 (3.8/Legacy); 734 LY, 1186 LS, 17/101 |
| GR25 | HIP 39768 / A 14 F, POI: Ancient Ruins (2) (Beta) @ 49.46, -85.72 (4.0/Live) or -0.01, -149.47 (3.8/Legacy); 84 LY, 6861 LS, 29/101 |
| GR89 | SYNUEFE ZL-J D10-109 / E 3, POI: Ancient Ruins (2) (Beta) @ 37.44, 84.86 (4.0/Live) or -26.65, -148.43 (3.8/Legacy); 71 LY, 92424 LS, 40/101 |
| GS67 | COL 173 SECTOR OE-P D6-11 / B 3, POI: Ancient Ruins (3) (Beta) @ -35.28, -130.54 (4.0/Live) or 2.00, -10.67 (3.8/Legacy); 170 LY, 34463 LS, 48/101 |
| GR35 | COL 173 SECTOR LY-Q D5-59 / 8 B @, POI: Ancient Ruins (1) (Alpha) -6.34, 130.67; 101 LY, 1169 LS, 56/101 |
| GR28 | COL 173 SECTOR XG-J C10-17 / A 2, POI: Ancient Ruins (1) (Beta) @ (4.0/Live) or -17.00, 44.24 (3.8/Legacy); 46 LY, 290 LS, 59/101 |
| GR159 | COL 173 SECTOR UU-O D6-20 / 6 D, POI: Ancient Ruins (1) (Alpha) @ -17.39, -104.85; 138 LY, 796 LS, 66/101 |
| GR123 | COL 173 SECTOR UU-O D6-30 / 4 D, POI: Ancient Ruins (2) (Gamma) @ 24.73, -133.21; 29 LY, 920 LS, 84/101 |
| GR132 | COL 173 SECTOR YG-A C15-20 / A 1, POI: Ancient Ruins (1) (Beta) @ 27.03, -85.83 (4.0/Live) or -71.00, 169.85 (3.8/Legacy); 0 LY, 249 LS, 86/101 |
| GR131 | COL 173 SECTOR YG-A C15-20 / A 1, POI: Ancient Ruins (2) (Gamma) @ 40.77, -21.05 (4.0/Live) or 69.19, -63.96 (3.8/Legacy); 160 LY, 249 LS, 94/101 |
| GR119 | COL 173 SECTOR OC-C B29-1 / A 4, POI: Ancient Ruins (1) (Gamma) @ 21.11, 54.58; 111 LY, 96 LS, 101/101 |

### Objective lookup

| Log | Site | Obelisk | SRV cargo multiset |
| --- | --- | --- | --- |
| B1 | GR159 | I1 | Ur + Re |
| B2 | GR159 | A6 | Ur + Ur |
| B3 | GR35 | I6 | Ur + Ca |
| B4 | GR35 | I10 | Ur + Ta |
| B5 | GR159 | F19 | Ur + Or |
| B6 | GR159 | F21 | Ur + To |
| B7 | GR25 | U15 | Ur + Re |
| B8 | GR25 | U12 | Ur + Ur |
| B9 | GR25 | U47 | Ur + Ca |
| B10 | GR132 | R14 | Ur + Ta |
| B11 | GR89 | U4 | Ur + Or |
| B12 | GR89 | U22 | Ur + To |
| B13 | GR131 | A9 | Ur |
| B14 | GR131 | I7 | Ur + Ur |
| B15 | GR123 | B16 | Ur + Ca |
| B16 | GR123 | B24 | Ur + Ta |
| B17 | GR131 | I16 | Ur + Or |
| B18 | GR119 | I11 | Ur + To |
| B19 | GR123 | I14 | Ur + Re |
| C1 | GR159 | B6 | To + Re |
| C2 | GR35 | C8 | To + To |
| C3 | GR35 | C3 | To + Ca |
| C4 | GR11 | C1 | To + Ur |
| C5 | GR11 | C6 | To + Ta |
| C6 | GR11 | D1 | To + Or |
| C7 | GR89 | K26 | To |
| C8 | GR132 | R18 | To + To |
| C9 | GR25 | I5 | To + Ca |
| C10 | GR25 | P23 | To + Ur |
| C11 | GR28 | K4 | To + Ta |
| C12 | GR89 | K21 | To + Or |
| C13 | GR25 | P2 | To + Re |
| C14 | GR123 | C5 | To |
| C15 | GR131 | R11 | To + To |
| C16 | GR131 | C15 | To + Ca |
| C17 | GR123 | C4 | To + Ur |
| C18 | GR119 | C7 | To + Ta |
| C19 | GR131 | C2 | To + Or |
| C20 | GR123 | R16 | To + Re |
| H1 | GR11 | J1 | Ca |
| H2 | GR159 | A14 | Ca + Ca |
| H3 | GR11 | G2 | Ca + Ur |
| H4 | GR11 | J5 | Ca + Ta |
| H5 | GR11 | G3 | Ca + Or |
| H6 | GR11 | N5 | Ca + To |
| H7 | GR159 | L4 | Ca + Re |
| H8 | GR89 | G18 | Ca |
| H9 | GS67 | D6 | Ca + Ca |
| H10 | GR89 | A9 | Ca + Ur |
| H11 | GR89 | T18 | Ca + Ta |
| H12 | GR89 | G13 | Ca + Or |
| H13 | GS67 | T4 | Ca + To |
| H14 | GS67 | G4 | Ca + Re |
| H15 | GS67 | T14 | Ca + To |
| H16 | GR89 | T13 | Ca + Re |
| H17 | GR123 | O3 | Ca + To |
| H18 | GR119 | J4 | Ca + Ca |
| H19 | GR123 | E4 | Ca + Ur |
| H20 | GR119 | O2 | Ca + Ta |
| H21 | GR131 | D1 | Ca + Or |
| L1 | GR35 | M1 | Ta |
| L2 | GR11 | M10 | Ta + Ta |
| L3 | GR11 | M19 | Ta + Ca |
| L4 | GR11 | M20 | Ta + Ur |
| L5 | GR11 | M5 | Ta + Or |
| L6 | GR35 | M14 | Ta + Ta |
| L7 | GR35 | M24 | Ta + Re |
| L8 | GR28 | C17 | Ta |
| L9 | GR25 | C20 | Ta + Ta |
| L10 | GR25 | C10 | Ta + Ca |
| L11 | GS67 | E22 | Ta + Ur |
| L12 | GR25 | N8 | Ta + Or |
| L13 | GS67 | N24 | Ta + To |
| L14 | GS67 | N2 | Ta + Re |
| L15 | GR119 | H2 | Ta |
| L16 | GR131 | H22 | Ta + Ta |
| L17 | GR123 | H4 | Ta + Ca |
| L18 | GR123 | H5 | Ta + Ur |
| L19 | GR131 | H43 | Ta + Or |
| L20 | GR123 | D12 | Ta + To |
| L21 | GR123 | H32 | Ta + Re |
| T1 | GR11 | O7 | Or |
| T2 | GR11 | O15 | Or + Or |
| T3 | GR11 | P7 | Or + Ca |
| T4 | GR11 | P9 | Or + Ur |
| T5 | GR11 | O19 | Or + Ta |
| T6 | GR35 | O12 | Or + To |
| T7 | GR25 | M2 | Or |
| T8 | GR28 | H9 | Or + Or |
| T9 | GR25 | E3 | Or + Ca |
| T10 | GR89 | U37 | Or + Ur |
| T11 | GR25 | H5 | Or + Ta |
| T12 | GR89 | O3 | Or + Re |
| T13 | GS67 | L6 | Or + Re |
| T14 | GR123 | K9 | Or |
| T15 | GR123 | F9 | Or + Or |
| T16 | GR123 | K7 | Or + Ca |
| T17 | GR123 | F7 | Or + Ur |
| T18 | GR131 | F6 | Or + Ta |
| T19 | GR123 | G4 | Or + To |
| T20 | GR123 | L5 | Or + Re |

## D02: all 28 Guardian Logs combinations

A location is an example instance, not a requirement to fly this exact route. Canonn reports that the same combination at the same structure layout supplies the same log. The layout is part of the key: cargo alone does not determine the log. These locations have system/body and layout data but no precise surface coordinates or complete physical obelisk placements in this source; recreating the geography still requires the linked maps or a site survey.

| Log | Example location and layout | Obelisk alternatives | SRV cargo multiset |
| --- | --- | --- | --- |
| 1 | Vela Dark Region ZE-A d66 (68Ly) 6 B 1446ls HAMMERBOT/ANCIENT_SMALL_001 | A03 | Thargoid Sensor + Cyclops Tissue |
| 2 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | C01 | Thargoid Sensor + Basilisk Tissue |
| 3 | Col 173 Sector PZ-O d6-116 (39Ly) 6 D 1280ls CROSSROADS/ANCIENT_TINY_002 | B09 | Thargoid Sensor + Thargoid Link |
| 4 | Vela Dark Region EG-X b1-1 (19Ly) A 1 42ls BEAR/ANCIENT_SMALL_002 | E08 | Thargoid Sensor + Thargoid Probe |
| 5 | Col 173 Sector ME-P d6-92 (58Ly) B 5 411ls BOWL/ANCIENT_SMALL_003 | D01 | Thargoid Sensor + Medusa Tissue |
| 6 | Col 173 Sector RU-O d6-16 (105Ly) A 2 A 1476ls HAMMERBOT/ANCIENT_SMALL_001 | C06 | Casket + Orb |
| 7 | Vela Dark Region EL-Y d55 (53Ly) 1 367ls BEAR/ANCIENT_SMALL_002 | E03 | Casket + Tablet |
| 8 | Col 173 Sector ZL-L b24-2 (44Ly) B 1 466ls BOWL/ANCIENT_SMALL_003 | D5 | Casket + Totem |
| 9 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | C02 | Casket + Relic |
| 10 | Col 173 Sector YF-N b23-6 (44Ly) A 3 41ls LACROSSE/ANCIENT_TINY_001 | D10 | Casket + Urn |
| 11 | Col 173 Sector ZL-L b24-2 (44Ly) B 1 466ls BOWL/ANCIENT_SMALL_003 | B07 | Orb + Relic |
| 12 | Vela Dark Region EG-X b1-1 (19Ly) A 1 42ls BEAR/ANCIENT_SMALL_002 | E14 | Orb + Orb |
| 13 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | B09 | Orb + Casket |
| 14 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | C08, B08 | Relic + Totem |
| 15 | Col 173 Sector ME-P d6-92 (58Ly) B 5 411ls BOWL/ANCIENT_SMALL_003 | A05 | Relic + Casket |
| 16 | Col 173 Sector ME-P d6-92 (58Ly) B 5 411ls BOWL/ANCIENT_SMALL_003 | A07 | Relic + Urn |
| 17 | Col 173 Sector PZ-O d6-116 (39Ly) 6 D 1280ls CROSSROADS/ANCIENT_TINY_002 | A09, B04 | Relic + Tablet |
| 18 | Col 173 Sector ZL-L b24-2 (44Ly) B 1 466ls BOWL/ANCIENT_SMALL_003 | C07 | Orb + Totem |
| 19 | Col 173 Sector RU-O d6-16 (105Ly) A 2 A 1476ls HAMMERBOT/ANCIENT_SMALL_001 | A10 | Orb + Casket |
| 20 | Col 173 Sector PZ-O d6-116 (39Ly) 6 D 1280ls CROSSROADS/ANCIENT_TINY_002 | D01 | Relic + Orb |
| 21 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | A07 | Orb + Urn |
| 22 | Vela Dark Region EG-X b1-1 (19Ly) A 1 42ls BEAR/ANCIENT_SMALL_002 | E16, B01 | Orb + Tablet |
| 23 | HIP 39768 (127Ly) A 14 F 6953 ls FISTBUMP/ANCIENT_TINY_003 | B08 | Orb + Relic |
| 24 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | A12, D06 | Tablet + Totem |
| 25 | Vela Dark Region EL-Y d55 (53Ly) 1 367ls BEAR/ANCIENT_SMALL_002 | E07 | Urn + Orb |
| 26 | Vela Dark Region ZE-A d66 (68Ly) 6 B 1446ls HAMMERBOT/ANCIENT_SMALL_001 | B01 | Urn + Totem |
| 27 | Synuefe GT-H b43-1 (640Ly) C 4 27770 ls TURTLE/ANCIENT_SMALL_005 | D07 | Urn + Tablet |
| 28 | HIP 39768 (127Ly) A 14 F 6953 ls FISTBUMP/ANCIENT_TINY_003 | C02, A07 | Urn + Casket |

## Historical alternative-site archive

[D18](../sources.md) supplies a pinned Canonn research snapshot with 335 ruins sites, 100 structure sites, 952 ruin-obelisk definitions and 488 structure-obelisk definitions. The normalized [historical site dataset](data/guardian-historical-sites.json) retains all 101/28 log definitions once, separate obelisk definitions, and each site's active-obelisk references. It excludes lore text. Source JSON URLs and SHA-256 hashes are embedded.

This snapshot contains 4,093 ruin-site/obelisk associations and 419 structure-site/obelisk associations, covering all 101 and 28 objective IDs respectively. Of these associations, 2,740 and 417 reference obelisks marked unverified in that snapshot. Their presence is a research lead, not proof of correctness. Keep `broken`, `verified` and null log IDs; do not turn every grid position into a usable mission scan.

Dates show pre-Odyssey records for many coordinates. For example the bulk GR11 record gives 31.88,-100.05 while a separately cached site-11 response gives 54.109,141.159. The route explicitly separates Legacy and Live values. A missing Live GR28 value must not be filled from the historical -17.00,44.24 record. Bulk database coordinates, a separately cached response and a contemporary route are different evidence profiles.

The repository also contains Alpha/Beta/Gamma map SVGs. They establish map-art locations, not independently measured game-world metre coordinates, surface orientation or current terrain. Exact scene reconstruction still requires those transformations and an original-game fixture. Use the route tables above for the verified objective transcription; use the historical archive to investigate alternatives and contradictions.

## Acceptance fixtures and remaining limits

Verify all 101 expected IDs B1-B19, C1-C20, H1-H21, L1-L21 and T1-T20, and all second-mission IDs 1-28. The saved datasets pass uniqueness and set-completeness checks. For each row, exercise correct items, reversed order, missing item, wrong item and repeat scan. For Or+Or require two Orbs. A correct scan at the wrong layout must not accidentally return the expected D02 log. Complete one log, save/reload, and verify one credit only. Hand in one fewer than the total and check that no completion bonus is granted.

These datasets close objective enumeration and decoding combinations. They do not close exact site meshes, object coordinates, Sentinel spawn triggers, every alternative site, or current-build reward/expiry behaviour. Keep D01/D02 at R2 for whole-mission historical parity until those are verified; the decoding objective component is now R1.
