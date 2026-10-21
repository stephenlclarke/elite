# Three current control and cue expectations predate approved behavior

CI 612's exact inventory records three Q-message failures at `FlightWorkGuidanceRuntimeTests.swift:715`, one initial EMP-display failure at `FlightWeaponSnapshotTests.swift:13`, and five hostile-salvage cue failures at `TargetColourCueTests.swift:151`. The raw log shows `MANUAL CONTROL - RELEASE HOLD`, `READY`, and `.recoverable` respectively. This correction uses parent `4553add250145b1b9702f33bd2cb83565a8fa9c9`; the control sources remain unchanged from the run.

Actual Q release uses the generated release-hold label in its message and still preserves momentum. Approved `b20e6cf0` keeps an idle trigger ready instead of inventing a fresh-Return stop. The wanted-board cue contract explicitly preserves orange priority for qualified disabled/recoverable objects, red missiles and purple eligible wanted careers. The five salvage cases are abandoned cargo/technology/module/drone/empty-pod metadata on a non-NPC cargo actor, not a purple wanted career. Other ownerships retain hostile red.

The separate Commander equality failures at lines 816/819 concern refused dock/arrival persistent state. They are reserved for G2 and remain untouched; no save/atomicity waiver is inferred from the control findings.

[Minimal test-only correction](PR-control-cue-oracles.md).
