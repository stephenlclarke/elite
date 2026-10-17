# Recognise textured ship surfaces in export and targeting

## Change

`Frame.hasShipSurfaces` recognises plain panels and valid textured triangles with nonzero clipped area. Texture checks reuse the existing four-bound polygon clipper after intersecting the triangle and flight clips; they do not allocate raster tiles. Other drawing commands do not become ship surfaces. `exportShipMedia` requires this shared surface query, retaining its image and GIF finalization guards. Front targeting uses wire lines or the surface query. See [the observed exporter failure and targeting gap](ISSUE-textured-ship-surface-presence.md).

No source artwork, manifest, TOML, geometry, cache, UV mapping, projection, drawing order or raster operation changes. A texture command lying beyond the viewport or outside a viewport corner cannot make a ship visible. Existing plain-panel and wire visibility paths remain intact, and wire-only frames do not satisfy the export surface requirement.

## Regression coverage

Five authored cases across three methods:

- `NativeTexturedShipExportTests.actualTexturedShipGIFContainsAllRenderedFrames(id:)`, SH169/SH170: all 24 portraits contain textured surfaces without plain panels; actual native export produces a GIF whose 24 frames decode at 256 by 256, retain colour variation and show changing rendered pixels.
- `TexturedShipVisibilityTests.selectedTexturedHullsUseActualFrontClippingAndBasicAcquisition(id:)`, SH169/SH170: actual catalogue meshes and Basic targeting test centred, partially visible, offscreen and behind positions in every display style.
- `TexturedShipVisibilityTests.surfacePresenceRejectsHUDWireOnlyAndClippedTextureFaces`: rejects HUD/wire-only commands, wholly offscreen faces, a viewport-corner false positive, a degenerate face and malformed vertices; checks both world and ordinary graphic collections and the retained plain-panel path.

## Validation and remaining gates

Strict Swift formatting, Markdown lint and diff checks pass. No compilation, native renderer execution or test execution occurred in this worker. Root owns the execution lease and must run these cases, existing texture/visibility/media checks, actual media generation/currentness and final composed `make ci`. This source repair does not establish a runtime pass, visual parity, performance result or release acceptance. Completed external review and final-head checks remain required before merge/publication.
