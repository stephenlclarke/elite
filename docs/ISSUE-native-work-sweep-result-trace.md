# The native hold is blocked without a retained clearance result

Run 537 obtained actual first-release readiness at iterations 9 and 109. Physical time advanced from 0.18 to 0.20 and from 2.18 to 2.20. The first point was approaching with an applied motion; the second was blocked by `clearance("Insufficient hull clearance")` without an applied motion. Both remained not holding, not suspended, with the salvage cutter selected, no hot session, and unchanged imported work 0.25 of the required 16 seconds. These observations explain why the cutter earned no work at those two frames. They do not identify a refusing obstacle, the failing sweep sample or a correct production repair.

The guidance closure currently discards the computed `HullSweepResult` after taking its clearance. The same result already contains failure, obstacle, sampled clearance and charged query/triangle/node counts. Its existing sweep input supplies the proposed work/braking trajectory, target motion and work point. Retain these facts only as opt-in debug output around that exact single validation call. No repeated geometry query, surrogate hull, relaxed clearance, different budget, forced hold, teleport or fabricated credit is justified.

This is temporary diagnostic instrumentation, not a solver repair. G1 owns the independent build and one bounded diagnostic; the author runs no compiler, native process or profiler. A causal repair and the original genuine acceptance remain subsequent work.

Run 539 subsequently captured the complete requested/braking failure against SH127 and released its execution lease. The tap is removed in the visible-approach repair; this issue records the diagnostic evidence gap that existed before that run.
