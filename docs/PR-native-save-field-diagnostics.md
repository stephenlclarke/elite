# test: report strict save mismatch fields and pin naval initial cash

## Change

The naval plans reward test now builds the same original game setup locally with explicit1000 initial cash before prepareEquipment. All original reward, provenance, score, payment-history, reload and duplicate-prevention assertions remain exact. The shared factory and every other method are unchanged.

CurrentNativeSaveTestFixture.diskMismatchFacts retains its noninline borrowing failure-only boundary. It compares the union of independently serialized actual/expected top-level fields in sorted order and appends differing key names to the existing two booleans. No values are emitted, no saved projection is changed, and strict disk equality still fails before world checks when unequal. Temporary JSON subtrees exist only on failure and no owned Commander is added across awaits.

## Validation and ownership

Assignment M01-native-save-field-diagnostics: G2 source author, Root coordinator, G1 sole executor/integrator. Exact base5cd68862cc5ac8844fac6a349044a8296259db85; only two test paths plus this paired note set. Source format, Markdown lint, whitespace and original-oracle conservation checks run before freeze. Independent review and matching execution remain pending until recorded in the frozen packet. No author compiler/test/runtime execution.

The only runtime selection is heldBeamDischargesSoundOnConsecutivePositiveFlashSnapshots and MissionEquipmentBridgeTests/originalPlansDeliveryGrantsActualNavalHardwareAndCannotDuplicateAfterReload: two methods/two cases, after G1's UI lease closes. Retain the three1024 freight passes without repetition. No full CI, release, crash attribution, world-validity or passing save claim yet. Compatibility and production schemas/resources/defaults are unchanged. See [motivation](ISSUE-native-save-field-diagnostics.md).
