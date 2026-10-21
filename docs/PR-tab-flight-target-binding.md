# Make Tab the single flight target key

Core flight dispatch, native steering-clear admission and actor post-key control reset now recognize Tab alone. The existing cycleAutoTarget implementation, visible-first/distance ordering, stations, module eligibility and work-guidance controllers are unchanged. No second target cycle or new custody path is introduced. HUD/contextual help, README, controls, targeting guide and maintained UI-integration instructions show Tab. Historical implementation/validation documents explicitly identify their old R references as historical; pinned failure proofs, research source quotes and JSON/native evidence remain unchanged.

Existing flight targeting, mission/combat, docking, work-guidance and EMP fixtures now use Tab while retaining their ordering, identities, ticks, budgets and assertions. Native mining/salvage/missing-module cases retain actual R event delivery as a negative case, require no target/custody mutation, then use actual Tab through the actor dispatcher for the original behavior. Native painted-absence coverage requires only Tab to clear steering. The existing native steering/docking test also checks R leaves held steering and target state alone before Tab engages its original behavior.

Three new regression methods cover all four cockpit views with R inert and Tab's existing ship-then-station cycle; actual actor key delivery preserving controls on R and resetting them for Tab docking; and R remaining normal chart/showroom search text. Existing showroom reset, gallery retry, passenger refit, market/inventory/showroom Tab focus tests remain unchanged.

FR-008 was copied verbatim from the recovery log before its own status was updated to source-prepared. Every other request row/status remains unchanged. Only this request's source work is described here; independent source review, real execution and release evidence must be recorded separately.

## Validation and limits

Worker validation is source formatting, strict Swift lint, scoped Markdown lint and whitespace checks. No compiler, typecheck, tests, native process, renderer/media, CI, push, PR, merge or release ran. The active G1 candidate/run is unchanged. The new and amended native/actor regressions have not executed; G1 owns integration and affected/full validation after lease closure. Any regenerated screenshots/media must use the maintained game renderer. No runtime, performance or complete delivery is claimed. See [motivation](ISSUE-tab-flight-target-binding.md).
