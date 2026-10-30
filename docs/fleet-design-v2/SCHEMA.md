# Per-ship authoring contract

Version `l337.fleet-design/2` describes a base ship; `l337.fleet-design-variant/2` describes a Tithe conversion. This is the complete proposal handoff shape, not permission to replace an established runtime decoder without review. The shared loader owner adapts it to the maintained per-ship folder once, preserving all values and source decisions. Generated tables and JSON are not independent authorities.

| Section | Meaning | Required handling |
| --- | --- | --- |
| Top level | Stable ID, current name/family, existing classification, origin, object kind, capital status and actual primary use | ID keys ownership/discovery/missions; display names never key saved identity. Reject duplicate IDs and duplicate normalised display names. |
| `access` | Player flyability, purchase rule, discovery method, specific mission gate and crew requirement | A true numeric capability does not override `never` purchase or a missing Medusa prerequisite. A station uses docking discovery. |
| `acquisition` | Controlling salvage workstream, actual EMP/sample evidence, beam dependencies and specific Medusa receiving/loan/retry rule | No new destroy-to-unlock grants; a temporary disable or generic scoop is insufficient. Normal paid purchase is separate from story completion. |
| `medusaConfigurations` | Four distinct stock/mission/purchase/actual-upgraded configurations | Stock budget is 13, mission and purchase grant no player maximum. The 32-unit expansion needs an actual paid fitting contract. |
| `candidatePlayerUpgradeTargets` | Earlier proposed upgraded targets retained for planning in the same units as performance | Never apply these directly to stock, mission, purchase or as a free upgrade preset. Complete legal upgraded-loadout power comparison remains pending. |
| `source` | Old display name, exact original spec/geometry paths and fingerprints, reason for naming | Preserve provenance; the previous name is audit data, not a runtime alias, compatibility name or alternate showroom search result. |
| `geometry` | Original intent, new physical target/basis, surface/attachment requirements, variant feature and native budget | Authored metre dimensions and new estimates remain distinct. Resolve active calibration before admitting a changed physical hull. |
| `performance` | Complete proposed base numerical values | Finite nonnegative fields; positive price for normally purchasable ships; range cannot exceed tank; valid facing mask. Units are fixed by CAPABILITIES.md. |
| `accommodation` | Original per-hull layout estimate, required actual crew/places, autonomy and cabin mass/limits | Keep source estimate status visible in engineering docs. Do not turn it into automatic free people, cabins or E01 runtime calculation. |
| `fitting` | Equipment budget, utility mounts, supported devices, recommended role kit, cabin package and missile mounting | Quote and runtime enforce the same real limits. Role kit is an optional separately priced fit. |
| `environment` | Station/platform/probe behavior without fabricated normal player performance | Reuse explicit native service/damage/docking/mission contracts; absence of player performance is intentional. |

There are 163 base performance records after adding SH163, including the escape pod and unpurchasable capitals. The remaining eight base objects are six stations, one platform and one probe. This does not mean 163 ships can be bought. The Tithe conversion performance points to an exact frozen parent contract and must retain that parent fingerprint when admitted; its geometry and control/crew policy are distinct.

Conversion `boxComponentsXYZWHL` rows are `[centreX,centreY,centreZ,width,height,length]` in metres. They are initial assembly envelopes. They cannot be parsed as completed detailed/native faces or used to skip attachment, tool-aperture and physical collision authoring.

`equipmentBudgetUnits` counts usable fitting units including the four-unit foundation. The stored whole-hold cabin ceiling is a physical upper bound, not a fitted count. The selected purchased role package must also fit remaining units, mounts and actual life support. `fuelTankLY` measures stored standard fuel; `maxJumpLY` measures one jump. The 19LY Warthog Tanker has a 12LY single-jump reach.

The eventual runtime decoder must use a bounded TOML implementation and typed Swift 6 Sendable values; no network/eval/plugin code is embedded in a ship file. Validate all fields and referenced assets before atomic catalogue admission. Preserve never-purchase and mission-gate policy even when a custom file supplies attractive statistics. A malformed record must not partially mutate the live catalogue or commander.

Proposal budgets and generic utility counts need the native conversion defined in EQUIPMENT-MAPPING.md. They are not a substitute for existing typed ComponentFittingSlot admission or shared equipment-unit/resource effects. Unbound new devices stay unavailable. SH123's currentAcceptedDisplay fields deliberately distinguish its accepted selected display source from historical source provenance, without declaring physics or activation.

Store only current-format state as required by the game; this request does not require old-format adapters. A current save references stable IDs and owned components/people, not copied stale derived display names. A current ship-definition version change must be handled by the actual quoted/revalidated ownership policy, never silently delete occupants, cargo, mission custody or fitted items.
