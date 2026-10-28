"""Deterministic diagnostic contracts. No host tool, process, signal or resource probe."""

from contextlib import ExitStack
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import signal
import tempfile
import unittest
from unittest.mock import patch

import native_runner as guard
import prepare_native_runner as provision
import recoverable_shards as shards
import sanitizer_checkpoints as legacy


HEAD = "a" * 40
SHA = "b" * 64
START = "Mon Oct 28 10:00:00 2026"
RAW = b"REGION TYPE         VIRTUAL SIZE\nMALLOC              14M\n"  # Deliberately no residency field.


def write_json(path, value, immutable=False):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.exists():
        path.chmod(0o600)
    path.write_text(json.dumps(value))
    path.chmod(0o400 if immutable else 0o600)
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def row(pid, parent, group=None, command=None, rss=1024, role=None):
    value = dict(pid=pid, parent=parent, group=pid if group is None else group,
                 start=START, command=command or "/fake/" + str(pid), rss_bytes=rss, state="S")
    if role is not None:
        value["role"] = role
    return value


def identity(value):
    return {key: value[key] for key in ("pid", "parent", "group", "start", "command", "role")}


class FakeClock:
    def __init__(self):
        self.now, self.on_sleep = 10.0, None

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds
        if self.on_sleep is not None:
            self.on_sleep()


class Fixture(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory())).resolve()
        self.custody = self.root / "diagnostic-custody"
        self.custody.mkdir(mode=0o700)
        self.stack.enter_context(patch.object(guard, "diagnostic_custody_root", return_value=self.custody))
        self.stack.enter_context(patch.dict(os.environ, {}, clear=True))
        # Any accidentally unmocked native/process action fails this test immediately.
        for name in ("run", "Popen", "check_output", "call"):
            self.stack.enter_context(patch.object(shards.subprocess, name,
                side_effect=AssertionError("Unmocked process call: " + name)))
        self.stack.enter_context(patch.object(shards.os, "kill", side_effect=AssertionError("Real signal")))
        self.empty_registry()
        self.clock = FakeClock()
        self.source = self.root / "project"
        (self.source / "Tools/CI").mkdir(parents=True)
        self.image = self.root / "worker/.build/debug/ElitePackageTests.xctest/Contents/MacOS/ElitePackageTests"
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b"fake prepared image, not an executable")
        self.python = self.root / "python-image"
        self.python.write_bytes(b"fake controller image")
        self.stack.enter_context(patch.object(shards.sys, "executable", str(self.python)))
        self.authority = object.__new__(shards.LocalAuthority)
        self.authority.root = self.source
        self.authority.policy = {"approved_head": HEAD}
        self.authority.policy_sha256, self.authority.session_digest = SHA, "c" * 64
        self.authority.session = {"kind": shards.VM_SESSION_KIND, "stage": "execute", "max_launches": 1}
        self.used = 1
        self.authority.check_session = lambda stage: self.authority.session
        self.authority.budget_state = lambda: (None, {"used": self.used})
        self.authority.config = {"admission": {"peak_per_worker": 2415919104, "ram_reserve": 2147483648},
            "vmmap_diagnostic": {"kind": shards.VM_DIAGNOSTIC_KIND,
                "tool": {"path": "/usr/bin/vmmap", "sha256": SHA},
                "argv": ["/usr/bin/vmmap", "-summary", "-w", "{helper_pid}"],
                "target_binding": "single-owned-prepared-image-v1", "trigger_worker_rss_bytes": 1879048192,
                "max_captures": 1, "capture_seconds": 10, "cleanup_seconds": 2,
                "output_limit_bytes": 4 * 1024 * 1024, "accounting": "controller-worker-vmmap-support-union-v1",
                "cohort_count": 16, "cohort_methods_sha256": SHA,
                "game_test_inputs_sha256": shards.fingerprint({"Sources/Game.swift": SHA, "Tests/Game.swift": SHA}),
                "deployment": {"path": str(self.root / "deployment.json"), "sha256": SHA}}}
        self.runtime = {"inputs": {"Sources/Game.swift": SHA, "Tests/Game.swift": SHA},
            "image_sha256": legacy.digest(self.image), "image_uuid": "d" * 64,
            "environment": {shards.VM_DIAGNOSTIC_ENV: SHA}}
        self.deploy()
        self.attempt = self.root / "attempt"
        self.attempt.mkdir(mode=0o700)
        self.owner = row(os.getpid(), 1, command="/fake/controller", role="controller")
        self.owner["image_sha256"] = legacy.digest(self.python)

    def empty_registry(self):
        write_json(self.custody / "registry.json", {"schema": 1, "kind": guard.CUSTODY_KIND,
                                                   "generation": 0, "records": {}})

    def deploy(self):
        names = {"controller": "recoverable_shards.py", "guard": "native_runner.py",
                 "legacy": "sanitizer_checkpoints.py", "quality": "quality_phase_checkpoints.py",
                 "provisioner": "prepare_native_runner.py"}
        entries = []
        for name, filename in names.items():
            path = self.source / "Tools/CI" / filename
            if path.exists():
                path.chmod(0o600)
            path.write_text("fixture source " + filename)
            path.chmod(0o400)
            entries.append(dict(role="source-" + name, path=str(path), sha256=legacy.digest(path)))
            installed = self.root / ("installed-" + filename)
            if installed.exists():
                installed.chmod(0o600)
            installed.write_bytes(path.read_bytes())
            installed.chmod(0o400)
            entries.append(dict(role="installed-" + name, path=str(installed), sha256=legacy.digest(installed)))
        hook = self.root / "job-started.sh"
        if hook.exists():
            hook.chmod(0o600)
        hook.write_text("fixture hook bytes")
        hook.chmod(0o400)
        entries.append(dict(role="installed-hook", path=str(hook), sha256=legacy.digest(hook)))
        matrix = sorted(guard.RECOVERABLE_JOBS)
        review = write_json(self.root / "deployment-review.json", {
            "schema": 1, "kind": "diagnostic-launch-surface-review-v1", "head": HEAD,
            "entries_sha256": shards.fingerprint(entries), "matrix_sha256": shards.fingerprint(matrix),
            "old_paths_quiesced": True}, immutable=True)
        self.authority.config["vmmap_diagnostic"]["deployment"] = write_json(self.root / "deployment.json", {
            "schema": 1, "kind": "reviewed-diagnostic-launch-surface-v1", "head": HEAD, "entries": entries,
            "supported_jobs": matrix, "controller_needing_jobs": [], "old_paths_quiesced": True,
            "review": review}, immutable=True)

    def leases(self):
        result = []
        for role in ("controller", "executor", "reservation"):
            lock = self.stack.enter_context((self.root / (role + ".lock")).open("a+"))
            shards.fcntl.flock(lock, shards.fcntl.LOCK_EX | shards.fcntl.LOCK_NB)
            result.append(self.stack.enter_context(guard._diagnostic_lease_context(lock, role)))
        return result

    def capability(self):
        controller = {key: self.owner[key] for key in ("pid", "start", "command", "image_sha256")}
        controller.update(image=str(self.python), source_sha256=legacy.digest(self.source / "Tools/CI/recoverable_shards.py"))
        cap = shards._VmmapCapability(self.authority, self.attempt, controller, self.leases(), 30, self.clock)
        record = dict(nonce=cap.nonce, attempt=str(self.attempt), source_head=HEAD, policy_sha256=SHA,
            session_sha256="c" * 64, controller=controller, identities=[identity(self.owner)], state="ACTIVE",
            phase="timed", launches=1, deadline=30, last_verified=None, terminal=None, intents=[], target=None)
        cap.publish(record)
        return cap, record

    def resolve(self, record):
        evidence = write_json(self.root / "absence.json", dict(schema=1, kind="diagnostic-terminal-absence-v1",
            nonce=record["nonce"], record_sha256=guard.custody_digest(record), identities=record["identities"],
            absent=[item for item in record["identities"] if item["role"] != "controller"], target=record["target"], intents=record["intents"],
            unobserved_spawns_resolved=True, direct_children_reaped=True, controller_absent=True), immutable=True)
        review = write_json(self.root / "resolution-review.json", dict(schema=1,
            kind="diagnostic-custody-resolution-review-v1", nonce=record["nonce"],
            record_sha256=guard.custody_digest(record), evidence_sha256=evidence["sha256"], approved=True), immutable=True)
        value = {key: record[key] for key in ("nonce", "attempt", "source_head", "policy_sha256", "session_sha256",
                                           "controller", "identities", "target")}
        value.update(schema=1, kind="reviewed-diagnostic-custody-resolution-v1",
                     record_sha256=guard.custody_digest(record), evidence=evidence, review=review)
        path = self.custody / "resolutions" / (record["nonce"] + ".json")
        write_json(path, value, immutable=True)
        return path


