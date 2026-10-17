# test(targeting): separate target-removal scenario lifetimes

> Current controls (FR-008): Tab alone selects flight targets. R references below describe historical source or validation evidence; they are not current flight instructions. Archived input/evidence records are retained unchanged.

The original target-removal test kept later fixture storage in its caller while constructing the first locked game. It failed alone under the unchanged baseline TSan binary at checkpoint 174. The test now calls `verifyThirdPartyRemoval(mode:)` for modes 0 through 2, followed by `verifyManualTargetCancellation()`. See [the issue and evidence qualification](ISSUE-target-removal-fixture-lifetimes.md).

## Preservation and validation

Both helpers contain the original bodies without behavioral edits. Inlining them at their original positions reconstructs the whole pre-change file exactly, including the unchanged `lockedGame` factory and the other two original tests. All original assertions, R/Q input, ticks and scenario order remain. No Core source, rendering algorithm, target policy, skip, stack flag, serialization or boxed Game state changes.

Strict Swift source lint, Markdown lint and whitespace checks pass. The actual pre-change 174 proof records source `e9ee7ef43a5d93776acb698dc9f63a0dd393d643`, signal 4 and raw log SHA256 `432d40d8e031cdf4b073f7c94c4b53a9ef23f4984774f776a3309ab34b93c65c`. Protected inputs were unchanged and owned processes were closed. Debugger checkpoint 173 identified the actual nested targeting/visibility path; no matching original 172 OS report establishes equivalence.

The new source has not been compiled or executed. Actual compiled frame inspection, the original focused target-removal test, related scenarios and final composed `make ci` remain required. Source lifetime separation is not a measured stack reduction or a passing runtime result. Completed external review, final-head checks and protected merge remain separate release gates.
