# Temporary arrays in swept hull distance checks

The one-second non-stopping sample of active TSan run 247 reached automatic salvage approach through `RelativeWorkController` and `HullSweepSafety`. Its triangle-distance path allocated short vertex, edge and distance arrays repeatedly. The original run and its 2,400-frame controller budget remain unchanged; this sample is not a completed performance comparison or acceptance result.

Remove only those temporary collections while preserving actual geometry, ray/point/edge arithmetic and evaluation order, continuous-motion proofs, exact minimum-clearance results and all work counters/budget refusals. Keep the current test binary and canonical source frozen. Review source in an isolated checkout, then verify existing hull-sweep contracts and the actual native path after the active lease closes.
