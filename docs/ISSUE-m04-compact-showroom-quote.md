# M04: compact showroom quote overlaps the ship-list heading

## Problem

Actual interactive acceptance on qualified main 0cc45dca used the ordinary app with a 512 by 540 content view. Selecting Redtail Mk III showed the third quote row, "Trade blocked - open review for reasons", over the "Ships" heading. At the actual 1.25 font scale, labels are 8.75 logical pixels high. The quote row spans y200 to y208.75; the heading spans y204 to y212.75, overlapping by 4.75 pixels. The corrected heading starts at y220, leaving an 11.25-pixel gap. Both share the narrow column. Wide screens place the list in a separate column.

The original screenshot and private-save run are retained in the operator's interactive-main0cc45 failure evidence. The app quit normally. Real commander and preference hashes, all 61 prior session states and both checkouts remained unchanged.

## Required result

Reserve room for all three quote rows before the narrow ship-list heading. Preserve wide-column placement, ship prices, purchase rules, hit testing, discovery and player ownership. Check rendered label rectangles for both M04 hulls at minimum, compact and wide sizes without changing commander property.

## Acceptance

Run the new meaningful regression, the affected showroom checks and the updated isolated selection. Resume actual compact and full-screen acceptance on the qualified corrected source. Source preparation is not execution evidence, and flight, docking and physical touch contacts remain unqualified.

See [implementation and validation](PR-m04-compact-showroom-quote.md).
