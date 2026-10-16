# Equipment actor validation evidence

Validated candidate: `19a134f62bc2d2d2520144b5762732ba1524a658`. Its production code and generated media are byte-identical to `09b19a4434e14839204e8569fe24a5002d8d6f4b`; the intervening correction changes only the native test and this evidence document. This record is a later documentation-only commit, not a newly validated runtime candidate.

Lease 023 regenerated all 168 ship references (only the fingerprint manifest changed) and README media (no tracked image changes). Its affected run compiled in 11.65 seconds and completed 64 tests in eight suites in 13.275 seconds, with four failures in the new native shop test after reload. The six actor tests and seven existing native equipment tests passed. The failed log and all 52 native evidence files remain preserved.

The correction retains whole-Commander equality across reload, then uses the actual loaded encoding for subsequent blocked-action checks. Original save-file byte checks remain intact. Lease 024 passed that semantic equality and all 64 affected tests in eight suites in 13.175 seconds (build: 5.79 seconds). Both sanitizers passed the six actor tests plus the new native shop method: Thread Sanitizer took 55.017 seconds (build: 20.83 seconds); serial Address Sanitizer took 20.689 seconds (build: 20.31 seconds). These are focused passes, not full-suite sanitizer results.

The single required `make ci` attempt passed its prechecks, then stopped in coverage: 838 tests in 56 suites completed in 65.320 seconds with 74 assertion issues. The parameter-aware parser matched 73 occurrences to the prior lease-021 failures; one newly visible SolarFlight save-comparison issue remains with the source owner for review. Its raw output shows identical equipment membership in opposite serialized array orders. No correction to that test or runtime was included here. The final coverage report, full-suite sanitizer stages, and leak stage were not reached. Full CI has not passed.

| Lease | Phase | Command seconds | Result |
| --- | --- | ---: | --- |
| 023 | ships | 55.253 | Pass |
| 023 | readme-media | 11.685 | Pass |
| 023 | focused | 27.851 | Fail |
| 024 | focused | 21.124 | Pass |
| 024 | tsan | 83.539 | Pass |
| 024 | asan | 44.239 | Pass |
| 024 | ci | 100.679 | Fail |

Evidence roots are `/tmp/elite-equipment-actor-boundary-023` and `/tmp/elite-equipment-actor-boundary-024`, each retaining raw logs, input maps, and results. Lease 024 has 153 native directory entries: 150 files (83 PNGs and 67 JSON records) plus three phase directories. Phase outputs preserve focused, Thread Sanitizer, Address Sanitizer, and CI captures separately. These are offscreen renderer/event-processing checks, not physical display scanout.

Tracked inputs and private native preference maps remained unchanged during every validation command. The production save retained SHA-256 `bd9d68c6acd4c21a6798cc4ec662d9fe01977244c512d7499851ab8cecf792f7`. Both leases were explicitly released with no validation processes remaining. There was no autosave, publication, formal PR review, main-branch validation, or release in this slice.

| Raw log | SHA-256 |
| --- | --- |
| 023/ships.log | `dcfc7992948005206794bcc23b6efa93a50dbfe4a873e7f68e4345fc095fb9f4` |
| 023/readme-media.log | `858c20641d3345343b14a8f16b7fe6b6532d4fa3869973d7eb61cd98fc87c2eb` |
| 023/focused.log | `7dfd90661397369c109a291f82f01c1bc359c8302da01cced4f48dce93dc2e59` |
| 024/focused.log | `97dd49d4d8c7604a4875b94daad0ab463e3ac1fda0680266fcea946671b59ce6` |
| 024/tsan.log | `e93969b3cca21e6573b01d0a098732b01b7f37e40b647582237307f34cfcc3d5` |
| 024/asan.log | `f0f9caa499edd5651946b75402122581b28128205ea53cf48ebb561ccbbca00d` |
| 024/ci.log | `29533c437095f37501e060c9db34a8d77faf290e124ed39c2b3e35365ece3072` |

The subsequent [combined central 026 gate](CENTRAL-COMBINED-GATE-VALIDATION-026.md) passed on exact committed source `4cf39004374c0d253b955a5150b7b2d5589ddebc`, after the independently reviewed foundation corrections and required renderer regeneration. All 840 tests passed in coverage, full TSan and serial ASan runs; line coverage is 95.08%, and leak diagnostics report zero leaks. This later result preserves the failed isolated 023/024 runs above. The independent whole-app review remains open; passing CI is not a clean review or release approval.
