# Original degenerate source supports

## Motivation

Five exactly collinear source triangles and the tiny nonzero Whitetail sliver prevent preparation of their complete original ship assemblies. SH038 face 13 comes from the pinned ADCK Eagle Mk II. SH066 faces 1752, 2090, 2296 and 2634 are two authentic copies of BBS rotator source faces 2 and 340. SH154 face 148 is already tiny and noncoplanar with its neighbour in the pinned source DAT. Dropping, moving or remeshing these faces would either change source support or require additional provenance and appearance remaps.

## Required behavior

Retain every original finite three-vertex primitive as its complete convex support. This is exactly the filled triangle when nonzero, or its segment when collinear; it is not a replacement of the whole hull with a convex hull or box. A tiny nonzero triangle must not be approximated by only its edges. Preserve all 171 raw definitions, source face indices, appearance, saved work profiles and the actual SH127 human manifest/eight-plus-eight regression.

A mixed mesh can retain unresolved supports alongside certified surfaces. An entirely unresolved standalone mesh still fails preparation. Finite coordinate, index, exact-weld duplicate, polygon, geometry complexity and query-budget guards remain. An all-unresolved component cannot acquire closed-volume eligibility merely because its edges have two incidences. Open or uncertain containment remains unproven.

## Scope

The source-only implementation changes `HullSweepSafety.swift`, its existing safety/placement tests and this unique issue/PR pair. It changes no importer, TOML, UV/material mapping, schema, native work controller, resource, writer or actor state. The earlier producer seam-repair proposal remains preserved for comparison; no source-face cull or producer repair is applied here.

## Validation and remaining risks

New authored tests retain all six original faces, supply a future genuine 171-definition preparation inventory, prove useful exterior clearance for original segment/sliver supports, and reject segment crossings, filled-interior misses and false closed-volume authority. They exercise exact-player and sphere paths, BVH traversal orders and a genuine closed cube with a retained zero seam. Existing malformed/standalone-degenerate, concave thin-bridge, positive-budget exhaustion and SH127 tests remain intact.

Only formatting, lint and bounded source/hash/inverse checks are authorised for this author. No compilation, discovery or execution is claimed. Conservative bounds may refuse some close or ill-conditioned queries; query cost, actual all-171 preparation, native holding/collision behavior, historical compatibility, coverage and sanitizer/leak gates remain pending. The integrator owns the live compile/runtime lease and must run one authoritative `make ships` after the reviewed combined Core freeze, then `make ships-check` and the required `make ci` gates. No generated image or hash is hand-patched.

## References

The source allocation is based on canonical `3102d89ffc2df6cbf2665c376af29e621fd91678`. The retained source-lineage and convex-support proposals are planning evidence, not native execution. The full all-171 and existing backlog scope remains unchanged. See [the implementation review](PR-degenerate-source-support.md).

## Transformed-query cost correction

Independent source review found eager full interval-area construction in every transformed player triangle. Separate the one-time preparation certificate from a bounded selected-component transformed certificate, preserving full fallback for any uncertainty or represented collapse. This is a source-proven added-work correction, not a measured regression or attribution of procurement run 380. Ordinary rigid transforms, near-collinear contact/exterior and actual large-coordinate collapse/refusal require regression coverage and later execution.

## Collapsed-transform test premise correction

The collapsed-transform regression retains the standard subdivision budget, original pose/vertices, collapse precondition, positive sampled-distance oracle and actual `unproven` refusal. With zero motion and large retained numerical headroom, the proof attempts further subdivisions after its endpoint/midpoint checks; the test therefore requires more than three charged distance queries and positive triangle work rather than incorrectly expecting exactly three queries. This is a source-only expectation correction, with no production, budget, case-count or certification change and no measured execution result.

## Reduce repeated larger-player collision work

The retained single run-380 sample places active stacks in `meshDistance` and `triangleDistance`; recursive sample counts are not CPU shares or a measured regression. The existing outer loop transforms every player primitive and walks the target tree separately. For larger player BVHs, original node-pair traversal can defer transformations and prune spatially separated groups using outward-enclosed actual pose operations and certified box gaps, while retaining all original supports and current charges/budgets. Small-player traversal and both component-containment loops must stay intact. Analytic same-budget near/far work, conservative negatives, real exhaustion and transformed uncertainty require regression coverage before any genuine native performance comparison. No speedup is inferred from source structure alone.

## Direct dual-leaf crossing coverage

Add one test-only large-player/small-target regression whose genuine filled triangles cross on `x=0,z=0,y in [-10,10]`. The player retains its crossing primitive plus eight separated far primitives, while the target retains one horizontal triangle. Every player component representative has nonzero z outside the target's z=0 bounds; the target representative has x=-10 outside every player's nonnegative-x component bounds. Both winding variants preserve these first vertices. The original containment loops therefore cannot supply the refusal: the test requires actual charged node/primitive work, first-query `clearanceViolation` and zero sampled clearance. Standard budgets, production code and earlier 189 source cases remain unchanged; this is regression-coverage improvement, not an executed result, demonstrated kernel defect or performance claim. Combined newly authored source cases are 190.
