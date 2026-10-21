# Native RRS geometry adapter v1

`rrs-native-geometry-v1` is a project engineering adaptation, not original Oolite population or collision parity. It supplies geometry to the native station runtime; it does not populate stations, grant services, issue docking receipts or implement P30 missions. Those integration paths remain separate. A geometry result alone never authorizes docking or a service.

## Retained source and distribution

Selected source is Rescue Stations 1.5.4, original by cim, updated by spara, dated 20 June 2017. Archive: <https://wiki.alioth.net/img_auth.php/0/05/Rescue_stations_1.5.4.oxz>, SHA256 `c3d6ba5b46e7d09865f57ec96d6741c4b53477cbdf641f9aaf44e601f3dea70c`. The original notice explicitly licenses the work under CC BY-NC-SA 3.0 Unported. Its credits identify Keeper's waystation shader work and Griff's HQ rock texture; neither shader nor texture is copied here. The original notice is retained unchanged in [RescueStations-LICENSE.txt](../Sources/EliteCore/Resources/RescueStations-LICENSE.txt), and the full legal code is already bundled in [CC-BY-NC-SA-3.0.txt](../Sources/EliteCore/Resources/Legal/CC-BY-NC-SA-3.0.txt). These numeric mesh derivatives retain that licence and attribution, following [NOTICE.md](../NOTICE.md); they are not relicensed under the application's MIT licence.

Source DAT vertices and face indices are embedded in `NativeStationGeometry.swift`. The following input hashes identify the exact unchanged source bytes used for extraction:

| Model | SHA256 |
| --- | --- |
| rrs_waystation.dat | b02afa82363c41f74ddc4c21eab76cbf33ca3dbc084ef3d91045a2aa35da8f36 |
| rrs_waystation_dock.dat | 16c7f1a47c549e8d4bca9e206ca59434d1e8708ac49b5976374fcf8449bfa9f5 |
| rrs_headquarters_asteroid.dat | 605b6ce10a665a202a0548b2b057ed19f7625c3146868b4ce5c6dd1a015b67dd |
| rrs_headquarters_construction.dat | 60c0d9c1545e6e26e46e9a6f1d4c5d2433b74664db7eaccdfd39f87062c106a8 |
| rrs_headquarters_bay.dat | ed4b32964325af313550ab8945334668de5cd979c05778cbbdebc80e55a4dcfe |

Config/shipdata.plist SHA256 `489517ba8d056211bb58a789113638476643d540eb05091f19709258fbbc073d` supplies subentity offsets/orientations and distinct source roles. Research references are `rescue-model-source.json`, `rescue-family1-mechanics.json` and `rescue-route-bindings.json` in the received research handoff. No scripts, textures or generated research files are modified.

## Geometry and coordinate adaptation

Model scale remains one native unit per source model unit. This follows the existing custom NPC `design.rawMesh` convention; it deliberately does not apply player showroom normalization to stations. Source local coordinates map through the proper rotation `(x,y,z) -> (-x,y,-z)`, so source +Z entrance normals face native -Z. Its determinant is +1: face indices and winding are preserved, with no reflection or second winding flip.

The waystation assembles the source body plus both dock subentities. Source docking offset is `(0,0,280)` with a front plane at +70; its native entrance is `(0,0,-350)`. Source launch offset is `(0,0,-280)` with quaternion `(0,1,0,0)` (X180), applied before the native Y180 transform. Its native exit port is `(0,0,350)` facing +Z. The actual octagon's alternating coordinates are 112.80569 and 46.72565; tunnel depth is 140. The main body bounds remain ±675 X, ±150 Y and ±500 Z.

HQ assembles its source asteroid and construction with all eight source bay placements. Docking bay seven is source `(-250,86.5,1685.8)`; its front plane +175 gives native `(250,86.5,-1860.8)`, facing -Z. Its aperture is 250 by 125 and depth 350. Structural bounds after adaptation are `[-1585.29214,-1779.0468,-1860.83266]` to `[1566.54969,1716.77885,1931.09101]`. Native launch uses this same actual dock bay.

