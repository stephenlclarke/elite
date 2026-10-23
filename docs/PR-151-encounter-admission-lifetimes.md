# Encounter admission lifetime phases

## Motivation

[Issue151](https://github.com/stephenlclarke/elite/issues/151) identifies the owned stopped admission predicate path in the original authored-board travel/delivery/repeat test. Early admission checks share a function frame with later request construction and persistence temporaries.

## Implementation

Use a thin noninline entry for the original empty-plan predicate and a noninline nonempty phase containing the complete original remainder. Forward the same plan value. Preserve all original guards, operation order, receipts, atomicity, idempotency, identity allocation and state publication. No per-request or general admission policy is changed.

## Validation

Formatting and diff hygiene pass. Six directly affected unchanged methods/cases retain empty/adoption, full preflight, atomic/partial refusal, replay and original mission delivery assertions. Execution and independent actual-diff/result review are pending. [The issue evidence](ISSUE-151-encounter-admission-lifetimes.md) preserves exact failure scope and missing guard-mapping limits.

## Compatibility and remaining limits

No save schema, actor isolation, equipment, missile resource or mission behavior changes. No stack enlargement, concurrency change or assertion weakening. The current full VM and required quality runs remain separate, and historical144 origin is unproved. Native M01 and release acceptance remain open.

The first focused invocation at d5d6da32556fd73578d6ac081453927a56780d06 failed: build94.32s, total110.009920s, process exit1. Only the two EmptyEncounterAdmission methods completed successfully. Three GameplayAdmission methods recorded five hard-coded body-count assertion failures; actual admission restores registered native stations after the fixture removes their bodies. The original authored-board method started but has no completed result. The helper also terminated with signal10 and XML remained unfinished52bytes. No fresh attributable normal crash report was found, so this run does not establish a new fault location or guard mapping. Evidence: `/tmp/elite-151-admission-lifetimes-units-result.json`, its log and unfinished XML. Source151 remains unqualified; no six-method pass is claimed.

The corrected fixture run at 18fb5976b9b09ecbefa19215b6b487fdf767dd69 compiled in48.18s and ended exit1 after62.762780s. All three corrected admission fixtures passed (stale8.765s, success/replay8.769s, atomic/partial8.796s), with no assertions. The original mission only started before helper signal10; XML remained unfinished. These are three individual passes, not a complete four-method qualification. Evidence: `/tmp/elite-151-152-admission-unresolved-units-result.json` and raw log.

One authorized bounded capture of that exact original mission used the unchanged built image97114AA2-3EB4-3CF7-8185-3F7F9223AD04, SHA25632e783a9834f1579811d62d931ecf84865b7f5df9de80956e4ce827e5ac694d0. Two initial launch attempts could not load test-runtime libraries and never executed the test; their failures remain retained. After supplying the existing SwiftPM/Xcode test-library paths, the sole executed capture stopped thread4 in16.469223s: EXC_BAD_ACCESS code2 at0x16fe03fc0, SP0x16fe03fa0, both inside actual no-access mapping0x16fe00000-0x16fe04000. The path is NativeStationWorld metadata/world.valid, complete station validation, population header/cohort, populateNativeStations/ensurePhysicalActors, nonempty encounter admission, missile launch/advance and the original mission at ScriptContractTests211. The debugger killed only owned helper83049 after capture; debugger exit0 is not a test pass. No helper/debugger remains.

Evidence: `/tmp/elite-151-original-mission-fault-capture/runtime-paths-corrected`, with exact command/image, log, result and unfinished XML; earlier launch-only failures remain in parent/sibling directories. This actual fault supports separating the nonempty adoption/context preflight from the unchanged batch/construction body as a third noninline phase. The same plan and successfully built context pass synchronously in the original order; every full validation and admission rule remains. No new diagnostic is planned, and historical144 SIGILL origins remain unproved.

The final seven-method run at5ba8a787c3248b04ecf8077d6b95ed8d0b4310d0 also failed: compile88.54s, total103.403302s, exit1 and helper signal10; XML remains unfinished52bytes. All five corrected admission fixtures and the actual-request/adoption method individually passed with no assertions. The original mission only started and has no completed result. No aggregate seven-method pass or151 completion is claimed. Evidence: `/tmp/elite-151-152-preflight-admission-units-result.json` and raw log. No further capture, unchanged replay or speculative production change was started.
