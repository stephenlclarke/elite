# Display options expect cleared ordinary NPC bindings after versioned loading

## Evidence and required correction

Checkpoint 216 reports full Commander equality failing in the XYZZY display/grant test. Its expected state clears ordinary NPC bindings, while schema 21 loading restores those same physical actors from the retained scene. Loading also allocates fresh station actors and updates their current ledger bindings.

Pin the versioned schema, retain original ordinary NPC bindings and derive only the station rebindings from the original saved native world and actual matching restored physical actors. Preserve full Commander equality and all grant/progression assertions; do not remove the native world or copy actual state wholesale.

## Validation and limits

Strict Swift/Markdown lint and diff checks pass. Source reversal verifies the bounded changes preserve the rest of the original test files. No compilation or execution occurred in this worker; checkpoint 216 remains failed evidence. Focused execution and required composed `make ci` remain with the integration owner. See [the implementation](PR-display-native-roundtrip.md).