class RegistryTests(Fixture):
    def test_empty_missing_malformed_and_owned_physical_only(self):
        guard.require_diagnostic_custody_clear()
        self.assertEqual(guard.authorization_failure(ValueError())["category"], "ValueError")
        path = self.custody / "registry.json"
        path.unlink()
        with self.assertRaises(OSError):
            guard.require_diagnostic_custody_clear()
        for data in (b"{}", b'{"schema":1,"schema":1}', b'{"x":NaN}', b'[]'):
            path.write_bytes(data)
            path.chmod(0o600)
            with self.assertRaises(ValueError):
                guard.require_diagnostic_custody_clear()
        self.empty_registry()
        path.chmod(0o644)
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()
        path.unlink()
        path.symlink_to(self.root / "absent.json")
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()

    def test_dead_owner_unknown_and_generic_ack_never_clear(self):
        cap, record = self.capability()
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()
        cap.unknown(record)
        self.assertEqual(guard.diagnostic_custody_registry()["records"][cap.nonce]["state"], "UNKNOWN")
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()
        path = self.custody / "resolutions" / (cap.nonce + ".json")
        write_json(path, {"ack": True}, immutable=True)
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()
        self.resolve(record)
        guard.require_diagnostic_custody_clear()
        registry = guard.diagnostic_custody_registry()
        registry["records"][cap.nonce]["intents"].append(dict(role="worker", argv=["/fake/new"], pid=None, state="planned"))
        write_json(self.custody / "registry.json", registry)
        with self.assertRaises(ValueError):
            guard.require_diagnostic_custody_clear()

    def test_closed_schema_and_clean_requires_full_bounded_terminal_evidence(self):
        cap, original = self.capability()
        for change in ({"launches": True}, {"deadline": float("nan")}, {"identities": []},
                       {"state": "CLEAN", "phase": "terminal", "terminal": {"absent": [], "reaped": True, "time": 31}},
                       {"state": "CLEAN", "phase": "terminal", "terminal": {"absent": [], "reaped": True, "time": float("inf")}}):
            record = dict(original, **change)
            write_json(self.custody / "registry.json", dict(schema=1, kind=guard.CUSTODY_KIND, generation=1,
                                                           records={cap.nonce: record}))
            with self.assertRaises(ValueError):
                guard.diagnostic_custody_registry()
        record = dict(original, state="CLEAN", phase="terminal", terminal={"absent": [], "reaped": True, "time": 20})
        write_json(self.custody / "registry.json", dict(schema=1, kind=guard.CUSTODY_KIND, generation=2, records={cap.nonce: record}))
        guard.require_diagnostic_custody_clear()

    def test_all_shared_admissions_refuse_before_any_native_call(self):
        self.capability()
        calls = [lambda: guard.validate({}, {}), lambda: guard.admit_recoverable({}, {}, {}),
                 lambda: guard.authorize_recoverable({}, {}, {}), legacy.ensure_no_live_tests,
                 lambda: shards.LocalAuthority(None, None, None, None, None),
                 lambda: shards.NativeAuthority(None),
                 lambda: shards.reserve_worker(None, None, None, None, 1).__enter__(),
                 lambda: shards.NativeExecutor.reclaimable(None, None)]
        # Physical-enable precondition is source-only; test the shared guard that follows it.
        with patch.object(shards, "require_physical_activation"):
            for call in calls:
                with self.subTest(entrypoint=call):
                    with self.assertRaisesRegex(ValueError, "custody"):
                        call()


