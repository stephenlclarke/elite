# Streamline developer/reviewer delivery

## Motivation and implementation

Remove contradictory process gates and duplicate review bookkeeping so source development can continue while MBA review and GitHub units run. DEVELOPMENT-WORKFLOW.md is authoritative; the ledger links it, and MBA-TEST-QUEUE.md points to the development PR rather than maintaining another live table. Define the one-comment packet handoff, code-first review, GitHub-executed isolated units, issue correction/verification states and a concrete threshold for the optional issue-only coder.

## Validation and limitations

Markdown lint and git diff whitespace checks pass for the changed documents. The development PR and mba-finding/awaiting-mba labels supply the review loop; queue23 is historical. No application source, test, CI/protection or release setting is weakened. No integration testing is added. Faster throughput is an intended process improvement; no measured delivery speedup is claimed. Related problem note: ISSUE-developer-reviewer-workflow.md.

Workflow measurement uses a dated scorecard and JSON extract from existing ledger/GitHub events, including the earlier72-hour audit as an explicitly approximate cost reference. Feature/fix packets, infrastructure, reviews, GitHub-unit success and usable delivery remain separate. No new developer forms, tests or worker are introduced; early carry-over work does not establish a causal speedup.

The latest simplification uses the per-push PR review request as the sole handoff, removing duplicate queue23/chat comments. MBA owns review/issue/thread closure and Sonar triage; Root batches scorecard updates. The developer never waits for those activities. No code or CI/protection changes are included.

Issue closure is part of each MBA verification batch. Independently verified source/compiler fixes close with correction SHA, existing unit evidence and explicit unreleased scope when no automated actionable finding requires follow-up. Generic review-service errors are non-blocking under the latest human direction: MBA supplies independent final-head PR review, raises actionable issues and verifies corrections. Required GitHub checks and applicable approvals remain mandatory. Open issues state their exact missing evidence or next action; stale awaiting-review labels are removed. Sonar and explicit delivery acceptance remain required where applicable.
