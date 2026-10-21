# Correct restart and campaign-link context help

Game Over now says NEW COMMANDER without embedding a commander name. Campaign links advertise OPTION-UP/DOWN, matching the existing EliteMac input adapter and the other context pages. Dedicated Page Up/Down keys continue to work through the unchanged adapter.

## Validation

Two existing focused methods are extended, with two total cases. The restart test reads direct and overlay help, confirms the previous commander is unchanged, closes help and performs its existing real Return restart and current-default assertions. The campaign test creates actual parent/child relationships, opens the real campaign links, reads direct and overlay help, returns to the same relationship context and retains its original commander-equality oracle. Existing bodies and assertions are preserved. Swift execution is pending: the MBA toolchain exits69 because its Xcode licence has not been accepted. No test PASS, integration readiness or playable delivery is claimed. Owner must obtain focused PASS and independent bugs/performance/style review before integration. Existing restart behavior is covered by NewCommanderDefaultsTests.restartUsesCurrentDefaultsAndTitleRetainsTruthfulBuildIdentity; it is unchanged.

## Scope and limitations

Only PlayerHelp.swift, NewCommanderDefaultsTests.swift, DisplayOptionsTests.swift, the existing controls guide and this paired documentation change. No actor, storage, input, save, mission, rendering or compatibility behavior changes. Source base is public6b6ed6cec08c89e4bf00828c631da99d62acae26. No broad integration rerun or new app packaging is required for this source handoff.
