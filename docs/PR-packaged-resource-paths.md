# fix(distribution): verify copied script and texture resource paths

The packager looked up copied script-pack and texture files by basename, rejecting a correctly built bundle at `ScriptPacks/generated-couriers/manifest.toml`. `verify_resources` now preserves the relative paths of `ScriptPacks` and `ShipTextures`, matching the existing `Ships` and `MissionPacks` handling and the declarations in `Package.swift`. See [the packaging issue](ISSUE-packaged-resource-paths.md).

## Validation

All 16 distribution Python tests pass, including four new regression methods. The new tests cover flat and `Contents/Resources` bundle layouts, distinct manifests/scripts/textures sharing basenames, missing and changed fixture resources, and rejection of flattened aliases even when their bytes match. Processed legal/model licence files remain flattened. Exact byte verification is unchanged.

The existing pre-fix built-bundle failure was independently reproduced without compiling or launching the game. This source change has not yet been checked against a freshly built signed or notarized release artifact; those remain release gates after the central validation lease is transferred. No native test, full `make ci`, sanitizer, leak, media or Sonar acceptance is claimed here.

## Compatibility and review

No game data, save format, signing, notarization policy or resource content changes. The existing `make homebrew-cask-check` target discovers these Python tests. The combined release PR requires completed clean `@codex review`, final-head checks and a protected merge before publication.
