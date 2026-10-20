# fix(rescue): delegate authenticated G08 identities through the legacy field gate

## Change

NativePeopleVersionedSave preserves the existing validation order: G08 fields first at the original schema, then G05 and G04 at their existing lowered schemas. Only the final G04 call receives allowOriginalRescue, computed from the original G08 schema after earlier validation has succeeded. The new argument defaults to false for all existing direct callers.

The G04 nativePerson guard separately verifies the enum, admits only a valid rescue identity when the explicit internal permission is true, and otherwise executes the exact original station validity/batch/canonical/leaf checks. G08 has already checked rescue field presence, exact keys, canonical serialization and the original leaf before delegation; later native claim validation remains mandatory. Invalid, stripped, foreign, forged and lower-schema payloads retain their refusal paths.

The existing authenticated cold-reader test now reads the pristine boarded45 save before any tampering, verifies commander/world validity, G08 claims and full native custody/owner preservation against the pre-save scene. It then requires direct G04 schema41 validation without permission to throw. Every original physical-join and marker tamper mode/assertion remains intact. The existing whole-journey method already round-trips boarded payloads through both45/46 formats.

## Scope, preflight and qualification

Exactly NativePeopleVersionedSave.swift, NativeStationPassengerJourneySave.swift, NativeOriginalRescueRecordTests.swift plus paired notes, based on1b24818f1256a105c38da123d14aeb6aad2907f8. All existing source paths outside this bounded change remain untouched. Full caller/type/access inspection accounts for the coordinator, two existing direct G04 lifecycle-test calls and the new direct legacy-denial assertion. Only the coordinator can enable delegation; the flag is not serialized or exposed as configuration.

Scoped strict Swift formatting, Markdown lint, whitespace and exact original-guard/negative-test conservation checks precede freeze. Root owns one complete independent review; G3 then owns matching compilation and the minimal affected selection, including the existing whole journey and strengthened cold reader. These are two methods/two cases; schema and tamper loops are not new parameterized cases. Other caller qualification follows G3/Root's current execution ledger without replaying unaffected cohorts.

No author compiler/build/test/native probe/runtime, extra review agent, production load oracle, new framework or passing runtime claim. Functional integration and full quality/review/release gates remain pending. See [motivation](ISSUE-original-rescue-schema-delegation.md).
