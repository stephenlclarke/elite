# Reduce duplicate observations in existing runtime tests

Issues [#219](https://github.com/stephenlclarke/elite/issues/219) and [#220](https://github.com/stephenlclarke/elite/issues/220) describe repeated observation and frame-publication overhead in the existing multi-batch and measured-extraction runtime tests. The multi-batch source note retains a 2426.7-second historical duration. That motivates investigation; it does not establish current sanitizer cost or a measured speedup.

The tests already own the last frame returned by the actor. Reuse that frame and the previous scalar work observation instead of publishing or deriving the same observation again. Keep every assertion, scenario, declared parameter case, simulation delta, frame bound, control sequence, work budget, real save/reload and authority/custody check.

Combine only the exclusive already-authored test changes from PR216 and PR217 onto current canonical. Their inherited M03 changes are already integrated and must not enter this packet again. No production, workflow, selector, cache, time limit, sanitizer setting or current M01 head changes are permitted.

Acceptance requires independent source review and meaningful affected-method coverage at the next already-required candidate checkpoint. Reuse existing timing evidence with a matching execution fingerprint; do not rerun an old baseline. No local compiler, native test, profile, standalone replay or speed claim is part of this source packet. [Implementation and exact affected methods](PR-test-observation-reuse.md).
