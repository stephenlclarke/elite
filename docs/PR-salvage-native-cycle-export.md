# Share native section cycles and seal original exports

## Result

The existing `SalvageLedger.advancePlanned` producer now calls `SalvageSectionCycle` for its original bounded release calculation. It retains inspection, operation ordering, partial-work publication, ordinary pending capacity and depletion handling. Every emitted batch still clears work and damage, including incomplete sections.

`SalvageLedger.exportNativeSection` returns a non-Codable value constructed only in the ledger file after full ledger and original-seed emission checks. It binds the whole original semantic ledger, including current poses, and exposes exact optional old work, damage, death, depletion and global operation evidence. The internal transfer seam removes section-local pending custody and reserved stored property once, retains the original plan and settlements and ordinary stored technology, and records an irreversible routing marker. The marker is a subset of existing old plans, not a new native source-history pool.

## Validation

Source parsing and strict formatting are checked before handoff. Seven new methods cover actual original producer batch reset and mining damage, refused batch admission, original seed and missing history, stale same-revision pose seals, exact transfer and replay refusal, round-trip markers and refusal of uninspected plans. Compilation and execution are pending the sole validation lease; source checks are not a test or native gameplay pass.

## Compatibility and risks

Existing original plan keys and values are retained. The optional routing field defaults to empty for older ledgers. No gameplay caller uses the transfer seam yet; the actor/world-codec/census/continuation/collector publication integration remains required before it can be enabled. No new capability, full CI, coverage, leak, performance, review or release claim is made by this change. The README player behavior remains unchanged. Linked issue: [ISSUE-salvage-native-cycle-export.md](ISSUE-salvage-native-cycle-export.md).
