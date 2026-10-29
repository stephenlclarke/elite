# M01 ASAN test memory profile

## Problem and resulting behavior

The existing admission estimate needs 6 GiB while only about 4.3-4.6 GiB is available. ASAN already runs serially, but each packed process can retain unrelated suite state. This change reduces its packing target to 16 IDs and measures its owned process tree against the configured worker allocation during actual test execution. [Issue and acceptance criteria](ISSUE-m01-asan-test-memory.md).

## Implementation

`make_plan` applies the 16-ID limit to address mode at every existing entry point, including callers requesting the former 64-ID target. The plan validator refuses multi-atom address selections above 16 IDs. Larger single atoms remain intact. The retained inventory calculation produces 200 jobs instead of 52, below the existing 256-job limit, with all 3,403 IDs exactly once. The larger indivisible selections contain 170, 31, 26, 26, 22, 21, 20, 18, 17 and 17 IDs. The AppKit and salvage shared groups remain complete. Process exit and cleanup between jobs release process-local state; no process reset occurs inside a required shared cohort.

Only a `NativeMonitor` bound to an address test runtime requests the resident-size column in its existing process snapshot. Darwin `ps` reports KiB; the parser converts to bytes and rejects missing, malformed or duplicate rows. The same snapshot supplies ownership and RSS. Accounting sums only freshly matched owned descendants, including the Swift command and its helper. Its existing polling loop waits 0.1 seconds between observations; snapshot, image verification and persistence add time to that interval. RSS sums can count shared pages repeatedly and are not physical-footprint measurements.

`processes.json` retains sample count, helper sample count, current sum, high-water sum, configured budget and failure reason. Missing RSS, snapshot errors, no helper sample or a sum above `recoverable_shards.admission.peak_per_worker` fails execution. The existing cleanup helper freshly verifies PID/start/command before each signal. Initial and asynchronous budget refusal terminate owned processes, preserve raw progress and return a failed outcome through the existing child-exit path. A memory observation never replaces XML or a sealed result as pass authority. Non-ASAN snapshots and normal/leak monitors retain their existing behavior.

## External resource policy and identity

G1 owns policy generation and installation. The candidate fixed-host allocation is `explicit=1`, `cpu_budget=1`, `ram_reserve=2147483648` and `peak_per_worker=2147483648`: 4 GiB total, leaving about 0.3-0.6 GiB against the supplied postboot range. Preserve all other reviewed CPU/disk/path/authentication fields. There is no new policy schema, environment override or budget exemption. The monitor reads the actual configured worker allocation, and the existing execution-policy digest binds those admission values into the child runtime identity. Source inputs bind the real packing and monitoring implementation; ASAN build flags remain the c15 single-job/nonbatch flags.

These admission fields are shared by the existing preparation and execution route. The new sampled refusal applies to ASAN test children only; it does not establish a compiler, normal, leak or TSAN memory peak. G1 must review the complete candidate policy and its stage applicability before installation. This packet does not mutate any policy or assert that the candidate will fit.

The 17 original c15 receipts remain historical proof for their original identity: 1,194 IDs, comprising 1,189 executed and 5 GPU-inactive IDs. Changed source and resource-policy digests require a fresh committed runtime, build/plan and qualification. Smaller packed selections also change shard identities. No receipt is sliced, relabelled, imported or promoted into the new profile, even if executable bytes happen to match. Existing receipt validators and sanitizer options remain unchanged.

## Validation

The focused Python run passes 21 tests: 13 new ASAN memory cases, six existing planning cases, one affected granularity case and one existing helper-image binding case. They cover full atomic membership, unchanged thread packing, old packed-plan refusal, KiB conversion, PID reuse, high-water retention, missing RSS, snapshot errors, initial and asynchronous budget refusal, fresh-identity cleanup and failed raw child evidence. The retained-inventory planner calculation independently confirms the 200-job exact union and unchanged shared groups. Python parsing, diff whitespace and scoped Markdown lint are checked before freeze. Durable logs and the calculation are supplied with the frozen handoff.

No native compiler, test, game, GUI, resource probe or `make ci` ran in this source-only assignment. G1 is the sole native operator. Independent MBA review is required before integration. G1 must qualify actual ASAN execution of the intact AppKit cohort, salvage cohort and a 16-ID selection with many atoms, retaining real observed maxima and raw failures. Missing samples, exceeded allocation, failed assertions, sanitizer reports, mismatched XML or uncertain cleanup cannot qualify. Transient peaks between samples remain a limit; an intrinsic cohort that exceeds the allocation needs a separate reviewed fixture-lifetime change, not skipped tests or weakened sanitizer diagnostics.

## ASAN-only installer role correction

`reviewed_recoverable_policy` now accepts only the existing full seven-role reservation or the exact ASAN-only reservation `{native_checks, prepare_address, address_shards}`. Duplicate roles remain invalid. The approved list is retained exactly in the installed policy; no other roles are added. All surrounding policy, source, helper, workflow, path, ownership, expiry and manifest checks are unchanged.

Four focused fake tests pass: two new role-profile cases and the two affected existing installation/refusal cases. The new cases exercise all 128 subsets of the seven roles, duplicate and extra roles, both supplied role orders, ASAN-only installation without permission expansion, and refusal of a stale full-profile manifest digest. The installer source change and fake tests require independent review; the prior `2c670642` ASAN implementation clearance remains limited to its frozen scope. G1 retains publication, actual policy/binding review and native qualification. No installed policy or runner was changed by this correction.
