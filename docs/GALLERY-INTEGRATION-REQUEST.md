# Campaign Gallery integration boundary

Source work is isolated at `/Users/sclarke/.codex/worktrees/mission-campaign-gallery/elite`, branch `feature/mission-campaign-gallery`, based exactly on engine `81814a69f26deb7ef8f5d4b4534b1537feac4e79`. The Orchestrator approved the narrow engine/AppKit hooks below after confirmations from their owners. The implementation now includes only those granted regions. Native/full validation awaits an explicit resource lease; source readiness is not runtime acceptance.

## Pointer action forwarding

`GameRuntime.galleryClick(x:y:)` currently only calls the value-type Game presentation handler. A pointer click can navigate read-only relationships there, but starting an isolated trial must run in GameRuntime, which owns the save namespace/publication barrier. Approved and implemented one-line delegation in Game.swift:

```swift
public func galleryClick(x: Double, y: Double) { campaignGalleryClick(x: x, y: y) }
```

`campaignGalleryClick(x:y:)` is implemented in the assigned ScriptGalleryTrial.swift. It stages presentation input, then validates and starts an exact root trial inside the actor. A mismatched review or changed selection cannot select another root.

## Painted Gallery input identity

The base's ScriptPagePresentation protects offers/questions but represents all Gallery pages as absence. Gallery pointer packets are plain coordinates, and T/retry commands are unwrapped. They cannot distinguish queued input from a prior assignment page, an unseen root-trial review or a returned commander context. Default Back plus a distinct review prevents repeated T from starting a trial, but does not by itself prove that every pointer/keyboard decision refers to a painted page.

Approved and implemented boundaries:

- ScriptPageInput.swift: add a Gallery page identity containing commander context, exact saved/preview selection, relationship/detail/review mode and root review target. Selection focus on one visible review remains separate so same-page arrow plus Return works. Validate this identity through the existing page key/click methods and delegate Gallery clicks to the actor forwarding helper.
- EliteApp.swift: capture Gallery key/click proofs from the existing post-paint `displayedScriptPage`; wrap Gallery T/trial/retry commands and Gallery mouse clicks. Preserve existing offer/question proof behaviour and the renderer's post-paint capture. Native menu trial/retry actions should enqueue the same proof rather than raw commands.

One existing native-menu test gained an explicitly approved actual-paint call before dispatch. New native cases join its serialized suite to avoid process-wide AppKit races. No ScriptDirector projection hook is needed: assignment presentation derives from native saved instances, declarations and inverse bindings. No campaign/schema/persistence/finance/renderer changes are requested.

## Validation coordination

Checkpoint `8036f5c` passed eighteen focused and existing-regression tests, including four outcome cases, physical foreign-receipt rejection and compact/wide frame bounds. The subsequent proof hooks and added regressions await compilation and execution after the central integrator releases its quiet gate. The owned-child root-trial physical patrol/combat/docking/report/debrief/save/load/Return test passes, preserving the live save bytes and original commander epoch. Native selection now remains bound to the exact saved instance if missing content reorders catalogue rows; Return restores browsing without reviving a selected trial confirmation. Renderer snapshots and canonical make ci remain pending the Orchestrator's CPU/GUI lease release. Final delivery requires integrated native painted-input regressions and the actual PR review/check gates; these local results are not a completion claim.

## Implemented proof details

Gallery packets use compact generation/mode, selected-entry, visible-control-map and layout digests. Preview identity includes its immediate owner, alias and exact declaration; root review includes source/root/pinned digest; retry binds revision and availability. The existing 1024-byte decoded/1400-byte base64 limits remain. Geometry covers viewport and scroll/visible-row mapping. Post-successful-draw capture uses actual painted bounds, including resize before the simulation publishes its new viewport; model assignment never updates proof.

Physical T/R/Tab/L also capture a non-Gallery page absence so a queued open-then-trial pair cannot borrow the unseen Gallery context. Their ordinary controls remain allowed only on matching absent pages, while offers/questions cannot authorize Gallery commands. Menus and pointers use the same painted cache. Return and each attempted trial/retry refresh Gallery generation; same visible review focus changes preserve proof. Malformed, oversized, unknown and nonfinite packets have no raw-command fallback.
