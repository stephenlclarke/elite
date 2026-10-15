# Campaign Gallery integration boundary

Source work is isolated at `/Users/sclarke/.codex/worktrees/mission-campaign-gallery/elite`, branch `feature/mission-campaign-gallery`, based exactly on engine `81814a69f26deb7ef8f5d4b4534b1537feac4e79`. The Orchestrator approved the narrow engine/AppKit hooks below after confirmations from their owners. The implementation includes only those granted regions. Corrected-source native/full validation passed under the coordinated lease; Researcher review and central integration remain separate gates.

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

Corrected source/media checkpoint `c73ca75a071648e5fe192650370c901b25b61988` passed 24 focused and 14 native tests. The owned-child root trial physically launches, fights, docks, reports and debriefs; Save/Load/Restart/Return preserve live save bytes and the original commander context. Native selection stays bound to the exact saved instance when missing content reorders catalogue rows. Painted input regressions cover queued/unseen/stale/malformed actions, menu/pointer equivalence and actual resize geometry. Six committed renderer images remain byte-identical to regenerated originals. Canonical `make ci` passed 590 tests per lane with 94.82% coverage and zero leaks in 754.76s; all 770 frozen inputs remained unchanged, with no intervention. The quiet CPU/GUI lease was explicitly released afterward. Full commands, timings, hashes and prior attempts are in [the validation record](MISSION-CODER-GALLERY-VALIDATION.json).

The later engine handoff commit `401626e884654b65e674236daf275764fa09ad8d` differs from the assigned base only by its handoff document. Central integration must compare the actual resulting source inputs and run fresh relevant checks if they change. Researcher review, integration and eventual PR review/checks remain pending through the Orchestrator; no push or merge occurred in this checkout.

## Implemented proof details

Gallery packets use compact generation/mode, selected-entry, visible-control-map and layout digests. Preview identity includes its immediate owner, alias and exact declaration; root review includes source/root/pinned digest; retry binds revision and availability. The existing 1024-byte decoded/1400-byte base64 limits remain. Geometry covers viewport and scroll/visible-row mapping. Post-successful-draw capture uses actual painted bounds, including resize before the simulation publishes its new viewport; model assignment never updates proof.

Physical T/R/Tab/L also capture a non-Gallery page absence so a queued open-then-trial pair cannot borrow the unseen Gallery context. Their ordinary controls remain allowed only on matching absent pages, while offers/questions cannot authorize Gallery commands. Menus and pointers use the same painted cache. Return and each attempted trial/retry refresh Gallery generation; same visible review focus changes preserve proof. Malformed, oversized, unknown and nonfinite packets have no raw-command fallback.

## Saved contract root eligibility

The Researcher confirmed through the Orchestrator that normal saved-contract trial refusal also applies to owned-child root routing. The actual resolved root is checked for `contract != nil` before constructing a review. Its explicit unavailable reason is "Trials of saved contract assignments are not supported." Read-only owner navigation remains available; a separate provider template retains normal fresh-offer trial eligibility. Regressions extend the genuine scripted-contracts provider with an exact owned patrol declaration and native acceptance handler; no contract state is stamped into a projection fixture.

Genuine direct/nested board acceptance and provider trial cases pass. The native painted keyboard/queued-menu/pointer regression refuses the saved contract root without creating a trial namespace or changing commander, offer/deposit/receipt state, epoch or live save bytes, while actual owner navigation remains usable. Native board offer UUIDs are deterministic across isolated worlds; provider-trial isolation is verified through commander context, epoch, save namespace and preserved live bytes rather than assumed UUID uniqueness.

Earlier checkpoint `942431b93f786ff2e21425fc7efaf9523b32026f` passed uninterrupted canonical `make ci` with 588 tests per lane, 94.87% coverage and zero leaks in 765.05s, before the contract correction. An earlier parallel sanitizer run also returned 0 after a recorded targeted TERM intervention. Both remain distinct prior-source evidence. The final corrected canonical run used the approved serial AddressSanitizer flag with every test/assertion retained; one read-only process sample confirmed buffered output was progressing renderer tests, and no signal was sent.
