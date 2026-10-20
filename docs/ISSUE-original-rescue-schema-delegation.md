# Valid G08 boarded rescue saves fail the older station-passenger field gate

## Actual failure and source cause

The G08 whole journey failed ScriptSaveStore.read at the boarded, non-Alien round trip. NativePeopleVersionedSave first validates G08 fields using original schema45/46, then lowers the schema through G05 and G04. G04's nativePerson berth guard requires person.station.valid. A valid NativePersonReference.rescue deliberately has no station identity, so this older guard rejects the already authenticated rescue payload.

The existing rescue cold-reader negative test writes an actual boarded save but never reads the pristine version before tampering. Every negative variant could therefore pass because the underlying valid save already failed. Keep every existing tamper assertion and establish the positive baseline first.

## Bounded correction

Add an internal allowOriginalRescue parameter defaulting to false on the G04 field validator. Only the coordinator passes true, after successful original-schema G08 validation and only when that original schema is45/46. The G04 rescue branch still requires rescue.valid; all other native-person cases retain the original station validity, batch, canonical representation and leaf guards. No schema number, serialized field, lower-schema/stripping policy or blanket foreign-person bypass changes.

In the same existing cold-reader method, require a pristine top-level read with valid native claims and preserved full source custody/owner identity before tampering. Also prove that calling the G04 validator directly with schema41 and no permission still rejects those pristine rescue bytes. This makes the negative checks discriminating while proving the legacy default remains closed.

## Ownership and gates

Root assigned G2 two production files, the existing NativeOriginalRescueRecordTests method and paired notes on frozen1b24818f. G3 owns matching compilation and minimal runtime after its current job closes. One independent full-delta review precedes execution. No author compiler/build/test/probe or new framework, feature, population rule or schema. See [handoff](PR-original-rescue-schema-delegation.md).