class CapabilityTests(Fixture):
    def test_current_attempt_only_consumed_budget_and_exact_record(self):
        cap, record = self.capability()
        cap.require_current()
        self.used = 0
        with self.assertRaises(ValueError):
            cap.require_current()
        self.used = 1
        saved = cap.nonce
        cap.nonce = "00000000-0000-0000-0000-000000000000"
        with self.assertRaises(ValueError):
            cap.require_current()
        cap.nonce = saved
        registry = guard.diagnostic_custody_registry()
        registry["records"][cap.nonce]["attempt"] += "-different"
        write_json(self.custody / "registry.json", registry)
        with self.assertRaises(ValueError):
            cap.require_current()

    def test_deadline_source_pid_image_and_phase_revoke(self):
        cap, record = self.capability()
        for key, bad in (("pid", -1), ("image_sha256", "e" * 64), ("source_sha256", "e" * 64)):
            previous = cap.controller[key]
            cap.controller[key] = bad
            with self.assertRaises(ValueError):
                cap.require_current()
            cap.controller[key] = previous
        self.clock.now = 30
        with self.assertRaises(ValueError):
            cap.require_current()
        cap.unknown(record)  # Safety persistence works at the deadline, reentry does not.
        self.clock.now = 10
        with self.assertRaises(ValueError):
            cap.require_current()

    def test_fd_lifetime_replacement_and_open_fd_are_not_witnesses(self):
        cap, _ = self.capability()
        lease = cap.leases[0]
        with self.assertRaises(ValueError):
            shards._VmmapCapability(self.authority, self.attempt, cap.controller, [item.lock for item in cap.leases], 30, self.clock)
        fd = lease.fd
        os.close(fd)
        replacement = os.open(lease.lock.name, os.O_RDWR)
        if replacement != fd:
            os.dup2(replacement, fd)
            os.close(replacement)
        with self.assertRaisesRegex(ValueError, "closed/reused"):
            cap.require_current()
        lease.lock.close()
        with self.assertRaises(ValueError):
            lease.verify()
        with self.assertRaises(ValueError):
            guard._DiagnosticLease(cap.leases[1].lock, "controller", object())


class PolicyTests(Fixture):
    def test_absent_is_ordinary_closed_policy_cannot_weaken_contract(self):
        self.assertIsNone(shards.validate_vmmap_policy({}))
        with self.assertRaises(ValueError):
            shards.local_environment({shards.VM_DIAGNOSTIC_ENV: shards.VM_DIAGNOSTIC_KIND})
        self.assertEqual(shards.validate_vmmap_policy(self.authority.config)["max_captures"], 1)
        for key, bad in (("max_captures", 2), ("capture_seconds", 11), ("cleanup_seconds", 3),
                         ("trigger_worker_rss_bytes", 1879048191), ("cohort_count", 15),
                         ("output_limit_bytes", True), ("argv", ["vmmap", "--help"])):
            value = copy.deepcopy(self.authority.config)
            value["vmmap_diagnostic"][key] = bad
            with self.subTest(field=key), self.assertRaises(ValueError):
                shards.validate_vmmap_policy(value)
        value["vmmap_diagnostic"]["new_option"] = True
        with self.assertRaises(ValueError):
            shards.validate_vmmap_policy(value)

    def test_actual_installed_source_review_and_job_matrix_are_required(self):
        shards.validate_vmmap_deployment(self.authority, self.runtime)
        installed = self.root / "installed-native_runner.py"
        installed.chmod(0o600)
        installed.write_bytes(b"old guard")
        with self.assertRaises(ValueError):
            shards.validate_vmmap_deployment(self.authority, self.runtime)
        self.deploy()
        path = self.root / "deployment.json"
        value = json.loads(path.read_text())
        value["controller_needing_jobs"] = ["local-run"]
        self.authority.config["vmmap_diagnostic"]["deployment"] = write_json(path, value, immutable=True)
        with self.assertRaises(ValueError):
            shards.validate_vmmap_deployment(self.authority, self.runtime)
        self.deploy()
        self.runtime["inputs"]["Sources/Game.swift"] = "e" * 64
        with self.assertRaises(ValueError):
            shards.validate_vmmap_deployment(self.authority, self.runtime)

    def test_diagnostic_session_and_ordinary_success_are_separate(self):
        session = dict(schema=1, kind=shards.VM_SESSION_KIND, id="00000000-0000-0000-0000-000000000000",
            head=HEAD, policy_sha256=SHA, mode="address", worker="one", stage="execute", shards=[SHA],
            expires_at=9999999999, plan_sha256=SHA, max_launches=1, diagnostic_sha256=SHA)
        shards.validate_local_session(session)
        for changes in ({"mode": "thread"}, {"stage": "validate"}, {"max_launches": 2}, {"shards": [SHA, "e" * 64]}):
            with self.assertRaises(ValueError):
                shards.validate_local_session(dict(session, **changes))
        with self.assertRaisesRegex(ValueError, "Diagnostic"):
            shards.validate_success(self.attempt, {"runtime": {"environment": {shards.VM_DIAGNOSTIC_ENV: SHA}}})


