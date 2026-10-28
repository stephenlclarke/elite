# M01 local sanitizer adapter

## Result

Three explicit commands, `local-prepare`, `local-run` and `local-validate`, execute and validate a sanitizer mode through the existing recovery harness without Actions scheduling, artifact transport or GitHub API calls. The local path has its own owned policy/session and typed authorization record. The existing GitHub path remains independently gated. [Problem and acceptance criteria](ISSUE-m01-local-sanitizers.md).

## Reviewed local policy

G1 owns policy creation and activation after independent source and actual binding review. The policy is an absolute physical owner-only `0400` file outside source, cache, legacy and worker storage. Its exact fields are `approved_head`, `developer_dir`, `swift`, `sdk`, `recoverable_shards` and `local_activation`.

`recoverable_shards` retains the existing storage/admission schema, with exactly worker `one`, `explicit=1` and `cpu_budget=1`. Its `legacy_cache` must be the physical account's `~/Library/EliteNativeCI/sanitizer-checkpoints`. Policies for address and thread modes have independent admission allocations. There is no ASAN budget fallback for TSAN and no new sanitizer override.

`local_activation` has exactly these fields:

| Field | Reviewed value |
| --- | --- |
| `schema`, `kind` | `1`, `local-sanitizer-activation-v1` |
| `mode` | `address` or `thread`, one per policy |
| `workspace` | Exact clean committed physical controller checkout running this helper |
| `sources` | SHA-256 map for `native_runner.py`, `recoverable_shards.py`, `sanitizer_checkpoints.py`, `quality_phase_checkpoints.py`, `crash_artifacts.py` |
| `expires_at` | Future finite Unix time, at most seven days ahead |
| `inventory_sha256` | `fingerprint(sorted(full_discovered_inventory))` from the existing canonical JSON hash helper |
| `inventory_count`, `shard_count` | Independently reviewed expected full counts; actual fresh discovery and planning must match |
| `environment` | `legacy.runtime_identity(runtime_child_environment(parent_environment))`, before adding execution/local-policy digests |

The environment pin includes the actual compiler path, developer directory, test opt-ins, diagnostics and sanitizer controls. It avoids a policy-hash cycle by pinning the parent environment before injection. The runtime then additionally binds the actual local policy's raw SHA-256 and the existing admission-policy digest. Incoming `GITHUB_*`, `RUNNER_*`, GitHub authorization controls and supplied local authorization identities refuse before probes. Cross-mode sanitizer options refuse; reviewed `TSAN_OPTIONS` remain bound and unchanged.

The authority verifies immutable ancestry, all source pins, exact source location, physical Apple Silicon UUID, non-VM hardware, compiler/SDK/developer identity, clean committed head, disjoint owned storage and static capacity. It rechecks local policy/session identity and expiry before runtime verification, admission and launches. Live resource checks retain the existing fail-closed arithmetic.

## Finite session and launch budget

Each separately reviewed immutable `0400` session has exactly `schema`, `kind`, `id`, `head`, `policy_sha256`, `mode`, `worker`, `stage`, `expires_at`, `plan_sha256`, `shards` and `max_launches`. Use schema `1`, kind `local-sanitizer-session-v1`, an actual canonical UUID, the exact policy file SHA-256/source/mode, worker `one`, and an expiry no later than the policy expiry.

| Stage | Plan assignment | Budget |
| --- | --- | --- |
| `prepare` | `null`, with `shards=null` | Exactly one logical preparation |
| `execute` | Exact fresh plan file SHA-256 and a unique list of assigned shard IDs | 1-256 actual shard launches |
| `validate` | Exact same plan file SHA-256, with `shards=null` | Zero launches |

Before use, G1 creates an owned `0600` file named `<session-filename>.state.json` beside the session: `{"schema":1,"session_sha256":"<raw session file SHA-256>","used":0}`. Missing state is an error, never an automatic reset. Existing file claims serialize its durable increment. A failed or uncertain launch consumes its slot; a matching completed receipt consumes none. Repeated preparation needs a newly reviewed finite session rather than resetting its old counter. Validation uses its own zero-launch session. New sessions within the same unchanged policy/runtime may truthfully reuse matching receipts, retaining their original execution authorization.

Both modes acquire the existing physical account's `~/Library/EliteNativeCI/recoverable-control.lock`. Preparation also holds the existing exclusive `sanitizer-checkpoints/executor.lock`; shard execution retains the existing legacy lease and private worker/resource claims. The controller descriptor is inherited by build, discovery and shard children. No per-mode competing controller lock is created. G1 issues ASAN approval first and TSAN approval after ASAN qualification; there is no automatic parallel mode dispatch.

