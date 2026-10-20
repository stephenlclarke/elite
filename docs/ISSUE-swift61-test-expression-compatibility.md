# Swift 6.1 test compilation stops at two observer-selection expressions

## Observed blocker

Hosted quality for fdc209f1f88000b94e11e9a5d0c1e335b8243a4f passed actual Swift 6.1 production compilation and the mission-pack CLI, then stopped compiling coverage tests. Exact diagnostics are NativeCrimboRuntimeTests.swift:378 and SalvageWorldRuntimeTests.swift:38: the compiler cannot type-check the compound map/first geometry expression in reasonable time. Saved evidence is /tmp/elite-coherent-pr-checkpoint-fdc209f1, raw log SHA256 2b169ddaaeaf6b733c9813c3d6ac45e693f341e8313151705ac8a315d2e2698a.

## Scope and acceptance

Split only these two private fixture expressions into typed candidate generation and ordered distance predicates. Preserve the six directions, native site selection, mapped positions, first-match order, strict 2x-planet / 4x-sun / 1200-station thresholds, short-circuit evaluation and every existing assertion. No production, physics, resource, oracle or fixture-policy change is needed.

G1 owns matching compilation and three representative existing methods / four cases using both helpers, followed by actual hosted Swift 6.1 acceptance. No author execution, runtime probe, full CI replay or renderer media refresh is required for this test-only patch. Companion: [PR-swift61-test-expression-compatibility.md](PR-swift61-test-expression-compatibility.md).