class OwnershipTests(Fixture):
    def test_union_roles_dedup_reparent_and_unrelated_ancestors(self):
        root = row(100, 1, command="/fake/controller", role="controller", rss=10)
        owners = shards._VmmapOwners(identity(root))
        for pid, role in ((200, "worker"), (300, "vmmap"), (400, "support")):
            child = type("Child", (), dict(pid=pid, role=role, argv=["/fake/" + str(pid)], code=None))()
            owners.spawned(child)
        rows = {item["pid"]: item for item in (root, row(200, 100, rss=20), row(201, 200, 200, rss=30),
                row(300, 100, rss=40), row(400, 100, rss=50), row(1, 0, rss=999999))}
        live, roles, total = owners.observe(rows)
        self.assertEqual(roles, dict(controller=10, worker=50, vmmap=40, support=50))
        self.assertEqual(total, 150)
        rows[201]["parent"] = 1
        live, _, total = owners.observe(rows)
        self.assertEqual(live[201]["role"], "worker")
        self.assertEqual(total, 150)
        rows[201]["start"] = "different start"
        with self.assertRaisesRegex(ValueError, "drift"):
            owners.observe(rows)

    def test_ambiguity_unowned_controller_child_and_missing_rss_refuse(self):
        root = row(100, 1, role="controller")
        for rows in ({100: root, 200: row(200, 100)}, {100: {**root, "rss_bytes": None}}):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                shards._VmmapOwners(identity(root)).observe(rows)


class FakeWorld:
    def __init__(self, fixture, worker_exit=True, stubborn=False, utility_hang=False, union_over=False, raw=RAW, helper_rss=1879048192, controller_rss=1024):
        self.fixture, self.clock = fixture, fixture.clock
        self.worker_exit, self.stubborn, self.utility_hang, self.union_over = worker_exit, stubborn, utility_hang, union_over
        self.raw, self.children, self.actions, self.signals = raw, [], [], []
        self.helper_rss, self.controller_rss = helper_rss, controller_rss
        self.utility_done = None
        self.helper_live = True
        self.monitor = None

    def spawn(self, role, argv, workspace, environment, descriptors, output, limit):
        self.actions.append(("spawn", self.clock(), role))
        registry = guard.diagnostic_custody_registry()
        assert len(registry["records"]) == 1 and next(iter(registry["records"].values()))["state"] == "ACTIVE"
        child = FakeChild(self, role, argv, 20000 + len(self.children), output, limit)
        self.children.append(child)
        if role == "support":
            child.snapshot = self.snapshot()
        return child

    def snapshot(self):
        rows = [dict(self.fixture.owner, rss_bytes=self.controller_rss)]
        for child in self.children:
            if child.code is None:
                rows.append(row(child.pid, self.fixture.owner["pid"], command=shlex.join(child.argv), rss=4096))
        worker = next((child for child in self.children if child.role == "worker"), None)
        if worker is not None and worker.code is None and self.helper_live:
            image = str(self.fixture.image)
            command = shlex.join(["/fake/swiftpm-testing-helper", "--test-bundle-path", image, image,
                                  "--testing-library", "swift-testing"])
            rows.append(row(30000, worker.pid, worker.pid, command, rss=self.helper_rss))
        if self.union_over:
            rows[0] = dict(rows[0], rss_bytes=2415919104)
        return "\n".join(f'{r["pid"]} {r["parent"]} {r["group"]} S {r["start"]} {r["rss_bytes"] // 1024} {r["command"]}' for r in rows).encode()

    def signal(self, pid, signum):
        self.actions.append(("signal", self.clock(), pid))
        self.signals.append((pid, signum, self.clock()))
        if not self.stubborn:
            if pid == 30000:
                self.helper_live = False
            for child in self.children:
                if child.pid == pid:
                    child.exit = -signum
                    if child.role == "worker":
                        self.helper_live = False

    def settle(self):
        if self.worker_exit and self.utility_done is not None and self.clock() > self.utility_done + 0.3:
            for child in self.children:
                if child.role == "worker":
                    child.exit = 0
                    self.helper_live = False


class FakeChild:
    def __init__(self, world, role, argv, pid, output, limit):
        self.world, self.role, self.argv, self.pid = world, role, list(argv), pid
        self.output, self.limit, self.code, self.exit = output, limit, None, None
        self.open_streams = {"stdout", "stderr"}
        self.buffers, self.total, self.snapshot = {"stdout": bytearray(), "stderr": bytearray()}, 0, b""
        self.clock, self.deadline = world.clock, float("inf")

    def poll(self):
        if self.clock() < self.deadline:
            self.world.actions.append(("poll", self.clock(), self.role))
            self.world.settle()
            self.code = self.exit
        return self.code

    def drain(self):
        if not self.open_streams:
            return
        self.world.actions.append(("drain", self.clock(), self.role))
        if self.role == "support":
            self.buffers["stdout"].extend(self.snapshot)
            self.exit = 0
        elif self.role == "vmmap":
            if self.world.utility_hang:
                return
            self.total += len(self.world.raw)
            self.output["stdout"].write(self.world.raw)
            self.output["stdout"].flush()
            self.exit = 0
            self.world.utility_done = self.clock()
        elif self.exit is None:
            return
        self.open_streams.clear()

    def close(self):
        self.world.actions.append(("close", self.clock(), self.role))


