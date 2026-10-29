# Procurement preflight observation exhausts the default helper stack

## Actual evidence

Qualification 657 ended with a matched Thread stack size exceeded/SIGBUS in swiftpm-testing-helper PID54876, started 12:17:31. The retained crash report is /tmp/elite-station-qualification-657/swiftpm-testing-helper-2026-10-19-121746.ips, SHA256 33943778080e108edad9b1de62969a2ce2da9d44949dcadc4e5453f048da5e9d. The source was c55c248f693a080fb95b616263d1f26b97acbda0; it already includes the preceding transit publication lifetime repair. All 49 selected methods were UNKNOWN, with zero terminal outcomes/issues; no collision, transit or reader behavior failure can be inferred from the interrupted run.

The matched stack reaches Array equality through NativeStationLedger and NativeStationWorldContent semantic equality, NativeStationValidationMemo.contains, current station validity, gameplayMeshOverrides and nearestMissionCollision. The active test-helper callers are GameRuntime.procurementPreflightFacts at ScriptProcurementFixture.swift1040 and procurementMissileFallback at ScriptProcurementMissileDefence.swift44, beneath procurementMissileActiveNativeECMDefersWithoutSpendingOriginalStock. The top equality frame is not proof that equality itself is defective.

## Source lifetime gap

The synchronous fallback function's first preflight executes in the same function that later owns a full Commander value baseline and its post-launch comparisons. That full value remains live across another arm/preflight call. Entry-frame reservation is a source-backed risk, not a measured allocation diagnosis. Preflight also repeatedly projects actor-owned Game state while making the deep native geometry/current-validity query. The repair must materially separate these lifetimes while preserving all original checks and the actual physical query.

## Required limits

Keep the default stack and concurrency, complete station memo equality, original geometry/law/stock/receipt predicates, and the unchanged crashed regression. Add no hit grant, test skip, validation shortcut or authority suppression. G1 alone owns compiler/native execution. See PR-procurement-preflight-observation-frame.md.
