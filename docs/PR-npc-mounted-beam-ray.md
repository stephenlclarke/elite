# fix: fire NPC front beams along their mounted axis

The NPC beam acquisition cone previously steered collision rays toward target centres. The native nearest-obstruction query now receives the normalized ship-forward axis from the existing emission position. The front mount has no gimbal or aim-assist entitlement in this path. Combat and mining retain their existing acquisition thresholds and ranges, intended-target requirement, resource gates, damage, attribution and law.

Three focused regressions reuse the maintained combat setup and physical actor allocator. They cover an aligned hit with actual owner/victim/front-mount attribution, energy/heat/cooldown charging and cooldown refusal; an off-axis cargo hull whose centre ray hits inside the acquisition cone while the forward ray misses without spending resources; and a nearer physical cargo obstruction that preserves intended-target refusal without damage or spending.

Only strict Swift formatting, Markdown lint and whitespace checks run on this author branch. Compiler, tests, native app, UI, profiler and CI jobs are intentionally unrun under the coordinated execution lease. G1 owns native validation. No AUTO, police, Game/Commander layout, mission-provider or asteroid source is changed. See ISSUE-npc-mounted-beam-ray.md.
