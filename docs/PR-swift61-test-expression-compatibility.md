# test(compiler): split native observer geometry expressions

## Preserved behavior

The two private helpers still eagerly map all six directions to site.position plus direction times the same distance/offset, then inspect candidates in original order. Explicit Vector3 and Double intermediates separate overload resolution. Ordered guards preserve the original planet, sun, station short-circuit predicates and strict thresholds; a missing candidate still continues the same generated-system loop. Everything outside the two expressions, including every test assertion, remains byte-exact. No production file changes.

## Focused qualification

The nativeArrivalWreckFixture helper has one caller with two cases. salvageWorldGame has eight callers with nine cases; only its representative direct pose and full save/reload paths are selected in this bounded batch. Request these three methods / four expanded cases from G1:

- NativeCrimboRuntimeTests.genuineNativeArrivalSoftRefusalKeepsDriveFuelCargoAndOriginalWorld: false/true, two cases.
- SalvageWorldRuntimeTests.changedActualWreckPoseStillPublishesAndAnIdenticalCaptureIsIdempotent: one case.
- SalvageWorldRuntimeTests.generatedSiteRetainsCanonicalDriftSpinAndDamageThroughCullAndRealSaveReload: one case.

Strict scoped Swift formatting, Markdown lint, whitespace and exact two-expression source checks are author prerequisites. One independent bugs/performance/style delta review is requested. Matching local qualification is pending and cannot substitute for final actual hosted Swift 6.1 compilation. No new mirrored test, timeout waiver, oracle relaxation, production change, CI replay or media refresh is included. No remote PR is created by this author packet. Companion: [ISSUE-swift61-test-expression-compatibility.md](ISSUE-swift61-test-expression-compatibility.md).

## Selected-method native-authority correction after 1008

Only the failed save/reload method now joins its generated native source and original actor, observes actual staged native motion after the ordinary tick, reads the actual parked native record after culling, and checks the native record after ordinary Save/load. The same drift, spin, damage, cull, rebinding, pose and reload comparisons remain. Additional assertions bind native record identity/owner and prove the legacy ledger remains unchanged. No motion is fabricated or extra flush forced.

Only the arrival method's true-branch refusal setup now saturates current native snapshot worldRevision to UInt64.max while preserving owner, native world, commands, sources, attachments, upgrades and receipts. The snapshot passes native validation and replacement; the installed max revision and actual existing replacingNativeWorld arithmeticOverflow guard are required before killing the authentic generated body. All existing dead-source, unsettled-refusal, exact commander/body, drive, fuel, cargo, flight-state and message assertions remain. The invalid-angular false branch is unchanged. No production code or shared helper changes.

Request one independent child-delta review and G1 matching build followed only by the two previously failed methods / three expanded cases. Retain the direct pose/idempotence method's actual 1008 pass through unchanged dependencies. This does not claim all consumers passed, or infer per-argument outcomes absent from events. Actual final-head Swift 6.1 hosted acceptance remains pending. Source diagnosis receipt: /tmp/elite-g2-swift61-test-expressions/CAUSAL-DIAGNOSIS-1008.json.

The child review identified that native rebinding permits sub-1e-8 pose rounding. The exact cold-load motion comparison therefore uses the actual post-rebind native record; original tolerant parked-pose comparisons remain unchanged. The rebound record is also joined to the original native ID and actual returned actor. This preserves persistence precision without rejecting allowed coordinate reconstruction.

## Small selected path correction after 1010

Only the motion method's save-path setup now uses NativePagedSalvageFixture.folder(), a commander.json child and owned whole-folder cleanup. This preserves the existing realpath-based physical temporary root and cleans the native archive sidecar with the save. No native archive validation, ordinary Save/load, motion/energy/identity/rebind/cold-load assertion, shared helper or production source changes. The precise 1010 throwing call/path remains unknown; one small source-delta review and G1 matching build / only this method's one case will qualify the correction. Retain the actual 1010 arrival two-case pass and 1008 pose one-case pass through unchanged dependencies.
