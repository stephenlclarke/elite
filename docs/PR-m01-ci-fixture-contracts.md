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
