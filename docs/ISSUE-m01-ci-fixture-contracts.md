# Required CI fixtures predate shared custody and the normal-only job

## Problem

The required native-runner Python file failed before exercising its intended cases because old fake homes omitted the existing physical executor and custody registry. A metadata fixture bypassed the now-required operator lease. The active workflow fake matrix also had a NativeExecutor stub without config and shared fake homes without custody. These are fixture contract gaps, not reasons to relax production guards.

The revised active workflow uses only native_checks, but the actual installer accepted only the historical full or ASAN role sets. A positive normal/leaks-only fixture reproduced that production rejection with a complete valid profile policy.

## Selected correction

Create private temporary valid-empty registry and executor fixtures; retain existing state for reused fake homes; acquire the actual temporary controller/executor contexts where production requires them. Keep unknown/missing/malformed custody and lease refusal tests. Give the existing non-diagnostic executor fake its empty config. No real operator directory or policy is initialized by these tests.

Allow exactly the current singleton native_checks role on the default backend only when both strict normal/leak profiles validate. Preserve the historical manual role profiles and all unknown/duplicate role refusals. No new backend or schema is introduced. All normal coverage/leak/resource/authorization guards remain.

## Status and boundaries

Focused Python checks pass; independent delta review and final native quality remain pending. ships-check separately reports171 stale GIF inputs and requires actual renderer generation. No Swift game/tests, maintained media, historical proofs/counters, registry state, native process, installed policy or release changed in this packet. See [validation and handoff](PR-m01-ci-fixture-contracts.md).

## Hosted isolation follow-up, 29 October

Actual CI40837312906 exposed remaining fake dependencies on the operator's real custody state and hosted listener environment. Local runs had passed because physical registry state existed and operator variables were absent. The hard-kill Python child does not inherit a parent mock. A nested request/selected fixture also restored mocks out of order, leaving a deleted temporary registry selected after the test. Fix the fixture lifetimes and temporary data, not the production guards. The new hosted-like validation must run the entire native file and active fake classes in one process to detect cross-class pollution.

## Physical job environment follow-up

The real native job then reached another fixture gap: QualityPhaseTests cleared only the policy value while retaining the real native job's GitHub authorization tuple. The production profile selector correctly treated it as hosted quality and refused the empty policy path. The fixture must isolate that tuple entirely while retaining unrelated tool paths and restoring the parent environment. Validate all three files in the required checkpoint Make gate under native-job variables before retrying the real pipeline.
