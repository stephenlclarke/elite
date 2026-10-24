# Issue 175: physical hull constraints

## Motivation

The unfiltered quality run [40043514103](https://github.com/stephenlclarke/elite/actions/runs/40043514103) for PR25 head `ae97d337cb9cf25b58322a21946e9ece297dd60a` failed. Its saved evidence records 62 assertion-bearing methods and a separate terminal SIGBUS. The earlier 19-method and 524-method passes remain limited to their recorded scopes.

## Scope and correction

Use the actual zero-hold SH040 for cabin refusals. Keep all whole-Commander atomicity, ownership, item and transfer assertions.

Original assertion locations for this group: OwnedEquipmentHullTests.swift:217, OwnedEquipmentHullTests.swift:220, OwnedEquipmentTests.swift:56, PassengerCabinGradesTests.swift:299, PassengerCabinGradesTests.swift:303, ShipAccommodationTests.swift:94. The independent full inventory is recorded in `docs/evidence/M01-ae97-terminal-review.json`.

## Validation and compatibility

Source review is complete for the coherent correction batch. Unit execution is pending; these changes are not qualified for integration or release. One combined normal affected-unit batch must retain all 62 methods, including the unresolved moving-debris case. Swift actor ownership, save authority, original data, solver budgets and required quality gates stay unchanged.

## Links and remaining risks

[GitHub issue 175](https://github.com/stephenlclarke/elite/issues/175); [PR25](https://github.com/stephenlclarke/elite/pull/25). The moving-debris sweep remains unresolved; debug-only scalar refusal logging collects its actual query without changing the result. Issue185 remains unattributed. Full coverage, sanitizers, leaks, final review and protected release publication remain pending.
