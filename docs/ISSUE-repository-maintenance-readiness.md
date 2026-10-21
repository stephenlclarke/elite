# Consolidate dependency maintenance and quality failure evidence

## Motivation

The composed game source does not yet contain the daily Swift/Actions update configuration from [PR #17](https://github.com/stephenlclarke/elite/pull/17) or the maintained quality-evidence capture from historical [PR #20](https://github.com/stephenlclarke/elite/pull/20). Its workflow still pins Node 20 action versions. README describes two allowed actions although the live allowlist has three, and readers need an explicit distinction between the published GitHub release and the older published Homebrew cask.

## Acceptance

Reuse PR #17's existing configuration rather than create a competing implementation. Pin the current official checkout, upload-artifact and dependency-review action releases by exact full SHA. Preserve read-only tokens, disabled credential persistence, selected actions, the existing required quality job and main-only exact-SHA Sonar analysis. Import only the maintained quality wrapper and its CI invocation, retaining raw failure evidence without retrying or waiving failed gates. Exclude the historical one-off diagnostic workflow, script and test.

README badges must report actual workflow/release status or describe configuration and link to security information. They must not certify a vulnerability-free repository or a successful CodeQL scan. The Homebrew update remains owned by [Elite PR #16](https://github.com/stephenlclarke/elite/pull/16) and [tap PR #9](https://github.com/stephenlclarke/homebrew-tap/pull/9); this change must not duplicate their cask or release work.

## Scope and remaining gates

Stage source in the G1-owned maintenance branch, separately from the frozen gameplay checkout. Static checks may run here; compilation, full quality validation, media generation and publication remain coordinator-owned. Every PR needs a completed clean repeated review and final-head required checks before merge. A failed review service response is not approval. See [the implementation handoff](PR-repository-maintenance-readiness.md).
