# Swift 6.1 test compilation stops at two observer-selection expressions

## Observed blocker

Hosted quality for fdc209f1f88000b94e11e9a5d0c1e335b8243a4f passed actual Swift 6.1 production compilation and the mission-pack CLI, then stopped compiling coverage tests. Exact diagnostics are NativeCrimboRuntimeTests.swift:378 and SalvageWorldRuntimeTests.swift:38: the compiler cannot type-check the compound map/first geometry expression in reasonable time. Saved evidence is /tmp/elite-coherent-pr-checkpoint-fdc209f1, raw log SHA256 2b169ddaaeaf6b733c9813c3d6ac45e693f341e8313151705ac8a315d2e2698a.

## Scope and acceptance

Split only these two private fixture expressions into typed candidate generation and ordered distance predicates. Preserve the six directions, native site selection, mapped positions, first-match order, strict 2x-planet / 4x-sun / 1200-station thresholds, short-circuit evaluation and every existing assertion. No production, physics, resource, oracle or fixture-policy change is needed.

G1 owns matching compilation and three representative existing methods / four cases using both helpers, followed by actual hosted Swift 6.1 acceptance. No author execution, runtime probe, full CI replay or renderer media refresh is required for this test-only patch. Companion: [PR-swift61-test-expression-compatibility.md](PR-swift61-test-expression-compatibility.md).

## Actual 1008 exposes two stale native-store assumptions

Matching build 1007 passed. Actual 1008 passed the direct pose/idempotence method (one case); two methods containing three expanded cases recorded nine issues. The damage/cull/save method read legacy wreckMotion, which was nil despite actual energy 4783. Generated alien wrecks use the native alien-storage record; ordinary ticks stage current motion in nativeSalvageWreckMotion and culls publish the parked native record. The old legacy-ledger read cannot witness that authority.

The arrival method saturated the obsolete legacy ledger revision to induce death-publication refusal. Native death settlement instead observes and flushes its native record, bypassing the old markWreckDestroyed guard. Death therefore settled, no dead source remained and arrival/galactic travel continued. The source and actual expected WRECK SETTLEMENT message locate those assertions in the true branch; Swift 6.4 issue events provide no per-argument terminal mapping, so individual case outcomes are not invented. No production defect is established. Preserve all 1008 evidence and the passing method.

## Actual 1010 and native archive path prerequisite

Actual 1010 passed both native-arrival cases. The remaining motion method caught NSPOSIXErrorDomain Code 20 (Not a directory) at function scope; the concrete pathname and throwing call were not emitted. Source tracing shows its direct temporaryDirectory URL reaches native archive openat checks that reject aliases in every ancestor with O_DIRECTORY and O_NOFOLLOW. The existing NativePagedSalvageFixture.folder helper resolves the temporary root with realpath and is already used for native archive saves in this same test file. Reusing that established physical-path fixture is a source-supported correction, not a traced syscall diagnosis. Preserve 1010 failure and its uncertainty.

## Actual 1012 and retained scene custody

The physical-path correction allowed the real archive and cold-record checks to complete without issues. Actual 1012 then found no final wreck body. The old test copied only the loaded commander into a fresh Game, called launch and deleted the new bodies. Native save/load restores world.bodies and its native wreck binding together; activateNearbySalvageSites requires an unbound retained record before it can admit another actor. Commander-only replacement plus scene deletion discards that custody. No production defect is established by this stale setup.
