# PR #9: showroom controls, comparisons and Cobra restore

The existing exchange flow now has a prominent Switch ship - review trade action with price, 75% allowance, payment/credit and resulting cash before opening the quote. Currently flying identifies the owned hull. Read specs / Browse ships remains available by pointer; Return opens specifications then review, Tab changes panes and Escape goes back. Current ship and Selected ship label the models. The word-and-colour key sits beside comparison headings after tradeoffs, with bounded columns and scroll regions down to 512 x 518 logical points.

XYZZY activation and C Switch to Cobra Mk III restore canonical SH023 with maximum hardware. This free refit preserves cash, personal and reserved mission cargo, progress, legal status, kills, preferences and unique actors; excess cargo enables unlimited capacity rather than being discarded. Option 2 still refits the current hull. Reopening XYZZY does not replay its starting cash or auto-trade. Maximum refit replaces fitted hardware/weapons; no equipment warehouse is invented.

Save and Save As now enter the same main-actor input queue as player actions, so an immediate save cannot overtake a confirmed exchange or refit. GameRuntime continues to own simulation and disk persistence. All 167 ship definitions and source profiles, transaction constraints and fitted-performance calculations are preserved. Help, README and the controls/showroom guides match the final interaction. Renderer media was regenerated with make ships and make readme-media.

## Validation

Native walkthrough accepted minimum, narrow and wide captures, pointer quote/confirmation, real Boa launch and automatic return to Lave, repeated keyboard exchange, immediate Command-S and XYZZY restore. The saved hull/cash matched each action; restoring the Cobra preserved 695,128.4 CR and unrelated state. The original commander bytes and save preference were restored. Evidence: reports/ui/shipyard-ux/report.md. Custom canvas controls lack individual accessibility elements; physical trackpad hardware and Intel UI delivery remain unverified.

Current local validation: 224 Swift tests, 92.96% line coverage and clean Thread Sanitizer (73.5s). Final Address Sanitizer and leak gates are running before publication. Regression coverage includes direct/blocked review, layout bounds and legend order, payload/actor preservation, repeat refit/save reload and native event-loop save ordering. Source checks and scoped Markdown lint pass.

The 1.2.0 universal Developer ID package will be generated from a clean committed source checkpoint and added in a later artifact commit. Notarization remains unavailable without a configured notarytool profile; the manifest records the actual result. Motivation: [ISSUE-9.md](ISSUE-9.md). Player details: [SHIP-SHOWROOM.md](SHIP-SHOWROOM.md), [CONTROLS.md](CONTROLS.md).
