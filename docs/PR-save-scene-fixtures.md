# Preserve genuine save scenes and compare only expected station rebindings

## Implementation

The timed mission failure test keeps its native launch scene, advances the same 0.1-second tick, selects system 129 and uses the actual arrival path before its original docking and save/load sequence. A precondition verifies the destination and physical anchor system. Original failed status, completed count, no-reward and invalid retry transition assertions remain.

The jump-limit test starts with its original expected Commander and the existing NPC-binding adjustment. Its private helper copies the saved native world, requires matching physical bodies for every current living station, verifies current system, same saved/current visit and a new actor, then rebinds only those ledger records. Original poses, revisions, custody, observations, other systems and all remaining world fields stay in the full Commander equality comparison. See [the diagnostic cause](ISSUE-save-scene-fixtures.md).

## Validation, compatibility and risk

No production save/scene validation, actual loaded state or assertion outcome changes. Inverse setup transformation reconstructs every original follow-up test file exactly; strict Swift/Markdown lint and diff checks pass. Focused attempt 204 failed compilation before any test because Swift Testing consumed the helper's explicit borrowed parameter. The correction passes the same existing test value as inout, matching the compiled solar-world helper, and changes no assertion. Failure proof `/tmp/elite-focused-batch-204/agent-game-test-verification-204.json` retains raw log SHA256 `5c7c21276299c9d1adfb568e0728daeb208c96826cc99a4223ee12f531bdc6ce`, protected-input conservation and process closure. The combined focused retry and required composed `make ci` remain pending; source preservation does not establish runtime success.
