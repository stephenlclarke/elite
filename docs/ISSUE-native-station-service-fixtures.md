# Station service fixtures use a non-launch key and lack a snapshot directory

## Evidence and required correction

Checkpoint 216 reports launch/manual-cancel cases still docked and a missing directory enumerator in the main-arrival test. Space only dismisses the title/game-over screen; docked launch is key 0. The temporary storage constructor creates only its root, and the original main doorway receipt path does not automatically write a save generation, so its nested save directory need not exist.

Use the actual launch input, retaining manual cancellation and every stale-authority assertion. Explicitly create the exact main-arrival test directory for the existing strict file snapshot. Keep genuine doorway entry, typed destinations and all guards; no Core geometry or authority bug is established by these failures.

## Validation and limits

Strict Swift/Markdown lint and diff checks pass. Source reversal verifies the bounded changes preserve the rest of the original test files. No compilation or execution occurred in this worker; checkpoint 216 remains failed evidence. Focused execution and required composed `make ci` remain with the integration owner. See [the implementation](PR-native-station-service-fixtures.md).
