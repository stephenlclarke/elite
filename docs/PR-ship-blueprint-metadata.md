# Define catalogue v2 blueprint, habitat and collection policies

Adds an intentional metadata correction after frozen `b1ec8d1`, keeping all 171 identity/mechanics/design/archive/people/crew records intact. Huntsman's effective project cargo basis is refreshed to explain retained25t after the Military supersession; numeric capacity and historical profiles remain unchanged. `schemaVersion = 2` separates the eight displayed primary types from the seven functional AI roles. SH112-SH125 and SH171 display Alien; their functional military eligibility and existing origin remain separate. Ionics SH152-SH155 display/function Military, superseding Huntsman's former Trader classification without reducing its hold.

## Fabrication and habitats

`purchasePolicy` is blueprintFabrication, pendingFabrication, xyzzyOnly or never. Normal purchase capability remains catalogue policy rather than commander knowledge. A genuine credited kill, qualified system AI docking registration, current tech, cash, fit and services remain runtime requirements; targeting alone cannot unlock trading. `never` cannot be overridden by a generic XYZZY purchase bypass, while existing owned hulls remain preserved. SH171 explicitly retains xyzzyOnly and normal collection exclusion.

Every normal/pending fabrication entry has an explicit `minimumBuildTechLevel` in displayed1-15 units. The selected158 per-ID tiers are maintained in `docs/research/data/ship-catalogue-balance.json`, with reviewed family/identity/fitting basis and retained native yard evidence where available. They are project fabrication balances, not claimed historical manufacturing requirements or a formula derived solely from price/role/name. The current selected range is2-15; compare actual stored system technology plus one. Non-purchasable entries and Liberator have no normal fabrication level. Black Widow retains intended collection membership and an explicit pending-fabrication tier14 without inventing missing native mechanics.

Ionics use independent `habitat` metadata: Corporate government7 and minimum displayed Tech Level12. Retained ordinary Universe source data has no qualifying Corporate system in internal galaxy3, so this ordinary-habitat balance declares Ionics in galaxies0,1,2,4,5,6,7. Actual `systemsIncludingPlugh` adds high-tech Corporate PLUGH256 in every galaxy: omitting internal3 is a project placement choice, not a claim that the entire galaxy lacks a capable system. This does not change any world's original government/technology and never restricts fabrication to Corporate systems. Other named Military craft SH157-SH161/SH170 have broader all-eight-galaxy intent without the Ionics filter; authored providers remain pending. Redback illustrates the distinction: it may inhabit displayedTL12 Corporate space but fabrication requiresTL13 after an earned plan and qualified dock.

## Explicit inventory

| Entries | Purchase policy | Collection/full-knowledge milestone |
| --- | --- | --- |
| SH043 Farragut, SH081 Majestic, SH123 Thargoid Titan | Never | Actual credited destruction |
| SH028 Coriolis, SH034 Dodo, SH102 Rock hermit, SH141 Wheel, SH161 carrier/station, SH164 factory | Never | Genuine physical docking |
| SH156 active PLUGH platform adaptation | Never | Genuine physical docking |
| SH078 Long Range Cruiser, SH079/080 Lynx, SH155 Funnelweb, Anaconda/Python/Panther and Federal Corvette | Retained blueprint fabrication | Earned plan and qualified fabrication knowledge |
| SH163 Black Widow | Pending native fabrication adapter | Retained required membership, pending provider/mechanics |
| SH171 Liberator | XYZZY-only | Excluded from normal collection |
| Capsule and spy satellite | Never | Explicitly excluded |

The roster follows the UX capital/station inventory SHA256 `332cd9f4ca7da7c29b9253510b61b89aefe7f310254d247e6be4213f7a0da5b8`: explicit capital classes043/081 and alienCapital Titan123, with the named large civilian/specialist cases reviewed individually. Cargo tonnage and a Cruiser/Carrier name are insufficient to ban purchase. Station161 retains structural carrier/station identity and needs a real reachable docking provider; the factory also remains pending rather than receiving a fake docking receipt.

`isCapital`, `collectionMilestone` and `damagePolicy` are explicit. Milestones are none, blueprintAndFabrication, destruction or docking. `activeStationIndestructible` describes a live station instance, including active PLUGH; it does not turn an abandoned CR150 wreck into a live invulnerable station. The main coder must enforce station immunity across real weapon/collision/script paths and preserve separate abandoned-wreck salvage. No source field alone authenticates an actor or docking crossing.

## Loader, generators and validation

The production loader now calls `validEffectiveCargo`, closing the reviewed omission while preserving the actual malformed-TOML cargo-expansion regression. Typed validation rejects contradictory purchase/collection/damage states, invalid build/habitat levels and malformed displayed types. The one project input remains authoritative through direct authoring, staged import, refinement, Liberator authoring and reference generation. Reference source prints display type, functional role, fabrication tech, habitat, milestone and purchase/damage policy, replacing target-only purchase copy. Generated Markdown/GIF/media execution remains with the main coder.

New source tests cover Alien versus functional-role separation, every fabrication tier's source-system attainability, independent Corporate habitats, reviewed capital/station versus large civilian policies, and missing/out-of-range metadata through the actual loader. A source-data route audit uses retained Universe seed/twist/distance rules: galaxy0/system7 reaches256 systems, including system151 at displayedTL15, sufficient for all158 selected build tiers. This is data analysis, not proof of real station docking, factory upload, actor reachability or native commerce.

Local checks are formatting, Markdown lint, Python syntax, TOML/JSON data and exact nonmetadata preservation. No compiler, unit/Python/native/GPU tests, runtime profiler, media or CI jobs ran here. G1 must execute affected tests and implement/verify credited deaths, genuine docks, system-local fabrication, truthful first locations, shared silhouette/wireframe/full rendering, indestructible stations, pending providers, safe owned-save migration and final CI. Metadata declarations do not complete those requirements.

Root independently verified full eight-galaxy plus PLUGH source feasibility in `elite-root-galaxy-build-habitat-feasibility-20261017.json`, SHA256 `53fe99650ab8732132103805d5af5e20adb634348a0a788adbe107bd3d64b776`. Ordinary displayedTL15 exists only in six systems, absent from ordinary galaxies3/4/8 in displayed numbering; portable blueprints do not promise ordinary local fabrication everywhere. Current qualified-system docking and the secret PLUGH exception remain actor-owned.
