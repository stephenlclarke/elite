# PR handoff for issue186: affine debris clearance

## Resulting behavior

The proposed native clearance calculation retains one shared time variable when projecting a linear relative trajectory onto a separating axis. It can prove the thin diagonal gap without widening X, Y and Z independently first. It changes neither the physical movement nor the allowed clearance.

## Implementation

Keep `translatedTrianglesClear`'s original conservative BVH bounds. At each existing leaf axis, project the constant local triangle vertices and add `relativePosition.dot(axis) + relativeVelocity.dot(axis) * time`. Every operation still uses the outward interval operators. All original triangles, axes, tolerances, numerical guards, work budgets and refusal/authority checks remain.

Add a directed rotated-box regression with a positive 0.00001 gap throughout diagonal translation, both pair orders and zero/large common world offsets. Keep the actual -3000 debris/NPC case and its momentum, health, reward and custody assertions. Normalize the two selected-hull resource fixtures and isolate the bounded ore-admission timeout by deferring only the existing ambient director's next decision.

## Validation

Independent actual-hunk review and the focused normal follow-up are pending. The earlier source6423 batch compiled and completed 135 methods: 131 passed, four failed with six issues. All 62 originally failing methods completed, with 60 passing. The [durable receipt](evidence/M01-authored-fixture-unit-results.json) records each actual timing and status. The new candidate has not run and is not a passing release claim.

## Links and remaining risks

[Issue186](https://github.com/stephenlclarke/elite/issues/186), [PR25](https://github.com/stephenlclarke/elite/pull/25), and the paired [issue note](ISSUE-186-affine-debris-clearance.md). The focused follow-up must include the four failed methods and directly affected contact/fragmentation consumers. Full required CI, main-only SonarQube, review and protected release gates remain required. Issue185 remains an independent unknown-cause SIGBUS; the source6423 normal batch did not reproduce it.
