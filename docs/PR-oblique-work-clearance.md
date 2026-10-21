# fix(flight): validate oblique work endpoints before compensating stand-off

The controller keeps the original acquired approach and facing. For an oblique approach whose conservative compensation exceeds the original stand-off, it queries the existing validator once at the original prospective hold, provided that original point is within tool range. The query carries the same target identity/pose/velocity/angular velocity/end motion/delta, original gap/radius, desired hold attitude, matched work velocity/angular motion and centripetal acceleration. It does not invent a stationary target. A clear actual-geometry proof retains the original work point; a refused or unproved query chooses normal-support compensation.

Compensation pays the angle between approach and geometric surface normal, conservative radius, margin and the lateral offset's normal component. It never reduces the original stand-off. Finite checks, near-tangent refusal, original tool range and the full ordinary current-pose motion/braking validation remain. The prospective query is never the published validatedSweep. This is a destination correction, not permission to pass a safety guard or a proof of the actual G12 failure's cause.

The existing validate callback is a geometric decision function: it must not commit gameplay state or infer motion approval merely from being called. An eligible oblique step can make at most one extra bounded hold-proof call, followed by the unchanged actual work/braking calls. The aligned/default path makes no extra call. The original finite-wedge acquired-ray test remains byte-exact, including its300range, geometry and every counterfactual/braking/hold/clearance assertion. FlightWorkGuidance, HullSweepSafety and all G3/G12 files remain unchanged; no cache, new API/framework or caller-specific geometry shortcut is added.

## Regression and matching owner selection

Three new controller methods add six cases. A wide closed plane hull rejects the analytical old65.5centre endpoint and proves the new destination's gap, uses moving/rotating target data, checks prospective/actual sweep separation and tests the262range boundary. Two actual rotated-plane cases verify inward/outward collection offsets. Three tangent/near-tangent cases verify finite/range refusal without publishing work or selecting a tool. They use controller outputs and unchanged HullSweepSafety geometry, not source-string or duplicated-formula tests.

The matching focused owner selection is13methods/16cases:

- relativeWorkObliqueDestinationClearsRealPlaneHullAndPreservesRangeBoundary: new, one case.
- relativeWorkObliqueCollectionOffsetPaysItsInwardNormalComponent: new, two sign cases.
- relativeWorkTangentApproachNeverBypassesFiniteOrToolRangeGuards: new, three cosine cases.
- relativeWorkUsesSurfaceNormalAndActualPlayerRadiusForWorkClearance: unchanged, one case.
- relativeWorkFeedForwardIncludesWorkOffsetSpinAndCentripetalAcceleration: unchanged, one case.
- relativeWorkRequiresActualSweptClearanceAndSeparatelyValidatesBraking: unchanged, one case.
- relativeWorkKeepsVisibleObliqueApproachInsteadOfLosingItsBrakingCorridor: unchanged, one case.
- RelativeWorkCollectionOffsetTests.defaultAndExplicitZeroPreserveAllOutputAndValidatedSweepFields: unchanged, one case.
- RelativeWorkCollectionOffsetTests.offsetUsesTargetUpIndependentOfPlayerOrientationAndRetainsNormalClearance: unchanged, one case.
- RelativeWorkCollectionOffsetTests.rotatingTranslatedTargetUsesFullLeverArmAndAnalyticalApprovedEndpoint: unchanged, one case.
- RelativeWorkCollectionOffsetTests.rangeUsesActualSurfaceHypotenuseWithInclusiveBoundaryAndZeroCompatibility: unchanged, one case.
- RelativeWorkCollectionOffsetTests.invalidOffsetsNeverValidateAndRejectedWorkOnlyPublishesApprovedBrake: unchanged, one case.
- RelativeWorkMotionOutputTests.approvedOutputRetainsExactSweepAndAnalyticalAcceleratingRotatingEndpoint: unchanged, one case.

Author source parse/format/strict lint, geometry-hunk isolation, byte-exact original test prefix, unchanged shared files, paired Markdown and diff checks pass. G1 owns matching compilation and all selected native execution, currently unrun. Real compiler/unit corrections precede one complete independent bugs/performance/style review of the passing four-path freeze. No author native test, galaxy regeneration, fixture campaign, stack/concurrency/timeout waiver or CI run occurs. Normal required CI and G3's actual geometry evidence remain separate; no native pass, G12 repair or release completion is claimed. See [the proved generic invariant and finite-face constraint](ISSUE-oblique-work-clearance.md).
