# Equipment translation and activation boundary

The fitting numbers and generic `utilityMounts` in this proposal are planning/layout targets. They are not the existing engine's device costs or typed sockets, an approved change to those costs, or proof that a real quote fits. The reviewed immutable source is `e10c06e45c36df450b0d60074c8d2faef6b9cd18`. At dispatch the shared owner must reconcile the actual current source and freeze one typed adapter before admitting the proposed hull. Quote, commit, inventory and operation must consume that same adapter. Do not copy a 13/32 budget into an old ship profile or double-charge the intrinsic core.

## Device and socket map

| Proposal identifier / planning cost | Inspected native binding and equipment-unit cost | Mass, power and activation boundary |
| --- | --- | --- |
| Four-unit foundation reservation | `ScriptEquipmentProjection.commonEquipmentUnitCost(for:)` gives intrinsic foundation items zero units | Four is a proposal worksheet reserve only. Preserve actual intrinsic item IDs/entitlements and zero native cost. Any new structural reservation needs an explicit separately reviewed capacity adapter, not four charged equipment nodes. |
| `combatLaser`, planning one | `EquipmentRuntimeCatalog.laserFamily` and actual `LaserKind` key, `.laser(mount)`; native equipment cost zero | Actual supported facing, owned laser, heat/energy and damage still apply. Zero point cost is not a free laser, extra facing or unlimited power. |
| `miningLaser`, planning one | Same laser family and `LaserKind.mining.equipmentName`; use `.utility(.miningLaser)` only where the hull's real `workTools` supports it; native equipment cost zero | Keep actual cutter/mining emission costs and owned module condition. A generic utility count cannot create this socket. |
| `cargoScoop`, planning one | `Fuel Scoops`, `.utility(.fuelScoops)`; native equipment cost one | Use existing intake geometry and actual custody/lot admission. Do not invent a held-mass or electrical cost from the point count. |
| `salvageCutter`, planning one | `Salvage Cutter`, `.utility(.salvageCutter)`; native equipment cost one; current context requires `workTools` support | Bind actual tool envelope, section work and operational energy/heat. Never grant it because the planning kit lists it. |
| `ECM`, planning one | `E.C.M. System`, `.utility(.ecm)`; native equipment cost one | Real equipped/active state, source attribution and energy/cooldown apply. |
| `EMP`, planning two | `Equipment.empPirateBlaster`, `.utility(.empPirateBlaster)`; native equipment cost one | Planning two is not a native-cost assertion. WS-SALVAGE-01 owns the actual bank/grade/fitting/energy transfer. Hull energy and trigger warmup are not a capacitor bank. |
| `auxiliaryFuelTank`, planning two/+5LY/5t | Existing `Fuel Storage Unit` uses `.fuelStorage(index)`, one native equipment unit, +70 tenths-LY = +7LY, maximum four | The earlier worksheet values are a distinct unapproved proposed device, not an alias changing FuelStorage. Either bind/relabel the actual existing +7LY device with its real accounting, or author/approve a separate node, physical mass and power contract before use. Inspected cargo projection charges cabins but supplies `otherFittedCargoTonnes: 0`; no native 5t debit was established for FuelStorage. Never silently replace its existing behavior. |
| `salvageBeam`, planning grade allowance up to three | New branch/emitter adapter belongs to WS-SALVAGE-01; no approved current node/socket/price is inferred here | Freeze exact grade node, predecessor, typed emitter socket, physical mount, hold mass, operational draw/force and range before activation. Planning three utility devices is not current runtime support. |
| `surveyArray`, planning two | No exact shared native purchase node was established by this bounded inspection | Resolve a real existing capability or author the exact new node and typed socket. Bind consent/dwell/geometry observations and real operational costs; no fake free scan. |
| `rescueReceiver`, planning two | No exact shared native purchase node was established by this bounded inspection | Resolve the actual receiver geometry, people/custody capability, node/socket and costs. A role string cannot admit people or capture a protected actor. |
| `flightRecorder`, planning one | No generic installed recorder node was established; an identified mission recorder is not a generic equipment entitlement | Author the exact device/custody contract or map a genuine supported capability; preserve protected original items. |
| `passengerCabin`, planning one each | Existing actual cabin modules cost one native equipment unit and 5t each | Use actual grade, owned cabin/place IDs, life support/stasis, paid price and occupied/reserved constraints. Expand the specified kit count once. |

Existing shields/energy/navigation/drive/targeting families use `.shield`, `.energy`, `.navigation`, `.drive`, `.targetingCore`, `.targetingMining`, `.targetingSalvage`. Utilities use `.utility(kind)` with at most the supported kind instances; fuel tanks and missiles use indexed slots. A generic count of four never means four identical ECMs, four arbitrary utility nodes or permission to omit the current work-tool capability guard.

The owner must produce one finite typed binding row for every offered device: exact node/family and prerequisite IDs, typed socket set, supported count, equipment units, explicit hold mass, operational resource law and geometry/condition constraints. An unestablished value is Pending, not zero or a made-up default. Shared graphs and existing transactions remain the authority for current devices. New or changed numeric rows require their normal design approval; this correction approves none.

## Exact cabin aliases

| Proposal grade | Native `PassengerCabinGrade` | Places | Physical cost |
| --- | --- | ---: | --- |
| `packedStasis` | `cryogenic` | 20 | 5t / one equipment unit |
| `economy` | `economy` | 8 | 5t / one equipment unit |
| `standard` | `standard` | 4 | 5t / one equipment unit |
| `luxury` | `luxury` | 2 | 5t / one equipment unit |
| `singleStateroom` | `stateroomSingle` | 1 | 5t / one equipment unit |
| `doubleStateroom` | `stateroomDouble` | 2 | 5t / one equipment unit |

Preserve actual native support/consent, current owned identities and paid prices. A cabin-grade alias is not an old-save decoder. Intrinsic crew places cannot be counted as passenger places. The new 200CR recruitment fee and per-hull staffing remain design-only prerequisites, not silently adopted runtime shop values.

## Typed unmanned-construct EMP permission

The inspected `empPulseEligible` path rejects mission actors and requires supported human crew plus legacy hull/profile admission. Medusa's explicit unmanned quest actor therefore needs a narrow typed native permission, not a fake human crew count or a global removal of guards. Its provider must bind the actual unique registered construct, physical/world identity, owning case and unlocked quest stage, finite resource/loadout profile, no-living-crew fact, permitted electrical-disable/salvage purpose and protected core/section bounds.

Only the owning runtime/provider may mint that authority after real prerequisites. A `fullyUpgraded=false` string, arbitrary TOML flag, model name, global faction tag or generic ship ID cannot grant it. Recheck the same identity/protection/crew/resource/permission at charge start, release, disable transition and salvage application. Preserve every general protected-person/mission guard, current actual custody and no-hull-damage electrical rule. The authority admits only the intended construct under the agreed purpose; it does not turn all mission ships into targets.

## Implementation acceptance

Prove native node and socket resolution before quoting a role kit. Compare the exact quote and final commit against the same real inventory, mass, units, condition and occupied places; cancellation/refusal is atomic. Demonstrate that intrinsic costs are not double charged, free point-cost lasers are still owned/paid, existing FuelStorage remains +7LY/one unit/max four unless a separately approved change exists, and pending new devices cannot be sold as working equipment.

Test all six cabin aliases, one exact kit-count expansion, and distinct crew/passenger identities. For the unmanned permission, show the genuine unlocked quest construct succeeds while a protected witness, ordinary mission actor, forged/replayed/recycled identity, wrong world/stage and newly occupied cut volume remain refused. No source, runtime or native validation was performed by this document.
