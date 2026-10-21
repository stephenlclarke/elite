# test(fixtures): verify durable native equipment publication

## Changes

Three native equipment tests previously required the bootstrap pointer bytes after a successful action. They now derive the complete expected state from the captured pre-operation Game and verify the actual durable publication, while retaining the immutable original pointer/tree for earlier read-only or refused actions.

The purchase expectation receives only the allocated transaction and item UUIDs from the result. It requires fresh, distinct identities and independently constructs the Fuel Scoops node, authoritative displayed price, station shop, offer revision and utility fitting. Lower-domain quote/apply is checked against manual exact debit, prerequisites, ownership, physical items/components/provenance, original history prefix, receipt/revision increments and retained cargo, salvage, mission state and resources. The two Fit expectations validate the original grant and painted command, independently project the only permitted location changes and revision increment, and compare supported Commander fitting with Game fitting/resource preservation.

The publication helper requires complete live/view/stored Commander equality, valid consistent complete saved world values, exact commander-scope typed schema 26, a new valid generation and four exact chunk names with verified actual hashes. Every original generation file is byte-identical; exactly four new files belong to the sole new generation. This retains the native double-queue tests and prevents a second publication from passing as once-only behavior. It never derives expected Commander chunk hashes from unordered Codable Sets.

All positive checks are throwing requirements before the helper returns a post-commit checkpoint. Each method then replays its original purchase or Fit intent through the actor, requires `.refused(.staleContext)`, and compares the complete expected Commander, resources, pointer and whole file tree with the verified checkpoint. The existing stale-after-load mouse case remains before the successful fresh painted mouse action. Awaited, throwing and mutating effects in changed assertion contexts are bound before macros.

## Scope and verification

The exact parent is `db04b9b4b7323cf186a7b89bffa5e26895907c88`. Three files change: `NativeEquipmentViewTests.swift` and this new issue/PR pair. The three existing methods are `nativePaintedShopRejectsStaleActionsAndCommitsDuplicateReturnOnce`, `nativeInventoryRequiresPaintAndSafelyRefusesFastFocusBeforeReturn` and `nativeInventoryMouseRejectsUnpaintedResizeAndRestoredContext`: three cases, no new test methods. Four new private expectation/publication/refusal helpers have caller counts one, two, three and three. Shared bootstrap, `verifyUnchanged`, other five native fixture methods and all other source regions remain unchanged.

Only source formatting/parsing, strict lint, Markdownlint and static assertion-effect/scope/selection/hash checks run in this authoring lease. No compiler, typecheck, test discovery, test, build, UI, media, GitHub, push, merge or Sonar job runs. Root must review the committed source before G1 executes it. All prior refs and completed historical/current scopes remain preserved; the six validation-341 passes and validation-339 40-method/50-case passes are retained without claiming this child has executed.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for every actionable finding, required checks passing on the final head, required independent approval and protected merge without bypass.
