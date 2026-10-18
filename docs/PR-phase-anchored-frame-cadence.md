# fix(frames): preserve deadline phase across late wakes

The AppKit loop now uses a small deadline-arithmetic helper to keep one cadence rather than resetting its time origin to each late frame start. After work, it selects a strictly future slot and sleeps, skipping missed slots without a tight catch-up loop. An effective display-rate change re-anchors at the current instant, preserving the 1...60 FPS cap. The sleep explicitly permits 100 microseconds of tolerance, a small fraction of the foreground frame interval.

Actual simulation elapsed time still comes from the unchanged ContinuousClock delta closure. AppKit remains on MainActor; cancellation checks and cancellation/error exit from Task.sleep remain, with an additional stop check after frame work. Profiling still records the frame's original target deadline, so skipped work does not conceal its overrun. The cadence leaf changes no simulation, save, renderer or GPU implementation.

## Validation

Three authored deterministic arithmetic tests use one clock instant only as an origin and synthetic duration offsets. They cover repeated 1 ms late wakes without phase drift, work overruns/exact boundaries/long missed-slot gaps, effective refresh-rate re-anchoring and rate clamping. There are no sleeps or wall-clock FPS assertions. Cancellation continues through the maintained loop/task mechanisms rather than a new timing abstraction.

Strict source checks passed. Subsequent focused run 501 passed all three cadence methods and sixteen geometry methods, 19 methods/20 cases total; unchanged original EMP smoke 502 passed both cases. Matched development profiles 504/505 measured median draw intervals of about 16.66 ms, against about 17.7 ms in baseline 497/498, with lower p95 intervals and 1,509 distinct frames per after run, zero repeated draws and zero coalesced/undrawn submissions. See the [measured report and evidence](NATIVE-FRAME-PACING.md).

The coherent measured after source includes separate geometry/save changes, so the result is not uniquely attributed to cadence. Compact baseline application success retains its separate inherited wrapper-assertion failure without retry. This is development-source measurement, not public release, physical scanout/input latency or a 60 FPS guarantee across gameplay. Mission run 503 still stack-crashed; full CI, signing, main publication and release acceptance remain outstanding. Previously accepted safety 494 and equipment 493 results are retained. This documentation closeout ran no new native jobs.
