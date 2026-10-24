# Issue 185: unattributed terminal decoder fault

## Motivation

The unfiltered quality run [40043514103](https://github.com/stephenlclarke/elite/actions/runs/40043514103) for PR25 head `ae97d337cb9cf25b58322a21946e9ece297dd60a` failed. Its saved evidence records 62 assertion-bearing methods and a separate terminal SIGBUS. The earlier 19-method and 524-method passes remain limited to their recorded scopes.

## Scope and correction

Keep the actual SIGBUS open. Retained offline evidence identifies the decoder/freight/Commander-validation path but lacks actual fault address, mapped guard bounds and the caller beyond frame63. No speculative cause or production repair is claimed.

Original assertion locations for this group: the separate terminal decoder path, not an assertion group. The independent full inventory is recorded in `docs/evidence/M01-ae97-terminal-review.json`.

## Validation and compatibility

Source review is complete for the coherent correction batch. Unit execution is pending; these changes are not qualified for integration or release. One combined normal affected-unit batch must retain all 62 methods, including the unresolved moving-debris case. Swift actor ownership, save authority, original data, solver budgets and required quality gates stay unchanged.

## Links and remaining risks

[GitHub issue 185](https://github.com/stephenlclarke/elite/issues/185); [PR25](https://github.com/stephenlclarke/elite/pull/25). The moving-debris sweep remains unresolved; debug-only scalar refusal logging collects its actual query without changing the result. Issue185 remains unattributed. Full coverage, sanitizers, leaks, final review and protected release publication remain pending.

## First combined normal execution

Source `6423e889ab76109f04821e4159fb110be0f9b779` compiled successfully in284.84seconds and completed135 methods in39.895seconds (326.039040208seconds overall). The actual XML records131 passing methods, four failing methods and six failure elements, with zero errors or skips. Every one of the original62 failure methods completed;60 passed. The [per-method receipt](evidence/M01-authored-fixture-unit-results.json) preserves exact selection, durations and status. This is a failed aggregate, not full quality or release qualification.

Remaining failures are the actual -3000 debris/NPC continuation, peaceful classic-frame shield normalization, recovered ECM baseline normalization and a bounded ore-recovery timeout interrupted by game over. Issue186 records the conservative affine-enclosure candidate; three fixture corrections accompany its focused follow-up. No SIGBUS occurred in this run. Issue185 remains unattributed and open, independent of these assertion results.

## Diagnostic retention correction before the next required quality run

The existing first-fault observer is being extended to retain160 minimal caller frames and primitive stopped-thread PC/SP/FP, raw stop data and the actual reported fault address when available. Read-only VM-region metadata records the stack region and its neighbors plus the reported fault region. General and optional FAR/ESR register output precede the backtrace. Unsupported metadata remains explicitly unavailable; calculated instruction addresses are not substituted for actual reported faults. Identity, one-attempt ownership, process handback, cleanup, artifact budgets and the target's normal stack/concurrency/runtime flags remain unchanged. Existing collector units and independent actual-hunk review must pass before publication; this is diagnostic evidence retention and does not establish the cause or correction of the original SIGBUS.
