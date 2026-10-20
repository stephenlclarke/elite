# Stack exhaustion in rescue metadata during ordinary auto targeting

Actual required quality run 39504100404 at source 88e3b071 captured a SIGBUS stack in ___chkstk_darwin, then Game.originalRescueMetadata at NativeOriginalRescueCapsules.swift:124, recoverableMetadata, workTargetCandidate, cycleAutoTarget, Game.key and stationAutoGame, within stationAutoConfirmedMilitaryResponsePreemptsRetainedActor. This is the actual fault stack, not attribution from the last interleaved test name. G1 retains and verifies the matching test image/dSYM UUID 5614E424-E3AA-31B0-B859-364EC53268D2 and raw log provenance. No OS report original was observed.

The small metadata wrapper enters originalRescueFacts for ordinary non-station/non-capital candidates. That classifier repeatedly reads the computed Game.commander property, including supplying Commander to nested borrowed validators. Game already stores Commander in checked copy-on-write storage and exposes withReadOnlyCommander to lend the stored value without materializing a whole owned Commander. The classifier did not use that mechanism.

The stack probe establishes exhaustion at the reader boundary; it does not establish exact optimized frame sizes or identify every implicit temporary. The correction should use the existing synchronous stored-Commander borrow, preserve every classifier predicate and keep genuine rescue metadata and guidance working. Matching owner compilation and focused native qualification must precede independent review and integration; full required CI remains necessary. No stack limit, concurrency, timeout, serialization or gate waiver is allowed.

See [the correction and qualification plan](PR-rescue-metadata-stack.md).
