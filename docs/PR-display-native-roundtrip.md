# Expect verified station rebindings and original ordinary actors

## Change and preservation

The exact display save test checks schema 21 and retains its original expected Commander and ordinary NPC bindings. An inout helper copies only the original native world, requires current living station records with matching physical bodies, verifies the same visit and a new actor, then changes only those ledger bindings.

All poses, observations, custody, other systems and other Commander fields remain in full equality. Original hardware identity/provenance, cash, cargo, four missiles, fuel, display cycling and repeat-grant conservation checks remain. No production save rule, actual-state normalization or equality field removal changes.

See [the observed cause](ISSUE-display-native-roundtrip.md).

## Validation and risks

Strict Swift/Markdown lint and diff checks pass; inverse setup transformation reconstructs each affected original test file exactly at `861ab718c06adb841847dca395f1ee5b4e9edf03`. This worker has not compiled or executed the batch. Runtime behavior and full CI acceptance remain unestablished until the integration owner completes validation.
