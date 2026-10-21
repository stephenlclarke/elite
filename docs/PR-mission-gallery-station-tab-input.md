# test(missions): use Tab for native gallery station selection

## Changes

Two obsolete station-selection inputs now send `tab`: the physical courier delivery helper and the campaign root-trial station loop. This matches the actual documented flight controls and retained Tab/R-no-action proof. No other source literal, control, delta, iteration budget, target, docking/combat behavior or assertion changes.

`physicallyDeliverCourier` has one caller in the existing six-row native courier method, with physical delivery only for rows zero and one. The remaining four rows retain their original travel route. The campaign root trial is one separate method: two existing methods/two Swift Testing cases overall, no new tests. All original alignment/collision/delivery/receipt/save/namespace/people checks remain. No target injection, teleport, manual docking, weaker assertion or blanket replacement of R menu/retry actions is introduced.

## Scope and verification

The exact parent is `25574f2e1ebfc26c52fa33700eaeac9e48db853b`. Four files change: `ScriptCourierGalleryTests.swift`, `ScriptCampaignGalleryTests.swift` and this issue/PR pair. The complete Swift-file inverse must differ from the parent by exactly the two approved `r` to `tab` literals; all other bytes remain identical. Shared input implementations, other callers/methods and production remain unchanged. All previous refs, including both approved template leaves, are retained.

Only source parsing/strict lint, Markdownlint and static exact-literal/caller/scope/selection/hash checks run. No compiler, typecheck, discovery, tests, build, native/UI/media, GitHub, push, merge, Sonar or composition jobs run. Prior mission failures remain qualified as failures until actual reruns; no overall CI or release result is claimed. Root's independent 352 preservation/result review and final source approval precede integration and execution.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for all actionable findings, required final-head checks and approval, and protected merge without bypass.
