# Textured ships are omitted from surface-presence checks

## Problem

Renderer checkpoint 176 compiled the combined source but stopped while exporting SH169, with top-level `ShipFileError.invalid("SH169")`. The exporter creates its GIF and then requires a plain ship panel for each portrait. Textured faces emit textured triangles instead of duplicate plain panels, so a valid fully textured portrait fails that guard. This is distinct from TOML validation, which reports the filename including `.toml`.

Front targeting has the same assumption: it recognises only wire lines or plain panels. Fully textured front-visible ships therefore become ineligible for Basic targeting or are misclassified as offscreen. Merely counting texture commands would create a second bug, because projected offscreen triangles are retained until rendering clips them.

## Required behavior

Recognise actual ship surfaces from plain panels or valid textured triangles intersecting the frame's flight clip and their own clip. Reuse the existing polygon clipper without allocating texture raster tiles. Export still requires surfaces, while targeting retains wire lines as an additional visibility path. Do not count HUD marks or create duplicate flat panels. Preserve source assets, digests, UVs, near-plane projection, renderer order and ImageIO validity guards.

## Acceptance and validation

Actual native GIF export must produce 24 decodable 256-square frames for both SH169 and SH170. Front visibility and actual Basic acquisition must accept centred and partially visible hulls, reject behind/offscreen hulls and retain all three display styles. Separate surface checks cover HUD/wire-only commands, viewport-corner rejection, degenerate triangles and both graphic collections.

Strict Swift formatting, Markdown lint and diff checks pass. Authored tests have not been compiled or run in this worker. Root must execute the focused cases, regenerate media through the game renderer and complete the composed quality gates. The failed 176 run is not accepted media or runtime validation. See [the implementation handoff](PR-textured-ship-surface-presence.md).
