# Issue 182: work scene geometry

## Motivation

The unfiltered quality run [40043514103](https://github.com/stephenlclarke/elite/actions/runs/40043514103) for PR25 head `ae97d337cb9cf25b58322a21946e9ece297dd60a` failed. Its saved evidence records 62 assertion-bearing methods and a separate terminal SIGBUS. The earlier 19-method and 524-method passes remain limited to their recorded scopes.

## Scope and correction

Use an explicitly compatible conventional work hull and a naturally RRS-free world for the deliberately single-target/small-obstacle scenes. Keep actual scoop, spin, actor, steering, cutter and clearance assertions.

Original assertion locations for this group: FlightWorkGuidanceRuntimeTests.swift:1006, FlightWorkGuidanceRuntimeTests.swift:1032, FlightWorkGuidanceRuntimeTests.swift:1084, FlightWorkGuidanceRuntimeTests.swift:1085, FlightWorkGuidanceRuntimeTests.swift:242, FlightWorkGuidanceRuntimeTests.swift:319, FlightWorkGuidanceRuntimeTests.swift:320, FlightWorkGuidanceRuntimeTests.swift:321, FlightWorkGuidanceRuntimeTests.swift:322, FlightWorkGuidanceRuntimeTests.swift:323, FlightWorkGuidanceRuntimeTests.swift:326, FlightWorkGuidanceRuntimeTests.swift:369, FlightWorkGuidanceRuntimeTests.swift:419, FlightWorkGuidanceRuntimeTests.swift:423, FlightWorkGuidanceRuntimeTests.swift:445, FlightWorkGuidanceRuntimeTests.swift:471, FlightWorkGuidanceRuntimeTests.swift:483, FlightWorkGuidanceRuntimeTests.swift:714, FlightWorkGuidanceRuntimeTests.swift:715, FlightWorkGuidanceRuntimeTests.swift:716, NativeMissionWeaponGeometryTests.swift:109, NativeMissionWeaponGeometryTests.swift:76. The independent full inventory is recorded in `docs/evidence/M01-ae97-terminal-review.json`.

## Validation and compatibility

Source review is complete for the coherent correction batch. Unit execution is pending; these changes are not qualified for integration or release. One combined normal affected-unit batch must retain all 62 methods, including the unresolved moving-debris case. Swift actor ownership, save authority, original data, solver budgets and required quality gates stay unchanged.

## Links and remaining risks

[GitHub issue 182](https://github.com/stephenlclarke/elite/issues/182); [PR25](https://github.com/stephenlclarke/elite/pull/25). The moving-debris sweep remains unresolved; debug-only scalar refusal logging collects its actual query without changing the result. Issue185 remains unattributed. Full coverage, sanitizers, leaks, final review and protected release publication remain pending.
