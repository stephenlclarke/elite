# Pr 197: Keep raw legacy save fixtures valid after selecting SH013

## Motivation

Required quality run [40062040085](https://github.com/stephenlclarke/elite/actions/runs/40062040085) at `a890a93c7e7d698fd8a308cbb39dad75fe892278` completed3395normal methods with99issue records across55distinct methods. All1879retained source/build inputs match the published head. The helper exited naturally with status1; no SIGBUS recurred. Coverage execution failed, so later sanitizer and leak gates were not established.

## Bounded correction and preserved behavior

Both fixtures change Commander.shipID toSH013 while retaining current default stock, then legacy load rejects invalidCommander. Normalize fuel/missiles to the intended historical hull before encoding. Preserve in-memory migration, unchanged original bytes, invalid-save rollback and queued Cobra restore order.

This is one cause group in the single M01 correction packet, not a separate execution or review gate. Confirmed fixture changes explicitly establish their intended hull stock, cash, shop eligibility, authored world or codec envelope. Unattributed paths retain their original assertions and bounded failure-only facts until actual evidence establishes the cause. The physical runner arrangement retains the hard GPU assertions and every required quality command; [its authorization design](NATIVE-QUALITY-RUNNER.md) keeps untrusted events and unapproved heads out of native execution.

Affected methods:

- `startupRestoreMigratesInMemoryWithoutOverwritingAndFailuresPreserveGame()`
- `nativeSaveIncludesEarlierQueuedCobraRestore()`

## Validation and compatibility

The coherent actual patch and one combined affected/direct-consumer batch are pending independent review and execution. No passing result or issue closure is claimed. Previous524maintained unit passes and the earlier qualified repair scopes remain separate. No original feature, authority, ownership, physics, custody, allocation, save schema, renderer parity, coverage threshold or branch protection is weakened. The independent [terminal receipt](evidence/M01-a890-terminal-quality-review.json), [complete cause mapping](evidence/M01-a890-blocker-packets.json) and [issue mapping](evidence/M01-a890-blocker-issues.json) preserve exact assertions and source confidence.

## Links and remaining risks

[Issue 197](https://github.com/stephenlclarke/elite/issues/197); [PR25](https://github.com/stephenlclarke/elite/pull/25). Remaining unknowns require actual bounded unit evidence in the same batch. Full final-head quality, protected merge, committed-main-only SonarQube with exact source SHA and signed/notarized release acceptance remain required. Issue185 stays open pending full quality; this terminal run is not a recurring stack crash.