class ControllerTests(Fixture):
    def execute(self, **options):
        world = FakeWorld(self, **options)
        monitor = shards.VmmapDiagnostic(self.authority, self.attempt, self.image.parents[5], self.runtime,
            self.image, self.leases(), self.owner, self.clock, self.clock.sleep, world.spawn, world.signal)
        # Tool identity is a fake fixture assertion; no real /usr/bin/vmmap metadata is read.
        monitor.tool_identity = lambda: None
        world.monitor = monitor
        return monitor, world

    def test_one_threshold_capture_raw_units_clean_exit_and_no_promotion(self):
        monitor, world = self.execute()
        result = monitor.execute(["/fake/swift", "test", "--skip-build"], 6, (), {})
        self.assertEqual(result, 0, monitor.errors)
        self.assertEqual(sum(child.role == "vmmap" for child in world.children), 1)
        self.assertGreaterEqual(monitor.last_sample_started, monitor.utility_finished)
        self.assertEqual(monitor.utility.argv, ["/usr/bin/vmmap", "-summary", "-w", "30000"])
        self.assertEqual((self.attempt / "vmmap.stdout").read_bytes(), RAW)
        self.assertEqual((self.attempt / "vmmap.stdout").stat().st_mode & 0o777, 0o600)
        receipt = json.loads((self.attempt / "diagnostic.json").read_text())
        self.assertEqual(receipt["status"], "capture-complete/question-unanswered")
        self.assertEqual(receipt["residency"], "UNAVAILABLE")
        self.assertFalse(receipt["ordinary_pass"])
        self.assertGreater(monitor.memory["roles"]["controller"], 0)
        guard.require_diagnostic_custody_clear()
        write_json(self.attempt / "authorization.json", {"head": HEAD, "policy_sha256": SHA,
            "session": {"kind": shards.VM_SESSION_KIND, "policy_sha256": SHA}})
        evidence = shards.validate_vmmap_evidence(self.attempt, {"runtime": self.runtime})
        self.assertFalse(evidence["ordinary_pass"])
        write_json(self.attempt / "result.json", {"status": "passed"})
        with self.assertRaises(ValueError):
            shards.validate_vmmap_evidence(self.attempt, {"runtime": self.runtime})

    def test_union_overflow_aborts_capture_but_still_cleans(self):
        monitor, world = self.execute(union_over=True)
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertFalse(monitor.triggered)
        self.assertIn("budget", monitor.memory["failure"])
        self.assertTrue(world.signals)
        guard.require_diagnostic_custody_clear()

    def test_hung_capture_cleanup_within_original_deadline_and_term_kill(self):
        monitor, world = self.execute(worker_exit=False, stubborn=True, utility_hang=True)
        hold_actions = []
        def resolution_after_hold():
            if monitor.cap is not None and monitor.cap.phase == "custody-only":
                if not hold_actions:
                    hold_actions.extend(world.actions)
                    for lease in monitor.leases:
                        lease.verify()
                    self.assertRaises(ValueError, guard.require_diagnostic_custody_clear)
                    # Simulate an interrupt while custody is held. It must not unwind leases.
                    raise KeyboardInterrupt()
                self.resolve(guard.diagnostic_custody_registry()["records"][monitor.cap.nonce])
        self.clock.on_sleep = resolution_after_hold
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 5, (), {}), 125)
        self.assertTrue(hold_actions)
        self.assertTrue(any(item[1] == signal.SIGTERM for item in world.signals))
        self.assertTrue(any(item[1] == signal.SIGKILL for item in world.signals))
        self.assertTrue(all(action[1] < monitor.deadline for action in world.actions if action[0] != "close"))
        self.assertEqual([a for a in world.actions[len(hold_actions):] if a[0] != "close"], [])
        receipt = json.loads((self.attempt / "diagnostic.json").read_text())
        self.assertEqual(receipt["post_deadline"], {"rss": "UNKNOWN", "identity": "UNKNOWN"})
        self.assertEqual(receipt["status"], "INCOMPLETE/UNKNOWN")
        guard.require_diagnostic_custody_clear()

    def test_raw_invalid_utf8_is_retained_and_incomplete(self):
        monitor, world = self.execute(raw=b"\xff original bytes")
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertFalse(monitor.capture_complete)
        self.assertEqual((self.attempt / "vmmap.stdout").read_bytes(), b"\xff original bytes")

    def test_tool_drift_before_capture_is_not_retried(self):
        monitor, world = self.execute()
        monitor.tool_identity = lambda: (_ for _ in ()).throw(ValueError("fake tool drift"))
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertTrue(monitor.triggered)
        self.assertFalse(any(child.role == "vmmap" for child in world.children))


    def test_worker_threshold_excludes_controller_and_no_trigger_is_incomplete(self):
        monitor, world = self.execute(helper_rss=1024, controller_rss=1879048192)
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 4, (), {}), 125)
        self.assertFalse(monitor.triggered)
        self.assertFalse(any(child.role == "vmmap" for child in world.children))
        guard.require_diagnostic_custody_clear()

    def test_capture_has_own_ten_second_limit_and_only_one_cleanup_window(self):
        monitor, world = self.execute(worker_exit=False, utility_hang=True)
        start = self.clock()
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 20, (), {}), 125)
        self.assertLessEqual(self.clock() - start, 12.1)
        self.assertEqual(sum(child.role == "vmmap" for child in world.children), 1)
        self.assertTrue(any("capture deadline" in error for error in monitor.errors))
        guard.require_diagnostic_custody_clear()

    def test_failed_terminal_persistence_retains_leases_until_exact_resolution(self):
        monitor, world = self.execute()
        original = monitor.persist
        def persist(critical=False):
            if monitor.record["state"] == "CLEAN":
                raise OSError("fixture disk failure at terminal publication")
            original(critical)
        monitor.persist = persist
        held = []
        def resolve_hold():
            if monitor.cap is not None and monitor.cap.phase == "custody-only":
                held.extend(lease.verify() for lease in monitor.leases)
                self.resolve(guard.diagnostic_custody_registry()["records"][monitor.cap.nonce])
        self.clock.on_sleep = resolve_hold
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertEqual(len(held), 3)
        self.assertTrue(any("terminal persistence" in error for error in monitor.errors))


    def test_spawn_exception_retains_unresolved_intent_and_held_custody(self):
        monitor, world = self.execute()
        def spawn(role, *args):
            if role == "worker":
                raise OSError("fixture constructor failed after possible spawn")
            return world.spawn(role, *args)
        monitor.spawn = spawn
        seen = []
        def resolve_hold():
            if monitor.cap is not None and monitor.cap.phase == "custody-only":
                record = guard.diagnostic_custody_registry()["records"][monitor.cap.nonce]
                seen.extend(item for item in record["intents"] if item["role"] == "worker")
                for lease in monitor.leases:
                    lease.verify()
                self.resolve(record)
        self.clock.on_sleep = resolve_hold
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertEqual(seen[0]["state"], "planned")
        self.assertIsNone(seen[0]["pid"])


    def test_missing_diagnostic_output_never_falls_back_to_native_reclaim_probe(self):
        cap, record = self.capability()
        write_json(self.attempt / "start.json", {"identity": {"runtime": self.runtime}})
        executor = object.__new__(shards.NativeExecutor)
        self.assertFalse(executor.proven_exited(self.attempt))
        cap.unknown(record)
        self.assertFalse(executor.proven_exited(self.attempt))
        self.resolve(record)
        self.assertTrue(executor.proven_exited(self.attempt))


