# Refuse uncommitted source in authoritative Sonar analysis

The Sonar entry point reuses the distribution source-checkpoint guard, including its maintained-source path policy. It pins the initial commit, verifies its required format, and repeats the branch and source checks after coverage. Only that original commit is passed to the scanner. Distribution keeps its existing default behavior; its guard accepts an action label for accurate analysis errors.

Nine offline test methods exercise the actual entry point in temporary Git repositories with local settings, coverage and scanner fixtures. They cover all maintained path categories, ignored build outputs, tracked changes, and changes to source, branch or clean HEAD during coverage. The ordinary distribution test target discovers them, so the combined quality gate also executes them.

Source implementation is ready for focused validation and independent review. The pre-fix regression, focused results and final integrated quality gate will be recorded after execution. No authoritative Sonar scan is performed from this feature branch. Motivation: [issue handoff](ISSUE-review-source-guard.md).
