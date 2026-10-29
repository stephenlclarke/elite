# Context player velocity fallback copies Commander on a deep admission stack

Actual focused run 513 at `6f9293c151af8c22ac527194e207509e836cca21` exhausted its stack after actor projection. The exact owned report is `/tmp/elite-native-journeys-focused-513/swiftpm-testing-helper-2026-10-19-002519.ips`, SHA256 `05957049240280c4a591dd07e0b7aba877d4d54ddbf5aea085aab8d29969d286`, helper PID 47886. It identifies `initializeWithCopy for Commander`, `Game.commander.read`, the lazy `flightWorldVelocity` fallback, context tail/player assembly and actual mission admission. Verification is `/tmp/elite-native-journeys-focused-513/agent-game-test-verification-513.json`, SHA256 `637a3ce1a56269a3b449975cc7d941815e4fcbbadd9bc0d93f45c397fabe0ef5`.

Game already stores Commander in checked COW storage and exposes `_read`/`_modify`; do not change that layout or accessor. Address lazy receiver/capture and temporary overlap across the complete player and tail phase. Preserve guidance/braking/current-pose priority, exact world velocity, fresh performance/cargo/identity/mining/system/seed reads, every actual context field, all protection/budget semantics and caller authority. No reused stale pose, synthetic state, cached trust, schema, test, stack or concurrency workaround is authorized.

Scene tests from 512 passed five methods/five cases; other existing EMP, cadence/geometry and measured graphics evidence remains separately qualified. The new deep-stack failure is not permission to rerun unrelated accepted scopes or claim broader acceptance.

[Repair and focused validation handoff](PR-gameplay-player-tail.md).
