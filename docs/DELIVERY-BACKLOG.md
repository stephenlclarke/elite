# Requested game changes and delivery evidence

This checklist separates implemented source, verified behaviour and released downloads. The public 1.2.0 ZIP predates this change set. `integrated` below means present on the feature branch, not yet in the public download or the player's running app. Coder 1 owns integration; Coder 2's isolated contributions are cherry-picked. The scriptable mission engine has its own user-requested branch and owner.

| Request | Owner | Status | Implementation evidence | Remaining acceptance |
| --- | --- | --- | --- | --- |
| Fine detail across every project-generated hull | Coder 1 | In progress | `refine-catalogue.py`, `surface-detail.py`, individual `[design]` records; 93 revised existing recipes | Distinctness regression, all contact sheets/rotations, live showroom |
| Recognisable families; distinct Krait, Mandalay, Viper and Type silhouettes | Coder 1 | In progress | `mechanical-hulls.py`, explicit per-TOML family/variant recipes | Full visual review, family comparisons |
| Smooth, organic Thargoids | Coder 1 | Integrated | `organic-hulls.py`, 12 distinct forms; closed mesh/winding tests | Renderer and native visual review |
| Coordinated palettes and material properties in each TOML | Coder 1 | Integrated | `ShipMaterial`, `ShipAppearance`, per-face assignments, ten authored palettes | Full loader/renderer tests; actual source textures remain metadata |
| Preserve imported face colours, texture references and UVs | Coder 2 | Integrated | Importer commit `888700e`; exact geometry comparisons for 74 source meshes | Final metadata/geometry provenance tests |
| Liberator: three nacelles; buy/fly/save | Coder 1 | Integrated | `SH171.toml`, `liberator-design.py`, `LiberatorTests.swift` | Final native purchase/flight/docking/reload |
| Liberator: round green engine, two hemispheres, one band | Coder 1 | Integrated | Engine structural tests; rendered 24-frame rotation | Final native visual review |
| Liberator: gold collector stays visible on exposed body | Coder 1 | Integrated | Grey hull no longer crosses collector interval; regression test and full rendered rotation | Final native visual review |
| Top five profitable reachable planets; saved toggle; XYZZY default | Coder 2 | Integrated | `363df86`, `ProfitScan.swift`, focused budget/stock/hold/range tests | Combined native chart/navigation flow and full CI |
| Startup title before continuing restored commander | Coder 2 | Integrated | `cf9a177`, `restoreStartup(from:)`, startup-save tests | Cold launch with valid/missing/corrupt save; native Continue |
| Credits show version, repository and exact build SHA | Coder 2 | Integrated | `BuildIdentity.swift`, packaged metadata, startup tests | Final committed bundle metadata/title/credits check |
| Compact charts: notes, map, facts, globe, legend and footer do not overlap | Coder 1 | Integrated | Reserved range-note area; `CompactChartTests.swift` | Native 512/768/wide windows, scan-enabled dense charts |
| Keyboard, menus, contextual help and README agree | Coder 2 / Coder 1 | Integrated | `dab746c`, current-owned-ship wording; no essential End/F keys | Final native controls/help review |
| Every ship loads from its own TOML with design and specs | Coder 1 | Carry-forward | `ShipCatalogue.load`, existing loader tests; 168 records | Final all-record validation |
| GIF dependencies include specs, geometry, palettes and renderer; central catalogue | Coder 1 | Carry-forward | `ship-reference.py`, content-hash tests, `make ships` | Regenerate and `make ships-check` |
| Real trade quote/exchange; cargo, fit, cash and missions preserved | Coder 1 | Carry-forward | Existing ship-trade tests plus Liberator test | Final native exchange/save/reload |
| Normalised better/worse/same comparisons, aligned values and legend | Coder 1 | Carry-forward | Comparison/layout/UX tests | Native narrow/wide checks |
| A-Z and power sorting; visible ship-switch action | Coder 1 | Carry-forward | Existing showroom state/UX tests | Native browse/filter/purchase |
| XYZZY Clean reset and Cobra restore | Coder 1 | Carry-forward | Existing XYZZY tests and menu actions | Combined regression suite |
| MacBook search, paging, focus, Back and overflow hints | Coder 1 | Carry-forward | Existing keyboard/help/navigation tests; controls guide | Native essential flows |
| Mission schema shared with researcher | Coder 1 | Verified handoff | Explicit cross-chat handoff of `MISSION-PACKS.md` and current source boundaries; researcher acknowledged | Preserve schema-1 compatibility in engine branch |
| Generic mission terminology and safe existing campaign behaviour | Coder 1 | Carry-forward | Existing mission-pack/gallery/dialog tests | Final suite; no unsupported research campaign activation |
| Game-rendered icon, README media and ship previews | Coder 1 | Pending regeneration | `make readme-media`, `make ships` | Regenerate after final source edits |
| Coverage, thread/address sanitizers, memory leaks | Coder 1 | Pending final gate | Focused checks pass; prior Liberator-only gate is not final evidence | `make ci` on combined checkpoint |
| Protected main, exact-commit Sonar, signed/notarized universal download | Coder 1 | Pending delivery | Existing protected-main/release workflow; valid `elite-release` profile | PR checks/merge, exact-main Sonar, notarization/public-download verification |
| Fully scriptable mission engine | Mission researcher | Separate branch in progress | `feature/scriptable-mission-engine`, approved design in `docs/research` | Engine owner's implementation/compatibility/physical capability gates; no premature playable claims |

Imported geometry, source profiles, gameplay values, stable ship IDs and existing saves must survive the visual revision. Ship livery defaults are explicitly project adaptations. Archival texture names/UVs are not texture pixels, and unknown texture rights are not inferred from a geometry licence. The renderer currently uses actual geometry, diffuse material colour and emissive panels.
