# Liberator DSV2

The Liberator from Blake's 7 is a purchasable, flyable native adaptation at stable save ID `SH171`. Search **Liberator**, **DSV2** or **SH171** in the station shipyard. Its individual [TOML](../Sources/L337Core/Resources/Ships/SH171.toml) supplies the actual geometry, materials, gameplay, price and source notes; [the rotating catalogue entry](SHIP-CATALOGUE.md#sh171---liberator-dsv2) is rendered from that same definition. Existing ship records are preserved. Research reserves SH168-SH170 for three other craft, so those IDs are not reused.

## Visual references and authoring

The user supplied [Tony Gardner's Blake's 7 Spaceships gallery](https://www.artstation.com/artwork/lxXNAe). Its front and side renders were inspected directly, including the image captioned **Deep Space Vehicle 2**. The model has three separate nacelles arranged 120 degrees around a narrow central hull: one dorsal and two ventral, each on a swept pylon. The pointed nacelle guns and central probe face forward; the large green sphere is the aft engine. Pale grey hull plating, stepped nacelle housings, dark equipment bays and grilles, central gold collector panels, muted oxide service blocks and a ribbed green engine establish the palette and detail.

The [Liberator model-building history](https://www.hermit.org/b7/Essays/liberator.html) and [Michael Pigott's photographs and Corgi description](https://mikepigottsdiecasttoysandmodels.wordpress.com/2018/11/16/blakes-7-by-corgi/) provide additional context. The Corgi article describes thicker, shorter toy pylons; those are not used as the reference proportions. [Fan scale analysis](https://www.hermit.org/Blakes7/Essays/LibSize.html) is explicitly an estimate, not a canonical specification.

The mesh is newly authored project geometry. No ArtStation model, image, texture or other reference asset is imported or redistributed. MIT covers this project's implementation and authored mesh data; it does not grant rights to outside reference artwork or the underlying television property. Reference attribution and adaptation notes live here and in the generated provenance appendix rather than an invented-design badge in the app.

`Tools/showroom/liberator-design.py` rebuilds geometry from the TOML's retained recipe with **make liberator-design**. The result uses closed lofts, outward local winding, three independently identifiable pylons/nacelles, actual raised panel and grille geometry, and a gold collector array replacing the central hull section rather than intersecting a long grey tube. The aft engine has two spherical green hemispheres separated by one broad pale equatorial housing, with fine curved pale ribs and the intentional aft housing point. Palette assignments are per face, with emission limited to the green engine. White wireframe remains white; colour-wireframe and tactical scanner/target colours retain their existing roles. Shaded showroom views, portraits and GIFs use the same materials and lighting.

## Native mechanics

All numeric specifications are chosen game adaptations, including the renderer envelope. They are not established television dimensions, combat ratings or SI measurements. The price follows the existing hull-economics formula, rounded to 415,000 CR. The current hull contributes its normal 75% trade-in allowance. Compatible fitted equipment, personal and reserved mission cargo, actual fuel and missiles transfer under the standard reviewed exchange rules; buying the hull grants no free stock or fitted equipment.

| Native hull value | Adaptation |
| --- | --- |
| Standard hold / bay upgrade | 120 t / 15 t |
| Top speed / acceleration | 36.6 / 9.0 speed per second |
| Energy / recharge | 1,024 / 4.0 per second |
| Shields / recharge | 510 each / 2.0 per second |
| Roll / pitch / yaw | 0.4 / 0.5 / 0.45 rad/s |
| Fuel tank / base jump / charge | 14 LY / 7 LY / 15 s |
| Missile pylons | 8 |
| Laser mounts | Front, Rear, Left, Right |
| Hull price / trade-in | 415,000 CR / 311,250 CR |

The three pointed nacelles are visual bow guns; the native game's four facing laser mounts remain the actual fitted weapon controllers. Energy, shields, throttle, steering and tank/navigation limits use the existing simulation. The normalised point-based docking envelope and solo automation match other playable hull adaptations. Teleportation, television-scale docking, independent TV gun banks, crew systems and other unsupported television abilities are not implemented.

## Verification

Structural checks verify exactly three radial nacelles and pylons, forward tips, an aft sphere, nondegenerate planar faces, complete opaque material assignments and deterministic recipe regeneration. Runtime regressions cover discovery, compatibility review, charged purchase, fit/property preservation, real flight values, docking resets, save/load, all 24 rotation angles, visible engine emission and unchanged wireframe policies. The rotating GIF and overview are produced by the game renderer through **make ships**. Native store/flight/save walkthrough evidence is retained under `reports/ui/liberator/` when available.
