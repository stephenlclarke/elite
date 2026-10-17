# Target-removal fixture retains later scenarios during target setup

The original `thirdPartyDestructionRangeLossAndDespawnCannotClaimPlayerKill` test reproduced signal 4 alone under the unchanged baseline thread-sanitizer binary at checkpoint 174. No assertion failure or matching original OS crash report was found. Its debugger reproduction at 173 stopped in the real `lockedGame` → key R → automatic targeting → front visibility → mesh drawing path.

## Evidence and required behavior

The exact-binary audit identified three Game stack slots in the test caller before its first fixture construction. Later manual-cancellation fixture/read storage remained allocated while earlier independent removal scenarios constructed their games. The fixture factory and actual rendering path also use stack storage; this observation alone does not establish that changing one caller is sufficient.

Give each of the three removal modes its own helper lifetime, followed by a separate manual-cancellation helper. Preserve every original statement, assertion, key press, tick, mode and ordering. Keep the fixture factory and other tests unchanged. Do not change rendering, target eligibility, production guards, runtime stack settings or test selection to obtain a pass.

## Acceptance

Inlining the helpers must reconstruct the complete old file exactly. Strict source lint and whitespace checks must pass, followed by actual compiled execution of the unchanged original test and related target-removal cases. Checkpoint 173 is its own debugger evidence; without a matching original report it must not be presented as proof of checkpoint 172's crash cause. See [the implementation handoff](PR-target-removal-fixture-lifetimes.md).
