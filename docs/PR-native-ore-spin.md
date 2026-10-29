# fix(physics): honor native ore angular motion at admission

## Implementation

GameplayAdmission recognizes mining-produced cargo/ore requests with no NPC, rock or catalogue ship override. It leaves the requested orientation and physical angularVelocity intact, removes only the legacy display rotation rate for that new body and marks the existing physical motion as canonical. The existing canonical spin integrator then owns zero or nonzero motion immediately. Later automatic target selection preserves that motion through its existing canonical guard.

Other legacy, derelict, persistence and EMP behavior is unchanged. No existing pod is stopped, and no geometry, scoop speed, relative-motion, authority or custody guard changes. Only GameplayAdmission.swift, appended FlightWorkGuidanceRuntimeTests coverage and these paired notes change. The current moving-original validation freeze and G12 execution queue remain separate.

## Regression and qualification

nativeOreAdmissionAndSelectionPreserveRequestedPhysicalSpin has three requested-spin cases: zero; slow0.01/0.02/0.03; fast0.2/0.001/0.5. Each obtains a genuine generated rock's output through actual mining hits, varies only its not-yet-admitted request, uses native admission and ledger acknowledgement, then real Tab and tick. It requires the same actor, payload, binding, native geometry, birth orientation and requested angular velocity throughout. Nonzero motion must continue rotating. A non-mining legacy canister retains its original display-spin policy. Fast spin stays above the retained surface-speed threshold; this test does not manufacture a protected intake or claim that G12 intake was executed.

The bounded supporting selection is the new method/three cases, unchanged genuinelyGeneratedRockHandsItsAcknowledgedOreToAutomaticRecovery/one case and ScoopApproachControllerTests.realCobraAndCargoMeshCanValidateCaptureWhileEnclosingSphereRefuses/one case: three methods/five cases. G1 may add only a concrete dependency check if required. All existing test bodies remain exact. Native compilation and outcomes are pending with G1, followed by one complete independent four-path bugs/performance/style review before integration. No author native build, test, debugger or probe occurs.

Source authoring and available formatting checks run on the MBA through SSH in an isolated source directory; the full clean Git freeze is local. The MBA Swift license blocks native execution and no sudo/license change is attempted. Source structure proves requested-motion preservation, not a complete automatic twelve-original journey. See [the producer defect and scope](ISSUE-native-ore-spin.md).

## Causal fixture correction after actual1204

Only workRuntimeGame's initial Mining fixture now selects SH023 and matches its fuel capacity before prepareEquipment. SH023 explicitly supports the Mining Laser utility; current default SH025 does not. The actual unsupportedSlot failures therefore precede the behavior this slice intends to qualify. Every existing test method, grant, admission action and oracle remains exact; the production motion correction is unchanged.

Exactly three methods call this Mining helper: nativeOreAdmissionAndSelectionPreserveRequestedPhysicalSpin (three cases), genuinelyGeneratedRockHandsItsAcknowledgedOreToAutomaticRecovery (one case) and miningAndSalvageNeverInheritEachOthersFittedModule (one case). Include that third dependency alongside the original exact-mesh supporting case: four methods/six cases after the correction. G1 owns the matching build and actual outcomes. Source-only MBA formatting/strict lint, exact helper-only insertion, local Markdown and diff checks pass; no author native run or replay occurs. The separate G12 two-case execution is not qualified by this setup correction, and automatic twelve-original acceptance remains pending.

## Two causal fixture boundaries after actual1208

Only the two failing existing methods change. Module isolation now retains the native cargo actor identity, chooses the actual Salvage filter, requires Mining present and Salvage absent, and evaluates that actor's candidate. Its original missing-Salvage-module and no-guidance/no-target assertions remain. Valid unrelated station docking is neither disabled nor mistaken for cargo.

The generated-rock journey now runs at most800 neutral0.1 ticks and requires real same-parent hold readiness, selected Mining and no suspended trigger before its original fire=true loop. Tab already selects the Mining tool for a fitted Mining hold; no guessed W press or direct tool/controller assignment is introduced. Its original800-step mining loop,600-step automatic recovery loop, geometry, resources, damage, output, custody and once-only collection oracles remain exact.

Next matching qualification runs only these two changed methods/two cases. Retain the unchanged requested-spin method's three actual1208 PASS cases and exact-mesh capture's one actual1204 PASS case on unchanged code/dependencies, yielding four methods/six cases if the two corrections pass. MBA source formatting/strict lint and local exact-hunk/Markdown/diff checks precede that run. No author native replay, product change, slot/filter waiver, forced hold or observer/cooldown adjustment occurs.
