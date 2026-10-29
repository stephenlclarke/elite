# Freight row-zero flight dies without causal observation

Full CI 683 on `1f9098a910aefa17655f3aeadbb59df03257b64e` stopped `freightActualAllRemainingPaysFrozenTierReward(row: 0)` during real flight with zero energy at physical time 133.2 seconds. Its existing assertion reports game-over, system, fuel and mass-lock facts but cannot distinguish actual incoming fire, collision or controller behavior immediately before death. The same method already uses the maintained bounded last-live and defence observer for row two, but disables it for row zero.

Enable that existing observer for both authored rows on the next required affected run. Do not change traffic, hardware, route, resources, law, controller behavior, completion assertions or flight budgets to make the case pass. This is evidence collection for a known unresolved failure, not a repair or a separate diagnostic job. See [the scope](PR-freight-first-failure-observation.md).
