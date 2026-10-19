# perf(geometry): reuse immutable scalars in exact sweep fast kernels

`SweepTriangle` retains two additional private scalar values computed from its own represented vertices. `fastNormalLength` stores the existing `area` result; `fastRayDeterminantScale` stores the original left-associated `1e-12 * firstLength * secondLength`. Construction's existing edge-length calculations are named once and reused. Prepared triangles remain immutable, and each already-cached transformed triangle computes these values from its actual transformed coordinates, never from an old pose or a previous query's clearance.

The fast ray guard now multiplies the stored determinant scale by the current ray direction length. Its threshold, association and comparison are identical to the original expression. The point-triangle fast path reuses the same local projection dot product and divides by the stored normal length. `Vector3.length` is exactly the square root of the same left-associated three squared components used by `normal.dot(normal)`, so this is the original square-root result, not a reciprocal, approximation or reassociated quotient.

Conditioned, unresolved-support and outward-interval paths are unchanged. Cached scalars are arithmetic inputs to the existing fast kernels, not area, support, separation or continuous-motion certificates. No node or triangle charge moves, no query or sample is skipped, and no BVH ordering, pruning, bound, clearance, guard, budget or acceptance predicate changes. No Game state, schema, global/cross-frame proof cache, geometry authority or tool/control/work behavior changes. The only new storage is two `Double` fields per private triangle instance.

## Parity and validation

Reversing the scalar substitutions and removing the two fields recovers the entire prior `HullSweepSafety.swift` byte for byte. The proof explicitly expands the cached edge lengths and preserves `(1e-12 * edge.length) * other.length * direction.length`; it rejoins the repeated point dot product and the exact normal square root. Every conservative branch and all outward interval source remain byte-identical after that expansion, including malformed, overflow, collapse, thin support and budget refusal.

Use the existing independent analytic and geometric regression cases rather than a new test that merely mirrors the cached formulas:

- `hullSweepRetainsAnalyticFaceEdgeAndCornerDistancesForBothWindingDirections`
- `hullSweepExactPlayerMeshUsesPrunedTrianglePairsAndTestsContainmentBothWays`
- `hullSweepThinOpenInteriorAndRayBoundaryStayConservative`
- `hullSweepPreparedRawCapitalGeometryHasBoundedNativeStepWork`
- `HullSweepPlacementTests.ordinaryExactPlayerRigidTransformsRetainUsefulSurfaceClearance`
- `HullSweepPlacementTests.nearCollinearExactPlayerTransformRetainsConservativeContactAndExterior`
- `HullSweepPlacementTests.representedRigidTransformCollapseKeepsActualNumericalUnknownRefusal`
- `HullSweepPlacementTests.dualBVHReportsActualPrimitiveAndTwoNodeChargeExhaustion`
- `HullSweepPlacementTests.dualBVHOverflowEnclosureCannotPruneAnInfiniteBestIntoClearance`
- `HullSweepPlacementTests.dualBVHRowCertificateReducesPaidPairsWhenBothPlayerLeafBoxesOverlapTarget`

These cover independent distance oracles, real dense geometry, fast/conditioned support, represented numerical failure, exact charged exhaustion and the 90-pair/18-node row-certificate result. The existing capital case also retains its bounded-step timing output; its aggregate timing is not a native-stage performance or acceptance claim.

Author checks are source correspondence, strict Swift formatting, Markdown lint and whitespace checks. No author compiler, runtime, test or profiling job was run. G1 owns one independent review/coherent build and the selected meaningful parity checks. No new continuation or original 600-second run is authorized by this source leaf.

## Practical limits

For a fully visited nonconditioned triangle pair, the six edge-ray calls previously repeated up to twelve immutable triangle-edge square roots. Interior vertex queries can additionally repeat the normal square root and projection dot product. This leaf removes those source-proven operations; it does not predict a measured frame-speed percentage or sufficient original deadline headroom. Existing 499 samples and 539 query counts establish the relevant code path, not current post-change timing.

Run 552's last recorded hot progress, its timeout, the saved pre-loop stage and original 542's unknown terminal remain separate facts. This precision-preserving computation reuse does not turn either diagnostic into acceptance, infer a later release, or justify blaming per-frame native disk persistence. Any later owned execution needs its own allocation and actual results.
