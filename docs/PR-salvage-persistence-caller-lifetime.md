# fix(salvage): separate post-EMP observation frame from archive capture

`persistSalvagePosesInPlace` now consists of the unchanged mandatory `persistEMPState` guard followed by a call to a non-inlined helper. The helper contains the complete original post-EMP ledger/body observation, publication and ordered cold flush body without edits. Both call boundaries are non-inlined so the dormant salvage observation frame is entered after EMP persistence returns.

The outer cold snapshot and rollback are unchanged. No new Game/Commander value candidate, no-EMP shortcut, trust/cache, schema, guard, observation, flush ordering, gameplay, test, concurrency or budget changes are introduced. EMP capture internals, Game and Script source remain with their existing owners.

## Validation

Static correspondence removes only the introduced function boundary and annotations and reconstructs the entire original `FlightWorkTools.swift` byte for byte against `67cdb1be7e9a97b9fe3cbe5680eb5a320c142951`. Strict Swift formatting, paired Markdown lint and whitespace checks are source validation only. No build, test, native probing, GUI, debugger, renderer or profiling jobs were run here; no peak reduction or crash resolution is claimed.

G1 owns one independent review and composition with the separately authored EMP capture repair, one coherent build, then the same unchanged EMP smoke with both arguments first. The two original control/mining issue methods remain held until that smoke passes, and prior qualified results remain retained.
