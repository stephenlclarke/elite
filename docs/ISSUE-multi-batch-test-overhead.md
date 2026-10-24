# Multi-batch test repeats observation work between identical frames

The existing normal-run timing reports 2426.7 seconds for `NativeMultiBatchRuntimeTests.originalHumanManifestImportRequiresAFullSecondBudgetAcrossActualSaveAndReload`. This is retained timing evidence, not a new measurement or attribution of the full duration to one operation.

Its first-release and resumed-release loops already own the exact frame returned by the preceding actor advance. The held-work fixture immediately requests another actor snapshot to read the same holding and fire-suspension flags. `GameRuntime.snapshot` also derives the weapon display, which can perform work-ray collision and salvage-authority projection. No input or runtime mutation occurs between the caller's last snapshot and this repeated snapshot. All three normal-test loops also derive the same scalar work observation at the end of one iteration and the start of the next.

Remove only that duplicated test observation work. Preserve the actual actor simulation, conditional release/Return/press sequence, 0.02-second frames, three 2500-frame bounds, work budgets, per-frame assertions, ownership and lot oracles, and genuine save/reload/no-write checks. Production code and quality gates are outside this packet. The M03 identity packet remains frozen separately; the M01 merge hold remains.