class CorrectionTests(Fixture):
    execute = ControllerTests.execute

    def test_persistent_output_cap_still_samples_signals_and_reaps(self):
        monitor, world = self.execute(worker_exit=False)
        original_spawn = monitor.spawn
        failed_reads = []
        held = []
        block = {101: b"O" * 16384, 102: b"E" * 16384}
        def spawn(role, *args):
            child = original_spawn(role, *args)
            if role == "vmmap":
                child.streams = {"stdout": 101, "stderr": 102}
                def drain():
                    with patch.object(shards.select, "select", return_value=([101, 102], [], [])), \
                            patch.object(shards.os, "read", side_effect=lambda fd, size: block[fd][:size]):
                        try:
                            shards._VmmapChild.drain(child)
                        except ValueError:
                            failed_reads.append(self.clock())
                            raise  # Repeats forever if cleanup tries failed acquisition again.
                child.drain = drain
            return child
        monitor.spawn = spawn
        original_signal = world.signal
        def signal_after_grace(pid, signum):
            if signum == signal.SIGTERM:
                world.actions.append(("signal", self.clock(), pid))
                world.signals.append((pid, signum, self.clock()))
            else:
                original_signal(pid, signum)
        monitor.send_signal = signal_after_grace
        def rescue_old_failure():
            if monitor.cap is not None and monitor.cap.phase == "custody-only":
                held.append(self.clock())
                self.resolve(guard.diagnostic_custody_registry()["records"][monitor.cap.nonce])
        self.clock.on_sleep = rescue_old_failure
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 20, (), {}), 125)
        self.assertEqual(len(failed_reads), 1)
        self.assertEqual(held, [], "Output failure alone must not abandon verified cleanup")
        self.assertEqual(monitor.failed_output, {monitor.utility.pid})
        self.assertEqual({signum for _, signum, _ in world.signals}, {signal.SIGTERM, signal.SIGKILL})
        self.assertEqual({pid for pid, _, _ in world.signals}, {monitor.worker.pid, monitor.utility.pid, 30000})
        self.assertTrue(all(child.code is not None for child in world.children))
        self.assertLess(self.clock(), min(monitor.deadline, failed_reads[0] + 2))
        self.assertTrue(all(time < monitor.deadline for _, _, time in world.signals))
        after_failure = [a for a in world.actions if a[1] > failed_reads[0]]
        self.assertTrue(any(a[0] == "spawn" and a[2] == "support" for a in after_failure))
        output = {name: (self.attempt / ("vmmap." + name)).read_bytes() for name in ("stdout", "stderr")}
        self.assertEqual(sum(map(len, output.values())), 4 * 1024 * 1024)
        for name, byte in (("stdout", b"O"), ("stderr", b"E")):
            self.assertEqual(output[name], byte * len(output[name]))
        self.assertFalse(monitor.capture_complete)
        self.assertTrue(any("combined output cap" in error for error in monitor.errors))
        self.assertFalse(any(error.startswith("cleanup:") for error in monitor.errors))
        guard.require_diagnostic_custody_clear()

    def test_cleanup_output_exception_does_not_abort_fresh_identity_checks(self):
        monitor, world = self.execute()
        original_cleanup = monitor.cleanup
        failures = []
        def cleanup():
            def failed_output():
                failures.append(self.clock())
                raise OSError("fixture persistent worker output failure during cleanup")
            monitor.worker.drain = failed_output
            return original_cleanup()
        monitor.cleanup = cleanup
        self.assertEqual(monitor.execute(["/fake/swift", "test"], 6, (), {}), 125)
        self.assertEqual(len(failures), 1)
        self.assertTrue(any(error.startswith("cleanup output: OSError") for error in monitor.errors))
        self.assertEqual(monitor.failed_output, {monitor.worker.pid})
        self.assertTrue(all(child.code is not None for child in world.children))
        guard.require_diagnostic_custody_clear()

    def _assert_paced_hold(self, failure):
        cap, record = self.capability()
        world = FakeWorld(self)
        monitor = shards.VmmapDiagnostic(self.authority, self.attempt, self.image.parents[5], self.runtime,
            self.image, cap.leases, self.owner, self.clock, self.clock.sleep, world.spawn, world.signal)
        monitor.cap, monitor.record = cap, record
        self.clock.now = cap.deadline
        original_registry = guard.diagnostic_custody_registry
        original = original_registry()
        registry_path = self.custody / "registry.json"
        if failure == "missing":
            registry_path.unlink()
        elif failure == "malformed":
            write_json(registry_path, {"schema": "invalid"})
        else:
            unknown = dict(record, state="UNKNOWN", phase="custody-only", terminal=None)
            path = self.resolve(unknown)
            value = json.loads(path.read_text())
            value["record_sha256"] = "e" * 64
            write_json(path, value, immutable=True)
        reads, waits = [], []
        def resolve():
            if failure in ("missing", "malformed"):
                write_json(registry_path, original)
            self.resolve(original_registry()["records"][cap.nonce])
        def read_registry():
            reads.append(self.clock())
            if len(reads) == 6:
                resolve()  # Let the old busy loop return, so its missing waits fail assertions.
            return original_registry()
        def wait(seconds):
            waits.append((self.clock(), seconds))
            for lease in cap.leases:
                lease.verify()
            self.assertEqual(world.actions, [])
            self.clock.sleep(seconds)
            if len(waits) == 1:
                raise KeyboardInterrupt()  # The interrupted wait must not unwind custody or read again.
            if len(waits) == 3:
                resolve()
        monitor.sleep = wait
        with patch.object(guard, "diagnostic_custody_registry", side_effect=read_registry):
            monitor.custody_hold()
        self.assertEqual(len(reads), 4)  # UNKNOWN publication plus three paced resolution checks.
        self.assertEqual(len(waits), 3)
        self.assertTrue(all(seconds == 0.1 for _, seconds in waits))
        self.assertTrue(all(later - earlier >= 0.1 - 1e-9 for earlier, later in zip(reads[1:], reads[2:])))
        for lease in cap.leases:
            lease.verify()
        self.assertEqual(world.actions, [])
        receipt = json.loads((self.attempt / "diagnostic.json").read_text())
        self.assertEqual(receipt["post_deadline"], {"rss": "UNKNOWN", "identity": "UNKNOWN"})
        self.assertEqual(receipt["status"], "INCOMPLETE/UNKNOWN")
        self.assertEqual(cap.phase, "custody-only")
        guard.require_diagnostic_custody_clear()

    def test_missing_registry_hold_retries_are_paced_with_leases_retained(self):
        self._assert_paced_hold("missing")

    def test_malformed_registry_hold_retries_are_paced_with_leases_retained(self):
        self._assert_paced_hold("malformed")

    def test_stale_resolution_hold_retries_are_paced_with_leases_retained(self):
        self._assert_paced_hold("stale-resolution")


