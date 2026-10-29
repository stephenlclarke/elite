# test(ci): restore required fixture contracts and normal-only installation

## Result

Required runner fixtures now create the existing owned temporary executor and valid-empty registry, and use witnessed controller/executor custody for protected calls. Shared fake homes preserve prior state instead of reinitializing it. The non-diagnostic NativeExecutor fake supplies its existing empty config. Production custody, lease and identity guards are unchanged.

The installer accepts the current exact native_checks role with both strict normal/leak profiles on the default backend. Missing, partial or malformed profiles refuse; legacy/manual role sets and duplicate/unknown job refusals remain. The positive fixture failed on the old production code, then passed after the narrow correction. No new backend, policy field or framework is added. [Problem and scope](ISSUE-m01-ci-fixture-contracts.md).

## Validation

- Required native-runner file:63 methods pass after fixture repair and the singleton installer correction.
- Complete active workflow fake matrix:125 methods pass, including the26 affected Process/OwnedQualityBridge methods.
- Four focused installer methods pass after the singleton correction, including six new refusal mutations, legacy role combinations and occupied-lease behavior. The retained pre-fix positive failure establishes the regression.
- Existing static targets pass instance equality25, crash evidence60, flight controls11, distribution39, showroom57, sanitizer checkpoint contract32, normal/leak contract17 and normal attestation7 tests. These are Python/static checks and do not run sanitizers or Swift workloads.
- ships-check refuses all171 stale GIF fingerprints. Actual renderer regeneration remains necessary before final full CI; no fingerprint waiver is applied.

Saved raw logs remain under the owned operator-recovery directory. Initial failures are retained. No broad Swift/native run, sanitizer, profiler, leak probe or Sonar publication occurred. The cleared458c CI-removal review is retained for unchanged production scope; this packet needs one narrow independent review before integration. Current normal/leak assertions and resource bounds, protected checks/review and main/release gates remain required.

## Hosted isolation follow-up, 29 October

The common fake fixture now creates a private valid-empty registry and executor in a temporary home. The deliberately hard-killed Python child constructs its own temporary home before running fake work. Operator preparation/registration fixtures remove ambient GitHub listener variables only within their scoped fake environment, then restore them. The nested selected-role test registers outer request cleanups before activating the inner selected stack, so close order no longer restores an already closed mock. Exit stacks also have owner cleanup for failure paths.

The full native-runner file plus active workflow fake classes pass152 cases together with hosted `GITHUB_ACTIONS`, job/run/workflow and runner variables set. New checks retain missing-registry refusal, verify all six hostile listener keys still refuse inside the isolated operator fixture, restore ambient environment, and assert the original custody function returns after nested fixture cleanup. Earlier84-case isolated success and failed combined runs are retained as narrower evidence. The production custody, authorization and operator-only predicates are unchanged. No real registry, Swift workload, sanitizer or native quality result is created by these tests. Independent delta review and final hosted quality remain required.
