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

The accepted runtime key dispatcher must handle `gallery-trial`, `mission-resume`, `trial-return` and `trial-restart` through its actual trial/campaign lifecycle. Preserve saveForInterface trial routing and epoch resets; ordinary `Game.interfaceKey` cannot execute those actor-owned operations. The shared script-page guard already allows explicit contracts and gallery action names. Exact page proof is required for contracts, trial and retry; every action also rechecks screen, the existing InventoryContextEpoch, ECM epoch and availability. Do not rotate physical ECM or invent a new epoch. Trial return restores the parent ECM epoch but rotates inventory context, so a captured parent action stays invalid.

## Native menu retention and ordered event queue

Add `var missionMenu: NativeMissionMenu?` to AppDelegate and `var pendingMissionUI: [MissionUIIntent] = []` to GameView. After constructing the existing Game submenu, retain and install:

```swift
let target = NativeMissionMenu(
  snapshot: { [weak self] in
    (self?.window?.contentView as? GameView)?.game
  },
  paintedPresentation: { [weak self] in
    (self?.window?.contentView as? GameView)?.paintedMissionMenuPresentation
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

Expose this read-only accessor inside GameView using the accepted private painted fields. It must return nil before paint or after bounds change; never substitute the latest `game.scriptPagePresentation`:

```swift
var paintedMissionMenuPresentation: ScriptPagePresentation? {
  guard displayedScriptPageSize == bounds.size else { return nil }
  return displayedScriptPage
}
```

The helper compares that painted proof to the latest snapshot for contracts, Try and Retry, both when validating a menu item and immediately when choosing it. Non-page menu actions still capture the latest snapshot's screen and inventory context. The pending actor dispatch checks both again.

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

Run `MissionUICompositionTests`, `NativeMissionMenuTests`, existing `MissionCatalogueReplacementTests`, accepted campaign/trial/page-identity tests and native FIFO/focus tests only under the next assigned lease. The authored actor regression performs a real successful trial start and return, checks the same restored ECM epoch and screen with a changed inventory context, and proves refusal of the parent library intent without commander mutation. Native tests cover painted A/latest B mismatch, missing paint, changed bounds and fresh B dispatch. Check docked main station, secondary station, flight, paused library, trial return/restart and campaign review manually. Finally run the shared full `make ci` gates. This slice has performed no builds, tests or native launches.
