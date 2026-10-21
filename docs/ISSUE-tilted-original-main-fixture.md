# Tilted docking fixture must identify the original main station

Full 222 records the tilted auto-docking method failing to dock after its original 7,000 steps. It injects station ID 1; the existing flat/side/spin docking proof uses original main ID 0 and passed in the same partial run. Current native original-main docking requires its actual flight-anchor actor, while an arbitrary station-shaped body is not main-station authority. This is source-backed diagnosis, not an observed failed-target identity dump.

Use original main ID 0 and require its actual selected physical anchor identity before the unchanged tilt/spin/loop/docking and later target-switch/manual-control assertions. Do not increase the time budget, force docking or weaken native station guards. See [the correction](PR-tilted-original-main-fixture.md).
