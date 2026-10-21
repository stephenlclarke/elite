# Stage dependency configuration and retain hosted quality failures

## Implementation

Import `.github/dependabot.yml`, the read-only Dependency Review workflow and the historical handoff pair from [PR #17](https://github.com/stephenlclarke/elite/pull/17), head `617b56d07f4b5ee8d59e5ed32370d86c28991d3e`. Daily updates target main at 09:00 Europe/London; routine minor/patch versions are grouped with finite PR limits. Recognized newly introduced advisories at low severity or above fail dependency review. Historical PR #17 validation describes that PR, not a new run of this composed source.

Official release tags and exact `action.yml` contents were checked on 17 October 2026:

| Action | Release | Commit | Runtime |
| --- | --- | --- | --- |
| checkout | [v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | Node 24 |
| upload-artifact | [v7.0.2](https://github.com/actions/upload-artifact/releases/tag/v7.0.2) | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | Node 24 |
| dependency-review-action | [v5.0.0](https://github.com/actions/dependency-review-action/releases/tag/v5.0.0) | `a1d282b36b6f3519aa1f3fc636f609c47dddb294` | Node 24 |

The dependency-review pin is already current. Node 24 requires Actions Runner 2.327.1 or newer; these workflows use GitHub-hosted runners. Read-only permissions, credential persistence disabled, PR-only dependency review without PR comments, existing triggers and main-only Sonar conditions are preserved.

Copy `Tools/CI/capture-quality.py` byte-for-byte from historical PR #20 head `abc7a95f3f1d8a334919eedf510df9ebe09368a2`, SHA-256 `8376020e4e4a96bb56fc7ed257e0b2b05afc1e004316b862d7f4a4f61d710ab4`. Its maintained CI invocation replaces direct `make ci`; the wrapper invokes that command exactly once with inherited environment and no added test timeout. It records raw output, original make status, source/toolchain identity, actual descendant process history and a bounded natural-exit observation. Persistent owned processes require cleanup and remain a failure. Changed tracked source fails the wrapper. Only crash originals matching observed PID, launch time and executable are copied; unrelated reports retain attribution metadata only. Existing `always()` artifact upload includes the reports directory.

The one-off `native-lifetime-diagnostic.yml`, `native-lifetime-diagnostic.py` and `NativeLifetimeDiagnosticTests.swift` are excluded. Historical PR #20 and its checkout are untouched. No old source checkpoint is rerun.

README reuses the dependency/security badges from PR #17, scopes CI status to main, adds a dynamic published-release badge and a Homebrew cask link, documents the three-action allowlist, and retains the explicit 1.3.1 tap versus 1.4.0 GitHub release distinction. The pending tap PR remains linked without claiming a completed clean review or install update. [PR #16](https://github.com/stephenlclarke/elite/pull/16) retains ownership of cask/release synchronization; none of its distribution implementation is duplicated here. No CodeQL success or vulnerability-free claim is introduced.

## Validation and compatibility

Source-only checks pass: actionlint for both workflows, strict YAML lint for all three configuration files, Markdown lint for the five touched documents, Python AST parsing and 25 isolated safety-helper checks, official full-SHA/tag/runtime verification, and diff hygiene. Across 1,246 existing tracked blobs, only the maintained CI workflow and README differ; all game source, tests, resources, generated media, packaging and distribution inputs remain byte-identical. All eight badge/download destinations return HTTP 200 through curl; the earlier Python user-agent HTTP 403 responses are retained separately. No game build, `make ci`, native session, media generation, Sonar publication or release runs in this staging pass.

The live read-only GitHub snapshot confirms selected-actions mode with only checkout/upload-artifact/dependency-review-action, mandatory full-SHA pinning, read-only default tokens and no Actions review approval. Main retains strict required quality, administrator enforcement, linear history, resolved conversations and blocked force pushes/deletion. This source change does not mutate those settings.

Configuration becomes active only after reaching main. Swift advisory coverage remains unverified because the initial graph omitted TOMLDecoder; SHA-pinned Actions do not receive vulnerability alerts. Final composed quality checks, a completed clean repeated PR review and final-head required checks remain necessary before integration/publication. Tap #9 separately requires CODEOWNER approval. See [the requirement](ISSUE-repository-maintenance-readiness.md).
