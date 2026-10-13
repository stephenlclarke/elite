# Protect main and public contribution workflows

Main requires pull requests, an up-to-date GitHub Actions quality check, resolved conversations and linear history, including for administrators. Force pushes and deletion are blocked. Independent approving reviews remain optional because the owner is the only writer. Merge commits are disabled; merged branches are deleted automatically.

Pull requests run the complete local quality gates with a read-only token. Only main performs exact-commit Sonar analysis. Actions are pinned, checkout credentials are not persisted, and the repository allows only checkout and artifact upload, with full-SHA pinning required. All external workflow runs require approval. Secret scanning, secret push protection, dependency alerts/updates and private vulnerability reporting are enabled.

Validation reads back repository permissions and rules through the GitHub API, verifies no additional writers/deploy keys/webhooks, and exercises the required check through this change's pull request and the main run after merge. Existing research files maintained separately are preserved.

SonarQube visibility follows the public repository so README badges are accessible. Its Owners group retains scan and administration permissions; anonymous visitors have no write access. Main analysis updates the display name to XYZZY Elite - Right-On Commander.

Request: [ISSUE-public-repository.md](ISSUE-public-repository.md).
