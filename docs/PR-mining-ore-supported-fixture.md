# test(mining): use a supported initial hull in ore-motion fixtures

## Implementation and compatibility

actualMinedOreGame chooses initial commander.shipID SH023 and matches fuel to that hull's capacity before prepareEquipment. This is the same bounded helper hunk already retained in the private G12 source, copied alone. It does not change the starter configuration, catalogue, slots, equipment validation, native damage, actor admission, ore payloads or collection policy.

Every existing method body, generated-rock setup, real firing loop, camera-motion test, ledger guard, cold save/load, relaunch and once-only collection assertion remains exact. All production files and the seven-path fresh-release owner stay unchanged. No extra fixture refactor or private G12 import occurs.

## Exact qualification

Four unchanged methods/four cases:

- MiningOreRuntimeTests.actualMovingOreKeepsCanonicalPoseThroughCameraMotionCullAndReentry.
- MiningOreRuntimeTests.realSaveReloadAndLaunchUseLatestOreMotionWithoutCreatingAnotherYield.
- MiningOreRuntimeTests.wrongActorCannotScoopOrRewriteAnActualAcknowledgedOrePod.
- MiningOreRuntimeTests.actualBoundOreCollectsOnlyOnceAndAnOldVisitBodyCannotCollectIt.

MBA source authoring/formatting/strict lint and local exact-hunk/test preservation, Markdown, scope and diff checks precede one G1 matching composed execution of these four cases. The fresh-release cohort may share that build; no separate native author run, probe or replay is requested. One complete independent three-path bugs/performance/style review follows actual owner PASS before integration. Native outcomes remain pending, and no automatic G12 twelve-original acceptance follows from this prerequisite.
