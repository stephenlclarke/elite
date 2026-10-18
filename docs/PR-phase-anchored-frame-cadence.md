# fix(frames): preserve deadline phase across late wakes

The AppKit loop now uses a small deadline-arithmetic helper to keep one cadence rather than resetting its time origin to each late frame start. After work, it selects a strictly future slot and sleeps, skipping missed slots without a tight catch-up loop. An effective display-rate change re-anchors at the current instant, preserving the 1...60 FPS cap. The sleep explicitly permits 100 microseconds of tolerance, a small fraction of the foreground frame interval.

Actual simulation elapsed time still comes from the unchanged ContinuousClock delta closure. AppKit remains on MainActor; cancellation checks and cancellation/error exit from Task.sleep remain, with an additional stop check after frame work. Profiling still records the frame's original target deadline, so skipped work does not conceal its overrun. Simulation, save, renderer and GPU code are unchanged.

## Validation

Three authored deterministic arithmetic tests use one clock instant only as an origin and synthetic duration offsets. They cover repeated 1 ms late wakes without phase drift, work overruns/exact boundaries/long missed-slot gaps, effective refresh-rate re-anchoring and rate clamping. There are no sleeps or wall-clock FPS assertions. Cancellation continues through the maintained loop/task mechanisms rather than a new timing abstraction.

Strict Swift formatting, Markdown lint, whitespace and unchanged elapsed-delta source comparison are source checks. No author build, native tests, GUI, profiling or renderer jobs were run; no measured improvement or 60 FPS acceptance is claimed. G1 owns one source review, composition with the other bounded repair in the next coherent build after its current process ends, and matched compact/fullscreen after profiles. Previously accepted safety 494 and equipment 493 cases are retained and do not need rerunning for this leaf.
