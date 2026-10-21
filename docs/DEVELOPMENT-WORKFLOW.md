# Developer and reviewer workflow

Updated 21 October 2026. This is the single current workflow authority. Older assignment and validation instructions in the completion ledger and historical notes are evidence, not active instructions. Current human direction overrides this document.

## Roles

| Role | Owns | Does not do |
| --- | --- | --- |
| MBP / Elite Coder 1 / GPT-6.1 Sol High | Ledger implementation, regression/unit-test authoring, source pushes, fixes after each packet, integration and release ownership | Wait for review or Orchestrator acknowledgement before starting the next ready task |
| MBA / Elite Coder 2 | Independent code review, focused isolated unit execution, GitHub findings with suggested fixes, verification and closure of corrected issues | Implement application, renderer or test fixes; run integration tests |
| Orchestrator | Priorities, issue routing, concise ledger transitions, ownership conflicts and useful delivery notifications | Duplicate the reviewer, start competing builds, require handoff acknowledgements or maintain duplicate issue dossiers |
| Optional second MBP coder | Explicitly assigned GitHub issue fixes and their regression tests, in an isolated branch with disjoint file ownership | Take ledger features, adjacent refactors or self-assigned work |

MBA may additionally create requested graphics/image assets under an explicit brief and separate paths. Application/renderer/shader/model-generation code remains MBP-owned. Asset creation is secondary to correction review and queued code review. README media must still come from the game renderer through `make readme-media`; do not fabricate game screenshots.

## Sources of truth

- [Completion ledger](COMPLETION-LEDGER.md): feature priority, owner and implementation/delivery state. Update at assignment, source push and meaningful review/delivery transitions; do not append an entry for every poll.
- [GitHub review queue #23](https://github.com/stephenlclarke/elite/issues/23): pushed work packets, their base/head, code-review and unit outcomes, and linked findings. This is a coordination tracker, not a defect.
- GitHub `mba-finding` issues: actionable defects, reproduction, suggested fixes, correction commits and MBA verification. Do not copy the full issue into the ledger or a second queue file.
- [MBA queue guide](MBA-TEST-QUEUE.md): links and current execution rules; GitHub holds live state.

## Small, complete work packets

A packet has one identifiable behavior or one root-cause fix, a ledger/issue ID, a coherent compileable change and meaningful isolated unit tests. Keep independently complete corrections separate where this is natural. Do not split inseparable code into broken commits merely to increase the push count, or hold completed changes for an entire milestone or release.

MBP posts one comment to queue #23 when it pushes a packet:

```text
Packet: <ledger ID or issue number> — <behavior>
Base: <SHA>  Head: <pushed SHA>  Branch: <branch>
Unit command: <exact focused selector/command>
Known gaps: <remaining limitation, or none known>
```

The same comment is the handoff. No freeze packet, repeated hash inventory, extra source audit or acknowledgement is required. Tag the coherent packet if useful; never label unfinished source as a release.

## Developer loop: never wait for review

1. Implement the next ledger item in priority order, with M01 first, and write isolated unit/regression tests. Use necessary compilation or short focused checks to resolve actual implementation uncertainty; do not repeat unaffected tests.
2. Commit and push the coherent packet promptly. Do not wait for independent review, an empty review queue, a full milestone, packaging or broad validation.
3. At the packet boundary, read open actionable `mba-finding` issues. Address all ready findings or explicitly assign disjoint ones to the issue-only coder. Acknowledge a finding once with its owner/branch; avoid repeated chat handoffs.
4. Push corrections and comment the exact correction SHA on each issue. Apply `awaiting-mba`. Use `Refs #N`, not auto-closing keywords: only MBA verification closes the issue.
5. If no actionable finding is ready, immediately implement the next ledger item. A pending review, compile, unavailable reviewer or graphics asset never leaves the developer waiting for work. Review findings can interrupt the current packet only for a genuine critical correctness/security/data-loss problem.

The feature author uses one active development checkout and a stable commit chain where practical; do not recreate worktrees for every helper or re-import old whole files. Never rewrite an already published packet or overwrite another worker's unfinished edits.

## Reviewer loop: code review overlaps unit execution

1. Fetch the exact pushed SHA without historical archive tags. Use one persistent MBA checkout and incremental build cache, with one compiler/test job at a time. Do not re-clone or discard the build cache per packet.
2. Review the base-to-head diff and necessary callers for bugs, performance and repository coding standards while compilation/units run. Do not wait for tests to finish before reporting a source-proven defect. Review correction deltas rather than re-auditing unchanged whole files.
3. Run the declared affected isolated unit methods, including parameterized cases. Record the exact source, command and actual result; never convert a cancelled/unrun case into PASS. Documentation-only packets receive documentation review without recompiling the app.
4. Post code-review and unit outcomes separately on queue #23. One confirmed root cause gets one `mba-finding` issue; reuse an existing issue for repeats. Include severity, SHA/path/line, expected versus actual behavior, reproduction/evidence and a suggested fix. Mark an unverified suggested fix as a hypothesis. Style preferences without a repository violation or material risk are advisory comments, not a stream of blocking defects.
5. Review pushed corrections first, then new packets in order. Verify the correction and affected unit result, then close the finding and remove `awaiting-mba`. If the issue persists, leave it open with concrete evidence. If verification is blocked, keep it open and state why; the developer continues other work.

No integration, full-game, native mission/runtime journey, GUI, system, broad `make ci` or performance-test campaigns during this code-completion phase. A test's name is insufficient: it must actually isolate the component. Instantiating a whole game and driving flight/docking/save/reload through a mission is not an isolated unit test. Do not weaken or delete existing tests or CI protection. Toolchain, machine and compiler infrastructure failures are reported separately from product defects; the reviewer never fixes source to make a test pass.

## Backlog and conflict control

Activate the additional MBP issue-only coder when two or more ready MBA findings remain at a packet boundary and would delay the next ledger feature, or when the unresolved ready count keeps growing across packet boundaries. Exclude coordination trackers, external/infrastructure blockers and `awaiting-mba` issues from that count. Do not activate a worker merely because an old unrelated issue is open.

Assign issue numbers, branch/base and specific file/hunk ownership before it starts. Never allow both developers to edit overlapping code concurrently; give the remediator another independent issue or let the primary take another ready feature. The remediator pushes linked corrections; G1 composes them into the development chain and MBA verifies the resulting correction. Keep the extra coder idle when the actionable backlog clears.

## State and release honesty

Track these separately: implemented, pushed, review outcome, unit outcome, integrated source, usable local build, published release and Homebrew availability. Unit-only checking does not prove full-game acceptance. Existing end-to-end evidence may be retained; lack of new integration testing must not be disguised as an implementation defect or used to block writing the next feature.

Required `@codex review`, applicable approvals and final-head GitHub checks still govern PR merges. They do not govern development-branch pushes or starting the next packet. Do not bypass branch protection or claim a release from an unchecked development push. If required checks cannot run under the current no-integration direction, leave the merge/release pending and continue source development.

The source checkpoints remain backups, not new releases or hundreds of review tasks. Keep signed packaging, release publication and Homebrew work distinct from code authoring. Slack is for a usable player-facing feature with execution evidence and an accessible build, not source pushes, tests, reviews or routine status.
