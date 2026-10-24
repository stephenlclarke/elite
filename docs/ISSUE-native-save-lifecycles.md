# Align equipment fixtures and retained-flight save tests with actual contracts

Validation 318 completed 51 methods, with 46 passing and five failing. One shared fixture sent current typed equipment through the legacy-only raw loader. Two save tests correctly restored active flight but then expected a new visit from a launch command while already flying. Diagnostic 319 proved the remaining historical format-21 mismatch consists of three stock display mirrors written explicitly during current publication; canonical gear and every other typed state comparison match.

Construct the current typed fixture directly without weakening raw-loader rejection. Exercise retained flight, then an explicit actor docking command and launch before asserting new visit and reference bindings. Specify the historical stock mirrors independently before save, preserving the complete migrated Commander, original gear identities, resources, calendar and file checks. Logical actor docking in these tests does not establish swept physical docking.

[PR-native-save-lifecycles.md](PR-native-save-lifecycles.md).
