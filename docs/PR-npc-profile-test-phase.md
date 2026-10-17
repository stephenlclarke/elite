# test(npc): defer profile rejection verification until after setup

## Motivation and implementation

The [fixture lifetime issue](ISSUE-npc-profile-test-phase.md) is addressed by moving the complete post-fixture verification body unchanged into a private helper taking the same `Game` by `inout`. The fixture and production code remain unchanged. No assertions, invalid-state guards, cases, compiler settings or test scheduling are removed or weakened.

## Validation

An inverse-inline check reconstructs the complete original test file byte for byte. The exact old coverage binary and debugger evidence are retained outside the repository. Runtime validation is pending; the original focused test and full `make ci` remain required.

## Compatibility and risks

This changes test scope only and introduces no app, save or mission format change. Further independent failures in the combined suite remain release blockers.
