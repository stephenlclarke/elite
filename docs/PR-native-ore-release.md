# fix(mining): separate fresh ore births and wait for pending admission

## Fresh output and compatibility

MiningLedger changes only new native AsteroidBeltDefinition chunk output. Its grid spacing is twice the actual cargo radius plus16, leaving headroom over the unchanged8-unit hull admission gap. Native chunk sizes are one or multiples of five. Centering that grid about the original centroid preserves birth center of mass; one-pod output is unchanged. Fragment ordering, amounts, per-index velocities and total mass/linear momentum remain exact. Complete five-column rows also preserve angular momentum about the original source center.

Existing pending records, admitted bodies, saved witnesses and ordinary fallback output are never repositioned or regenerated. Source-content bytes and save formats are unchanged. All player, sibling, traffic, planet and exact motion guards still apply; the layout does not guarantee immediate admission in an obstructed scene or automatic repair of legacy dense pending output.

## Truthful recovery and bounded retry

selectNextMinedOre checks same-source ledger pending cargo before announcing completion. Existing eligible selection remains unchanged. Unbound pending cargo with no eligible actor retains the source and waits for the already scheduled normal admission path. One transient Game deadline expires on the first normal step at or after60 physical seconds; that reports safe-admission blockage and clears only automatic recovery state. Pending cargo and physical momentum remain intact. All-bound but ineligible cargo reports uncollected-ore blockage immediately, including full-hold cases. No blocking loop or extra physics/admission query is added.

The deadline resets for new-source recovery, actual acquisition, eligible selection, completion and cancellation. releaseWorkGuidance clears pending recovery/deadline before its existing live-controller guard, so Q and scene changes also cancel an actorless wait. The original guided/braking momentum release remains unchanged; the actorless waiting phase follows completed braking. No Codable field, actor ownership change or public API is introduced.

## Regression and qualification

Five new methods declare fifteen cases:

- MiningLedgerTests.nativeChunkBirthLayoutPreservesIssuedMassCentroidAndMomentum: eleven native unit sizes, including genuine twenty-mineral output, native geometry spacing, exact identity/amount/velocity, centroid and momenta, cold round-trip and unchanged previously pending records after another native extraction.
- FlightWorkGuidanceRuntimeTests.freshTwentyPodOutputUsesNativeSafeAdmission: one genuine twenty-pod native release, actual ledger requests/admission/acknowledgement, and retained player-overlap refusal.
- pendingOreRecoveryWaitsExpiresAndQPreservesMomentum: one actual admission-capacity fixture, native physical clock expiry, real Q with actual throttle momentum and untouched pending cargo.
- pendingOreRecoveryResumesAndFinishesOnlyWithoutPending: one actual admission resumption and ordinary ledger settlement before completion; no protected receipt is fabricated.
- boundButIneligibleOreRecoveryReportsBlocked: one real admitted set under an initial owned full-hold condition, preserving pending cargo.

All old test bodies remain exact. The first bounded native selection is eight methods/eighteen cases: the five new methods/fifteen cases plus unchanged FlightWorkGuidanceRuntimeTests.genuinelyGeneratedRockHandsItsAcknowledgedOreToAutomaticRecovery, MiningLedgerTests.allMountsExtractOnceAndRoundTrip and MiningLedgerTests.admissionRefusalCullAndSettlementKeepOnePayload, one case each. Ordinary MiningOreRuntime motion/save tests exercise changed admission/output dependencies; their public helper still inherits a starter without a Mining utility, while the separate private G12 owner already has a supported-hull fixture correction. Do not import that private owner or expand this seven-path source slice: Root must resolve the prerequisite before those native selectors run. After the prerequisite is resolved or explicitly present in the executor composition, add the four MiningOreRuntimeTests methods actualMovingOreKeepsCanonicalPoseThroughCameraMotionCullAndReentry, realSaveReloadAndLaunchUseLatestOreMotionWithoutCreatingAnotherYield, wrongActorCannotScoopOrRewriteAnActualAcknowledgedOrePod and actualBoundOreCollectsOnlyOnceAndAnOldVisitBodyCannotCollectIt, one case each. That yields twelve methods/twenty-two cases. Prior retained17/18 evidence is not automatically transferable across the new output/recovery code. The existing spin/mode/mesh results are retained only with explicit exercised-dependency proof, never relabeled as an execution of this changed source.

MBA source authoring and source-only formatting/strict lint, exact scope/old-test checks and local Markdown/diff checks precede G1's matching compilation and exact selected cohort. Native tests, one complete independent seven-path bugs/performance/style review and required CI remain pending. No author native execution, probe or runner timeout change occurs. The frozen automatic twelve-original journey is separate and remains required for end-to-end acceptance after matching qualification.

## Test assertion compiler correction

The focused 1217 build rejected the mutating ledger destroy call inside the testing macro. The completion test now evaluates that same call once into a local Boolean before asserting it. The payload, action order, state and oracle remain unchanged; production code is unchanged. Source formatting and lint checks are complete; matching native qualification remains assigned to G1.
