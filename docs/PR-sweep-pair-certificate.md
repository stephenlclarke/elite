# perf(geometry): certify irrelevant pairs inside visited BVH leaves

The dual-BVH leaf loop now checks the actual transformed player triangle box against the immutable target triangle box after its original `work.triangle()` charge and existing whole-row certificate. If both triangles are resolved and ordinary, the current best and its outward squared upper endpoint are finite, and both boxes are finite, an ordinary gap may trigger the existing outward lower-bound calculation. Only a finite certified lower bound greater than or equal to that upper endpoint skips the expensive feature kernel. An ordinary gap alone never excludes a pair.

## Safety and correspondence

For the represented filled triangles A and B, their boxes enclose them. The existing interval calculation gives L <= box-distance-squared <= triangle-distance-squared. The outward square of finite nonnegative best gives U >= best-squared. Thus finite L >= U proves that this candidate cannot improve best. No result is set to clear, no early return is introduced, and best itself is unchanged on exclusion. The query-local transformed triangle's actual represented coordinates supply the box; no old pose, ideal affine transform or previous-query proof supplies authority.

Both `hasResolvedArea` checks and both negative `conditioned`/`unresolvedSupport` checks are explicit. A failed guard, unknown interval, overflow or nonfinite bound falls through to the original feature kernel. Existing collapse/conditioning/support and containment behavior remains untouched. Ordinary floating feature intermediates are not claimed to be bit-identical when the kernel is excluded; public distance, failure and budget parity require the independent regression checks.

Removing the inserted block and substituting `obstacle.triangles[second]` back for the local `candidate` recovers the entire parent production file byte for byte. All existing test bytes remain unchanged; one independent test method is inserted. No Game API, save schema, controls, proof tolerances, deadline, fixtures, traversal ordering, node/query/pair charge, budgets, sampled-motion authority or global cache changes.

## Analytic regression

Two x-separated clusters per mesh each contain eight filled triangles at y=0,20,...140. Player z=0 and target z=10 give exact minimum distance10. Each nonmatching row has y gap at least19, while the whole corresponding leaf overlaps that row in x/y. Consequently the existing matching node/row certificates cannot exclude those pairs. Both source orders retain the same oracle.

The two BVHs each split on x into two eight-triangle leaves. Per query, root then two player/root pairs then four leaf pairs give seven popped node pairs, two charges each. Two matching leaves each retain 64 paid primitive examinations. Three stationary samples therefore require exactly384 paid pairs,42 node charges and3 queries. A383-pair budget must genuinely fail with `workBudgetExceeded`, rather than being forgiven by feature pruning. Source geometry establishes the count independently of the new certificate; executor verification is still required.

Each matching leaf contains eight matching-row pairs and56 pairs whose boxes have an additional y gap. After the first finite best is established, those off-row pairs can skip their feature kernels while remaining paid. This suggests48 full kernels instead of384 across the three samples for this fixture; it is a structural source claim, not an instrumented count or measured scene speedup. No test-only feature counter was added.

The same fixture checks that required clearance10 fails the existing continuous numerical-headroom proof at depth0 with `unproven`, while9.999 retains sufficient margin. Existing90-pair/18-node row-certificate,191-pair exhaustion, overlap/crossing, outward-transform, collapse, thin/support and overflow tests remain unchanged.

## Validation and limits

Author validation is source correspondence, strict Swift formatting, Markdown lint and whitespace checks only. No author compiler, native, runtime, test, ABI, harness or profiling job was run. G1 owns one independent review, coherent build, the existing ten scalar-reuse parity cases and `HullSweepPlacementTests.dualBVHPairCertificateRetainsAnalyticDistanceAndAllPaidExaminations`. Any failure must be investigated without relaxing existing assertions or tolerances.

Retained continuation555 passed its historical second release, while matched scalar-reuse intervals showed no clear performance gain. This leaf claims neither fresh original acceptance nor sufficient600-second headroom. The actual salvage scene's pair exclusion frequency and net timing remain unmeasured, and the extra bounds work may offset avoided feature work. Root allocates any later matched performance execution only after review/build/parity success. No automatic runtime or full-CI allocation is included in this source handoff.

## Subsequent composed validation

The integrator independently reviewed and compiled the composed repairs. Fresh original run 558 passed in 551.180 seconds within its unchanged 600-second ceiling, with zero issues, original assertions and all trace/continuation flags off. Earlier run numbers above remain historical evidence. See the [composed validation report](COMPOSED-NATIVE-VALIDATION.md) for exact scope, digests, focused checks and full-gate/release requirements.
