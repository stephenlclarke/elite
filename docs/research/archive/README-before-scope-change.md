# Archived: README.md before mission scope change

**Excluded reference snapshot. Do not implement removed mission content from this document. The active [scope](../implementation-scope.md) takes precedence.**

## Elite research and replication reference

This reference preserves the research on Elite's computer and console editions, Frontier: Elite II, Frontier: First Encounters, Elite Dangerous and the fan adaptations discussed with the project owner. It separates historical behaviour from implementation recommendations so that a new game can reproduce a selected edition without accidentally combining incompatible rules.

Research updated: 13 October 2026. Mission descriptions contain spoilers.

## Catalogues

- [Versions and differences](../versions.md): platform identifiers, release families and compatibility scope.
- [Missions](../missions.md): deduplicated mission identities and version mappings.
- [Mission replication specification](../mission-specifications.md): triggers, state transitions, destinations, objectives, rewards, failure handling, persistence and acceptance scenarios.
- [Classic port profiles](../classic-port-profiles.md): C64/NES Trumbles, ST mission scheduler and GBA asteroid assignment.
- [MSX and Spectrum profiles](../z80-port-profiles.md): five MSX disk assignment graphs, Spectrum scheduler/rewards and directly checked tape resource data.
- [Oric campaign and tutorials](../oric-mission-specifications.md): ten unique assignments, two shared classic identities and four tutorials.
- [First Encounters source evidence](first-encounters-source-notes.md): interpreter findings and a structural graph of all 105 script records.
- [First Encounters journals and start saves](ffe-journal-and-save-profiles.md): 671 journal slots, 274 script journal operations, calendar conversion, six checked start saves, F03/F06/F10/F11/F12 graphs and conflicting displayed/effective deadlines.
- [Guardian mission data](guardian-mission-data.md): all 101 and 28 log requirements, route tables and historical site evidence.
- [Operations evidence](operations-evidence.md): official release boundaries, observed stage sequences and conflicting reports.
- [Operations project variants](operations-project-specifications.md): seven scenarios,26 stages, necessary labelled estimates and complete adapted runtime rules.
- [Oolite expansion specifications](../oolite-expansion-specifications.md): sixteen analysed package identities across seventeen revision profiles, including Deposed and two Military Fiasco revisions and package provenance.
- [Assassins Guild campaign](../assassins-mission-specifications.md): ten contracts, revenge/news graph, Black Mesa adventure, target parameters and 68 source callback/choice/ammunition checks.
- [Xeptatl's Sword campaign](../xeptatl-mission-specifications.md): both circuits, component retrieval, Hive battle, finale branches, source defects and 50 callback checks.
- [Estimate policy](../project-estimates.md): the owner-authorized use of necessary, individually labelled mission and ship estimates.
- [Ships](../ships.md): deduplicated models, aliases, variants and supported appearances.
- [Ship specifications and playable refits](../ship-specifications.md): Oolite core/player/equipment data, Elite-A player tables, GBA combat values, 47 ED outfitting hulls/970 modules and 155 filled common project refit profiles.
- [Docked shipyard design](../player-shipyard-design.md): full 3D inspection, side-by-side comparison with linked rotation, equipment transfer and persistent storage.
- [Aliens](../aliens.md): inhabitants, intelligent species, creatures and machines with separate classifications.
- [Sources](../sources.md): URLs, authors, relevant sections, evidence quality and disagreements.
- [Coverage and unresolved details](../coverage.md): what can be reproduced from this reference and what still needs an original-game observation or source-code check.

## How to use the reference

Choose a version profile first. Mission identities are shared, but each profile supplies its own thresholds, enemies, rewards and completion rules. A name match does not prove identical ship geometry or statistics. An appearance in one port does not prove appearance in every port.

`Confirmed` means supported by code or a detailed specialist reference. `Reported` means supported by a walkthrough or historical FAQ but not checked against a specific binary. `Unknown` means no reliable mapping was established. `Unfinished` means historical material is reported incomplete; surviving text alone does not prove a playable retail branch or its absence. Unknown is not the same as absent. Structural script decoding is evidence for further analysis, not proof that a reachable mission works in a retail binary.

The documents are behavioural specifications, not copied mission dialogue or source code. Suggested architecture and acceptance scenarios are project recommendations. Values marked unresolved must remain explicit configuration requirements; they must not silently become invented historical facts.

## Deduplication

Each mission has one canonical identifier. Ports and aliases are attached to that identifier; substantial differences are subordinate profiles. Separate story assignments remain separate even if both use the delivery mechanic. Each ship has one model row, with meaningful marks or demonstrably different designs retained. Species descriptions such as colour and temperament are not automatically separate species. Thargon drones are ships, not a second biological race.

The reference includes normalized JSON under `data/`: Guardian requirements and historical sites, Oolite package hashes, primary-source file hashes, the FFE script graph, journal index and scenario checkpoints, and Oric/MSX/Spectrum/Oolite combat resources. The ship datasets add Oolite core/equipment/model envelopes, Elite-A player capabilities, GBA resource definitions and a separate project adaptation profile. The combat tables retain raw values and explicit inheritance limits. Each dataset identifies its source and limitations.

The earlier chat overstated completeness. Community expansion content and live-service events have no closed, permanent inventory. These catalogues retain the known names while clearly identifying entries for which a faithful reproduction is not yet specified.

## Future playable ship requirements

The owner requested every playable refit to include a docking computer, forward laser, hyperspace drive and at least one missile. Missing player capabilities may be estimated, with cargo calibrated from usable hull volume. Source values, borrowed edition values and project estimates remain separate. The initial 25% hold fraction is a provisional project choice, not an original-game fact. The later docked shipyard must provide 3D inspection, a comparison in which both ships rotate together in the same direction/plane, transfer compatible equipment, and persist surplus gear for reuse. The detailed design supplies transfer/save acceptance scenarios.

All 155 current whole-craft catalogue rows have filled numerical project refits, retaining provisional geometry and estimates. Remaining campaign analysis still prevents an honest all-missions implementation handoff. The owner now permits necessary labelled mission-parameter estimates; these close project design gaps only after a mission's objective/branch sequence is established.
