# Assert the actual wrapped inventory fitting rows

The combined 025 focus completed all 47 intended methods but reported five failures in two newly updated inventory display tests. Both tests expected two leading spaces in a fitting row. `inventoryInformationRows` passes every row through `MissionNotice.wrap`, which splits on spaces and joins words; the public row has no leading indentation. The original failed diagnostic explicitly contains `Fitted Energy bomb - Granted`.

Remove only the two leading spaces in the expected energy-bomb row and the four-mount prefix. Preserve the exact remaining labels, physical fitting and acquisition assertions, complete Commander comparisons, prices, typography, viewport bounds and row reachability. No production change or general string normalization is needed. See the [implementation handoff](PR-inventory-row-whitespace.md).
