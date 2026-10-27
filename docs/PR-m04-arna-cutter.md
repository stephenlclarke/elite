# Bind the original Arna Cutter transporter hull

SH064 resolves to original Arna Cutter mechanics and approved metre geometry. This M04.H064 packet starts from published, source-reviewed Moose Clipper `7ab49761f3948ef0b7aef73daa1004307643db57` (PR244). Parent qualification and integration gates remain separate. Elite Coder3 owns this bounded packet.

Specification fingerprint `38d6360e261ce6fa95abdd0a79b8fd284c7ec15b01d0473151f80137be870777` and model `fleet-completion-20261019/batch-03/SH064-design.toml`, fingerprint `470c4f3530d75eb55cd74e896922e26b26df6771b65af04112639db4209d5c80`, authenticate only SH064. The model explicitly declares metres;112 vertices,184 faces, eight materials and complete texture assignments supply raw physical/player/salvage meshes. Bounds are32 x18.98 x56.59 metres. Display normalization sets no physical scale. Raw resources are unchanged.

Native values retain396t cargo,160t expansion, speed24.9, acceleration5.8, energy630/recharge5.23, shield440/recharge1.7, fuel130, jump8, spool14, six pylons, four laser facings and397,000CR. Transporter classification, technology-thirteen blueprint rules, common natural placement across all eight galaxies and retained regions remain. Closed SH064 dispatch and strict physical/identity guards reuse Moose's existing transporter guard, with no new shared role semantics.

The SH064-only typed live profile applies E01 equipment88, crew5 and intrinsic places5; historical Imperial Cutter fields retain40/1/1. Initial passenger cabins remain zero. All17 catalogue properties are forwarded, and no people, cabins, inventory, blueprint or hull is granted. Shared accommodation, salvage, admission, ownership and mission adapters are unchanged.

Five meaningful methods cover source/model/role/policy/flyability/unit/path/hash refusals; mechanics/history and unrelated identities; full physical/player/salvage geometry and appearance; transporter policy/placement and explicit NPC authority; actual accommodation/hold396+160/mounts6/fuel130/no-grant/malformed-input behavior. Actual unchanged SalvageCatalogue classification is largeCombatShip with exactly generalShip source roles; abandoned, occupied, claimed, mission-protected and station eligibility remain. Existing27 test oracle files add onlySH064. All613 parent methods remain; five Arna methods produce618 selected methods. SH005/006/028/056/058 remain unchanged and not runtime-ready, with blocked56/58 guards intact.

Strict Swift formatting, Markdown/whitespace and20 Python report-helper fixtures are the local validation scope. Swift methods are authored and UNRUN at freeze; independent source review and exact-head hosted qualification remain pending. No local compiler, native/GUI, broad integration, performance or release work ran. [M04.H064](ISSUE-m04-arna-cutter.md) source/component acceptance does not establish playable completion.

## Meridian acceptance mapping

Current design branch `docs/final-game-review` remains pinned to `8c899a7e0d351551498b05a7b371b84758575085`; prerequisite check used live ledger `ad8ca555d1f8e821d7a8fc8cec82c7e1e68c2c86`. Root approved this packet after Moose publication and owns ledger updates and independent MBA dispatch. The design snapshot remains read-only.

| Design path | SHA256 | Packet mapping |
| --- | --- | --- |
| `docs/meridian/missions/gameplay/ships/SH064.json` | `a6c3edba4dd71ea845f40162f17858d93f8a7021eef4fd9c79edf5b3aa1ce868` | Exact Arna/arna/transporter/flyable/blueprint identity and all native values. |
| `docs/meridian/missions/gameplay/models/SH064.json` | `f16d2a6416f53372cfb97fa0240ce3cc3df0193c855ad384c1b7b580fd8aac70` | Entire parsed model equals packaged geometry, explicit units, path/hash, materials and UVs. |
| `docs/meridian/SHIP-REFERENCE.md` | `6a3688bf28f9251e58853990bfd5c76334c7e514b05d36ba4fc145c1a03ce4af` | E01 equipment88, crew5, reserved5, initial cabins0; historical40/1/1 preserved. |

Direct consumer review found the existing SalvageCatalogue SH064 largeCombatShip entry derives mesh, bounds and sections from the authoritative raw catalogue mesh without fixed legacy name/hash guards. Its implementation is untouched. Concrete SH056/58 M01 dependencies remain blocked, with archival decoupling deferred to G1 after release/safe boundary. No name/hash/calibration guard is relaxed.
