# Duplicate authored geometry in the raw mesh cache

## Source finding

`SalvageCatalogue.all` builds and retains 37 ordinary profiles from resolved `ShipCatalogue.all` records. Each profile retains `ship.design.rawMesh`. The separate `ShipCatalogue.rawMeshesByID` initializer converts those same resolved designs again. Each conversion creates a new vertex buffer and can create a new outer face-texture array. Faces, materials, details and underlying UV arrays can already share storage; their deep contents must not be counted twice.

The native salvage fixture reaches the raw cache through its actual zero-radius collision query, mesh overrides and `gameplayMeshAfterNativeStation`. The allocator diagnostic recorded a large heap increase during fixture setup, but that span also includes search, launch and migration. It does not identify the first cache initialization, allocation owner or sufficient RSS saving. The failed attempt remains historical diagnostic evidence with zero qualified shards.

## Resolved source inventory

The active records differ from packaged Ships TOML. `OriginalPlayerHullActivation.resolve` replaces SH012 with its original Sable Liner model and SH019 with its original Gazelle Explorer model. These have 132 vertices/228 faces and 172 vertices/304 faces respectively. Each has three original texture references and one face-texture mapping per face. Both caches use the same resolved record.

The 37 active designs contain 90,741 vertices and 79,168 faces. Three eight-byte Double scalars per vertex total 2,177,784 bytes of duplicate scalar payload. This is a source projection, not Swift layout, allocation overhead, resident savings or proof that a cohort fits. The earlier proposal's packaged TOML totals of 94,781 vertices and 81,810 faces are superseded.

## Required correction and limits

Reuse ordinary salvage profiles' immutable meshes inside the existing raw cache, after its unchanged SH061 physical-contract branch. Keep the exact original raw conversion fallback for other IDs. Do not make profile construction request the full raw cache, change EMP profiles, normalize geometry or alter texture validation.

Profile-only paths keep their existing initialization. A raw-cache-first path now initializes the 37 profiles' bounds, sections and metadata earlier. That adds earlier scratch allocations and can increase early ASAN churn or the raw-only peak. It must not be presented as a universal startup or peak-memory improvement. No new cache, lock, eviction, purge, option, budget or actor policy is needed. See [the change and validation handoff](PR-m01-shared-authored-mesh.md).
