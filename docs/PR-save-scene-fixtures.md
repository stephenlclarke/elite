# Preserve genuine save scenes and compare only expected station rebindings

## Implementation

The timed mission failure test keeps its native launch scene, advances the same 0.1-second tick, selects system 129 and uses the actual arrival path before its original docking and save/load sequence. A precondition verifies the destination and physical anchor system. Original failed status, completed count, no-reward and invalid retry transition assertions remain.

The jump-limit test starts with its original expected Commander and the existing NPC-binding adjustment. Its private helper copies the saved native world, requires matching physical bodies for every current living station, verifies current system, same saved/current visit and a new actor, then rebinds only those ledger records. Original poses, revisions, custody, observations, other systems and all remaining world fields stay in the full Commander equality comparison. See [the diagnostic cause](ISSUE-save-scene-fixtures.md).

## Validation, compatibility and risk

No production save/scene validation, actual loaded state or assertion outcome changes. Inverse setup transformation reconstructs every original follow-up test file exactly; strict Swift/Markdown lint and diff checks pass. This worker has not compiled or executed the batch. The integration owner retains focused tests and required composed `make ci`; source preservation alone does not establish runtime success.
