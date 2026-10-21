# Diagnose three existing native save callers without changing their oracles

Validation 316 completed 48 methods: 44 passed and four failed. Three failures involve existing NPC and absent-salvage save callers. Two attempted to decode the saved file directly as Commander and reported a missing name key; one complete live Commander equality failed; the undocked NPC save/reload path raised invalidCommander. These observations do not yet distinguish an actual publication defect, policy transition or obsolete raw-file assumption.

Preserve the exact failed build and original assertions. Measure the same private NPC fixture and the original empty-salvage fixture through prepare, dock, actor initialization, actual save, the official versioned/raw reader and actor load. Record complete-value equality, supplemental encoded field deltas, file schema/type and actual world/Commander guards. Do not repair input, default failed fields or normalize the expected Commander.

[PR-native-save-caller-diagnostics.md](PR-native-save-caller-diagnostics.md).
