# Resolve mission actors from the actual required facts

The existing game entry point passes current body, mission instance, installed pack, system and geometry values to private pure helpers. The guards and resulting descriptor retain their original meaning. Fitting checks share the same geometry dictionary and avoid carrying a second whole simulation receiver through nested contact validation.

The exact failing binary and debugger trace are preserved under `/tmp/elite-debug-crash-134`; this is a diagnostic reproduction, not a completed test run or attribution of an earlier unobserved crash. Source formatting passes. Normal component-contact and broad combat validation, compiled frame inspection and `make ci` remain pending. No stack flags, skipped tests, heap-boxed game or relaxed authority guards are introduced. Motivation: [issue](ISSUE-native-actor-resolution-lifetime.md).
