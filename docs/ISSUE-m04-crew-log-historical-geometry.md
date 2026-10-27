# Preserve the C08 recorder independently of live Brabant activation

## Problem and authority

The published canonical base is `22010f6c67d8e6ddcdaf930ff06a872e492ce83f`. NativeInductionCrewLogSource.authenticatedRecorder reads the effective live SH058 design. That record is currently the retained Hauler, but the approved Meridian SH058 is Brabant. A future legitimate showroom activation would change this lookup and fail the C08 recorder's existing canonical geometry hash.

The recorder must retain hash `5362f0948c8a6f1b2acc770b100f746ff3f55799db7c0c53261f02943c6a680e`, model `catalogue:SH058`, scale0.2, actual radius no larger than16, existing fits, ownership, permissions and save representation. This prerequisite does not activate Brabant or change any physical hull calibration.

## Existing historical source and bounded scope

`Sources/EliteCore/Resources/Ships/SH058.toml` is byte-identical to the recorder's original source commit `61995c8c`; full resource SHA256 is `6f5e4f8dc4a115ed833086199b853e8b5ec9baf1332a90bd44fa9c3d26a571d9`. ShipCatalogue.load already decodes this resource before OriginalPlayerHullActivation.resolve chooses a live adaptation. Reuse that existing retained geometry; do not create an asset, geometry copy or new calibration.

Only the C08 source lookup, a small C08-specific read-only decoder/authenticator, four focused methods, additive selector/count and paired notes are owned. MC1's H056 geometry work, fleet registries, main/current M01, actor state, schemas and release files are excluded.

## Remaining shared-loader boundary

ScriptNPCAssets.readNPCModels also resolves catalogue references through the live showroom. ScriptPack.swift includes the resulting canonical model bytes in the pack digest. The current C08-only scope removes its direct source lookup dependency but cannot by itself preserve bundled loading after a future live SH058 change. Root must separately reserve an exact C08 catalogue-reference loader hook, or assign that dependency to the future activation owner. Do not claim that all SH058 activation blockers are removed by this source-only slice.

## Acceptance

Prove exact raw-decoder equivalence and original hash/appearance/radius/fit, strict refusal of altered geometry/provenance/source identity, independence from the actual approved Brabant model, and unchanged C08 ownership/custody. Four methods are authored; hosted Swift execution and independent bugs/performance/style review remain pending. No native journey, compiler, GUI, probe or broad test run is assigned.

See [the implementation note](PR-m04-crew-log-historical-geometry.md).
