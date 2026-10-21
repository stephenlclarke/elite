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

## Latest observed checkpoint

At the21 October offer-routing verification checkpoint, the cohort has17 product source packets (ten feature, seven fix), including two inherited packets and two corrective rework packets. Sixteen have independent source review and relevant maintained GitHub units verified. The original caller-failure packet remains recorded as corrected rework. The latest verified exact-head offer-routing run passed68methods/92expandedcases; these are component results, not whole-game acceptance. CI setup, shared-binding refactoring and warning maintenance are excluded from product throughput.

No new usable build or published release has been delivered in this cohort. Generic automated service errors are ignored under the latest human direction; MBA independently reviews the final PR head and raises actionable issues. Required GitHub checks/approvals still apply. The Wayfarer Exchange opening was subsequently pushed as84c733de (18th product packet,11features/7fixes); independent source review is complete, but exact-head GitHub compilation failed before unit execution (issue35). G1 has moved to the issue34 correction; Burro’s physical-source, retained comparison and first-sale prerequisite units are verified; the Glass Meridian offer-routing regression is also verified. All queued source/unit review through9b71b1c9 is complete. Full Burro activation and later campaign stages remain outstanding. This short window does not establish a causal speedup.

Later independent review of the complete PR found [issue34](https://github.com/stephenlclarke/elite/issues/34), a P2 field-relief terminal/custody join that can abort escape. G1 has taken this correction after pushing the Wayfarer opening; one ready defect is not a growing backlog and does not activate the optional helper. The preceding unit checkpoint remains historical component evidence and did not cover this event sequence.

## Lightweight maintenance

Batch JSON updates at natural packet boundaries, meaningful delivery changes and the existing daily hygiene review, deduplicated by SHA, review URL or run ID. Use the single PR handoff, review/finding issues, Actions results and ledger transitions; issue23 records are historical. Do not create a separate commit or dossier for every review or CI transition. No builds, tests, new worker or extra developer form is needed for measurement. Keep the prior snapshot; report changes since the last snapshot and window-to-window comparisons when asked or a meaningful milestone changes.

Authoritative reads: current development PR comments/reviews (queue23 is historical); `gh issue list --state all --label mba-finding --json number,title,state,createdAt,closedAt,labels`; exact-head `gh run list`; and ledger-linked commit history. Match actual run heads and conclusions; skipped, cancelled or missing tests are not PASS. If a required timestamp or old comparison is unavailable, leave it unknown and explain the limitation rather than inventing a number.

The next C08 compile result created a second ready issue, #35. The bounded issue-only MBP helper is assigned its display-expression correction while G1 retains34. The failed run executed no units and contributes no qualified packet or playable delivery.

G1 subsequently composed35 atb8cd1cfa and pushed34 at8c82f024. Both findings now await independent verification; neither is a ready unimplemented defect. The maintained78-method hosted run39673657024 is active. The stopped helper has no new assignment. No unit PASS or usable delivery is inferred from this push.
