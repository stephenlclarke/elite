# Correct alien missile damage relative to standard missiles

The alien seeker runtime profile now derives speed and damage as 1.25 times the standard missile profile: speed remains 990 and damage becomes 312.5. The salvage missile specification reads both values from the runtime profile, replacing duplicate constants. Guidance, ECM resistance, range, lifetime and other weapon values remain unchanged.

A focused ratio contract checks the standard baseline, both 25% advantages and specification/runtime agreement. An additional parameterized regression uses the existing ordnance fixture and production advanceOrdnance collision/combat path for standard and alien missiles. It checks actual travel, an attributed impact on a surviving hull, exact remaining hull energy and no second damage on repeated advancement. This is not evidence of alien salvage, PLUGH fitting or real ammunition launch; those paths remain with the central integrator.

## Validation and compatibility

Only source formatting, strict Swift formatting lint, scoped Markdown lint and whitespace checks are permitted in this worker slot. No compile, typecheck, tests, native process, media generation, CI, publishing or release ran. The regression source is uncompiled and unexecuted; Coder 1 owns execution after the active validation lease closes. No save schema or owned ammunition identity changes are introduced. Active saved alien ordnance resolves the corrected profile when resumed. See [motivation](ISSUE-alien-missile-relative-strength.md).
