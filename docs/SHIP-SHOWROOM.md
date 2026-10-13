# Docked ship showroom

Press W while docked or choose Commander > Ship Showroom (Command-Shift-W). Browsing pauses gameplay and cannot buy or replace a hull, transfer equipment, change missions or award money. W closes; Escape returns from detail before closing. The previous station screen and equipment selection are retained.

The snapshot contains 167 distinct canonical ships/objects and 158 labelled common project refits. It retains classic, Frontier, First Encounters, Elite Dangerous, Oolite and expansion appearances, crew evidence and source mappings. The 158 refits are comparison data, not 158 flyable native hulls. Search by name, class, source/edition or SH identifier. Source facts take priority. Missing values receive a defensible estimate when possible, with basis and confidence; engine-defined omitted fields use the pinned Oolite initialization defaults. Estimated GBA player hold capacities borrow the same canonical project refit with low confidence, separately from NPC dropped cargo. Single-pilot narrative complements are labelled medium-confidence estimates. Life-support/passenger accommodation stays a capacity fact, never minimum operating crew. Estimated or borrowed fields stay labelled; edition units and flight seats are not silently converted into native performance or minimum crew.

Fifty-six records have inspected corresponding shaded geometry: 25 Oolite core models, Vector SE, the distinct GC Inspection Team craft, Arafura Rescue Boat and 28 additional expansion renditions. The additional models include complete source-defined nacelles, wings, turrets and docks, with distinct Hydra I/II assemblies. The Imperial Courier rendition follows Frontier-inspired Oolite geometry and is not an Elite Dangerous model. The source-model inventory is a dated research snapshot; imported runtime status is recorded here. Other records show Model unavailable; they never borrow a generic Cobra or a bounding-box surrogate. Geometry has original vertex/face topology with source normals, Z reflection and winding reconciliation; station source subentities are assembled and flashers omitted. Both comparison models share rotation. Textures are not included. Source envelopes are model units, not proven internal volume, SI dimensions or docking clearance. The current fitted Cobra comparison uses the game's existing approximate native Cobra, clearly labelled separately from the source Cobra model.

| Key | Action |
| --- | --- |
| Up / Down | Select ship; scroll specs in narrow detail view |
| / | Search name, class, source or ID |
| Return / Escape while searching | Finish search |
| Backspace | Delete search character |
| Return | Toggle detail view |
| Space | Pause / resume model rotation |
| B / R | Pin selected baseline / reset to actual current Cobra fit |
| C | Toggle comparison / individual specs |
| V | Toggle common project refit / edition source profiles |
| Comma / full stop | Previous / next profile variant |
| Fn-Up / Fn-Down | Page specifications |
| Click / scroll | Select ships and buttons / browse list or specifications |
| K / Command-K | Context help |
| W / Escape | Close / back |

The comparison label column is measured from the longest displayed label at the fixed bitmap scale, with separate 16-point gutters. Narrow windows wrap values and, only when needed, labels; all cells share the actual wrapped row height. Long source identifiers split across lines instead of overlapping a neighbour. Comparison aligns matching fields and only subtracts compatible units/profile groups. Current-native physical capacities and counts can compare to source/project values; native speed, energy and shield pools cannot. Capacity, speed, crew burden, pylons and jump reach produce descriptive tradeoffs when comparable. Neither price nor hull size is treated as an automatic advantage.

Missing dimensional data uses the retained named reference envelope and stated linear/volume scale, rounded to two significant figures and labelled low confidence. This is only an estimated envelope: it never supplies a fake authentic mesh or measured internal space. One hundred eight unavailable-model entries currently have such dimensional estimates. Numeric differences involving estimated values say estimated.

The current fit reports actual cargo, fuel/tank/nav limits, independent mounted lasers, targeting/navigation tiers, shields, energy and missile stock, plus the actual native maximum speed/acceleration, recharge and normal-flight control authority. Native engine values remain distinct from source/project units; non-modelled slot capacities are not fabricated for the live commander. Its commander is the one assigned crew member; quarters remain outside usable cargo. No charter cabins are fitted: berths, passengers, free places and cabin footprint are zero. Project standard refits likewise start unladen with zero fitted charter cabins. Historical rescue passenger maxima do not create free berths on a player hull. Full hull purchase, crew hiring, cabin fitting, equipment transfer and surplus storage remain future shipyard work.

## Snapshot and attribution

`make showroom-data SHOWROOM_MODELS=/path/to/pinned/Oolite/Resources/Models SHOWROOM_EXPANSIONS=/path/to/recovered/packs SHOWROOM_MODEL_CACHE=/path/to/verified/archive/cache` regenerates the checked-in JSON from the independently maintained local `docs/research` snapshot. The generator reads each input once, records its SHA256, verifies every included mesh's source SHA256, and checks identity/refit totals. It does not edit research. P30 and P46 directories and the verified archive cache are needed for the complete 56-model snapshot. The additional inventory pins archive and DAT hashes, root definitions, all inherited/subentity assemblies and notices. Without optional expansion inputs, generation deliberately leaves those models unavailable. `make showroom-check` validates inheritance, component transforms, whole-assembly scaling, legacy strings and fail-closed missing/cyclic components; it also runs in `make ci`. Normal builds use the committed snapshot and need no research checkout or network access.

[Asset attribution](../Sources/EliteCore/Resources/ASSET-NOTICE.txt) identifies authors, source versions, transformations and licenses. Oolite models use the artwork's CC-BY-NC-SA-3.0 option from its [full license](../Sources/EliteCore/Resources/Oolite-LICENSE.txt); Vector and Rescue Stations models use their respective CC-BY-NC-SA-3.0 licenses. Other imported models retain their per-package CC-BY-NC-SA-3.0 or 4.0 license and original notices in `ModelLicenses`. Stealth's additional identifier clauses are preserved: its preview has an XYZZY identity and activates none of the source entity roles or scripts. These model adaptations retain their applicable asset license. The Swift game code remains MIT. Source licenses/credits ship in the app resource bundle. The approved original native Cobra app icon is unchanged.

Remaining geometry gaps: 111 entries, including five unresolved exact variant identities. Modern ED and historical Frontier/FFE same-name craft are not silently assigned unrelated Oolite/Pioneer models. Original source decoding, rights and faithful reference reconstruction remain separate work. Wheel station has an explicitly low-confidence same-role station energy/translation comparison; it has no fabricated authentic geometry or playable hull.
