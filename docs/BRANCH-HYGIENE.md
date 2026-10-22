# Branch hygiene

Root owns branch retirement so it does not interrupt feature authors. Keep a branch only for active assigned work, an open PR, the shared delivery/release line, or a managed checkout that is still needed.

- Authors use one feature branch per coherent feature and own its corrections and merge. GitHub automatic head-branch deletion after merge stays enabled.
- Before removing an old branch, check current worker ownership, worktrees, open PRs and unpublished commits. Preserve unfinished source first and verify the remote recovery reference. Do not merge archival source into the game.
- Close a superseded PR only with evidence that its changes are incorporated, or an explicit recorded supersession. Preserve actionable findings and delivery requirements separately.
- Remove inactive local references after recovery is verified. Preserve managed worktrees, active indexes, source and required build caches. Retire those through their owning session/app when no longer needed.
- Daily hygiene checks for newly merged/obsolete branches and unexplained leftovers. Do not create permanent backup branches or duplicate open PRs for the same delivered source.

## 22 October 2026 cleanup

| Item | Before | After |
| --- | --- | --- |
| Local branches | 577 | 36 |
| GitHub branches | 17 | 12 |

Closed superseded PRs32,36 and44 after every changed file matched shared development byte-for-byte. Removed their remote heads, the obsolete source-backup branch and the older native-contact source branch already contained in shared development. No protected merge or approval requirement was bypassed.

Archived and removed541 inactive local references:22 were ancestors of shared development;519 were inactive recovery branches whose complete history remains in the archive. Active/open-PR/managed-checkout references stay. Five dirty worktree source snapshots were preserved without changing their real indexes or files. Non-ignored source and research are included. The existing signed candidate ZIP remains in its verified durable Applications copy; its manifest/checksum and matching SHA256 are recorded. Ignored compiler caches were not added to Git or deleted.

Recovery tag: `archive/branch-cleanup-20261022T080946Z`. [Browse its manifest](https://github.com/stephenlclarke/elite/blob/archive/branch-cleanup-20261022T080946Z/BRANCH-ARCHIVE.json). It records original branch names/commits, worktree heads, source-snapshot commits and the preserved build location. This is recovery history, not a release or a claim that unfinished work passes tests.

To inspect the saved references:

```sh
git fetch origin tag archive/branch-cleanup-20261022T080946Z
git show archive/branch-cleanup-20261022T080946Z:BRANCH-ARCHIVE.json
```

Restore selected work from its recorded commit into a new branch when needed. Do not merge the archive metadata commit: its recovery parents intentionally retain unrelated historical work.
