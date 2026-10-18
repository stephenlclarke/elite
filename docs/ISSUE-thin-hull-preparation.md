# Thin hull preparation

## Motivation

The original Tiger Trader (SH127) has a nonzero thin triangle at face 747. Its cross-product length is approximately 0.0000330555858, but preparation requires more than 0.000135746036 because it rejects aspect ratios below 0.000001. This rejects the entire original mesh before held cutting can start. The original human manifest and eight/eight save/reload regression must continue to use this same ship, source geometry and real collision checks.

All three face-747 edges join another face. Removing the triangle changes the surface. Its exact stored decimal cross product is [-0.0000203231, -0.0000248438, 0.0000079012], so it must not be confused with the separately known zero-area source faces. The assembly also has open/nonmanifold components; successful triangle preparation must not imply that those components are closed.

## Required behavior

Accept a source triangle only when outward-rounded arithmetic proves that its area is resolved. Preserve its coordinates, winding, triangle count, component edges and materials. For newly accepted thin or small triangles, distance must be a conservative lower bound and an uncertain ray intersection must remain a boundary/unproven result. Keep the existing strict clearance, continuous sweep envelope, open-component ambiguity and work budgets.

Original three-corner faces need no polygon projection or ear clipping before the common certified area gate. General polygons retain their existing self-intersection and triangulation checks. Zero, unresolved, nonfinite and malformed geometry must still fail explicitly. No hull substitution, fixture filter, source-face removal or clearance override is acceptable.

## Scope and compatibility

This phase changes only hull preparation and its conditioned queries, two existing geometry test files and this issue/PR pair. It changes no ship TOML, importer, save shape, work controller or native manifest test. A static predicate scan of 143219 original triangle faces across 171 definitions found 15 resolved thin faces and six zero/roundoff-collinear faces in the failing class. That scan is not a Swift preparation or all-hull acceptance result. Repairing the six source-degenerate faces remains a separate maintained-source task.

## Validation and remaining gates

Authored tests cover the original 7016-triangle SH127 assembly, scaled/translated/reversed thin triangles, thin closed/open interiors, sphere and exact-player sweeps, continuous crossings, boundary clearance, unresolved/zero/malformed inputs and work-budget refusal. Translation that collapses a thin dimension below the stored Double precision must fail rather than perturb the geometry. These tests have not been compiled or executed by the source author.

Source review corrected the budget test premise before compilation: a zero triangle budget is invalid input and must report invalid motion without queries. Actual exhaustion is exercised separately with a positive one-query budget, a clear first endpoint and a required second endpoint. The test requires evidence of that first real distance/triangle query before the work-budget refusal.

The integrator must compile and run focused geometry tests and the unchanged actual SH127 human eight/eight regression. Numerical conservatism can refuse a genuinely close or unresolved query; runtime success, performance and coverage remain unproven. The required final `make ci` coverage, sanitizers and leaks remain outstanding. Because the ship-media fingerprint includes every Core Swift source, `make ships` and `make ships-check` are required after the combined source freeze even though ship definitions remain byte-identical. Generated media/hashes must not be patched manually.

## References

Source authority is the bounded phase-one geometry allocation on commit `709e6ed23f47f459a6abaaf255a35e8afe54bce3`. The full 171-hull goal and remaining backlog retain their original scope. See [the implementation review](PR-thin-hull-preparation.md).
