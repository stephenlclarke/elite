# fix(tests): synchronize the Crimbo native entry fixture

## Result and implementation

The station fixture now performs one real native `Game.tick` instead of advancing physical time and the convoy adapter separately. This advances the rotating station model with the same physical clock used by native doorway detection. Both affected actor tests still exercise actual `GameRuntime.advance`.

The refused RRS entry test requires the authentic station rigid pose before approach and checks the real old/end doorway depths, including entry into the existing tunnel. It retains the original expected save-location refusal, undocked state, cleared pending proof, advanced physical time and discarded attained-motion/sample assertions. Other test methods and production entry/observer code remain unchanged.

## Evidence and validation

The actual run-318 failure reported the unchanged launch message and a non-nil motion observation. Source inspection identified the native rigid-pose gate and the fixture's permanent 0.002-radian phase lag at 0.1 seconds. This is a source diagnosis correlated with the runtime failure; the corrected fixture has not been executed here.

Formatter/parser, scoped strict lint, Markdown and exact helper/method-only diff checks passed. No compiler, typecheck, test discovery/execution or native job ran. G1 must rerun the refused-entry case and shared main-contact fixture case, preserving the other completed passing scopes and applicable `make ci` requirements.

## Scope

Only `NativeCrimboActorMotionTests.swift` and this [issue/PR pair](ISSUE-native-crimbo-entry-fixture.md) change. No entry authority is manufactured and no production guard, save path, capability or activation changes. Eventual PRs still require actual completed clean `@codex review` cycles and passing final-head required checks and approvals before protected merge, without bypass.
