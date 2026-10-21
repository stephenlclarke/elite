# Galactic travel fixture assumes the next target is always the original station

> Current controls (FR-008): Tab alone selects flight targets. R references below describe historical source or validation evidence; they are not current flight instructions. Archived input/evidence records are retained unchanged.

## Partial-run evidence and source inference

Active full CI checkpoint 222 reports the final guided-docking assertion failing in `jumpTravelDockingAndGalacticDrive`. The failure output does not identify the selected actor. Source shows a current-system waystation in galaxy one, system seven, and target cycling restores native station bodies after the fixture replaces its visible scene. Cancelling guidance preserves cycling history, so a subsequent R input can select an unvisited waystation rather than original station zero.

This is a source-backed target-selection diagnosis, not an observed runtime target dump or established controller bug. The test uses direct `Game.tick` for original-main docking; native RRS arrival requires its separate durable runtime commit and must not be substituted for that intended scenario.

## Required correction

Preserve the original first selection, P cancellation and second selection. Use bounded additional real R inputs to require the actual original-main target and engaged docking before the unchanged 2000-tick loop. Keep the same physical actor/anchor identity, actual docking/status/speed and later manual doorway/collision checks. Do not reset private controller history, suppress waystations, increase the time budget or waive arrival authority. See [the implementation](PR-galactic-main-station-selection.md).

## Validation and limits

Strict source/Markdown lint and diff checks pass. Source reversal preserves the rest of the original file exactly. No execution occurred in this worker; the integration owner will validate after the full run closes. A bounded final-state diagnostic will expose any remaining genuine docking failure.
