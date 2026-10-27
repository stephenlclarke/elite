# Original fleet native models have no isolated showroom resolver

The staged OriginalFleetDefinitionData records preserve specifications and integration blockers, but do not resolve the effective nativeDesign geometry selected by the complete 171-ship delivery index. Existing ShipCatalogue activation would also imply unresolved performance, physics, units and policy decisions. Display access needs a separate read-only boundary before a later player-facing showroom change.

Use the existing ShipDesign Codable, validation and rawMesh path. Preserve the exact native vertices, faces, materials, UVs, winding and provenance; never substitute detailed geometry or infer physical units from dimensions. See [the display-only resolver and validation limits](PR-original-fleet-showroom-models.md).
