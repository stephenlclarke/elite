# EMP test assertion lifetime and prior-attack precondition

The actual 938 crash trace records a 184,304-byte caller span in the full-stock Cobra EMP test, above the native 800-frame helper and real collision/beam handling. Moving the original assertion tail into a noninline phase lets run 941 reach its assertions and terminate normally, but that run fails because the expected prior Cobra attack window is absent. Later assertions and the final tick did not execute.

The fixture never establishes a prior player hit. Native beam invocation or a miss does not create a CrimeLedger attack window. Establish a verified real native beam after the first actual EMP pulse; placing an unprovoked NPC hit before that pulse would alter its self-defence law. Preserve every original post-pulse assertion and the original frame budget.

MC1 owns the two test paths through Root: `EMPTravelAndSecurityTests.swift` and `EMPReleaseBoundaryFixture.swift`. G1 composes canonical original `GameplayWeapons.swift`, excluding the failed index/borrowing predicate patch. No production behavior, resource refill, actor move, geometry waiver or invented incident is included. The correction is source-frozen, focused validation and independent review pending; no release claim.
