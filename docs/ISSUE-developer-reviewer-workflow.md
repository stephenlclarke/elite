# Developer/reviewer workflow delays

## Problem and behavior

Repeated policy additions conflict with older ledger instructions. Review state is duplicated between chat, ledger and a queue file. Packet boundaries and spare-coder activation were ambiguous, and code review could wait behind MBA compilation. Corrections could also be closed before independent verification.

Use one current workflow document and the development PR. MBP pushes small coherent packets without waiting; MBA reviews diffs while GitHub runs isolated units, reports root-cause findings and verifies corrections. GitHub-owned isolated unit execution and documentation-only exemptions reduce repeated local build work. GitHub labels distinguish actionable defects and corrections awaiting MBA review; the optional coder handles only a real ready issue backlog.

## Compatibility and validation

This changes documentation and GitHub coordination only, with no game code, save representation, test assertions or branch protections changed. Markdown lint and diff whitespace checks pass. Existing source remains on its development/checkpoint refs. No integration test or application acceptance is claimed. Current review: [development PR #25](https://github.com/stephenlclarke/elite/pull/25); queue23 remains historical.

Workflow measurement uses a dated scorecard and JSON extract from existing ledger/GitHub events, including the earlier72-hour audit as an explicitly approximate cost reference. Feature/fix packets, infrastructure, reviews, GitHub-unit success and usable delivery remain separate. No new developer forms, tests or worker are introduced; early carry-over work does not establish a causal speedup.

The latest simplification uses the per-push PR review request as the sole handoff, removing duplicate queue23/chat comments. MBA owns review/issue/thread closure and Sonar triage; Root batches scorecard updates. The developer never waits for those activities. No code or CI/protection changes are included.
