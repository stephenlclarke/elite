# fix(physics): honor native ore angular motion at admission

## Implementation

GameplayAdmission recognizes mining-produced cargo/ore requests with no NPC, rock or catalogue ship override. It leaves the requested orientation and physical angularVelocity intact, removes only the legacy display rotation rate for that new body and marks the existing physical motion as canonical. The existing canonical spin integrator then owns zero or nonzero motion immediately. Later automatic target selection preserves that motion through its existing canonical guard.

Other legacy, derelict, persistence and EMP behavior is unchanged. No existing pod is stopped, and no geometry, scoop speed, relative-motion, authority or custody guard changes. Only GameplayAdmission.swift, appended FlightWorkGuidanceRuntimeTests coverage and these paired notes change. The current moving-original validation freeze and G12 execution queue remain separate.

## Regression and qualification

nativeOreAdmissionAndSelectionPreserveRequestedPhysicalSpin has three requested-spin cases: zero; slow0.01/0.02/0.03; fast0.2/0.001/0.5. Each obtains a genuine generated rock's output through actual mining hits, varies only its not-yet-admitted request, uses native admission and ledger acknowledgement, then real Tab and tick. It requires the same actor, payload, binding, native geometry, birth orientation and requested angular velocity throughout. Nonzero motion must continue rotating. A non-mining legacy canister retains its original display-spin policy. Fast spin stays above the retained surface-speed threshold; this test does not manufacture a protected intake or claim that G12 intake was executed.

The bounded supporting selection is the new method/three cases, unchanged genuinelyGeneratedRockHandsItsAcknowledgedOreToAutomaticRecovery/one case and ScoopApproachControllerTests.realCobraAndCargoMeshCanValidateCaptureWhileEnclosingSphereRefuses/one case: three methods/five cases. G1 may add only a concrete dependency check if required. All existing test bodies remain exact. Native compilation and outcomes are pending with G1, followed by one complete independent four-path bugs/performance/style review before integration. No author native build, test, debugger or probe occurs.

Source authoring and available formatting checks run on the MBA through SSH in an isolated source directory; the full clean Git freeze is local. The MBA Swift license blocks native execution and no sudo/license change is attempted. Source structure proves requested-motion preservation, not a complete automatic twelve-original journey. See [the producer defect and scope](ISSUE-native-ore-spin.md).
