<!-- markdownlint-disable MD013 -->
# Crew-log recorder lookup frame during target cycling

[Issue #108](https://github.com/stephenlclarke/elite/issues/108) follows [#106](https://github.com/stephenlclarke/elite/issues/106) and [PR #107](https://github.com/stephenlclarke/elite/pull/107). Current52ce compiled in run39839922136, then execution ended with signal4 and no attributed crash report. Its single approved retained-image capture39843168323 stopped after102.347seconds with one launch and successful owned cleanup. This diagnostic stop is not qualification or proof that the original signal4 has the same exception identity.

The captured stack is chkstk, inductionCrewLogRecorder, inductionCrewLogFacts, workTargetCandidate, real Tab target cycling and the unchanged original station-hazard test. It contains no Display.draw or visibleInFront frame. Image/dSYM UUID E97D806C-28C7-32C9-A102-313DC07DEE89 matches the retained current image. The recorder's LR+1660 maps to return0x1d5a3e4 immediately after stack-probe call0x1d5a3e0. The preceding metadata/size load is NativeInductionCrewLogState; captured x8 is4871bytes, aligned4880. This is a prologue allocation before the source's leading marker rejection. No memory-region map was captured, so a stack-guard region is not separately proved for this stop.

Ordinary non-mission targets must reject without entering that large present-validation frame. Keep the same marker predicate once, then call a noninline helper for the unchanged full owning-child/recorder/physical/profile authority checks. Preserve returned alias/identity/body semantics and all state/save/selection behavior. See [the repair note](PR-crew-recorder-marker-boundary.md).

## Current facts boundary

The subsequent exacteed9 retained image B50DBAA9-2482-375C-8867-1037424B648B emitted the recorder's128-byte wrapper and separate full validator. Its single capture39848103306 stopped after79.457seconds with successful cleanup. The current frame is inductionCrewLogFacts+176, called by inductionCrewLogMetadata and recoverable target metadata; no old recorder frame is present. LR0x114d24d34 maps to static0x1dd0d34 after probe0x1dd0d30. Metadata caller0x114d25360 maps to return0x1dd1360 after its facts call, independently confirming slide0x112f54000. The probe is the second aligned Commander allocation in the facts prologue, before the recorder guard.

The same correction separates recorder rejection from full facts validation. The leading recorder check still runs once. Only a genuine recorder enters a private noninline facts helper with the same child-state guard and original identity/cargo-fit expression. Metadata generation, status prose and target semantics remain unchanged. No current stack-guard memory region or original signal4 exception equivalence is inferred.

## Current shared read boundary

The exact01af hosted run39861559047 compiled in556.85seconds, then ended with SIGBUS10 and zero completed methods. Its raw stack identifies closure1 in Game.withReadOnlyCommander+356, called through Array.withUnsafeBufferPointer, recorder lookup, facts, metadata, work targeting and the original five-condition station-hazard regression. No matched IPS or stack-guard region was retained for this hosted result.

The retained binary SHAa25ce1374da397639cb59af3bb1a6d13d4b9274d179f780644f363b75f0b7dea and UUIDB5BEB7F0-5E88-38D9-B311-8721FDCD8FE0 match the current recorded image. The closure begins at0x9f33f4. Commander metadata at0x9f3464 and its value-witness size load at0x9f3480 precede a temporary allocation. The call at0x9f3554 is CommanderVWOc; its return0x9f3558 is exactly closure+356 and the reported runtime return0x113cdf558. The pointer-pointee expression therefore materializes an owned Commander before invoking the existing borrowing closure. This is emitted-code attribution, not a claim about an unretained guard region.

Replace that one shared helper body with a direct checked array-element read passed to the existing borrowing callback. Preserve synchronous execution, rethrows, return-value ownership, array storage and every marker/lookup check. New throw-propagation assertions extend the existing storage regression; no selector or method count changes. Compilation, affected execution and new emitted-code validation must precede a claim that the owned copy is eliminated.
