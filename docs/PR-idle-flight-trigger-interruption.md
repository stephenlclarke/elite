# fix(controls): avoid inventing held-fire stops during idle changes

`interruptFlightTool()` now sets `workFireSuspended` only if the observed flight trigger is held. It always clears the pending press and selected-tool activity as before. The false branch does not assign to the latch, so an existing damage/impact stop remains set. No stop is globally cleared, no selected tool is substituted, and no autonomous or manual weapon guard is removed.

## Causal evidence

Actual CI568's two original methods produced three qualified records: station before/after and procurement inactive-control before. The latter threw before its after record; the observation is incomplete and is not acceptance. Both before records had an idle-command-created stop despite genuine target, law, resource, equipment and geometry readiness. Station fire returns on that latch before testing mounts. Procurement fallback returns on the same latch before its budget reservation or launch sequence. These exact source gates are sufficient to explain the recorded refusals without inventing a later missile result.

The source producer chain is `performNativeLaunch -> cancelAutoTarget -> interruptFlightTool`, plus actual `Tab -> prepareFlightControlKey/cycleAutoTarget` and `selectFlightTool -> interruptFlightTool`. None requires held Return. `Game.tick` later calls `admitFlightFire(false) -> observeFlightFire(false)`, clearing the artificial latch. `GameRuntime.prepareAdvance` calls station missile publication before that tick, so waiting for frame admission is insufficient. The repaired producer lets idle readiness remain truthful at those boundaries.

## Preserved safety

When Return is held, the same true latch is written, the pending press is cleared and held fire cannot restart work or EMP charge. The existing fresh-press/release logic remains byte-identical. Damage and impact can still set a hard stop directly, and this change never clears one. Native hot-work flush, refused-command rollback, actor-owned trigger state, EMP checks, cooldown/energy limits, station target/law/contact checks, missile native stock/publication barriers and every consumer of `workFireSuspended` remain byte-identical.

The production delta is one conditional assignment plus its explanatory comment in `FlightControlInput.swift`. Removing that conditional wrapper restores the entire parent production file byte for byte. No Game field, layout, schema, authority, tolerance, deadline, budget, mission validation or existing fixture/assertion changes. The earlier opt-in observation source remains default off and is not expanded by this repair.

## Regression and validation

One new parameterized regression uses the actual released-trigger W/Tab/F/Q paths. Each must preserve released/pending state, require no invented fresh press and emit no audio, heat or energy consumption. It then creates an actual damage stop while a work tool is selected and verifies the same idle key preserves that stop until the existing release observation clears it. All prior test bytes remain unchanged after removing this one method.

G1's direct selection should include both original CI568 methods with the observation flag off; all original CI566 failing Station AUTO cases (native mounted hit, finite/unlimited missile publication, save refusal/rebinding, military ECM order for both axes, opportunistic range1000/3000); the rest of StationAutoDefenceTests for current safety refusals; `FlightControlInputTests` for held Return, refused hot flush and pending-command rollback; `MiningWorkToolTests` for damage interruption; `FlightWorkGuidanceRuntimeTests` for work release/momentum; and `ScriptProcurementMissileDefenceTests` for stock budgets, active ECM, native refusal and control preservation. Root also routes the unchanged historical-docking forgery arguments as dependency checks. Their previous live-flight deaths are not proven to share this cause; no historical fixture or authentication change is included.

Author validation is strict Swift formatting, paired-note Markdown lint, whitespace checks and exact source correspondence. No author compiler, native, GUI, runtime, test, profile, ABI or debugger job was run. G1 owns one independent review/build after current569 closure and the allocated meaningful regression batch. There is no automatic observation retry, whole-CI run, renderer task or claim of completed defence acceptance in this source leaf.
