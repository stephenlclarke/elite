# Capture actual historical save mirror changes without changing the oracle

Diagnostic 319 completed the original method under default TSan concurrency. The unchanged whole-Commander assertion failed as expected. Typed inventory, purchase history, mining, calendar, flight, NPC registry, salvage, cargo and laser getter values were equal. Exactly three semantic encoded fields changed: the basic hyperspace-drive equipment label was added, the implicit front pulse laser became an explicit mount, and the implicit zero storage-unit count became explicit zero. Inventory encoding order differed while typed inventory equality remained true.

The complete report and exact compiled artifacts are preserved in `/tmp/elite-historical-save-mirror-diagnostic-319`, with terminal verification in `agent-game-test-verification-319.json`. The diagnostic is evidence of the cause, not a passing gate. The temporary observation helper is removed by the separately documented native save lifecycle repair, which specifies these three expected mirrors independently before saving and retains whole-value equality.

[ISSUE-historical-save-mirror-observation.md](ISSUE-historical-save-mirror-observation.md).
