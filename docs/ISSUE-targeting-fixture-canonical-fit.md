# Targeting fixtures mutate the legacy mirror after canonical fitting

## Observed failures

Full coverage checkpoint 190 on `7e474867618129cd66368d0fd483b4ea8755bcd5` failed with assertion issues and signal 10 before a completed test summary. The assigned targeting failures were `workStatusRequiresARealMatchingPhysicalIdentity` (four nil status results), `rEngagesFullStationDockingWhenXYZzyAssistanceIsOffAndCIsRemoved` (five missing-core/guidance expectations), and `thirdPartyDestructionRangeLossAndDespawnCannotClaimPlayerKill` (three missing target-loss announcements). Other failing methods and the independently captured crash are outside this correction.

## Cause

Launching now activates native station state and prepares the canonical owned-equipment inventory. These fixtures then call the legacy `installTargetingComputer`, which changes only the legacy equipment mirror. The actual fitted targeting slot remains empty, so the runtime correctly refuses targeting, information disclosure and guidance. No target lock exists to lose. Production code has no callers of this legacy fixture helper; weakening the canonical getter would conceal the setup defect.

## Required correction

Configure legacy fixture hardware before launch so the existing canonical migration fits it, and assert the actual resulting tier and required lock. The station test must retain its initial unfitted refusal, then explicitly grant its fixture core through the existing owned-equipment fitting operation. The textured-hull fixture needs the same canonical fitting correction before its actual Basic acquisition checks. Preserve all original scenarios, inputs, ticks, disclosure checks, docking and announcement assertions.

## Validation and limits

Strict formatting, Markdown lint and diff checks pass. Source reversal verifies that only the intended fixture setup and explicit preconditions change. No production code, authority, paid progression rule, case selection or expected result changes. The corrected tests have not been compiled or executed by this worker; Root must execute the focused original cases and final composed quality gate. The 190 failure remains failed evidence. See [the implementation handoff](PR-targeting-fixture-canonical-fit.md).
