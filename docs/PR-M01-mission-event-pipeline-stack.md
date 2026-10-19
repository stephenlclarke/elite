# M01: bound acceptance and event-publication stack lifetimes

## Problem and resulting behavior

The real mission writer is entered from an already crowded worker stack. Existing760 binary inspection identifies three Game-sized buffers in the mutating event wrapper, even though make/run/finish use them sequentially and destroy the first two before publication. The earlier source-only helper chain did not achieve a native PASS and remains preserved, unintegrated.

Root-authorized fresh base is `a9fd7e60f8a8e77f7a38e5a7b1c501b9f3215918`. This isolated branch changes only two production hunks in `ScriptDirector.swift`: the original independently reviewed acceptance validation/construction split from457, and one borrowed-original event pipeline. It imports only457's new acceptance test file; no old ledger or failed helper is cherry-picked.

## Implementation and preservation

Acceptance validation returns before instance construction, preserving all original guards, mutating receiver, admission authority, existing scratch object and publication/rollback path. This is the same initial457 product hunk whose five acceptance cases passed in744, attached to that older exact source.

A private non-inlined static `executeScriptEventAttempt` borrows the original Game once across the unchanged make, run and finish calls, then returns the existing attempt scratch. The mutating wrapper still selects, invokes, commits and handles typed refusal/ordinary failure in the original order. No explicit Game copy, owner, schema, guard, physics or event/publication rule is added. The predicted reduction is two sequential original-Game buffer reservations in the wrapper; neither the new compiled slot count nor default-stack repair is claimed before execution.

Inlining the pipeline reconstructs the entire457 Director byte-for-byte; reversing only the imported acceptance patch then reconstructs the entire approved base Director. Proof `/tmp/elite-M01-minimal-pipeline-source-proof.json` also checks the imported acceptance test byte identity, original native fixture/regression and affected existing test sources. The failed branch remains clean/frozen at `1af6fd7d549b18bb7ce2126b6c164fa24faf7d7e`. Game, FlightWorkTools, both native salvage files and G3's final freight source stay byte-identical to the fresh base. There is no cross-owner freight composition in this branch.

## Validation and current status

Current status is **in development**, awaiting independent bugs/performance/style review and a matching author-owned focused run. Strict Swift formatting/lint, scoped Markdown lint, whitespace and whole-file source inversions pass. No new compilation, binary inspection or runtime has occurred on this leaf.

Proposed batch is six existing/new methods, ten cases: two acceptance-preparation methods/five cases; both original real courier parent/child context cases; the unchanged actual native crossing/failed-writer regression; real freight partial/final writer refusal and once-only settlement; accepted-freight save/reload and stale-contact refusal. These test the new shared event pipeline and native publication authority. No salvage-only or other failed-helper test scope is carried forward.

All original fixture, assertion, stack and concurrency settings remain unchanged. The author owns focused PASS and review fixes before integration handoff. No full CI, coverage percentage, sanitizer/leak, new playable build, PR/check or release acceptance is established. Existing private preview742 and open M01 identity/defaults/docking work remain separate. See the [issue](ISSUE-M01-mission-event-pipeline-stack.md).
