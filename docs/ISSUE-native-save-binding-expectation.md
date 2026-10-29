# Strict save expectations omit wanted-career craft binding phases

## Actual evidence

Actual1027 passed the naval consumer including real save/cold restore and no duplicate reward. The audio consumer failed strict disk commander equality; the failure-only serialized key diagnostic listed equipment, savedEquipmentInventory and savedWantedCareers. World validity and consistency requirements were not reached, and there was no crash or unknown outcome. Preserve actual1024/1027 failures and the qualified three freight cases separately.

## Source cause

GameRuntime.prepareNativeSaveState validates/prepares equipment, mirrors it and retains the live commander; finishNativeSaveState clears both NPC scene bindings and optional wanted-career craft bindings only on the disk copy. The fixture independently expected NPC binding removal but omitted wanted binding removal. Authentic cold load restores the saved NPC scene, then reconciles wanted careers against that admitted ledger; the independent expected cold commander omitted reconciliation.

Serialized key inequality is not proof of semantic equipment corruption. Commander.equipment is a Set, and inventory ComponentTemplate.requiredAxes/compatibleFeatures and ComponentInstance.features also contain Codable sets. JSON sortedKeys sorts object keys, not synthesized set arrays. The publication/read source does not mutate current equipment after the independently verified live preparation. Keep the full typed commander equality and add strict typed equipment/inventory requirements rather than deleting, normalizing or overwriting any equipment facts.

## Scope and acceptance

Root assigned G2 only CurrentNativeSaveTestFixture.swift plus paired notes. Base1bb63ab975b00b19638c9b77e66c47ffb10bdd1a preserves reviewed diagnostics and the separately qualified naval leaf; that test remains untouched. Correct independent expected disk/cold phases using existing domain primitives and original input/scene data, never actual stored/published values. Preserve native condition, item identities/modules, all strict world/hash/schema/audio/reload checks and no-extra-file oracles. One coherent independent review precedes G1 matching build and both existing helper consumers, with no author runtime or passing freight/earlier cohort replay. Root/G1 own central ledger and integration. See [handoff](PR-native-save-binding-expectation.md).
