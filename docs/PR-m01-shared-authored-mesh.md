# Share authored salvage mesh storage with the raw cache

## Change

The existing raw mesh cache now reuses `SalvageCatalogue.profile(...).mesh` for its 37 ordinary salvage hulls. This removes their second vertex conversion and any second outer resolved face-texture array once both inventories are initialized. The lookup follows the unchanged SH061 physical-contract branch; every other ID retains the original `ship.design.rawMesh` fallback. The profile constructor, EMP disabled profiles, winding, materials, texture validation and immutable Swift 6 ownership remain unchanged. [Source problem and corrected inventory](ISSUE-m01-shared-authored-mesh.md).

The initialization graph is raw cache to ordinary profiles to already resolved catalogue records and raw design conversion. Profile construction does not request the raw cache. Texture loading has no reverse cache or salvage dependency. No direct initialization cycle was found in source. Native cold initialization and concurrency remain untested.

Profile-only paths do not initialize the full fleet cache. Raw-cache-first paths now construct 37 profiles' metadata and scratch buffers earlier, which can increase early churn or the raw-only peak. The change does not claim universal peak improvement, attribution of the diagnostic's heap increase, measured RSS savings or sufficient fit. The corrected active inventory is 90,741 vertices/79,168 faces and 2,177,784 bytes of vertex scalar payload only; resolved SH012/SH019 original models replace their packaged TOML designs.

## Regression assertions

The existing `actualMeshBoundsMaterialsAndFaceWorkGeometryRemainUnnormalized` method keeps every prior assertion and its Test ID. It compares profile and cached meshes with the independent resolved `ship.design.rawMesh` oracle across all 37 entries: vertices, faces, details, materials, material assignments and full texture/UV mappings. Nonempty vertex-buffer addresses must match between each profile and cached mesh to verify sharing.

Private helpers in the same method check SH012/SH019 against their authenticated original models, including their active geometry counts and original texture mappings. They also compare the SH061 cached mesh with the physical contract and its EMP disabled profile with the unscaled authored mesh. The original SH061 physical-first branch and fallback remain unchanged. All other test methods, selectors, cohorts, fixture searches, assertions, instrumentation, diagnostics and internal concurrency remain intact.

## Validation and handoff

Focused source and offline model checks accompany the frozen packet. These check the corrected activation routing and inventory, immutable alias routing, unchanged SH061/fallback branches, preservation of old assertions and Test IDs, and intentional mutations. They are not Swift execution or memory measurements. Scoped Markdown lint and whitespace checks are recorded with the packet.

The strengthened Swift assertions and `make ci` are **UNRUN** under MC1's source-only assignment. This packet remains in development/validation pending. Root routes independent bug, performance and style review of the frozen code. G1 owns the existing native lease and must compile the exact composed source, execute the relevant actual tests and required unchanged cohorts, and return passing evidence before integration handoff. MC1 must close actual findings.

No native execution, process/resource probe, sanitizer option or budget change, operator policy/session/proof mutation, publication or release was performed. Preserve the previous diagnostic source, failed raw data and used execution counter. Any new preparation needs its own exact committed source and reviewed bindings. Full required ASAN/TSAN, normal coverage, leak, final PR checks/review, protected merge, exact-main Sonar and usable release gates remain required.
