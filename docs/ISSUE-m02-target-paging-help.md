# Target-detail help advertises unavailable paging

M02.P01 / F04,F43. The six flight bindings already share the generated authority across input, menu and help. The remaining concrete defect is the unconditional target-detail paging hint in the flight reference. It appears without an identified target, with a collapsed panel and when all rows fit. The paging action already refuses unavailable detail panels.

Use the existing targeting tier, expansion and actual viewport calculation for both input and help. Preserve the six bindings, target and weapon selection, actor state and paging behavior. Direct help and the help overlay must agree. Do not change AppKit, simulation, save state, missions or CI policy.
