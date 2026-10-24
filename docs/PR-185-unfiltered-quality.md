# PR handoff for issue 185: unattributed terminal decoder fault

## Resulting behavior

Keep the actual SIGBUS open. Retained offline evidence identifies the decoder/freight/Commander-validation path but lacks actual fault address, mapped guard bounds and the caller beyond frame63. No speculative cause or production repair is claimed.

## Implementation and review

This is part of the single M01 release-blocker packet in [PR25](https://github.com/stephenlclarke/elite/pull/25), linked to [issue 185](https://github.com/stephenlclarke/elite/issues/185). The paired [issue note](ISSUE-185-unfiltered-quality.md) records the observed failure and scope. Independent source review found two draft defects in component filler placement and stock-limited reservation assertions; both were corrected and reviewed again. No passing execution is claimed yet.

## Validation

Swift formatting and diff hygiene pass. The one combined normal affected-unit batch is pending on the frozen source. Existing unrelated reviewed/tested evidence is reused within its original scope. Required final-head make ci, main-only SonarQube with exact source SHA, signing/notarization and protected publication remain required.

## Compatibility and risks

No save schema, permissions, simulation authority, solver tolerance or quality threshold is weakened. Issue185 is still an unknown-cause terminal fault. The preserved moving-debris case may still fail and must supply actual geometric evidence before any solver correction.

## First combined normal execution

Source `6423e889ab76109f04821e4159fb110be0f9b779` compiled successfully in284.84seconds and completed135 methods in39.895seconds (326.039040208seconds overall). The actual XML records131 passing methods, four failing methods and six failure elements, with zero errors or skips. Every one of the original62 failure methods completed;60 passed. The [per-method receipt](evidence/M01-authored-fixture-unit-results.json) preserves exact selection, durations and status. This is a failed aggregate, not full quality or release qualification.

Remaining failures are the actual -3000 debris/NPC continuation, peaceful classic-frame shield normalization, recovered ECM baseline normalization and a bounded ore-recovery timeout interrupted by game over. Issue186 records the conservative affine-enclosure candidate; three fixture corrections accompany its focused follow-up. No SIGBUS occurred in this run. Issue185 remains unattributed and open, independent of these assertion results.

## Diagnostic retention correction before the next required quality run

The existing first-fault observer is being extended to retain160 minimal caller frames and primitive stopped-thread PC/SP/FP, raw stop data and the actual reported fault address when available. Read-only VM-region metadata records the stack region and its neighbors plus the reported fault region. General and optional FAR/ESR register output precede the backtrace. Unsupported metadata remains explicitly unavailable; calculated instruction addresses are not substituted for actual reported faults. Identity, one-attempt ownership, process handback, cleanup, artifact budgets and the target's normal stack/concurrency/runtime flags remain unchanged. Existing collector units and independent actual-hunk review must pass before publication; this is diagnostic evidence retention and does not establish the cause or correction of the original SIGBUS.
