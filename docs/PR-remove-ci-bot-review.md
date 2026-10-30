# docs: remove mandatory bot review from delivery

Update AGENTS.md and both current README review descriptions. Independent review remains mandatory, including dependency and tap PRs. CI and the delivery workflow no longer request bot reviews or wait for them. Existing actionable findings still require correction and independent review. Required final-head checks, approvals and branch protection remain unchanged.

A targeted source search confirms zero request calls in `.github` and `Tools`, so no workflow code or permissions change is needed. The preceding gallery/source/results reviews remain valid; this child changes only documentation. Markdown and whitespace checks apply. No compiler, native execution, bot request or release is performed by this correction. See [the issue](ISSUE-remove-ci-bot-review.md).
