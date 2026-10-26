# Bind the original Moose Clipper transporter hull

SH062 resolves to original Moose Clipper mechanics and approved metre geometry. The packet starts from published Barbary `78beba1e76e69baf8d1efdc9af5dd2ff439094a3` (PR243); parent Condor/Falconet/Barbary qualification and integration remain separate gates. This is M04.H062, owned by Elite Coder3.

The exact specification fingerprint is `39fc71f28c9597a79b7f06ab1d1e578703bc77ff9cb9e1d2f2b823504e224833`. Model `fleet-completion-20261019/batch-03/SH062-design.toml`, fingerprint `ec91173e7ff65ed64271fabdae0c237519774c07d5ef6a97a2e21c36287324f0`, explicitly declares metres. Its114 vertices,192 faces, eight materials and texture assignments supply raw physical/player/salvage meshes. Bounds are31 x23.41 x70.59 metres; display normalization does not set physical scale. Raw resources remain unchanged.

Original mechanics use396t cargo,160t expansion, speed24.9, acceleration5.8, energy630/recharge5.23, shield440/recharge1.7, fuel130, jump8, spool14, six pylons, four laser facings and397,000CR. Transporter classification, technology-ten blueprint rules, common natural placement across all eight galaxies and retained regions remain. The sole shared role change adds transporter to the existing closed allowed-role guard; exact SH062 authentication and dispatch still apply.

The SH062-only typed live projection uses E01 equipment88, operating crew5 and intrinsic places5. Historical Imperial Clipper fields retain22/1/1. Initial passenger cabins remain zero. All17 catalogue properties are forwarded. No people, cabins, inventory, blueprint or hull is granted. No shared accommodation, salvage, admission, ownership or mission adapter changes are included.

Five meaningful methods cover source/model/role/policy/flyability/unit/path/hash refusals; all mechanics/history and unrelated identities; complete physical/player/salvage geometry and appearance; transporter placement and explicit NPC actor authority; and actual accommodation/hold396+160/mounts6/fuel130/no-grant/malformed-input behavior. Actual salvage profile tests preserve largeTransport classification and abandoned/occupied/claimed/mission/station eligibility. Existing26 membership-oracle files add onlySH062; prior role tuples remain unchanged. All608 parent selections remain, with five new methods giving613. SH005/006/028/056/058 remain unchanged and not runtime-ready.

Strict Swift formatting, Markdown/whitespace and20 Python report-helper fixtures are the local validation scope. Swift methods are authored and UNRUN at freeze; independent review and exact-head hosted qualification remain pending. No local compiler, native/GUI, broad integration, performance or release work ran. [M04.H062](ISSUE-m04-moose-clipper.md) does not establish playable completion.

## Meridian acceptance mapping

Design branch `docs/final-game-review` is pinned to `8c899a7e0d351551498b05a7b371b84758575085`. The prerequisite check used live ledger `c913cdeb37aeadf8482d63a51491fd9f595f4c8d`. Root owns ledger edits and independent MBA dispatch. The design snapshot is read-only.

| Design path | SHA256 | Packet mapping |
| --- | --- | --- |
| `docs/meridian/missions/gameplay/ships/SH062.json` | `b0b02c37fc0759a2cc05dc6f2259cd2683e917ea2edeed2cdbc227e62462ad64` | Exact Moose/moose/transporter/flyable/blueprint identity and all native values match packaged data. |
| `docs/meridian/missions/gameplay/models/SH062.json` | `528a1be69e2454213f36030ca31b0b1fe9bef4bdb7e1278c50e0479021c35a12` | Entire parsed model matches packaged geometry, units, source path/hash, materials and UVs. |
| `docs/meridian/SHIP-REFERENCE.md` | `6a3688bf28f9251e58853990bfd5c76334c7e514b05d36ba4fc145c1a03ce4af` | SH062 E01 equipment88, crew5, reserved5, initial cabins0; historical22/1/1 retained. |

Direct consumer review found SalvageCatalogue derives SH062 mesh/bounds/sections from the authoritative catalogue mesh without a fixed historical hash. Its production implementation remains unchanged. Concrete SH056/58 M01 geometry dependencies remain blocked, with archival decoupling deferred to G1 after the release/safe boundary. No name/hash/calibration guard is relaxed.
