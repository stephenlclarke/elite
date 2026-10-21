# feat(flight): observe Crimbo attainment after native actor advance

## Result and implementation

Game retains one optional non-Codable world-unit attained-motion observation. `GameRuntime.advance` clears that observation and the prior sample before `prepareAdvance`, including paths that return early from preflight. The existing physical tick and native station entry retain their single owners. One observer call runs after native entry/fatal handling and before people capture and script drains.

The wrapper authenticates the actor's captured active-flight state, starting physical time and exact player binding against the current physical clock, frame, epoch and sample. It rejects paused, docked, fatal, native-entry-attempt and current/changed contact-marker states. It checks the actual admitted `min(requestedDelta, 0.1)` with bounded floating-point clock tolerance. It consumes `finishNativeCrimboMotion` once, then clears the sample on every path. Observer errors clear the observation without changing or rolling back physical state.

Completed native simulation in cockpit, status, chart and other active views uses the same actual-step checks; no cockpit-only camera gate is added. Returned poses, velocities and signed tangential displacement remain explicitly native world units. This observation supplies no synthetic route distance, metre interval, reward or mission readiness.

## Authored verification

Eight new test methods define 24 cases in a dedicated actor-path file. Every method calls actual `GameRuntime.advance`. Definitions cover real movement across nine active views, snapshot reads and duplicate callback/no-tick refusal, requested time above 0.1 seconds, paused/docked/default-false/game-over/help states, fatal physical effects, actual main-station collision, actual refused RRS doorway entry, and actual mission-actor preflight refusal before physical changes. Supplemental refusal probes reconstruct transient data from a real actor-produced observation, tamper a test Game copy and verify that teleport, stale epoch/player/start and contact-marker inputs yield no evidence while preserving already-applied body and damage state. Those probes are injected boundary tests, not native permission or actual teleport acceptance claims.

All awaited, mutating and throwing operations in the new tests are evaluated before assertion macros, apart from dedicated optional-value requirements. Formatter/parser, strict scoped lint, Markdown and diff/scope checks are the only local validation. No compiler, typecheck, test discovery/execution, native job or performance result is claimed; G1 owns meaningful actor-path execution and applicable `make ci` gates.

## Scope and remaining integration

Only the optional Game field, advance-start resets and exact finishAdvance observer insertion in Game, the wrapper in NativeCrimboRuntime, the dedicated test file and this [issue/PR pair](ISSUE-native-crimbo-actor-motion.md) change. Existing fatal/native-entry/people/script order is retained. The prerequisite test-macro correction is separate and excluded from this owned leaf.

Production readiness remains false by default. G1 retains supported save 28/global owner/durability publication, alien integration, combat/group law, EMP/death/core/people/relay/service observers and all four Guiding Light branches. No capability is advertised and no SI mapping is assumed. Eventual project PRs require actual completed clean `@codex review` cycles and passing final-head checks and approvals before protected merge, without bypass.
