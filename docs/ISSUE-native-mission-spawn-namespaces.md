# Native mission restoration rejects independent spawn counters

The first normal police launch can pause an active mission with `MISSION FLIGHT RESTORE REFUSED - PAUSED`. Station security owns a zero-based spawn counter; its first police request has producer `security` and sequence `0`. The mission scene validator incorrectly requires every producer's sequence to be positive. This stops subsequent player fire and patrol progress despite valid mission bindings, equipment and collision geometry.

## Confirmed cause

Run 098 at `61103be6eb50b7e14e71aa85780a31153e14ee07` isolates the failure to spawn allocation addresses. Actual mission bindings pass; local restoration throws `NativeMissionActorAdmissionError.invalidScene`. Independent inspection of run 096 also identifies the legitimate first police spawn: security sequence `0`, shared flight cursor `2`. The original 098 log is retained with SHA256 `c192dc217666794fab4d223b17876167d4e92f16d77d57a6e02a6e67be28ffd4`.

[StationSecurity](../Sources/EliteCore/StationSecurity.swift) creates the request before advancing its own counter. Ambient traffic and NPC persistence also own independent sequences. [NativeMissionEmission](../Sources/EliteCore/NativeMissionEmission.swift) has the related error of comparing all producers against the shared flight cursor, incorrectly rejecting legitimate higher local sequences.

## Required behavior

Every spawn must retain its actual system and visit, with unique identities. Only mission and ordnance spawns use the shared flight allocator: their sequences must be positive and below `nextSpawn`. Other producer-local counters can legitimately be zero or exceed that cursor; their native producer/admission contracts remain authoritative. Foreign, duplicate and invalid shared addresses must still refuse atomically.

See [the matching implementation handoff](PR-native-mission-spawn-namespaces.md). Run 100 compiled, then failed with SIGBUS from stack exhaustion during native actor construction. Its incomplete execution does not establish a passing namespace regression set or full CI.

## Later regression evidence

Run 104 at `104384c956e760df2375d3df8b47064b7ea963c2` completed without signals: all 168 methods started, 164 passed, and four campaign methods failed with 32 issues. Both native actor-admission and emission suites passed, including the four new methods/sixteen cases, capacity/refusal cases and actual first-police-zero control regression. The namespace regression evidence is now positive, while the overall project gate remains failed. Raw-log SHA256: `eee82fb8bbfd7386aef39ef6c1b283614924d37757e4bacd1f41ce3802af5ce8`.

Run 105 at `bef0269e1bb61dc7013ccf443cdae743a47cb9a9` selected only those four campaign methods; all four failed with 32 issues and no signals. Actual flight diagnostics show unpaused, valid starting scenes and real laser discharges, followed by player death with living raiders behind the unchanged forward firing direction. This is separate from the earlier spawn-address pause; it does not reverse the completed native-suite passes or establish a full CI pass. Raw-log SHA256: `4281f7e8bd0b116ff6f1d84a10da43b42885514f6d2a89894d79a2ed158169ec`.
