# Procurement filtering fixture assumes every route pool has an excluded path

Qualification 659 recorded failures for rows 0, 1 and 2 only at the strict-subset precondition in `procurementV2SelectsFromStableFeasibleCandidatesBeforeItsFrozenDraw`. The actual original-world basic-reach pool is nonempty and entirely feasible. No later seed/draw issue was recorded, but the method and all three cases failed; the cohort later crashed and supplies no overall acceptance.

Retain the actual pool and frozen draw checks, explicitly cover its fully feasible result, and add a separate meaningful strict-subset generator case. That case must obtain broader native reach through real paid navigation and storage purchases, independently filter actual BFS route calendar costs, and verify selection from the filtered ordered pool. Do not change generator policy, deadlines, seeds or the existing empty-pool and deadline-boundary checks.
