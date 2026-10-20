# EMP test assertion lifetime

The actual 938 crash trace records a 184,304-byte caller span in the full-stock Cobra EMP test, above the unchanged 800-frame native helper and real collision/beam handling. The prior mesh predicate extraction still crashes and is not a qualified repair.

Move the existing post-pulse assertion phase into a private noninline helper, called after the original native loop returns. Preserve setup, real input and simulation operations, every assertion, their order and the final tick. Scope: only `EMPTravelAndSecurityTests.swift`; the shared EMP helper remains byte-identical.

MC1 owns this source-only M01 repair through Root. Focused execution and independent review remain pending. G1 composes canonical original `GameplayWeapons.swift`, excluding the failed index/borrowing predicate patch and deferred physical predicate alternative. No game behavior or default stack change is proposed.
