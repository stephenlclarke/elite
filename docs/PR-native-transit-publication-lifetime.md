# Separate native transit resolution from later publication values

## Change

Base is the exact run-655 canonical commit `a25ab702da28bf517edbd7bf3dcb8d0fd175b994`. The actual stack-guard crash reached retained mission-actor fit validation under the live native transit loop. That loop still owned later candidate publication expressions even though its private candidate was already heap-owned.

`publishNativeNPCTransitAttempt` now performs the original actor persistence, Commander validation and actual publisher call only after leg/source advancement returns. `commitNativeWormholeAttempt` contains the original whole-Game assignment, shared by successful NPC publication, successfully written refusal state and successful player passage. Both helpers are non-inlined. The existing heap-attempt initializer is also non-inlined, so its Game initialization completes before source resolution. No new simulation owner, persistent cache, actor or saved authority is added.

The exact same checks and statement order remain: prepare candidate -> advance actual leg -> persist actor state -> validate Commander -> write -> install candidate -> witness successful departure removal. Refused publication still installs nothing and records no removal witness. The same player path publishes before installing its candidate. Source/owner/fit/resource/sweep/current-frame checks, original-world resolution, fuel/calendar accounting, spool/arrival policy and writer errors retain their original behavior. All G1 borrow/exclusivity repairs and station work in the base remain intact. The independent G03 shop leaf remains frozen and is not mixed into this repair.

## Validation and regression

Inverse phase extraction and removal of the added non-inlining attributes reproduce the complete base provider byte-for-byte. Strict Swift formatting/lint, scoped Markdown lint and whitespace checks pass. The actual run-655 crash hash is independently confirmed. No compiler, build, test, CI, native, GUI, debugger, profiler or ABI job runs on the author side. No measured compiled-frame reduction, stack margin, allocation improvement or runtime PASS is claimed.

The existing crashed method `NativeWormholeCohortTests.departureCannotBorrowAnotherActuallyAllocatedSourceAddress` is the same-path regression: real mission creation, actual request/spool/open processing and current native descriptor validation must complete before its exact forged-address assertions run. Its full source and the fixture remain unchanged. Central G1 must compile this material fix and execute that method plus the simultaneous NPC crossings, refused first writer, concurrent player passage and current-location history cases. Preserve the interrupted 655 evidence and UNKNOWN outcomes. Required final matching-head CI/review/check/merge gates remain separate. See the [issue](ISSUE-native-transit-publication-lifetime.md).
