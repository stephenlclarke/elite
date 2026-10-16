# Mission UI integration hooks for G1

## Ownership and prerequisites

Apply the UI slice onto the accepted mission engine composition. G1 owns `Game.swift`, its screen enum/state, `GameRuntime`, and `EliteMac/EliteApp.swift`. This document is an integration recipe, not a claim that those hooks are implemented. The UI slice has no shadow engine state or stub APIs.

Add `.contracts` and `.library` to `Screen`; compose the accepted mission fields including `library = ScriptLibraryState()` and `contractBoard = ContractBoardUI()` and the accepted campaign/trial/script fields required by their existing extensions. Preserve current actor isolation and physical equipment APIs. Preserve the current C, R/Tab and W bindings; do not copy obsolete shortcuts from older source revisions.

## Actor entry point

The slice implements this method in the `GameRuntime` extension in `MissionUIAction.swift`, using the actual game owner. Do not duplicate it in Game.swift. Validation and dispatch stay in the same actor turn without an intervening await:

```swift
public func missionUICommand(_ intent: MissionUIIntent) {
  guard intent.isCurrent(in: game) else { return }
  if intent.action.requiresPageProof {
    scriptPageKey(intent.action.rawValue, expected: intent.presentation)
  } else {
    key(intent.action.rawValue)
  }
}
```

The accepted runtime key dispatcher must handle `gallery-trial`, `mission-resume`, `trial-return` and `trial-restart` through its actual trial/campaign lifecycle. Preserve saveForInterface trial routing and epoch resets; ordinary `Game.interfaceKey` cannot execute those actor-owned operations. The shared script-page guard already allows explicit contracts and gallery action names. Exact page proof is required for contracts, trial and retry; every action also rechecks epoch and availability.

## Native menu retention and ordered event queue

Add `var missionMenu: NativeMissionMenu?` to AppDelegate and `var pendingMissionUI: [MissionUIIntent] = []` to GameView. After constructing the existing Game submenu, retain and install:

```swift
let target = NativeMissionMenu(
  snapshot: { [weak self] in
    (self?.window?.contentView as? GameView)?.game
  },
  enqueue: { [weak self] intent in
    guard let view = self?.window?.contentView as? GameView,
      view.pendingMissionUI.count < 64
    else { return }
    view.pendingMissionUI.append(intent)
    view.pending.append("mission-ui")
  })
missionMenu = target
target.install(in: game.submenu!)
```

Remove obsolete mission menu creation at its existing installation site if it would duplicate these items. Preserve pause/spin and other Game items. The helper only removes existing items whose representedObject is one of its nine explicit action strings and assigns no keyboard equivalents.

Inside the existing single-consumer `processPendingCommands`, capture and clear `view.pendingMissionUI` alongside the inventory, purchase and file queues before the first await. Keep `var missionUIIndex = 0`. Dispatch the paired marker at its original FIFO position:

```swift
if event == "mission-ui" {
  guard missionIntents.indices.contains(missionUIIndex) else { continue }
  let intent = missionIntents[missionUIIndex]
  missionUIIndex += 1
  await runtime.missionUICommand(intent)
} else if event == "equipment-purchase" {
  // Existing purchase branch continues unchanged.
}
```

Declare `let missionIntents = view.pendingMissionUI` and clear it with keepingCapacity before dispatch. Clear or drain this typed queue together with its paired markers wherever existing queues are invalidated. Do not enqueue raw menu action strings independently of their proof.

## Painted-page keyboard and pointer integration

Use the accepted `ScriptPagePresentation` input bridge when composing EliteApp. Capture the actual painted page after presentation, including absence; never substitute an actor snapshot fetched later. Route its controlKeys, galleryContextKeys and contractContextKeys with the captured proof and epoch through `scriptPageKey`. Retain flight R/Tab behavior when the captured page is absent. Gallery, contract and handoff clicks must carry the painted page identity through the existing accepted guarded actor click methods. Add contract and library click/scroll destinations to native hit routing; library is read-only, contract actions require exact proof. Preserve inventory hit proof and ordered file-intent dispatch.

## Validation ownership

Run `MissionUICompositionTests`, `NativeMissionMenuTests`, existing `MissionCatalogueReplacementTests`, accepted campaign/trial/page-identity tests and native FIFO/focus tests only under the next assigned lease. Add an actor test that captures an intent, changes runtime epoch by restore/load/trial lifecycle, then verifies refusal without commander mutation. Check docked main station, secondary station, flight, paused library, trial return/restart and campaign review manually. Finally run the shared full `make ci` gates. This slice has performed no builds, tests or native launches.
