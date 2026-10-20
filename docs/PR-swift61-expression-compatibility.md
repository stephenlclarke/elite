# fix(compiler): decompose expressions for Swift 6.1

## Changes

Both texture loaders use explicitly typed UInt32 channel shifts and a reserved output loop. Byte order remains R in bits 31...24, G in 23...16, B in 15...8; archival textures force alpha 255 while original textures retain the authenticated fourth byte. All file-size, dimension, digest, alpha and binding checks remain exact. No native-endian memory load is introduced.

ContractBoardDisplay preserves its distinct issue and row-summary precedence with short lazy fallback groups. ScriptContractPageInput preserves detail-only review evaluation and the exact repair/cold/provider/people/finance/RRS/ordinary/fallback priority. MissionGallery appends the same strings in the same order. ScriptCampaignGallery appends the same seven proof fields in order. ScriptNavigationTradeRuntime builds the same accounting text in ordered pieces. Game changes only the native-save diagnostic bit-expression to four UInt16 intermediates with the same predicates and 1/2/4/8 values; admission and error behavior stay unchanged.

## Validation selection

One G1 matching build and these nine existing methods (eleven expanded cases) are requested; every source dependency is the frozen base plus this ten-path patch, including unchanged tests and bundled resources:

- ShipTextureAssetsTests.selectedSourceBindingsSurviveMeshNormalizationAndPlayerScaling: one case.
- ShipTextureAssetsTests.sourceCachesRejectAnAlteredManifestDigest: one case.
- OriginalShipTextureAssetsTests.pinnedOriginalPixelsLoadThroughExistingRendererLookup: one case.
- galleryResponsiveMasterDetailAndPointerSelectionKeepTextInsideBounds: one case.
- campaignGalleryProofDistinguishesPreviewAliasesAndStaysCompact: one case.
- courierContactRendererUsesTypedActionsAndKeepsCompactWideBounds: two cases, data/package.
- OriginalContractOfferPolicyTests.originalReopenClockPauseDeclineAndPageFactsStayStable: one case.
- scriptRefusalObservationPreservesNativeAndStoreValidationRefusals: one case.
- navigationTradeActualLossColdRestoreAndReceptionRetainExactAccounting: two cases, false/true.

Author prerequisites are strict scoped Swift formatting, Markdown lint, whitespace and exact owned-path/hunk checks. No author compiler, test, benchmark or full CI execution occurred. One independent bugs/performance/style review is requested on the complete frozen batch. Local Swift 6.4 qualification is explicitly distinct from final hosted Xcode 16.4 / Swift 6.1.2 acceptance; that hosted check remains required after G1 integration. No thresholds, toolchains, frameworks or CI checks are waived.

## Compatibility and remaining risk

No public API, saved format, resource or test changes are included. Ordered String/Array appends replace compound concatenation; texture loops retain one preallocated result and the same byte-wise arithmetic. Native actor ownership and isolation remain unchanged. Actual older-toolchain compilation is pending, so the author packet does not claim the release blocker is cleared. Companion: [ISSUE-swift61-expression-compatibility.md](ISSUE-swift61-expression-compatibility.md).
