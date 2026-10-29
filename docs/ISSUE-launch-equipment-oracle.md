# Launch rollback diagnostic treats equipment Set order as a semantic change

Full CI 593 at `0482eb88a3c549b60bbe382bb21e7d8715ef1bc7` recorded `failedActualLaunchPublicationRollsBackNestedStateAndRetryKeepsOldSnapshots` line 172 rejecting raw changed fields `savedNPCPersistence`, `equipment` and `savedEquipmentInventory`. The retained issue context is `/tmp/elite-full-review-ci-593/issue-context.json`. It reports field names, not equipment array contents, so no particular member order or permutation is established.

`Commander.equipment` is a `Set<String>`. Codable represents that unordered Set as an array, and the diagnostic compares JSON arrays as order-sensitive `NSArray` values after decoding a fresh Commander. Its existing comment acknowledges Set/dictionary ordering, but the whitelist only covers nested equipment inventory representation. The full typed Commander comparison already derives the permitted disk-only NPC-binding normalization from an independent value copy; there is no source contract allowing equipment membership changes at this boundary.

Preserve every failed-publication rollback, old snapshot, blocker byte, native receipt, nested inventory and complete Commander assertion. Preserve the raw field diff and its evidence file. Correct only the diagnostic comparison for the known Set-valued field, with an explicit membership equality check and independent canonical arrays. Do not add equipment to the whitelist or change production serialization/migration.

[Minimal oracle correction](PR-launch-equipment-oracle.md).
