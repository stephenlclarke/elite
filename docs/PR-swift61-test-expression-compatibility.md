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

## Complete final cold-scene and readmission correction after 1012

The selected method now loads the ordinary archive into a fresh GameRuntime and checks the actual restored body against its retained native binding, energy, spin and original pose tolerance. It preserves the loaded Game instead of discarding its authenticated scene. Ordinary Game.dock runs persistSalvagePoses and flushNativeSalvageMotion(parkingSystem:) before clearing bodies; the test requires the resulting parked native record with unchanged energy, logical identity and legacy ledger. Ordinary launch then enters a new visit. The existing observer placement and activateNearbySalvageSites perform real source-backed admission, with all original final energy/spin/pose checks intact plus a new actor/current-visit binding to the same original native source, ID and owner.

No body injection, direct binding edit, forced flush, mocked load or relaxed tolerance is included. Docking is used as the existing scene-parking boundary; this test does not claim a physical main-station arrival receipt. Every remaining cold-restore/admission assertion was traced as part of this complete selected-method migration. One independent correction review and G1 matching build / only this motion case are pending; retain the other three actual passing cases and all earlier failed evidence.

## G1 selected qualification and retained failures

Matching1007 currentSwift6.4 build passed, then actual1008 passed the pose-publication/idempotence method (one case) and failed two methods/three expanded cases with nine issues. Source diagnosis found obsolete legacy-motion observations and a legacy revision-overflow setup bypassed by the current native store. The selected method corrections use actual hot/parked/cold native records and validated native-world revision overflow while preserving physical/refusal/original-state oracles. One review P2 corrected exact cold comparison to the actual post-rebind record, retaining parked pose tolerances.

Matching1009 and actual1010 passed the native-arrival method's two cases; the sole motion case then caught POSIX20 ENOTDIR. Its precise throwing path/call was not emitted. A source-supported correction uses the existing resolved native temporary-folder helper and child file, preserving archive security and persistence checks. Matching1011 and actual1012 reached the cold-record checks but failed at the final body admission: the test copied only the commander, discarded its authenticated scene and cleared bodies while retaining the native binding. Complete selected-method reconciliation preserves the loaded scene, exercises ordinary dock parking, then launch/new-visit and actual native re-admission; no injected body/direct binding edit/forced flush or physical docking receipt is claimed.

Matching1013 passed; actual1014 ran only the motion case and passed through the last oracle in10.473seconds, zero issues/unknowns. Aggregate selected qualification is three methods/four cases (1008pose1 +1010arrival2 +1014motion1), not a single all-pass run. Exact dependency proofs preserve the retained passing methods and shared helpers/resources/product bytes. The salvage helper's other callers are not a qualified whole family. Original1008/1010/1012 failures and immutable raw values remain retained, without invented per-argument issue/end pairing.

Every runtime run retained all1,945 artifacts, tracked inputs and primary preferences exactly and independently closed its actual owned starts without timeout/cleanup. Final1014 closed13 starts and released its lease. Proof SHA256 `1ad51de517832d880821a1bf172ac45bf4173cd35aea6cdcbc66a23eaf33c568`; closure SHA256 `46dcc8349caec33e38058ccfcf87c944300b206a4343c33db16e6b0a3be9be4f`. Full expression review SHA256 `ef13141f90c684f3aab22cb877516600025a1f66c5f9c4c5836e835599b1038d`, native fixture review/closure SHA256 `9f0d54dcd331d8d8157dc84f4b65b7723f3b4d507c422dba79ba00a073e71269`, path delta SHA256 `4865e4766fe3da3ff7acc76cd1f130d8866585b8bcb87d1fcc89ebedff21821a` and complete motion-method review SHA256 `70cd36acb698c311a8d857a4ad1f0279974c6ae1a99e72c6730904c537252869` are CLEAN.

The previousfdc hosted head actually passed Swift6.1.2 production compilation and mission-pack validation, then failed coverage-test compilation at the original two expressions. Tests/coverage export/threshold, TSan/ASan/leaks did not run. Local6.4 selected results do not establish the corrected test target's older-compiler acceptance. One corrected final-head hosted check and clean required external review remain necessary. No product/source/media changes, full local CI, threshold/time-limit/protection waiver, merge or release.
