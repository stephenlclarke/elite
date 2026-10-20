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

## G1 selected qualification and retained failures

Matching1007 currentSwift6.4 build passed, then actual1008 passed the pose-publication/idempotence method (one case) and failed two methods/three expanded cases with nine issues. Source diagnosis found obsolete legacy-motion observations and a legacy revision-overflow setup bypassed by the current native store. The selected method corrections use actual hot/parked/cold native records and validated native-world revision overflow while preserving physical/refusal/original-state oracles. One review P2 corrected exact cold comparison to the actual post-rebind record, retaining parked pose tolerances.

Matching1009 and actual1010 passed the native-arrival method's two cases; the sole motion case then caught POSIX20 ENOTDIR. Its precise throwing path/call was not emitted. A source-supported correction uses the existing resolved native temporary-folder helper and child file, preserving archive security and persistence checks. Matching1011 and actual1012 reached the cold-record checks but failed at the final body admission: the test copied only the commander, discarded its authenticated scene and cleared bodies while retaining the native binding. Complete selected-method reconciliation preserves the loaded scene, exercises ordinary dock parking, then launch/new-visit and actual native re-admission; no injected body/direct binding edit/forced flush or physical docking receipt is claimed.

Matching1013 passed; actual1014 ran only the motion case and passed through the last oracle in10.473seconds, zero issues/unknowns. Aggregate selected qualification is three methods/four cases (1008pose1 +1010arrival2 +1014motion1), not a single all-pass run. Exact dependency proofs preserve the retained passing methods and shared helpers/resources/product bytes. The salvage helper's other callers are not a qualified whole family. Original1008/1010/1012 failures and immutable raw values remain retained, without invented per-argument issue/end pairing.

Every runtime run retained all1,945 artifacts, tracked inputs and primary preferences exactly and independently closed its actual owned starts without timeout/cleanup. Final1014 closed13 starts and released its lease. Proof SHA256 `1ad51de517832d880821a1bf172ac45bf4173cd35aea6cdcbc66a23eaf33c568`; closure SHA256 `46dcc8349caec33e38058ccfcf87c944300b206a4343c33db16e6b0a3be9be4f`. Full expression review SHA256 `ef13141f90c684f3aab22cb877516600025a1f66c5f9c4c5836e835599b1038d`, native fixture review/closure SHA256 `9f0d54dcd331d8d8157dc84f4b65b7723f3b4d507c422dba79ba00a073e71269`, path delta SHA256 `4865e4766fe3da3ff7acc76cd1f130d8866585b8bcb87d1fcc89ebedff21821a` and complete motion-method review SHA256 `70cd36acb698c311a8d857a4ad1f0279974c6ae1a99e72c6730904c537252869` are CLEAN.

The previousfdc hosted head actually passed Swift6.1.2 production compilation and mission-pack validation, then failed coverage-test compilation at the original two expressions. Tests/coverage export/threshold, TSan/ASan/leaks did not run. Local6.4 selected results do not establish the corrected test target's older-compiler acceptance. One corrected final-head hosted check and clean required external review remain necessary. No product/source/media changes, full local CI, threshold/time-limit/protection waiver, merge or release.
