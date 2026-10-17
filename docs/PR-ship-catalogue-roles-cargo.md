# Add typed ship catalogue roles and consistent project cargo

Adds a required `catalogue` table to each ship definition and a typed loader contract. The selected UX mapping is retained in one stable-ID project input, separately from archival source specifications. Its cargo overlay updates only actual game cargo/expansion and the corresponding effective project profile fields; the ratified Rudolf display-name change preserves its original source-name alias.

## Metadata contract

- `schemaVersion = 1` and `family` identify the project schema and reviewed family. Optional `aliases` preserve source names when the project display name changes.
- `objectKind` is `ship`, `station`, `platform`, `capsule` or `other`; it does not replace archival `shipClass`.
- `origin` is `human`, `alien` or `unknown`. Origin does not determine role, allegiance, hostility or pilot legality.
- `primaryRole` and distinct positive `roleWeights` use transporter, trader, pirate, military, bountyHunter, miner or leisure. Functional roles apply to alien ships too.
- `access` is normal or xyzzyOnly. Player flyability, normal purchase capability and discovery eligibility are explicit independent fields. Purchase capability never grants a commander discovery unlock.
- `encounterMode` is natural, authored or none. Rarity, zero-based galaxy indices and existing typed encounter regions declare intended placement. Optional typed `authoredSystems` records exact galaxy/system intent without creating a provider. Authored providers are distinct from ambient draws.
- `mechanicsStatus` is ready or pending and describes native schema availability. `placementStatus` is declared or pending, separately recording unfinished authored placement/provider work. Pending authored placements may be empty; intended discovery membership remains in the required completion audit. Declared policy alone does not prove actual admitted reachability.
- `basis` documents the source-backed classification and project choice.

Common, uncommon and rare base weights are 100, 25 and 5. Primary roles use preference 4 and secondary roles 1, with pirate favourites 8 and Fer-de-Lance/Mamba bounty-hunter preference 32. A role preference multiplies the base by an authored integer from 1 through 100. These are version-one project balance values, not historical frequency claims. Natural common hulls are declared across all eight galaxies; uncommon hulls use three consecutive galaxies and rare hulls one. The start is the first byte of SHA256 over UTF-8 `elite-catalogue-placement-v1:` plus the reviewed family key, modulo eight; explicit final lists are retained in each TOML. Authored/alien or >=2500t hulls are rare; military/bounty-hunter/leisure or >=750t hulls are otherwise uncommon, and other hulls common. Actual admitted actor generation, saved identities and reachability remain runtime responsibilities.

The loader rejects missing metadata, unsupported schema, duplicate roles/placements, invalid galaxies/weights, missing primary roles for encounter ships, stale effective project cargo and contradictory capability states. Structural/capsule objects do not acquire invented ship roles just to pass population validation. SH171 is explicitly XYZZY-only, excluded from normal purchase/discovery and normal encounter provision. Missing game data does not imply display-only or noncollectible status.

## Cargo and regeneration

Role minima apply the standard unladen usable hold: 25t for any designated trader role and 150t for any transporter role. Intrinsic operating quarters are not deducted a second time. Existing cargo and cargo expansion are never reduced. Fitted cabins, protected property, people, actual NPC manifests and current-save transfer constraints remain native integration concerns.

`Tools/showroom/catalogue-balance.py` applies one reviewed input across the shared TOML writer and staged import projection. Refinement and Liberator authoring already use that writer. Reference generation refuses stale metadata or effective cargo instead of printing a different balance. Only project-refit-v1 and liberator-native-v1 cargo, expansion and usable-cargo fields are updated; retained cabin hold is subtracted from usable cargo and intrinsic quarters are not double-counted; original edition profiles remain intact. Geometry, palettes/textures, native combat, crew and other performance values are preserved.

## Validation and integration

New source tests cover the seven roles/floors, origin-independent functional roles, pending mission mechanics, malformed placements/weights, SH171 restrictions and actual loader refusal of missing/invalid metadata. Authoring tests cover immutable archival profiles, noncargo/geometry preservation, overlay idempotence, staged/direct agreement, capacity-reduction refusal and complete stable-ID consistency.

Local work is source/data/lint only. No compiler, tests, native execution, generated media or CI ran under this handoff. The main coder must execute the affected catalogue/generator tests, compose actual discovery/encounter/trade/native-profile changes, regenerate references and renderer media, validate current-save conservation and finish `make ci`. Declared positive placements are not proof that every eligible hull has a reachable admitted runtime provider.

## Selected data and remaining provider work

The final UX review, SHA256 `9489676b9c25861efc00d2c65ebf11f648bdf4b5d484d218631aa49bc627742e`, supplies all 171 classifications and cargo recommendations. FR047 supersedes Santa with Transporter150t and Rudolf naming; Ray Mk I retains an existing5t cabin, so base30t is required for the requested25t usable trader minimum rather than the review's unladen25t recommendation. This change adds 171 metadata tables, increases 56 holds and reconciles 119 stale project expansion fields without reducing an authoritative hold/expansion. The 162 ship-kind classifications and 162 performance-bearing definitions are coincidentally equal sets of different membership: Black Widow is a ship with pending mechanics, while the preserved capsule performance adaptation is not a collectible vessel.

| Family | Selected base / variant cargo (t) |
| --- | --- |
| Anaconda | 750 / 800 |
| Python | 150 / 175 |
| Panther Clipper | 750 / 800 |
| Boa | 150 / 175 |
| Lanner | 150 / 175 |
| Cobra I / III / IV / V | 25 / 30 / 40 / 35 |
| Type 6 / 7 / 8 / 9 / 10 / 11 | 150 / 200 / 250 / 400 / 300 / 200 |
| Lynx Bulk / Highliner | 3000 / 2500 |

Cobra V's smaller hold than IV is a deliberate speed/combat tradeoff; fighter/specialist holds retain smaller values when they have no trader/transporter role. Large corrections such as Anaconda Mk II and Lynx Highliner require the integrator's price/accommodation review; this leaf preserves existing price, crew and all noncargo performance fields.

All 24 authored-provider rows are explicitly pending. Black Widow retains ship-kind Pirate classification and discovery membership despite missing mechanics. SH161 remains an authored military-function carrier/station, and SH156 retains the pending real PLUGH port adaptation. Santa SH150 and Rudolf SH151 carry authored galaxy eight/internal seven, system8 Crimbo intent for FR047. The exact ratified design SHA256 is `c96f49ea546a353ec17b6d8ef04af24ec0903b119fd64d5f378550b9e203b954`; world renaming/theme and the actual provider remain central runtime work, not fabricated completed placement. Pending intended discovery entries must remain in the completion audit until their actual providers are delivered.

The authoring audit compared every original source hash before rewriting and every protected field afterward. It confirmed all original designs, native combat, archival profiles, crew/accommodation fields and noncargo performance were unchanged. The main coder must reconcile older source-preservation/cargo fixture pins against these exact approved deltas while retaining the protected-field assertions.

The three Commies project profiles lacked cabin-hold/usable-cargo comparison copies. These fixed comparison fields now derive from retained initial berth counts without changing those counts: Convict Miner zero, Ray Mk I one5t berth, Military Stingray zero. Ray Mk I is30t base/25t usable; no cabin, person or intrinsic crew place was removed.
