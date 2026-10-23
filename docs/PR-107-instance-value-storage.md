# PR 107: private mission-instance value storage

The private `ScriptInstanceValue` now stores one reference to its 51-field heap payload. Its four identity fields remain read only. All 47 mutable properties detach shared backing before assignment or `_modify`. The shared clone allocates its destination first and copies each field through a separate noninline helper. The existing one-element Array and public API remain.

Equality compares every original member in declaration order without an identity shortcut, preserving NaN behavior. Explicit codec helpers keep the original 51 keys, 14 required fields and 37 optional omissions. The nine former raw-offset queries use ordinary facade reads with the same owned outputs. No cache or query authority is added.

The maintained Python gate now inventories the actual logical payload and verifies equality order, every mutable projection, clone coverage and codec paths. All 22 Python unit methods pass, including negative per-field omission and detach fixtures. The five additional Swift methods cover 37 optional null keys, large native fields during contract mutation, throwing nested inout, NaN and signed zero, and supplied/actor/caller snapshot isolation. Existing instance, cargo and settlement query tests retain their original oracles.

Production and gate source review is clear. Swift tests, native compilation and emitted layout/clone proof are pending G1's executor lease; this checkpoint makes no native PASS claim. G1 owns composition into PR 107, affected execution, required CI and release. MC1 retains correction ownership for findings. See [issue 112](https://github.com/stephenlclarke/elite/issues/112) and its [packet note](ISSUE-112-instance-value-storage.md).
