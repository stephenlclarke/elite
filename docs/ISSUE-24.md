# Trackpad mode transition preserves the contact-lift latch

Linked GitHub finding: [issue #24](https://github.com/stephenlclarke/elite/issues/24), packet **M02.P02.I24**. No pull request is created by this handoff.

## Problem and correction

The model-only F05 correction preserved rejected-contact suppression in update, but GameView's real Spin Hold mode-change caller still called reset first. That cleared the rejection latch before the next event could use the corrected model path. Leftover contacts could re-arm input without a full lift.

TrackpadInput now exposes setSpinMode as the shared mode-transition operation. It synchronously clears active contacts, direction and circle recognition while preserving an existing wait-for-lift latch. Both update and the GameView mode-change caller use it. Invalid flight state, focus/lifecycle changes, cancelled touches and explicit reset retain their separate clearing behavior. AppKit remains main-actor isolated and no simulation state moves out of GameRuntime.

## Isolated verification and limits

Three new pure-value regression methods exercise the exact shared operation used by the caller: rejected four-contact input followed by an explicit mode transition and leftover touches; synchronous clearing of active steering/spin outputs before a new event; and the preserved explicit lifecycle-reset behavior. The first two cover both initial modes. Existing F05 isolated regressions remain unchanged and all five methods are included in fixed GitHub execution. Six report/selection Python fixtures pass locally.

GitHub compiles/runs affected Swift units and MBA independently reviews the caller and results. No local Swift execution, AppKit GUI/integration journey, playable build or release result is claimed for this correction. The pushed fix references issue #24 without automatically closing it; MBA owns verification and closure.
