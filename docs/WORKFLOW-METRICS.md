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

## Two-developer comparison phase

Started22 October2026 at05:55:43UTC under explicit human authorization. G1 owns the complete clinic service loop; G3 owns complete showroom comparison. MBA reviews both and authors own their merges. No dedicated integrator or central integration queue.

Judge improvement by complete ledger features merged per rolling24hours and complete features made available in an accessible build. Record assignment, first push, source-complete, MBA review, final-head qualification, merge, playable build and release separately using existing GitHub/ledger evidence. Track review queue count/oldest age, actionable findings, correction verification, reopened issues, conflicts and confirmed developer waiting. Unknown timestamps remain unknown. Source packets, commits and unit-case counts cannot substitute for finished features.

The retained single-developer snapshot at21 October20:11:14UTC covers4.29hours:10 feature packets,7 fix packets and16 reviewed/unit-qualified packets; zero new usable builds or releases. This snapshot is partial and packet sizes differ. Later source qualification continues through81d54e74:221 methods/253 cases verified by MBA, but no new usable build or release. These figures do not establish a full-period packet rate or percentage speedup. Preserve the old72-hour estimates and baseline limitations above.

The first comparison follows a full24-hour two-developer window. Show both complete-feature outcomes and each feature's actual complexity/carry-over; a small unequal sample is directional, not causal proof. Review backlog above two ready packets or oldest source-review age above30minutes triggers orchestration, never a developer wait. Metrics are maintained from existing events without extra testing, forms or per-poll paperwork. The JSON stores the phase baseline and both feature outcomes.

## Third developer added — explicit resource change

On22 October Stephen added Elite Coder4, session01a16256-13d9-7a00-bd74-07d4dbf942aa, reported Sol6.1 High. G1/G3 remain Medium; G2/MBA independently reviews all three. G4 owns the separate T02.P01 practice provider. Record this as a resource/configuration change within the existing series, not a reset or a claimed speedup. Compare subsequent complete-feature outcomes with clear worker-count and complexity caveats; do not attribute differences solely to parallelism. No extra tests or forms are introduced.

## Lightweight maintenance

Batch JSON updates at natural packet boundaries, meaningful delivery changes and the existing daily hygiene review, deduplicated by SHA, review URL or run ID. Use the single PR handoff, review/finding issues, Actions results and ledger transitions; issue23 records are historical. Do not create a separate commit or dossier for every review or CI transition. No builds, tests, new worker or extra developer form is needed for measurement. Keep the prior snapshot; report changes since the last snapshot and window-to-window comparisons when asked or a meaningful milestone changes.

Authoritative reads: current development PR comments/reviews (queue23 is historical); `gh issue list --state all --label mba-finding --json number,title,state,createdAt,closedAt,labels`; exact-head `gh run list`; and ledger-linked commit history. Match actual run heads and conclusions; skipped, cancelled or missing tests are not PASS. If a required timestamp or old comparison is unavailable, leave it unknown and explain the limitation rather than inventing a number.

The next C08 compile result created a second ready issue, #35. The bounded issue-only MBP helper is assigned its display-expression correction while G1 retains34. The failed run executed no units and contributes no qualified packet or playable delivery.

G1 subsequently composed35 atb8cd1cfa and pushed34 at8c82f024. Both findings now await independent verification; neither is a ready unimplemented defect. The maintained78-method hosted run39673657024 is active. The stopped helper has no new assignment. No unit PASS or usable delivery is inferred from this push.
