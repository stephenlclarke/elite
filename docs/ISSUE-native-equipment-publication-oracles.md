# Verify native equipment publication against the correct save generation

## Recorded failure and cause

Validation 341 completed nine methods/nine cases at `26ae50032788bd1f65653e53ef0b89c55e88bc0f` in 41.641 seconds. Six methods passed. Three methods recorded one issue each at `NativeEquipmentViewTests.swift` lines 405, 639 and 691: the saved pointer was compared with the bootstrap pointer after a successful purchase or fit. The raw log is `/tmp/elite-native-equipment-bootstrap-focused-341/candidate-341-attempt-01.log`, SHA256 `ad41a6e2c3521351ab11624af63aa63584ebd48a8bb41db8399d0133559baa41`. Its diagnostics say `<not evaluated>`; no actual pointer or chunk byte operands were dumped.

The cause is source-backed: the legitimate versioned bootstrap retains a calendar, so equipment transactions own durable state. Successful mutations publish a new UUID generation through the strict writer. Refused commands return before publication. The original pointer remains the correct baseline for earlier read-only and stale actions, but successful publication requires independently expected changed state and a fresh, verified post-commit baseline.

## Required behavior

Keep `originalSave`, `originalFiles`, the shared bootstrap and `verifyUnchanged` immutable. Preserve every existing paint, focus, resize, load, stale-context, duplicate native-event, owner, inventory, history, cash, targeting and active-destination oracle. The two inventory methods additionally verify the original complete save tree immediately before their successful action.

Build the expected complete Game from the pre-operation value and the trusted selected item or painted Fit command. For the purchase, take only the two unavoidable allocated UUIDs from the unique new paid receipt, require them fresh and distinct, and independently construct the node, price, shop, offer revision, hull and fitting location. Re-quote and apply through the lower domain, checking manual prerequisites, exact debit, receipt/revision increments and original physical property conservation. For held grants, independently project the item locations and use the supported Commander and Game fitting operations, preserving components, provenance, funds, history, salvage and resources.

Require complete live and strictly read saved Commander equality. Require exact schema 26, commander scope, typed codec, a different valid generation, the exact four chunk names and hashes of their actual bytes. Every old generation file must retain its exact bytes; the pointer is the only replaced original file. Exactly four new files must exist under the single new generation, excluding a second publication or orphan generation after the queued duplicate. Compare every saved world JSON value with the independently expected world; this empty-body fixture has no nested Commander Sets, and no expected Commander hash is derived by re-encoding Sets.

Only after all positive checks succeed may the helper return the immutable post-commit file checkpoint. Replay the original painted purchase context, chosen Fit command or fresh restored Fit command through the actual actor boundary. Require explicit stale-context refusal, the same independently expected Commander/resources, and byte-identical current pointer and entire file tree.

## Scope and validation

The parent is preserved `db04b9b4b7323cf186a7b89bffa5e26895907c88`. Exactly three existing methods/three cases change, with four private helpers called by one, two, three and three methods respectively. Only `NativeEquipmentViewTests.swift` and this new issue/PR pair change. The other five fixture callers, the Jump method, shared bootstrap and existing helpers remain byte-identical. Production, G1 EMP/UI/Security work, earlier historical scopes and all preserved refs are excluded.

Formatting/parsing, strict source lint, Markdownlint, assertion-effect inspection and static scope/hash/selection checks are the only local validation. Root reviews the frozen child before G1 runs the approved selection. Validation 341 remains failed overall; its six passes and validation 339's 40 methods/50 cases remain retained. No native acceptance is inferred from source checks. See the [PR handoff](PR-native-equipment-publication-oracles.md).
