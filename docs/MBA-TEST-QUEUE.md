# Reviewer entry points

Follow the [developer/reviewer workflow](DEVELOPMENT-WORKFLOW.md). The [completion ledger](COMPLETION-LEDGER.md) is the sole work plan. The active development PR contains the single per-packet handoff and automated review; GitHub issues hold actionable findings, and Actions holds unit results.

MBA reviews new diffs, automated findings and actual GitHub results, then verifies corrections and closes their PR threads/issues. Sonar triage uses completed main analyses only. Issue23 and earlier local-test records remain historical evidence; no new duplicate queue comments or routine local test runs are required. Keep no live assignment table here.

After each verification batch, reconcile covered issues immediately under the workflow closure rule. Keep only genuine outstanding acceptance work open; source-fix closure does not waive PR merge/release gates.

Human direction: ignore generic Codex service errors. MBA owns independent review of the actual PR, raises actionable issues and verifies corrections. Reuse prior packet reviews; cover remaining changed code and interactions once. A clean final-head MBA review replaces the unavailable automated outcome, while required GitHub checks/approvals and actual code-finding dispositions remain mandatory.
