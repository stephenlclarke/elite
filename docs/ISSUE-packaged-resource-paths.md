# Copied script packs and ship textures fail package verification

SwiftPM preserves the relative paths of copied resource directories. The macOS packager already checks `Ships` and `MissionPacks` using that layout, but checks `ScriptPacks` and `ShipTextures` using only each file's basename. Nested resources therefore fail verification even when the built bundle contains their exact bytes. Distinct packs also share names such as `manifest.toml` and `main.lua`, so flattened lookup cannot identify the intended file.

## Evidence and required behavior

On 17 October 2026, the existing built resource bundle at source `e9ee7ef43a5d93776acb698dc9f63a0dd393d643` reproduced `Missing/changed packaged resource: ScriptPacks/generated-couriers/manifest.toml` without a rebuild. This affects the existing bundled schema 2 courier provider before the newly composed ship textures are considered.

Verify all four copied roots at their preserved relative paths, while retaining flattened lookup for processed legal and model licence resources. Preserve exact byte comparisons and support both SwiftPM resource bundle layouts. Missing, changed or incorrectly flattened replacement files must fail.

## Acceptance and compatibility

Pure Python regressions must cover both bundle layouts, duplicate basenames, missing resources, changed bytes and rejected flattened replacements. Actual signed and notarized artifact verification remains a separate release gate. See [the implementation and validation handoff](PR-packaged-resource-paths.md).