class StreamTests(Fixture):
    def test_nonblocking_fair_drain_combined_cap_and_original_bytes(self):
        child = object.__new__(shards._VmmapChild)
        child.role, child.clock, child.deadline = "vmmap", self.clock, 30
        child.total, child.limit = 0, 20000
        child.streams, child.open_streams = {"stdout": 101, "stderr": 102}, {"stdout", "stderr"}
        child.output = {"stdout": io.BytesIO(), "stderr": io.BytesIO()}
        reads = []
        def read(fd, size):
            reads.append((fd, size))
            return bytes([fd]) * size
        with patch.object(shards.select, "select", return_value=([101, 102], [], [])), patch.object(shards.os, "read", side_effect=read):
            with self.assertRaisesRegex(ValueError, "combined output cap"):
                child.drain()
        self.assertEqual({fd for fd, _ in reads}, {101, 102})
        self.assertTrue(all(size == 16384 for _, size in reads))
        self.assertEqual(sum(len(stream.getvalue()) for stream in child.output.values()), 20000)
        self.clock.now = 30
        with patch.object(shards.select, "select", side_effect=AssertionError("postdeadline select")):
            child.drain()
        child.code = None
        child.process = type("Process", (), {"poll": lambda self: (_ for _ in ()).throw(AssertionError("postdeadline poll"))})()
        self.assertIsNone(child.poll())

    def test_reaped_root_does_not_hide_unregistered_reparented_session_child(self):
        root = row(100, 1, role="controller")
        owners = shards._VmmapOwners(identity(root))
        child = type("Child", (), dict(pid=200, role="worker", argv=["/fake/200"], code=0))()
        owners.spawned(child)
        with self.assertRaisesRegex(ValueError, "session member"):
            owners.observe({100: root, 201: row(201, 1, 200)})


class OrdinaryTests(Fixture):
    def test_ordinary_workflow_admission_never_reacquires_parent_controller(self):
        policy = {"recoverable_activation": {"workflow_sha256": SHA, "manifest_sha256": SHA}}
        environment = {"GITHUB_JOB": "address_shards"}
        enabled = type("Guard", (), {"PHYSICAL_EXECUTION_ENABLED": True})()
        with patch.object(provision, "recoverable_control", side_effect=AssertionError("job controller deadlock")), \
                patch.object(guard, "require_recoverable_session"), patch.object(guard, "require_recoverable_identity"), \
                patch.object(guard, "load_recoverable_guard", return_value=enabled), \
                patch.object(guard, "require_recoverable_host", return_value=self.root):
            self.assertEqual(guard.admit_recoverable(policy, environment, {}), self.root)

    def test_selected_existing_fake_default_reuse_and_runtime_identity_cases(self):
        from test_recoverable_shards import CheckpointTests
        for name in ("test_success_reuses_with_explicit_tested_and_current_heads",
                     "test_failed_only_resume_keeps_independent_completed_shard",
                     "test_all_runtime_dimensions_and_selection_invalidate_reuse"):
            case = CheckpointTests(name)
            result = unittest.TestResult()
            case.run(result)
            self.assertTrue(result.wasSuccessful(), result.failures + result.errors)


