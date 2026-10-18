# Retain the validated native catalogue before legacy EMP custody

The real launch producer `nativePhysicalActorState` creates an ordinary legacy hull with an implicit native catalogue alias. Its first partial EMP pulse records catalogue-backed electrical recharge while leaving that alias implicit. Ordinary NPC snapshots explicitly validate the same native-hull fallback. On a later zero-power pulse, custody captures `EMPStoredObject` before the disabled-hull constructor pins the catalogue, but that stored-object guard requires an explicit catalogue whenever legacy recharge exists. The current producer therefore cannot satisfy its strict later custody guard.

Diagnostic 340 confirms the ordinary Cobra emitted one real pulse but refused another release, then died during its third charge. Those observations alone do not identify a particular guard; source inspection independently establishes this producer/validator mismatch. Exact failed binaries and original native inputs remain preserved. The security case's full shields and native UI's old timing assumptions are separate concerns.

Pin the same already-resolved validated native catalogue on the private pulse candidate before partial persistence or zero custody capture. Support retained partial aliases with an existing correct recharge as well as first hits. Preserve explicit known catalogue IDs, reject unknown IDs or mismatched recharge, and retain every owner, geometry, resource, atomicity, snapshot and custody guard. No loader/global adoption/validator changes or production balance adjustment.

[PR handoff](PR-emp-legacy-native-catalogue.md).
