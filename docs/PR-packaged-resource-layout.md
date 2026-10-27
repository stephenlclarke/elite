# Verify the actual SwiftPM copied resource layout

The verifier now preserves OriginalShipTextures, OriginalFleetShowroomModels and OriginalMarkets alongside its five existing copied directories. Its shared constant is checked against the literal resource-copy declarations in Package.swift. Resource enumeration and exact byte comparison are unchanged; processed files still use their existing flattened paths.

The regression fixture includes the actual failing SH084.json path and the other two omitted directory families. Existing tests exercise both bundle layouts, missing and altered resources, and rejected flattened aliases. The valid nested-resource regression fails on the original verifier in both layouts. Focused unit results are recorded with the owner handoff; no native compiler, app launch, packaging or signing runs are needed for this Python-only correction.

The signed local preview 1215 was already packaged with an external checker. It is not rebuilt or modified by this maintained-source repair. G1 remains the sole integrator; one independent bugs/performance/style review precedes integration, with final required CI and PR review unchanged.