The recovered `rescue_missions.js` SHA256 `0df0c819f618ee2927fa5a20a2bdbee47957742f5013d01e3a149471a9e4449f` explicitly sets waystation source orientation to quaternion `[1,0,0,0]`. HQ receives no such orientation override; a stable native HQ orientation is an engineering choice, not a recovered source orientation. Pinned engine tree `574ca848c91a067178416216523e8d09c1e9282a` resolves omitted dock permissions to docking=yes and launching=yes: `OOShipRegistry.m` lines 1458–1464 (SHA256 `1005316bb00b864b299dd1f87421d06f511eb4a4d7eb4de73e3023296bab057b`) and `ShipEntity.m` lines 913–923 (SHA256 `78f26fc31c4bccf935bc730542cbb2fc03c442f7057fc6592e93c7005751d623`). Thus HQ's shared dock/launch port is supported by the selected reader, while waystation's explicit separate permissions remain intact.

This version intentionally excludes parked display ships, flashers and force-field artwork from the station's structural mesh. It does not claim the complete source visual assembly. A native runtime must not add omitted solid actors without including them in scene collision checks. Source roles remain `rescue_station rrs_group_spacestation` and `rrs_galactic_hq rrs_group_spacestation`; the orbital mesh is never substituted.

## System placement

Use canonical system-space anchors, before camera/player transforms. The native main-station anchor must be at zero. Waystation placement preserves the source interpolation equation: `lerp(planet*0.5, normalize(sun)*length(planet*0.5), 0.3)`, evaluated on native anchors.

HQ preserves the source direction `normalize(cross(sun,planet))`. Source distance 500000 is compressed to the existing native arrival-to-main-station distance, currently 16000. This is an explicit world-distance adaptation, separate from model scale. Neither this distance nor native celestial sizes are historical source units. It introduces no extra station locations: the runtime must use the authoritative galaxy/system bindings, retaining the separate waystation in each HQ system. PLUGH receives no inferred RRS station.

Nonfinite/zero/degenerate anchors, nonzero main origin, invalid celestial radii, or overlap of the station's conservative enclosing sphere with a celestial body/main origin refuse placement. There is no fallback position. Actor budgets, another station's overlap and scene obstacles are runtime checks.

## Fit and launch proof boundaries

Fit uses every vertex of the actual effective `Commander.playerMesh`, including its current player normalization and 0.69 scaling. Each vertex must lie strictly inside every convex aperture half-plane; optional positive margin tightens this test. Convexity makes vertex containment sufficient for the whole transverse triangle projection. Both aligned directions share symmetric apertures. Equality, oversized/nonfinite geometry and invalid margins refuse. This is an aperture-fit proof, not a proof of a continuous approach, roll alignment, docking speed or tunnel clearance.

The launch pose aligns player +Z with the selected port's outward normal using a proper orthonormal basis. Its center is moved along that normal until the rear-most transformed player vertex lies 1000 units beyond the entire structural station bound. The 1000-unit project clearance is explicitly specified by `PROJECT-RRS-BOARD-v1`. All subsequent outward ray positions retain positive separation from that bound. This proves an outside-station launch placement and outward departure, not a flight path from an internal hangar. The runtime must separately sweep against other actors/celestials and respect current station pose/rotation and lifecycle; absence of that proof must refuse launch.

`NativeStationGeometryTests.swift` checks retained structural counts/bounds, proper rotation and a source triangle normal, separate ports, canonical placement and degeneracy, independent aperture inequalities for every current flyable catalogue hull, every transformed exit vertex and outward separation, and boundary/oversize/nonfinite refusal. These tests are source work until run under the coordinator's validation lease. No runtime integration or game acceptance is implied by their presence.
