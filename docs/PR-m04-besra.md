# feat(fleet): port reviewed Besra onto current L337 Redtail source

## Problem and resulting behavior

Current Redtail `b949f2860063a2e3be171350ddd011fe3e4fcb12` lacks Besra. This component ports only the reviewed 28-path delta from `4d69e3d80a380565f777c37619be3b9d9cd0f7a4` to `c8b0375717c53a2d0f79e35826208a5fc44ab5f8`, using the current L337 namespace. It preserves current Redtail, M02 release and corrected M03 source. No old whole tree, resource replacement or additional hull policy is imported. See the [issue](ISSUE-m04-besra.md).

## Complete retained Besra behavior

The adapter's source semantics match the reviewed packet. Require SH108/Besra/besra/bountyHunter/player/blueprintFabrication, valid native performance and approved mesh. Specification `6618c94a78caafe83aabe1e2fd5761b0f16849307e4af82f44cb609cd4d420fe` and metre model `fleet-completion-20261019/batch-04/SH108-design.toml`, fingerprint `ef7d78789eed53b721c6f9417abe5f79a0394613540ff901d8af1fd9c76e13f1`, remain pinned to Meridian `8c899a7e0d351551498b05a7b371b84758575085`.

All 17 native mechanics and all 17 CatalogueShip properties remain. Complete geometry retains 122 vertices, 208 triangular faces, eight materials, 208 material/UV assignments and three textures, with bounds (-11.124,-4.6,-22.09) to (11.124,6.124,14), dimensions 22.248 x 10.724 x 36.09 metres. Only live crew/reserved places change six to one under E01. Equipment capacity stays twelve with its original field; historical Skeet profiles retain six/six/twelve and charter places remain zero. No people, fittings, cargo, discovery, blueprint or hull ownership is granted.

Blueprint fabrication retains technology eight, noncapital access and uncommon natural placement in zero-based galaxies 2/3/4 with deepSpace/tradeLane regions. The catalogue bounty-hunter label assigns no NPC intent, hostility, legal state or hardware. The existing reviewed test uses a valid explicit escort role and checks retained actor facts and native capacities.

## Current-parent composition

Preflight compared all 21 shared Swift parent files with the old parent after only EliteCore/EliteMac to L337Core/L337Mac mapping and standalone formatting. Every file matched; there was no overlap requiring a policy decision. A parent-relative patch adds the existing adapter and five-method test suite, the four shared readiness/physical/player/performance joins and seventeen prior-oracle membership changes. All 23 resulting Swift files match the reviewed head after the same mechanical transformations. Earlier activated hulls, SH025/SH103 geometry and the original unchanged SH108 showroom method retain their assertions. Raw/generated resources, save schemas, mission data and historical baselines remain untouched.

Only the original two selector groups are inserted into the actual current selection. All 559 prior methods and original AST/order/duplicate-key semantics remain. The measured union is 569 methods, and the maintained report-count fixture changes only from 559 to 569. Historical 524/534 and old-lineage 734/739 selectors are not copied or promoted. README receives only the reviewed Besra paragraph after the complete current parent content; these notes describe the new parent and actual selection.

## Validation, review and handoff

The parent Redtail composition is independently source-cleared at `/tmp/elite-g2-redtail-b949f286-current-composition-source-clear.json`, SHA256 `5a17a687cc9e18b2c4836d1b65c82c58b440dfd1e00dab4e96d4ad316185fe72`. This credit does not qualify native behavior. The original Besra/reviewed fleet lineage remains preserved; no historical pass is inherited by the new composition.

Standalone strict Swift formatting, scoped Markdown/whitespace checks, Python AST inspection without project imports or execution, parent/delta/resource hashes and exact selector preservation provide static evidence only. The five Besra methods and five Redtail methods are UNRUN here, as is the 569-method selection. No compiler, test discovery/unit/native execution, GUI, GPU, media, CI, external mutation, push/PR or shared-ledger action occurs. The frozen manifest binds the exact parent, candidate, path hashes, patch and static receipts for independent changed-composition review. G1 owns later focused qualification and actual visual/flight/docking acceptance while M03 delivery remains first.

## Current G1 composition boundary

This retained note records the previously reviewed component. G1 prepares Redtail b949f286 followed by Besra 5f17913d on exact PR297 source `a7b609b4d4842cfcdf6363f1e971aeac7f26e9f4`, tree 1b2032eb. The old parent references above remain historical component provenance. All ten new hull methods and the combined 569-method selection are UNRUN. The running PR297 checks do not qualify this candidate; actual protected-main rebinding, independent composition review and affected execution remain required. Published L337 1.6.0 remains its separate source 05b3 delivery.
