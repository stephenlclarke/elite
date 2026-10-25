# Reduce repeated observation work in the multi-batch runtime test

The normal first-release and resumed-release loops now pass their already observed fresh-press decision to an additive `NativePagedSalvageFixture.advanceHeldWork` overload. It runs the identical conditional input sequence and actual actor advance. The original overload still obtains its own snapshot for existing callers. The caller-owned frames remain private to this sequential test; there is no shared mutable Game cache.

All three normal-test phases retain the previous six-field work observation instead of deriving it twice across adjacent iterations. `observeWork` borrows its input. Every original assertion, case, frame size, iteration bound, credited-work budget, save/reload and authority check remains. Diagnostic continuation code retains the original snapshot-taking helper.

## Validation and execution handoff

Strict Swift formatting and whitespace checks pass. Markdown lint passes for these notes. No local compilation, test, profiling or benchmark run was started. The retained 2426.7-second duration motivates this change; no measured speedup is claimed.

The exact affected method is `NativeMultiBatchRuntimeTests.originalHumanManifestImportRequiresAFullSecondBudgetAcrossActualSaveAndReload`. It is absent from the maintained 529-method isolated selection; an unrelated 529 PASS cannot qualify it. Root must route one matching affected-method run through the existing authorized executor, then MBA reviews its source, assertions and actual results. No new workflow, selector change or execution gate is introduced here.

The original helper's unchanged callers are the retained opt-in continuation diagnostic, `NativePagedSalvageRuntimeTests.genuineGeneratedInspectionAndWorkBypassEveryFullOrdinaryLifetimePool`, `NativePagedSalvageRuntimeTests.actualActorWriterRefusalRetainsCompletedBudgetAndRetryMovesReleasedFragmentsInTheSameFrame`, and `NativeSalvageAdmissionFixture.makeReleased` (shared by admission runtime tests). Review the forwarding overload for equivalence; those consumers retain their snapshot path. This packet remains implementation/validation pending until the affected method and independent review pass. Do not merge into frozen M01.

See [the issue note](ISSUE-multi-batch-test-overhead.md).
