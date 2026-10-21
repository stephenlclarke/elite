# feat(worlds): bundle approved original-world catalogue and checked adapter

Bundles the exact approved `catalogue.json` and `authoring.toml` under `Resources/OriginalWorlds`, plus a dated provenance manifest recording source authority, SHA-256 fingerprints, byte counts and original statistics. The catalogue contains 2,048 ordinary worlds, 256 per galaxy, with the exact eight galaxy names. Negative Cartesian LY coordinates are retained.

`OriginalWorldCatalogue.loadBundled()` checks the pinned fingerprints before decoding the maintained JSON/TOML resources. The immutable Sendable records retain all 29 world fields: original keys/names, positions, government/hostility, economy/sector fractions, technology, wealth, population/productivity, radius/tilt and every appearance/seasonal field. Typed read-only authoring records retain the complete galaxy, government, commodity, equipment and economic configuration without enabling those policies in gameplay.

Validation rejects missing/unknown world fields, invalid versions, non-finite or out-of-bounds values, inconsistent ID/name pairs, duplicate identities/names, incomplete galaxies and changed recorded statistics. Coordinate bounds are the actual preserved per-galaxy extents recorded during import. Lookups use exact keys and bounded identities; Euclidean Cartesian LY distance refuses cross-galaxy requests. No aliases, old universe regeneration, anisotropic conversion or fallback data are introduced.

## Validation

Authored focused tests cover bundled decoding, all identities and galaxy names, every actual Avenor G01-S007 field, independently calculated distances, cross-galaxy/unknown/secret refusals, byte fingerprints, original statistics and malformed resource/schema/authoring cases. Static checks verify byte preservation and declared field coverage, strict Swift formatting, Markdown lint and whitespace. No compiler, native tests, GUI, renderer or profiling jobs were run by this author; native compilation and focused/full acceptance remain with the integrator after one independent review.

## Remaining integration

The live Universe, Game, commander defaults, markets, equipment, Script content and tutorial selection are unchanged. The eight secret PLUGH worlds are excluded and have no invented coordinates. Actual original-world selection, all-eight-galaxy UI/navigation, new-commander defaults, economic gameplay, secret-world and original mission wiring remain full-goal work. Bundling this resource alone does not establish native gameplay or whole-release completion.
