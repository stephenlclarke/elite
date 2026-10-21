# Ore-motion fixture inherits a hull without its required mining utility

## Source prerequisite

actualMinedOreGame in MiningOreRuntimeTests starts from the current SH025 commander, prepares equipment and grants a Mining Laser at the mining utility slot. SH025 declares no native mining work tool, so the owned fitting context does not support that utility. SH023 explicitly declares Mining and Salvage work tools. The earlier runtime fixture failure1204 established the same unsupported-slot boundary.

These four ore-motion/custody/save cases must exercise the changed fresh-output dependencies, so do not knowingly run them with an unsupported initial fit. Choose the supported initial SH023 and its actual fuel capacity before the existing equipment preparation. Preserve all native fitting checks and all actual test actions and oracles.

## Scope and acceptance

Reuse only the identical initial helper hunk already present in the separate private G12 owner. Do not import that owner, its whole test file, product hooks or other source. Only MiningOreRuntimeTests.swift and these paired notes change. G1 obtains matching native qualification of the four existing methods, then one complete independent three-path bugs/performance/style review. No source check implies native PASS. See [the implementation handoff](PR-mining-ore-supported-fixture.md).
