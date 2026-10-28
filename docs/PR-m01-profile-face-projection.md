# Project profile faces directly from their indexed mesh

## Change and equivalence

Only the per-face projected Vector3 array and its consumers change in `makeProfile`. The first three values come directly from the immutable mesh. Midpoint reduction starts at the same zero, adds the same values in the original index order and multiplies by the same count reciprocal. Repeated and closing indices remain repeated. Radius calculation still builds the same ordered Double array and calls the same Array.max. [Source problem and limits](ISSUE-m01-profile-face-projection.md).

The original count and full-index guard runs before every indexed read, including invalid later indices. The first-three subtraction/cross order, strict `> 1e-8` guard and normal expression remain exact. Degenerate-first-three faces still skip even if later vertices could form a triangle. No tolerance, finite-value policy, reassociation or handwritten maximum is introduced.

Everything outside this face hunk remains unchanged: mesh acquisition, SH061 scale, eligibility, materials/textures, bounds and whole-mesh radius maps, Face enumeration, section filters/fallback, comparator and index tie policy. Equal ordered Face values feed the same selection code. No cache, lock, actor boundary, product API or diagnostic hook is added.

## Regression assertions

The existing resolved EMP helper now calls a private selected-section oracle using its already independent `ship.design.rawMesh`. It validates each section's source-face index and indices, then uses the old materialized Vector3-array formula for cross, midpoint, normal and radius. Exact geometry comparisons supplement all previous mesh, storage, ID, role, scale, game-nil, original-texture and SH061 assertions. The ordinary 37-profile face/work oracles remain intact.

Every previous test statement and assertion stays in order. Test IDs, the 63 checkpoint calls, selectors, whole cohorts, internal concurrency, instrumentation, options and 225 worker plus reserve remain unchanged. The extra oracle processes only selected sections and retains no collection across iterations or unsafe pointer. Its allocation/time cost can shift a later guard failure.

## Focused validation

Four source/model checks pass. The independent old-array and indexed Python projections compare 222,875 faces across the 37 ordinary and 132 disabled source candidates, including 222,869 accepted model faces and 1,521 selected model sections. Ordered component and radius-input bit patterns match. Twenty-three synthetic cases cover invalid/short/later-invalid indices, repeats, closing vertices, degeneracy, cutoff boundaries, cancellation, asymmetry, facing fallback, equal scores, signed zero, nonfinite values and overflow. Five deliberate guard/order/drop/threshold faults are detected.

The model uses declared common reference selectors; it does not execute or certify Swift Array.max or section-max semantics. The source proof retains the identical ordered inputs and unchanged Swift selection operations. Candidate/model counts are not native constructed-profile counts. Exact source stripping restores all original assertions, operations, Test IDs and checkpoint code, with the rest of production byte-identical. Scoped Markdown lint and whitespace checks accompany the packet.

## Required handoff

Actual Swift compilation, selected-section/full-mesh assertions, compiler behavior, allocation effect and `make ci` remain **UNRUN** for this packet. It stays in development/validation pending one independent source review and G1's separate fresh-source execution authority. MC1 must close concrete findings and obtain passing focused native evidence before integration handoff.

No native build/run, profiler, resource/process probe, operator policy/session/proof write, publication or release was performed. Preserve prior failed source/raw data/counters. Full ASAN/TSAN, real coverage, leaks, final-head PR review/checks, protected merge, exact-main Sonar and release gates remain required. Diagnostic-on observations do not qualify ordinary gate-OFF execution.
