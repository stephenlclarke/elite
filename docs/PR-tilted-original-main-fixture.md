# test(docking): identify the tilted fixture as the original main station

One existing tilted-station method uses main body ID 0 and requires the real selected actor to match current flight anchors, with no native-RRS identity and with the docking computer engaged. Original position, pitch/roll/yaw, rotation rate, 7,000 by 0.02-second loop, final docking assertion and all later switch/manual-control checks remain unchanged. The method now throws for setup requirements. See [the identity mismatch](ISSUE-tilted-original-main-fixture.md).

No production docking, geometry, authority, controller or loop-budget changes. Whole-file reversal reconstructs the original file. Independent source review is clean; focused/full execution remains pending while frozen 222 completes; no passing or failed-target observation is inferred from the proposal.
