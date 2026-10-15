# Bounded Gallery integration hooks requested

Source work is isolated at `/Users/sclarke/.codex/worktrees/mission-campaign-gallery/elite`, branch `feature/mission-campaign-gallery`, based exactly on engine `81814a69f26deb7ef8f5d4b4534b1537feac4e79`. Assigned Gallery source and tests are implemented locally; reserved engine/AppKit files have not been edited.

## Pointer action forwarding

`GameRuntime.galleryClick(x:y:)` currently only calls the value-type Game presentation handler. A pointer click can navigate read-only relationships there, but starting an isolated trial must run in GameRuntime, which owns the save namespace/publication barrier. Request permission for this one-line delegation change in Game.swift, or ask the engine owner to provide it:

```swift
public func galleryClick(x: Double, y: Double) { campaignGalleryClick(x: x, y: y) }
```

`campaignGalleryClick(x:y:)` is implemented in the assigned ScriptGalleryTrial.swift. It stages presentation input, then validates and starts an exact root trial inside the actor. A mismatched review or changed selection cannot select another root.

## Painted Gallery input identity

The base's ScriptPagePresentation protects offers/questions but represents all Gallery pages as absence. Gallery pointer packets are plain coordinates, and T/retry commands are unwrapped. They cannot distinguish queued input from a prior assignment page, an unseen root-trial review or a returned commander context. Default Back plus a distinct review prevents repeated T from starting a trial, but does not by itself prove that every pointer/keyboard decision refers to a painted page.

Request a bounded ownership handoff or owner-supplied integration for:

- ScriptPageInput.swift: add a Gallery page identity containing commander context, exact saved/preview selection, relationship/detail/review mode and root review target. Selection focus on one visible review remains separate so same-page arrow plus Return works. Validate this identity through the existing page key/click methods and delegate Gallery clicks to the actor forwarding helper.
- EliteApp.swift: capture Gallery key/click proofs from the existing post-paint `displayedScriptPage`; wrap Gallery T/trial/retry commands and Gallery mouse clicks. Preserve existing offer/question proof behaviour and the renderer's post-paint capture. Native menu trial/retry actions should enqueue the same proof rather than raw commands.

No ScriptDirector projection hook is needed: assignment presentation derives from native saved instances, declarations and inverse bindings. No campaign/schema/persistence/finance/renderer changes are requested.

## Validation coordination

Eighteen focused and existing-regression tests pass, including four outcome cases, physical foreign-receipt rejection and compact/wide frame bounds. The owned-child root-trial physical patrol/combat/docking/report/debrief/save/load/Return test passes, preserving the live save bytes and original commander epoch. Native selection now remains bound to the exact saved instance if missing content reorders catalogue rows; Return restores browsing without reviving a selected trial confirmation. Renderer snapshots and canonical make ci remain pending the Orchestrator's CPU/GUI lease release. Final delivery requires integrated native painted-input regressions and the actual PR review/check gates; these local results are not a completion claim.
