# Add the Executive Constrictor Hunt and Thargoid Plans

The two naval missions now run from actual docking, combat and spawning events. Commander saves retain the source TP stages with legacy defaults. Paged native briefings, system-data clues, source-derived target geometry/statistics, protected Constrictor weapons, finite ordnance, ECM, pursuit and orphan-drone behaviour connect the objectives to gameplay. Debrief commits stage, equipment and rewards once.

[The pinned source profile](BBC-EXECUTIVE-MISSIONS.md) records thresholds, coordinates, rewards, source routines/hashes, the removal-completion and register-wrap quirks and remaining engine/presentation parity limits. Native steering, RNG, clock, collision and dialogue are independent; no original-binary outcome parity is claimed.

Validation covers boundary/workflow fixtures, commander persistence, wrong-order and repeated docking, clues, target uniqueness, military-laser damage, bomb resistance, missiles/ECM, finite drone releases, energy fitting, messages/help and both new hull silhouettes. `make ci` supplies coverage and sanitizer/leak gates; committed main supplies the exact-SHA Sonar analysis. README controls and the historical checklist are updated, and renderer-generated media is regenerated.

Request: [ISSUE-executive-missions.md](ISSUE-executive-missions.md).

Final local validation, including the trackpad changes: 56 tests, 92.99% Swift coverage across every source file, passing Thread/Address Sanitizer runs and zero leaked bytes from the native mission/frame probe.
