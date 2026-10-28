# Disabled EMP profiles convert retained raw geometry again

## Source finding

The fallback in `SalvageCatalogue.empProfile` reads an eager immutable dictionary of eligible nonordinary ships. Its factory converts and retains `ship.design.rawMesh` for each candidate. For every ID except SH061, the existing raw mesh cache already derives the same mesh from the same resolved catalogue record. Repeating conversion creates another vertex buffer and any outer resolved face-texture array. Faces, palettes, details, material assignments and underlying UV arrays can already share storage and are not counted as deep duplicates.

The resolved source projection contains 132 eligible disabled-profile candidates, including SH061, with 131 shareable candidates. The latter have 167,384 vertices and 141,987 faces. Three eight-byte Double fields per vertex total 4,017,216 scalar bytes. This is not an executed profile count, Swift layout, allocator overhead, RSS saving or fit prediction. The factory can still return nil under its existing checks. Activated originals use the original JSON native design selected by `OriginalPlayerHullActivation.resolve`, rather than their packaged Ships TOML design.

SH061 is different: its raw cache intentionally retains the physical contract at 20 metres per source unit, while its disabled EMP profile uses the authored unscaled design. That distinction must remain intact.

## Observed interval and limits

The diagnostic on `e5d2844a3759010d90e67751086590e70511dea1` emitted 60 available records, all 37 profile entries, profiles-done and both original texture-done events. Its last record was SH061 emp-before, with no emp-after or body-exit. Owned RSS refused at 2,432,450,560 bytes against 2,415,919,104. The incomplete interval includes observer return, the lookup, `#require` and subsequent sampling. It does not prove product entry, cache coldness, initializer execution or allocation cause. Zero ordinary qualification follows.

## Selected correction and tradeoff

Reuse the existing raw mesh only for disabled ordinary profiles other than SH061, with the exact original raw conversion as fallback. Keep ordinary profiles, SH061, eager metadata and section work unchanged. No new cache, lock, lazy factory, purge, numeric change, option or budget is needed.

Root accepted that an EMP-first path now forces the full 171-entry raw cache earlier, including game-nil SH162/SH163 geometry, separate physical SH061 geometry and dictionary storage. Early churn and peak can increase on that path. This is not a universal startup or memory improvement, nor an established fix for the observed RSS refusal. See [the implementation and validation handoff](PR-m01-disabled-profile-mesh-reuse.md).
