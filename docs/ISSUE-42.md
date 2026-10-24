# Issue42: stale deferred-stage expectations

Original rescue receiving delivered the stage9 source transition and changed the truthful deferred-stage notice to stages10–14. The maintained VaultKey assertion at line80 and Continuation assertion at line208 still expected9–14. Collector-enabled39711047075 reported both actual failures. Preserve surrounding custody/progress/reward assertions and update only these two expected boundary strings.

Existing correction run39713632774 completed all174 methods/206 expanded cases without a crash and passed the first two corrected assertions. Its sole remaining failure is the same stale `9-14` expectation in `NativeWayfarerInductionCassetteServiceUnitTests.swift:99`. This third location extends the same issue, not a separate root cause; all surrounding service/custody checks remain intact.
