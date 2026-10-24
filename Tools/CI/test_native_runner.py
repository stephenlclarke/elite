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
        for gate in ["test_native_runner.py", "script/coverage.sh", "--sanitize=thread",
                     "--sanitize=address", "leaks --atExit"]:
            self.assertIn(gate, quality)


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
        fixture = Path(temporary)
        home = fixture / "EliteCI"
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
