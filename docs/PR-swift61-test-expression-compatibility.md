# test(compiler): split native observer geometry expressions

## Preserved behavior

The two private helpers still eagerly map all six directions to site.position plus direction times the same distance/offset, then inspect candidates in original order. Explicit Vector3 and Double intermediates separate overload resolution. Ordered guards preserve the original planet, sun, station short-circuit predicates and strict thresholds; a missing candidate still continues the same generated-system loop. Everything outside the two expressions, including every test assertion, remains byte-exact. No production file changes.

## Focused qualification

The nativeArrivalWreckFixture helper has one caller with two cases. salvageWorldGame has eight callers with nine cases; only its representative direct pose and full save/reload paths are selected in this bounded batch. Request these three methods / four expanded cases from G1:

- NativeCrimboRuntimeTests.genuineNativeArrivalSoftRefusalKeepsDriveFuelCargoAndOriginalWorld: false/true, two cases.
- SalvageWorldRuntimeTests.changedActualWreckPoseStillPublishesAndAnIdenticalCaptureIsIdempotent: one case.
- SalvageWorldRuntimeTests.generatedSiteRetainsCanonicalDriftSpinAndDamageThroughCullAndRealSaveReload: one case.

Strict scoped Swift formatting, Markdown lint, whitespace and exact two-expression source checks are author prerequisites. One independent bugs/performance/style delta review is requested. Matching local qualification is pending and cannot substitute for final actual hosted Swift 6.1 compilation. No new mirrored test, timeout waiver, oracle relaxation, production change, CI replay or media refresh is included. No remote PR is created by this author packet. Companion: [ISSUE-swift61-test-expression-compatibility.md](ISSUE-swift61-test-expression-compatibility.md).
