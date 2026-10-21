# Keep authoritative analysis tied to committed source

Review finding CR-16 identified that the Sonar entry point ignored untracked files when checking whether main was clean. SwiftPM and the scanner could include a new maintained file even though the published project version named an older commit. Reading HEAD again after coverage could also attach coverage to a different commit if the checkout changed during the run.

Reject untracked maintained source before any settings request or coverage work. Pin the initial lowercase 40-character commit SHA, then recheck main, tracked changes, maintained additions and that same commit before invoking the scanner. Preserve the Previous version baseline and remote settings checks. Ignored build and coverage outputs must remain permitted.

Acceptance requires offline integration tests of the real shell entry point, including clean publication, dirty and untracked input rejection, and source, branch or commit changes during coverage. No test may publish a real analysis. See the [implementation handoff](PR-review-source-guard.md).
