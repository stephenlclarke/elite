# Simplify station market and information screens

Docked Market (7) combines prices, stock, holdings and buying/selling in one table. Tab or clicking Buy/Sell changes the mode without resetting the selected commodity; Return or the trade button trades one unit. Left sells and Right buys one. Keys 1/2 remain aliases, while the docked Screens menu exposes only the primary Market entry. Switching modes does not add Back history. In-flight prices remain read-only and 1/2 retain rear/left views.

Commander Status (8) summarises location, condition, fuel, finances, legal standing, rank, cargo use and missiles. Inventory (9) owns commodity holdings, reserved mission payloads and the full laser/equipment list. The actual transaction implementation and mission property constraints are unchanged.

Pointer events pass through the existing runtime actor. Keyboard help, README and the control guide describe the consolidated flow. Focused regressions cover mode/selection/history, transactions, paused pointer input, flight behavior and distinct information responsibilities; existing compact market bounds and inventory scrolling tests remain applicable.

Validation: the station/navigation run exercised 16 tests; 14 passed initially and two help expectations exposed the old status/inventory split. Conditional overflow hints and those expectations were corrected; the focused five-test recheck passes, including reserved mission cargo, paused input and underlying help context. Existing compact market bounds and full inventory scrolling pass. Markdown lint and diff checks pass.

The isolated native QA app was checked at 768x768 and 512x518: keyboard purchase and mode switching retain the selected commodity, pointer Sell one restores cash/holdings, all commodities remain reachable, the docked menu has one Market entry, Status is concise and Inventory contains full fittings with working compact scrolling. No save was written; the QA app is closed and its GUI lease released.

`make ci` was attempted and stops at `ships-check`: all 168 GIFs are stale because the shared fingerprint includes changed core source. Full integrated CI, media regeneration and final packaging are owned by Coder 1. No independent merge or release is requested. This branch overlaps Game, screen navigation and the native event adapter; integrate deliberately with gameplay/performance changes. Motivation: [issue](ISSUE-station-market-ux.md).
