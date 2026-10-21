# Nested durable save exhausts stack while resolving the script anchor

Focused run 453 at `4399134c851bbc06ac247153b97220fb57b4ea60` crashed with SIGBUS, "Thread stack size exceeded", on a 544 KiB cooperative thread. Its matched report identifies `scriptAnchor` beneath `persistScriptActors`, script publication, candidate completion, timer dispatch and the unchanged durable timer regression. This is a different fault entry from run 447; it does not establish measured success of the earlier EMP repair.

The exact coherent-452 object retained under `/tmp/elite-native-journey-compile-452/snapshot` has SHA256 `d0f6edbf7fdfc9f65386705023dc532b8467e11e4f090867b8a0b60f218afdd9`. G1's relocation-bearing getter disassembly shows dynamic stack probes and separate Commander getter calls for fallback galaxy and system. A small fixed entry reservation is not peak stack usage. No aggregate frame estimate is asserted.

Anchor selection must preserve first live id-zero station preference, refusal of a dead actual station without fallback, and fallback only when the actual station is absent and the saved frame matches galaxy/system with positive station energy. Station condition/loss and reference-frame refresh must still precede anchor resolution; all shot and actor capture must remain in the same order. Publication, rollback, native guards and save representation remain unchanged.

[Repair and validation handoff](PR-script-anchor-stack.md).
