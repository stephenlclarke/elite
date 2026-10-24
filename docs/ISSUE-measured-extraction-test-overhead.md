# Measured-extraction loops publish the same frame twice

`NativeMeasuredExtractionFixture.aim` discards the Game returned by each real hold-approach advance and immediately requests another snapshot to inspect holding. `extract` repeats the same pattern for depletion. The loops contain no intervening input or mutation. `GameRuntime.advance` already returns `snapshot()` on every path, and `snapshot` derives the weapon display; this can repeat collision and authority projection for the same frame.

Use the returned frame for those two predicates. Keep every actual simulation frame, conditional exit, 400/1000-frame limit, 0.05-second delta, controls, required mining budget and final assertions. Do not share a mutable fixture or modify production, persistence, gates or adjacent helpers. NativeSalvageOfferTests was checked first; its runtime tests already use the existing genuine release task and no additional honest duplicated setup reduction was established there.
