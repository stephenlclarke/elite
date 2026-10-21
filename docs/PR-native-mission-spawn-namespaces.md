# fix(missions): respect producer-local spawn sequence namespaces

A legitimate first police spawn uses security sequence `0`; mission restoration previously rejected it and paused flight. The fix also permits independent ambient/persistence counters above the shared flight cursor while retaining strict mission/ordnance allocation bounds. See [the confirmed issue and original failure evidence](ISSUE-native-mission-spawn-namespaces.md).

## Change and safeguards

Source feature `929c528e9a8760bf0effef1e3e6793dbb4b5db19` adds the small internal [spawn-address predicate](../Sources/EliteCore/NativeMissionSpawnAddress.swift) at two production sites: [actor admission](../Sources/EliteCore/NativeMissionActorAdmission.swift) and [projectile emission](../Sources/EliteCore/NativeMissionEmission.swift). Current system/visit and unique spawn identities remain mandatory. Mission/ordnance require `0 < sequence < nextSpawn`; other producers retain their own counter namespaces. Emission rejects foreign and duplicate addresses before allocation. Source, fit, binding, capacity, archive and publication checks remain intact. The projectile-restoration allocator-capacity check is unchanged.

Four new native methods cover sixteen cases: real mixed-producer admission followed by retained restoration/plasma emission, plus atomic refusal of mission/ordnance zero/cursor, foreign-system/visit and duplicate addresses at both affected sites. The existing control regression now witnesses the actual first StationSecurity police sequence `0`, retained bindings/restoration, rejected foreign-epoch controls and successful current-epoch fire. Redundant diagnostic guard copies are removed.

## Validation

Source formatting, whitespace, original-test inventory and patch application checks pass. Run 100 compiled at `eeae022efe617a89bd7bb5a45f9dafe26489c9bb` under coverage with default parallelism, but **failed**: 167 of 168 selected methods started and 22 completed passes before signal 10/SIGBUS. The matched crash reports thread stack exhaustion in `Game.missionActorAdmissionTemplate`, reached from `unboundLiveObstacleRefusesBeforeCapacityOrAlreadyPresentNoop`. There was no final Swift Testing summary; remaining outcomes are unestablished.

Evidence is retained in `/tmp/elite-composed-regressions-100/`: raw-log SHA256 `3a72510876afd81f39e0e3031067a9c03e53f99d822ea0acee4c64831eb387ef`, independent-verification SHA256 `565ed3b40ea06980f40b3bcc67584c4784d2659f486b03485ee698caf5a45199`, and crash SHA256 `7d84e2ac338b9b7894f4b7968d747853267ce1cf379f161aef8c7aa0ecb51202`. No complete regression pass, full CI, sanitizer, leak or release result is claimed. G1 retains publication, completed clean `@codex review`, final-head checks and protected merge ownership.

## Subsequent completed evidence

Run 104 at `104384c956e760df2375d3df8b47064b7ea963c2` completed all 168 selected methods without signals: 164 passed and four campaign methods failed with 32 issues. The entire native actor-admission and emission suites passed, including all four new methods/sixteen cases, original capacity/refusal cases and the actual first StationSecurity zero-sequence/fresh-control regression. Terminal campaign checks passed in both policy cases. Raw log: `/tmp/elite-composed-regressions-104/candidate-104-attempt-01.log`, SHA256 `eee82fb8bbfd7386aef39ef6c1b283614924d37757e4bacd1f41ce3802af5ce8`.

Run 105 at `bef0269e1bb61dc7013ccf443cdae743a47cb9a9` narrowed execution to the four remaining campaign methods: four started, zero passed, four failed with 32 issues, and no signals. Read-only diagnostics distinguish actual unpaused fire and player death with surviving moving raiders from the repaired restoration pause. Raw log: `/tmp/elite-patrol-flight-diagnostics-105/candidate-105-attempt-01.log`, SHA256 `4281f7e8bd0b116ff6f1d84a10da43b42885514f6d2a89894d79a2ed158169ec`. These completed results establish the stated native regression passes, not a clean project regression set, full CI or permission to merge before the final review/check gates.
