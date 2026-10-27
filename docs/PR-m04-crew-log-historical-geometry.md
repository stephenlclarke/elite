# Read the original C08 recorder before live showroom resolution

## Change

NativeInductionCrewLogSource.authenticatedRecorder now reads NativeInductionCrewLogHistoricalGeometry.design instead of ShipCatalogue.ship("SH058").design. Its original fixed canonical hash guard remains unchanged. The small helper reads the already shipped SH058.toml once, decodes only its exact id and existing ShipDesign representation, and authenticates the same fixed geometry hash before retaining it. It does not resolve a live hull, generate geometry, change any catalogue policy or use a fallback model.

The decoder reuses TOMLDecoder and the same ShipDesign Codable implementation used by ShipCatalogue.load before activation. Unknown unrelated catalogue fields are not projected into the mission. All encoded ShipDesign geometry, materials, UV/texture metadata and source/license fields remain identical. The typed raw-source id is also checked. Result storage is immutable and prepared once; no per-frame reads, additional whole-CatalogueShip ownership or simulation writer is introduced.

## Source proof and design alignment

Base: `22010f6c67d8e6ddcdaf930ff06a872e492ce83f`. The retained `Resources/Ships/SH058.toml` is byte-for-byte equal to commit `61995c8c`, which originally introduced the C08 source. Resource SHA256: `6f5e4f8dc4a115ed833086199b853e8b5ec9baf1332a90bd44fa9c3d26a571d9`. The current live resolver falls through unchanged for SH058; therefore moving its raw decode before the resolver preserves today's exact source while removing that source lookup's dependency on a later activation.

The fixed authenticated recorder has2352 vertices,1598 faces and six materials; at the unchanged0.2 scale its measured origin radius is6.322963883093118, below16. The model token, recorder hash, fit definitions, actor identity, manifest, permissions, custody, save format and all later source guards are unchanged.

Meridian design authority remains commit `8c899a7e0d351551498b05a7b371b84758575085`, README and implementation/README, SHIP-REFERENCE.md, and canonical missions/gameplay/ships/SH058.json plus models/SH058.json. The original ship is Brabant, transporter, flyable with blueprintFabrication policy. That is a different model from the historical package; it must not inherit this recorder's calibration or mission authority. The new code does not activate it.

## Focused validation and boundary

Four meaningful methods cover raw/full decoder equivalence, unchanged canonical hash and all appearance/texture assignments, exact recorder radius, rejection of vertex/material/provenance/id changes, refusal of the real Brabant model, and original fit/custody/parent invariants. Existing599 selectors remain plus four for603. Local strict formatting, six selector/report fixtures and whitespace/Markdown checks pass. Authored methods are UNRUN until the authorized hosted run; MBA source review is pending. No local Swift compiler/native/GUI/performance/probe/full-integration execution occurred.

ScriptNPCAssets.readNPCModels still uses live catalogue geometry when constructing the C08 bundled pack, and ScriptPack.swift includes it in the digest. An exact shared-loader reservation is still needed to remove that separate future activation dependency. This patch does not weaken or rewrite pack digests and does not claim the whole H058 blocker is resolved. See [the issue note](ISSUE-m04-crew-log-historical-geometry.md).
