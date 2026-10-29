# Trackpad runtime fixture inherits a different native hull

Required quality run 39517752658 on committed 5b8f02f4 reported exactly three assertions in trackpadHoldsTurnOrThrustEveryFrameAndReleaseStabilizesAtCruisingSpeed at TrackpadTests.swift:86, :91 and :97. These concern the expected speed32, braking to20 and turn rates greater than0.4 in magnitude. Other reported market/courier/targeting failures belong to a separate owner and are outside this change.

The method constructs the current default Game, now SH025 through OriginalWorlds/authoring.toml and NewCommanderDefaults. SH025 native speed34.3, acceleration9.1, pitch0.7 and roll0.79 differ from the fixture's original stock-Cobra calibration. Its original one-second brake therefore reaches25.2, and the two-finger average0.8 maps to direction0.473684, pitch0.331579 and roll-0.374211. All three reported failures follow from that stale hull premise.

SH023 native speed32, acceleration12 and pitch/roll1 preserve the original numeric witnesses. Explicitly select that hull and initialize fuel/energy/shields coherently before launch, without changing input mapping, runtime behavior or any original expectation. Inherited SH025 fuel130 must become the selected hull's native70 for a valid fixture. See [the bounded correction and qualification](PR-trackpad-native-hull.md).
