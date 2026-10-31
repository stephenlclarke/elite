# Port the reviewed SH103 Redtail Mk III activation to current L337 source

This composition ports only the reviewed25-path delta `e3d445518362b17ffaaca6800211c90bbfe88b2d..4d69e3d80a380565f777c37619be3b9d9cd0f7a4` onto immutable current L337 parent `15f28f956e2983b8a24e7c3d79a25b237ca1341b`. The new adapter, its five tests, four shared production additions and16 prior-oracle changes retain their reviewed semantics. Only Core paths/import namespace, current-parent handoff notes and the owned README placement change. The existing reviewed original/797/4d source packets remain preserved; no old whole-tree, M02 release or M03 source is replayed. [Motivation](ISSUE-m04-redtail-mk-iii.md).

## Behavior and authority

The adapter requires SH103/Redtail Mk III/redtail/bountyHunter/player/blueprintFabrication, valid native performance, approved mesh and specification fingerprint `902ed193390f5fa4dd4fabf3099717b91a67fb1d09ea95a93d80b654822cdf34`. Physical binding requires explicit metres, model path `fleet-completion-20261019/batch-04/SH103-design.toml` and fingerprint `39ec7a78c9da5b4ff652255b4d278d1169821bb27941e1d34ccc2f97ce61eb90`. The packaged model matches the exact frozen Meridian `8c899a7e0d351551498b05a7b371b84758575085` model bytes.

The complete physical/player model retains 84 vertices, 140 triangular faces, eight materials, 140 face-material/texture assignments and three textures. Bounds are minimum (-11, -9, -18.5), maximum (11, 4.936, 18.5), dimensions 22 x 13.936 x 37 metres. Source units use scale 1. Preview normalization supplies no physical authority.

All 17 original values remain: cargo 22, speed 54.7, acceleration 16.2, energy 370, recharge 4.76, roll 1.32, pitch 1.16, yaw 1.08, shield 270, shieldRecharge 2.09, fuel 130, jump 9, spool 13, missiles 7, facings 15, cargoExpansion 10 and price 287000. Work tools remain nil. The wrapper forwards all 17 CatalogueShip properties and changes only the live equipment-budget field under E01, 8 + ceil(22/5) = 13. Historical Saker Mk III fields retain equipment 12; live and historical crew/reserved places remain 1/1 with zero initial charter places.

Cargo 22+10, seven finite pylons, the 13-LY tank and four laser facings are capacity limits. No equipment, people, cabins, cargo, tools, blueprint, discovery or ownership is issued. Retained policy remains noncapital/nil subtype/destructible/normal access, blueprint fabrication at technology 9, uncommon natural placement in zero-based galaxies 0/1/7 and retained deepSpace/tradeLane regions. Existing common bounty-hunter admission is reused. An explicitly supplied escort/civilian actor retains its legal, navigation, provenance and absent-scoop facts; catalogue role does not infer actor authority.

Only the per-hull adapter and four existing registration/physical/player-mesh files change production behavior. The targeted SH103/name scan found generated source data, raw/model/manifest resources and two historical baseline fixtures, with no fixed mission/runtime Swift dependency. None of those resources or fixtures changes. SH102 and other known unitless controls remain blocked. All hull and historical-loader bindings present in the actual M01 parent remain intact. No absent old-canonical activation or loader is imported.

## Five focused methods

1. `exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash`: strict definition/specification/performance and model/units/path/hash refusal, including unitless SH102 and foreign hulls.
2. `originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings`: all 17 native mechanics, current identity, complete historical fields and unrelated unactivated records.
3. `physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance`: full physical/player vertex, face, material, detail, UV and texture equality, exact bounds/dimensions, clearance and source notes.
4. `bountyHunterPolicyKeepsAccessAndPlacementWithoutChangingActorAuthorityOrEarlierRoles`: retained policy, earlier roles, unknown discovery and explicit escort/civilian actor admission without inferred legal/navigation/equipment authority.
5. `originalHoldCrewWeaponLimitsAndRetainedInputValidationGrantNoFreeFittings`: live 13 versus historical 12, unchanged crew/reserved/charter values, actual capacity and mount limits, no inventory/people/cargo grant, explicit cargo expansion and malformed retained-name refusal after a valid load.

All four shared production files and16 prior-oracle files in the current target parent are byte-identical to the original delta parent after mechanical `EliteCore` to `L337Core` namespace mapping. The same reviewed SH103 membership additions therefore apply without changing another hull's activation or a newer physical binding. The original adapter is byte-identical; the new test retains every original oracle with only its import namespace mapped. Formatting may change whitespace only. No absent old-canonical tests or activations are resurrected.

Tools/CI, current test fixtures, normal quality configuration and all selectors remain byte-identical to this parent. G3 will compose the existing Besra packet and exact incremental selectors after this packet freezes. No selector replacement, active-hull policy or guessed global selected-method/hull count is part of this work. The parent/current namespace union needs its own future validation; historical734 PASS is not replayed or promoted.

## Pins and validation

| Authoritative path | SHA256 |
| --- | --- |
| `docs/meridian/missions/gameplay/ships/SH103.json` | `3e3cb1b668a9eeb11f226c221adcb723100d5bbc39e21e69cb8cafa9dde64115` |
| `docs/meridian/missions/gameplay/models/SH103.json` | `05285e9531db6baecaad91e33c73e5390ed2b2495d1d13ef10e2c6eeadb9289a` |
| `docs/meridian/SHIP-REFERENCE.md` | `6a3688bf28f9251e58853990bfd5c76334c7e514b05d36ba4fc145c1a03ce4af` |
| Retained `Sources/L337Core/Resources/Ships/SH103.toml` | `965f48f068fe1ec43be1b7bf2bf3c022612ecaffbf5c3eb21b61f3adac541c8a` |

Static source/path/namespace/hash checks, scoped standalone Swift formatting, Markdown lint and whitespace are the complete validation boundary. All five Redtail methods are authored but UNRUN on this parent. Existing source reviews remain credited for unchanged implementation semantics; only current changed composition awaits independent review. No compiler/typecheck/test/native/GUI/GPU/render/media/probe/performance/CI execution, push, PR, merge, ledger or live/primary checkout mutation occurs. G1's current M03 delivery remains primary, and later qualification/visual/flight/docking/release gates remain separate.

## Current G1 composition boundary

This retained note records the previously reviewed component. G1 prepares Redtail b949f286 followed by Besra 5f17913d on exact PR297 source `a7b609b4d4842cfcdf6363f1e971aeac7f26e9f4`, tree 1b2032eb. The old parent references above remain historical component provenance. All ten new hull methods and the combined 569-method selection are UNRUN. The running PR297 checks do not qualify this candidate; actual protected-main rebinding, independent composition review and affected execution remain required. Published L337 1.6.0 remains its separate source 05b3 delivery.