class ProvisioningTests(Fixture):
    def setUp(self):
        super().setUp()
        self.home = self.root / "operator"
        self.home.mkdir(mode=0o700)
        cache = self.home / "sanitizer-checkpoints"
        cache.mkdir(mode=0o700)
        (cache / "executor.lock").touch(mode=0o600)
        self.stack.enter_context(patch.object(provision, "HOME_ROOT", self.home))
        self.stack.enter_context(patch.object(provision, "RUNNER", self.home / "native-runner"))

    def test_default_and_nested_prepare_first_action_has_both_leases(self):
        calls = []
        def install(*args):
            custody = provision._require_provisioning(executor=True)
            calls.append(custody)
            return self.root / "policy.json"
        with patch.object(provision, "_prepare_locked", side_effect=install):
            provision.prepare(HEAD, self.root / "archive", SHA)
            with provision.recoverable_control() as lock, provision.quiescent_legacy():
                provision.prepare(HEAD, self.root / "archive", SHA)
                self.assertIs(calls[-1].lock, lock)
        self.assertEqual(len(calls), 2)
        with self.assertRaises(ValueError):
            provision._require_provisioning()

    def test_registration_and_listener_release_executor_retain_controller(self):
        observed = []
        def run(argv, **kwargs):
            custody = provision._require_provisioning(executor=Path(argv[0]).name != "run.sh")
            observed.append((Path(argv[0]).name, custody.executor is not None, custody.controller.active))
            return type("Result", (), dict(returncode=0, stdout='{"token":"fixture-not-a-secret"}'))()
        with patch.dict(os.environ, {"GITHUB_TOKEN": "fixture-only"}), patch.object(provision.subprocess, "run", side_effect=run):
            provision.register_and_run(True)
        self.assertEqual(observed, [("gh", True, True), ("config.sh", True, True), ("run.sh", False, True)])

    def test_listener_job_cannot_acquire_controller_or_use_forged_flag(self):
        with patch.dict(os.environ, {"GITHUB_JOB": "local-run"}):
            with self.assertRaisesRegex(ValueError, "ineligible"):
                provision.prepare(HEAD, self.root / "archive", SHA)
        with self.assertRaises(ValueError):
            provision.prepare(HEAD, self.root / "archive", SHA, registered=True)
        with provision.recoverable_control():
            with self.assertRaises(ValueError):
                provision.renew_recoverable(None, None, None, None, None, False, False, object())
        with self.assertRaises(ValueError):
            provision._ProvisioningCustody(None, None, object())

    def test_unresolved_and_missing_refuse_default_registration_and_renewal(self):
        self.capability()
        for call in (lambda: provision.prepare(HEAD, self.root / "archive", SHA),
                     lambda: provision.register_and_run(True),
                     lambda: provision.renew_recoverable(None, None, None, None, None, False, False)):
            with self.assertRaises(ValueError):
                call()
        (self.custody / "registry.json").unlink()
        with self.assertRaises(OSError):
            provision.register_and_run(True)


    def test_renewal_consumes_one_exact_slot_and_listener_receives_no_executor(self):
        policy = {"approved_head": HEAD, "recoverable_activation": {"expires_at": 150, "runners": {"fixture-runner": {}}},
                  "recoverable_shards": {"legacy_cache": str(self.home / "sanitizer-checkpoints")}}
        path = self.home / "policy.json"
        write_json(path, policy, immutable=True)
        runner = provision.RUNNER
        runner.mkdir(mode=0o700)
        calls = []
        def active(policy, binding):
            provision._require_provisioning(executor=True)
            calls.append("metadata")
            return calls.count("metadata") == 1
        def run(argv, **kwargs):
            provision._require_provisioning(executor=True)
            if Path(argv[0]).name == "config.sh":
                write_json(runner / ".runner", dict(agentName="fixture-runner", gitHubUrl="https://github.com/stephenlclarke/elite", workFolder="_work"))
            return type("Result", (), dict(returncode=0, stdout='{"token":"fixture"}'))()
        def listener(argv, **kwargs):
            custody = provision._require_provisioning()
            self.assertIsNone(custody.executor)
            self.assertEqual(kwargs["pass_fds"], (custody.lock.fileno(),))
            (runner / ".runner").unlink()
            return type("Listener", (), {"wait": lambda self, timeout: 0})()
        with patch.object(provision.time, "time", return_value=100), \
                patch.object(provision, "session_run_active", side_effect=active), \
                patch.object(provision.subprocess, "run", side_effect=run), \
                patch.object(provision.subprocess, "Popen", side_effect=listener):
            result = provision.renew_recoverable(path, "123", "1", 1, 140, True, True)
        self.assertEqual(result, {"used": 1, "reason": "workflow completed"})
        state = next((self.home / "recoverable-sessions").glob("*.state"))
        self.assertEqual(json.loads(state.read_text()), {"used": 1, "phase": "idle"})
        with patch.object(provision.time, "time", return_value=140), self.assertRaises(ValueError):
            provision.renew_recoverable(path, "123", "1", 1, 140, True, True)


if __name__ == "__main__":
    unittest.main()
