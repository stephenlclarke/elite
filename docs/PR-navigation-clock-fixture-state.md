# test(navigation): use owned consumables and retained clock scenes

The screen test now seeds its Escape Pod before the actual launch, and the navigation test seeds Galactic Hyperdrive before its launch. Both add explicit fitted-item preconditions, then retain the original key/navigation actions and every original assertion. Launch performs real legacy-to-owned migration; no display-name-only item is treated as a fitting. See [the fixture issue](ISSUE-navigation-clock-fixture-state.md).

The mission-clock test retains its actual bodies through flight and versioned save/load. It adds a real main-station-body precondition and checks restored flight with fresh unpaused input state, then advances the original final tick. The actual schema contains no paused field, so no false paused-restore assertion or pause toggle is introduced. Every original elapsed-time, panel-freeze, paused-freeze, completion and exact 1,500-tenths credit assertion remains.

## Validation and limits

Only the three existing test files and this handoff pair change. No Core, writer, native station, equipment, clock, guard, skip or runtime setting changes. Strict Swift source lint, Markdown lint and whitespace checks pass. The corrected fixtures have not been compiled or executed.

Actual 190 failed with 15 assertion headers across six methods plus signal 10; these three methods are this change's scope. Raw log SHA256 `d0c4bc7552ea9cc08b132bebb744a4263fffe340e8950aca8ba440fbf842e89d`. The separately owned targeting fixtures and original NPC rejection debugger/lifetime work are not accepted by these edits. Focused execution, complete maintained CI and final review/publication gates remain required.
