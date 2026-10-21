# Development and MBA test workflow

Updated 21 October 2026 by explicit human direction. This supersedes earlier parallel implementation assignments; historical qualification records remain intact.

## Ownership

- Elite Coder 1 is the sole developer and integrator, using GPT-6.1 Sol at High effort. It implements every feature and fix, writes meaningful unit tests, keeps documentation current, and pushes each completed feature to the remote.
- Elite Coder 2 operates the MBA as a tester only. It tests exact pushed commits, creates GitHub issues for confirmed failures, documents reproduction and a proposed solution, and never changes application or test source to fix them.
- By explicit human exception, the MBA also creates and pushes requested graphics assets (bitmaps, textures, icons and illustrations) under distinct file ownership assigned by the Orchestrator. G1 supplies a concrete brief and continues unrelated code while artwork is pending. Application, renderer, Swift, shader and model-generation code remain G1-owned; README media must come from the game renderer through `make readme-media`. Asset pushes are not usable-feature delivery.
- The Orchestrator maintains priorities, assignments, the ledger and test queue, prevents duplicate work, and ensures findings return to the sole developer.
- Other coding and research sessions remain idle unless the human changes this arrangement. Previous mission-only routing and MBA authoring assignments are superseded.

## Feature delivery

1. Select one deliverable from `COMPLETION-LEDGER.md` in priority order, with M01 first. Record the owner and acceptance criteria before implementation.
2. Implement the complete feature and its meaningful unit tests. Run affected unit tests locally and review the change for bugs, performance and coding style. Reuse unaffected evidence; avoid repeated broad integration runs.
3. Commit using Conventional Commits and push the feature to its remote development branch. Record the exact SHA, affected test command, behavior and limitations in the ledger and MBA test queue.
4. The MBA fetches and checks out that exact SHA in its isolated test checkout. It runs the affected tests with one job and a recorded command/result. Full integration testing is batched after several delivered features and at release checkpoints.
5. For each confirmed problem, create one GitHub issue (reuse an existing issue for the same cause) containing the commit, environment, expected and actual behavior, reproduction, relevant failure evidence and proposed solution. Mark an unproven solution as a hypothesis. Do not implement it on the MBA.
6. The Orchestrator prioritises the issue for the sole developer. The developer fixes it with a regression test and pushes the correction. The MBA verifies the changed behavior on the new exact SHA.
7. Distinguish implemented, pushed, MBA-tested, integrated, usable local build, released and Homebrew-available states. A source checkpoint or passing unit test is not a release.

## Source checkpoints and release gates

The initial checkpoint preserves all local branch and worktree source, including unfinished work, on remote backup refs with annotated checkpoint tags. A checkpoint manifest maps every ref to its source commit and records excluded non-source files. These backups preserve work; they do not merge incompatible branches, certify tests, or publish a release.

Each completed feature must be pushed. Checkpoint tags use a `checkpoint/` namespace; release version tags are reserved for actual releases. Never force-update an existing checkpoint tag.

Required final-head pull-request review, approvals, CI (`make ci`), signing and release requirements remain in force. The MBA does not independently start competing main-Mac builds, performance jobs or GUI sessions. Report infrastructure failures separately from product failures.
