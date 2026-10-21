# Keep staged encounter bodies joined to their private owner

A mission handler can request two declared encounters in one command result. After the first request succeeds, its native bodies and allocator changes exist in the private game candidate, while its owned-encounter record remains in the separate next-instance value. The following native admission validates the existing scene against the candidate's Commander and cannot resolve the first cohort's ownership. The whole handler then rolls back.

The unfiltered 131 run recorded zero owned encounters where the actor-admission fixture required two, and missing `opponents` records in both later-binding cases. These are observed failures. The ownership mismatch above is the subsequent source diagnosis; that log did not establish an exact suspension reason.

Stage the first successful encounter's actual next-instance record into the same private candidate before processing another command. Preserve the exact installed-content, source, legacy-provenance, actor-condition and physical-scene guards. Continue publishing only after every command, final validation and the existing save barrier succeed. A later invalid command must leave the live Commander, scene, allocators and simulation randomness unchanged apart from the intended saved fault state.

Acceptance requires the original two-cohort and forged-source regressions, a real first encounter followed by an invalid second command, and the existing final-publication and save-failure gates. A separate direct destruction fixture must dispatch its genuinely queued native death events before expecting a script report phase. Source review alone does not establish runtime acceptance. See [implementation and validation handoff](PR-staged-encounter-ownership.md).
