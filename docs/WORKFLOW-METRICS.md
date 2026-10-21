# Workflow progress scorecard

The Orchestrator measures whether the single-developer/asynchronous-review workflow produces more completed game work with less waiting and rework. The [main ledger](COMPLETION-LEDGER.md) remains the sole work-packet authority. [Measurement snapshots](metrics/workflow-progress.json) are derived observations, not another work plan.

## Measures and decisions

| Measure | Definition and source | What it changes |
| --- | --- | --- |
| Game-code throughput | Unique coherent ledger feature/fix packets actually pushed; feature and fix counts separate. Also show reviewed-plus-GitHub-unit-passed packets and usable-build/release deliveries separately. Ledger scope and GitHub handoff/commits are the sources. Exclude docs, workflow setup, tags and testing-only activity. | If code throughput stalls, identify the current implementation blocker or oversized packet; do not add a validation campaign. |
| Flow time | Assignment-to-push when a genuine assignment timestamp exists; handoff-to-code-review and handoff-to-reviewed/GitHub-unit-passed times from GitHub timestamps. Show pending item age and sample count. An issue-comment timestamp is an observed handoff, not an exact push timestamp. | Growing review age shifts MBA to corrections/code review rather than optional art. Developer advances independently. |
| Rework and waiting | Ready actionable MBA findings, finding-to-fix and fix-to-verification times, reopened findings and confirmed developer wait caused by review/coordination despite ready work. Exclude tracker23, external blockers and awaiting-MBA corrections from the ready count. Missing timing evidence is unknown, never zero. | Two ready findings at a packet boundary or a growing ready backlog activates the issue-only MBP coder. A confirmed avoidable wait triggers immediate task routing. |

Guardrails: track GitHub unit startup/execution failures and the distinction between code review, unit success and playable delivery. No claim that fewer observed findings proves better quality; exposure and test scope matter. No LOC, raw commit, unit-case-count or branch/tag target rewards busywork. Several child packets do not count as completion of their whole parent capability; show parent ledger progress alongside packet totals.

## Baseline and comparison

The previous requested72-hour audit (18 October15:39UTC to21 October15:39UTC) is retained in the JSON with its original method/caveats:207.4 overlapping session-hours, including an estimated95.9 coordination/evidence hours and37.8 testing/build/diagnostic hours. These are rough session-time estimates, not elapsed labour, billed credits or exact task timers. The old period lacks a comparable stable packet-size definition.

The new cohort starts at the published workflow commit `0f47b2f60f91f749f23c46a1ac0727ef4fcec5f2`,21 October15:53:44UTC. Record subsequent workflow refinements as events rather than resetting the counter. Compare rolling24-hour and72-hour windows with the same definitions. Separate carry-over/composition work, new implementation, fixes and workflow infrastructure; the first two product packets inherit work begun earlier.

Initial snapshot,21 October16:36:52UTC: two game-code packets pushed (one fix and one mission composition), one CI/setup packet, two game-code reviews complete, zero reviewed-plus-GitHub-unit-passed packets, and no new usable build/release. Median handoff-to-code-review completion is425seconds (7m05s), n=2. The GitHub unit retry is still running; the original startup failure remains recorded. Finding/remediation and avoidable-wait durations are not yet measured.

Do not infer a speedup from this short early sample or extrapolate it to a daily rate. Review the first comparable24-hour window and at least five reviewed product packets with unit outcomes before judging direction; keep observations visible before then. If packet sizes change, compare parent-capability advancement too. Do not claim a billed-credit saving without project-scoped billing evidence.

## Lightweight maintenance

Update the JSON once at a pushed packet/review/CI-terminal/correction event, deduplicated by source SHA, comment URL or run ID. Use existing GitHub queue23 handoffs, review/finding issues, Actions results and ledger transitions. Collect at natural packet boundaries and the existing daily hygiene review, not every poll. No builds, tests, new worker or extra developer form is needed for measurement. Keep the prior snapshot; report changes since the last snapshot and window-to-window comparisons when asked or a meaningful milestone changes.

Authoritative reads: `gh issue view 23 --json comments`; `gh issue list --state all --label mba-finding --json number,title,state,createdAt,closedAt,labels`; exact-head `gh run list`; and ledger-linked commit history. Match actual run heads and conclusions; skipped, cancelled or missing tests are not PASS. If a required timestamp or old comparison is unavailable, leave it unknown and explain the limitation rather than inventing a number.