## Operator sequence

The following are command shapes, not an activation or a request to execute them before review. G1 supplies real absolute reserved paths and separately checked file digests, from an environment matching the reviewed policy with no GitHub runner identities.

```sh
python3 Tools/CI/recoverable_shards.py local-prepare \
  --mode address --policy "$LOCAL_POLICY" \
  --local-session "$PREPARE_SESSION" --local-session-digest "$PREPARE_SESSION_SHA256" \
  --output "$FRESH_PLAN" --timeout 7200

python3 Tools/CI/recoverable_shards.py local-run \
  --mode address --policy "$LOCAL_POLICY" \
  --local-session "$EXECUTE_SESSION" --local-session-digest "$EXECUTE_SESSION_SHA256" \
  --input "$FRESH_PLAN" --digest "$FRESH_PLAN_SHA256" --timeout 7200

python3 Tools/CI/recoverable_shards.py local-validate \
  --mode address --policy "$LOCAL_POLICY" \
  --local-session "$VALIDATE_SESSION" --local-session-digest "$VALIDATE_SESSION_SHA256" \
  --input "$FRESH_PLAN" --digest "$FRESH_PLAN_SHA256" --output "$FRESH_COMPONENT"
```

Repeat with `--mode thread` and its own reviewed policy, sessions, plan and component output after ASAN. Preparation uses the existing separate `build_only` checkpoint followed by skip-build discovery/freeze/private restoration. Local execution runs only the unique shard IDs in the immutable session assignment, stops at the first failure, retains raw checkpoints and reports validated progress. G1 can first authorize exact qualification cohorts, then review a finite remaining assignment against the same full plan; a partial assignment cannot produce full component qualification. Resume rechecks each exact receipt and runs only missing work within the remaining approved budget. Timeout, unknown helpers, altered source/image/runtime, failed XML/assertions/diagnostics or exhausted authority cannot qualify.

G1 reserved policy storage under `~/Library/EliteNativeAuthorization/local-reviewed/{head}/{profile}/{mode}/policy.json`, session storage under `~/Library/EliteNativeCI/local-sanitizer-sessions/{policyDigest}/{campaignUUID}/{attemptUUID}`, and separate new cache/worker namespaces. This source packet creates none of those operator reservations and never edits old markers, workers or proof.

## Local component and release gates

`local-validate` recomputes the full assigned inventory/plan, verifies the current prepared private runtime and absence of unknown helpers, and validates every sealed shard through the existing output hashes, exact XML, diagnostics, child exit, source and typed authorization checks. It additionally requires each original local execution assignment to match the exact plan/policy, terminal process/image/UUID/workspace evidence, and successful sampled ASAN RSS evidence within that mode's real allocation. TSAN does not gain an ASAN sampled cap or measured peak claim.

Only a complete exact union produces sealed `component.json` plus its commit digest, with source/mode/plan/policy/runtime/inventory/receipt hashes and the ASAN sampled maximum. Its status is sanitizer component qualification; its release status explicitly remains pending. A missing, partial, tampered, stale, cross-mode or wrong-policy result cannot substitute for the component.

The existing full aggregate still requires both modes, matching full inventory, coverage and zero leaks. `release_macos.publish` still requires exact-main required quality success/main analysis before tag or publication mutation. Root, G1 and MBA must supply a separately reviewed truthful integration of local sanitizer components into that full quality gate before publishing. This adapter does not issue a CI status, bypass protected checks, promote old normal/leak results or claim a complete release pass.

## Validation and remaining work

Twenty-six focused fake tests pass: 16 new local cases, six existing planning cases and four affected GitHub authority/preparation/profile cases. They cover both modes, strict ownership and preprobe refusal, independently pinned environment/allocation, durable budgets, descriptor inheritance, exact receipt reuse, source/plan/mode rejection, and full component refusal for missing, tampered, wrong-image, active, diagnostic or bad-RSS proof. Local fakes prohibit real subprocess/API/probe calls. Python parsing, scoped Markdown lint, diff whitespace and static invariance checks accompany the frozen packet. No compiler, native tests, resources, GUI or operator operation ran; `make ci` remains with G1's reviewed native lease.

Fresh local preparation is mandatory for both modes because maintained tools and the local policy environment change runtime identity. Historical e731/c15/TSAN proof stays unchanged. The original TSAN 4 GiB allocation plus 2 GiB reserve is unmeasured and cannot currently admit against the supplied 4.3-4.6 GiB available range. A separately reviewed follow-on can reduce actual build/test working set and calibrate its own allocation; this packet does not lower the guard, request more memory or assert a fit. Independent source review, actual policy/session review, native qualification and full-quality release integration remain pending.
