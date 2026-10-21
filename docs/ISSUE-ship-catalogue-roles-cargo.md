# Ship roles, population eligibility and cargo balances need one authoritative catalogue

The catalogue contains 171 definitions, including 162 with player performance data. Generic archival class labels and model families do not identify functional roles or purchase/discovery eligibility. The runtime currently selects a narrow native hull set; ship browsing does not prove an encounter, identification or unlock.

Cargo values also contain unexplained family differences: Python Mk II has 10t against Python's 100t, while Anaconda Mk II has 20t against Anaconda's 750t. Many effective project profiles disagree with the game's cargo expansion. These are project consistency issues; original edition-specific specifications must remain historical evidence.

The requested seven functional roles are transporter, trader, pirate, military, bounty hunter, miner and leisure. Designated traders need at least 25t of usable standard hold and transporters at least 150t. Those minima do not inflate fighters or specialists indiscriminately. No existing hold capacity, carried property, people or historical specification should be reduced or erased.

Missing performance data must not silently classify an object as display-only or remove it from the requested discovery collection. Black Widow has a distinct mission-ship model, and the carrier/station distinction needs explicit authored classification. Functional role, origin, object kind, player mechanics, discovery eligibility, purchase capability and natural/authored provision are separate facts.

## Acceptance

- Use the single source-backed UX mapping for every stable ship ID, including family-relative cargo choices and specialist exceptions.
- Decode typed per-ship metadata and reject contradictory states, invalid roles/weights and malformed declared placements.
- Preserve original profiles, native combat, geometry, appearance, noncargo performance and existing capacity.
- Apply the same reviewed project overlay through direct TOML authoring, staged imports, refinement, Liberator regeneration and reference generation.
- Explicitly queue required missing mechanics and authored providers; metadata declarations alone do not prove admitted runtime coverage.
- Keep discovery authority, encounters, purchase commits, save migration, native profiles and PLUGH integration with the main coder.

## Evidence and execution

The durable audit is `elite-ship-discovery-cargo-plugh-audit-20261017.json`, SHA256 `17d9f6108c05273632cafba198378ac9039aa512b7d4d6bf51221258885c52f2`. It is a source/data audit, not runtime proof. UX supplies per-hull classification; this change implements the catalogue contract and selected project values. The main coder owns compilation, tests, native execution, generated references/media and final CI.
