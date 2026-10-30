# docs(m02): credit existing trackpad controls and define acceptance

The source audit found no demonstrated remaining trackpad correction. Retain the implementation and its existing regression tests. This documentation records the acceptance work for the M02 integration batch without changing the healthy M01 execution checkout.

| Acceptance | Existing implementation and automated witness | Status |
| --- | --- | --- |
| One finger slows, two steer/cruise, three accelerate; neutral/lift preserves speed | TrackpadInput controls; heldTrackpadDirectionUsesAbsolutePositionAndNeutralCenter; trackpadFingerCountSelectsBrakingSteeringAndAcceleration; trackpadHoldsTurnOrThrustEveryFrameAndReleaseStabilizesAtCruisingSpeed | Prior actual PASS |
| Four contacts or invalid coordinates remain suppressed until complete lift | TrackpadInput waitingForLift; trackpadRejectsSystemGesturesAndInvalidContactsUntilLift; TrackpadContactSafetyTests | Prior actual PASS |
| Switching control mode clears active output without rearming rejected contacts | setSpinMode; both callerModeTransition methods and modeChangeCannotRearmAnInvalidTouchUntilEveryFingerLifts | Prior actual PASS |
| Spin circles recognize both pilot directions; two-finger aim rebases on contact changes | SpinGesture; deliberateCirclesRecognizeBothPilotDirectionsOnlyInSpinMode; circleRecognizerRejectsShortArcsReversalsStationaryTouchesAndJumps; spinSteeringRebasesEveryContactCountAndDoesNotApplyTheCircleToAim | Prior actual PASS |
| Spin speed holds hands-off, changes smoothly and remains independent of forward throttle | SpinControl; spinHoldAcceleratesCapsSlowsToZeroAndKeepsHandsOffRate; oppositeCircleAndStopChangeActualRateSmoothlyAndHUDReportsBothRates; spinAdjustmentTimingIsFrameRateIndependentAndCircleSuppressesSpeedChanges | Prior actual PASS |
| Pause, help, docking and cancellation clear held flight input | GameView lifecycle adapter; nativeTrackpadHoldsControlsAndClearsOnPauseHelpDockingOrFocusLoss; nativeSpinInputRecognizesCirclesRebasesAimAndKeepsForwardThrottleSeparate; spinCancelsOnFocusPauseHelpDockingAndChartsButExplicitStopIsSmooth | Prior actual PASS |
| Window focus loss clears held keys and trackpad state and queues spin cancellation | AppDelegate.windowDidResignKey source; physical window exercise below | Source checked; hardware acceptance pending |

The bounded evidence contains22 existing method records from the successful [PR278 native job](https://github.com/stephenlclarke/elite/actions/runs/40887243102/job/123495444263), with no failures, errors or skips among those methods. Its full suite contained3403 methods. Source comparison includes TrackpadInput, SpinGesture, SpinControl, EliteApp and the TrackpadContactSafetyTests, TrackpadTests, SpinTests and NativeViewTests files. No new method, selector replacement or fresh execution is claimed.

For M02 integration, combine the actual reviewed controls/help, comparison and transaction packets after usable M01 release. Preserve the complete parent selector and add each owner's exact new methods once; discover the final union rather than infer its total from another branch. Recheck these existing22 methods on the resulting candidate through the established validation route. Required PR checks, actual main analysis and playable delivery remain separate outcomes.

Use the delivered M02 build for the physical acceptance pass: hold each finger count, centre and lift at an intermediate cruise speed; draw clockwise and anticlockwise circles; adjust spin with one/three contacts; use two-finger pitch/yaw while maintaining spin; change mode during a held or rejected gesture; cancel, pause, open help, activate docking and leave/re-enter the window. Confirm the current Mac delivers the intended contacts and that restored focus does not retain stale thrust or steering. Actual hardware/UI acceptance is pending; the recorded AppKit tests supply synthetic input and do not establish that observation.

Documentation lint and whitespace checks pass. No production change or additional framework is proposed. See [the issue](ISSUE-M02.P02-trackpad-acceptance.md).
