# Approved original-world data foundation

The approved original-world proposal contains 2,048 ordinary worlds across eight named galaxies, but native game code has no bundled, checked adapter for those records. Reconstructing them through the old universe generator or coordinate conversions would lose the approved names, Cartesian LY positions and authored metadata.

## Required behavior

Retain `catalogue.json` and `authoring.toml` byte for byte with dated provenance and SHA-256 fingerprints. Expose immutable Sendable records for all 29 world fields and the complete authoring configuration. Validate schema, finite values, approved bounds, unique identities/names, 256 ordinary systems in each galaxy and preserved statistics. Distances use actual Euclidean Cartesian light-years and explicitly refuse different galaxies or unknown identities.

## Delivery boundary

This is a read-only resource and adapter. It does not select the live universe, change commander defaults, install economy/equipment policies, modify markets, enable tutorials or replace mission content. Eight secret PLUGH worlds are outside the ordinary catalogue; their coordinates are not invented here. Subsequent secret-world wiring, all-eight-galaxy UI/navigation, new-commander defaults, markets, equipment and original mission integration remain required for the full original-universe goal.
