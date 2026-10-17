# Native mission restoration rejects independent spawn counters

The first normal police launch can pause an active mission with `MISSION FLIGHT RESTORE REFUSED - PAUSED`. Station security owns a zero-based spawn counter; its first police request has producer `security` and sequence `0`. The mission scene validator incorrectly requires every producer's sequence to be positive. This stops subsequent player fire and patrol progress despite valid mission bindings, equipment and collision geometry.

## Confirmed cause

Run 098 at `61103be6eb50b7e14e71aa85780a31153e14ee07` isolates the failure to spawn allocation addresses. Actual mission bindings pass; local restoration throws `NativeMissionActorAdmissionError.invalidScene`. Independent inspection of run 096 also identifies the legitimate first police spawn: security sequence `0`, shared flight cursor `2`. The original 098 log is retained with SHA256 `c192dc217666794fab4d223b17876167d4e92f16d77d57a6e02a6e67be28ffd4`.

[StationSecurity](../Sources/EliteCore/StationSecurity.swift) creates the request before advancing its own counter. Ambient traffic and NPC persistence also own independent sequences. [NativeMissionEmission](../Sources/EliteCore/NativeMissionEmission.swift) has the related error of comparing all producers against the shared flight cursor, incorrectly rejecting legitimate higher local sequences.

## Required behavior

Every spawn must retain its actual system and visit, with unique identities. Only mission and ordnance spawns use the shared flight allocator: their sequences must be positive and below `nextSpawn`. Other producer-local counters can legitimately be zero or exceed that cursor; their native producer/admission contracts remain authoritative. Foreign, duplicate and invalid shared addresses must still refuse atomically.

See [the matching implementation handoff](PR-native-mission-spawn-namespaces.md). Run 100 compiled, then failed with SIGBUS from stack exhaustion during native actor construction. Its incomplete execution does not establish a passing namespace regression set or full CI.
