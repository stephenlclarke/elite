# Issue 173: archival texture fixture

## Motivation

The unfiltered quality run [40043514103](https://github.com/stephenlclarke/elite/actions/runs/40043514103) for PR25 head `ae97d337cb9cf25b58322a21946e9ece297dd60a` failed. Its saved evidence records 62 assertion-bearing methods and a separate terminal SIGBUS. The earlier 19-method and 524-method passes remain limited to their recorded scopes.

## Scope and correction

Remove original rendered texture fields from the archival-metadata fixture. Keep both production dialect validators and all malformed metadata cases unchanged.

Original assertion locations for this group: ShipAppearanceTests.swift:23. The independent full inventory is recorded in `docs/evidence/M01-ae97-terminal-review.json`.

## Validation and compatibility

Source review is complete for the coherent correction batch. Unit execution is pending; these changes are not qualified for integration or release. One combined normal affected-unit batch must retain all 62 methods, including the unresolved moving-debris case. Swift actor ownership, save authority, original data, solver budgets and required quality gates stay unchanged.

## Links and remaining risks

[GitHub issue 173](https://github.com/stephenlclarke/elite/issues/173); [PR25](https://github.com/stephenlclarke/elite/pull/25). The moving-debris sweep remains unresolved; debug-only scalar refusal logging collects its actual query without changing the result. Issue185 remains unattributed. Full coverage, sanitizers, leaks, final review and protected release publication remain pending.
