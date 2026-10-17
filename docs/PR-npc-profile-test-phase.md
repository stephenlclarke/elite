# test(npc): defer profile rejection verification until after setup

## Motivation and implementation

The [fixture lifetime issue](ISSUE-npc-profile-test-phase.md) is addressed by moving the complete post-fixture verification body unchanged into a private helper taking the same `Game` by `inout`. The fixture and production code remain unchanged. No assertions, invalid-state guards, cases, compiler settings or test scheduling are removed or weakened.

## Validation

An inverse-inline check reconstructs the complete original test file byte for byte. The exact old coverage binary and debugger evidence are retained outside the repository. The unchanged original test passed in the focused coverage-enabled run at `53a3ebe569c9bcf1d0226587521969d0f248bed8` (14.64 seconds to compile; 9.463 seconds to execute). Protected source, commander save, preferences and process closure were independently checked. The full `make ci` gate remains required; this focused pass does not accept the release.

## Compatibility and risks

This changes test scope only and introduces no app, save or mission format change. Further independent failures in the combined suite remain release blockers.
