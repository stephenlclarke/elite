# Issue 75: ship media fingerprints include unrelated simulation code

PR25 quality run 39758860541 at fd6499cc stops in `make ships-check` before Swift coverage, sanitizer or leak execution. The shared GIF key hashes every top-level EliteCore Swift file. Mission, custody and service edits therefore mark all 171 portraits stale even when their rendering inputs have not changed. This is a media-dependency failure, not a Swift test result.

The key must follow the actual `exportShipMedia` to `Display.shipPortrait`, preview mesh, drawing and CPU image export path. Preserve the per-ship TOML input, rendering settings, package resolution, geometry, materials, palettes, texture interpretation, both texture resource trees and GIF missing/output-tamper checks. Do not bless unrendered media, skip the stale assertion or edit GIF bytes by hand.

The source correction changes the fingerprint contract. All 171 assets, exactly docs/ships/SH001.gif through docs/ships/SH171.gif inclusive, need a coordinated actual game-renderer regeneration and a newly generated manifest. This packet must stop before that resource-intensive step. The issue remains open until the actual generated media and normal stale check pass.
