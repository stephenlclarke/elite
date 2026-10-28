"""Exercise the physical runner's host-owned authorization without launching a target."""

import copy
import unittest
from native_runner import require_trusted_job

SHA = "a" * 40
REPO = {"full_name": "stephenlclarke/elite", "fork": False}


def fixture():
    """Return a trusted internal PR event with an immutable reviewed head."""
    environment = {"GITHUB_REPOSITORY": REPO["full_name"], "GITHUB_ACTOR_ID": "22142777",
                   "GITHUB_JOB": "quality", "GITHUB_EVENT_NAME": "pull_request",
                   "GITHUB_WORKFLOW_REF": REPO["full_name"] + "/.github/workflows/ci.yml@refs/pull/25/merge"}
    event = {"repository": copy.deepcopy(REPO), "sender": {"id": 22142777},
             "pull_request": {"head": {"sha": SHA, "repo": copy.deepcopy(REPO)},
                              "base": {"ref": "main", "repo": copy.deepcopy(REPO)},
                              "user": {"id": 22142777}}}
    return environment, event


class NativeAuthorizationTests(unittest.TestCase):
    def test_exact_internal_pr_is_allowed(self):
        env, event = fixture()
        require_trusted_job(env, event, SHA)

    def test_each_external_or_misrouted_identity_is_rejected(self):
        mutations = [
            lambda e, p: e.update(GITHUB_REPOSITORY="outside/elite"),
            lambda e, p: e.update(GITHUB_ACTOR_ID="2"),
            lambda e, p: e.update(GITHUB_JOB="untrusted"),
            lambda e, p: e.update(GITHUB_EVENT_NAME="pull_request_target"),
            lambda e, p: e.update(GITHUB_WORKFLOW_REF=REPO["full_name"] + "/.github/workflows/other.yml@refs/heads/main"),
            lambda e, p: p["repository"].update(fork=True),
            lambda e, p: p["sender"].update(id=2),
            lambda e, p: p["pull_request"]["head"].update(sha="b" * 40),
            lambda e, p: p["pull_request"]["head"]["repo"].update(fork=True),
            lambda e, p: p["pull_request"]["head"]["repo"].update(full_name="outside/elite"),
            lambda e, p: p["pull_request"]["base"].update(ref="other"),
            lambda e, p: p["pull_request"]["base"]["repo"].update(full_name="outside/elite"),
            lambda e, p: p["pull_request"]["user"].update(id=2),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutations.index(mutate)):
                env, event = fixture()
                mutate(env, event)
                with self.assertRaises(ValueError):
                    require_trusted_job(env, event, SHA)

    def test_push_requires_exact_main_commit_without_force_or_delete(self):
        env, event = fixture()
        env.update(GITHUB_EVENT_NAME="push", GITHUB_REF="refs/heads/main", GITHUB_SHA=SHA)
        event.update(ref="refs/heads/main", after=SHA, deleted=False, forced=False)
        require_trusted_job(env, event, SHA)
        for field, value in [("ref", "refs/heads/other"), ("after", "b" * 40),
                             ("deleted", True), ("forced", True)]:
            changed = copy.deepcopy(event)
            changed[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                require_trusted_job(env, changed, SHA)

    def test_dispatch_requires_exact_approved_branch_commit(self):
        env, event = fixture()
        env.update(GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_REF="refs/heads/main", GITHUB_SHA=SHA)
        require_trusted_job(env, event, SHA)
        for changes in [{"GITHUB_REF": "refs/tags/v1"}, {"GITHUB_SHA": "b" * 40}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                require_trusted_job(dict(env, **changes), event, SHA)

    def test_missing_metadata_or_invalid_approval_never_authorizes(self):
        for approved in ["", "A" * 40, "../main", "a" * 39]:
            with self.subTest(approved=approved), self.assertRaises(ValueError):
                require_trusted_job({}, {}, approved)
        env, event = fixture()
        for key in env:
            incomplete = dict(env)
            del incomplete[key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                require_trusted_job(incomplete, event, SHA)


class RecoverableAuthorizationTests(unittest.TestCase):
    def contract(self):
        from native_runner import assignment_digest, assignment_payload, policy_digest
        from pathlib import Path
        from tempfile import TemporaryDirectory
        import json
        env, event = fixture()
        workflow = REPO["full_name"] + "/.github/workflows/recoverable-quality.yml@refs/heads/approved"
        env.update(GITHUB_JOB="native_shards", GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_SHA=SHA,
                   GITHUB_REF="refs/heads/approved", GITHUB_WORKFLOW_REF=workflow, RUNNER_NAME="owned-one",
                   GITHUB_WORKSPACE="/fixture/native-runner/_work/elite/elite",
                   GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1", PLAN_DIGEST="e" * 64,
                   ELITE_RECOVERABLE_CODE_ENABLED="true",
                   ELITE_NATIVE_APPROVED_HEAD=SHA, ELITE_NATIVE_POLICY="/fixture/owned-policy.json",
                   ELITE_RECOVERABLE_PLAN_SHA256="e" * 64,
                   ELITE_RECOVERABLE_REQUEST_MODE="thread", ELITE_RECOVERABLE_REQUEST_SHARD="f" * 64,
                   ELITE_RECOVERABLE_REQUEST_WORKER="one",
                   ELITE_RECOVERABLE_WORKFLOW_SHA256="c" * 64, ELITE_RECOVERABLE_ACTIVATION_SHA256="d" * 64)
        temporary = TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        assignment_root = Path(temporary.name).resolve()
        policy = {"approved_head": SHA, "recoverable_activation": {
            "schema": 1, "enabled": True, "revoked": False, "expires_at": 200,
            "head": SHA, "workflow_ref": workflow, "workflow_sha256": "c" * 64,
            "manifest_sha256": "d" * 64, "runners": {"owned-one": {
                "workspace": env["GITHUB_WORKSPACE"], "jobs": ["native_shards"]}},
            "assignment_root": str(assignment_root)}}
        policy["recoverable_shards"] = {"host": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
        activation = policy["recoverable_activation"]
        manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head",
                                                       "workflow_sha256", "runners", "assignment_root")}
        manifest["ref"] = env["GITHUB_REF"]
        activation["manifest_sha256"] = policy_digest(manifest)
        env.update(ACTIVATION=json.dumps(manifest), ELITE_RECOVERABLE_ACTIVATION_SHA256=policy_digest(manifest))
        env["ELITE_RECOVERABLE_POLICY_SHA256"] = policy_digest(policy)
        env["POLICY_DIGESTS"] = json.dumps({"owned-one": policy_digest(policy)})
        binding = {**assignment_payload(policy, env), "expires_at": 190, "revoked": False}
        path = assignment_root / (assignment_digest(env) + ".json")
        path.write_text(json.dumps(binding))
        path.chmod(0o400)
        env["ELITE_RECOVERABLE_ASSIGNMENT_PATH"] = str(path)
        env["ELITE_RECOVERABLE_ASSIGNMENT_SHA256"] = policy_digest(binding)
        from unittest.mock import patch
        owner = patch("native_runner.require_owned_activation_file")
        owner.start()
        self.addCleanup(owner.stop)
        return policy, env, event

    def test_explicit_manual_contract_accepts_only_reserved_instance(self):
        from native_runner import require_recoverable_job
        policy, env, event = self.contract()
        self.assertEqual(require_recoverable_job(policy, env, event, now=100), policy["recoverable_activation"])

    def test_default_ci_policy_never_authorizes_new_workflow(self):
        from native_runner import require_recoverable_job
        _, env, event = self.contract()
        with self.assertRaises(ValueError):
            require_recoverable_job({"approved_head": SHA}, env, event, now=100)
        with self.assertRaises(ValueError):
            require_trusted_job(env, event, SHA)

    def test_contract_drift_expiry_revocation_source_policy_and_instances_fail_closed(self):
        from native_runner import require_recoverable_job
        mutations = [lambda p, e: e.update(GITHUB_SHA="b" * 40),
                     lambda p, e: e.update(GITHUB_ACTOR_ID="2"),
                     lambda p, e: e.update(GITHUB_EVENT_NAME="push"),
                     lambda p, e: e.update(GITHUB_JOB="arbitrary-job"),
                     lambda p, e: e.update(GITHUB_WORKFLOW_REF="outside/workflow"),
                     lambda p, e: e.update(RUNNER_NAME="unreserved"),
                     lambda p, e: e.update(GITHUB_WORKSPACE="/other/path"),
                     lambda p, e: e.update(ELITE_RECOVERABLE_WORKFLOW_SHA256="f" * 64),
                     lambda p, e: e.update(ELITE_RECOVERABLE_ACTIVATION_SHA256="f" * 64),
                     lambda p, e: e.update(ELITE_RECOVERABLE_CODE_ENABLED="false"),
                     lambda p, e: e.update(ELITE_NATIVE_APPROVED_HEAD="b" * 40),
                     lambda p, e: e.update(ELITE_NATIVE_POLICY="/other/owned-policy.json"),
                     lambda p, e: e.update(PLAN_DIGEST="f" * 64),
                     lambda p, e: e.update(GITHUB_RUN_ATTEMPT="2"),
                     lambda p, e: e.update(ELITE_RECOVERABLE_REQUEST_SHARD="b" * 64),
                     lambda p, e: p["recoverable_activation"].update(expires_at=99),
                     lambda p, e: p["recoverable_activation"].update(expires_at=float("inf")),
                     lambda p, e: p["recoverable_activation"].update(revoked=True),
                     lambda p, e: p.update(guard_sha256="changed-guard-and-policy")]
        for mutate in mutations:
            policy, env, event = self.contract()
            mutate(policy, env)
            with self.subTest(mutation=mutations.index(mutate)), self.assertRaises(ValueError):
                require_recoverable_job(policy, env, event, now=100)

    def test_safe_hook_diagnostic_names_actual_job_and_event_guard_failures(self):
        import native_runner
        policy, env, event = self.contract()
        env["GITHUB_JOB"] = "unapproved-role"
        try:
            native_runner.require_recoverable_job(policy, env, event, now=100)
        except ValueError as error:
            record = native_runner.authorization_failure(error)
        else:
            self.fail("The unchanged job guard must still refuse")
        self.assertEqual({key: record[key] for key in ("stage", "predicate", "category")},
                         dict(stage="pre-job", predicate="exact-job-contract", category="ValueError"))
        self.assertIs(type(record["owned_line"]), int)
        policy, env, event = self.internal_pr_contract()
        event["pull_request"]["head"]["sha"] = "c" * 40
        try:
            native_runner.require_recoverable_event(policy["recoverable_activation"], env, event)
        except ValueError as error:
            record = native_runner.authorization_failure(error)
        self.assertEqual(record["predicate"], "execution-source-ref")
        self.assertNotIn("c" * 40, repr(record))

    def test_safe_hook_diagnostic_never_formats_secret_bearing_or_unknown_errors(self):
        import json, subprocess
        from unittest.mock import patch
        import native_runner
        secret = "FAKE-PRIVATE-TOKEN-POLICY-PAYLOAD"
        class UnprintableValueError(ValueError):
            def __str__(self):
                raise AssertionError("Exception text must never be formatted")
        errors = [(UnprintableValueError(secret), "ValueError"), (KeyError(secret), "KeyError"),
                  (OSError(secret), "OSError"),
                  (subprocess.CalledProcessError(1, [secret], output=secret, stderr=secret), "SubprocessError"),
                  (RuntimeError(secret), "unknown")]
        for error, category in errors:
            with self.subTest(category=category), patch.dict("os.environ", {"GITHUB_TOKEN": secret, "GITHUB_JOB": secret}):
                record = native_runner.authorization_failure(error)
                self.assertEqual(record, dict(stage="unknown", predicate="unknown", category=category, owned_line=None))
                self.assertNotIn(secret, json.dumps(record))
                self.assertEqual(set(record), {"stage", "predicate", "category", "owned_line"})

    def test_safe_hook_diagnostic_unknown_owned_site_emits_only_integer_not_name_or_path(self):
        import json
        import native_runner
        private_name = "FAKE_PRIVATE_FUNCTION_NAME"
        source = "def " + private_name + "():\n    raise ValueError('FAKE_PRIVATE_ARGUMENT')\n"
        scope = {}
        exec(compile(source, native_runner.__file__, "exec"), scope)
        try:
            scope[private_name]()
        except ValueError as error:
            record = native_runner.authorization_failure(error)
        self.assertEqual(record, dict(stage="unknown", predicate="unknown", category="ValueError", owned_line=2))
        self.assertNotIn(private_name, json.dumps(record))
        self.assertNotIn(native_runner.__file__, json.dumps(record))

    def test_safe_hook_entrypoint_keeps_nonzero_exit_and_suppresses_raw_exception_context(self):
        import ast, json, subprocess, sys
        from pathlib import Path
        import native_runner
        source = Path(native_runner.__file__).read_text()
        entrypoint = next(node for node in ast.parse(source).body if isinstance(node, ast.If)
                          and isinstance(node.test, ast.Compare) and ast.unparse(node.test) == "__name__ == '__main__'")
        expressions = ["ValueError('FAKE_PRIVATE_VALUE')", "KeyError('FAKE_PRIVATE_KEY')",
                       "OSError('FAKE_PRIVATE_PATH')",
                       "subprocess.CalledProcessError(1, ['FAKE_PRIVATE_COMMAND'], output='FAKE_PRIVATE_OUTPUT', stderr='FAKE_PRIVATE_STDERR')"]
        for expression in expressions:
            # Run only the real handler AST with an injected failing main, never a real hook.
            script = ("import ast, subprocess\nimport native_runner as native\n"
                      "def main():\n    raise " + expression + "\n"
                      "scope = dict(native.__dict__, __name__='__main__', main=main)\n"
                      "node = next(n for n in ast.parse(" + repr(source) + ").body if isinstance(n,ast.If) and isinstance(n.test,ast.Compare) and ast.unparse(n.test)==\"__name__ == '__main__'\")\n"
                      "exec(compile(ast.Module(body=[node],type_ignores=[]), native.__file__, 'exec'), scope)\n")
            result = subprocess.run([sys.executable, "-c", script], cwd=Path(native_runner.__file__).parent,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertNotIn("FAKE_PRIVATE", result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertNotIn(native_runner.__file__, result.stderr)
            record = json.loads(result.stderr.split("Native quality authorization failed: ", 1)[1])
            self.assertEqual(set(record), {"stage", "predicate", "category", "owned_line"})
        # The source handler's suppression and caught classes are preserved exactly.
        handler = entrypoint.body[0].handlers[0]
        self.assertEqual(ast.unparse(handler.type), "(KeyError, OSError, ValueError, subprocess.SubprocessError)")
        self.assertIsInstance(handler.body[-1], ast.Raise)
        self.assertIsInstance(handler.body[-1].cause, ast.Constant)
        self.assertIsNone(handler.body[-1].cause.value)

    def test_invalid_new_contract_is_rejected_before_physical_probe(self):
        import json
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from unittest.mock import patch
        from native_runner import validate
        policy, env, event = self.contract()
        env["RUNNER_NAME"] = "unknown"
        with TemporaryDirectory() as folder:
            path = Path(folder) / "event.json"
            path.write_text(json.dumps(event))
            env["GITHUB_EVENT_PATH"] = str(path)
            with patch("native_runner.require_physical_host") as physical, self.assertRaises(ValueError):
                validate(policy, env)
            physical.assert_not_called()

    def test_prejob_authorizer_authenticates_workflow_then_issues_owned_assignment_and_rejects_replay(self):
        import base64
        import hashlib
        import json
        from pathlib import Path
        from types import SimpleNamespace
        from native_runner import authorize_recoverable, policy_digest, require_recoverable_job
        for role in ("prepare_native", "native_shards"):
            policy, env, event = self.contract()
            Path(env["ELITE_RECOVERABLE_ASSIGNMENT_PATH"]).unlink()
            source = b"fake reviewed workflow bytes"
            activation = policy["recoverable_activation"]
            activation["runners"]["owned-one"]["jobs"] = [role]
            activation["workflow_sha256"] = hashlib.sha256(source).hexdigest()
            env.update(GITHUB_JOB=role, GITHUB_TOKEN="fake-private-read-token")
            if role == "prepare_native":
                for name in ("PLAN_DIGEST", "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_REQUEST_MODE",
                             "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
                    env.pop(name, None)
            else:
                env.update(PLAN_ID="7", PLAN_ARCHIVE="b" * 64)
            cache = Path(activation["assignment_root"]).with_name(Path(activation["assignment_root"]).name + "-cache")
            policy["recoverable_shards"] = {"host": "fake-host", "cache": str(cache),
                                             "workers": {"one": "/fixture/private-worker"}, "admission": {"disk_per_worker": 1000}}
            manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head",
                                                           "workflow_sha256", "runners", "assignment_root")}
            manifest["ref"] = env["GITHUB_REF"]
            activation["manifest_sha256"] = policy_digest(manifest)
            env.update(ACTIVATION=json.dumps(manifest), POLICY_DIGESTS=json.dumps({"owned-one": policy_digest(policy)}))
            requests = []
            def api(path):
                requests.append(path)
                if "/contents/Tools/CI?" in path:
                    result = []
                    for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                                 "quality_phase_checkpoints.py", "crash_artifacts.py"):
                        raw = (Path(__file__).resolve().parent / name).read_bytes()
                        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw, usedforsecurity=False).hexdigest()
                        result.append({"name": name, "type": "file", "sha": blob})
                    return result
                return ({"encoding": "base64", "content": base64.b64encode(source).decode()}
                        if "/contents/" in path else {"name": "native-plan-1"})
            class Remote:
                def __init__(self, authority, api):
                    pass

                def fetch(self, artifact, digest):
                    self.assertion = digest
                    return Path(activation["assignment_root"])
            class Workflow:
                def __init__(self, authority, remote):
                    pass

                def plans(self, bundle, digest):
                    return [], {"host": "fake-host", "phases": ["normal", "leaks"], "expected": [
                        {"mode": "thread", "shard": "f" * 64, "worker": "one"}]}
            guard = SimpleNamespace(PHYSICAL_EXECUTION_ENABLED=True, GitHubArtifacts=Remote, NativeWorkflow=Workflow)
            issued = authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
            require_recoverable_job(policy, issued, event, now=100)
            binding = Path(issued["ELITE_RECOVERABLE_ASSIGNMENT_PATH"]).read_text()
            self.assertNotIn("fake-private-read-token", binding)
            self.assertEqual(json.loads(binding)["plan_sha256"], None if role == "prepare_native" else "e" * 64)
            self.assertTrue(any("/contents/" in path for path in requests))
            with self.assertRaises(ValueError):
                require_recoverable_job(policy, {**issued, "GITHUB_RUN_ATTEMPT": "2"}, event, now=100)
            guard.PHYSICAL_EXECUTION_ENABLED = False
            requests.clear()
            with self.assertRaisesRegex(ValueError, "HELD"):
                authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
            self.assertEqual(requests, [])

    def test_explicit_new_contract_uses_only_its_named_physical_workspace(self):
        import json
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from unittest.mock import patch
        from native_runner import validate
        policy, env, event = self.contract()
        with TemporaryDirectory() as folder:
            path = Path(folder) / "event.json"
            path.write_text(json.dumps(event))
            env["GITHUB_EVENT_PATH"] = str(path)
            with patch("native_runner.time.time", return_value=100), patch(
                    "native_runner.require_physical_host", return_value=Path(env["GITHUB_WORKSPACE"])) as physical, patch(
                    "native_runner.platform.system", return_value="Darwin"), patch(
                    "native_runner.platform.machine", return_value="arm64"), patch(
                    "native_runner.output", return_value='"IOPlatformUUID" = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"'):
                self.assertEqual(validate(policy, env), Path(env["GITHUB_WORKSPACE"]))
            self.assertEqual(physical.call_args.args[0]["runner_root"], "/fixture/native-runner")

    def test_environment_self_hash_cannot_replace_missing_owned_assignment(self):
        from pathlib import Path
        from native_runner import require_recoverable_job
        policy, env, event = self.contract()
        Path(env["ELITE_RECOVERABLE_ASSIGNMENT_PATH"]).unlink()
        with self.assertRaises(OSError):
            require_recoverable_job(policy, env, event, now=100)

    def test_ci_push_and_internal_pr_merge_require_exact_execution_and_source_approvals(self):
        from copy import deepcopy
        from native_runner import require_recoverable_job, policy_digest
        policy, env, event = self.contract()
        activation = policy["recoverable_activation"]
        env.update(GITHUB_JOB="prepare_thread", ELITE_RECOVERABLE_REQUEST_MODE="thread",
                   GITHUB_EVENT_NAME="push", GITHUB_REF="refs/heads/main",
                   GITHUB_WORKFLOW_REF=REPO["full_name"] + "/.github/workflows/ci.yml@refs/heads/main")
        for name in ("PLAN_DIGEST", "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
            env.pop(name, None)
        activation["workflow_ref"] = env["GITHUB_WORKFLOW_REF"]
        activation["runners"]["owned-one"]["jobs"] = ["prepare_thread"]
        event.update(ref="refs/heads/main", after=SHA, deleted=False, forced=False)
        env["ELITE_RECOVERABLE_POLICY_SHA256"] = policy_digest(policy)
        require_recoverable_job(policy, env, event, now=100, verify_assignment=False)
        for changes in ({"forced": True}, {"deleted": True}, {"after": "f" * 40}):
            with self.assertRaises(ValueError):
                require_recoverable_job(policy, env, {**event, **changes}, now=100, verify_assignment=False)
        activation["pr_head"] = "b" * 40
        env.update(GITHUB_EVENT_NAME="pull_request", GITHUB_REF="refs/pull/7/merge",
                   GITHUB_WORKFLOW_REF=REPO["full_name"] + "/.github/workflows/ci.yml@refs/pull/7/merge")
        activation["workflow_ref"] = env["GITHUB_WORKFLOW_REF"]
        env["ELITE_RECOVERABLE_POLICY_SHA256"] = policy_digest(policy)
        event.update(number=7, pull_request={"head": {"sha": "b" * 40, "repo": REPO},
                     "base": {"ref": "main", "repo": REPO}, "user": {"id": 22142777}, "merge_commit_sha": SHA})
        require_recoverable_job(policy, env, event, now=100, verify_assignment=False)
        for mutate in (lambda p: p["head"].update(sha="c" * 40),
                       lambda p: p["head"].update(repo={**REPO, "fork": True}),
                       lambda p: p["base"].update(ref="release/m01")):
            bad = deepcopy(event)
            mutate(bad["pull_request"])
            with self.assertRaises(ValueError):
                require_recoverable_job(policy, env, bad, now=100, verify_assignment=False)

    def internal_pr_contract(self):
        from native_runner import policy_digest
        policy, env, event = self.contract()
        env.update(GITHUB_JOB="prepare_thread", ELITE_RECOVERABLE_REQUEST_MODE="thread",
                   GITHUB_EVENT_NAME="pull_request", GITHUB_REF="refs/pull/7/merge",
                   GITHUB_WORKFLOW_REF=REPO["full_name"] + "/.github/workflows/ci.yml@refs/pull/7/merge")
        for key in ("PLAN_DIGEST", "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
            env.pop(key, None)
        activation = policy["recoverable_activation"]
        activation.update(pr_head="b" * 40, workflow_ref=env["GITHUB_WORKFLOW_REF"])
        activation["runners"]["owned-one"]["jobs"] = ["prepare_thread"]
        env["ELITE_RECOVERABLE_POLICY_SHA256"] = policy_digest(policy)
        event.update(number=7, pull_request={"head": {"sha": "b" * 40, "repo": copy.deepcopy(REPO)},
                     "base": {"ref": "main", "repo": copy.deepcopy(REPO)},
                     "user": {"id": 22142777}, "merge_commit_sha": None})
        return policy, env, event

    def test_pr_context_accepts_null_stale_or_absent_webhook_merge_metadata(self):
        from native_runner import require_recoverable_event, require_recoverable_job
        for webhook in (None, "c" * 40, SHA, "absent"):
            with self.subTest(webhook=webhook):
                policy, env, event = self.internal_pr_contract()
                if webhook == "absent":
                    event["pull_request"].pop("merge_commit_sha")
                else:
                    event["pull_request"]["merge_commit_sha"] = webhook
                require_recoverable_event(policy["recoverable_activation"], env, event)
                self.assertEqual(require_recoverable_job(policy, env, event, now=100, verify_assignment=False), policy["recoverable_activation"])

    def test_webhook_metadata_cannot_authorize_wrong_pr_execution_source_or_context(self):
        from native_runner import require_recoverable_job
        changes = [lambda e, v: e.update(GITHUB_SHA="c" * 40),
                   lambda e, v: v["pull_request"]["head"].update(sha="c" * 40),
                   lambda e, v: e.update(GITHUB_REF="refs/pull/8/merge"),
                   lambda e, v: e.update(GITHUB_WORKFLOW_REF="outside/workflow"),
                   lambda e, v: v.update(number=8),
                   lambda e, v: e.update(GITHUB_REPOSITORY="outside/elite"),
                   lambda e, v: v["repository"].update(full_name="outside/elite"),
                   lambda e, v: v["repository"].update(fork=True),
                   lambda e, v: e.update(GITHUB_ACTOR_ID="2"),
                   lambda e, v: v["sender"].update(id=2),
                   lambda e, v: v["pull_request"]["user"].update(id=2),
                   lambda e, v: v["pull_request"]["head"]["repo"].update(full_name="outside/elite"),
                   lambda e, v: v["pull_request"]["head"]["repo"].update(fork=True),
                   lambda e, v: v["pull_request"]["base"].update(ref="release/m01"),
                   lambda e, v: v["pull_request"]["base"]["repo"].update(full_name="outside/elite")]
        for webhook in (None, "c" * 40):
            for index, mutate in enumerate(changes):
                with self.subTest(webhook=webhook, mutation=index):
                    policy, env, event = self.internal_pr_contract()
                    event["pull_request"]["merge_commit_sha"] = webhook
                    mutate(env, event)
                    with self.assertRaises(ValueError):
                        require_recoverable_job(policy, env, event, now=100, verify_assignment=False)

    def test_pr_event_helper_itself_requires_approved_execution_and_workflow_ref(self):
        from native_runner import require_recoverable_event
        for change in ({"GITHUB_SHA": "c" * 40}, {"GITHUB_REF": "refs/pull/8/merge"},
                       {"GITHUB_WORKFLOW_REF": "outside/workflow"}):
            policy, env, event = self.internal_pr_contract()
            env.update(change)
            event["pull_request"]["merge_commit_sha"] = env["GITHUB_SHA"]
            with self.assertRaisesRegex(ValueError, "execution/source/ref"):
                require_recoverable_event(policy["recoverable_activation"], env, event)

    def test_ci_prejob_authorizer_pins_caller_and_called_workflow_before_owned_issuance(self):
        import base64
        import hashlib
        import json
        from pathlib import Path
        from types import SimpleNamespace
        from native_runner import authorize_recoverable, policy_digest
        policy, env, event = self.contract()
        source, called = b"pinned ci workflow", b"pinned recoverable workflow"
        a = policy["recoverable_activation"]
        a.update(workflow_sha256=hashlib.sha256(source).hexdigest(),
                 reusable_workflow_sha256=hashlib.sha256(called).hexdigest(),
                 workflow_ref=REPO["full_name"] + "/.github/workflows/ci.yml@refs/heads/main")
        a["runners"]["owned-one"]["jobs"] = ["prepare_thread"]
        env.update(GITHUB_JOB="prepare_thread", ELITE_RECOVERABLE_REQUEST_MODE="thread", GITHUB_EVENT_NAME="push",
                   GITHUB_REF="refs/heads/main", GITHUB_WORKFLOW_REF=a["workflow_ref"], GITHUB_TOKEN="fake-private-read-token")
        for name in ("PLAN_DIGEST", "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
            env.pop(name, None)
        event.update(ref="refs/heads/main", after=SHA, deleted=False, forced=False)
        cache = Path(a["assignment_root"]).with_name(Path(a["assignment_root"]).name + "-not-created-cache")
        policy["recoverable_shards"].update(cache=str(cache), workers={"one": "/fixture/private-worker"}, admission={})
        manifest = {name: a[name] for name in ("schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256",
                                               "reusable_workflow_sha256", "runners", "assignment_root")}
        manifest.update(ref=env["GITHUB_REF"], workflow_file="ci.yml")
        a["manifest_sha256"] = policy_digest(manifest)
        env.update(ACTIVATION=json.dumps(manifest), POLICY_DIGESTS=json.dumps({"owned-one": policy_digest(policy)}))
        bad_called = False
        def api(path):
            if "/contents/Tools/CI?" in path:
                entries = []
                for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"):
                    raw = (Path(__file__).resolve().parent / name).read_bytes()
                    sha = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw, usedforsecurity=False).hexdigest()
                    entries.append({"name": name, "type": "file", "sha": sha})
                return entries
            raw = (b"changed called workflow" if bad_called else called) if "recoverable-quality.yml" in path else source
            return {"encoding": "base64", "content": base64.b64encode(raw).decode()}
        class Remote:
            def __init__(self, authority, api):
                # Preparation does not consume an existing plan or artifact.
                pass
        guard = SimpleNamespace(PHYSICAL_EXECUTION_ENABLED=True, GitHubArtifacts=Remote)
        approved = authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
        path = Path(approved["ELITE_RECOVERABLE_ASSIGNMENT_PATH"])
        original = path.read_bytes()
        bad_called = True
        with self.assertRaises(ValueError):
            authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
        self.assertEqual(path.read_bytes(), original)

    def test_aggregate_owned_assignment_binds_both_independent_plan_digests(self):
        from pathlib import Path
        import json
        from native_runner import assignment_payload, assignment_digest, policy_digest, require_recoverable_job
        policy, env, event = self.contract()
        env.update(GITHUB_JOB="native_aggregate", OTHER_PLAN_DIGEST="a" * 64)
        for name in ("ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
            env.pop(name, None)
        policy["recoverable_activation"]["runners"]["owned-one"]["jobs"] = ["native_aggregate"]
        env["ELITE_RECOVERABLE_POLICY_SHA256"] = policy_digest(policy)
        payload = {**assignment_payload(policy, env), "expires_at": 190, "revoked": False}
        path = Path(policy["recoverable_activation"]["assignment_root"]) / (assignment_digest(env) + ".json")
        path.write_text(json.dumps(payload))
        path.chmod(0o400)
        env.update(ELITE_RECOVERABLE_ASSIGNMENT_PATH=str(path), ELITE_RECOVERABLE_ASSIGNMENT_SHA256=policy_digest(payload))
        require_recoverable_job(policy, env, event, now=100)
        for value in ("", "b" * 64):
            with self.assertRaises(ValueError):
                require_recoverable_job(policy, {**env, "OTHER_PLAN_DIGEST": value}, event, now=100)

    def recoverable_installation_fixture(self):
        import hashlib, json
        from pathlib import Path
        from unittest.mock import patch
        import prepare_native_runner as install
        from native_runner import policy_digest
        stack, home, archive, archive_hash = ImmutablePreparationTests.with_fixture(self)
        stack.enter_context(patch("prepare_native_runner.time.time", return_value=100))
        repo = home.parent / "repo"
        helpers = {}
        for name in ("recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"):
            path = repo / "Tools/CI" / name
            path.write_text("# fixture pinned helper " + name + "\n")
            helpers[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        workflow = repo / ".github/workflows"
        workflow.mkdir(parents=True)
        for name in ("ci.yml", "recoverable-quality.yml"):
            (workflow / name).write_text("# pinned workflow " + name + "\n")
        legacy = home.parent / "legacy-cache"
        legacy.mkdir(mode=0o700)
        (legacy / "executor.lock").touch(mode=0o600)
        activation = dict(schema=1, enabled=True, revoked=False, expires_at=10000, head=SHA,
                          workflow_ref="stephenlclarke/elite/.github/workflows/ci.yml@refs/heads/main",
                          workflow_sha256=hashlib.sha256((workflow / "ci.yml").read_bytes()).hexdigest(),
                          reusable_workflow_sha256=hashlib.sha256((workflow / "recoverable-quality.yml").read_bytes()).hexdigest(),
                          runners={"elite-mbp-native": {"workspace": str(home / "native-runner/_work/elite/elite"),
                                   "jobs": sorted(install.RECOVERABLE_ROLES)}},
                          assignment_root=str(home.parent / "assignments"), guard_files=helpers)
        manifest = {k: activation[k] for k in ("schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256",
                                               "reusable_workflow_sha256", "runners", "assignment_root")}
        manifest.update(ref="refs/heads/main", workflow_file="ci.yml")
        activation["manifest_sha256"] = policy_digest(manifest)
        policy = dict(approved_head=SHA, runner_root=str(home / "native-runner"), developer_dir=install.DEVELOPER,
                      swift="fixture Swift", sdk="fixture SDK", guard_sha256=hashlib.sha256((repo / "Tools/CI/native_runner.py").read_bytes()).hexdigest(),
                      runner_archive_sha256=archive_hash, recoverable_activation=activation,
                      recoverable_shards=dict(schema=1, host="AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", cache=str(home.parent / "cache"),
                       legacy_cache=str(legacy), workers={"one": str(home.parent / "worker")},
                       admission=dict(explicit=1, cpu_budget=1, ram_capacity=20, ram_reserve=2, peak_per_worker=6,
                                      disk_capacity=100, disk_reserve=10, disk_per_worker=20)))
        reviewed = home.parent / "reviewed-policy.json"
        reviewed.write_text(json.dumps(policy, indent=2) + "\n")
        reviewed.chmod(0o400)
        checksum = hashlib.sha256(reviewed.read_bytes()).hexdigest()
        return stack, home, archive, archive_hash, reviewed, checksum, policy

    def test_installer_accepts_only_exact_full_or_asan_role_profiles(self):
        import hashlib, itertools, json
        import prepare_native_runner as install
        from native_runner import policy_digest
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            base = {k: v for k, v in policy.items() if k not in ("recoverable_activation", "recoverable_shards")}
            full = sorted(install.RECOVERABLE_ROLES)
            asan = ["native_checks", "prepare_address", "address_shards"]
            self.assertEqual(install.ASAN_RECOVERABLE_ROLES, set(asan))
            candidates = [list(group) for count in range(8) for group in itertools.combinations(full, count)]
            candidates += [asan + ["native_checks"], full + ["native_checks"], asan + ["quality"],
                           full + ["quality"], ["quality"], list(reversed(asan)), list(reversed(full))]
            accepted = []
            for jobs in candidates:
                with self.subTest(jobs=jobs):
                    a = policy["recoverable_activation"]
                    a["runners"]["elite-mbp-native"]["jobs"] = jobs
                    manifest = {k: a[k] for k in ("schema", "enabled", "revoked", "expires_at", "head",
                                "workflow_sha256", "reusable_workflow_sha256", "runners", "assignment_root")}
                    manifest.update(ref="refs/heads/main", workflow_file="ci.yml")
                    a["manifest_sha256"] = policy_digest(manifest)
                    reviewed.chmod(0o600)
                    reviewed.write_text(json.dumps(policy))
                    reviewed.chmod(0o400)
                    checksum = hashlib.sha256(reviewed.read_bytes()).hexdigest()
                    if len(jobs) == len(set(jobs)) and set(jobs) in (set(full), set(asan)):
                        actual = install.reviewed_recoverable_policy(reviewed, checksum, base)
                        self.assertEqual(actual, policy)
                        accepted.append(set(jobs))
                    else:
                        with self.assertRaisesRegex(ValueError, "role reservation"):
                            install.reviewed_recoverable_policy(reviewed, checksum, base)
            self.assertEqual(len(accepted), 4)  # Both exact profiles, in both supplied orders.
            self.assertFalse((home / "native-runner").exists())

    def test_installer_preserves_asan_only_roles_and_keeps_manifest_gate(self):
        import hashlib, json
        import prepare_native_runner as install
        from native_runner import policy_digest
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            a = policy["recoverable_activation"]
            jobs = ["native_checks", "prepare_address", "address_shards"]
            a["runners"]["elite-mbp-native"]["jobs"] = jobs
            # Rehash the reviewed file but leave its old full-profile manifest digest: still refused.
            reviewed.chmod(0o600)
            reviewed.write_text(json.dumps(policy))
            reviewed.chmod(0o400)
            checksum = hashlib.sha256(reviewed.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, "manifest is inconsistent"):
                install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            self.assertFalse((home / "native-runner").exists())
            manifest = {k: a[k] for k in ("schema", "enabled", "revoked", "expires_at", "head",
                        "workflow_sha256", "reusable_workflow_sha256", "runners", "assignment_root")}
            manifest.update(ref="refs/heads/main", workflow_file="ci.yml")
            a["manifest_sha256"] = policy_digest(manifest)
            reviewed.chmod(0o600)
            reviewed.write_text(json.dumps(policy))
            reviewed.chmod(0o400)
            checksum = hashlib.sha256(reviewed.read_bytes()).hexdigest()
            actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            installed = json.loads(actual.read_text())
            self.assertEqual(installed, policy)
            self.assertEqual(installed["recoverable_activation"]["runners"]["elite-mbp-native"]["jobs"], jobs)

    def test_installer_explicit_mode_installs_five_pins_and_preserves_legacy_and_immutable_mismatches(self):
        import hashlib
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            legacy = install.prepare(SHA, archive, archive_hash)
            legacy_bytes = legacy.read_bytes()
            with install.recoverable_control(), install.quiescent_legacy(policy):
                actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            self.assertNotEqual(actual, legacy)
            self.assertEqual(actual.parent.name, "recoverable-" + checksum)
            self.assertEqual(legacy.read_bytes(), legacy_bytes)
            self.assertEqual(actual.parent.parent, legacy.parent)
            for name, expected in {"native_runner.py": policy["guard_sha256"], **policy["recoverable_activation"]["guard_files"]}.items():
                self.assertEqual(hashlib.sha256((actual.parent / name).read_bytes()).hexdigest(), expected)
            before = actual.read_bytes()
            self.assertEqual(install.prepare(SHA, archive, archive_hash, reviewed, checksum).read_bytes(), before)
            helper = actual.parent / "recoverable_shards.py"
            helper.chmod(0o600)
            helper.write_text("# altered installed code")
            helper.chmod(0o400)
            with self.assertRaises(ValueError):
                install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            self.assertEqual(actual.read_bytes(), before)
            self.assertEqual(legacy.read_bytes(), legacy_bytes)

    def test_installer_refuses_unreviewed_pins_expiry_role_paths_and_nonquiescent_lease(self):
        import fcntl, hashlib, json
        from copy import deepcopy
        import prepare_native_runner as install
        faults = (lambda p: p.update(guard_sha256="b" * 64),
                  lambda p: p["recoverable_activation"].update(reusable_workflow_sha256="b" * 64),
                  lambda p: p["recoverable_activation"].update(expires_at=99),
                  lambda p: p["recoverable_activation"]["guard_files"].pop("crash_artifacts.py"),
                  lambda p: p["recoverable_activation"]["runners"]["elite-mbp-native"].update(jobs=["quality"]),
                  lambda p: p["recoverable_shards"].update(workers={"two": "/unapproved"}),
                  lambda p: p["recoverable_shards"].update(cache=p["recoverable_shards"]["legacy_cache"]))
        for mutate in faults:
            stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
            with stack:
                altered = deepcopy(policy)
                mutate(altered)
                reviewed.chmod(0o600)
                reviewed.write_text(json.dumps(altered))
                reviewed.chmod(0o400)
                checksum = hashlib.sha256(reviewed.read_bytes()).hexdigest()
                with self.assertRaises(ValueError):
                    install.prepare(SHA, archive, archive_hash, reviewed, checksum)
                self.assertFalse((home / "native-runner").exists())
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack, open(policy["recoverable_shards"]["legacy_cache"] + "/executor.lock", "a") as active:
            fcntl.flock(active, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError), install.quiescent_legacy(policy):
                self.fail("Cannot cross the current native lease")

    def test_installer_serial_session_reserves_before_tokens_and_stops_at_durable_job_budget(self):
        import json, os
        from unittest.mock import patch
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            registered = []
            def register(run, runner_name, **bounds):
                self.assertFalse(run)
                ticket = install.owned_json(home / "recoverable-sessions/ticket.json")
                self.assertEqual(ticket["ordinal"], len(registered) + 1)
                (home / "native-runner/.runner").write_text(json.dumps(dict(agentName=runner_name,
                    gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work")))
                registered.append(runner_name)
            class Listener:
                def wait(inner, timeout):
                    self.assertLessEqual(timeout, 30)
                    (home / "native-runner/.runner").unlink()
                    return 0
            def spawn(command, **kwargs):
                self.assertEqual(command[-1], "--once")
                self.assertNotIn("GH_TOKEN", kwargs["env"])
                self.assertNotIn("GITHUB_TOKEN", kwargs["env"])
                for fd in kwargs["pass_fds"]:
                    os.fstat(fd)
                return Listener()
            with install.recoverable_control() as lock, patch.object(install, "session_run_active", return_value=True), patch.object(
                    install, "register_and_run", side_effect=register) as token, patch.object(install.subprocess, "Popen", side_effect=spawn):
                result = install.renew_recoverable(actual, "123", "1", 2, 9000, True, True, lock)
                self.assertEqual(result, {"used": 2, "reason": "registration budget exhausted"})
                install.renew_recoverable(actual, "123", "1", 2, 9000, True, True, lock)
                self.assertEqual(token.call_count, 2)
                with self.assertRaises(ValueError):
                    install.renew_recoverable(actual, "123", "1", 3, 9000, True, True, lock)
                import subprocess
                with patch.object(install, "register_and_run", side_effect=subprocess.TimeoutExpired("fake-private-command", 1)), patch.object(
                        install.subprocess, "Popen") as never_launched:
                    with self.assertRaisesRegex(ValueError, "Registration outcome is unresolved") as error:
                        install.renew_recoverable(actual, "124", "1", 2, 9000, True, True, lock)
                    self.assertNotIn("fake-private", str(error.exception))
                    never_launched.assert_not_called()

            self.assertEqual(len(registered), 2)

    def test_installer_register_only_then_explicit_run_uses_same_slot_and_hook_rejects_other_run_or_attempt(self):
        import json, subprocess, os
        from types import SimpleNamespace
        from unittest.mock import patch
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            def register(run, runner_name, **bounds):
                (home / "native-runner/.runner").write_text(json.dumps(dict(agentName=runner_name,
                    gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work")))
            with install.recoverable_control() as lock, patch.object(install, "session_run_active", return_value=True), patch.object(
                    install, "register_and_run", side_effect=register) as token:
                self.assertEqual(install.renew_recoverable(actual, "123", "1", 2, 9000, True, False, lock)["reason"], "registered only")
                args = SimpleNamespace(run=True, session_run_id="123", session_run_attempt="1", max_jobs=2, session_expires_at=9000)
                self.assertTrue(install.registered_session_slot(policy, args))
                before = actual.read_bytes()
                self.assertEqual(install.prepare(SHA, archive, archive_hash, reviewed, checksum, registered=True).read_bytes(), before)
                # Exercise the shared session check with only fake owned session files.
                import native_runner, shutil
                from pathlib import Path
                hook = actual.parent / "job-started.sh"
                self.assertTrue(hook.read_text().endswith(" --admit\n"))
                account = home.parent / "account"
                root = account / "Library/EliteNativeCI/recoverable-sessions"
                shutil.copytree(home / "recoverable-sessions", root)
                ticket_path = root / "ticket.json"
                ticket = json.loads(ticket_path.read_text())
                ticket['binding'] = str(root / Path(ticket['binding']).name)
                ticket_path.chmod(0o600)
                ticket_path.write_text(json.dumps(ticket))
                ticket_path.chmod(0o400)
                with patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(account))):
                    for run_id, attempt, accepted in (("123", "1", True), ("124", "1", False), ("123", "2", False)):
                        if accepted:
                            native_runner.require_recoverable_session(policy, dict(GITHUB_RUN_ID=run_id, GITHUB_RUN_ATTEMPT=attempt), now=100)
                        else:
                            with self.assertRaises(ValueError):
                                native_runner.require_recoverable_session(policy, dict(GITHUB_RUN_ID=run_id, GITHUB_RUN_ATTEMPT=attempt), now=100)
            class Listener:
                def wait(inner, timeout):
                    (home / "native-runner/.runner").unlink()
                    return 0
            import sys
            command = ["prepare_native_runner.py", "--approved-head", SHA, "--runner-archive", str(archive),
                       "--archive-sha256", archive_hash, "--recoverable-policy", str(reviewed),
                       "--recoverable-policy-sha256", checksum, "--session-run-id", "123", "--session-run-attempt", "1",
                       "--max-jobs", "2", "--session-expires-at", "9000", "--run"]
            with patch.object(sys, "argv", command), patch.object(install, "session_run_active", return_value=True), patch.object(
                    install, "register_and_run", side_effect=AssertionError("Registered-only resume must not request another token")), patch.object(
                    install.subprocess, "Popen", return_value=Listener()):
                install.main()
            state = next((home / "recoverable-sessions").glob("*.state"))
            self.assertEqual(json.loads(state.read_text()), {"used": 1, "phase": "idle"})
            self.assertEqual(token.call_count, 1)

    def test_installer_expiry_preserves_uncertain_listener_without_signal_or_replacement(self):
        import json, subprocess
        from unittest.mock import patch, Mock
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            def register(run, runner_name, **bounds):
                (home / "native-runner/.runner").write_text(json.dumps(dict(agentName=runner_name,
                    gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work")))
            listener = Mock()
            def wait(timeout):
                install.time.time.return_value = 1000
                raise subprocess.TimeoutExpired("fixture-listener", timeout)
            listener.wait.side_effect = wait
            with install.recoverable_control() as lock, patch.object(install, "session_run_active", return_value=True), patch.object(
                    install, "register_and_run", side_effect=register) as token, patch.object(install.subprocess, "Popen", return_value=listener):
                with self.assertRaisesRegex(ValueError, "expired with unresolved"):
                    install.renew_recoverable(actual, "123", "1", 2, 101, True, True, lock)
                listener.send_signal.assert_not_called()
                self.assertEqual(token.call_count, 1)
                state = next((home / "recoverable-sessions").glob("*.state"))
                self.assertEqual(json.loads(state.read_text()), {"used": 1, "phase": "running"})

    def test_installer_completed_run_stops_only_its_listener_without_another_registration(self):
        import json, subprocess, signal
        from unittest.mock import patch, Mock
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            actual = install.prepare(SHA, archive, archive_hash, reviewed, checksum)
            def register(run, runner_name, **bounds):
                (home / "native-runner/.runner").write_text(json.dumps(dict(agentName=runner_name,
                    gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work")))
            listener = Mock()
            listener.wait.side_effect = [subprocess.TimeoutExpired("fixture-listener", 30), 0]
            with install.recoverable_control() as lock, patch.object(install, "session_run_active", side_effect=[True, False]), patch.object(
                    install, "register_and_run", side_effect=register) as registration, patch.object(install.subprocess, "Popen", return_value=listener):
                result = install.renew_recoverable(actual, "123", "1", 2, 9000, True, True, lock)
                self.assertEqual(result, {"used": 1, "reason": "workflow completed"})
                listener.send_signal.assert_called_once_with(signal.SIGINT)
                self.assertEqual(registration.call_count, 1)

    def test_installer_run_metadata_is_exact_and_never_leaks_private_response(self):
        import json
        from copy import deepcopy
        from types import SimpleNamespace
        from unittest.mock import patch
        import prepare_native_runner as install
        stack, home, archive, archive_hash, reviewed, checksum, policy = self.recoverable_installation_fixture()
        with stack:
            binding = {"run_id": "123", "run_attempt": "1", "expires_at": 9000}
            run = dict(id=123, run_attempt=1, head_sha=SHA, repository={"full_name": "stephenlclarke/elite"},
                       actor={"id": 22142777}, triggering_actor={"id": 22142777}, status="in_progress",
                       event="push", path=".github/workflows/ci.yml", head_branch="main")
            for changes in ({}, {"status": "completed"}, {"head_sha": "b" * 40}, {"run_attempt": 2}, {"path": ".github/workflows/other.yml"}):
                data = {**deepcopy(run), **changes}
                with patch.object(install.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=json.dumps(data), stderr="private")):
                    if changes and changes.get("status") != "completed":
                        with self.assertRaises(ValueError) as error:
                            install.session_run_active(policy, binding)
                        self.assertNotIn("private", str(error.exception))
                    else:
                        self.assertEqual(install.session_run_active(policy, binding), changes.get("status") != "completed")


class ArtifactProvenanceDiagnosticTests(unittest.TestCase):
    def test_loaded_pinned_helper_failure_emits_only_fixed_codes_and_integer(self):
        import ast, json
        from pathlib import Path
        from types import SimpleNamespace
        import native_runner as native
        import recoverable_shards as shards
        secret = "FAKE_PRIVATE_RUN_PAYLOAD_TOKEN"
        authority = SimpleNamespace(environment=dict(GITHUB_REF="refs/heads/approved", GITHUB_EVENT_NAME="workflow_dispatch"),
                                    policy=dict(approved_head=SHA))
        class UnprintableValueError(ValueError):
            def __str__(self):
                raise AssertionError("Never format exception text")
        class PrivateRun(dict):
            def __getitem__(self, key):
                raise UnprintableValueError(secret)
        try:
            shards.require_artifact_run_provenance(authority, PrivateRun(), "123")
        except ValueError as error:
            record = native.authorization_failure(error)
        function = shards.require_artifact_run_provenance
        source = ast.parse(Path(shards.__file__).read_text())
        check = next(node for node in source.body if isinstance(node, ast.FunctionDef) and node.name == function.__name__)
        first_guard = next(node for node in check.body if isinstance(node, ast.If))
        self.assertEqual(record, dict(stage="artifact", predicate="run-provenance", category="ValueError", owned_line=first_guard.lineno))
        self.assertNotIn(secret, json.dumps(record))
        self.assertNotIn(shards.__file__, json.dumps(record))
        self.assertEqual(set(record), {"stage", "predicate", "category", "owned_line"})

    def test_same_name_or_spoofed_filename_cannot_replace_the_loaded_helper_code(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        import native_runner as native
        import recoverable_shards as shards
        name = "require_artifact_run_provenance"
        source = "def " + name + "():\n    raise ValueError('FAKE_PRIVATE_ARGUMENT')\n"
        for filename in ("/untrusted/recoverable_shards.py", shards.__file__):
            with self.subTest(filename=filename):
                scope = {}
                exec(compile(source, filename, "exec"), scope)
                try:
                    scope[name]()
                except ValueError as error:
                    record = native.authorization_failure(error)
                self.assertEqual(record, dict(stage="unknown", predicate="unknown", category="ValueError", owned_line=None))
        # Matching the loaded function identity alone cannot admit a foreign path.
        foreign = {}
        exec(compile(source, "/untrusted/recoverable_shards.py", "exec"), foreign)
        with patch.dict("sys.modules", {"recoverable_shards": SimpleNamespace(**foreign)}):
            try:
                foreign[name]()
            except ValueError as error:
                record = native.authorization_failure(error)
        self.assertEqual(record["predicate"], "unknown")
        self.assertIsNone(record["owned_line"])

    def test_unloaded_helper_is_not_imported_to_format_an_unrelated_error(self):
        from unittest.mock import patch
        import native_runner as native
        import sys
        loaded = dict(sys.modules)
        loaded.pop("recoverable_shards", None)
        with patch.dict(sys.modules, loaded, clear=True), patch("builtins.__import__", wraps=__import__) as imports:
            record = native.authorization_failure(ValueError("FAKE_PRIVATE_ARGUMENT"))
        self.assertEqual(record, dict(stage="unknown", predicate="unknown", category="ValueError", owned_line=None))
        self.assertFalse(any(call.args[0] == "recoverable_shards" for call in imports.call_args_list))


class SplitAuthorizationTests(unittest.TestCase):
    contract = RecoverableAuthorizationTests.contract

    def request_fixture(self, role):
        """Use only local fake API responses and immutable temporary assignment files."""
        import base64, hashlib, json
        from pathlib import Path
        from types import SimpleNamespace
        import native_runner as native
        policy, env, event = self.contract()
        Path(env.pop("ELITE_RECOVERABLE_ASSIGNMENT_PATH")).unlink()
        for name in ("ELITE_RECOVERABLE_ASSIGNMENT_SHA256", "ELITE_RECOVERABLE_CODE_ENABLED",
                     "ELITE_RECOVERABLE_PLAN_SHA256", "PLAN_DIGEST", "ELITE_RECOVERABLE_REQUEST_MODE",
                     "ELITE_RECOVERABLE_REQUEST_SHARD", "ELITE_RECOVERABLE_REQUEST_WORKER"):
            env.pop(name, None)
        source = b"fake reviewed workflow bytes"
        activation = policy["recoverable_activation"]
        activation["runners"]["owned-one"]["jobs"] = [role]
        activation["workflow_sha256"] = hashlib.sha256(source).hexdigest()
        env.update(GITHUB_JOB=role, GITHUB_TOKEN="fake-workflow-read-token", REQUESTED_NATIVE="true",
                   RUNNER_ENVIRONMENT="self-hosted")
        if role not in native.PREPARE_JOBS:
            env.update(PLAN_ID="7", PLAN_ARCHIVE="b" * 64, PLAN_DIGEST="e" * 64)
        if role in ("prepare_thread", "prepare_address"):
            env["ELITE_RECOVERABLE_REQUEST_MODE"] = role.removeprefix("prepare_")
        if role in native.SHARD_JOBS:
            env.update(ELITE_RECOVERABLE_REQUEST_MODE="address" if role == "address_shards" else "thread",
                       ELITE_RECOVERABLE_REQUEST_SHARD="f" * 64, ELITE_RECOVERABLE_REQUEST_WORKER="one")
        if role == "native_phase":
            env["ELITE_RECOVERABLE_REQUEST_PHASE"] = "normal"
        if role == "native_aggregate":
            env.update(OTHER_PLAN_ID="8", OTHER_PLAN_ARCHIVE="c" * 64, OTHER_PLAN_DIGEST="d" * 64)
        root = Path(activation["assignment_root"])
        policy["recoverable_shards"].update(cache=str(root.with_name(root.name + "-cache")), workers={"one": "/fixture/private-worker"})
        manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head",
                                                       "workflow_sha256", "runners", "assignment_root")}
        manifest.update(ref=env["GITHUB_REF"], workflow_file="recoverable-quality.yml")
        activation["manifest_sha256"] = native.policy_digest(manifest)
        env.update(ACTIVATION=json.dumps(manifest), POLICY_DIGESTS=json.dumps({"owned-one": native.policy_digest(policy)}),
                   ELITE_RECOVERABLE_POLICY_SHA256=native.policy_digest(policy),
                   ELITE_RECOVERABLE_WORKFLOW_SHA256=activation["workflow_sha256"],
                   ELITE_RECOVERABLE_ACTIVATION_SHA256=activation["manifest_sha256"])
        requests = []

        def api(path):
            requests.append(path)
            if "/contents/Tools/CI?" in path:
                result = []
                for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                             "quality_phase_checkpoints.py", "crash_artifacts.py"):
                    raw = (Path(native.__file__).parent / name).read_bytes()
                    blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw, usedforsecurity=False).hexdigest()
                    result.append(dict(name=name, type="file", sha=blob))
                return result
            if "/contents/" in path:
                return dict(encoding="base64", content=base64.b64encode(source).decode())
            return dict(name="native-plan-fake")

        class Remote:
            def __init__(self, authority, api):
                pass  # No live API or artifact access in this fake.

            def fetch(self, artifact, digest):
                return root

        class Workflow:
            def __init__(self, authority, remote):
                pass  # The fixture supplies the already authenticated plan contract.

            def plans(self, bundle, digest):
                return [dict(runtime=dict(mode="address" if digest == "d" * 64 else "thread"))], {
                    "host": policy["recoverable_shards"]["host"], "phases": ["normal", "leaks"],
                    "expected": [dict(mode=mode, shard="f" * 64, worker="one") for mode in ("thread", "address")]}

        guard = SimpleNamespace(PHYSICAL_EXECUTION_ENABLED=True, GitHubArtifacts=Remote, NativeWorkflow=Workflow)
        return policy, env, event, api, guard, requests

    def test_admission_accepts_identity_without_any_custom_job_env_and_never_issues_assignment(self):
        from pathlib import Path
        from unittest.mock import patch
        import native_runner as native
        for role in sorted(native.RECOVERABLE_JOBS):
            with self.subTest(role=role):
                policy, env, event, api, guard, requests = self.request_fixture(role)
                hook_env = {name: value for name, value in env.items() if name.startswith(("GITHUB_", "RUNNER_", "ELITE_NATIVE_"))}
                hook_env.pop("GITHUB_TOKEN")
                with patch.object(native, "require_recoverable_session") as session, patch.object(
                        native, "load_recoverable_guard", return_value=guard), patch.object(
                        native, "require_recoverable_host", return_value=Path(env["GITHUB_WORKSPACE"])), patch.object(
                        native, "authorize_recoverable", side_effect=AssertionError("Admission cannot authorize")):
                    native.admit_recoverable(policy, hook_env, event, now=100)
                session.assert_called_once_with(policy, hook_env, 100)
                self.assertEqual(requests, [])
                self.assertEqual(list(Path(policy["recoverable_activation"]["assignment_root"]).glob("*.json")), [])
                self.assertNotIn("ELITE_RECOVERABLE_CODE_ENABLED", hook_env)
                self.assertFalse(any("ASSIGNMENT" in name for name in hook_env))

    def test_full_authorizer_requires_actual_role_request_for_every_role(self):
        from pathlib import Path
        import native_runner as native
        for role in sorted(native.RECOVERABLE_JOBS):
            with self.subTest(role=role):
                policy, env, event, api, guard, requests = self.request_fixture(role)
                issued = native.authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
                native.require_recoverable_job(policy, issued, event, now=100)
                assignment = Path(issued["ELITE_RECOVERABLE_ASSIGNMENT_PATH"])
                self.assertNotIn(env["GITHUB_TOKEN"], assignment.read_text())
                for field, bad in (("GITHUB_RUN_ID", "124"), ("GITHUB_RUN_ATTEMPT", "2"),
                                   ("ELITE_RECOVERABLE_REQUEST_MODE", "wrong"),
                                   ("ELITE_RECOVERABLE_REQUEST_SHARD", "wrong"),
                                   ("ELITE_RECOVERABLE_REQUEST_WORKER", "wrong"),
                                   ("ELITE_RECOVERABLE_REQUEST_PHASE", "wrong")):
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        native.require_recoverable_job(policy, {**issued, field: bad}, event, now=100)
                assignment.unlink()
                for field in ("ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
                              "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE"):
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        native.authorize_recoverable(policy, {**env, field: "wrong"}, event, api=api, guard=guard, now=100)
                    self.assertEqual(list(assignment.parent.glob("*.json")), [])
                for field in ("ACTIVATION", "POLICY_DIGESTS", "GITHUB_TOKEN"):
                    broken = dict(env)
                    broken.pop(field)
                    with self.subTest(missing=field), self.assertRaises((ValueError, KeyError)):
                        native.authorize_recoverable(policy, broken, event, api=api, guard=guard, now=100)
                    self.assertEqual(list(assignment.parent.glob("*.json")), [])

    def test_session_ticket_rejects_replay_budget_expiry_and_mutated_owned_evidence(self):
        import hashlib, json
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from types import SimpleNamespace
        from unittest.mock import patch
        import native_runner as native
        policy = dict(approved_head=SHA, recoverable_activation=dict(expires_at=200))
        env = dict(GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1")
        with TemporaryDirectory() as temporary:
            home = Path(temporary).resolve()
            root = home / "Library/EliteNativeCI/recoverable-sessions"
            root.mkdir(parents=True, mode=0o700)
            binding = dict(schema=1, policy_sha256=native.policy_digest(policy), head=SHA, run_id="123",
                           run_attempt="1", max_jobs=2, expires_at=190)
            path = root / "session.json"
            ticket_path = root / "ticket.json"

            def publish(changes=None, ticket_changes=None):
                value = {**binding, **(changes or {})}
                if path.exists():
                    path.chmod(0o600)
                path.write_text(json.dumps(value))
                path.chmod(0o400)
                ticket = dict(binding=str(path), binding_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                              ordinal=1, policy_sha256=native.policy_digest(policy))
                ticket.update(ticket_changes or {})
                if ticket_path.exists():
                    ticket_path.chmod(0o600)
                ticket_path.write_text(json.dumps(ticket))
                ticket_path.chmod(0o400)

            with patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(home))):
                publish()
                native.require_recoverable_session(policy, env, now=100)
                for name in env:
                    with self.subTest(replay=name), self.assertRaises(ValueError):
                        native.require_recoverable_session(policy, {**env, name: "2"}, now=100)
                changes = (dict(schema=True), dict(policy_sha256="c" * 64), dict(head="c" * 40),
                           dict(max_jobs=0), dict(max_jobs=257), dict(max_jobs=True), dict(expires_at=99),
                           dict(expires_at=201), dict(expires_at=float("inf")))
                for change in changes:
                    publish(change)
                    with self.subTest(binding=change), self.assertRaises(ValueError):
                        native.require_recoverable_session(policy, env, now=100)
                for change in (dict(ordinal=0), dict(ordinal=3), dict(ordinal=True),
                               dict(binding=str(home / "outside.json")), dict(binding_sha256="0" * 64),
                               dict(policy_sha256="c" * 64), dict(binding=[])):
                    publish(ticket_changes=change)
                    with self.subTest(ticket=change), self.assertRaises(ValueError):
                        native.require_recoverable_session(policy, env, now=100)
                publish()
                path.chmod(0o600)
                with self.assertRaises(ValueError):
                    native.require_recoverable_session(policy, env, now=100)
                publish()
                saved = root / "saved.json"
                path.rename(saved)
                path.symlink_to(saved)
                with self.assertRaises(ValueError):
                    native.require_recoverable_session(policy, env, now=100)

    def test_full_authorizer_keeps_frozen_plan_membership_phase_and_both_aggregate_inputs(self):
        from pathlib import Path
        import native_runner as native
        cases = (("thread_shards", "ELITE_RECOVERABLE_REQUEST_WORKER", "two"),
                 ("address_shards", "ELITE_RECOVERABLE_REQUEST_SHARD", "0" * 64),
                 ("native_phase", "PLAN_ID", "missing"),
                 ("native_aggregate", "OTHER_PLAN_ID", "missing"),
                 ("native_aggregate", "OTHER_PLAN_DIGEST", "invalid"),
                 ("native_aggregate", "OTHER_PLAN_DIGEST", "e" * 64))
        for role, field, value in cases:
            with self.subTest(role=role, field=field):
                policy, env, event, api, guard, requests = self.request_fixture(role)
                with self.assertRaises(ValueError):
                    native.authorize_recoverable(policy, {**env, field: value}, event, api=api, guard=guard, now=100)
                self.assertEqual(list(Path(policy["recoverable_activation"]["assignment_root"]).glob("*.json")), [])
        policy, env, event, api, guard, requests = self.request_fixture("native_phase")
        env["ELITE_RECOVERABLE_REQUEST_PHASE"] = "leaks"
        issued = native.authorize_recoverable(policy, env, event, api=api, guard=guard, now=100)
        native.require_recoverable_job(policy, issued, event, now=100)

    def step_fixture(self):
        """Create a fake account and pinned package; no real runner paths are accessed."""
        import hashlib, json
        from pathlib import Path
        from tempfile import TemporaryDirectory
        import native_runner as native
        policy, env, event, api, guard, requests = self.request_fixture("prepare_address")
        temporary = TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        home = Path(temporary.name).resolve()
        raw = Path(native.__file__).read_bytes()
        policy.update(guard_sha256=hashlib.sha256(raw).hexdigest(), swift="fake Swift", sdk="fake SDK")
        digest = native.policy_digest(policy)
        # The raw reviewed input can use different whitespace from the installed policy.
        reviewed_input = (json.dumps(policy, indent=4) + "\n").encode()
        generation = hashlib.sha256(reviewed_input).hexdigest()
        self.assertNotEqual(generation, digest)
        package = home / "Library/EliteNativeAuthorization" / SHA / ("recoverable-" + generation)
        package.mkdir(parents=True, mode=0o700)
        guard_path = package / "native_runner.py"
        guard_path.write_bytes(raw)
        guard_path.chmod(0o500)
        policy_path = package / "policy.json"
        policy_path.write_text(json.dumps(policy))
        policy_path.chmod(0o400)
        event_path = home / "event.json"
        event_path.write_text(json.dumps(event))
        env.update(ELITE_NATIVE_POLICY=str(policy_path), ELITE_RECOVERABLE_POLICY_SHA256=digest,
                   POLICY_DIGESTS=json.dumps({"owned-one": digest}), GITHUB_EVENT_PATH=str(event_path),
                   GITHUB_ENV=str(home / "hook-env"))
        root = home / "Library/EliteNativeCI/recoverable-sessions"
        root.mkdir(parents=True, mode=0o700)
        binding_path = root / "session.json"
        binding = dict(schema=1, policy_sha256=digest, head=SHA, run_id="123", run_attempt="1", max_jobs=1, expires_at=190)
        binding_path.write_text(json.dumps(binding))
        binding_path.chmod(0o400)
        (root / "ticket.json").write_text(json.dumps(dict(binding=str(binding_path),
            binding_sha256=hashlib.sha256(binding_path.read_bytes()).hexdigest(), ordinal=1, policy_sha256=digest)))
        (root / "ticket.json").chmod(0o400)
        return home, policy_path, policy, env, event, api, guard, requests

    def workflow_script(self, marker):
        import textwrap
        from pathlib import Path
        source = (Path(__file__).resolve().parents[2] / ".github/workflows/recoverable-quality.yml").read_text()
        return textwrap.dedent(source.split(marker, 1)[1].split("<<'PY'\n", 1)[1].split("\n          PY", 1)[0])

    def test_real_stage_entrypoints_obey_next_step_env_and_binding_before_checkout(self):
        import contextlib, io, os
        from pathlib import Path
        from types import SimpleNamespace
        from unittest.mock import patch
        import native_runner as native
        home, policy_path, policy, env, event, api, guard, requests = self.step_fixture()
        hook_env = {key: value for key, value in env.items()
                    if key.startswith(("GITHUB_", "RUNNER_", "ELITE_NATIVE_")) and key != "GITHUB_TOKEN"}
        hook_env.update(ELITE_RECOVERABLE_CODE_ENABLED="true", ELITE_RECOVERABLE_ASSIGNMENT_PATH="forged")
        real_authorize = native.authorize_recoverable

        def authorize(p, e, v):
            return real_authorize(p, e, v, api=api, guard=guard, now=100)

        def run_main(values, flag):
            with patch.dict(os.environ, values, clear=True), patch("sys.argv", ["native_runner.py", "--policy", str(policy_path), flag]):
                native.main()

        with patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(home))), patch(
                "time.time", return_value=100), patch.object(native, "load_recoverable_guard", return_value=guard), patch.object(
                native, "require_recoverable_host", return_value=Path(env["GITHUB_WORKSPACE"])), patch.object(
                native, "authorize_recoverable", side_effect=authorize) as full, contextlib.redirect_stdout(io.StringIO()):
            run_main(hook_env, "--admit")
            full.assert_not_called()
            exported = dict(line.split("=", 1) for line in Path(env["GITHUB_ENV"]).read_text().splitlines())
            self.assertFalse(any("ASSIGNMENT" in name or "CODE_ENABLED" in name for name in exported))
            self.assertEqual(list(Path(policy["recoverable_activation"]["assignment_root"]).glob("*.json")), [])
            step_env = {**env, **exported, "GITHUB_ENV": str(home / "authorization-env")}

            def child(argv, cwd, check):
                self.assertEqual(argv, ["/usr/bin/python3", "-E", "-s", "-B", str(policy_path.parent / "native_runner.py"),
                                        "--policy", str(policy_path), "--authorize"])
                self.assertEqual(cwd, policy_path.parent)
                self.assertTrue(check)
                run_main(step_env, "--authorize")

            with patch.dict(os.environ, step_env, clear=True), patch("subprocess.run", side_effect=child):
                exec(compile(self.workflow_script("Authorize actual job request"), "fake-owned-dispatch", "exec"), {})
                # Child GITHUB_ENV writes do not alter the current parent process.
                self.assertNotIn("ELITE_RECOVERABLE_CODE_ENABLED", os.environ)
                with self.assertRaises(KeyError):
                    exec(compile(self.workflow_script("Require host hook and exact instance"), "fake-binding", "exec"), {})
            next_env = dict(line.split("=", 1) for line in Path(step_env["GITHUB_ENV"]).read_text().splitlines())
            with patch.dict(os.environ, {**step_env, **next_env}, clear=True):
                exec(compile(self.workflow_script("Require host hook and exact instance"), "fake-binding", "exec"), {})
            self.assertEqual(full.call_count, 1)
            self.assertTrue(requests)

    def test_step_dispatch_refuses_unowned_paths_or_changed_pins_before_executing_code(self):
        import os
        from types import SimpleNamespace
        from unittest.mock import patch
        for change in ("supplied-path", "digest", "head", "workflow", "activation", "guard-bytes", "guard-mode", "symlink"):
            with self.subTest(change=change):
                home, policy_path, policy, env, event, api, guard, requests = self.step_fixture()
                guard_path = policy_path.parent / "native_runner.py"
                if change == "supplied-path":
                    env["ELITE_NATIVE_POLICY"] = str(home / "untrusted/policy.json")
                elif change in ("digest", "head", "workflow", "activation"):
                    key = {"digest": "ELITE_RECOVERABLE_POLICY_SHA256", "head": "GITHUB_SHA",
                           "workflow": "ELITE_RECOVERABLE_WORKFLOW_SHA256", "activation": "ELITE_RECOVERABLE_ACTIVATION_SHA256"}[change]
                    env[key] = "0" * (40 if change == "head" else 64)
                elif change == "guard-bytes":
                    guard_path.chmod(0o700)
                    guard_path.write_text("raise RuntimeError('never execute')")
                    guard_path.chmod(0o500)
                elif change == "guard-mode":
                    guard_path.chmod(0o700)
                else:
                    saved = home / "saved.py"
                    guard_path.rename(saved)
                    guard_path.symlink_to(saved)
                with patch.dict(os.environ, env, clear=True), patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(home))), patch(
                        "subprocess.run") as never, self.assertRaises((AssertionError, OSError)):
                    exec(compile(self.workflow_script("Authorize actual job request"), "fake-owned-dispatch", "exec"), {})
                never.assert_not_called()

    def test_hook_or_full_authorization_failure_exports_no_assignment_and_stops_before_checkout(self):
        import contextlib, io, os
        from pathlib import Path
        from types import SimpleNamespace
        from unittest.mock import Mock, patch
        import native_runner as native
        for failure in ("hook-identity", "session-attempt", "mode", "activation", "token", "source"):
            with self.subTest(failure=failure):
                home, policy_path, policy, env, event, api, guard, requests = self.step_fixture()
                real_authorize = native.authorize_recoverable
                if failure == "hook-identity":
                    env["GITHUB_ACTOR_ID"] = "2"
                elif failure == "session-attempt":
                    env["GITHUB_RUN_ATTEMPT"] = "2"
                elif failure == "mode":
                    env["ELITE_RECOVERABLE_REQUEST_MODE"] = "thread"
                elif failure == "activation":
                    env["ACTIVATION"] = "{}"
                elif failure == "token":
                    env.pop("GITHUB_TOKEN")
                else:
                    def api(path):
                        return dict(encoding="base64", content="YmFk")
                checkout = Mock()
                with patch.dict(os.environ, env, clear=True), patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(home))), patch(
                        "time.time", return_value=100), patch("sys.argv", ["native_runner.py", "--policy", str(policy_path), "--authorize"]), patch.object(
                        native, "load_recoverable_guard", return_value=guard), patch.object(native, "require_recoverable_host", return_value=Path(env["GITHUB_WORKSPACE"])), patch.object(
                        native, "authorize_recoverable", side_effect=lambda p, e, v: real_authorize(p, e, v, api=api, guard=guard, now=100)), contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises((ValueError, KeyError)):
                        native.main()
                        checkout()
                checkout.assert_not_called()
                self.assertFalse(Path(env["GITHUB_ENV"]).exists())
                self.assertEqual(list(Path(policy["recoverable_activation"]["assignment_root"]).glob("*.json")), [])

    def test_workflow_requires_authorization_then_binding_before_every_native_checkout(self):
        import re
        from pathlib import Path
        source = (Path(__file__).resolve().parents[2] / ".github/workflows/recoverable-quality.yml").read_text()
        jobs = dict(zip(*[iter(re.split(r"^  ([a-z_]+):\n", source.split("jobs:\n", 1)[1], flags=re.M)[1:])] * 2))
        roles = {"native_checks", "prepare_thread", "prepare_address", "native_phase", "thread_shards", "address_shards", "native_aggregate"}
        for role in sorted(roles):
            with self.subTest(role=role):
                steps = jobs[role].split("    steps:\n", 1)[1]
                self.assertLess(steps.index("native_authorize"), steps.index("native_guard"))
                self.assertLess(steps.index("native_guard"), steps.index("native_checkout"))



class PhysicalIdentityTests(unittest.TestCase):
    def policy(self):
        """Return only non-secret identities used by the owned checkout gate."""
        return {"runner_root": "/fixture/native-runner", "developer_dir": "/fixture/Xcode",
                "swift": "fixture Swift", "sdk": "fixture SDK"}

    def test_physical_host_and_exact_workspace_are_required(self):
        from unittest.mock import patch
        from pathlib import Path
        from native_runner import require_physical_host
        policy = self.policy()
        env = {"GITHUB_WORKSPACE": "/fixture/native-runner/_work/elite/elite",
               "DEVELOPER_DIR": "/fixture/Xcode"}
        values = ["Mac14,12", "fixture Swift", "fixture SDK"]
        with patch("native_runner.platform.system", return_value="Darwin"), \
                patch("native_runner.platform.machine", return_value="arm64"), \
                patch("native_runner.output", side_effect=values):
            self.assertEqual(require_physical_host(policy, env), Path(env["GITHUB_WORKSPACE"]))
        for model in ["VirtualMac2,1", "VirtualMac"]:
            with self.subTest(model=model), \
                    patch("native_runner.platform.system", return_value="Darwin"), \
                    patch("native_runner.platform.machine", return_value="arm64"), \
                    patch("native_runner.output", return_value=model), self.assertRaises(ValueError):
                require_physical_host(policy, env)

    def test_other_platforms_toolchains_and_workspaces_fail_closed(self):
        from unittest.mock import patch
        from native_runner import require_physical_host
        for system, machine, workspace, developer, values in [
            ("Linux", "arm64", "/fixture/native-runner/_work/elite/elite", "/fixture/Xcode", []),
            ("Darwin", "x86_64", "/fixture/native-runner/_work/elite/elite", "/fixture/Xcode", []),
            ("Darwin", "arm64", "/fixture/other", "/fixture/Xcode", ["Mac14,12"]),
            ("Darwin", "arm64", "/fixture/native-runner/_work/elite/elite", "/other", ["Mac14,12"]),
            ("Darwin", "arm64", "/fixture/native-runner/_work/elite/elite", "/fixture/Xcode", ["Mac14,12", "other Swift"]),
            ("Darwin", "arm64", "/fixture/native-runner/_work/elite/elite", "/fixture/Xcode", ["Mac14,12", "fixture Swift", "other SDK"]),
        ]:
            with self.subTest(system=system, machine=machine, workspace=workspace, values=values), \
                    patch("native_runner.platform.system", return_value=system), \
                    patch("native_runner.platform.machine", return_value=machine), \
                    patch("native_runner.output", side_effect=values), self.assertRaises(ValueError):
                require_physical_host(self.policy(), {"GITHUB_WORKSPACE": workspace,
                                                      "DEVELOPER_DIR": developer})


class ProvisioningFailureTests(unittest.TestCase):
    def registration_fixture(self):
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from unittest.mock import patch
        import prepare_native_runner as install
        temporary = TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        runner = Path(temporary.name).resolve()
        replacement = patch.object(install, "RUNNER", runner)
        replacement.start()
        self.addCleanup(replacement.stop)
        policy = {"recoverable_activation": {"runners": {"owned-one": {}}}}
        value = dict(agentName="owned-one", gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work")
        return install, runner / ".runner", policy, value

    def test_registration_accepts_utf8_with_or_without_bom_without_rewriting_vendor_bytes(self):
        import json
        install, path, policy, value = self.registration_fixture()
        value["vendorField"] = "retained \ufeff value"
        for encoding in ("utf-8", "utf-8-sig"):
            with self.subTest(encoding=encoding):
                raw = json.dumps(value, ensure_ascii=False).encode(encoding)
                path.write_bytes(raw)
                path.chmod(0o600)
                self.assertIsNone(install.require_registration(policy))
                self.assertEqual(path.read_bytes(), raw)

    def test_registration_bom_does_not_accept_malformed_json_or_invalid_utf8(self):
        import json
        install, path, policy, value = self.registration_fixture()
        for prefix in (b"", b"\xef\xbb\xbf"):
            for payload in (b"{bad json", b"\xff", b'{"agentName":'):
                with self.subTest(prefix=prefix, payload=payload), self.assertRaises(ValueError):
                    path.write_bytes(prefix + payload)
                    path.chmod(0o600)
                    install.require_registration(policy)
        path.write_bytes(b"\xef\xbb\xbf" * 2 + json.dumps(value).encode("utf-8"))
        with self.assertRaises(ValueError):
            install.require_registration(policy)

    def test_registration_bom_does_not_relax_vendor_identity_checks(self):
        import json
        install, path, policy, value = self.registration_fixture()
        for prefix in (b"", b"\xef\xbb\xbf"):
            for mutation in ({"agentName": "other"}, {"agentName": "owned-one\ufeff"},
                             {"gitHubUrl": "https://github.com/outside/elite"}, {"workFolder": "other"},
                             {"agentName": None}):
                with self.subTest(prefix=prefix, mutation=mutation):
                    path.write_bytes(prefix + json.dumps({**value, **mutation}).encode("utf-8"))
                    path.chmod(0o600)
                    with self.assertRaisesRegex(ValueError, "approved repository/runner"):
                        install.require_registration(policy)

    def test_registration_bom_does_not_relax_owned_file_or_symlink_checks(self):
        import json
        install, path, policy, value = self.registration_fixture()
        raw = json.dumps(value).encode("utf-8-sig")
        path.write_bytes(raw)
        path.chmod(0o666)
        with self.assertRaises(ValueError):
            install.require_registration(policy)
        target = path.with_name("vendor-json")
        target.write_bytes(raw)
        target.chmod(0o600)
        path.unlink()
        path.symlink_to(target)
        with self.assertRaises(ValueError):
            install.require_registration(policy)

    def test_unclean_or_wrong_head_cannot_prepare_a_runner(self):
        from pathlib import Path
        from unittest.mock import patch
        from prepare_native_runner import prepare
        for values in [["b" * 40], [SHA, " M a.swift"]]:
            with self.subTest(values=values), \
                    patch("prepare_native_runner.output", side_effect=values), self.assertRaises(ValueError):
                prepare(SHA, Path("/nonexistent/runner.tar.gz"), "a" * 64)

    def test_registration_failure_does_not_print_or_raise_credentials(self):
        from contextlib import redirect_stdout
        import io
        from types import SimpleNamespace
        from unittest.mock import patch
        from prepare_native_runner import register_and_run
        for responses in [[SimpleNamespace(returncode=1, stdout="private", stderr="private")],
                          [SimpleNamespace(returncode=0, stdout='{"token":"fake-private-token"}'),
                           SimpleNamespace(returncode=1)]]:
            captured = io.StringIO()
            with self.subTest(stage=len(responses)), redirect_stdout(captured), \
                    patch("prepare_native_runner.subprocess.run", side_effect=responses):
                with self.assertRaises(ValueError) as error:
                    register_and_run(False)
                self.assertNotIn("private", str(error.exception))
            self.assertEqual(captured.getvalue(), "")

    def test_success_uses_one_ephemeral_registration_without_exposing_token(self):
        from contextlib import redirect_stdout
        import io
        from types import SimpleNamespace
        from unittest.mock import patch
        from prepare_native_runner import register_and_run
        responses = [SimpleNamespace(returncode=0, stdout='{"token":"fake-private-token"}'),
                     SimpleNamespace(returncode=0), SimpleNamespace(returncode=0)]
        captured = io.StringIO()
        with redirect_stdout(captured), patch("prepare_native_runner.subprocess.run", side_effect=responses) as run:
            register_and_run(True)
        configuration = run.call_args_list[1].args[0]
        self.assertIn("--ephemeral", configuration)
        self.assertIn("--disableupdate", configuration)
        self.assertEqual(configuration[configuration.index("--labels") + 1], "elite-native")
        self.assertEqual(run.call_args_list[2].args[0][-1], "--once")
        self.assertNotIn("fake-private-token", captured.getvalue())


class MaintainedMakeTargetsTests(unittest.TestCase):
    def test_unit_target_still_runs_the_authoritative_selection_once(self):
        from pathlib import Path
        import subprocess
        root = Path(__file__).resolve().parents[2]
        plan = subprocess.check_output(["make", "-n", "unit-ci"], cwd=root, text=True)
        self.assertEqual(plan.count("python3 Tools/CI/isolated_units.py"), 1)
        self.assertIn("test_script_instance_equality.py", plan)
        quality = subprocess.check_output(["make", "-n", "ci"], cwd=root, text=True)
        self.assertNotIn("Tools/CI/isolated_units.py", quality)
        for gate in ["test_native_runner.py", "quality_phase_checkpoints.py normal", "quality_phase_checkpoints.py leaks"]:
            self.assertIn(gate, quality)
        from tempfile import TemporaryDirectory
        from unittest.mock import patch
        import sanitizer_checkpoints as checkpoints

        class CapturedBuild(Exception):
            pass

        for mode, scratch in [("thread", ".build/tsan"), ("address", ".build/asan")]:
            self.assertEqual(quality.count("python3 Tools/CI/sanitizer_checkpoints.py " + mode), 1)
            with TemporaryDirectory() as directory:
                fixture = Path(directory).resolve()
                with (patch.object(checkpoints, "ROOT", fixture),
                      patch.object(checkpoints, "ensure_no_live_tests"),
                      patch.object(checkpoints, "output", side_effect=["a" * 40, ""]),
                      patch.object(checkpoints, "executable_inputs", return_value={}),
                      patch.object(checkpoints.shutil, "which", return_value="/toolchain/swift"),
                      patch.object(checkpoints.subprocess, "run", side_effect=CapturedBuild) as run):
                    # Capture the actual production build command before any process can run.
                    with self.assertRaises(CapturedBuild):
                        checkpoints.run_mode(mode, fixture / "checkpoints")
                command = run.call_args.args[0]
                self.assertEqual(command[:3], ["/toolchain/swift", "build", "--build-tests"])
                flags = command[3:]
                self.assertEqual(flags, ["--scratch-path", scratch, "--sanitize=" + mode])
                test = checkpoints.batch_command(
                    "/toolchain/swift", flags, mode, fixture, ["EliteCoreTests.Smoke/always()"])
                self.assertIn("--sanitize=" + mode, test)
                self.assertEqual("--no-parallel" in test, mode == "address")
                self.assertIn("--filter", test)


class ImmutablePreparationTests(unittest.TestCase):
    def with_fixture(self):
        """Build a tiny local archive and mocked fingerprints; no runner is executed."""
        from contextlib import ExitStack
        import hashlib
        import io
        from pathlib import Path
        import tarfile
        import tempfile
        from unittest.mock import patch
        stack = ExitStack()
        temporary = stack.enter_context(tempfile.TemporaryDirectory())
        fixture = Path(temporary).resolve()
        home = fixture / "EliteNativeCI"
        authorization = fixture / "NativeAuthorization"
        repo = fixture / "repo"
        guard = repo / "Tools/CI/native_runner.py"
        guard.parent.mkdir(parents=True)
        guard.write_text("# approved fixture guard\n")
        archive = fixture / "runner.tar.gz"
        with tarfile.open(archive, "w:gz") as target:
            for name in ["config.sh", "run.sh", "bin/Runner.Listener"]:
                data = ("fixture " + name).encode()
                member = tarfile.TarInfo(name)
                member.size = len(data)
                target.addfile(member, io.BytesIO(data))
        def fingerprint(*args, **kwargs):
            if args == ("git", "rev-parse", "HEAD"):
                return SHA
            if args == ("git", "status", "--porcelain"):
                return ""
            return "fixture SDK" if args[0] == "xcrun" else "fixture Swift"
        stack.enter_context(patch("prepare_native_runner.ROOT", repo))
        stack.enter_context(patch("prepare_native_runner.HOME_ROOT", home))
        stack.enter_context(patch("prepare_native_runner.AUTHORIZATION_ROOT", authorization))
        stack.enter_context(patch("prepare_native_runner.RUNNER", home / "native-runner"))
        stack.enter_context(patch("prepare_native_runner.output", side_effect=fingerprint))
        return stack, home, archive, hashlib.sha256(archive.read_bytes()).hexdigest()

    def test_prepare_then_same_head_register_reuses_immutable_authorization(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        from prepare_native_runner import prepare, register_and_run
        stack, home, archive, digest = self.with_fixture()
        with stack:
            self.assertFalse(home.exists())
            policy = prepare(SHA, archive, digest)
            before = policy.read_bytes()
            installation = home / "native-runner/.elite-native-installation.json"
            self.assertEqual(installation.stat().st_mode & 0o777, 0o400)
            installation_identity = (installation.stat().st_ino, installation.stat().st_mtime_ns)
            again = prepare(SHA, archive, digest)
            self.assertEqual(again, policy)
            self.assertEqual(policy.read_bytes(), before)
            self.assertEqual((installation.stat().st_ino, installation.stat().st_mtime_ns), installation_identity)
            with patch("prepare_native_runner.subprocess.run", side_effect=[
                SimpleNamespace(returncode=0, stdout='{"token":"fake-private-token"}'),
                SimpleNamespace(returncode=0),
            ]):
                register_and_run(False)

    def test_failed_token_or_configuration_can_retry_same_approved_head(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        from prepare_native_runner import prepare, register_and_run
        for failure in ["token", "configuration"]:
            stack, home, archive, digest = self.with_fixture()
            with stack, self.subTest(failure=failure):
                policy = prepare(SHA, archive, digest)
                before = policy.read_bytes()
                responses = [SimpleNamespace(returncode=1)] if failure == "token" else [
                    SimpleNamespace(returncode=0, stdout='{"token":"fake-private-token"}'),
                    SimpleNamespace(returncode=1)]
                with patch("prepare_native_runner.subprocess.run", side_effect=responses), self.assertRaises(ValueError):
                    register_and_run(False)
                self.assertEqual(prepare(SHA, archive, digest).read_bytes(), before)
                with patch("prepare_native_runner.subprocess.run", side_effect=[
                    SimpleNamespace(returncode=0, stdout='{"token":"fake-private-token"}'),
                    SimpleNamespace(returncode=0)]):
                    register_and_run(False)

    def test_changed_guard_policy_modes_or_runner_bytes_refuse_reuse(self):
        from prepare_native_runner import prepare
        for fault in ["guard", "policy", "mode", "runner", "active", "installation-link",
                      "installation-mode", "trust-root-mode", "authorization-parent-mode",
                      "authorization-mode"]:
            stack, home, archive, digest = self.with_fixture()
            with stack, self.subTest(fault=fault):
                policy = prepare(SHA, archive, digest)
                if fault == "installation-link":
                    marker = home / "native-runner/.elite-native-installation.json"
                    target = home / "marker-target"
                    target.write_bytes(marker.read_bytes())
                    marker.unlink()
                    marker.symlink_to(target)
                elif fault == "installation-mode":
                    (home / "native-runner/.elite-native-installation.json").chmod(0o600)
                elif fault in ["trust-root-mode", "authorization-parent-mode", "authorization-mode"]:
                    directory = {"trust-root-mode": home,
                                 "authorization-parent-mode": policy.parent.parent,
                                 "authorization-mode": policy.parent}[fault]
                    directory.chmod(0o777)
                elif fault == "runner":
                    (home / "native-runner/bin/Runner.Listener").write_text("modified")
                elif fault == "active":
                    (home / "native-runner/.runner").write_text("registered")
                elif fault == "mode":
                    policy.chmod(0o600)
                else:
                    path = policy if fault == "policy" else policy.parent / "guard.py"
                    path.chmod(0o600)
                    path.write_text("modified")
                    path.chmod(0o400 if fault == "policy" else 0o500)
                with self.assertRaises(ValueError):
                    prepare(SHA, archive, digest)


class HookDispatchTests(unittest.TestCase):
    with_fixture = ImmutablePreparationTests.with_fixture
    def test_unsafe_installation_is_refused_and_owned_scripts_dispatch_safely(self):
        from pathlib import Path
        import subprocess
        from unittest.mock import patch
        from prepare_native_runner import prepare
        stack, home, archive, digest = self.with_fixture()
        with stack:
            spaced = home.parent / "Application Support/native-runner"
            with patch("prepare_native_runner.RUNNER", spaced), self.assertRaises(ValueError):
                prepare(SHA, archive, digest)
            self.assertFalse(home.exists())
            self.assertFalse(spaced.exists())
            policy = prepare(SHA, archive, digest)
            self.assertFalse(any(character.isspace() for character in str(home)))
            assignment = (home / "native-runner/.env").read_text().splitlines()[0]
            hook = Path(assignment.split("=", 1)[1])
            self.assertFalse(any(character.isspace() for character in str(hook)))
            self.assertEqual(hook.parent, policy.parent)
            self.assertFalse(hook.is_symlink())
            # Match Actions' outer unquoted shell dispatch. The fixture guard is a no-op.
            result = subprocess.run(
                ["/bin/bash", "--noprofile", "--norc", "-c", str(hook)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            script = home / "native-runner/_work/_temp/step.sh"
            script.parent.mkdir(parents=True)
            script.write_text("#!/bin/bash\nexit 0\n")
            result = subprocess.run(
                ["/bin/bash", "-c", "/bin/bash -e " + str(script)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            with patch("prepare_native_runner.AUTHORIZATION_ROOT", home / "unsafe authorization"):
                with self.assertRaises(ValueError):
                    prepare(SHA, archive, digest)
