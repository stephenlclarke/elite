# Record failure-only state at the native EMP flight boundary

This diagnostic changes one shared test helper and this paired handoff only. A single local Boolean holds the unchanged flight-continuation condition. Its required-true assertion remains; a failure-only string records primitive state and labels the existing target range as pre-tick. No whole Game/Commander dump, side-effectful query, health/gear adjustment, teleport, actor deletion, simulated-time edit or budget waiver is added.

The proposed diagnostic execution selects the two existing EMPTravelAndSecurity methods (three cases) using coverage/debug/default parallelism, the original 600-second command and 640-second supervisor. Source formatting, parsing, Markdown lint, whitespace and exact diff/hash checks precede review. Execution is pending source review; this leaf identifies the cause and does not claim to fix it. Preserved passing 335 and failed 337 executables remain untouched.

[Issue](ISSUE-emp-native-flight-diagnostics.md).
