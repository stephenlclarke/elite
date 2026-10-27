# Procurement filtering fixture assumes every route pool has an excluded path

Qualification 659 recorded failures for rows 0, 1 and 2 only at the strict-subset precondition in `procurementV2SelectsFromStableFeasibleCandidatesBeforeItsFrozenDraw`. The actual original-world basic-reach pool is nonempty and entirely feasible. No later seed/draw issue was recorded, but the method and all three cases failed; the cohort later crashed and supplies no overall acceptance.

Retain the actual pool and frozen draw checks, explicitly cover its fully feasible result, and add a separate meaningful strict-subset generator case. That case must obtain broader native reach through real paid navigation and storage purchases, independently filter actual BFS route calendar costs, and verify selection from the filtered ordered pool. Do not change generator policy, deadlines, seeds or the existing empty-pool and deadline-boundary checks.

## Latest central execution

Central run 661 at committed source c06c672a4e62f6e163d9ba36113c9dc918286774 completed all four selected methods and eight source cases with no errors, unknown outcomes, crashes or timeouts. The previously crashing unresolved-world request/save path, full PLUGH current-format live/disk Commander and default-public-load exact-pointer assertions, and all six basic/paid-extended route-pool cases passed. Evidence: /tmp/elite-station-qualification-661/agent-game-test-verification-661.json (SHA256 90facc6d3bd158fe34884a24357979f1c06e24b5be4d84826d1508f7918545f6). This is focused native evidence; earlier interrupted NPC departures, player cohorts and physics outcomes remain unqualified. Actual signed-app launch/save/load/hyperspace verification and final required gates are separate pending delivery steps.
