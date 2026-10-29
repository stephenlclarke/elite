# Reuse immutable target arithmetic for three vertex queries

Prepare the target edge basis once for the existing three-point fast query, and prepare its certified interval basis once for the conditioned query. Use identical represented vertices and operation grouping; keep every point-dependent projection, clamp, comparison, conservative fallback and minimum update.

Generic single-point helpers and unresolved-support fallback remain unchanged. No traversal, transform, certificate threshold, geometry, work budget, state, hull field, authority or public API changes.

## Validation

MBA formatting, strict lint and whole-source inverse checks pass; copied hashes, ASCII, Markdown lint, diff and exact scope are checked at freeze. No author native job or new test runs.

G1 owns these existing eight methods and eleven cases:

- hullSweepRetainsAnalyticFaceEdgeAndCornerDistancesForBothWindingDirections
- hullSweepExactPlayerMeshUsesPrunedTrianglePairsAndTestsContainmentBothWays
- hullSweepDualBVHPreservesConcaveEmptyNotchAndSolidArm
- hullSweepRefusesUnprovenIntervalsAndExhaustedBudgetsWithoutEndpointApproval
- hullSweepResolvedThinClosedHullPreservesWindingAndInteriorRefusal: two cases
- hullSweepThinOpenInteriorAndRayBoundaryStayConservative
- hullSweepConcaveThinBridgeCannotHideInsideBroadArmBehindMergedCrossings: three cases
- hullSweepControllerRetainsItsParentAndAppliesOnlyPhysicallyValidatedBraking

One complete three-path independent review follows actual owner PASS. Removing repeated arithmetic is source-proven; runtime benefit and full mission success remain unmeasured.

## Actual qualification

Matching public compilation1252 passes. Actual1253 passes all eight selected methods and eleven declared cases in0.315seconds (runner5.104973seconds, supervisor6.816779seconds), with zero issues or unknown outcomes. All twelve observed owned starts close naturally; source, preferences and2010 target artifacts remain exact. Complete independent three-path review is CLEAN (`20f98eaf06e8989d20e259298c0c893d8335e15171a974be5eb4064ff06ffd12`); exact reviewed files integrate at `9f6816d98443b245f128951e2eff479f61076223`. This does not qualify G12 or establish a runtime speedup.
