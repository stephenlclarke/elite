# Draw alien seekers with a shared forked collision mesh

Alien seekers now use a closed swept three-prong body with two real notches. Its dimensions follow the stock missile envelope. The actual physical ordnance profile selects this mesh before catalogue or hull fallbacks, and gameplay mesh overrides publish the same mesh for collision consumers. Standard missiles and plasma retain their existing geometry. No new hull or catalogue identity, palette, threat cue, speed or damage is introduced.

Focused regression source checks finite closed geometry, consistent edge winding, positive signed volume, profile selection and override agreement. A grid of actual GameplayRaycast queries compares the fork and stock silhouettes. Drawing-command tests exercise all three existing styles, distinct geometry and preserved hostile classification; white wireframe remains white. These are mesh/render/raycast tests, not evidence of loot, PLUGH fitting, ammunition launch or native flight.

## Validation and limits

Worker checks are strict source formatting lint, scoped Markdown lint and whitespace checks only. No compile, typecheck, test execution, native process, media generation, CI or publishing ran while the central validation lease was active. Tests remain uncompiled and unexecuted. Coder 1 owns integration and runtime verification. The mesh is immutable and cached once; no save or ownership schema changes are required. See [motivation](ISSUE-alien-missile-silhouette.md).
