# Add shared manual showroom rotation, view reset and calibrated comparison

## Result

Dragging either model rotates the shared pitch/yaw orientation; Shift-drag rolls it. A cycles the active axis and J/L turn it in 15-degree steps. Manual input pauses automatic motion. 0 and the Reset view button restore the original viewing pose and pause; R and Your ship keep their existing baseline behavior. Space still resumes or pauses automatic rotation. Search consumes its text keys and the trade dialog keeps its own navigation.

Both calibrated previews use one metre scale, resolved only from existing physical contracts and SH025's declared calibration. The largest normalized radius stays at its current framing size; the other preview moves back by the inverse physical-radius ratio, which is perspective-equivalent to uniform mesh scaling. The shared orientation applies to both. Radius resolution is cached; per-frame vertex rescaling and new calibration tables are avoided. Missing calibration is labelled Uncalibrated scale or Scale not comparable. Existing silhouette/wireframe/material and quote/purchase policies remain unchanged.

## Design and implementation mapping

Design authority is Meridian commit `8c899a7e0d351551498b05a7b371b84758575085`, read directly at its tracked `docs/meridian/` path. README and implementation/README establish design precedence while retaining the live ledger's ownership authority. GAMEPLAY-SPECIFICATION.md:95 and GAMEPLAY.md:448 supply the inspection requirement; SHIP-REFERENCE.md and canonical models/ships retain units and access policy. Exact design paths/hashes are retained in `/tmp/elite-g4-m02-m03-meridian-8c899a7e-alignment.json`. The read-only snapshot and historical stop prose do not alter current human authorization.

The patch owns showroom state/dispatch/render/scale, showroom-only help, the narrow AppKit pointer adapter and a GameRuntime extension beside the showroom implementation. Game.swift, fleet activation registries, release/workflow files and ledger are unchanged. Pointer coordinates are finite, bounded and rechecked against the current showroom model area and context by the actor-owned operation. The existing event queue preserves ordering.

## Exact design fingerprints

- `docs/meridian/missions/gameplay/GAMEPLAY-SPECIFICATION.md`: SHA256 `1ab13169744b08d0bbaae9f517e439882af57c3cf2c04a583b22d751e2db25dc`.
- `docs/meridian/SHIP-REFERENCE.md`: SHA256 `6a3688bf28f9251e58853990bfd5c76334c7e514b05d36ba4fc145c1a03ce4af`.
- `docs/meridian/missions/gameplay/ships/SH025.json`: SHA256 `35a63e37f36c332606b4650b03c0f8eeee284e842bb6c3887acf0c31a47b74b4`.
- `docs/meridian/missions/gameplay/models/SH025.json`: SHA256 `4733a94a55c6fa1572ff93da120996346b075c988d0846c8a544fdb19f849c40`.

## Validation

Six meaningful methods cover rendered shared drag at four viewport widths, all three full-circle axes and true reset versus pinned baseline, independent physical-radius ratios plus actual rendered size, uncalibrated disclosure and refused capital purchase, compact/wide button/help/search contexts, and actual actor dispatch plus invalid-context/coordinate refusal. All 562 inherited methods remain selected, plus six for 568. Local strict Swift formatting, six Python selector/report fixtures, Markdown and whitespace checks pass. Hosted Swift execution and independent bugs/performance/style review are pending; no new Swift PASS, native acceptance or release claim.

No local compiler, app launch, GUI, performance or broad integration run was performed. G1 owns M01 first, then M02 release acceptance. This later M02 source packet does not interrupt G1's frozen run. See [the issue note](ISSUE-m02-showroom-manual-view.md).

## Canonical Zebu composition

Composed canonical `89bcdf95` through a normal merge. Only the two additive selector/count conflicts required resolution: all 568 authored methods and all 567 canonical methods remain, with the union 573. The five showroom/help/AppKit production files and all six new method definitions are byte-identical to `e55a98c5`. README merged the separate showroom sentence and Zebu paragraph without conflict. The original automatic run remains live; the new composed head receives its own automatic run once. No source implementation changed.

## Hosted regression-oracle correction

Exact composed run40217645692 at285a6d2b compiled and reached all573 selected methods. Its job log reports three issues in two new methods; independent artifact/XML qualification remains MBA-owned. The shared-drag assertion incorrectly observed only untextured panels, while the owned SH025 emits actual textured triangles. It now observes both panel and texture surfaces, still requires visible changed geometry, and checks both previews' corresponding positions, colours/texture identity, appearance, lighting and perspective UV/depth. Paused geometry must remain unchanged.

The last scale assertion assumed that a capital name implies a larger model. Approved centred radii are approximately72.2013m for calibrated SH025 and60.0646m for SH043. It now requires the real SH025 radius to be larger, its shared factor to be1, and the SH043 factor to equal the independent60.0646/72.2013 ratio below1. All prior SH002-versus-SH043 ratio/rendered-shrink and disclosure checks remain. No production source, selector, method identity or purchase policy changes. These are test-oracle corrections; the failed aggregate remains recorded, and the next exact-head hosted result is still pending.
