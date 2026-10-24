# Meridian - the finished L337 game oracle

This folder defines the intended finished game: gameplay, progression, the complete original mission stories and stage rules, equipment and upgrades, mission graphics, and the new L337 fleet. It contains full spoilers.

Start with [the gameplay review](missions/GAMEPLAY.md). [The complete single-file oracle](FINAL-GAME-ORACLE.md) contains everything in one Markdown file, with all ship definitions/images at the end. The smaller reading views below make the same material convenient to browse on GitHub.

- [Implementation guide and read-only ledger snapshot](implementation/README.md)
- [Canonical mission data and all gameplay specifications](missions/README.md)
- [Guaranteed clue continuity and distinct physical mission rules](missions/gameplay/GAMEPLAY-SPECIFICATION.md)
- [Gameplay, equipment, upgrades and milestone outcomes](missions/GAMEPLAY.md)
- [All general contracts, Wayfarer services and tutorials](missions/CONTRACTS-AND-TUTORIALS.md)
- [The Unwritten Route and the complete 64-source clue register](missions/UNWRITTEN-ROUTE.md)
- [All 798 mission graphics (758 originals plus 40 additions)](MISSION-ARTWORK.md)
- [Portable complete mission, fleet and world definitions](missions/)
- [New graphics for revised missions](missions/gameplay/REVISED-MISSION-ARTWORK.md)
- [Exact asset provenance and geometry-image hashes](ASSET-PROVENANCE.json)
- [Coverage counts](COVERAGE.json)
- [Mission coherence and gameplay progression review](MISSION-COHERENCE-REVIEW.md)
- [Game-mechanics support audit and every objective](GAME-MECHANICS-SUPPORT.md)

## Complete original campaigns

| ID | Storyline | Full definition |
| --- | --- | --- |
| C01 | The Glass Meridian | [Read](missions/C01.md) |
| C02 | A Choir Beneath the Static | [Read](missions/C02.md) |
| C03 | The Hollow Manifest | [Read](missions/C03.md) |
| C04 | The Borrowed Voice | [Read](missions/C04.md) |
| C05 | The Shattered Wake | [Read](missions/C05.md) |
| C06 | The Tithe of Worlds | [Read](missions/C06.md) |
| C07 | The Still Current | [Read](missions/C07.md) |
| C08 | Wayfarer Exchange | [Read](missions/C08.md) |
| C09 | The Quiet Nursery | [Read](missions/C09.md) |
| C10 | Borrowed Dawn | [Read](missions/C10.md) |
| C11 | The Open Shadow | [Read](missions/C11.md) |
| C12 | Harbour Without Orders | [Read](missions/C12.md) |
| C13 | False Colours | [Read](missions/C13.md) |
| C14 | The Rubble Covenant | [Read](missions/C14.md) |
| C15 | A Garden in Transit | [Read](missions/C15.md) |
| C16 | The Warrant Ledger | [Read](missions/C16.md) |
| C17 | The Measure of Care | [Read](missions/C17.md) |
| C18 | The Long Return | [Read](missions/C18.md) |
| C19 | The Unfinished Map | [Read](missions/C19.md) |
| C20 | The Blue Reservoir | [Read](missions/C20.md) |
| C21 | Mutual Shelter | [Read](missions/C21.md) |
| C22 | The Listening Frontier | [Read](missions/C22.md) |
| C23 | An Assembly of Orbits | [Read](missions/C23.md) |
| C24 | Under Tow | [Read](missions/C24.md) |
| C25 | The Memory Atlas | [Read](missions/C25.md) |
| C26 | A Fleet of Neighbours | [Read](missions/C26.md) |
| C27 | Uncounted Names | [Read](missions/C27.md) |
| C28 | The Honest Circuit | [Read](missions/C28.md) |
| C29 | Small Lights | [Read](missions/C29.md) |
| C30 | The Passenger's Horizon | [Read](missions/C30.md) |
| C31 | The Kind Distance | [Read](missions/C31.md) |
| C32 | Cold Reserve | [Read](missions/C32.md) |
| C33 | The Magnetic Orchard | [Read](missions/C33.md) |
| C34 | Open Measure | [Read](missions/C34.md) |
| C35 | The Shared Pulse | [Read](missions/C35.md) |
| C36 | The Witness Window | [Read](missions/C36.md) |
| C37 | Public Record | [Read](missions/C37.md) |
| C38 | Signed Passage | [Read](missions/C38.md) |
| C39 | The Guiding Light | [Read](missions/C39.md) |

## Ship reference - new L337 fleet

[All 171 new L337 definitions and their images](SHIP-REFERENCE.md) form the final reference. Each record links its numerical definition and authenticated original mesh/material/UV data. These are the new L337 designs, not the legacy ships on `main`. The three-view images are exact source-geometry illustrations, not screenshots or physical calibration. Original texture assets are retained alongside them.

## Authority and use

Use this oracle to judge the intended finished product. Gameplay text describes the finished experience; it is not an implementation progress ledger. Mission IDs, target identities, branch requirements, custody, payouts, clues and hull access rules are preserved. Explicit estimates and reserved original design decisions are labelled rather than passed off as historical facts. The canonical work ledger remains the authority for implementation ownership and progress.

Canonical mission data and gameplay specifications live under `missions/`, including the detailed engine/UX contracts, fleet models/stats and world/economy data. The implementation folder contains a dated, exact-byte ledger copy; it is a read-only snapshot, while the live main ledger remains the single work-packet authority. New source-continuity and mission-interaction rules are designed here and still require native implementation and play balancing.

The single-file oracle is the complete reading source. The other Markdown views are exact section extracts with adjusted relative links. Update them together when changing the oracle. Artwork is original project content with methods and hashes recorded in the provenance manifest; ship illustrations use only the authenticated new L337 geometry.
