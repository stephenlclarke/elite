# Reduce Commander temporaries in synchronous script snapshot construction

Focused run 320 compiled successfully but ended in an owned native crash during the original hull-change observer method. Its report identifies a stack-guard protection fault while copying Commander in Game.commander.read, called by scriptSnapshot through scopedScriptSnapshot, drainScriptEvents, emitScriptEvent, confirmShipTrade and the original native key path. The exact 699 compiled artifacts, raw report, image identities and process-start evidence are retained. SwiftPM reports signal 4; the OS report also contains SIGILL and a bus-error termination. Preserve those observations without equating them to a race or another historical crash.

The snapshot dictionary expands thirteen read-only Commander expressions through the computed Game.commander accessor in one synchronous frame. Move these unchanged fields into a Commander borrowed-self helper, then compose the same game and nested-query fields. Keep Swift 6 ownership, original native actions, query semantics, event ordering, default test concurrency and stack sizes unchanged.

The same focused run separately found that the cargo-expansion refusal fixture fills exactly the current SH023 native 30t hold. Storing its expansion is legal at 30t. Set its cargo to the independently checked native hold plus one tonne, retaining the expected refusal and full property preservation.

[PR-script-snapshot-stack-lifetime.md](PR-script-snapshot-stack-lifetime.md).
