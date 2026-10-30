"""Fake-only fault injection. No Swift, native runner, game or sanitizer is launched."""

from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import textwrap
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

import recoverable_shards as shards

HEAD = "a" * 40
ADMISSION = dict(explicit=2, cpu_budget=2, ram_available=20, ram_reserve=4,
                 peak_per_worker=6, disk_available=100, disk_reserve=20, disk_per_worker=20,
                 ram_capacity=20, disk_capacity=100)
METHODS = ["L337CoreTests.A/one()", "L337CoreTests.A/two()", "L337CoreTests.B/three()"]


def xml(path, methods, skips=None):
    root = ET.Element("testsuites")
    suite = ET.SubElement(root, "testsuite", tests=str(len(methods)), failures="0", errors="0")
    for method in methods:
        classname, name = shards.legacy.xml_identity(method)
        case = ET.SubElement(suite, "testcase", classname=classname, name=name, time="1")
        if (classname, name) in (skips or {}):
            ET.SubElement(case, "skipped").text = skips[(classname, name)]
    ET.ElementTree(root).write(path)


class FakeExecutor:
    def __init__(self, workspace, runtimes):
        self.workspace, self.runtimes = workspace, runtimes
        self.calls, self.unknown, self.exited = 0, False, True
        self.exit_code, self.damage, self.pause = 0, None, None
        self.current = None

    def verify(self, runtime):
        if runtime != self.runtimes[runtime["mode"]]:
            raise ValueError("Actual fake source/host/toolchain/image/env changed")
        self.current = runtime

    def unknown_live_helpers(self):
        return self.unknown

    def proven_exited(self, attempt):
        return self.exited

    def reclaimable(self, reservation):
        return self.exited and not self.unknown

    def owner_identity(self):
        return {"pid": os.getpid(), "start": "fake-process-start", "image": "fake-python"}

    def phase_origin(self, attempt, identity):
        return dict(schema=1, host=self.current["host"], phase=identity["phase"], tested_head=HEAD,
                    receipt_sha256=shards.legacy.digest(attempt / "result.json"), exit_code=0, authorization=None)

    def execute(self, shard, attempt, timeout, descriptors):
        self.calls += 1
        shards.child_environment(attempt, {"LANG": "C"})
        shards.durable_json(attempt / "child.json", {"pid": 4242, "command": ["fake"], "started": 1})
        for descriptor in descriptors:
            os.fstat(descriptor)
        xml(attempt / "tests.xml", shard["methods"],
            shards.legacy.selected_opt_in_skips(self.current, shard["methods"]))
        (attempt / "test.log").write_text("fake completed\n")
        (attempt / "profiles" / "fake.profraw").write_bytes(b"fake profile")
        if self.damage:
            self.damage(attempt)
        if self.pause:
            self.pause()
        shards.durable_json(attempt / "child-exit.json", {"pid": 4242, "exit_code": self.exit_code})
        return self.exit_code


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.addCleanup(self.cleanup)
        # Fake contracts must never consult the operator's physical custody state.
        from test_native_runner import owned_control_fixture
        home = self.root / 'physical-home'
        owned_control_fixture(home / 'Library/EliteNativeCI')
        physical_home = patch('pwd.getpwuid', return_value=SimpleNamespace(pw_dir=str(home)))
        physical_home.start()
        self.addCleanup(physical_home.stop)
        self.image = self.root / "fake-image"
        self.image.write_bytes(b"fake executable bytes")
        self.runtimes = {mode: dict(
            schema=1, mode=mode, inputs={"Sources/Game.swift": "1" * 64}, toolchain="fake Swift 6",
            sdk=shards.fingerprint({"version": "fake-sdk", "path": "/fake/sdk"}), host="fake-host-A",
            os=shards.fingerprint({"release": "fake-os", "version": "fake-version"}),
            architecture="fake-arm64", image_sha256=shards.legacy.digest(self.image),
            image_uuid="fake-image-uuid", environment=shards.legacy.runtime_identity({"LANG": "C"}),
            phase_environment=shards.legacy.runtime_identity({"LANG": "C"}),
            flags=["--sanitize=" + mode], policy=shards.POLICY, opt_in_policy={})
            for mode in shards.MODES}
        self.store = shards.Store(self.root / "durable-cache")
        self.executor = FakeExecutor(self.root / "worker-1", self.runtimes)
        self.plan = shards.make_plan(self.runtimes["thread"], METHODS)

    def cleanup(self):
        for directory, names, files in os.walk(self.root):
            Path(directory).chmod(0o700)
            for name in files:
                file = Path(directory) / name
                if not file.is_symlink():
                    file.chmod(0o600)
        self.temp.cleanup()

    def run_one(self, plan=None, executor=None, fault=lambda stage: None):
        plan = plan or self.plan
        return shards.run_shard(plan, plan["shards"][0]["id"], self.store,
                                executor or self.executor, HEAD, 5, ADMISSION, fault)

    def identity(self, plan=None):
        plan = plan or self.plan
        return shards.shard_identity(plan["runtime"], plan["shards"][0])

    def change(self, path, value):
        path.chmod(0o600)
        path.write_text(value)


class PlanningTests(Fixture):
    def test_custody_fixture_is_private_empty_and_outside_operator_home(self):
        import native_runner
        root = native_runner.diagnostic_custody_root()
        self.assertTrue(root.is_relative_to(self.root))
        self.assertEqual(root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(native_runner.diagnostic_custody_registry()['records'], {})
        native_runner.require_diagnostic_custody_clear()

    def test_missing_fake_registry_still_refuses_execution(self):
        import native_runner
        (native_runner.diagnostic_custody_root() / 'registry.json').unlink()
        with self.assertRaises((ValueError, OSError)):
            native_runner.require_diagnostic_custody_clear()


    def test_longest_first_atomic_duration_packing_and_stable_identity(self):
        units = shards.legacy.partition(METHODS, "thread", 1)
        weights = {shards.fingerprint(unit): seconds for unit, seconds in zip(units, (5100, 70))}
        first = shards.make_plan(self.runtimes["thread"], METHODS, history=weights)
        self.assertEqual([row["estimated_seconds"] for row in first["shards"]], [5100, 70])
        self.assertTrue(first["shards"][0]["oversized"])
        self.assertEqual(first["shards"][0]["methods"], METHODS[:2])
        extra = "L337CoreTests.Z/four()"
        second = shards.make_plan(self.runtimes["thread"], [extra, *reversed(METHODS)],
                                  history={**weights, shards.fingerprint([extra]): 700}, budget=300)
        self.assertIn(first["shards"][0]["id"], [row["id"] for row in second["shards"]])
        self.assertEqual(shards.make_plan(self.runtimes["thread"], METHODS), self.plan)

    def test_real_audited_groups_remain_whole_in_both_modes(self):
        root = Path(__file__).resolve().parents[2]
        manifest = shards.load_json(root / "Tools/CI/sanitizer_groups.json")
        self.assertEqual([(len(group["members"]), len(group["sources"]))
                          for group in manifest["groups"]], [(173, 33), (13, 2)])
        methods = []
        for group in manifest["groups"]:
            for member in group["members"]:
                classname, method = member.split("/", 1)
                module, *components = classname.split(".")
                methods.append(module + "." + "/".join([*components, method]))
        methods.sort()
        policy = shards.legacy.grouping_policy(root, methods, "thread", 1)
        for mode in shards.MODES:
            plan = shards.make_plan(self.runtimes[mode], methods, policy["shared_groups"])
            for group in policy["shared_groups"]:
                self.assertEqual(sum(set(group) <= set(row["methods"]) for row in plan["shards"]), 1)
        thread = shards.legacy.batch_command("fake-swift", [], "thread", self.root, METHODS)
        address = shards.legacy.batch_command("fake-swift", [], "address", self.root, METHODS)
        self.assertNotIn("--no-parallel", thread)
        self.assertIn("--no-parallel", address)

    def test_resource_audit_requires_matching_sources_and_is_not_implied_by_grouping(self):
        self.assertFalse(self.plan["shards"][0]["audited"])
        resources = {shards.fingerprint(unit): {"sources": self.runtimes["thread"]["inputs"],
                                               "claims": ["default-save"], "reviewed": True}
                     for unit in shards.legacy.partition(METHODS, "thread", 1)}
        plan = shards.make_plan(self.runtimes["thread"], METHODS, resources=resources)
        self.assertTrue(plan["shards"][0]["audited"])
        self.assertEqual(plan["shards"][0]["claims"], ["default-save"])
        resources[next(iter(resources))]["sources"] = {"Sources/Game.swift": "3" * 64}
        with self.assertRaises(ValueError):
            shards.make_plan(self.runtimes["thread"], METHODS, resources=resources)

    def test_invalid_inventory_metadata_and_old_protocol_are_rejected(self):
        for mutate in (lambda plan: plan.update(schema=3), lambda plan: plan.update(budget_seconds=0),
                       lambda plan: plan["inventory"].append(METHODS[0]),
                       lambda plan: plan["shards"][0].update(oversized=True),
                       lambda plan: plan["shards"][0]["methods"].pop()):
            plan = deepcopy(self.plan)
            mutate(plan)
            with self.assertRaises(ValueError):
                shards.validate_plan(plan)
        with self.assertRaises(ValueError):
            shards.make_plan(self.runtimes["thread"], METHODS * 2)

    def test_build_is_frozen_once_and_existing_manifest_cannot_be_overwritten(self):
        calls = []
        class Builder:
            def preparation_claim(inner):
                return shards.claim(self.root / "prepare-claims", "exclusive-build")

            def build_and_discover(inner, mode):
                calls.append(mode)
                return self.runtimes[mode], METHODS, [], self.image, HEAD
        destination = self.root / "frozen"
        shards.freeze_build("thread", Builder(), destination)
        with self.assertRaises(ValueError):
            shards.freeze_build("thread", Builder(), destination)
        self.assertEqual(calls, ["thread"])
        self.assertFalse((destination / "build.json").stat().st_mode & 0o222)

    def test_plan_cli_round_trips_the_exact_frozen_selection(self):
        source, destination = self.root / "request.json", self.root / "plan.json"
        shards.durable_json(source, {"runtime": self.runtimes["thread"], "inventory": METHODS})
        subprocess.run([sys.executable, str(Path(shards.__file__)), "plan", "--input", str(source),
                        "--output", str(destination)], check=True)
        self.assertEqual(shards.load_json(destination), self.plan)


class CheckpointTests(Fixture):
    def test_failed_only_resume_keeps_independent_completed_shard(self):
        weights = {shards.fingerprint(unit): 700
                   for unit in shards.legacy.partition(METHODS, "thread", 1)}
        plan = shards.make_plan(self.runtimes["thread"], METHODS, history=weights)
        first, second = plan["shards"]
        shards.run_shard(plan, first["id"], self.store, self.executor, HEAD, 5, ADMISSION)
        self.executor.exit_code = 1
        with self.assertRaises(ValueError):
            shards.run_shard(plan, second["id"], self.store, self.executor, HEAD, 5, ADMISSION)
        self.executor.exit_code = 0
        before = self.executor.calls
        outcome = shards.run_pending([plan], self.store, [self.executor], HEAD, 5, ADMISSION)
        self.assertEqual(self.executor.calls - before, 1)
        self.assertEqual(sorted(row["reused"] for row in outcome), [False, True])

    def test_exact_declared_skip_is_required_and_an_enabled_or_wrong_skip_fails(self):
        runtime = self.runtimes["thread"]
        classname, name = shards.legacy.xml_identity(METHODS[0])
        runtime["opt_in_policy"] = {"expected_skips": [dict(classname=classname, name=name, reason="declared")]}
        plan = shards.make_plan(runtime, METHODS)
        self.run_one(plan)
        for index, skip in enumerate(({}, {(classname, name): "other"})):
            self.store = shards.Store(self.root / ("skip-" + str(index)))
            self.executor.damage = lambda attempt: xml(attempt / "tests.xml", METHODS, skip)
            with self.assertRaises(ValueError):
                self.run_one(plan)

    def test_success_reuses_with_explicit_tested_and_current_heads(self):
        first = self.run_one()
        second = shards.run_shard(self.plan, self.plan["shards"][0]["id"], self.store,
                                  self.executor, "b" * 40, 5, ADMISSION)
        self.assertFalse(first["reused"])
        self.assertTrue(second["reused"])
        self.assertEqual(second["tested_head"], HEAD)
        self.assertEqual(second["current_head"], "b" * 40)
        self.assertEqual(self.executor.calls, 1)

    def test_interruptions_retry_only_uncommitted_attempts_and_rebuild_index(self):
        for stage in ("before-execution", "after-exit", "before-receipt", "after-receipt", "before-upload"):
            with self.subTest(stage=stage):
                self.store = shards.Store(self.root / stage)
                before = self.executor.calls
                def stop(current):
                    if current == stage:
                        raise RuntimeError("fake controller loss")
                with self.assertRaises(RuntimeError):
                    self.run_one(fault=stop)
                outcome = self.run_one()
                committed = stage in ("after-receipt", "before-upload")
                self.assertEqual(outcome["reused"], committed)
                self.assertEqual(self.executor.calls - before,
                                 1 if committed or stage == "before-execution" else 2)
                self.assertIn(self.identity_hash(), shards.load_json(self.store.root / "index.json")["entries"])

    def identity_hash(self):
        return shards.fingerprint(self.identity())

    def test_full_xml_with_nonzero_exit_truncation_diagnostics_or_unexpected_skip_never_passes(self):
        damages = [lambda attempt: (attempt / "tests.xml").write_text("<testsuites>"),
                   lambda attempt: (attempt / "test.log").write_text("WARNING: ThreadSanitizer: race"),
                   lambda attempt: xml(attempt / "tests.xml", METHODS[:1]),
                   lambda attempt: xml(attempt / "tests.xml", METHODS,
                                       {shards.legacy.xml_identity(METHODS[0]): None})]
        for index, damage in enumerate([None, *damages]):
            self.store = shards.Store(self.root / ("invalid-" + str(index)))
            self.executor.exit_code, self.executor.damage = (9 if damage is None else 0), damage
            with self.assertRaises((ValueError, ET.ParseError)):
                self.run_one()
            self.assertIsNone(self.store.matching(self.identity()))
            self.executor.exit_code, self.executor.damage = 0, None
            self.assertFalse(self.run_one()["reused"])
            self.assertEqual(len(list((self.store.root / "attempts" / self.identity_hash()).iterdir())), 2)

    def test_all_runtime_dimensions_and_selection_invalidate_reuse(self):
        self.run_one()
        for key, value in (("host", "host-B"), ("toolchain", "Swift-other"), ("sdk", "sdk-other"),
                           ("image_sha256", "f" * 64), ("image_uuid", "other-uuid"),
                           ("inputs", {"Sources/Game.swift": "4" * 64}),
                           ("environment", {"LANG": "5" * 64}), ("policy", "other-policy")):
            runtime = {**self.runtimes["thread"], key: value}
            if key == "policy":
                with self.assertRaises(ValueError):
                    shards.make_plan(runtime, METHODS)
            else:
                plan = shards.make_plan(runtime, METHODS)
                self.assertIsNone(self.store.matching(self.identity(plan)))
                with self.assertRaises(ValueError):
                    self.run_one(plan)
        changed = shards.make_plan(self.runtimes["thread"], METHODS[:2])
        self.assertIsNone(self.store.matching(self.identity(changed)))

    def test_tampered_receipt_log_xml_profile_permissions_links_and_paths_are_rejected(self):
        for name in ("result.json", "test.log", "tests.xml", "profiles/fake.profraw", "commit.json"):
            with self.subTest(name=name):
                self.store = shards.Store(self.root / ("tamper-" + name.replace("/", "-")))
                attempt = Path(self.run_one()["attempt"])
                self.change(attempt / name, "tampered")
                self.assertIsNone(self.store.matching(self.identity()))
        self.store = shards.Store(self.root / "link")
        attempt = Path(self.run_one()["attempt"])
        attempt.chmod(0o700)
        (attempt / "test.log").unlink()
        (attempt / "test.log").symlink_to(self.image)
        self.assertIsNone(self.store.matching(self.identity()))

    def test_trusted_artifact_restore_runs_zero_times_and_rejects_index_tampering(self):
        self.run_one()
        artifact = self.root / "artifact"
        checksum = self.store.export(self.identity(), artifact)
        restored = shards.Store(self.root / "other-owned-host-cache")
        restored.restore_artifact(artifact, checksum, self.identity())
        self.store = restored
        before = self.executor.calls
        self.assertTrue(self.run_one()["reused"])
        self.assertEqual(self.executor.calls, before)
        self.change(artifact / "index.json", "{}")
        with self.assertRaises(ValueError):
            restored.restore_artifact(artifact, checksum, self.identity())
        with self.assertRaises(ValueError):
            restored.restore_artifact(artifact, "0" * 64, self.identity())

    def test_artifact_rejects_path_escape_extra_files_and_writable_permissions(self):
        self.run_one()
        for kind in ("path", "extra", "permissions"):
            artifact = self.root / ("artifact-" + kind)
            checksum = self.store.export(self.identity(), artifact)
            artifact.chmod(0o700)
            if kind == "path":
                index = shards.load_json(artifact / "index.json")
                index["attempt"] = "../outside"
                self.change(artifact / "index.json", json.dumps(index))
                checksum = shards.legacy.digest(artifact / "index.json")
            elif kind == "extra":
                (artifact / "extra").write_text("unaccounted")
            else:
                (artifact / "attempt" / "test.log").chmod(0o666)
            with self.assertRaises(ValueError):
                shards.Store(self.root / ("restore-" + kind)).restore_artifact(artifact, checksum, self.identity())


class AdmissionTests(Fixture):
    def test_static_slot_namespace_and_conservative_pending_running_headroom(self):
        first = {**ADMISSION, "ram_available": 16}
        second = FakeExecutor(self.root / "worker-2", self.runtimes)
        with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], first, 5) as one:
            with shards.reserve_worker(self.store, second, self.runtimes["address"], first, 5) as two:
                self.assertNotEqual(one["path"], two["path"])
                self.assertEqual(shards.load_json(two["path"])["state"], "pending")
            # Free memory has fallen; reserve full future headroom instead of assuming current RSS is peak.
            with self.assertRaises(ValueError):
                with shards.reserve_worker(self.store, second, self.runtimes["address"],
                                           {**first, "ram_available": 10}, 5):
                    pass
        growing = {**ADMISSION, "ram_capacity": 32, "ram_available": 32, "peak_per_worker": 12}
        self.store = shards.Store(self.root / "growing-worker")
        with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], growing, 5):
            with self.assertRaises(ValueError):
                with shards.reserve_worker(self.store, second, self.runtimes["address"],
                                           {**growing, "ram_available": 22}, 5):
                    pass
            with shards.reserve_worker(self.store, second, self.runtimes["address"],
                                       {**growing, "ram_available": 28}, 5):
                pass

    def test_unknown_startup_claim_blocks_replacement_until_proven_exit_and_nonce_cas(self):
        budget = {**ADMISSION, "explicit": 1}
        attempt = self.root / "failed-launch"
        attempt.mkdir(mode=0o700)
        self.executor.exited = False
        with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], budget, 5) as old:
            shards.reservation_update(self.store, old, attempt=str(attempt), state="launching")
        self.assertEqual(shards.load_json(old["path"])["state"], "unknown")
        with self.assertRaises(ValueError):
            with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], budget, 5):
                pass
        self.executor.exited = True
        with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], budget, 5) as new:
            self.assertNotEqual(new["nonce"], old["nonce"])
            with self.assertRaises(ValueError):
                shards.reservation_update(self.store, old, state="released")

    def test_fresh_resource_observation_occurs_under_atomic_host_admission_lock(self):
        def observe():
            with self.assertRaises(BlockingIOError), shards.claim(self.store.root / "claims", "admission"):
                pass
            return ADMISSION
        self.executor.observe_admission = observe
        with shards.reserve_worker(self.store, self.executor, self.runtimes["thread"], ADMISSION, 5):
            pass

    def test_unequal_mode_peaks_and_reserve_disk_host_policy_changes_are_rejected(self):
        budget = {**ADMISSION, "ram_available": 16, "ram_reserve": 4, "peak_per_worker": 10}
        plan = self.audited("thread", claim=None)
        other = self.audited("address", claim=None)
        entered, release = threading.Event(), threading.Event()
        self.executor.pause = lambda: (entered.set(), release.wait(3))
        second = FakeExecutor(self.root / "worker-2", self.runtimes)
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(shards.run_shard, plan, plan["shards"][0]["id"], self.store,
                                 self.executor, HEAD, 5, budget)
            self.assertTrue(entered.wait(2))
            try:
                for difference in ({"peak_per_worker": 6}, {"ram_reserve": 2},
                                   {"disk_reserve": 10}, {"disk_per_worker": 10}, {"cpu_budget": 1}):
                    with self.assertRaisesRegex(ValueError, "policy changed"):
                        shards.run_shard(other, other["shards"][0]["id"], self.store, second,
                                         HEAD, 5, {**budget, **difference})
            finally:
                release.set()
            future.result()
        self.assertEqual(second.calls, 0)
        changed = deepcopy(other)
        changed["runtime"]["host"] = "host-B"
        second.runtimes = {**self.runtimes, "address": changed["runtime"]}
        changed = shards.make_plan(changed["runtime"], METHODS)
        with self.assertRaisesRegex(ValueError, "policy changed"):
            shards.run_shard(changed, changed["shards"][0]["id"], self.store, second, HEAD, 5, budget)

    def audited(self, mode, methods=METHODS, claim="shared-save"):
        resources = {shards.fingerprint(unit): {"sources": self.runtimes[mode]["inputs"],
                                               "claims": [claim] if claim else [], "reviewed": True}
                     for unit in shards.legacy.partition(methods, mode, 1)}
        return shards.make_plan(self.runtimes[mode], methods, resources=resources)

    def test_ram_cpu_disk_caps_and_cross_mode_pool_are_bounded(self):
        self.assertEqual(shards.worker_limit(**ADMISSION), 2)
        self.assertEqual(shards.worker_limit(**{**ADMISSION, "cpu_budget": 1}), 1)
        self.assertEqual(shards.worker_limit(**{**ADMISSION, "ram_available": 10}), 1)
        for change in ({"disk_available": 25}, {"ram_available": 5}, {"explicit": 3}):
            with self.assertRaises(ValueError):
                shards.worker_limit(**{**ADMISSION, **change})
        second = FakeExecutor(self.root / "worker-2", self.runtimes)
        plans = [self.audited(mode, claim=None) for mode in shards.MODES]
        outcomes = shards.run_pending(plans, self.store, [self.executor, second], HEAD, 5, ADMISSION)
        self.assertEqual(len(outcomes), 2)
        self.assertFalse(any("failed" in outcome for outcome in outcomes), outcomes)
        with self.assertRaises(ValueError):
            shards.run_pending(plans, self.store, [self.executor, second], HEAD, 5,
                               {**ADMISSION, "cpu_budget": 1})

    def test_duplicate_shard_workspace_unknown_helper_and_live_incomplete_owner_block(self):
        for key in ("shard:" + self.plan["shards"][0]["id"], "workspace:" + str(self.executor.workspace)):
            with shards.claim(self.store.root / "claims", key), self.assertRaises(BlockingIOError):
                self.run_one()
        self.executor.unknown = True
        with self.assertRaises(ValueError):
            self.run_one()
        self.executor.unknown = False
        with self.assertRaises(RuntimeError):
            self.run_one(fault=lambda stage: (_ for _ in ()).throw(RuntimeError())
                         if stage == "before-execution" else None)
        self.executor.exited = False
        with self.assertRaises(ValueError):
            self.run_one()
        self.assertEqual(self.executor.calls, 0)
        self.executor.exited = True
        self.run_one()

    def test_unknown_groups_and_shared_external_resources_serialize(self):
        for first_plan, second_plan in ((self.plan, self.audited("address", claim=None)),
                                        (self.audited("thread"), self.audited("address"))):
            self.store = shards.Store(self.root / str(time.monotonic_ns()))
            entered, release, second_entered = threading.Event(), threading.Event(), threading.Event()
            self.executor.pause = lambda: (entered.set(), release.wait(3))
            second = FakeExecutor(self.root / "worker-2", self.runtimes)
            second.pause = second_entered.set
            with ThreadPoolExecutor(max_workers=2) as pool:
                one = pool.submit(self.run_one, first_plan)
                self.assertTrue(entered.wait(2))
                two = pool.submit(self.run_one, second_plan, second)
                self.assertFalse(second_entered.wait(0.1))
                release.set()
                one.result()
                two.result()
            self.assertTrue(second_entered.is_set())

    def test_same_host_slots_are_shared_across_modes_and_controllers(self):
        plan = self.audited("thread", claim=None)
        other = self.audited("address", claim=None)
        second = FakeExecutor(self.root / "worker-2", self.runtimes)
        with shards.claim(self.store.root / "claims", "worker:0"), shards.claim(
                self.store.root / "claims", "worker:1"):
            with self.assertRaisesRegex(ValueError, "slots"):
                self.run_one(plan)
            with self.assertRaisesRegex(ValueError, "slots"):
                self.run_one(other, second)
        self.assertEqual(self.executor.calls + second.calls, 0)


class PhaseTests(Fixture):
    def test_guard_or_policy_transition_never_relabels_previous_normal_proof(self):
        bundle, checksum = self.full_phase("normal")
        runtime = deepcopy(self.runtimes["thread"])
        runtime["inputs"]["Tools/CI/native_runner.py"] = "f" * 64
        with self.assertRaises(ValueError):
            shards.validate_phase(bundle, checksum, "normal", runtime, METHODS)
        runtime = deepcopy(self.runtimes["thread"])
        runtime["phase_environment"]["ELITE_RECOVERABLE_POLICY_SHA256"] = "e" * 64
        with self.assertRaises(ValueError):
            shards.validate_phase(bundle, checksum, "normal", runtime, METHODS)

    def full_phase(self, phase):
        runtime = self.runtimes["thread"]
        identity = dict(phase=phase, inputs=runtime["inputs"], swift=runtime["toolchain"],
                        sdk="fake-sdk", sdk_path="/fake/sdk", architecture=runtime["architecture"],
                        os_version={"release": "fake-os", "version": "fake-version"},
                        image_sha256=shards.legacy.digest(self.image),
                        image_uuid="UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (fake-arm64) /fake/image",
                        environment=runtime["environment"], inventory=METHODS if phase == "normal" else [],
                        opt_in_policy={}, flags=["--enable-code-coverage"] if phase == "normal" else [],
                        parallel=phase == "normal", policy="normal-coverage-80-v1" if phase == "normal"
                        else "leaks-at-exit-diagnostics-v1")
        attempt = self.root / phase
        attempt.mkdir(mode=0o700)
        (attempt / "phase.log").write_text("fake normal done" if phase == "normal"
                                           else "0 leaks for 0 total leaked bytes")
        if phase == "normal":
            xml(attempt / "tests-swift-testing.xml", METHODS)
            (attempt / "coverage.xml").write_text(
                '<coverage><file path="Sources/Game.swift">'
                + '<lineToCover covered="true"/>' * 4 + '<lineToCover covered="false"/>'
                + '</file></coverage>')
            (attempt / "coverage.lcov").write_text("fake lcov")
            (attempt / "default.profdata").write_text("fake merged profile")
        result = dict(identity=identity, status="passed", tested_head=HEAD, exit_code=0, native_exit_code=0,
                      outputs={name: shards.legacy.digest(attempt / name)
                               for name in shards.phases.phase_outputs(attempt, phase)},
                      validation=shards.phases.validate_outputs(attempt, identity))
        shards.durable_json(attempt / "result.json", result)
        bundle = self.root / (phase + "-proof")
        checksum = shards.freeze_phase(attempt, identity, runtime, METHODS, self.executor, bundle)
        return bundle, checksum

    def test_aggregate_requires_both_exact_modes_full_normal_coverage_and_zero_leaks(self):
        plans = [shards.make_plan(self.runtimes[mode], METHODS) for mode in shards.MODES]
        normal, normal_sha = self.full_phase("normal")
        leaks, leaks_sha = self.full_phase("leaks")
        for plan in plans:
            self.run_one(plan)
        outcome = shards.aggregate(plans, self.store, normal, normal_sha, leaks, leaks_sha)
        self.assertEqual(outcome["status"], "passed")
        with self.assertRaises(ValueError):
            shards.aggregate(plans[:1], self.store, normal, normal_sha, leaks, leaks_sha)
        with self.assertRaises(ValueError):
            shards.aggregate(plans, shards.Store(self.root / "empty"), normal, normal_sha, leaks, leaks_sha)
        self.change(leaks / "attempt" / "phase.log", "1 leak for 64 total leaked bytes")
        with self.assertRaises(ValueError):
            shards.aggregate(plans, self.store, normal, normal_sha, leaks, leaks_sha)

    def test_phase_cross_host_source_env_policy_inventory_and_coverage_tamper_are_rejected(self):
        normal, checksum = self.full_phase("normal")
        for key, value in (("host", "other-host"), ("inputs", {"Sources/Game.swift": "f" * 64}),
                           ("phase_environment", {}), ("toolchain", "other-swift")):
            with self.assertRaises(ValueError):
                shards.validate_phase(normal, checksum, "normal",
                                      {**self.runtimes["thread"], key: value}, METHODS)
        with self.assertRaises(ValueError):
            shards.validate_phase(normal, checksum, "normal", self.runtimes["thread"], METHODS[:1])
        self.change(normal / "attempt" / "coverage.xml", '<coverage/>')
        with self.assertRaises(ValueError):
            shards.validate_phase(normal, checksum, "normal", self.runtimes["thread"], METHODS)


class ProcessTests(Fixture):
    def progress_context(self, mode="address"):
        return {"mode": mode, "shard": "a" * 64, "selected_method_count": 2,
                "validated_shards_completed": 1, "shards_total": 3}

    def test_observed_fragmented_ansi_parameterized_and_parallel_events_are_not_proof(self):
        # Exact Swift Testing spelling from retained TSAN batch-0; Unicode is escaped in source.
        started = "\u25c7 Test celestialModeRendererEvidence() started.\n"
        parameterized = "\u25c7 Test cabinFittingIntentRefusesStalePausedWrongStationAndCapacityWithoutCharging() started.\n"
        for mode in shards.MODES:
            with self.subTest(mode=mode):
                attempt = self.root / (mode + "-observations")
                attempt.mkdir()
                now = [10.0]
                with (attempt / "test.log").open("wb") as raw, patch.object(shards.legacy, "progress"), shards.ObservedTestProgress(
                        attempt, raw, self.progress_context(mode), clock=lambda: now[0]) as capture:
                    # Split inside a multibyte glyph, an ANSI sequence and a test name.
                    data = ("\x1b[32m" + started.rstrip() + "\x1b[0m\n" + parameterized).encode()
                    for byte in data:
                        capture.feed(bytes([byte]))
                    capture.feed("\u25c7 Test expanded(argument: \"a b\") started.\n".encode())
                    self.assertEqual(len(capture.active), 3)
                    now[0] = 15.0
                    capture.feed("\u2718 Test expanded(argument: \"a b\") recorded an issue at File.swift:1:1\n".encode())
                    capture.feed("\u2718 Test expanded(argument: \"a b\") failed after 4.5 seconds with 1 issue.\n".encode())
                    capture.feed("\u2714 Test celestialModeRendererEvidence() passed after 0.387 seconds.\n".encode())
                    capture.feed("\u25c7 Test run started.\n".encode())
                    capture.feed(b"unfinished partial test line")
                    value = capture.publish("interrupted", force=True)
                    self.assertEqual(value["observed_counts"], dict(started=3, completed=2, failed=1, skipped=0, cancelled=0, issues=1))
                    self.assertEqual(value["observed_active"][0]["age_seconds"], 5)
                    self.assertTrue(value["partial_line"])
                    self.assertEqual(value["observed_active"][0]["name"], parameterized.split("Test ")[1].split(" started.")[0])
                    self.assertEqual((attempt / "test.log").read_bytes()[:len(data)], data)
                    self.assertFalse((attempt / "result.json").exists())
                events = [json.loads(line) for line in (attempt / "test-events.jsonl").read_text().splitlines()]
                self.assertEqual(events[-1]["reported_seconds"], 0.387)
                self.assertTrue(all(event["mode"] == mode for event in events))

    def test_same_display_names_remain_ambiguous_and_truncated_records_do_not_complete(self):
        attempt = self.root / "ambiguous-progress"
        attempt.mkdir()
        with (attempt / "test.log").open("wb") as raw, patch.object(shards.legacy, "progress"), shards.ObservedTestProgress(
                attempt, raw, self.progress_context()) as capture:
            capture.feed(("\u25c7 Test same(x:) started.\n" * 2).encode())
            capture.feed("\u2714 Test same(x:) passed after 1.0 seconds.\n".encode())
            self.assertEqual(len(capture.active), 2)
            capture.feed(b"x" * 70000)
            capture.feed("\u2714 Test bogus() passed after 1.0 seconds.\n".encode())
            self.assertEqual(capture.counts["completed"], 1)
            capture.publish("interrupted", force=True)
        events = [json.loads(line) for line in (attempt / "test-events.jsonl").read_text().splitlines()]
        self.assertTrue(events[-1]["ambiguous_same_name"])
        self.assertNotIn("observed_test_seconds", events[-1])

    def test_pty_drains_exact_bytes_and_silent_heartbeat_for_both_sanitizers(self):
        for mode in shards.MODES:
            with self.subTest(mode=mode):
                attempt = self.root / (mode + "-pty")
                attempt.mkdir()
                summary = self.root / (mode + "-summary")
                # Line-buffering is exercised in a fake Python child, not asserted for Swift.
                script = "import os,time; assert os.isatty(1); print('\\u25c7 Test quiet(x:) started.'); time.sleep(.25); print('\\u2714 Test quiet(x:) passed after 0.25 seconds.')"
                with patch.object(shards, "PROGRESS_HEARTBEAT_SECONDS", .05), patch.object(shards.legacy, "progress") as output, patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(summary)}):
                    code = shards.execute_process([sys.executable, "-c", script], self.root, attempt,
                        5, [], {"LANG": "C"}, isolate_environment=False, progress=self.progress_context(mode))
                self.assertEqual(code, 0)
                raw = (attempt / "test.log").read_bytes()
                self.assertEqual(raw, "\u25c7 Test quiet(x:) started.\n\u2714 Test quiet(x:) passed after 0.25 seconds.\n".encode())
                value = shards.load_json(attempt / "test-progress.json")
                self.assertEqual(value["state"], "exited")
                self.assertTrue(value["stream_eof"])
                heartbeats = [json.loads(call.args[0])["test_progress_heartbeat"] for call in output.call_args_list
                              if "test_progress_heartbeat" in json.loads(call.args[0])]
                self.assertTrue(any(row["observed_active"] and row["observed_active"][0]["age_seconds"] > .05 for row in heartbeats))
                self.assertIn(mode + " shard", summary.read_text())
                self.assertIn("validated shards 1/3", summary.read_text())
                self.assertEqual(shards.load_json(attempt / "child-exit.json")["exit_code"], 0)

    def test_progress_timeout_retains_partial_raw_events_and_no_success(self):
        for mode in shards.MODES:
            attempt = self.root / (mode + "-timeout-progress")
            attempt.mkdir()
            script = "import time; print('\\u25c7 Test unfinished() started.'); time.sleep(10)"
            with patch.object(shards.legacy, "progress"):
                code = shards.execute_process([sys.executable, "-c", script], self.root, attempt,
                    .2, [], {"LANG": "C"}, isolate_environment=False, progress=self.progress_context(mode))
            self.assertEqual(code, 124)
            value = shards.load_json(attempt / "test-progress.json")
            self.assertEqual(value["state"], "timed-out")
            self.assertEqual(value["observed_counts"]["started"], 1)
            self.assertEqual(value["observed_counts"]["completed"], 0)
            self.assertEqual(value["observed_active"][0]["name"], "unfinished()")
            self.assertFalse((attempt / "result.json").exists())

    def test_progress_cancellation_closes_owned_child_and_preserves_partial_output(self):
        script = """
import pathlib, sys
import recoverable_shards as shards
root = pathlib.Path(sys.argv[1])
shards.execute_process([sys.executable, '-c', "import time; print('\\u25c7 Test interrupted(value:) started.'); time.sleep(30)"],
    root, root, 60, [], {'LANG':'C'}, isolate_environment=False,
    progress={'mode':sys.argv[2], 'shard':'a'*64, 'selected_method_count':1})
"""
        for mode in shards.MODES:
            attempt = self.root / (mode + "-cancel-progress")
            attempt.mkdir()
            with (attempt / "controller.log").open("wb") as log:
                controller = subprocess.Popen([sys.executable, "-c", script, str(attempt), mode],
                    cwd=Path(shards.__file__).parent, stdout=log, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        path = attempt / "test-progress.json"
                        if path.exists() and json.loads(path.read_text()).get("observed_active"):
                            break
                        time.sleep(.01)
                    else:
                        self.fail("Fake child did not publish a started observation")
                    controller.send_signal(signal.SIGINT)
                    self.assertNotEqual(controller.wait(timeout=5), 0)
                finally:
                    if controller.poll() is None:
                        controller.kill()
                        controller.wait(timeout=5)
                value = shards.load_json(attempt / "test-progress.json")
                self.assertEqual(value["state"], "interrupted")
                self.assertEqual(value["observed_counts"]["completed"], 0)
                self.assertTrue(value["stream_eof"])
                self.assertFalse((attempt / "result.json").exists())
                plan = shards.make_plan(self.runtimes[mode], METHODS[:1])
                identity = shards.shard_identity(plan["runtime"], plan["shards"][0])
                stage = self.store.root / "attempts" / shards.fingerprint(identity) / (mode + "-partial")
                stage.parent.mkdir(parents=True)
                shutil.copytree(attempt, stage)
                export = self.root / (mode + "-partial-export")
                self.assertEqual(self.store.export_outcome(identity, export)["status"], "failed")
                for name in ("test.log", "test-events.jsonl", "test-progress.json"):
                    self.assertEqual((export / "last-attempt" / name).read_bytes(), (attempt / name).read_bytes())
                self.assertIsNone(self.store.matching(identity))

    def test_progress_startup_failure_closes_both_pty_fds(self):
        attempt = self.root / "progress-no-launch"
        attempt.mkdir()
        actual_open = shards.os.openpty
        descriptors = []

        def opened():
            pair = actual_open()
            descriptors.extend(pair)
            return pair

        with patch.object(shards.os, "openpty", side_effect=opened), patch.object(shards.subprocess, "Popen", side_effect=OSError("fake startup")), patch.object(shards.legacy, "progress"):
            with self.assertRaises(OSError):
                shards.execute_process(["/fake/command"], self.root, attempt, 5, [], {"LANG": "C"},
                    isolate_environment=False, progress=self.progress_context())
        for descriptor in descriptors:
            with self.assertRaises(OSError):
                os.fstat(descriptor)
        self.assertEqual(shards.load_json(attempt / "test-progress.json")["state"], "not-launched")
        self.assertFalse((attempt / "child.json").exists())

    def test_native_executor_routes_shared_progress_without_command_or_environment_changes(self):
        worker = self.root / "progress-router"
        worker.mkdir()
        for mode in shards.MODES:
            shards.durable_json(worker / (mode + "-build.json"), {"image_relative": ".build/fake-image"})
            executor = object.__new__(shards.NativeExecutor)
            executor.workspace, executor.active_workspace, executor.runtime = worker, worker / mode, self.runtimes[mode]
            environment = {"PATH": "/fake-path", "LANG": "C"}
            executor.authority = SimpleNamespace(config={}, environment_for=lambda _: dict(environment))
            executor.unknown_live_helpers = lambda: False
            executor.progress_context = {"validated_shards_completed": 1, "shards_total": 2}
            monitor = SimpleNamespace(bound_callback=None, observed={"fake-image": True}, errors=[])
            plan = shards.make_plan(self.runtimes[mode], METHODS)
            shard = plan["shards"][0]
            with patch.object(shards.shutil, "which", return_value="/fake/swift"), patch.object(shards, "NativeMonitor", return_value=monitor), patch.object(shards, "execute_process", return_value=0) as execute:
                self.assertEqual(executor.execute(shard, self.root / "route-attempt", 7200, [17]), 0)
            args, options = execute.call_args
            self.assertEqual(args[0], shards.legacy.batch_command("/fake/swift", self.runtimes[mode]["flags"], mode, self.root / "route-attempt", shard["methods"]))
            self.assertEqual(args[4], [17])
            self.assertEqual(args[5], environment)
            self.assertIs(args[6], monitor)
            self.assertEqual(options["progress"], dict(mode=mode, shard=shard["id"], selected_method_count=len(shard["methods"]), validated_shards_completed=1, shards_total=2))

    def test_progress_files_are_hashed_and_observations_cannot_replace_xml(self):
        for index, mode in enumerate(shards.MODES):
            plan = shards.make_plan(self.runtimes[mode], METHODS)
            shard = plan["shards"][0]
            self.store = shards.Store(self.root / (mode + "-progress-proof"))

            def observations(attempt):
                context = dict(mode=mode, shard=shard["id"], selected_method_count=len(shard["methods"]))
                with (attempt / "test.log").open("ab") as raw, patch.object(shards.legacy, "progress"), shards.ObservedTestProgress(attempt, raw, context) as capture:
                    capture.feed("\u2714 Test observationOnly() passed after 1.0 seconds.\n".encode())
                    capture.eof = True
                    capture.publish("exited", force=True, exit_code=0)

            executor = FakeExecutor(self.root / (mode + "-progress-worker"), self.runtimes)
            executor.damage = observations
            outcome = self.run_one(plan, executor)
            attempt = Path(outcome["attempt"])
            receipt = shards.load_json(attempt / "result.json")
            self.assertIn("test-events.jsonl", receipt["outputs"])
            self.assertIn("test-progress.json", receipt["outputs"])
            self.assertEqual(receipt["outputs"]["test-progress.json"], shards.legacy.digest(attempt / "test-progress.json"))

            def missing_xml(attempt):
                observations(attempt)
                (attempt / "tests.xml").write_text("<testsuites/>")

            self.store = shards.Store(self.root / (mode + "-progress-no-xml"))
            executor.damage = missing_xml
            with self.assertRaises(ValueError):
                self.run_one(plan, executor)
            self.assertIsNone(self.store.matching(shards.shard_identity(plan["runtime"], shard)))

            for mutation, name in [(lambda attempt: (attempt / "test-events.jsonl").unlink(), "missing-pair"),
                                   (lambda attempt: (attempt / "test-events.jsonl").write_text('{"schema":1}\n'), "bad-event"),
                                   (lambda attempt: (attempt / "test-progress.json").write_text('{}'), "bad-snapshot")]:
                self.store = shards.Store(self.root / (mode + "-progress-" + name))

                def damaged(attempt):
                    observations(attempt)
                    mutation(attempt)

                executor.damage = damaged
                with self.assertRaises(ValueError):
                    self.run_one(plan, executor)

    def test_child_startup_failure_has_durable_no_launch_proof(self):
        attempt = self.root / "not-launched"
        attempt.mkdir(mode=0o700)
        with patch.object(shards.subprocess, "Popen", side_effect=OSError("fake exec failure")):
            with self.assertRaises(OSError):
                shards.execute_process(["/fake/command"], self.root, attempt, 5, [], {"LANG": "C"})
        self.assertEqual(shards.load_json(attempt / "launch-failure.json")["status"], "not-launched")
        self.assertFalse((attempt / "child.json").exists())
    def test_child_temp_leftovers_qualify_and_unexpected_proof_or_environment_still_fails(self):
        class PythonExecutor(FakeExecutor):
            def execute(inner, shard, attempt, timeout, descriptors):
                inner.calls += 1
                report = attempt / "tests.xml"
                script = ("import os,pathlib; "
                          "pathlib.Path(os.environ['TMPDIR'],'leftover').write_text('temp'); "
                          + "pathlib.Path(" + repr(str(report)) + ").write_text(" + repr(
                              '<testsuites><testcase classname="L337CoreTests.A" name="one()" time="1"/>'
                              '</testsuites>') + ")")
                return shards.execute_process([sys.executable, "-c", script], self.root, attempt,
                                               timeout, descriptors, {"LANG": "C"})
        plan = shards.make_plan(self.runtimes["thread"], METHODS[:1])
        executor = PythonExecutor(self.root / "python-worker", self.runtimes)
        outcome = self.run_one(plan, executor)
        attempt = Path(outcome["attempt"])
        self.assertFalse((attempt / "tmp").exists())
        record = shards.load_json(attempt / "environment.json")
        self.assertNotEqual(record["base"]["TMPDIR"], record["actual"]["TMPDIR"])
        self.assertFalse(Path(record["bindings"]["TMPDIR"]["path"]).exists())
        attempt.chmod(0o700)
        (attempt / "unexpected").write_text("must reject")
        with self.assertRaises(ValueError):
            shards.evidence_outputs(attempt, plan["runtime"], plan["inventory"])
        (attempt / "unexpected").unlink()
        for change in (lambda value: value["actual"].update(LANG="f" * 64),
                       lambda value: value["bindings"]["TMPDIR"].update(kind="ignored"),
                       lambda value: value["base"].update(PATH="f" * 64)):
            damaged = deepcopy(record)
            change(damaged)
            self.change(attempt / "environment.json", json.dumps(damaged))
            with self.assertRaises(ValueError):
                shards.evidence_outputs(attempt, plan["runtime"], plan["inventory"])

    def test_hard_killed_python_controller_recovers_only_durable_success(self):
        script = """
import json, os, pathlib, sys
from types import SimpleNamespace
from unittest.mock import patch
import recoverable_shards as shards
from test_native_runner import owned_control_fixture
from test_recoverable_shards import FakeExecutor, ADMISSION, HEAD
plan = shards.load_json(pathlib.Path(sys.argv[1]))
cache, stage = pathlib.Path(sys.argv[2]), sys.argv[3]
home = cache.parent / 'child-physical-home'
owned_control_fixture(home / 'Library/EliteNativeCI')
patch('pwd.getpwuid', return_value=SimpleNamespace(pw_dir=str(home))).start()
executor = FakeExecutor(cache.parent / 'worker-hard-kill', {'thread': plan['runtime']})
if stage == 'after-xml':
    executor.damage = lambda attempt: os._exit(77)
def stop(current):
    if current == stage:
        os._exit(77)
shards.run_shard(plan, plan['shards'][0]['id'], shards.Store(cache), executor,
                 HEAD, 5, ADMISSION, stop)
"""
        plan_path = self.root / "plan.json"
        shards.durable_json(plan_path, self.plan)
        for stage in ("after-xml", "before-receipt", "after-receipt", "before-upload"):
            cache = self.root / ("hard-kill-" + stage)
            result = subprocess.run([sys.executable, "-c", script, str(plan_path), str(cache), stage],
                                    cwd=Path(shards.__file__).parent, timeout=10)
            self.assertEqual(result.returncode, 77)
            self.store = shards.Store(cache)
            before = self.executor.calls
            outcome = self.run_one()
            committed = stage in ("after-receipt", "before-upload")
            self.assertEqual(outcome["reused"], committed)
            self.assertEqual(self.executor.calls - before, 0 if committed else 1)

    def test_timeout_kills_only_owned_python_session_and_retains_terminal_failure(self):
        attempt = self.root / "process"
        attempt.mkdir(mode=0o700)
        code = shards.execute_process([sys.executable, "-c", "import time; time.sleep(10)"],
                                      self.root, attempt, 0.1, [], os.environ)
        self.assertEqual(code, 124)
        terminal = shards.load_json(attempt / "child-exit.json")
        self.assertEqual(terminal["exit_code"], 124)
        with self.assertRaises(ProcessLookupError):
            os.kill(terminal["pid"], 0)

    def test_child_inherits_claim_after_controller_drops_its_descriptor(self):
        claims = self.root / "process-claims"
        with shards.claim(claims, "shard") as lock:
            child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"],
                                     pass_fds=[lock.fileno()])
        try:
            with self.assertRaises(BlockingIOError), shards.claim(claims, "shard"):
                pass
        finally:
            child.terminate()
            child.wait(timeout=2)
        with shards.claim(claims, "shard"):
            pass

    def test_physical_cli_fails_before_any_execution(self):
        for command in ("prepare", "worker", "pool", "export", "restore", "phase", "aggregate",
                        "workflow-prepare", "workflow-load", "workflow-run", "workflow-phase", "workflow-export",
                        "workflow-phase-export", "workflow-aggregate"):
            result = subprocess.run([sys.executable, str(Path(shards.__file__)), command],
                                    text=True, capture_output=True,
                                    env={**os.environ, "ELITE_RECOVERABLE_CODE_ENABLED": "true"})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("a host-owned activation policy is required", result.stderr)


class NativeAdapterTests(Fixture):
    def test_only_closed_new_job_controls_are_removed_and_actual_popen_env_keeps_unknown_and_native_approval(self):
        authority = self.authority()
        expected = {"ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_PATH",
                    "ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
                    "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE",
                    "ELITE_RECOVERABLE_POLICY_SHA256", "ELITE_RECOVERABLE_WORKFLOW_SHA256",
                    "ELITE_RECOVERABLE_ACTIVATION_SHA256", "ELITE_RECOVERABLE_CODE_ENABLED"}
        self.assertEqual(set(shards.AUTHORIZATION_CONTROLS), expected)
        authority.environment.update({name: "fake-job-control" for name in expected})
        authority.environment.update(ELITE_UNKNOWN_TEST_CONTROL="retain-me", ELITE_NATIVE_APPROVED_HEAD=HEAD,
                                     ELITE_NATIVE_POLICY="/fixture/legacy-policy", SWIFT_EXEC="/fixture/swift",
                                     DYLD_PRINT_LIBRARIES="1", LC_ALL="C")
        actual = authority.environment_for("thread")
        self.assertFalse(set(actual) & expected)
        for name in ("ELITE_UNKNOWN_TEST_CONTROL", "ELITE_NATIVE_APPROVED_HEAD", "ELITE_NATIVE_POLICY",
                     "SWIFT_EXEC", "DYLD_PRINT_LIBRARIES", "LC_ALL"):
            self.assertEqual(actual[name], authority.environment[name])
        self.assertEqual(actual["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"], shards.execution_policy_digest(authority.config))
        original = actual["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"]
        authority.config["planning"] = {"thread": {"history": {"unrelated": 5100}}}
        authority.config["workers"]["two"] = str(self.root / "different-owned-instance")
        authority.environment["ELITE_RECOVERABLE_POLICY_SHA256"] = "different-parent-policy"
        self.assertEqual(authority.environment_for("thread")["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"], original)
        authority.config["admission"]["ram_reserve"] += 1
        self.assertNotEqual(authority.environment_for("thread")["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"], original)
        authority.config["admission"]["ram_reserve"] -= 1
        attempt = self.root / "actual-env-spy"
        attempt.mkdir(mode=0o700)
        with patch.object(shards.subprocess, "Popen", side_effect=OSError("fake no launch")) as spawn:
            with self.assertRaises(OSError):
                shards.execute_process(["/fake/swift", "test"], self.root, attempt, 5, [], actual)
        observed = spawn.call_args.kwargs["env"]
        self.assertFalse(set(observed) & expected)
        self.assertEqual(observed["ELITE_UNKNOWN_TEST_CONTROL"], "retain-me")
        runtime = {**self.runtimes["thread"], "host": authority.config["host"],
                   "environment": shards.legacy.runtime_identity(actual)}
        authority.environment.update(GITHUB_JOB="native_shards", GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1",
                                     ELITE_RECOVERABLE_CODE_ENABLED="true")
        authority.policy["recoverable_activation"] = {"workflow_sha256": "f" * 64}
        authority.environment.update(ELITE_RECOVERABLE_WORKFLOW_SHA256="f" * 64,
                                     ELITE_RECOVERABLE_POLICY_SHA256=shards.native_runner.policy_digest(authority.policy))
        proof = authority.authorization()
        shards.validate_authorization(proof, runtime)
        for mutate in (lambda value: value["controls"].update(ELITE_UNAPPROVED_IGNORE="f" * 64),
                       lambda value: value.update(execution_policy_sha256="f" * 64),
                       lambda value: value.update(host="other-host")):
            changed = deepcopy(proof)
            mutate(changed)
            with self.assertRaises(ValueError):
                shards.validate_authorization(changed, runtime)
        authority.environment.update(GITHUB_JOB="native_shards", ELITE_RECOVERABLE_REQUEST_MODE="thread",
                                     ELITE_RECOVERABLE_REQUEST_SHARD="a" * 64, ELITE_RECOVERABLE_REQUEST_WORKER="one")
        authority.verify_request("thread", "a" * 64, "one")
        with self.assertRaises(ValueError):
            authority.verify_request("address", "a" * 64, "one")

    def authority(self):
        controller = self.root / "controller"
        controller.mkdir(mode=0o700)
        policy = self.root / "host-policy.json"
        host = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        config = dict(schema=1, host=host, cache=str(self.store.root), legacy_cache=str(self.root / "legacy"),
                      workers={"one": str(self.root / "native-worker-one"),
                               "two": str(self.root / "native-worker-two")},
                      admission={key: value for key, value in ADMISSION.items()
                                 if key not in ("ram_available", "disk_available")})
        shards.durable_json(policy, {"approved_head": HEAD, "recoverable_shards": config})
        calls = []
        def read(command, workspace, environment, descriptors):
            calls.append((command, workspace, environment))
            if command[:3] == ["git", "rev-parse", "HEAD"]:
                return HEAD
            if command[:2] == ["git", "clone"]:
                Path(command[-1]).mkdir(mode=0o700)
            if command[0] == "ioreg":
                return '"IOPlatformUUID" = "' + host + '"'
            if command == ["sysctl", "-n", "hw.logicalcpu"]:
                return "2"
            if command == ["vm_stat"]:
                return ("Mach Virtual Memory Statistics: (page size of 4096 bytes)\n"
                        "Pages free: 100.\nPages inactive: 100.\nPages speculative: 100.\n")
            if command[0] == "fake-swift":
                return "fake Swift 6"
            if command == ["xcrun", "--show-sdk-version"]:
                return "fake-sdk"
            if command == ["xcrun", "--show-sdk-path"]:
                return "/fake/sdk"
            return ""
        with patch.object(shards, "PHYSICAL_EXECUTION_ENABLED", True), patch.object(
                shards.native_runner, "validate", return_value=controller) as validate, patch.object(
                shards.native_runner, "require_recoverable_checkout"):
            authority = shards.NativeAuthority(policy, {"LANG": "C", "GITHUB_JOB": "prepare_native",
                "ELITE_RECOVERABLE_CODE_ENABLED": "true", "ELITE_NATIVE_APPROVED_HEAD": HEAD,
                "ELITE_NATIVE_POLICY": str(policy)}, read)
            authority.environment = {"LANG": "C"}
            validate.assert_called_once()
        authority.calls = calls
        return authority

    def prepared(self):
        authority = self.authority()
        calls = []
        def build(root, swift, flags, environment, lock, report):
            mode = next(flag for flag in flags if flag.startswith("--sanitize=")).split("=", 1)[1]
            calls.append(mode)
            image = root / flags[1] / "fake.xctest/Contents/MacOS/L337CoreTests"
            image.parent.mkdir(parents=True, mode=0o700)
            image.write_bytes(self.image.read_bytes())
            return image, METHODS, 0.001
        def runtime(workspace, mode, image, flags, inputs=None):
            return {**self.runtimes[mode], "flags": flags, "image_sha256": shards.legacy.digest(image)}
        patches = [patch.object(shards.legacy, "ensure_no_live_tests"),
                   patch.object(shards.shutil, "which", return_value="/fake/swift"),
                   patch.object(shards.legacy, "executable_inputs", return_value=self.runtimes["thread"]["inputs"]),
                   patch.object(shards.legacy, "build_and_discover", side_effect=build),
                   patch.object(shards.legacy, "grouping_policy", return_value={"shared_groups": [METHODS[:2]]}),
                   patch.object(authority, "runtime", side_effect=runtime),
                   patch.object(authority, "admission", return_value={**ADMISSION, "disk_available": 1000000})]
        for item in patches:
            item.start()
            self.addCleanup(item.stop)
        builder = shards.NativeBuilder(authority)
        builds = {mode: builder.prepare(mode, self.root / ("frozen-" + mode)) for mode in shards.MODES}
        return authority, builder, builds, calls

    def test_preprobe_authorization_holds_before_policy_io_or_native_commands(self):
        with patch.object(shards.native_runner, "validate") as validate, patch.object(
                shards, "native_output") as read:
            with self.assertRaisesRegex(ValueError, "HELD"):
                shards.NativeAuthority(self.root / "does-not-exist",
                                       {"ELITE_RECOVERABLE_CODE_ENABLED": "true"}, read=read)
            read.assert_not_called()
            validate.assert_not_called()

    def test_actual_runtime_uses_mocked_compiler_sdk_host_inputs_image_and_mode_environment(self):
        authority = self.authority()
        with patch.object(shards.shutil, "which", return_value="fake-swift"), patch.object(
                shards, "image_uuids", return_value={"uuids": {"arm64": "fake-uuid"}}), patch.object(
                shards.legacy, "executable_inputs", return_value=self.runtimes["thread"]["inputs"]), patch.object(
                shards.legacy, "opt_in_policy", return_value={}), patch.object(
                shards.os, "uname", return_value=SimpleNamespace(release="fake-os", version="fake-version")), patch.object(
                shards.platform, "machine", return_value="fake-arm64"):
            runtime = authority.runtime(authority.root, "address", self.image,
                                        ["--scratch-path", ".build/asan", "--sanitize=address"])
        self.assertEqual(runtime["environment"]["ASAN_OPTIONS"],
                         shards.legacy.runtime_identity({"ASAN_OPTIONS": "detect_leaks=0"})["ASAN_OPTIONS"])
        self.assertIsNone(runtime["phase_environment"]["ASAN_OPTIONS"])
        self.assertEqual(runtime["image_sha256"], shards.legacy.digest(self.image))
        self.assertEqual(runtime["host"], authority.config["host"])
        shards.validate_runtime(runtime)
        with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=100)):
            self.assertEqual(authority.admission()["explicit"], 2)

    def test_native_preparation_reuses_one_build_per_mode_and_private_scratch_and_commands(self):
        authority, builder, builds, calls = self.prepared()
        builder.prepare("thread", self.root / "frozen-thread")
        self.assertEqual(calls, ["thread", "address"])
        clones = [command for command, _, _ in authority.calls if command[:2] == ["git", "clone"]]
        self.assertEqual(len(clones), 4)  # Two frozen modes in two private workers, once each.
        one, two = shards.NativeExecutor(authority, "one"), shards.NativeExecutor(authority, "two")
        for mode in shards.MODES:
            runtime = builds[mode]["runtime"]
            one.verify(runtime)
            two.verify(runtime)
            self.assertNotEqual(one.active_workspace, two.active_workspace)
            plan = shards.make_plan(runtime, METHODS)
            attempt = self.root / ("native-execution-" + mode)
            attempt.mkdir(mode=0o700)
            def completed(*args, progress):
                self.assertEqual(progress["mode"], mode)
                self.assertEqual(progress["selected_method_count"], len(plan["shards"][0]["methods"]))
                args[6].observed = {"fake": {"sha256": runtime["image_sha256"], "uuid": runtime["image_uuid"]}}
                return 0
            with patch.object(shards, "execute_process", side_effect=completed) as execute, patch.object(
                    one, "unknown_live_helpers", return_value=False):
                self.assertEqual(one.execute(plan["shards"][0], attempt, 5, []), 0)
            command, workspace = execute.call_args.args[:2]
            self.assertEqual(workspace, one.active_workspace)
            self.assertIn("--skip-build", command)
            self.assertEqual("--no-parallel" in command, mode == "address")
            self.assertEqual(command[command.index("--scratch-path") + 1], runtime["flags"][1])
        image = one.active_workspace / Path(builds["address"]["image"]).relative_to(authority.root)
        image.write_bytes(b"tampered image")
        with self.assertRaises(ValueError):
            one.verify(builds["address"]["runtime"])

    def test_copy_refuses_external_build_links_and_executor_refuses_controller_source_drift(self):
        authority, _, builds, _ = self.prepared()
        source = self.root / "unsafe-build"
        source.mkdir(mode=0o700)
        (source / "external").symlink_to(self.image)
        with self.assertRaises(ValueError):
            shards.copy_build_tree(source, self.root / "unsafe-copy")
        executor = shards.NativeExecutor(authority, "one")
        with patch.object(shards.legacy, "executable_inputs", return_value={"Sources/Game.swift": "f" * 64}):
            with self.assertRaises(ValueError):
                executor.verify(builds["thread"]["runtime"])

    def test_durable_mode_bundle_restores_lost_controller_scratch_and_private_worker_without_compile(self):
        authority, builder, builds, calls = self.prepared()
        shutil.rmtree(authority.root / ".build")
        shutil.rmtree(authority.workers["one"] / "thread")
        restored = builder.prepare("thread", self.root / "frozen-thread")
        self.assertEqual(restored, builds["thread"])
        self.assertEqual(calls, ["thread", "address"])
        shards.NativeExecutor(authority, "one").verify(restored["runtime"])
        bundle_image = self.root / "frozen-thread/scratch" / Path(restored["image_relative"]).relative_to(".build/tsan")
        self.change(bundle_image, "tampered frozen binary")
        with self.assertRaises(ValueError):
            builder.prepare("thread", self.root / "frozen-thread")
        self.assertEqual(calls, ["thread", "address"])

    def test_descendant_tracking_includes_separate_groups_and_cleanup_never_owns_reused_pid(self):
        authority = self.authority()
        root = dict(parent=1, group=10, state="S", start="fake-start", command="owned swift")
        helper = dict(parent=10, group=20, state="S", start="helper-start", command="swiftpm-testing-helper")
        rows = {10: root, 20: helper}
        authority.snapshot = lambda: dict(rows)
        attempt = self.root / "monitor"
        attempt.mkdir(mode=0o700)
        monitor = shards.NativeMonitor(authority, attempt, self.root / "worker")
        monitor.known[10] = root
        self.assertEqual(set(monitor.observe()), {10, 20})
        rows[10] = {**root, "start": "reused-pid", "command": "unrelated"}
        cleaned = []
        def cleanup(identity, snapshot):
            self.assertTrue(shards.same_process(identity, snapshot()[identity["pid"]]))
            cleaned.append(identity["pid"])
            rows.pop(identity["pid"])
        with patch.object(shards, "cleanup_owned_identity", side_effect=cleanup):
            self.assertFalse(monitor.finish(True))
        self.assertEqual(cleaned, [20])
        self.assertIn(10, rows)

    def test_cli_worker_uses_trusted_plan_and_actual_executor_contract(self):
        authority, _, builds, _ = self.prepared()
        plan = shards.make_plan(builds["thread"]["runtime"], METHODS)
        path = self.root / "native-plan.json"
        shards.durable_json(path, plan)
        args = ["recoverable_shards.py", "worker", "--input", str(path), "--digest", shards.legacy.digest(path),
                "--policy", str(self.root / "host-policy.json"), "--worker", "one", "--shard", plan["shards"][0]["id"]]
        with patch.object(shards, "PHYSICAL_EXECUTION_ENABLED", True), patch.object(
                shards, "NativeAuthority", return_value=authority), patch.object(
                shards, "run_shard", return_value={"fake-command-contract": "passed"}) as run, patch.object(
                shards.legacy, "progress"), patch.object(sys, "argv", args):
            shards.main()
            self.assertIsInstance(run.call_args.args[3], shards.NativeExecutor)
        with self.assertRaises(ValueError):
            shards.trusted_json(path, "0" * 64)

    def test_cli_export_restore_and_pool_resume_transport_per_shard_without_execution(self):
        authority, _, builds, _ = self.prepared()
        plan = shards.make_plan(builds["thread"]["runtime"], METHODS)
        executor = FakeExecutor(self.root / "transport-worker", {"thread": plan["runtime"]})
        self.run_one(plan, executor)
        plan_path, artifact = self.root / "transport-plan.json", self.root / "transport-artifact"
        shards.durable_json(plan_path, plan)
        common = ["--input", str(plan_path), "--digest", shards.legacy.digest(plan_path),
                  "--policy", str(self.root / "host-policy.json"), "--shard", plan["shards"][0]["id"]]
        def invoke(arguments):
            with patch.object(shards, "PHYSICAL_EXECUTION_ENABLED", True), patch.object(
                    shards, "NativeAuthority", return_value=authority), patch.object(
                    shards.legacy, "progress") as output, patch.object(sys, "argv", ["shards.py", *arguments]):
                shards.main()
                return json.loads(output.call_args.args[0])
        exported = invoke(["export", *common, "--output", str(artifact)])
        authority.cache = self.root / "restored-cli-cache"
        restored = invoke(["restore", *common, "--artifact", str(artifact),
                           "--artifact-digest", exported["index_sha256"]])
        self.assertTrue(Path(restored["restored"]).is_dir())
        matrix = self.root / "pool-manifest.json"
        shards.durable_json(matrix, {"plans": [{"path": str(plan_path), "sha256": shards.legacy.digest(plan_path)}]})
        with patch.object(shards, "NativeExecutor", return_value=executor):
            # Admit one fake worker to avoid aliasing the same fake workspace into two workers.
            with patch.object(authority, "admission", return_value={**ADMISSION, "explicit": 1}):
                outcome = invoke(["pool", "--input", str(matrix), "--digest", shards.legacy.digest(matrix),
                                  "--policy", str(self.root / "host-policy.json")])
        self.assertTrue(outcome[0]["reused"])
        self.assertEqual(executor.calls, 1)

    def test_disconnected_or_unregistered_helpers_block_even_with_a_saved_owned_ledger(self):
        authority = self.authority()
        executor = shards.NativeExecutor(authority, "one")
        attempt = authority.cache / "attempts" / ("a" * 64) / "fake-attempt"
        attempt.mkdir(parents=True, mode=0o700)
        controller = dict(pid=10, parent=1, group=10, state="S", start="controller", command="owned python")
        child = dict(pid=20, parent=10, group=20, state="S", start="swift", command="owned swift test")
        helper = dict(parent=20, group=30, state="S", start="helper", command="swiftpm-testing-helper")
        rows = {10: controller, 20: child, 30: helper}
        authority.snapshot = lambda: dict(rows)
        record = dict(schema=1, workspace=str(executor.workspace / "thread"), controller=controller,
                      root=child, running=True, processes={"20": child, "30": helper})
        shards.durable_json(attempt / "processes.json", record)
        shards.durable_json(attempt / "start.json", {"owner": controller})
        self.assertFalse(executor.unknown_live_helpers())
        self.assertFalse(executor.proven_exited(attempt))
        rows.pop(10)
        self.assertTrue(executor.unknown_live_helpers())
        rows[10] = controller
        rows.pop(20)
        self.assertTrue(executor.unknown_live_helpers())
        rows.pop(30)
        self.assertFalse(executor.proven_exited(attempt))  # Controller still live, no terminal proof.
        rows.pop(10)
        self.assertTrue(executor.proven_exited(attempt))

    def test_fresh_full_phase_executes_legacy_helper_and_records_preexecution_host_origin(self):
        authority, _, builds, _ = self.prepared()
        PhaseTests.full_phase(self, "normal")
        executor = shards.NativeExecutor(authority, "one")
        plan = shards.make_plan(builds["thread"]["runtime"], METHODS)
        def execute(command, workspace, attempt, timeout, descriptors, environment, monitor,
                    isolate_environment):
            self.assertFalse(isolate_environment)
            self.assertTrue((attempt / "launch.json").exists())
            self.assertEqual(command[2], "normal")
            fresh = Path(command[-1]) / "phases/fake/attempt"
            fresh.parent.mkdir(parents=True, mode=0o700)
            import shutil
            shutil.copytree(self.root / "normal", fresh)
            monitor.observed = {"/fake/image": {"sha256": shards.legacy.digest(self.image), "uuid": shards.fingerprint(
                {"fake-arm64": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"})}}
            return 0
        with patch.object(shards, "execute_process", side_effect=execute) as invocation, patch.object(
                executor, "unknown_live_helpers", return_value=False), patch.object(
                authority, "host", return_value=self.runtimes["thread"]["host"]):
            runner = shards.NativePhaseRunner(authority, executor)
            with self.assertRaises(RuntimeError):
                runner.run("normal", plan, self.root / "fresh-normal-proof", 5,
                           lambda stage: (_ for _ in ()).throw(RuntimeError("lost before upload")))
            checksum = runner.run(
                "normal", plan, self.root / "fresh-normal-proof", 5)
            self.assertEqual(runner.run("normal", plan, self.root / "fresh-normal-proof", 5), checksum)
            self.assertEqual(runner.run("normal", plan, self.root / "another-normal-export", 5), checksum)
            self.assertEqual(invocation.call_count, 1)
            self.assertTrue(runner.reused)
        shards.validate_phase(self.root / "fresh-normal-proof", checksum, "normal", plan["runtime"], METHODS)
        with self.assertRaises(ValueError):
            shards.NativePhaseRunner(authority, executor).phase_origin(self.root / "normal", {})

    def test_observed_helper_must_match_private_path_image_hash_uuid_and_be_present(self):
        authority, _, builds, _ = self.prepared()
        workspace = authority.workers["one"] / "thread"
        image = workspace / builds["thread"]["image_relative"]
        uuids = {"arm64": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
        runtime = {**builds["thread"]["runtime"], "image_uuid": shards.fingerprint(uuids)}
        root = dict(parent=1, group=10, state="S", start="root", command="swift test")
        for case in ("valid", "wrong-path", "wrong-hash", "wrong-uuid", "missing"):
            attempt = self.root / ("image-binding-" + case)
            attempt.mkdir(mode=0o700)
            path = image if case != "wrong-path" else self.image
            helper = dict(parent=10, group=20, state="S", start="helper",
                          command=f"/fake/swiftpm-testing-helper --test-bundle-path {path} {path} --testing-library swift-testing")
            rows = {10: root} if case == "missing" else {10: root, 20: helper}
            authority.snapshot = lambda: dict(rows)
            expected = {**runtime, **({"image_sha256": "f" * 64} if case == "wrong-hash" else
                                     {"image_uuid": "wrong"} if case == "wrong-uuid" else {})}
            monitor = shards.NativeMonitor(authority, attempt, workspace, expected, image)
            monitor.known[10] = root
            with patch.object(shards, "image_uuids", return_value={"uuids": uuids}):
                monitor.observe()
            rows.clear()
            self.assertEqual(monitor.finish(False), case == "valid", case)


class WorkflowTests(Fixture):
    authority = NativeAdapterTests.authority
    prepared = NativeAdapterTests.prepared

    def test_ci_requires_real_make_ci_and_has_no_sanitizer_or_local_proof_jobs(self):
        source = (Path(__file__).resolve().parents[2] / ".github/workflows/recoverable-quality.yml").read_text()
        for name in ('prepare_thread', 'prepare_address', 'thread_shards', 'address_shards',
                     'native_local_components', 'native_phase', 'native_aggregate'):
            self.assertNotIn("\n  " + name + ":\n", source)
        self.assertNotIn('workflow-verify-local-components', source)
        self.assertNotIn('workflow-owned-aggregate', source)
        self.assertNotIn('workflow-prepare --mode', source)
        self.assertIn('run: python3 Tools/CI/capture-quality.py', source)
        gate = self.workflow_script('Held, failed or cancelled execution')
        selected = dict(AUTHORIZED='true', FAKES='success', CHECKS='success',
                        GITHUB_STEP_SUMMARY=str(self.root / 'normal-leaks-summary'))
        with patch.dict(os.environ, selected, clear=True):
            exec(compile(gate, 'fake-normal-leaks-gate', 'exec'), {})
        for key in ('AUTHORIZED', 'FAKES', 'CHECKS'):
            for value in ('', 'skipped', 'failure', 'cancelled'):
                with self.subTest(control=key, value=value), patch.dict(os.environ, {**selected, key: value}, clear=True):
                    with self.assertRaises(AssertionError):
                        exec(compile(gate, 'fake-normal-leaks-gate', 'exec'), {})


    def workflow(self):
        authority, builder, builds, calls = self.prepared()
        for mode in shards.MODES:
            destination = authority.cache / "builds" / HEAD / mode
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copytree(self.root / ("frozen-" + mode), destination)
        class Remote:
            def artifacts(inner, prefix):
                return []

            def restore_shard(inner, plan, shard, store):
                return store.matching(shards.shard_identity(plan["runtime"], shard)) is not None
        workflow = shards.NativeWorkflow(authority, Remote())
        output = self.root / "workflow-plan"
        result = workflow.prepare(output)
        plans, manifest = workflow.plans(output, result["manifest_sha256"])
        return authority, workflow, output, result, plans, manifest, calls

    def test_workflow_pending_empty_all_failed_and_exact_cached_aggregate(self):
        authority, workflow, bundle, result, plans, manifest, calls = self.workflow()
        self.assertTrue(result["has_pending"])
        self.assertEqual(len(manifest["expected"]), len(manifest["pending"]))
        with self.assertRaises(ValueError):
            shards.workflow_manifest([], ["one"], self.store, HEAD)
        with self.assertRaises(ValueError):
            workflow.aggregate(plans)
        executor = FakeExecutor(self.root / "workflow-worker", {plan["runtime"]["mode"]: plan["runtime"] for plan in plans})
        outcomes = shards.run_pending(plans, self.store, [executor], HEAD, 5, ADMISSION)
        self.assertFalse(any("failed" in item for item in outcomes))
        complete = shards.workflow_manifest(plans, sorted(authority.workers), self.store, HEAD)
        self.assertFalse(complete["has_pending"])
        self.assertEqual(len(complete["expected"]), 2)
        for phase in ("normal", "leaks"):
            proof, _ = PhaseTests.full_phase(self, phase)
            destination = authority.cache / "full-phases" / shards.phase_key(plans[0]["runtime"], METHODS, phase)
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copytree(proof, destination)
        self.assertEqual(workflow.aggregate(plans)["status"], "passed")
        self.assertEqual(calls, ["thread", "address"])
        altered = deepcopy(manifest)
        altered["expected"].pop()
        self.change(bundle / "workflow-plan.json", json.dumps(altered))
        with self.assertRaises(ValueError):
            workflow.plans(bundle, shards.legacy.digest(bundle / "workflow-plan.json"))

    def test_portable_mode_restoration_after_zip_permissions_loss_never_compiles(self):
        authority, workflow, bundle, result, plans, manifest, calls = self.workflow()
        shutil.rmtree(authority.root / ".build")
        for mode in shards.MODES:
            frozen = authority.cache / "builds" / HEAD / mode
            writable = lambda path: shards.writable_private_tree(path)
            writable(frozen)
            shutil.rmtree(frozen)
        # Zip extraction loses executable bits; the bound manifest restores only those bits.
        for path in (bundle / "builds").rglob("*"):
            if path.is_file():
                path.chmod(0o600)
        with shards.NativeBuilder(authority).preparation_claim():
            workflow.restore_builds(bundle)
        for mode in shards.MODES:
            shards.NativeBuilder(authority).prepare(mode, authority.cache / "builds" / HEAD / mode)
        self.assertEqual(calls, ["thread", "address"])

    def test_failed_phase_upload_retains_raw_attempt_but_cannot_become_a_phase_proof(self):
        authority, workflow, bundle, result, plans, manifest, calls = self.workflow()
        attempt = authority.cache / "phase-runs/fake-failed-phase"
        attempt.mkdir(parents=True, mode=0o700)
        shards.durable_json(attempt / "launch.json", {"phase": "normal", "head": HEAD,
                                                      "host": plans[0]["runtime"]["host"]})
        (attempt / "test.log").write_text("original fake failure log")
        output = self.root / "failed-phase-artifact"
        self.assertEqual(workflow.export_phase(plans[0], "normal", output)["status"], "failed")
        self.assertEqual((output / "last-attempt/test.log").read_text(), "original fake failure log")
        with self.assertRaises((ValueError, OSError)):
            shards.validate_phase(output, shards.legacy.digest(output / "failure.json"), "normal", plans[0]["runtime"], METHODS)

    def archive(self, files):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            for name, value in files.items():
                archive.writestr(name, value)
        return buffer.getvalue()

    def remote(self, authority, payload, name="native-test-1", metadata=None):
        authority.environment["GITHUB_RUN_ID"] = "123"
        authority.environment["GITHUB_RUN_ATTEMPT"] = "1"
        authority.environment["GITHUB_REF"] = "refs/heads/approved"
        authority.environment["GITHUB_EVENT_NAME"] = "workflow_dispatch"
        authority.environment["GITHUB_WORKFLOW_REF"] = "stephenlclarke/l337/.github/workflows/recoverable-quality.yml@refs/heads/approved"
        authority.config["admission"]["disk_per_worker"] = 2 * 1024 * 1024
        artifact = dict(id=1, name=name, expired=False, digest="sha256:" + hashlib.sha256(payload).hexdigest(),
                        size_in_bytes=len(payload), workflow_run={"id": 123, "head_sha": HEAD})
        disk = patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=10000000))
        disk.start()
        self.addCleanup(disk.stop)
        artifact.update(metadata or {})
        run = dict(id=123, run_attempt=1, status="in_progress", head_sha=HEAD, event="workflow_dispatch", repository={"full_name": shards.native_runner.REPOSITORY},
                   actor={"id": 22142777}, triggering_actor={"id": 22142777}, head_branch="approved",
                   path=".github/workflows/recoverable-quality.yml@approved")
        def api(path):
            return {"artifacts": [artifact]} if "/artifacts?" in path else run
        remote = shards.GitHubArtifacts(authority, api=api, download=lambda record, path: path.write_bytes(payload))
        return remote, artifact

    def test_artifact_archive_external_digest_head_run_paths_links_and_size_are_strict(self):
        authority = self.authority()
        for filename in ("../escape", "/absolute", "back\\slash"):
            remote, artifact = self.remote(authority, self.archive({filename: "bad"}))
            with self.assertRaises(ValueError):
                remote.fetch(artifact)
        payload = self.archive({"index.json": "{}"})
        remote, artifact = self.remote(authority, payload)
        self.assertTrue((remote.fetch(artifact) / "index.json").exists())
        for changes in ({"digest": "sha256:" + "f" * 64},
                        {"workflow_run": {"id": 123, "head_sha": "b" * 40}},
                        {"workflow_run": {"id": 456, "head_sha": HEAD}}):
            with self.assertRaises(ValueError):
                remote.fetch({**artifact, **changes})
        with self.assertRaises(ValueError):
            remote.fetch(artifact, "f" * 64)
        authority.config["admission"]["disk_per_worker"] = 1
        with self.assertRaises(ValueError):
            remote.fetch(artifact)
        link = zipfile.ZipInfo("link")
        link.create_system, link.external_attr = 3, 0o120777 << 16
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr(link, "outside")
        remote, artifact = self.remote(authority, data.getvalue())
        with self.assertRaises(ValueError):
            remote.fetch(artifact)

    def test_authenticated_passed_shard_restore_executes_zero_and_failed_artifact_never_qualifies(self):
        self.run_one()
        artifact_dir = self.root / "passed-export"
        self.store.export(self.identity(), artifact_dir)
        payload = self.archive({path.relative_to(artifact_dir).as_posix(): path.read_bytes()
                                for path in artifact_dir.rglob("*") if path.is_file()})
        authority = self.authority()
        remote, metadata = self.remote(authority, payload, "native-shard-thread-" + self.plan["shards"][0]["id"] + "-1")
        restored = shards.Store(self.root / "api-restored")
        before = self.executor.calls
        self.assertTrue(remote.restore_shard(self.plan, self.plan["shards"][0], restored))
        self.assertIsNotNone(restored.matching(self.identity()))
        self.assertEqual(self.executor.calls, before)
        failure = self.root / "failure-export"
        shards.Store(self.root / "empty-failure").export_outcome(self.identity(), failure)
        remote, metadata = self.remote(authority, self.archive({"failure.json": (failure / "failure.json").read_bytes()}),
                                       "native-shard-thread-" + self.plan["shards"][0]["id"] + "-2")
        empty = shards.Store(self.root / "failed-api-restore")
        self.assertFalse(remote.restore_shard(self.plan, self.plan["shards"][0], empty))
        self.assertIsNone(empty.matching(self.identity()))

    def workflow_script(self, marker):
        source = (Path(__file__).resolve().parents[2] / ".github/workflows/recoverable-quality.yml").read_text()
        body = source.split(marker, 1)[1].split("python3 - <<'PY'\n", 1)[1].split("\n          PY", 1)[0]
        return textwrap.dedent(body)

    def pr_authorizer_fixture(self):
        activation = dict(schema=1, enabled=True, revoked=False, expires_at=time.time() + 60,
                          head=HEAD, ref="refs/pull/7/merge", pr_head="b" * 40,
                          workflow_file="ci.yml", workflow_sha256="c" * 64,
                          runners={"owned-one": {"workspace": "/fixture/native-runner/_work/l337/l337"}})
        env = dict(ACTIVATION=json.dumps(activation), POLICY_DIGESTS=json.dumps({"owned-one": "d" * 64}),
                   REQUESTED_NATIVE="true", GITHUB_REPOSITORY="stephenlclarke/l337",
                   GITHUB_ACTOR_ID="22142777", GITHUB_EVENT_NAME="pull_request", GITHUB_SHA=HEAD,
                   GITHUB_REF="refs/pull/7/merge",
                   GITHUB_WORKFLOW_REF="stephenlclarke/l337/.github/workflows/ci.yml@refs/pull/7/merge",
                   GITHUB_EVENT_PATH=str(self.root / "hosted-pr-event.json"),
                   GITHUB_OUTPUT=str(self.root / "hosted-pr-output"), GITHUB_TOKEN="must-not-log-this-token")
        repo = {"full_name": "stephenlclarke/l337", "fork": False}
        event = {"repository": deepcopy(repo), "sender": {"id": 22142777}, "number": 7,
                 "pull_request": {"head": {"sha": "b" * 40, "repo": deepcopy(repo)},
                                  "base": {"ref": "main", "repo": deepcopy(repo)},
                                  "user": {"id": 22142777}, "merge_commit_sha": None}}
        return activation, env, event

    def run_pr_authorizer(self, activation, env, event):
        source = self.workflow_script("Fail closed before any native routing")
        env["ACTIVATION"] = json.dumps(activation)
        Path(env["GITHUB_EVENT_PATH"]).write_text(json.dumps(event))
        Path(env["GITHUB_OUTPUT"]).unlink(missing_ok=True)
        with patch.dict(os.environ, env, clear=True):
            exec(compile(source, "fake-hosted-pr-authorizer", "exec"), {})
        return Path(env["GITHUB_OUTPUT"]).read_text()

    def test_hosted_authorizer_accepts_null_stale_or_absent_webhook_only_with_exact_pr_context(self):
        for webhook in (None, "c" * 40, HEAD, "absent"):
            with self.subTest(webhook=webhook):
                activation, env, event = self.pr_authorizer_fixture()
                if webhook == "absent":
                    event["pull_request"].pop("merge_commit_sha")
                else:
                    event["pull_request"]["merge_commit_sha"] = webhook
                self.assertEqual(self.run_pr_authorizer(activation, env, event), "authorized=true\nbackend=github-artifacts-v1\n")

    def test_hosted_authorizer_rejects_wrong_execution_source_ref_repo_actor_or_workflow(self):
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
                    activation, env, event = self.pr_authorizer_fixture()
                    event["pull_request"]["merge_commit_sha"] = webhook
                    mutate(env, event)
                    with self.assertRaises(AssertionError):
                        self.run_pr_authorizer(activation, env, event)
                    self.assertFalse(Path(env["GITHUB_OUTPUT"]).exists())

    def test_hosted_pr_mismatch_diagnostics_include_only_nonsecret_execution_or_source_fields(self):
        for mutate, label in [(lambda e, v: e.update(GITHUB_SHA="c" * 40), "execution SHA/ref mismatch"),
                              (lambda e, v: v["pull_request"]["head"].update(sha="c" * 40), "source SHA mismatch")]:
            activation, env, event = self.pr_authorizer_fixture()
            mutate(env, event)
            with self.assertRaises(AssertionError) as failure:
                self.run_pr_authorizer(activation, env, event)
            message = str(failure.exception)
            self.assertIn(label, message)
            self.assertIn("c" * 40, message)
            self.assertNotIn(env["GITHUB_TOKEN"], message)
            self.assertNotIn("merge_commit_sha", message)

    def test_physical_guard_requires_separate_host_hook_before_any_checkout_and_cancelled_never_passes(self):
        source = self.workflow_script("Require host hook and exact instance")
        activation = dict(schema=1, enabled=True, revoked=False, expires_at=time.time() + 60,
                          head=HEAD, ref="refs/heads/approved", workflow_file="recoverable-quality.yml", workflow_sha256="a" * 64,
                          assignment_root=str(self.root / "owned-assignments"),
                          runners={"owned-one": {"workspace": "/fixture/runner/_work/l337/l337", "jobs": ["native_shards"]}})
        env = dict(ACTIVATION=json.dumps(activation), POLICY_DIGESTS=json.dumps({"owned-one": "b" * 64}),
                   REQUESTED_NATIVE="true", RUNNER_ENVIRONMENT="self-hosted", RUNNER_NAME="owned-one",
                   GITHUB_REPOSITORY="stephenlclarke/l337", GITHUB_ACTOR_ID="22142777", GITHUB_EVENT_NAME="workflow_dispatch",
                   GITHUB_SHA=HEAD, GITHUB_REF="refs/heads/approved", GITHUB_JOB="native_shards",
                   GITHUB_WORKSPACE="/fixture/runner/_work/l337/l337", GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1",
                   PLAN_DIGEST="e" * 64, ELITE_RECOVERABLE_PLAN_SHA256="e" * 64,
                   ELITE_RECOVERABLE_REQUEST_MODE="thread", ELITE_RECOVERABLE_REQUEST_SHARD="f" * 64,
                   ELITE_RECOVERABLE_REQUEST_WORKER="one",
                   GITHUB_WORKFLOW_REF="stephenlclarke/l337/.github/workflows/recoverable-quality.yml@refs/heads/approved",
                   ELITE_NATIVE_APPROVED_HEAD=HEAD, ELITE_RECOVERABLE_CODE_ENABLED="true",
                   ELITE_NATIVE_POLICY="/fixture/owned-policy.json",
                   ELITE_RECOVERABLE_ACTIVATION_SHA256=shards.fingerprint(activation),
                   ELITE_RECOVERABLE_WORKFLOW_SHA256="a" * 64, ELITE_RECOVERABLE_POLICY_SHA256="b" * 64)
        binding = dict(schema=1, head=HEAD, workflow_sha256="a" * 64,
                       activation_sha256=shards.fingerprint(activation), policy_sha256="b" * 64,
                       run_id="123", run_attempt="1", job="native_shards", runner="owned-one",
                       workspace=env["GITHUB_WORKSPACE"], mode="thread", shard="f" * 64, worker="one", phase="",
                       policy_path=env["ELITE_NATIVE_POLICY"],
                       plan_sha256="e" * 64, expires_at=activation["expires_at"], revoked=False)
        root = Path(activation["assignment_root"])
        root.mkdir(mode=0o700)
        path = root / (shards.native_runner.assignment_digest(env) + ".json")
        path.write_text(json.dumps(binding))
        path.chmod(0o400)
        env.update(ELITE_RECOVERABLE_ASSIGNMENT_PATH=str(path),
                   ELITE_RECOVERABLE_ASSIGNMENT_SHA256=shards.fingerprint(binding))
        with patch.dict(os.environ, env, clear=True):
            exec(compile(source, "fake-precheckout-guard", "exec"), {})
        for change in ({"REQUESTED_NATIVE": "false"}, {"GITHUB_SHA": "f" * 40},
                       {"RUNNER_NAME": "unknown"}, {"GITHUB_WORKSPACE": "/other"},
                       {"ELITE_RECOVERABLE_CODE_ENABLED": "false"}, {"ELITE_RECOVERABLE_POLICY_SHA256": "f" * 64}):
            with patch.dict(os.environ, {**env, **change}, clear=True), self.assertRaises((AssertionError, KeyError)):
                exec(compile(source, "fake-precheckout-guard", "exec"), {})
        gate = self.workflow_script("Held, failed or cancelled execution")
        passed = dict(AUTHORIZED="true", CHECKS="success", FAKES="success",
                      GITHUB_STEP_SUMMARY=str(self.root / "gate-summary"))
        with patch.dict(os.environ, passed, clear=True):
            exec(compile(gate, "fake-final-gate", "exec"), {})
        for change in ({"FAKES": "failed"}, {"CHECKS": "cancelled"},
                       {"AUTHORIZED": "false"}, {"CHECKS": "skipped"}):
            with patch.dict(os.environ, {**passed, **change}, clear=True), self.assertRaises(AssertionError):
                exec(compile(gate, "fake-final-gate", "exec"), {})

class ArtifactRunProvenanceTests(unittest.TestCase):
    def contract(self, event="workflow_dispatch"):
        ref = {"workflow_dispatch": "refs/heads/approved", "push": "refs/heads/main",
               "pull_request": "refs/pull/25/merge"}[event]
        workflow = ".github/workflows/recoverable-quality.yml" if event == "workflow_dispatch" else ".github/workflows/ci.yml"
        environment = dict(GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="2", GITHUB_REF=ref, GITHUB_EVENT_NAME=event,
                           GITHUB_WORKFLOW_REF=shards.native_runner.REPOSITORY + "/" + workflow + "@" + ref)
        policy = dict(approved_head=HEAD, recoverable_activation=dict(pr_head="b" * 40))
        authority = SimpleNamespace(environment=environment, policy=policy)
        run = dict(id=123, run_attempt=2, status="in_progress", head_sha="b" * 40 if event == "pull_request" else HEAD,
                   event=event, repository=dict(full_name=shards.native_runner.REPOSITORY),
                   actor=dict(id=22142777), triggering_actor=dict(id=22142777),
                   head_branch=ref.removeprefix("refs/heads/"), path=workflow)
        return authority, run

    def guard_lines(self):
        import ast, inspect
        tree = ast.parse(inspect.getsource(shards.require_artifact_run_provenance))
        first = shards.require_artifact_run_provenance.__code__.co_firstlineno
        return [first + node.body[0].lineno - 1 for node in tree.body[0].body if isinstance(node, ast.If)]

    def refusal(self, authority, run):
        try:
            shards.GitHubArtifacts(authority, api=lambda path: run)
        except ValueError as error:
            self.assertEqual(type(error), ValueError)
            self.assertEqual(error.args, ("Artifact run provenance differs from the approved workflow",))
            return shards.native_runner.authorization_failure(error)
        self.fail("A changed provenance field must refuse")

    def test_exact_dispatch_push_and_separate_pr_source_contexts_accept_existing_paths(self):
        for event in ("workflow_dispatch", "push", "pull_request"):
            authority, run = self.contract(event)
            workflow = shards.native_runner.workflow_path(authority.environment)
            ref = authority.environment["GITHUB_REF"]
            paths = {workflow, workflow + "@" + ref, workflow + "@" + ref.removeprefix("refs/heads/"), workflow + "@" + HEAD}
            for path in sorted(paths):
                with self.subTest(event=event, path=path):
                    run["path"] = path
                    remote = shards.GitHubArtifacts(authority, api=lambda endpoint: run)
                    self.assertEqual(remote.run, "123")
            if event == "pull_request":
                run["head_sha"] = HEAD
                self.assertEqual(self.refusal(authority, run)["owned_line"], self.guard_lines()[1])

    def test_each_of_ten_original_predicates_has_one_distinct_owned_refusal_line(self):
        changes = [lambda r: r.update(id=124), lambda r: r.update(head_sha="c" * 40),
                   lambda r: r.update(run_attempt=3), lambda r: r.update(status="queued"),
                   lambda r: r.update(event="pull_request_target"),
                   lambda r: r["repository"].update(full_name="outside/repository"),
                   lambda r: r["actor"].update(id=2), lambda r: r["triggering_actor"].update(id=2),
                   lambda r: r.update(head_branch="outside"), lambda r: r.update(path="outside/workflow.yml")]
        lines = self.guard_lines()
        self.assertEqual(len(lines), 10)
        self.assertEqual(len(set(lines)), 10)
        for index, change in enumerate(changes):
            for event in ("workflow_dispatch", "push", "pull_request"):
                if event == "pull_request" and index == 8:
                    continue  # The original branch-name check applies only outside PRs.
                with self.subTest(predicate=index, event=event):
                    authority, run = self.contract(event)
                    change(run)
                    self.assertEqual(self.refusal(authority, run), dict(
                        stage="artifact", predicate="run-provenance", category="ValueError", owned_line=lines[index]))

    def test_queued_completed_cancelled_missing_status_and_invalid_branch_ref_still_refuse(self):
        for status in ("queued", "completed", "cancelled", "waiting", "pending", None, "missing"):
            with self.subTest(status=status):
                authority, run = self.contract()
                if status == "missing":
                    run.pop("status")
                else:
                    run["status"] = status
                self.assertEqual(self.refusal(authority, run)["owned_line"], self.guard_lines()[3])
        authority, run = self.contract()
        authority.environment["GITHUB_REF"] = "refs/tags/approved"
        self.assertEqual(self.refusal(authority, run)["owned_line"], self.guard_lines()[8])

    def test_first_failed_predicate_keeps_short_circuit_before_later_missing_fields(self):
        fields = ["id", "head_sha", "run_attempt", "status", "event", "repository", "actor", "triggering_actor", "head_branch", "path"]
        bad = [124, "c" * 40, 3, "queued", "outside", dict(full_name="outside/repository"),
               dict(id=2), dict(id=2), "outside", "outside.yml"]
        for index, field in enumerate(fields):
            with self.subTest(field=field):
                authority, run = self.contract()
                run[field] = bad[index]
                for later in fields[index + 1:]:
                    run.pop(later)
                self.assertEqual(self.refusal(authority, run)["owned_line"], self.guard_lines()[index])
        authority, run = self.contract()
        run.pop("head_sha")
        with self.assertRaises(KeyError):
            shards.GitHubArtifacts(authority, api=lambda path: run)


class AsanLowMemoryTests(Fixture):
    authority = NativeAdapterTests.authority
    prepared = NativeAdapterTests.prepared

    def build_context(self):
        from contextlib import ExitStack
        stack = ExitStack()
        self.addCleanup(stack.close)
        authority = self.authority()
        images, commands, queries = {}, [], []
        for mode in shards.MODES:
            image = authority.root / (".build/asan" if mode == "address" else ".build/tsan") / "Fake.xctest/Contents/MacOS/Fake"
            image.parent.mkdir(parents=True)
            image.write_bytes(self.image.read_bytes())
            images[mode] = image
        original = authority.output

        def output(command, *args, **kwargs):
            if "--show-bin-path" in command:
                queries.append(command)
                mode = next(value.split("=", 1)[1] for value in command if value.startswith("--sanitize="))
                return str(images[mode].parents[3])
            return original(command, *args, **kwargs)

        def runtime(workspace, mode, image, flags, inputs=None):
            return {**self.runtimes[mode], "flags": list(flags), "image_sha256": shards.legacy.digest(image)}

        def execute(command, workspace, attempt, *args, **kwargs):
            commands.append(command)
            (attempt / "test.log").write_text("\n".join(METHODS) if "list" in command else "fake build complete")
            return 0

        for context in (patch.object(shards.legacy, "ensure_no_live_tests"),
                        patch.object(shards.shutil, "which", return_value="/fake/swift"),
                        patch.object(shards.legacy, "executable_inputs", return_value=self.runtimes["thread"]["inputs"]),
                        patch.object(shards.legacy, "grouping_policy", return_value={"shared_groups": [METHODS[:2]]}),
                        patch.object(authority, "admission", return_value=ADMISSION),
                        patch.object(authority, "output", side_effect=output), patch.object(authority, "runtime", side_effect=runtime),
                        patch.object(shards, "execute_process", side_effect=execute)):
            stack.enter_context(context)
        return authority, shards.NativeBuilder(authority), commands, queries

    def test_only_asan_build_flags_change_and_existing_test_serialization_and_selectors_stay_exact(self):
        address = ["--scratch-path", ".build/asan", "--sanitize=address"]
        thread = ["--scratch-path", ".build/tsan", "--sanitize=thread"]
        low = ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
        self.assertEqual(shards.sanitizer_build_flags("thread"), thread)
        self.assertEqual(shards.sanitizer_build_flags("address"), address + low)
        old = shards.legacy.batch_command("fake-swift", address, "address", self.root, METHODS)
        new = shards.legacy.batch_command("fake-swift", address + low, "address", self.root, METHODS)
        start = new.index("--jobs")
        self.assertEqual(new[start:start + 4], low)
        self.assertEqual(new[:start] + new[start + 4:], old)
        self.assertEqual(new.count("--no-parallel"), 1)
        self.assertIn("--skip-build", new)
        self.assertEqual(shards.legacy.batch_command("fake-swift", thread, "thread", self.root, METHODS),
                         shards.legacy.batch_command("fake-swift", shards.sanitizer_build_flags("thread"), "thread", self.root, METHODS))

    def test_build_only_ready_reuse_and_skip_build_discovery_use_the_identical_profile(self):
        authority, builder, commands, queries = self.build_context()
        for mode in shards.MODES:
            self.assertFalse(builder.build_only(mode, 5)["reused"])
            self.assertTrue(builder.build_only(mode, 5)["reused"])
            with builder.preparation_claim():
                result = builder.build_and_discover(mode)
            self.assertEqual(result[1], METHODS)
            flags = shards.sanitizer_build_flags(mode)
            self.assertEqual(result[0]["flags"], flags)
            self.assertEqual(commands[-2], ["/fake/swift", "build", "--build-tests", *flags])
            self.assertEqual(commands[-1], ["/fake/swift", "test", *flags, "list", "--skip-build"])
            self.assertEqual(queries[-1], ["/fake/swift", "build", *flags, "--show-bin-path"])
            ready = shards.load_json(authority.cache / "build-stage" / HEAD / mode / "ready.json")
            self.assertEqual(ready["runtime"]["flags"], flags)
        self.assertEqual(sum("--build-tests" in command for command in commands), 2)

    def test_ready_checkpoint_with_old_asan_flags_is_refused_before_any_rebuild_or_discovery(self):
        authority, builder, commands, queries = self.build_context()
        builder.build_only("address", 5)
        ready = authority.cache / "build-stage" / HEAD / "address/ready.json"
        value = shards.load_json(ready)
        value["runtime"]["flags"] = ["--scratch-path", ".build/asan", "--sanitize=address"]
        ready.parent.chmod(0o700)
        ready.chmod(0o600)
        shards.durable_json(ready, value)
        shards.seal(ready.parent)
        before = list(commands)
        with self.assertRaisesRegex(ValueError, "Prepared controller build changed"):
            builder.build_only("address", 5)
        with builder.preparation_claim(), self.assertRaisesRegex(ValueError, "checkpoint runtime changed"):
            builder.build_and_discover("address")
        self.assertEqual(commands, before)

    def test_legacy_fallback_build_discovery_and_bin_queries_forward_exact_flags(self):
        for mode in shards.MODES:
            flags = shards.sanitizer_build_flags(mode)
            report = self.root / ("fallback-" + mode)
            report.mkdir()
            image = self.root / mode / "Fake.xctest/Contents/MacOS/Fake"
            image.parent.mkdir(parents=True)
            image.write_bytes(self.image.read_bytes())
            queries = []
            def output(command, *args):
                queries.append(command)
                return "\n".join(METHODS) if "list" in command else str(image.parents[3])
            with patch.object(shards.legacy.subprocess, "run") as never_native, patch.object(
                    shards.legacy, "output", side_effect=output), open(self.root / ("lock-" + mode), "a") as lock:
                actual, methods, _ = shards.legacy.build_and_discover(self.root, "fake-swift", flags, {"LANG": "C"}, lock, report)
            self.assertEqual(actual, image)
            self.assertEqual(methods, METHODS)
            self.assertEqual(never_native.call_args.args[0], ["fake-swift", "build", "--build-tests", *flags])
            self.assertEqual(queries, [["fake-swift", "test", *flags, "list", "--skip-build"],
                                       ["fake-swift", "build", *flags, "--show-bin-path"]])

    def test_flags_bind_existing_plan_shard_and_receipt_identity_without_promoting_old_profile(self):
        old_runtime = {**self.runtimes["address"], "flags": ["--scratch-path", ".build/asan", "--sanitize=address"]}
        new_runtime = {**old_runtime, "flags": shards.sanitizer_build_flags("address")}
        old_plan = shards.make_plan(old_runtime, METHODS)
        new_plan = shards.make_plan(new_runtime, METHODS)
        old_identity = shards.shard_identity(old_runtime, old_plan["shards"][0])
        new_identity = shards.shard_identity(new_runtime, new_plan["shards"][0])
        self.assertNotEqual(shards.fingerprint(old_identity), shards.fingerprint(new_identity))
        self.assertEqual(old_plan["inventory"], new_plan["inventory"])
        self.assertEqual(old_identity["methods"], new_identity["methods"])
        executor = FakeExecutor(self.root / "old-profile-worker", {"address": old_runtime})
        shards.run_shard(old_plan, old_plan["shards"][0]["id"], self.store, executor, HEAD, 5, ADMISSION)
        self.assertIsNotNone(self.store.matching(old_identity))
        self.assertIsNone(self.store.matching(new_identity))
        exported = self.root / "old-profile-artifact"
        checksum = self.store.export(old_identity, exported)
        with self.assertRaises(ValueError):
            shards.Store(self.root / "new-profile-cache").restore_artifact(exported, checksum, new_identity)

    def test_private_executor_keeps_asan_instrumentation_environment_filters_and_skip_build(self):
        authority, builder, builds, calls = self.prepared()
        runtime = builds["address"]["runtime"]
        self.assertEqual(runtime["flags"], shards.sanitizer_build_flags("address"))
        self.assertEqual(builds["thread"]["runtime"]["flags"], shards.sanitizer_build_flags("thread"))
        executor = shards.NativeExecutor(authority, "one")
        executor.verify(runtime)
        plan = shards.make_plan(runtime, METHODS)
        attempt = self.root / "low-memory-execution"
        attempt.mkdir()
        def completed(*args, progress):
            args[6].observed = {"fake": {"sha256": runtime["image_sha256"], "uuid": runtime["image_uuid"]}}
            return 0
        with patch.object(shards, "execute_process", side_effect=completed) as execute, patch.object(
                executor, "unknown_live_helpers", return_value=False):
            self.assertEqual(executor.execute(plan["shards"][0], attempt, 5, []), 0)
        self.assertEqual(execute.call_args.args[0], shards.legacy.batch_command("/fake/swift", runtime["flags"], "address", attempt, METHODS))
        self.assertEqual(execute.call_args.args[5]["ASAN_OPTIONS"], "detect_leaks=0")


class PrerequisiteRawExportTests(unittest.TestCase):
    def fixture(self):
        authority, free, root = ResourceRefusalEvidenceTests.fixture(self, ram=5)
        authority.environment["GITHUB_JOB"] = "native_checks"
        authority.environment.pop("ELITE_RECOVERABLE_REQUEST_MODE")
        return authority, free, root

    def launch(self, authority):
        return dict(head=HEAD, stage="admission", status="not-launched", mode=None,
                    authorization=authority.authorization())

    def assert_raw(self, output):
        manifest = shards.load_json(output / "export.json")
        self.assertEqual((manifest["kind"], manifest["status"]), ("raw-prerequisites", "unqualified"))
        actual = shards.physical_tree(output)
        self.assertEqual(manifest["outputs"], {name: digest for name, digest in actual.items() if name != "export.json"})
        shards.require_sealed(output)
        return manifest

    def test_real_early_admission_refusal_exports_its_exact_bound_raw_sample_without_rerun(self):
        authority, free, root = self.fixture()
        source, output = root / "checks", root / "raw"
        with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=free)) as disk, patch.object(
                shards.legacy, "ensure_no_live_tests"), patch.object(shards, "execute_process") as never, patch("sys.stdout", io.StringIO()):
            with self.assertRaisesRegex(ValueError, "RAM/disk admission reserve"):
                shards.NativeWorkflow(authority).checks(source, 5)
            original = next((authority.cache / "preparation").glob("*/resource-admission.json"))
            raw = original.read_bytes()
            with patch.object(authority, "admission", side_effect=AssertionError("Do not resample during export")):
                shards.NativeWorkflow(authority).export_checks(source, output)
        disk.assert_called_once()
        never.assert_not_called()
        self.assertEqual(len(authority.calls), 2)
        self.assertTrue(source.is_dir())
        self.assertEqual(list(source.iterdir()), [])
        self.assertEqual((output / "preparation" / original.parent.name / original.name).read_bytes(), raw)
        manifest = self.assert_raw(output)
        self.assertEqual((manifest["checks_state"], manifest["checks_binding"]), ("missing", "absent"))
        self.assertEqual((manifest["head"], manifest["role"], manifest["run_id"], manifest["run_attempt"]),
                         (HEAD, "native_checks", "123", "2"))
        self.assertFalse(any(path.name in {"result.json", "index.json", "commit.json", "ready.json"} for path in output.rglob("*")))

    def test_cli_exports_missing_or_empty_checks_as_unqualified_without_sampling_or_execution(self):
        for empty in (False, True):
            with self.subTest(empty=empty):
                authority, free, root = self.fixture()
                source, output = root / "checks", root / "raw"
                if empty:
                    source.mkdir(mode=0o700)
                argv = ["recoverable_shards.py", "workflow-checks-export", "--policy", str(root / "owned-policy.json"),
                        "--input", str(source), "--output", str(output)]
                with patch.object(sys, "argv", argv), patch.object(shards, "NativeAuthority", return_value=authority), patch.object(
                        authority, "admission", side_effect=AssertionError("No admission during export")), patch.object(
                        authority, "output", side_effect=AssertionError("No resource probes")), patch.object(
                        shards, "execute_process") as never, patch("sys.stdout", io.StringIO()):
                    shards.main()
                never.assert_not_called()
                self.assertEqual(self.assert_raw(output)["checks_state"], "missing")
                self.assertEqual(source.exists(), empty)

    def test_bound_partial_cancelled_and_failed_check_files_are_copied_without_rewriting(self):
        for result in (None, {"head": HEAD, "exit_code": 9}):
            with self.subTest(result=result):
                authority, free, root = self.fixture()
                source, output = root / "checks", root / "raw"
                source.mkdir(mode=0o700)
                shards.durable_json(source / "launch.json", self.launch(authority))
                (source / "test.log").write_bytes(b"partial original log\n")
                (source / "result.json.pending-interrupted").write_bytes(b'{"partial":')
                if result is not None:
                    shards.durable_json(source / "result.json", result)
                before = shards.physical_tree(source)
                with patch.object(shards, "execute_process") as never:
                    shards.NativeWorkflow(authority).export_checks(source, output)
                never.assert_not_called()
                self.assertEqual(shards.physical_tree(source), before)
                self.assertEqual(shards.physical_tree(output / "checks"), before)
                manifest = self.assert_raw(output)
                self.assertEqual(manifest["checks_state"], "incomplete" if result is None else "result-recorded")

    def test_foreign_head_role_run_attempt_and_unbound_partial_files_are_excluded(self):
        for field in ("launch-head", "head", "role", "run_id", "run_attempt", "missing-launch"):
            with self.subTest(field=field):
                authority, free, root = self.fixture()
                source, output = root / "checks", root / "raw"
                source.mkdir(mode=0o700)
                foreign = self.launch(authority)
                if field == "launch-head":
                    foreign["head"] = "c" * 40
                elif field != "missing-launch":
                    foreign["authorization"][field] = "foreign"
                if field != "missing-launch":
                    shards.durable_json(source / "launch.json", foreign)
                (source / "test.log").write_text("unbound raw output")
                for name, record in (("foreign", foreign), ("current", self.launch(authority))):
                    path = authority.cache / "preparation" / name
                    path.mkdir(parents=True, mode=0o700)
                    shards.durable_json(path / "launch.json", record if field != "missing-launch" or name == "current" else [])
                    (path / "resource-admission.json").write_text('{"status":"refused"}')
                shards.NativeWorkflow(authority).export_checks(source, output)
                manifest = self.assert_raw(output)
                self.assertEqual((manifest["checks_state"], manifest["checks_binding"]), ("incomplete", "unbound"))
                self.assertFalse((output / "checks").exists())
                self.assertFalse((output / "preparation/foreign").exists())
                self.assertTrue((output / "preparation/current/resource-admission.json").is_file())

    def test_unsafe_or_overlapping_paths_and_foreign_export_roles_are_rejected(self):
        for fault in ("symlink", "writable", "nested-output", "existing-output", "foreign-role"):
            with self.subTest(fault=fault):
                authority, free, root = self.fixture()
                source, output = root / "checks", root / "raw"
                source.mkdir(mode=0o700)
                shards.durable_json(source / "launch.json", self.launch(authority))
                if fault == "symlink":
                    (source / "linked.log").symlink_to(root / "private")
                elif fault == "writable":
                    (source / "launch.json").chmod(0o666)
                elif fault == "nested-output":
                    output = source / "raw"
                elif fault == "existing-output":
                    output.mkdir(mode=0o700)
                else:
                    authority.environment["GITHUB_JOB"] = "prepare_address"
                with self.assertRaises((ValueError, OSError)):
                    shards.NativeWorkflow(authority).export_checks(source, output)

    def test_workflow_retains_raw_make_ci_even_on_failure_and_never_passes_skips(self):
        source = (Path(__file__).resolve().parents[2] / '.github/workflows/recoverable-quality.yml').read_text()
        job = source.split('  native_checks:\n', 1)[1].split('  physical_qualification:\n', 1)[0]
        self.assertLess(job.index('capture-quality.py'), job.index('uses: actions/upload-artifact@'))
        self.assertIn("if: always() && steps.native_guard.outcome == 'success'", job)
        self.assertIn('            reports/', job)
        self.assertNotIn('continue-on-error', job)
        gate = WorkflowTests.workflow_script(self, 'Held, failed or cancelled execution')
        for status in ('failure', 'failed', 'cancelled', 'skipped', 'missing'):
            values = dict(AUTHORIZED='true', FAKES='success', CHECKS=status)
            with self.subTest(status=status), patch.dict(os.environ, values, clear=True), self.assertRaises(AssertionError):
                exec(compile(gate, 'fake-final-gate', 'exec'), {})


class ResourceRefusalEvidenceTests(unittest.TestCase):
    def fixture(self, ram=10, disk=100, cpu_budget=2):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        authority = object.__new__(shards.NativeAuthority)
        authority.root, authority.cache, authority.legacy_cache = root / "controller", root / "cache", root / "legacy"
        authority.cache.mkdir(mode=0o700)
        authority.legacy_cache.mkdir(mode=0o700)
        authority.config = dict(host="fake-host", admission=dict(explicit=1, cpu_budget=cpu_budget,
            ram_reserve=2, peak_per_worker=6, ram_capacity=100, disk_reserve=2, disk_per_worker=20, disk_capacity=200))
        authority.policy = dict(approved_head=HEAD, recoverable_shards=authority.config)
        authority.environment = dict(GITHUB_JOB="prepare_address", GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="2",
                                     RUNNER_NAME="owned-native", ELITE_RECOVERABLE_REQUEST_MODE="address",
                                     GITHUB_STEP_SUMMARY=str(root / "summary"))
        authority.calls = []

        def output(command):
            authority.calls.append(command)
            if command == ["sysctl", "-n", "hw.logicalcpu"]:
                return "4"
            if command == ["vm_stat"]:
                return ("Mach Virtual Memory Statistics: (page size of 1 bytes)\n"
                        f"Pages free: {ram}.\nPages inactive: 0.\nPages speculative: 0.\n")
            raise AssertionError("No additional resource probe is permitted")

        authority.output, authority.snapshot = output, lambda: {}
        return authority, disk, root

    def reports(self, authority):
        return list((authority.cache / "preparation").glob("*/resource-admission.json"))

    def test_ram_disk_cpu_and_zero_headroom_refusals_export_the_exact_sample_without_launch(self):
        for ram, disk, cpu, reasons in ((5, 100, 2, ["ram"]), (10, 10, 2, ["disk"]),
                                       (10, 100, 0.5, ["cpu"]), (2, 2, 2, ["ram", "disk"])):
            with self.subTest(reasons=reasons):
                authority, free, root = self.fixture(ram, disk, cpu)
                log = io.StringIO()
                with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=free)) as sample_disk, patch.object(
                        shards.legacy, "ensure_no_live_tests"), patch.object(shards, "execute_process") as never, patch.object(
                        shards.shutil, "which") as compiler, patch("sys.stdout", log):
                    with self.assertRaises(ValueError):
                        shards.NativeBuilder(authority).build_only("address", 5)
                never.assert_not_called()
                compiler.assert_not_called()
                sample_disk.assert_called_once_with(authority.cache)
                self.assertEqual(authority.calls, [["sysctl", "-n", "hw.logicalcpu"], ["vm_stat"]])
                reports = self.reports(authority)
                self.assertEqual(len(reports), 1)
                record = shards.load_json(reports[0])
                self.assertEqual(record["reasons"], reasons)
                self.assertEqual(record["sample"], dict(explicit=1, cpu_budget=cpu, cpu_observed=4,
                    cpu_budget_configured=cpu, cpu_required=1, ram_available=ram, ram_reserve=2,
                    peak_per_worker=6, ram_capacity=100, ram_required=8, disk_available=disk,
                    disk_reserve=2, disk_per_worker=20, disk_capacity=200, disk_required=22))
                launch = shards.load_json(reports[0].with_name("launch.json"))
                self.assertEqual((launch["head"], launch["mode"], launch["stage"], launch["status"]),
                                 (HEAD, "address", "admission", "not-launched"))
                self.assertEqual(json.loads(log.getvalue())["resource_admission"], record)
                self.assertIn(json.dumps(record["reasons"]), (root / "summary").read_text())
                exported = root / "raw-export"
                shards.NativeWorkflow(authority).export_preparation("address", exported)
                copied = exported / reports[0].parent.name / "resource-admission.json"
                self.assertEqual(shards.load_json(copied), record)
                manifest = shards.load_json(exported / "export.json")
                self.assertEqual(manifest["outputs"][copied.relative_to(exported).as_posix()], shards.legacy.digest(copied))
                shards.require_sealed(exported)
                self.assertFalse(any(path.name in {"index.json", "commit.json", "ready.json", "build.json", "result.json", "child.json"}
                                     for path in exported.rglob("*")))

    def test_partial_sampling_errors_retain_only_completed_measurements_and_original_exception(self):
        for failed in ("cpu", "ram", "disk"):
            authority, free, root = self.fixture()
            original = authority.output
            error = OSError("FAKE_PRIVATE_PROBE_RESPONSE")
            def output(command):
                if (failed == "cpu" and command[0] == "sysctl") or (failed == "ram" and command[0] == "vm_stat"):
                    authority.calls.append(command)
                    raise error
                return original(command)
            authority.output = output
            with patch.object(shards.shutil, "disk_usage", side_effect=error if failed == "disk" else None,
                              return_value=SimpleNamespace(free=free)) as sample_disk, patch("sys.stdout", io.StringIO()):
                try:
                    authority.admission()
                except OSError as actual:
                    self.assertIs(actual, error)
                else:
                    self.fail("Sampling failure must still refuse")
            record = shards.load_json(self.reports(authority)[0])
            self.assertEqual(record["reasons"], ["sample-" + failed])
            self.assertEqual(record["sample"]["cpu_observed"], None if failed == "cpu" else 4)
            self.assertEqual(record["sample"]["ram_available"], 10 if failed == "disk" else None)
            self.assertIsNone(record["sample"]["disk_available"])
            self.assertEqual(sample_disk.call_count, int(failed == "disk"))
            self.assertEqual(len(authority.calls), 1 if failed == "cpu" else 2)
            self.assertNotIn("FAKE_PRIVATE", json.dumps(record))

    def test_success_retains_the_existing_return_and_probe_count_without_failure_artifacts(self):
        authority, free, root = self.fixture()
        with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=free)) as disk, patch("sys.stdout", io.StringIO()) as log:
            admitted = authority.admission()
        self.assertEqual(admitted, {**authority.config["admission"], "cpu_budget": 2, "ram_available": 10, "disk_available": 100})
        self.assertEqual(len(authority.calls), 2)
        disk.assert_called_once()
        self.assertEqual(self.reports(authority), [])
        self.assertEqual(log.getvalue(), "")
        self.assertFalse((root / "summary").exists())

    def test_secret_bearing_exception_text_is_never_formatted_in_new_evidence(self):
        class UnprintableError(ValueError):
            def __str__(self):
                raise AssertionError("Do not format exception text")
        authority, free, root = self.fixture()
        error = UnprintableError("FAKE_PRIVATE_PAYLOAD_TOKEN")
        authority.output = lambda command: (_ for _ in ()).throw(error)
        with patch.object(shards.shutil, "disk_usage") as disk, patch("sys.stdout", io.StringIO()) as log:
            try:
                authority.admission()
            except UnprintableError as actual:
                self.assertIs(actual, error)
        disk.assert_not_called()
        record = shards.load_json(self.reports(authority)[0])
        self.assertEqual(record["category"], "ValueError")
        self.assertNotIn("FAKE_PRIVATE", log.getvalue() + (root / "summary").read_text() + json.dumps(record))
        poisoned = shards.admission_refusal({"ram_available": "FAKE_PRIVATE_VALUE"}, "FAKE_PRIVATE_CPU",
                                            "FAKE_PRIVATE_SAMPLE", "FAKE_PRIVATE_STAGE", error)
        self.assertNotIn("FAKE_PRIVATE", json.dumps(poisoned))
        self.assertEqual(poisoned["reasons"], ["sample-unknown"])

    def test_retention_failure_does_not_replace_the_refusal_or_repeat_a_sample(self):
        authority, free, root = self.fixture(ram=5)
        with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=free)) as disk, patch.object(
                shards, "durable_json", side_effect=OSError("FAKE_PRIVATE_WRITE_ERROR")), patch("sys.stdout", io.StringIO()) as log:
            with self.assertRaisesRegex(ValueError, "RAM/disk admission reserve"):
                authority.admission()
        self.assertEqual(len(authority.calls), 2)
        disk.assert_called_once()
        self.assertFalse(json.loads(log.getvalue())["raw_attempt_retained"])
        self.assertNotIn("FAKE_PRIVATE", log.getvalue())

    def test_invalid_nonfinite_caps_are_null_in_diagnostics_without_changing_refusal(self):
        authority, free, root = self.fixture()
        authority.config["admission"]["ram_capacity"] = float("inf")
        # Keep the fake authorization serializable so this test isolates numeric diagnostic sanitization.
        authority.authorization = lambda: {"schema": 1, "head": HEAD}
        with patch.object(shards.shutil, "disk_usage", return_value=SimpleNamespace(free=free)), patch("sys.stdout", io.StringIO()):
            with self.assertRaises(ValueError):
                authority.admission()
        record = shards.load_json(self.reports(authority)[0])
        self.assertIsNone(record["sample"]["ram_capacity"])
        self.assertEqual(record["reasons"], ["invalid-bound"])
        json.dumps(record, allow_nan=False)


class ActiveArtifactJobTests(unittest.TestCase):
    contract = ArtifactRunProvenanceTests.contract

    def fixture(self, status="queued", event="pull_request", bom=False):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve() / "native-runner"
        root.mkdir(mode=0o700)
        authority, run = self.contract(event)
        authority.environment.update(RUNNER_NAME="owned-native", GITHUB_JOB="prepare_address")
        authority.policy.update(runner_root=str(root))
        authority.policy["recoverable_activation"]["runners"] = {"owned-native": {
            "workspace": str(root / "_work/l337/l337"), "jobs": ["prepare_address"]}}
        run.update(status=status, conclusion=None)
        agent = dict(agentId=49, agentName="owned-native", gitHubUrl="https://github.com/stephenlclarke/l337", workFolder="_work")
        job = dict(id=901, run_id=123, runner_id=49, runner_name="owned-native", head_sha=run["head_sha"],
                   status="in_progress", conclusion=None)
        value = SimpleNamespace(authority=authority, run=run, agent=agent, registration=root / ".runner",
                                jobs=[job], requests=[], pages=None, error=None)

        def publish():
            value.registration.write_bytes((b"\xef\xbb\xbf" if bom else b"") + json.dumps(value.agent).encode())
            value.registration.chmod(0o600)

        def api(path):
            value.requests.append(path)
            base = "repos/stephenlclarke/l337/actions/runs/123"
            if path == base:
                return value.run
            prefix = base + "/attempts/2/jobs?per_page=100&page="
            if not path.startswith(prefix):
                raise ValueError("Only the exact attempt's jobs may corroborate activity")
            if value.error is not None:
                raise value.error
            page = int(path.removeprefix(prefix))
            if value.pages is not None:
                return value.pages[page - 1]
            return dict(total_count=len(value.jobs), jobs=value.jobs[(page - 1) * 100:page * 100])

        value.publish, value.api = publish, api
        publish()
        return value

    def authorize(self, value):
        return shards.GitHubArtifacts(value.authority, api=value.api)

    def refuse(self, value):
        with self.assertRaises(ValueError):
            self.authorize(value)

    def test_queued_waiting_require_the_exact_owned_active_job_and_accept_both_bom_encodings(self):
        for status in ("queued", "waiting"):
            for event in ("pull_request", "push", "workflow_dispatch"):
                for bom in (False, True):
                    with self.subTest(status=status, event=event, bom=bom):
                        value = self.fixture(status, event, bom)
                        raw = value.registration.read_bytes()
                        self.authorize(value)
                        self.assertEqual(value.registration.read_bytes(), raw)
                        self.assertEqual(value.requests, ["repos/stephenlclarke/l337/actions/runs/123",
                            "repos/stephenlclarke/l337/actions/runs/123/attempts/2/jobs?per_page=100&page=1"])
        value = self.fixture("in_progress")
        value.registration.unlink()
        self.authorize(value)
        self.assertEqual(len(value.requests), 1)  # Preserve the original running path without new I/O.

    def test_terminal_unknown_or_concluded_runs_never_request_job_corroboration(self):
        for status in ("completed", "cancelled", "failure", "success", "requested", "pending", "unknown", None, "missing"):
            with self.subTest(status=status):
                value = self.fixture(status)
                if status == "missing":
                    value.run.pop("status")
                self.refuse(value)
                self.assertEqual(len(value.requests), 1)
        for conclusion in ("failure", "success", "cancelled", "missing"):
            value = self.fixture()
            if conclusion == "missing":
                value.run.pop("conclusion")
            else:
                value.run["conclusion"] = conclusion
            self.refuse(value)
            self.assertEqual(len(value.requests), 1)

    def test_wrong_job_run_head_runner_attempt_or_conclusion_cannot_corroborate(self):
        changes = (dict(id=0), dict(id=True), dict(id="901"), dict(run_id=124), dict(run_id=True),
                   dict(runner_id=50), dict(runner_id=True), dict(runner_name="foreign"),
                   dict(head_sha=HEAD), dict(head_sha="c" * 40), dict(run_attempt=1),
                   dict(status="queued"), dict(status="completed"), dict(status="cancelled"),
                   dict(conclusion="failure"), dict(conclusion="success"))
        for change in changes:
            with self.subTest(change=change):
                value = self.fixture()  # PR job head is the source b*, not the synthetic execution a*.
                value.jobs[0].update(change)
                self.refuse(value)
        for missing in ("id", "run_id", "runner_id", "runner_name", "head_sha", "status", "conclusion"):
            value = self.fixture()
            value.jobs[0].pop(missing)
            self.refuse(value)
        value = self.fixture()
        value.authority.environment["GITHUB_RUN_ATTEMPT"] = "1"
        self.refuse(value)
        self.assertEqual(len(value.requests), 1)
        value = self.fixture()
        value.jobs = []
        self.refuse(value)
        value = self.fixture()
        value.jobs.append({**value.jobs[0], "id": 902})
        self.refuse(value)

    def test_owned_registration_identity_paths_modes_and_json_remain_mandatory(self):
        changes = (dict(agentId=0), dict(agentId=-1), dict(agentId=True), dict(agentId="49"),
                   dict(agentName="foreign"), dict(gitHubUrl="https://github.com/foreign/repo"), dict(workFolder="other"))
        for change in changes:
            value = self.fixture()
            value.agent.update(change)
            value.publish()
            self.refuse(value)
        for fault in ("missing-id", "missing-file", "malformed", "invalid-utf8", "double-bom", "writable-file", "writable-parent", "symlink", "foreign-owner", "changed-during-read"):
            with self.subTest(fault=fault):
                value = self.fixture()
                if fault == "missing-id":
                    value.agent.pop("agentId")
                    value.publish()
                elif fault == "missing-file":
                    value.registration.unlink()
                elif fault in ("malformed", "invalid-utf8", "double-bom"):
                    value.registration.write_bytes({"malformed": b"{", "invalid-utf8": b"\xff", "double-bom": b"\xef\xbb\xbf\xef\xbb\xbf{}"}[fault])
                elif fault == "writable-file":
                    value.registration.chmod(0o622)
                elif fault == "writable-parent":
                    value.registration.parent.chmod(0o722)
                    self.addCleanup(value.registration.parent.chmod, 0o700)
                elif fault == "symlink":
                    saved = value.registration.with_name("saved.json")
                    value.registration.rename(saved)
                    value.registration.symlink_to(saved)
                elif fault == "foreign-owner":
                    with patch.object(shards.native_runner, "require_owned_activation_file", side_effect=ValueError("foreign owner")):
                        self.refuse(value)
                    continue
                else:
                    original = value.api
                    def replace(path):
                        response = original(path)
                        if "/jobs?" in path:
                            value.agent["agentId"] = 50
                            value.publish()
                        return response
                    value.api = replace
                self.refuse(value)
        value = self.fixture()
        value.authority.environment["ELITE_RUNNER_REGISTRATION"] = "/untrusted/.runner"
        value.registration.unlink()
        self.refuse(value)  # No environment-supplied registration location is consulted.

    def test_complete_pagination_rejects_duplicates_truncation_inconsistency_and_bounds(self):
        value = self.fixture()
        queued = [dict(id=1000 + i, status="queued", runner_id=0) for i in range(100)]
        value.jobs = queued + value.jobs
        self.authorize(value)
        self.assertEqual(len(value.requests), 3)
        for fault in ("duplicate", "duplicate-page", "ambiguous-later", "truncated-first", "truncated-last", "inconsistent-total", "over-limit", "malformed", "elapsed"):
            with self.subTest(fault=fault):
                value = self.fixture()
                jobs = queued + value.jobs
                value.pages = [dict(total_count=101, jobs=deepcopy(jobs[:100])), dict(total_count=101, jobs=deepcopy(jobs[100:]))]
                if fault == "duplicate":
                    value.pages[1]["jobs"][0]["id"] = queued[0]["id"]
                elif fault == "duplicate-page":
                    value.pages[1]["jobs"] = value.pages[0]["jobs"]
                elif fault == "ambiguous-later":
                    value.pages[0]["jobs"][0] = deepcopy(value.jobs[0])
                    value.pages[1]["jobs"][0]["id"] = 902
                elif fault == "truncated-first":
                    value.pages[0]["jobs"].pop()
                elif fault == "truncated-last":
                    value.pages[1]["jobs"] = []
                elif fault == "inconsistent-total":
                    value.pages[1]["total_count"] = 102
                elif fault == "over-limit":
                    value.pages[0]["total_count"] = 1601
                elif fault == "malformed":
                    value.pages[0] = dict(total_count=True, jobs=[])
                else:
                    with patch.object(shards.time, "monotonic", side_effect=[0, 0, 121]):
                        self.refuse(value)
                    continue
                self.refuse(value)
        value = self.fixture()
        value.jobs = [dict(id=1000 + i, status="queued", runner_id=0) for i in range(1599)] + value.jobs
        self.authorize(value)
        self.assertEqual(len(value.requests), 17)  # One run request plus the sixteen bounded job pages.

    def test_api_failures_refuse_without_logging_or_retry(self):
        for error in (OSError("FAKE_PRIVATE_API_PAYLOAD"), ValueError("FAKE_PRIVATE_API_PAYLOAD"),
                      subprocess.CalledProcessError(1, ["FAKE_PRIVATE_TOKEN"], output="FAKE_PRIVATE_BODY"),
                      subprocess.TimeoutExpired(["FAKE_PRIVATE_TOKEN"], 60)):
            value = self.fixture()
            value.error = error
            try:
                self.authorize(value)
            except ValueError as refused:
                record = shards.native_runner.authorization_failure(refused)
            else:
                self.fail("An API failure cannot authorize activity")
            self.assertEqual(len(value.requests), 2)
            self.assertNotIn("FAKE_PRIVATE", json.dumps(record))
            self.assertEqual(record["predicate"], "run-provenance")

    def test_nine_run_identity_guards_still_refuse_with_valid_active_job_evidence(self):
        changes = (lambda r: r.update(id=124), lambda r: r.update(head_sha="c" * 40), lambda r: r.update(run_attempt=3),
                   lambda r: r.update(event="outside"), lambda r: r["repository"].update(full_name="outside/repo"),
                   lambda r: r["actor"].update(id=2), lambda r: r["triggering_actor"].update(id=2),
                   lambda r: r.update(head_branch="outside"), lambda r: r.update(path="outside.yml"))
        for change in changes:
            value = self.fixture(event="push")
            change(value.run)
            self.refuse(value)

    def test_registration_changes_bind_authorization_without_changing_native_environment_or_identity(self):
        value = self.fixture()
        controller = object.__new__(shards.NativeAuthority)
        controller.environment = value.authority.environment
        controller.config = dict(host="fake-host", admission=ADMISSION)
        original_environment = deepcopy(controller.environment)
        child = controller.execution_environment()
        runtime = shards.legacy.runtime_identity(child)
        for agent_id in (49, 50):
            value.agent["agentId"] = agent_id
            value.publish()
            value.jobs[0]["runner_id"] = agent_id
            self.authorize(value)
            self.assertEqual(controller.environment, original_environment)
            self.assertEqual(controller.execution_environment(), child)
            self.assertEqual(shards.legacy.runtime_identity(controller.execution_environment()), runtime)
            value.jobs[0]["runner_id"] = agent_id + 1
            self.refuse(value)


class GranularityTests(Fixture):
    authority = NativeAdapterTests.authority
    prepared = NativeAdapterTests.prepared
    workflow_script = WorkflowTests.workflow_script

    def test_bounded_packing_breaks_96_id_collection_but_preserves_whole_shared_cohort(self):
        counts = [4, 5, 4, 2, 9, 5, 5, 10, 3, 4, 4, 5, 3, 2, 3, 2, 1, 8, 10, 7]
        self.assertEqual(sum(counts), 96)
        methods = [f"L337CoreTests.Cohort{i}/case{j}()" for i, count in enumerate(counts) for j in range(count)]
        # Cohort8 is the three-case AppKit consumer; its actual shared-process contract is retained.
        appkit = [m for m in methods if m.startswith("L337CoreTests.Cohort8/")]
        appkit += [f"L337CoreTests.SharedAppKit/case{j}()" for j in range(167)]
        full = sorted(set(methods + appkit))
        plan = shards.make_plan(self.runtimes["address"], full, [appkit], max_methods=shards.PACKED_ID_TARGET)
        reverse = shards.make_plan(self.runtimes["address"], list(reversed(full)), [appkit], max_methods=shards.PACKED_ID_TARGET)
        self.assertEqual(plan, reverse)
        self.assertEqual(sorted(m for row in plan["shards"] for m in row["methods"]), full)
        self.assertIn(sorted(appkit), [row["methods"] for row in plan["shards"]])
        self.assertTrue(all(len(row["methods"]) <= shards.PACKED_ID_TARGET or len(row["atoms"]) == 1 for row in plan["shards"]))
        self.assertTrue(all(row["methods"] != sorted(methods) for row in plan["shards"]))
        complete = shards.workflow_manifest([plan], ["one"], self.store, HEAD)
        self.assertTrue(all(entry["label"].endswith(entry["shard"][:8]) for entry in complete["matrix"]["include"]))

    def test_indivisible_timeout_is_explicit_blocker_instead_of_automatic_replay(self):
        methods = [f"L337CoreTests.Indivisible/case{i}()" for i in range(3)]
        plan = shards.make_plan(self.runtimes["thread"], methods)
        self.executor.exit_code = 124
        self.executor.damage = lambda attempt: shards.durable_json(attempt / "timeout.json", {
            "schema": shards.SCHEMA, "seconds": 5, "reason": "process wait deadline"})
        with self.assertRaises(ValueError):
            self.run_one(plan)
        self.assertEqual(self.executor.calls, 1)
        self.executor.exit_code = 0
        with self.assertRaisesRegex(ValueError, "Indivisible cohort.*no automatic replay"):
            self.run_one(plan)
        self.assertEqual(self.executor.calls, 1)
        self.assertTrue(list((self.store.root / "attempts").glob("*/*/failure.json")))

    def test_authenticated_timeout_survives_cache_loss_and_blocks_only_same_identity_and_bound(self):
        methods = [f"L337CoreTests.Indivisible/case{i}()" for i in range(3)]
        plan = shards.make_plan(self.runtimes["thread"], methods)
        identity = shards.shard_identity(plan["runtime"], plan["shards"][0])
        self.executor.exit_code = 124
        self.executor.damage = lambda attempt: shards.durable_json(attempt / "timeout.json", {
            "schema": shards.SCHEMA, "seconds": 5, "reason": "process wait deadline"})
        with self.assertRaises(ValueError):
            self.run_one(plan)
        exported = self.root / "timeout-export"
        self.store.export_outcome(identity, exported)
        payload = WorkflowTests.archive(self, {p.relative_to(exported).as_posix(): p.read_bytes() for p in exported.rglob("*") if p.is_file()})
        authority = self.authority()
        remote, _ = WorkflowTests.remote(self, authority, payload, "native-shard-thread-" + plan["shards"][0]["id"] + "-1")
        fresh = shards.Store(self.root / "fresh-after-cache-loss")
        self.assertFalse(remote.restore_shard(plan, plan["shards"][0], fresh))
        executor = FakeExecutor(self.root / "fresh-worker", self.runtimes)
        with self.assertRaisesRegex(ValueError, "Indivisible cohort.*no automatic replay"):
            shards.run_shard(plan, plan["shards"][0]["id"], fresh, executor, HEAD, 5, ADMISSION)
        self.assertEqual(executor.calls, 0)
        self.assertIsNone(fresh.matching(identity))
        # A second cache loss still has the blocker, not a passed receipt.
        again = self.root / "timeout-reexport"
        fresh.export_outcome(identity, again)
        self.assertTrue((again / "last-attempt/timeout.json").is_file())
        self.assertFalse((again / "index.json").exists())
        changed_bound = shards.run_shard(plan, plan["shards"][0]["id"], fresh, executor, HEAD, 6, ADMISSION)
        self.assertFalse(changed_bound["reused"])
        self.assertEqual(executor.calls, 1)
        changed = shards.make_plan({**plan["runtime"], "image_sha256": "f" * 64}, methods)
        wrong = shards.Store(self.root / "wrong-identity")
        self.assertFalse(remote.restore_shard(changed, changed["shards"][0], wrong))
        changed_identity = shards.shard_identity(changed["runtime"], changed["shards"][0])
        with self.assertRaises(ValueError):
            wrong.restore_failure(exported, changed_identity)
        self.assertFalse((wrong.root / "timeout-blockers").exists())
        ordinary = shards.Store(self.root / "ordinary-failure")
        failed = FakeExecutor(self.root / "ordinary-worker", self.runtimes)
        failed.exit_code = 1
        with self.assertRaises(ValueError):
            shards.run_shard(plan, plan["shards"][0]["id"], ordinary, failed, HEAD, 5, ADMISSION)
        raw = self.root / "ordinary-export"
        ordinary.export_outcome(identity, raw)
        other_payload = WorkflowTests.archive(self, {p.relative_to(raw).as_posix(): p.read_bytes() for p in raw.rglob("*") if p.is_file()})
        other_remote, _ = WorkflowTests.remote(self, authority, other_payload, "native-shard-thread-" + plan["shards"][0]["id"] + "-2")
        retry = shards.Store(self.root / "ordinary-retry")
        self.assertFalse(other_remote.restore_shard(plan, plan["shards"][0], retry))
        normal_executor = FakeExecutor(self.root / "ordinary-retry-worker", self.runtimes)
        shards.run_shard(plan, plan["shards"][0]["id"], retry, normal_executor, HEAD, 5, ADMISSION)
        self.assertEqual(normal_executor.calls, 1)

    def test_each_mode_prepares_and_loads_without_other_mode_and_aggregate_requires_both(self):
        authority, builder, builds, calls = self.prepared()
        for mode in shards.MODES:
            destination = authority.cache / "builds" / HEAD / mode
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copytree(self.root / ("frozen-" + mode), destination)
        class Remote:
            def artifacts(self, prefix):
                raise AssertionError("Already prepared mode must not request another mode")
        workflow = shards.NativeWorkflow(authority, Remote())
        output = self.root / "thread-only"
        result = workflow.prepare(output, ("thread",))
        plans, manifest = workflow.plans(output, result["manifest_sha256"])
        self.assertEqual(set(manifest["plans"]), {"thread"})
        self.assertTrue(all(row["mode"] == "thread" for row in manifest["pending"]))
        self.assertEqual(calls, ["thread", "address"])
        with self.assertRaises(ValueError):
            workflow.aggregate(plans)

    def test_split_build_discovery_reuses_verified_build_and_retains_timeout_raw_data(self):
        authority, builder, builds, calls = self.prepared()
        original_output = authority.output
        def output(command, *args, **kwargs):
            if "--show-bin-path" in command:
                return str(Path(builds["thread"]["image"]).parents[3])
            return original_output(command, *args, **kwargs)
        commands = []
        def execute(command, workspace, attempt, *args, **kwargs):
            commands.append(command)
            (attempt / "test.log").write_text("\n".join(METHODS) if "list" in command else "build completed")
            return 124 if "--sanitize=address" in command else 0
        with patch.object(authority, "output", side_effect=output), patch.object(shards, "execute_process", side_effect=execute):
            self.assertFalse(builder.build_only("thread", 5)["reused"])
            self.assertTrue(builder.build_only("thread", 5)["reused"])
            with builder.preparation_claim():
                discovered = builder.build_and_discover("thread")
            self.assertEqual(discovered[1], METHODS)
            self.assertEqual(sum("--build-tests" in command for command in commands), 1)
            self.assertTrue(all("--skip-build" in command for command in commands if "list" in command))
            with self.assertRaises(ValueError):
                builder.build_only("address", 5)
        self.assertFalse((authority.cache / "build-stage" / HEAD / "address/ready.json").exists())
        target = self.root / "preparation-failure-export"
        shards.NativeWorkflow(authority).export_preparation("address", target)
        self.assertTrue(list(target.glob("*/test.log")))
        shards.require_sealed(target)
        self.assertEqual(calls, ["thread", "address"])

    def test_progress_counts_only_valid_complete_receipts_and_reports_oversized_limit(self):
        path = self.root / "step-summary"
        with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(path)}), patch.object(shards.legacy, "progress"):
            before = shards.report_progress(self.plan, self.store, "starting", self.plan["shards"][0])
            self.assertEqual(before["completed"], 0)
            self.run_one()
            after = shards.report_progress(self.plan, self.store, "completed", self.plan["shards"][0])
            self.assertEqual(after["completed"], 1)
            methods = [f"L337CoreTests.Huge/case{i}()" for i in range(70)]
            huge = shards.make_plan(self.runtimes["thread"], methods, max_methods=shards.PACKED_ID_TARGET)
            record = shards.report_progress(huge, self.store, "timed out", huge["shards"][0])
            self.assertTrue(record["indivisible_over_target_ids"])
            self.assertEqual(record["completed"], 0)
        self.assertIn("No method split", path.read_text())
        self.assertIn("1/1 complete", path.read_text())

    def test_future_ci_preserves_required_name_and_real_normal_leak_gates(self):
        root = Path(__file__).resolve().parents[2]
        ci = (root / '.github/workflows/ci.yml').read_text()
        workflow = (root / '.github/workflows/recoverable-quality.yml').read_text()
        make = (root / 'Makefile').read_text()
        self.assertIn('uses: ./.github/workflows/recoverable-quality.yml', ci)
        self.assertIn('name: quality', ci)
        self.assertIn('test "$COMPONENTS" = success', ci)
        targets = make.split('\nci: ', 1)[1].split('\n', 1)[0].split()
        self.assertIn('coverage-check', targets)
        self.assertIn('leaks', targets)
        self.assertNotIn('threads', targets)
        self.assertNotIn('address', targets)
        self.assertIn('make sonar', workflow)
        self.assertLess(workflow.index('Require every job outcome before authoritative main analysis'), workflow.index('make sonar'))
        self.assertNotIn('--other-digest', workflow)
        self.assertIn('python3 Tools/CI/capture-quality.py', workflow)
        self.assertIn("github.ref == 'refs/heads/main'", workflow)


    def test_aggregate_failure_is_retained_without_fabricated_pass_or_missing_mode_acceptance(self):
        authority = self.authority()
        workflow = shards.NativeWorkflow(authority)
        output = self.root / "aggregate-failed"
        with self.assertRaises(ValueError):
            workflow.aggregate_report([], output)
        receipt = shards.load_json(output / "result.json")
        self.assertEqual(receipt["status"], "failed")
        self.assertNotIn("result", receipt)
        shards.require_sealed(output)


class AsanTestMemoryTests(Fixture):
    def test_address_caps_all_planning_inputs_and_preserves_full_atomic_union(self):
        solo = [f"L337CoreTests.C{i}/one()" for i in range(80)]
        big = [f"L337CoreTests.Big/case{i}()" for i in range(170)]
        salvage = [f"L337CoreTests.Salvage{i}/one()" for i in range(13)]
        methods = sorted(solo + big + salvage)
        for target in (None, 16, 64, 500):
            plan = shards.make_plan(self.runtimes["address"], methods, [big, salvage], max_methods=target)
            self.assertEqual(sorted(m for row in plan["shards"] for m in row["methods"]), methods)
            self.assertIn(sorted(big), [row["methods"] for row in plan["shards"]])
            self.assertTrue(any(set(salvage) <= set(row["methods"]) for row in plan["shards"]))
            self.assertTrue(all(len(row["methods"]) <= 16 or len(row["atoms"]) == 1 for row in plan["shards"]))
            shards.workflow_manifest([plan], ["one"], self.store, HEAD)
        # Identical inventory/weights in thread mode retains the existing 64-ID packing.
        thread = shards.make_plan(self.runtimes["thread"], solo,
            history=shards.workflow_history(solo, "thread", []), max_methods=64)
        self.assertEqual(sorted(len(row["methods"]) for row in thread["shards"]), [16, 64])

    def test_untrusted_old_packed_address_plan_is_refused_even_with_rehashed_identity(self):
        methods = [f"L337CoreTests.C{i}/one()" for i in range(40)]
        thread = shards.make_plan(self.runtimes["thread"], methods,
            history=shards.workflow_history(methods, "thread", []), max_methods=64)
        self.assertEqual(len(thread["shards"]), 1)
        thread["runtime"] = self.runtimes["address"]
        for row in thread["shards"]:
            row["id"] = shards.fingerprint(shards.shard_identity(thread["runtime"], row))
        with self.assertRaisesRegex(ValueError, "ASAN packing"):
            shards.validate_plan(thread)

    def monitor(self, mode="address", budget=4096):
        workspace = self.root / ("memory-worker-" + mode)
        image = workspace / ".build/fake.xctest/Contents/MacOS/L337CoreTests"
        image.parent.mkdir(parents=True, mode=0o700)
        image.write_bytes(self.image.read_bytes())
        uuids = {"fake-arm64": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
        runtime = {**self.runtimes[mode], "image_uuid": shards.fingerprint(uuids)}
        root = dict(parent=1, group=10, state="S", start="root", command="/fake/swift test", rss_bytes=1024)
        helper = dict(parent=10, group=20, state="S", start="helper", rss_bytes=2048,
            command=f"/fake/swiftpm-testing-helper --test-bundle-path {image} {image} --testing-library swift-testing")
        rows = {10: root, 20: helper}
        authority = SimpleNamespace(config={"admission": {"peak_per_worker": budget}},
                                    snapshot=lambda **kwargs: deepcopy(rows))
        attempt = self.root / ("memory-attempt-" + mode)
        attempt.mkdir(mode=0o700)
        monitor = shards.NativeMonitor(authority, attempt, workspace, runtime, image)
        monitor.known[10] = deepcopy(root)
        self.uuid_patch = patch.object(shards, "image_uuids", return_value={"uuids": uuids})
        self.uuid_patch.start()
        self.addCleanup(self.uuid_patch.stop)
        return monitor, rows

    def test_resident_parser_uses_kib_preserves_ownership_and_rejects_missing_or_duplicate(self):
        original = "10 1 10 S Wed Oct 28 10:00:00 2026 /fake/swift test\n"
        resident = original.replace("2026 /", "2026 123 /")
        parsed = shards.process_rows(resident, resident=True)[10]
        self.assertEqual(parsed.pop("rss_bytes"), 123 * 1024)
        self.assertEqual(parsed, shards.process_rows(original)[10])
        for bad in ("", original, resident + resident, resident.replace("123", "-1"),
                    resident.replace("123", "nan"), "truncated"):
            with self.assertRaises(ValueError):
                shards.process_rows(bad, resident=True)

    def test_high_water_sums_only_fresh_owned_descendants_and_retains_last_sample(self):
        monitor, rows = self.monitor()
        rows[90] = {**rows[10], "parent": 1, "start": "unrelated", "rss_bytes": 10**12}
        monitor.observe()
        self.assertEqual(monitor.memory["high_water_bytes"], 3072)
        rows[20]["rss_bytes"] = 512
        monitor.observe()
        self.assertEqual(monitor.memory["last_bytes"], 1536)
        self.assertEqual(monitor.memory["high_water_bytes"], 3072)
        # A reused PID, plus its new children, cannot enter the retained owned tree.
        rows[20] = {**rows[20], "parent": 1, "start": "reused", "rss_bytes": 10**12}
        rows[21] = {**rows[20], "parent": 20}
        monitor.observe()
        rows.clear()
        self.assertTrue(monitor.finish(False))
        record = shards.load_json(monitor.attempt / "processes.json")
        self.assertEqual(record["resident_memory"]["high_water_bytes"], 3072)
        self.assertEqual(record["resident_memory"]["helper_samples"], 2)
        self.assertFalse(record["running"])

    def test_budget_refusal_retains_evidence_progress_and_cleans_only_reverified_identities(self):
        monitor, rows = self.monitor(budget=3071)
        monitor.observe()
        self.assertEqual(monitor.memory["high_water_bytes"], 3072)
        self.assertIn("exceeds budget", monitor.memory["failure"])
        # Simulate PID reuse between accounting and termination; use the real cleanup guard.
        rows[20] = {**rows[20], "parent": 1, "start": "reused"}
        sent = []
        from crash_artifacts import cleanup_owned_identity
        def safe_cleanup(identity, snapshot):
            def signal_owned(pid, signum):
                sent.append((pid, signum))
                rows.pop(pid)
            cleanup_owned_identity(identity, snapshot, send_signal=signal_owned)
        with patch.object(shards, "cleanup_owned_identity", side_effect=safe_cleanup), patch.object(shards.legacy, "progress"):
            self.assertTrue(monitor.cleanup_memory_failure(monitor.known))
        self.assertEqual([pid for pid, _ in sent], [10])
        record = shards.load_json(monitor.attempt / "processes.json")["resident_memory"]
        self.assertEqual(record["budget_bytes"], 3071)
        self.assertEqual(record["samples"], 1)
        self.assertIn("exceeds budget", record["failure"])
        self.assertFalse(monitor.finish(True))

    def test_initial_budget_refusal_stops_owned_child_and_preserves_failed_exit(self):
        monitor, rows = self.monitor(budget=3071)
        rows[os.getpid()] = dict(parent=1, group=1, state="S", start="controller", command="fake controller")
        cleaned = []
        def cleanup(identity, snapshot):
            self.assertTrue(shards.same_process(identity, snapshot().get(identity["pid"])))
            cleaned.append(identity["pid"])
            rows.pop(identity["pid"])
        process = SimpleNamespace(pid=10, returncode=0, wait=lambda timeout=None: 0, poll=lambda: 0)
        with patch.object(shards.subprocess, "Popen", return_value=process) as spawn, patch.object(
                shards, "cleanup_owned_identity", side_effect=cleanup), patch.object(shards.legacy, "progress"):
            code = shards.execute_process(["/fake/swift", "test"], monitor.workspace, monitor.attempt,
                                           5, [], {}, monitor, isolate_environment=False)
        self.assertEqual(code, 125)
        self.assertEqual(cleaned, [10, 20])
        spawn.assert_called_once()
        self.assertEqual(shards.load_json(monitor.attempt / "child-exit.json")["exit_code"], 125)
        record = shards.load_json(monitor.attempt / "processes.json")
        self.assertFalse(record["running"])
        self.assertEqual(record["resident_memory"]["high_water_bytes"], 3072)
        self.assertIn("exceeds budget", record["resident_memory"]["failure"])

    def test_missing_rss_and_sampling_errors_fail_closed_with_raw_evidence(self):
        monitor, rows = self.monitor()
        rows[20].pop("rss_bytes")
        with patch.object(shards.legacy, "progress") as progress:
            monitor.observe()
        self.assertIn("incomplete", monitor.memory["failure"])
        self.assertTrue(progress.called)
        self.assertEqual(shards.load_json(monitor.attempt / "processes.json")["resident_memory"], monitor.memory)
        monitor.authority.snapshot = lambda **kwargs: (_ for _ in ()).throw(ValueError("fake ps failure"))
        with self.assertRaises(ValueError):
            monitor.observe()
        self.assertTrue(monitor.errors)

    def test_background_sampler_refuses_growth_and_joins_before_final_evidence(self):
        monitor, rows = self.monitor()
        rows[os.getpid()] = dict(parent=1, group=1, state="S", start="controller", command="fake controller")
        stopped, cleaned = threading.Event(), []
        def cleanup(identity, snapshot):
            self.assertTrue(shards.same_process(identity, snapshot().get(identity["pid"])))
            cleaned.append(identity["pid"])
            rows.pop(identity["pid"])
            if identity["pid"] == 20:
                stopped.set()
        with patch.object(shards, "cleanup_owned_identity", side_effect=cleanup), patch.object(shards.legacy, "progress"):
            monitor.start(10)
            rows[20]["rss_bytes"] = 4096
            try:
                self.assertTrue(stopped.wait(2), "fake sampler did not terminate its over-budget tree")
            finally:
                self.assertFalse(monitor.finish(True))
        self.assertEqual(cleaned, [10, 20])
        self.assertFalse(monitor.thread.is_alive())
        memory = shards.load_json(monitor.attempt / "processes.json")["resident_memory"]
        self.assertGreaterEqual(memory["samples"], 2)
        self.assertEqual(memory["high_water_bytes"], 5120)

    def test_snapshot_failure_retains_reason_and_cleanup_still_rechecks_fresh_identity(self):
        monitor, rows = self.monitor()
        def snapshot(resident=False):
            if resident:
                raise ValueError("fake missing resident column")
            return deepcopy(rows)
        monitor.authority.snapshot = snapshot
        with patch.object(shards.legacy, "progress"):
            with self.assertRaises(ValueError):
                monitor.observe()
        self.assertEqual(monitor.memory["failure"], "snapshot ValueError")
        self.assertEqual(shards.load_json(monitor.attempt / "processes.json")["resident_memory"], monitor.memory)
        from crash_artifacts import cleanup_owned_identity
        sent = []
        def cleanup(identity, fresh_snapshot):
            def signal_owned(pid, signum):
                sent.append(pid)
                rows.pop(pid)
            cleanup_owned_identity(identity, fresh_snapshot, send_signal=signal_owned)
        with patch.object(shards, "cleanup_owned_identity", side_effect=cleanup):
            self.assertTrue(monitor.cleanup_memory_failure(monitor.known))
        self.assertEqual(sent, [10])

    def test_authority_resident_snapshot_requests_one_ps_sample_without_changing_default(self):
        line = "10 1 10 S Wed Oct 28 10:00:00 2026 123 /fake/swift test"
        calls = []
        def output(command):
            calls.append(command)
            return line if "rss=" in command[-1] else line.replace("2026 123", "2026")
        authority = SimpleNamespace(output=output)
        self.assertEqual(shards.NativeAuthority.snapshot(authority, resident=True)[10]["rss_bytes"], 123*1024)
        self.assertNotIn("rss_bytes", shards.NativeAuthority.snapshot(authority)[10])
        self.assertEqual(calls, [["ps", "-axo", "pid=,ppid=,pgid=,stat=,lstart=,rss=,command="],
                                 ["ps", "-axo", "pid=,ppid=,pgid=,stat=,lstart=,command="]])

    def test_no_helper_resident_observation_cannot_qualify(self):
        monitor, rows = self.monitor()
        rows.pop(20)
        monitor.observe()
        rows.clear()
        with patch.object(shards.legacy, "progress"):
            self.assertFalse(monitor.finish(False))
        self.assertEqual(monitor.memory["failure"], "no resident helper sample")

    def test_non_address_monitor_never_requests_resident_or_adds_memory_evidence(self):
        monitor, rows = self.monitor(mode="thread")
        for row in rows.values():
            row.pop("rss_bytes")
        monitor.authority.snapshot = lambda: deepcopy(rows)
        monitor.observe()
        rows.clear()
        self.assertTrue(monitor.finish(False))
        self.assertIsNone(monitor.memory)
        self.assertNotIn("resident_memory", shards.load_json(monitor.attempt / "processes.json"))

    def test_fixed_budget_admission_boundary_and_policy_identity_are_real(self):
        gib = 1024**3
        bounds = {**ADMISSION, "explicit": 1, "cpu_budget": 1, "ram_capacity": 8*gib,
                  "ram_reserve": 2*gib, "peak_per_worker": 2*gib, "ram_available": 4*gib}
        self.assertEqual(shards.worker_limit(**bounds), 1)
        with self.assertRaises(ValueError):
            shards.worker_limit(**{**bounds, "ram_available": 4*gib-1})
        with self.assertRaises(ValueError):
            shards.worker_limit(**{**bounds, "ram_available": int(4.6*gib), "peak_per_worker": 4*gib})
        config = {"host": "fake-host", "admission": bounds}
        before = shards.execution_policy_digest(config)
        config["admission"] = {**bounds, "peak_per_worker": 4*gib}
        self.assertNotEqual(before, shards.execution_policy_digest(config))
        plan = shards.make_plan(self.runtimes["address"], METHODS)
        changed = deepcopy(plan["runtime"])
        changed["inputs"]["Tools/CI/recoverable_shards.py"] = "f"*64
        self.assertNotEqual(shards.shard_identity(plan["runtime"], plan["shards"][0]),
                            shards.shard_identity(changed, plan["shards"][0]))


class LocalSanitizerTests(Fixture):
    def controls(self, mode="address", stage="execute", launches=1, extra_environment=None, separate_shards=False,
                 worker_budget=None, physical_home=None):
        import uuid
        directory = self.root / str(uuid.uuid4())
        directory.mkdir(mode=0o700)
        home, repo, controls = physical_home or directory / "home", directory / "source", directory / "controls"
        controls.mkdir(mode=0o700)
        from test_native_runner import owned_control_fixture
        owned_control_fixture(home / "Library/EliteNativeCI")
        (repo / "Tools/CI").mkdir(parents=True, mode=0o700)
        for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                     "quality_phase_checkpoints.py", "crash_artifacts.py"):
            (repo / "Tools/CI" / name).write_bytes((Path(__file__).parent / name).read_bytes())
        gib = 1024**3
        config = dict(schema=1, host="AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", cache=str(directory / "cache"),
            legacy_cache=str(home / "Library/EliteNativeCI/sanitizer-checkpoints"), workers={"one": str(directory / "worker")},
            admission=dict(explicit=1, cpu_budget=1, ram_capacity=20*gib, ram_reserve=2*gib,
                peak_per_worker=2*gib if worker_budget is None else worker_budget,
                disk_capacity=100*gib, disk_reserve=10*gib, disk_per_worker=20*gib))
        environment = {"PATH": "/fake/bin", "DEVELOPER_DIR": "/fixture/Xcode", "LANG": "C", **(extra_environment or {})}
        policy = dict(approved_head=HEAD, developer_dir="/fixture/Xcode", swift="fake Swift", sdk="fake SDK",
            recoverable_shards=config, local_activation=dict(schema=1, kind="local-sanitizer-activation-v1",
                mode=mode, workspace=str(repo), sources={p.name: shards.legacy.digest(p) for p in (repo / "Tools/CI").iterdir()},
                expires_at=10000, inventory_sha256=shards.fingerprint(METHODS), inventory_count=3,
                shard_count=2 if separate_shards else 1,
                environment=shards.legacy.runtime_identity(shards.runtime_child_environment(environment))))
        policy_path = controls / "policy.json"
        self.control_write(policy_path, policy)
        policy_sha = shards.legacy.digest(policy_path)
        child = shards.runtime_child_environment(environment)
        child["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"] = shards.execution_policy_digest(config)
        child[shards.LOCAL_POLICY_ENV] = policy_sha
        phase_environment = dict(child)
        if mode == "address":
            child["ASAN_OPTIONS"] = "detect_leaks=0"
        flags = shards.sanitizer_build_flags(mode)
        if mode == "thread":
            flags += ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
        runtime = {**self.runtimes[mode], "host": config["host"], "environment": shards.legacy.runtime_identity(child),
                   "phase_environment": shards.legacy.runtime_identity(phase_environment), "flags": flags}
        history = ({shards.fingerprint(unit): 600 for unit in shards.legacy.partition(METHODS, mode, 1)}
                   if separate_shards else shards.workflow_history(METHODS, mode, []))
        plan = shards.make_plan(runtime, METHODS, history=history, max_methods=64)
        plan_path = directory / "plan.json"
        shards.durable_json(plan_path, plan)
        session = dict(schema=1, kind="local-sanitizer-session-v1", id=str(uuid.uuid4()), head=HEAD,
            policy_sha256=policy_sha, mode=mode, worker="one", stage=stage, expires_at=9000,
            shards=[row["id"] for row in plan["shards"]] if stage == "execute" else None,
            plan_sha256=None if stage == "prepare" else shards.legacy.digest(plan_path),
            max_launches=0 if stage == "validate" else launches)
        session_path = controls / "session.json"
        self.control_write(session_path, session)
        session_sha = shards.legacy.digest(session_path)
        state = session_path.with_name(session_path.name + ".state.json")
        shards.durable_json(state, dict(schema=1, session_sha256=session_sha, used=0))
        calls = []
        def read(command, workspace, env, descriptors):
            calls.append(command)
            self.assertNotIn("gh", command)
            if command[:3] == ["git", "rev-parse", "HEAD"]:
                return HEAD
            if command[:2] == ["git", "status"]:
                return ""
            if command[0] == "ioreg":
                return '"IOPlatformUUID" = "' + config["host"] + '"'
            if command[:2] == ["sysctl", "-n"]:
                return "Mac14,12"
            if command[0] == "/fake/swift":
                return policy["swift"]
            if command[0] == "xcrun":
                return policy["sdk"]
            raise AssertionError("Unexpected fake command: " + repr(command))
        for item in (patch.object(shards, "__file__", str(repo / "Tools/CI/recoverable_shards.py")),
                     patch.object(shards.time, "time", return_value=100),
                     patch.object(shards.platform, "system", return_value="Darwin"),
                     patch.object(shards.platform, "machine", return_value="arm64"),
                     patch.object(shards.shutil, "which", return_value="/fake/swift"),
                     patch.object(shards.subprocess, "Popen", side_effect=AssertionError("No real native spawn in local fakes")),
                     patch.object(shards.subprocess, "run", side_effect=AssertionError("No real API/native command in local fakes")),
                     patch.object(shards.subprocess, "check_output", side_effect=AssertionError("No real probe in local fakes")),
                     patch.dict(os.environ, environment, clear=True),
                     patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(home)))):
            item.start()
            self.addCleanup(item.stop)
        return SimpleNamespace(policy_path=policy_path, session_path=session_path, session_sha=session_sha,
            policy=policy, session=session, state=state, plan=plan, plan_path=plan_path, environment=environment,
            read=read, calls=calls, home=home)

    @staticmethod
    def control_write(path, value):
        if path.exists():
            path.chmod(0o600)
        path.write_text(json.dumps(value))
        path.chmod(0o400)

    def authority(self, value):
        return shards.LocalAuthority(value.policy_path, value.session_path, value.session_sha,
            value.session["mode"], value.session["stage"], value.environment, value.read)

    def fake_local_executor(self, authority, plan):
        executor = FakeExecutor(authority.workers["one"], {plan["runtime"]["mode"]: plan["runtime"]})
        executor.authority = authority
        def execute(shard, attempt, timeout, descriptors):
            authority.check_session("execute")
            authority.consume_launch()
            executor.calls += 1
            for descriptor in descriptors:
                os.fstat(descriptor)
            shards.child_environment(attempt, authority.environment_for(plan["runtime"]["mode"]))
            shards.durable_json(attempt / "child.json", {"pid": 4242, "command": ["fake"], "started": 100})
            xml(attempt / "tests.xml", shard["methods"])
            (attempt / "test.log").write_text("fake completed\n")
            processes = {"running": False, "workspace": str(authority.workers["one"] / plan["runtime"]["mode"]),
                "root": {"pid": 4242, "start": "fake start"},
                "observed_images": {"fake": {"sha256": plan["runtime"]["image_sha256"], "uuid": plan["runtime"]["image_uuid"]}}}
            processes["resident_memory"] = dict(kind="sampled-owned-process-rss-v1", failure=None,
                mode=plan["runtime"]["mode"], helper_samples=1, samples=1, high_water_bytes=1024,
                budget_bytes=authority.config["admission"]["peak_per_worker"])
            shards.durable_json(attempt / "processes.json", processes)
            shards.durable_json(attempt / "child-exit.json", {"pid": 4242, "exit_code": 0})
            return 0
        executor.execute = execute
        return executor

    def args(self, value, command):
        return SimpleNamespace(command=command, policy=value.policy_path, local_session=value.session_path,
            local_session_digest=value.session_sha, mode=value.session["mode"], timeout=5,
            input=value.plan_path, digest=shards.legacy.digest(value.plan_path),
            output=value.plan_path.with_name("component"))

    def test_both_modes_are_genuinely_local_with_independent_profiles_and_explicit_flags(self):
        for mode in shards.MODES:
            value = self.controls(mode)
            authority = self.authority(value)
            shards.verify_local_plan(authority, value.plan, shards.legacy.digest(value.plan_path))
            shards.validate_authorization(authority.authorization(), value.plan["runtime"])
            child = authority.environment_for(mode)
            self.assertFalse(any(k.startswith(("GITHUB_", "RUNNER_")) for k in child))
            self.assertEqual("ASAN_OPTIONS" in child, mode == "address")
            self.assertNotIn("TSAN_OPTIONS", child)
            self.assertEqual(authority.config["admission"]["peak_per_worker"], 2*1024**3)
            if mode == "thread":
                self.assertEqual(value.plan["runtime"]["flags"], ["--scratch-path", ".build/tsan", "--sanitize=thread",
                                                               "--jobs", "1", "-Xswiftc", "-disable-batch-mode"])
            self.assertFalse(any(c[0] == "gh" for c in value.calls))

    def test_held_activation_and_supplied_github_identities_refuse_before_file_or_probe(self):
        for environment in ({"GITHUB_JOB": "address_shards"}, {"RUNNER_NAME": "pretend"},
                            {"ELITE_RECOVERABLE_CODE_ENABLED": "true"}, {shards.LOCAL_POLICY_ENV: "pretend"}):
            with patch.object(shards, "local_control") as never, self.assertRaises(ValueError):
                shards.LocalAuthority(Path("/missing"), Path("/missing-session"), "a"*64, "address", "execute", environment)
            never.assert_not_called()

        with patch.object(shards, "PHYSICAL_EXECUTION_ENABLED", False), patch.object(shards, "local_control") as never:
            with self.assertRaisesRegex(ValueError, "HELD"):
                shards.LocalAuthority(Path("/missing"), Path("/missing-session"), "a"*64, "thread", "execute", {})
            never.assert_not_called()

    def test_reviewed_tsan_options_are_bound_and_cross_mode_or_unreviewed_options_refuse(self):
        value = self.controls("thread", extra_environment={"TSAN_OPTIONS": "halt_on_error=1"})
        authority = self.authority(value)
        self.assertEqual(authority.environment_for("thread")["TSAN_OPTIONS"], "halt_on_error=1")
        value.calls.clear()
        value.environment["TSAN_OPTIONS"] = "different unreviewed controls"
        with self.assertRaisesRegex(ValueError, "mode environment"):
            self.authority(value)
        self.assertEqual(value.calls, [])
        for mode, option in (("thread", "ASAN_OPTIONS"), ("address", "TSAN_OPTIONS")):
            other = self.controls(mode, extra_environment={option: "cross-mode"})
            with self.assertRaisesRegex(ValueError, "mode environment"):
                self.authority(other)
            self.assertEqual(other.calls, [])

    def test_wrong_source_mode_policy_budget_or_expiry_refuses_before_probes(self):
        for fault in ("head", "mode", "policy", "expiry", "budget", "missing-state", "source"):
            value = self.controls()
            if fault in ("head", "mode", "policy", "expiry"):
                value.session[{"head": "head", "mode": "mode", "policy": "policy_sha256", "expiry": "expires_at"}[fault]] = {
                    "head": "b"*40, "mode": "thread", "policy": "f"*64, "expiry": 99}[fault]
                self.control_write(value.session_path, value.session)
                value.session_sha = shards.legacy.digest(value.session_path)
            elif fault == "budget":
                shards.durable_json(value.state, {"schema": 1, "session_sha256": value.session_sha, "used": 257})
            elif fault == "missing-state":
                value.state.unlink()
            else:
                (Path(value.policy["local_activation"]["workspace"]) / "Tools/CI/crash_artifacts.py").write_text("# changed")
            with self.subTest(fault=fault), self.assertRaises((ValueError, OSError)):
                self.authority(value)
            self.assertEqual(value.calls, [])

    def test_symlink_writable_and_overlapping_controls_never_authorize(self):
        value = self.controls()
        for mode in (0o600, 0o444):
            value.session_path.chmod(mode)
            with self.assertRaises(ValueError):
                self.authority(value)
        value.session_path.chmod(0o400)
        link = value.session_path.with_name("linked-session.json")
        link.symlink_to(value.session_path)
        with self.assertRaises(ValueError):
            shards.LocalAuthority(value.policy_path, link, value.session_sha, "address", "execute", value.environment, value.read)
        inside = Path(value.policy["local_activation"]["workspace"]) / "session.json"
        self.control_write(inside, value.session)
        with self.assertRaisesRegex(ValueError, "overlap"):
            shards.LocalAuthority(value.policy_path, inside, value.session_sha, "address", "execute", value.environment, value.read)
        self.assertEqual(value.calls, [])

    def test_launch_budget_is_durable_missing_exhausted_or_changed_state_cannot_reset(self):
        value = self.controls()
        authority = self.authority(value)
        authority.consume_launch()
        self.assertEqual(shards.load_json(value.state)["used"], 1)
        with self.assertRaisesRegex(ValueError, "exhausted"):
            authority.consume_launch()
        value.state.unlink()
        with self.assertRaises(OSError):
            authority.consume_launch()
        self.assertFalse(value.state.exists())

    def test_session_drift_and_mode_allocation_drift_refuse_reuse(self):
        value = self.controls()
        authority = self.authority(value)
        changed = deepcopy(value.plan)
        changed["runtime"]["environment"][shards.LOCAL_POLICY_ENV] = "f"*64
        for plan, digest in ((changed, value.session["plan_sha256"]), (value.plan, "e"*64)):
            with self.assertRaises(ValueError):
                shards.verify_local_plan(authority, plan, digest)
        value.policy["recoverable_shards"]["admission"]["peak_per_worker"] *= 2
        self.control_write(value.policy_path, value.policy)
        with self.assertRaises(ValueError):
            authority.check_session()

    def test_local_executor_consumes_budget_before_spawn_and_inherits_controller_descriptor(self):
        value = self.controls()
        authority = self.authority(value)
        with shards.file_claim(value.home / "Library/EliteNativeCI/recoverable-control.lock") as control:
            authority.control_descriptors = (control.fileno(),)
            executor = shards.LocalExecutor(authority, "one")
            def refused(*args):
                self.assertEqual(shards.load_json(value.state)["used"], 1)
                self.assertIn(control.fileno(), args[-1])
                raise OSError("fake failed spawn")
            with patch.object(shards.NativeExecutor, "execute", side_effect=refused):
                with self.assertRaises(OSError):
                    executor.execute(value.plan["shards"][0], self.root, 5, [])
                with self.assertRaisesRegex(ValueError, "exhausted"):
                    executor.execute(value.plan["shards"][0], self.root, 5, [])

    def test_local_prepare_uses_existing_separate_build_discovery_and_actual_mode(self):
        for mode in shards.MODES:
            value = self.controls(mode, "prepare")
            authority = self.authority(value)
            args = self.args(value, "local-prepare")
            args.output = value.plan_path.with_name("fresh-plan.json")
            build = {"runtime": value.plan["runtime"], "inventory": METHODS, "shared_groups": []}
            def build_only(m, t):
                self.assertEqual((m, t), (mode, 5))
                os.fstat(authority.control_descriptors[0])
                with self.assertRaises(BlockingIOError), shards.file_claim(value.home / "Library/EliteNativeCI/recoverable-control.lock"):
                    self.fail("The common controller lease must remain held during preparation")
            builder = SimpleNamespace(build_only=build_only, prepare=lambda m, p: build)
            with patch.object(shards, "LocalAuthority", return_value=authority), patch.object(shards, "NativeBuilder", return_value=builder):
                result = shards.local_command(args)
            self.assertEqual(result["plan_sha256"], shards.legacy.digest(args.output))
            self.assertEqual(shards.load_json(value.state)["used"], 1)

    def test_actual_builder_and_discovery_forward_local_controller_descriptor_both_modes(self):
        fixture = AsanLowMemoryTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        authority, builder, commands, queries = fixture.build_context()
        fake_execute = shards.execute_process.side_effect
        with shards.file_claim(self.root / "controller.lock") as control:
            authority.control_descriptors = (control.fileno(),)
            def execute(command, workspace, attempt, timeout, descriptors, *args, **kwargs):
                self.assertIn(control.fileno(), descriptors)
                self.assertEqual(len(descriptors), 2)
                for descriptor in descriptors:
                    os.fstat(descriptor)
                return fake_execute(command, workspace, attempt, timeout, descriptors, *args, **kwargs)
            with patch.object(shards, "execute_process", side_effect=execute) as observed:
                for mode in shards.MODES:
                    builder.build_only(mode, 5)
                    with builder.preparation_claim():
                        builder.build_and_discover(mode)
            self.assertEqual(observed.call_count, 4)

    def test_serial_local_run_and_exact_receipt_reuse_consume_no_extra_launches_both_modes(self):
        for mode in shards.MODES:
            value = self.controls(mode)
            authority = self.authority(value)
            executor = self.fake_local_executor(authority, value.plan)
            admission = {**authority.config["admission"], "ram_available": 20*1024**3, "disk_available": 100*1024**3}
            args = self.args(value, "local-run")
            with patch.object(shards, "LocalAuthority", return_value=authority), patch.object(shards, "LocalExecutor", return_value=executor), patch.object(
                    authority, "admission", return_value=admission), patch.object(shards.legacy, "progress"):
                result = shards.local_command(args)
                reused = shards.local_command(args)
            self.assertEqual(len(result["results"]), 1)
            self.assertTrue(reused["results"][0]["reused"])
            self.assertEqual(executor.calls, 1)
            self.assertEqual(shards.load_json(value.state)["used"], 1)

    def test_local_authorization_cannot_substitute_mode_head_policy_plan_or_github_kind(self):
        value = self.controls()
        authority = self.authority(value)
        record = authority.authorization()
        for malformed in (None, [], "pretend"):
            with self.assertRaises(ValueError):
                shards.validate_authorization(malformed, value.plan["runtime"])
        for field, replacement in (("head", "b"*40), ("mode", "thread"), ("policy_sha256", "f"*64),
                                   ("kind", "validated-control-plane-v1"), ("authorized_at", 9000)):
            altered = deepcopy(record)
            altered[field] = replacement
            with self.subTest(field=field), self.assertRaises(ValueError):
                shards.validate_authorization(altered, value.plan["runtime"])

        for field, replacement in (("plan_sha256", "wrong"), ("max_launches", 0), ("stage", "prepare")):
            altered = deepcopy(record)
            altered["session"][field] = replacement
            altered["session_content_sha256"] = shards.fingerprint(altered["session"])
            with self.subTest(session_field=field), self.assertRaises(ValueError):
                shards.validate_authorization(altered, value.plan["runtime"])

    def test_owned_subset_qualification_does_not_launch_unassigned_shards_or_qualify_full_union(self):
        value = self.controls(separate_shards=True)
        selected = value.plan["shards"][-1]["id"]
        value.session["shards"] = [selected]
        self.control_write(value.session_path, value.session)
        value.session_sha = shards.legacy.digest(value.session_path)
        shards.durable_json(value.state, dict(schema=1, session_sha256=value.session_sha, used=0))
        authority = self.authority(value)
        executor = self.fake_local_executor(authority, value.plan)
        admission = {**authority.config["admission"], "ram_available": 20*1024**3, "disk_available": 100*1024**3}
        with patch.object(shards, "LocalAuthority", return_value=authority), patch.object(shards, "LocalExecutor", return_value=executor), patch.object(
                authority, "admission", return_value=admission), patch.object(shards.legacy, "progress"):
            result = shards.local_command(self.args(value, "local-run"))
        self.assertEqual([r["id"] for r in result["results"]], [selected])
        self.assertEqual(executor.calls, 1)
        validation = self.validation_authority(value)
        with patch.object(shards.NativeExecutor, "verify"), patch.object(shards.NativeExecutor, "unknown_live_helpers", return_value=False):
            with self.assertRaisesRegex(ValueError, "missing/failed"):
                shards.local_component(validation, value.plan, value.session["plan_sha256"], shards.Store(authority.cache),
                                       value.plan_path.with_name("component"))
        authority.session["shards"] = ["e"*64]
        with self.assertRaisesRegex(ValueError, "outside the exact full plan"):
            shards.verify_local_plan(authority, value.plan, value.session["plan_sha256"])
        malformed = {**value.session, "shards": [selected, selected]}
        with self.assertRaisesRegex(ValueError, "unique shard"):
            shards.validate_local_session(malformed)

    def validation_authority(self, value):
        import uuid
        current = SimpleNamespace(**vars(value))
        current.session = {**value.session, "id": str(uuid.uuid4()), "stage": "validate", "max_launches": 0, "shards": None}
        current.session_path = value.session_path.with_name("validate-session.json")
        self.control_write(current.session_path, current.session)
        current.session_sha = shards.legacy.digest(current.session_path)
        current.state = current.session_path.with_name(current.session_path.name + ".state.json")
        shards.durable_json(current.state, dict(schema=1, session_sha256=current.session_sha, used=0))
        return self.authority(current)

    def completed_local(self, mode="address"):
        value = self.controls(mode)
        authority = self.authority(value)
        executor = self.fake_local_executor(authority, value.plan)
        admission = {**authority.config["admission"], "ram_available": 20*1024**3, "disk_available": 100*1024**3}
        store = shards.Store(authority.cache)
        result = shards.run_shard(value.plan, value.plan["shards"][0]["id"], store, executor, HEAD, 5, admission)
        return value, authority, store, Path(result["attempt"])

    def test_component_gates_both_full_mode_unions_and_seals_only_component_qualification(self):
        for mode in shards.MODES:
            value, authority, store, attempt = self.completed_local(mode)
            validation = self.validation_authority(value)
            output = value.plan_path.with_name("component")
            args = self.args(value, "local-validate")
            args.local_session, args.local_session_digest = validation.session_path, validation.session_digest
            with patch.object(shards, "LocalAuthority", return_value=validation), patch.object(shards.NativeExecutor, "verify") as verify, patch.object(
                    shards.NativeExecutor, "unknown_live_helpers", return_value=False):
                result = shards.local_command(args)
            verify.assert_called_once_with(value.plan["runtime"])
            self.assertEqual(result["status"], "qualified")
            self.assertEqual(result["inventory_count"], 3)
            self.assertEqual(result["inventory_sha256"], shards.fingerprint(METHODS))
            self.assertEqual(result["mode"], mode)
            self.assertIn("pending full quality", result["release_status"])
            self.assertEqual(result["sampled_rss_high_water_bytes"], 1024)
            shards.require_sealed(output)
            with self.assertRaises(ValueError), patch.object(shards.NativeExecutor, "verify"), patch.object(
                    shards.NativeExecutor, "unknown_live_helpers", return_value=False):
                shards.local_component(validation, value.plan, value.session["plan_sha256"], store, output)

    def test_component_rejects_missing_tampered_diagnostics_and_unknown_lifecycle(self):
        value = self.controls()
        validation = self.validation_authority(value)
        store = shards.Store(validation.cache)
        output = value.plan_path.with_name("component")
        with patch.object(shards.NativeExecutor, "verify"), patch.object(shards.NativeExecutor, "unknown_live_helpers", return_value=False):
            with self.assertRaisesRegex(ValueError, "missing/failed"):
                shards.local_component(validation, value.plan, value.session["plan_sha256"], store, output)
        self.assertFalse(output.exists())
        for mutation in ("tamper", "unknown"):
            value, authority, store, attempt = self.completed_local()
            validation = self.validation_authority(value)
            if mutation == "tamper":
                (attempt / "test.log").chmod(0o600)
                (attempt / "test.log").write_text("ERROR: AddressSanitizer: fake deliberate diagnostic\n")
                (attempt / "test.log").chmod(0o400)
            with patch.object(shards.NativeExecutor, "verify"), patch.object(
                    shards.NativeExecutor, "unknown_live_helpers", return_value=mutation == "unknown"):
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    shards.local_component(validation, value.plan, value.session["plan_sha256"], store,
                                           value.plan_path.with_name("component"))

    def test_component_rejects_internally_committed_bad_rss_image_and_plan_evidence(self):
        for mutation in ("rss-missing", "rss-over", "rss-zero", "image", "running", "plan"):
            value, authority, store, attempt = self.completed_local()
            validation = self.validation_authority(value)
            attempt.chmod(0o700)
            processes = shards.load_json(attempt / "processes.json")
            if mutation == "rss-missing":
                processes.pop("resident_memory")
            elif mutation == "rss-over":
                processes["resident_memory"]["high_water_bytes"] = processes["resident_memory"]["budget_bytes"] + 1
            elif mutation == "rss-zero":
                processes["resident_memory"]["helper_samples"] = 0
            elif mutation == "image":
                processes["observed_images"]["fake"]["uuid"] = "wrong image"
            elif mutation == "running":
                processes["running"] = True
            else:
                authorization = shards.load_json(attempt / "authorization.json")
                authorization["session"]["plan_sha256"] = "e"*64
                authorization["session_content_sha256"] = shards.fingerprint(authorization["session"])
                shards.durable_json(attempt / "authorization.json", authorization)
            shards.durable_json(attempt / "processes.json", processes)
            # Simulate a source bug that sealed internally consistent but insufficient raw evidence.
            receipt = shards.load_json(attempt / "result.json")
            receipt["outputs"] = shards.evidence_outputs(attempt, value.plan["runtime"], METHODS)
            shards.durable_json(attempt / "result.json", receipt)
            shards.durable_json(attempt / "commit.json", {"schema": 1, "receipt_sha256": shards.legacy.digest(attempt / "result.json")})
            shards.seal(attempt)
            with patch.object(shards.NativeExecutor, "verify"), patch.object(shards.NativeExecutor, "unknown_live_helpers", return_value=False):
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    shards.local_component(validation, value.plan, value.session["plan_sha256"], store,
                                           value.plan_path.with_name("component"))


class LocalControllerLeaseTests(Fixture):
    # Reuse the reviewed fake fixture; only these new methods are selected for this delta.
    controls = LocalSanitizerTests.controls
    control_write = staticmethod(LocalSanitizerTests.control_write)
    args = LocalSanitizerTests.args

    def test_held_common_controller_lease_prevents_authority_metadata_and_mode_storage(self):
        value = self.controls(stage="prepare")
        args = self.args(value, "local-prepare")
        cache = Path(value.policy["recoverable_shards"]["cache"])
        worker = Path(value.policy["recoverable_shards"]["workers"]["one"])
        self.assertFalse(cache.exists())
        self.assertFalse(worker.exists())
        with shards.file_claim(value.home / "Library/EliteNativeCI/recoverable-control.lock"), patch.dict(
                os.environ, value.environment, clear=True), patch.object(shards, "LocalAuthority", wraps=shards.LocalAuthority) as constructor:
            with self.assertRaises(BlockingIOError):
                shards.local_command(args)
        constructor.assert_not_called()
        self.assertEqual(value.calls, [])
        self.assertFalse(cache.exists())
        self.assertFalse(worker.exists())
        self.assertEqual(shards.load_json(value.state)["used"], 0)

    def test_first_real_authority_metadata_has_live_shared_controller_descriptor(self):
        value = self.controls(stage="prepare")
        args = self.args(value, "local-prepare")
        args.output = value.plan_path.with_name("fresh-plan.json")
        original, inherited = shards.LocalAuthority, []
        cache = Path(value.policy["recoverable_shards"]["cache"])
        worker = Path(value.policy["recoverable_shards"]["workers"]["one"])
        def read(command, workspace, environment, descriptors):
            self.assertEqual(len(descriptors), 1)
            self.assertEqual(os.fstat(descriptors[0]).st_uid, os.getuid())
            with self.assertRaises(BlockingIOError), shards.file_claim(value.home / "Library/EliteNativeCI/recoverable-control.lock"):
                self.fail("First metadata child must inherit the held common controller lease")
            if not inherited:
                self.assertFalse(cache.exists())
                self.assertFalse(worker.exists())
                self.assertEqual(command, ["sysctl", "-n", "hw.model"])
            inherited.append(tuple(descriptors))
            return value.read(command, workspace, environment, descriptors)
        def construct(*args, **kwargs):
            return original(*args, read=read, **kwargs)
        build = {"runtime": value.plan["runtime"], "inventory": METHODS, "shared_groups": []}
        builder = SimpleNamespace(build_only=lambda mode, timeout: None, prepare=lambda mode, path: build)
        # The builder is a deliberate fake: this test exercises real startup, not native preparation.
        with patch.dict(os.environ, value.environment, clear=True), patch.object(shards, "LocalAuthority", side_effect=construct), patch.object(
                shards, "NativeBuilder", return_value=builder):
            result = shards.local_command(args)
        self.assertEqual(result["plan_sha256"], shards.legacy.digest(args.output))
        self.assertTrue(inherited)
        self.assertTrue(all(descriptors == inherited[0] for descriptors in inherited))
        self.assertTrue(cache.exists())
        self.assertTrue(worker.exists())
        with self.assertRaises(OSError):
            os.fstat(inherited[0][0])

    def test_supplied_identity_is_refused_before_controller_storage_or_authority(self):
        args = SimpleNamespace(command="local-run", policy=Path("/missing"), local_session=Path("/missing-session"),
                               local_session_digest="a"*64, mode="address", timeout=5)
        with patch.dict(os.environ, {"GITHUB_JOB": "pretend"}, clear=True), patch.object(shards, "file_claim") as never, patch.object(
                shards, "LocalAuthority") as authority:
            with self.assertRaisesRegex(ValueError, "supplied authorization identities"):
                shards.local_command(args)
        never.assert_not_called()
        authority.assert_not_called()


class LocalTsanMemoryTests(Fixture):
    controls = LocalSanitizerTests.controls
    control_write = staticmethod(LocalSanitizerTests.control_write)
    authority = LocalSanitizerTests.authority
    fake_local_executor = LocalSanitizerTests.fake_local_executor
    validation_authority = LocalSanitizerTests.validation_authority

    def test_authority_dispatch_changes_only_local_thread_build_flags(self):
        value = self.controls("thread")
        authority = self.authority(value)
        original = ["--scratch-path", ".build/tsan", "--sanitize=thread"]
        expected = original + ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
        self.assertEqual(authority.build_flags("thread"), expected)
        self.assertEqual(shards.NativeAuthority.build_flags(authority, "thread"), original)
        self.assertEqual(shards.sanitizer_build_flags("thread"), original)
        self.assertEqual(shards.NativeAuthority.build_flags(authority, "address"),
                         ["--scratch-path", ".build/asan", "--sanitize=address", "--jobs", "1", "-Xswiftc", "-disable-batch-mode"])
        command = shards.legacy.batch_command("/fake/swift", expected, "thread", self.root, METHODS)
        old = shards.legacy.batch_command("/fake/swift", original, "thread", self.root, METHODS)
        position = command.index("--jobs")
        self.assertEqual(command[:position] + command[position+4:], old)
        self.assertNotIn("--no-parallel", command)  # Preserve Swift Testing/internal test concurrency.

    def test_local_old_flags_wrong_mode_and_oversized_plan_refuse_before_runtime_probe(self):
        value = self.controls("thread")
        authority = self.authority(value)
        with patch.object(shards.NativeAuthority, "runtime") as never:
            with self.assertRaises(ValueError):
                authority.runtime(authority.root, "thread", self.image, shards.sanitizer_build_flags("thread"))
            with self.assertRaises(ValueError):
                authority.build_flags("address")
        never.assert_not_called()
        old = deepcopy(value.plan)
        old["runtime"]["flags"] = shards.sanitizer_build_flags("thread")
        for row in old["shards"]:
            row["id"] = shards.fingerprint(shards.shard_identity(old["runtime"], row))
        with self.assertRaises(ValueError):
            shards.verify_local_plan(authority, old, value.session["plan_sha256"])
        methods = sorted(f"L337CoreTests.Small{i}/one()" for i in range(64))
        plan = shards.make_plan(value.plan["runtime"], methods,
            history=shards.workflow_history(methods, "thread", []), max_methods=64)
        authority.activation.update(inventory_sha256=shards.fingerprint(methods), inventory_count=64, shard_count=1)
        with self.assertRaisesRegex(ValueError, "packing exceeds"):
            shards.verify_local_plan(authority, plan)

    def test_local_thread16_retains_atomic_groups_and_global_thread64(self):
        value = self.controls("thread")
        solo = [f"L337CoreTests.Small{i}/one()" for i in range(64)]
        shared = [f"L337CoreTests.Shared{i}/one()" for i in range(170)]
        salvage = [f"L337CoreTests.Salvage{i}/one()" for i in range(13)]
        full = sorted(solo + shared + salvage)
        groups = [shared, salvage]
        history = shards.workflow_history(full, "thread", groups)
        plan = shards.make_plan(value.plan["runtime"], full, groups, history, max_methods=shards.LOCAL_PACKED_ID_TARGET)
        self.assertEqual(sorted(m for row in plan["shards"] for m in row["methods"]), full)
        self.assertTrue(all(len(row["methods"]) <= 16 or len(row["atoms"]) == 1 for row in plan["shards"]))
        for group in groups:
            self.assertEqual(sum(set(group) <= set(row["methods"]) for row in plan["shards"]), 1)
        baseline = shards.make_plan(self.runtimes["thread"], solo,
            history=shards.workflow_history(solo, "thread", []), max_methods=64)
        self.assertEqual([len(row["methods"]) for row in baseline["shards"]], [64])

    def test_actual_local_builder_ready_and_discovery_use_same_flags_and_refuse_old_ready(self):
        value = self.controls("thread", "prepare")
        authority = self.authority(value)
        builder = shards.NativeBuilder(authority)
        image = authority.root / ".build/tsan/Fake.xctest/Contents/MacOS/Fake"
        image.parent.mkdir(parents=True)
        image.write_bytes(self.image.read_bytes())
        expected = ["--scratch-path", ".build/tsan", "--sanitize=thread", "--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
        commands, original = [], authority.output
        def output(command, *args, **kwargs):
            if "--show-bin-path" in command:
                self.assertEqual(command, ["/fake/swift", "build", *expected, "--show-bin-path"])
                return str(image.parents[3])
            return original(command, *args, **kwargs)
        def execute(command, workspace, attempt, timeout, descriptors, *args, **kwargs):
            commands.append(command)
            for descriptor in descriptors:
                os.fstat(descriptor)
            (attempt / "test.log").write_text("\n".join(METHODS) if "list" in command else "fake build")
            return 0
        def runtime(workspace, mode, actual_image, flags, inputs=None):
            self.assertEqual(flags, expected)
            return value.plan["runtime"]
        bounds = {**authority.config["admission"], "ram_available": 20*1024**3, "disk_available": 100*1024**3}
        with patch.object(shards.legacy, "ensure_no_live_tests"), patch.object(authority, "snapshot", return_value={}), patch.object(
                authority, "admission", return_value=bounds), patch.object(authority, "output", side_effect=output), patch.object(
                authority, "runtime", side_effect=runtime), patch.object(shards.legacy, "executable_inputs", return_value=value.plan["runtime"]["inputs"]), patch.object(
                shards.legacy, "grouping_policy", return_value={"shared_groups": []}), patch.object(shards, "execute_process", side_effect=execute):
            self.assertFalse(builder.build_only("thread", 5)["reused"])
            self.assertTrue(builder.build_only("thread", 5)["reused"])
            with builder.preparation_claim():
                builder.build_and_discover("thread")
            self.assertEqual(commands, [["/fake/swift", "build", "--build-tests", *expected],
                                        ["/fake/swift", "test", *expected, "list", "--skip-build"]])
            ready = authority.cache / "build-stage" / HEAD / "thread/ready.json"
            stale = shards.load_json(ready)
            stale["runtime"]["flags"] = shards.sanitizer_build_flags("thread")
            ready.parent.chmod(0o700)
            shards.durable_json(ready, stale)
            shards.seal(ready.parent)
            with self.assertRaisesRegex(ValueError, "changed before discovery"):
                builder.build_only("thread", 5)
            self.assertEqual(len(commands), 2)

    def test_local_thread_rss_uses_own_budget_high_water_and_owned_refusal(self):
        value = self.controls("thread", worker_budget=3072)
        authority = self.authority(value)
        workspace = authority.workers["one"] / "thread"
        image = workspace / ".build/tsan/Fake.xctest/Contents/MacOS/Fake"
        image.parent.mkdir(parents=True)
        image.write_bytes(self.image.read_bytes())
        uuids = {"fake-arm64": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
        runtime = {**value.plan["runtime"], "image_uuid": shards.fingerprint(uuids)}
        root = dict(parent=1, group=10, state="S", start="root", command="/fake/swift test", rss_bytes=1024)
        helper = dict(parent=10, group=20, state="S", start="helper", rss_bytes=2048,
            command=f"/fake/swiftpm-testing-helper --test-bundle-path {image} {image} --testing-library swift-testing")
        rows = {10: root, 20: helper}
        authority.snapshot = lambda **kwargs: deepcopy(rows)
        attempt = self.root / "thread-rss"
        attempt.mkdir(mode=0o700)
        monitor = shards.NativeMonitor(authority, attempt, workspace, runtime, image)
        monitor.known[10] = deepcopy(root)
        with patch.object(shards, "image_uuids", return_value={"uuids": uuids}), patch.object(shards.legacy, "progress") as progress:
            monitor.observe()
            self.assertEqual(monitor.memory["budget_bytes"], 3072)
            self.assertEqual(monitor.memory["mode"], "thread")
            self.assertIsNone(monitor.memory["failure"])
            rows[20]["rss_bytes"] = 4096
            monitor.observe()
            self.assertEqual(monitor.memory["high_water_bytes"], 5120)
            self.assertIn("tsan_resident_memory_refused", json.loads(progress.call_args.args[0]))
        from crash_artifacts import cleanup_owned_identity
        sent = []
        def cleanup(identity, snapshot):
            def signal_owned(pid, signum):
                sent.append(pid)
                rows.pop(pid)
            cleanup_owned_identity(identity, snapshot, send_signal=signal_owned)
        with patch.object(shards, "cleanup_owned_identity", side_effect=cleanup):
            self.assertTrue(monitor.cleanup_memory_failure(monitor.known))
        self.assertEqual(sent, [10, 20])
        self.assertFalse(monitor.finish(True))

    def test_nonlocal_or_unbound_thread_does_not_gain_local_rss_policy(self):
        value = self.controls("thread")
        authority = self.authority(value)
        runtime = deepcopy(value.plan["runtime"])
        runtime["environment"][shards.LOCAL_POLICY_ENV] = "f"*64
        monitor = shards.NativeMonitor(authority, self.root, self.root, runtime)
        self.assertIsNone(monitor.memory)
        nonlocal_authority = SimpleNamespace(config={"admission": {"peak_per_worker": 1}})
        monitor = shards.NativeMonitor(nonlocal_authority, self.root, self.root, value.plan["runtime"])
        self.assertIsNone(monitor.memory)

    def test_thread_component_refuses_missing_wrong_mode_budget_and_over_budget_rss(self):
        for mutation in ("missing", "mode", "budget", "over"):
            value, authority, store, attempt = LocalSanitizerTests.completed_local(self, "thread")
            validation = self.validation_authority(value)
            processes = shards.load_json(attempt / "processes.json")
            if mutation == "missing":
                processes.pop("resident_memory")
            elif mutation == "mode":
                processes["resident_memory"]["mode"] = "address"
            elif mutation == "budget":
                processes["resident_memory"]["budget_bytes"] += 1
            else:
                processes["resident_memory"]["high_water_bytes"] = processes["resident_memory"]["budget_bytes"] + 1
            attempt.chmod(0o700)
            shards.durable_json(attempt / "processes.json", processes)
            receipt = shards.load_json(attempt / "result.json")
            receipt["outputs"] = shards.evidence_outputs(attempt, value.plan["runtime"], METHODS)
            shards.durable_json(attempt / "result.json", receipt)
            shards.durable_json(attempt / "commit.json", {"schema": 1, "receipt_sha256": shards.legacy.digest(attempt / "result.json")})
            shards.seal(attempt)
            with patch.object(shards.NativeExecutor, "verify"), patch.object(shards.NativeExecutor, "unknown_live_helpers", return_value=False):
                with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "mode-specific resident-budget"):
                    shards.local_component(validation, value.plan, value.session["plan_sha256"], store,
                                           value.plan_path.with_name("component"))



class OwnedQualityBridgeTests(Fixture):
    def controls(self, *args, **kwargs):
        return LocalSanitizerTests.controls(self, *args, physical_home=self.root / "physical-home", **kwargs)
    authority = LocalSanitizerTests.authority
    control_write = staticmethod(LocalSanitizerTests.control_write)
    fake_local_executor = LocalSanitizerTests.fake_local_executor
    completed_local = LocalSanitizerTests.completed_local
    workflow_script = WorkflowTests.workflow_script

    def bridge(self):
        """Create original local fake executions first, then a distinct real-format CI authority."""
        originals, entries = {}, {}
        for mode in shards.MODES:
            value, authority, store, attempt = self.completed_local(mode)
            value.plan_path.chmod(0o400)
            runtime = value.plan['runtime']
            worker = authority.workers['one']
            private = worker / mode
            relative = Path(runtime['flags'][1]) / 'Tests.xctest/Contents/MacOS/Tests'
            image = private / relative
            image.parent.mkdir(parents=True, mode=0o700)
            image.write_bytes(self.image.read_bytes())
            frozen = authority.cache / 'builds' / HEAD / mode
            (frozen / 'scratch').mkdir(parents=True, mode=0o700)
            frozen_image = frozen / 'scratch' / relative.relative_to(runtime['flags'][1])
            frozen_image.parent.mkdir(parents=True, mode=0o700)
            frozen_image.write_bytes(self.image.read_bytes())
            build = dict(schema=1, runtime=runtime, tested_head=HEAD, inventory=METHODS,
                         shared_groups=[], image_relative=str(relative), scratch=shards.build_entries(frozen / 'scratch'))
            shards.durable_json(frozen / 'build.json', build)
            shards.durable_json(frozen / 'build-commit.json', {'sha256': shards.legacy.digest(frozen / 'build.json')})
            shards.seal(frozen)
            self.control_write(worker / (mode + '-build.json'), build)
            component = value.plan_path.with_name('component')
            component.mkdir(mode=0o700)
            result = shards.local_component_content(value.plan, shards.legacy.digest(value.plan_path), store,
                HEAD, authority.policy_sha256, authority.config['admission'], worker)
            shards.durable_json(component / 'component.json', result)
            shards.durable_json(component / 'commit.json', {'sha256': shards.legacy.digest(component / 'component.json')})
            shards.seal(component)
            def pin(path, file=None):
                return dict(path=str(path), sha256=shards.legacy.digest(path / file if file else path))
            entries[mode] = dict(policy=pin(value.policy_path), plan=pin(value.plan_path),
                component=pin(component, 'component.json'), build=pin(frozen, 'build.json'),
                cache=str(authority.cache), worker=str(worker), runtime_sha256=shards.fingerprint(runtime),
                admission=authority.config['admission'])
            originals[mode] = SimpleNamespace(value=value, authority=authority, attempt=attempt, component=component)
        # From here all operations are read-only in-place proof verification under current CI.
        current = shards.NativeAuthority.__new__(shards.NativeAuthority)
        current.root = self.root / 'current-ci'
        (current.root / 'Tools/CI').mkdir(parents=True, mode=0o700)
        for name in value.policy['local_activation']['sources']:
            (current.root / 'Tools/CI' / name).write_bytes((Path(value.policy['local_activation']['workspace']) / 'Tools/CI' / name).read_bytes())
        current.cache, current.workers = self.root / 'ci-cache', {'one': self.root / 'ci-worker'}
        current.cache.mkdir(mode=0o700)
        current.workers['one'].mkdir(mode=0o700)
        target, tree = 'b' * 40, 'c' * 40
        current.config = deepcopy(value.policy['recoverable_shards'])
        current.config.update(cache=str(current.cache), workers={'one': str(current.workers['one'])})
        current.config['phase_profiles'] = {phase: dict(build_profile='jobs1-nonbatch-v1',
            admission={**current.config['admission'], 'peak_per_worker': peak})
            for phase, peak in [('normal', 2 * 1024**3), ('leaks', 3 * 1024**3)]}
        descriptor = dict(path=str(value.home / 'Library/EliteNativeAuthorization/local-quality-bindings' / target / 'binding.json'), sha256='f' * 64)
        current.policy = dict(approved_head=target, developer_dir=value.policy['developer_dir'],
            swift=value.policy['swift'], sdk=value.policy['sdk'], recoverable_shards=current.config,
            recoverable_activation=dict(sanitizer_backend=shards.native_runner.LOCAL_COMPONENTS_BACKEND,
                                       local_components=descriptor, workflow_sha256='e' * 64))
        current.environment = {**value.environment, 'GITHUB_JOB': 'native_local_components', 'GITHUB_RUN_ID': '123',
            'GITHUB_RUN_ATTEMPT': '1', 'RUNNER_NAME': 'owned-one', 'ELITE_NATIVE_APPROVED_HEAD': target,
            'ELITE_NATIVE_POLICY': str(self.root / 'ci-policy'), 'ELITE_RECOVERABLE_CODE_ENABLED': 'true',
            'ELITE_RECOVERABLE_WORKFLOW_SHA256': 'e' * 64,
            'ELITE_RECOVERABLE_POLICY_SHA256': shards.native_runner.policy_digest(current.policy)}
        current.calls = []
        def read(command, workspace=None, *args):
            current.calls.append((command, workspace))
            if command[:2] == ['git', 'rev-parse']:
                return tree if command[-1].endswith('^{tree}') else (target if workspace == current.root else HEAD)
            if command == ['git', 'status', '--porcelain']:
                return ''
            raise AssertionError('Unexpected fake bridge probe: ' + repr(command))
        current.read = read
        anchor_runtime = {**originals['address'].value.plan['runtime'], 'flags': shards.sanitizer_build_flags('address'),
            'environment': shards.legacy.runtime_identity(current.environment_for('address')),
            'phase_environment': shards.legacy.runtime_identity(current.execution_environment())}
        anchor = shards.make_plan(anchor_runtime, METHODS)
        binding = dict(schema=1, kind=shards.native_runner.LOCAL_COMPONENTS_BACKEND, target=dict(head=target, tree=tree),
            original=dict(head=HEAD, tree=tree), inputs=anchor_runtime['inputs'],
            semantic_environment=shards.bridge_semantics(anchor_runtime['phase_environment']), modes=entries)
        return SimpleNamespace(current=current, anchor=anchor, binding=binding, originals=originals)

    def verify(self, fixture):
        with patch.object(shards.native_runner, 'read_local_components_binding', return_value=fixture.binding), \
                patch.object(shards.NativeExecutor, 'verify') as executor, \
                patch.object(shards.NativeExecutor, 'unknown_live_helpers', return_value=False), \
                patch.object(shards.legacy, 'executable_inputs', return_value=fixture.binding['inputs']):
            result = shards.verify_owned_local_components(fixture.current, fixture.anchor)
        executor.assert_called_once_with(fixture.anchor['runtime'])
        return result

    def test_both_original_full_unions_are_read_in_place_under_current_ci_without_relabel_or_spawn(self):
        fixture = self.bridge()
        before = {mode: shards.physical_tree(row.component) for mode, row in fixture.originals.items()}
        with patch.object(shards, 'LocalAuthority', side_effect=AssertionError('No new local authority in CI')), \
                patch.object(shards.legacy, 'owned_directory', side_effect=AssertionError('Pure verifier cannot create storage')), \
                patch.object(shards, 'durable_json', side_effect=AssertionError('Pure verifier cannot write proof')), \
                patch.object(shards.shutil, 'copytree', side_effect=AssertionError('Pure verifier cannot copy proof')), \
                patch.dict(os.environ, {'GITHUB_JOB': 'native_local_components', 'GITHUB_SHA': 'b' * 40}, clear=True):
            result = self.verify(fixture)
        self.assertEqual(result['target_ci_head'], 'b' * 40)
        self.assertEqual(result['original_tested_head'], HEAD)
        self.assertEqual(set(result['modes']), set(shards.MODES))
        for mode, row in fixture.originals.items():
            self.assertEqual(result['modes'][mode]['inventory_count'], 3)
            self.assertEqual(shards.physical_tree(row.component), before[mode])
            self.assertEqual(shards.load_json(row.attempt / 'result.json')['tested_head'], HEAD)
        self.assertIn('not sanitizer execution at M', result['qualification'])

    def test_current_tree_blob_environment_role_and_unknown_controls_drift_refuse(self):
        fixture = self.bridge()
        for mutate in [lambda f: f.binding['target'].update(tree='d' * 40),
                       lambda f: f.binding.update(inputs={'Sources/Game.swift': '9' * 64}),
                       lambda f: f.binding['semantic_environment'].update(ELITE_NEW_CONTROL='9' * 64),
                       lambda f: f.current.environment.update(GITHUB_JOB='native_checks')]:
            saved_binding, saved_env = deepcopy(fixture.binding), deepcopy(fixture.current.environment)
            mutate(fixture)
            with self.assertRaises(ValueError):
                self.verify(fixture)
            fixture.binding, fixture.current.environment = saved_binding, saved_env
        original_read = fixture.current.read
        def wrong_original_tree(command, workspace=None, *args):
            if workspace != fixture.current.root and command[-1].endswith('^{tree}'):
                return 'd' * 40
            return original_read(command, workspace, *args)
        with patch.object(fixture.current, 'read', side_effect=wrong_original_tree), self.assertRaisesRegex(ValueError, 'checkout/tree'):
            self.verify(fixture)
        semantic = shards.bridge_semantics({'ELITE_NATIVE_POLICY': 'identity', 'ELITE_UNKNOWN_TEST_CONTROL': 'retain',
            'PATH': 'retain', 'HOME': 'retain', 'TSAN_OPTIONS': 'retain', 'ELITE_ENABLE_GPU': 'retain'})
        self.assertEqual(set(semantic), {'ELITE_UNKNOWN_TEST_CONTROL', 'PATH', 'HOME', 'TSAN_OPTIONS', 'ELITE_ENABLE_GPU'})

    def test_missing_mode_original_private_image_build_component_and_receipt_tamper_refuse(self):
        fixture = self.bridge()
        for mode in shards.MODES:
            entry = fixture.binding['modes'][mode]
            for control in ('policy', 'plan', 'component', 'build'):
                old = entry[control]['sha256']
                entry[control]['sha256'] = '0' * 64
                with self.subTest(mode=mode, control=control), self.assertRaises(ValueError):
                    self.verify(fixture)
                entry[control]['sha256'] = old
        row = fixture.originals['thread']
        image = Path(fixture.binding['modes']['thread']['worker']) / 'thread' / shards.load_json(
            Path(fixture.binding['modes']['thread']['build']['path']) / 'build.json')['image_relative']
        image.write_bytes(b'wrong image')
        with self.assertRaisesRegex(ValueError, 'private source/image'):
            self.verify(fixture)
        image.write_bytes(self.image.read_bytes())
        self.change(row.attempt / 'test.log', 'ERROR: ThreadSanitizer: deliberate fake diagnostic')
        with self.assertRaisesRegex(ValueError, 'missing/failed/incomplete'):
            self.verify(fixture)

    def test_expired_original_authority_remains_historical_and_allocation_and_semantics_are_exact(self):
        fixture = self.bridge()
        # Original policies expire at 10000, but their child began at 100. No local session is reopened.
        with patch.object(shards.time, 'time', return_value=20000):
            self.verify(fixture)
        original = fixture.originals['thread'].value
        changed = deepcopy(original.policy)
        changed['recoverable_shards']['legacy_cache'] = str(self.root / 'alternate-lease')
        self.control_write(original.policy_path, changed)
        entry = fixture.binding['modes']['thread']['policy']
        entry['sha256'] = shards.legacy.digest(original.policy_path)
        with self.assertRaisesRegex(ValueError, 'allocation differs'):
            self.verify(fixture)
        self.control_write(original.policy_path, original.policy)
        entry['sha256'] = shards.legacy.digest(original.policy_path)
        fixture.binding['modes']['thread']['admission'] = {**fixture.binding['modes']['thread']['admission'], 'peak_per_worker': 1}
        with self.assertRaisesRegex(ValueError, 'allocation differs'):
            self.verify(fixture)

    def test_real_quality_gate_requires_complete_current_native_and_fake_results(self):
        gate = self.workflow_script('Held, failed or cancelled execution')
        selected = dict(AUTHORIZED='true', CHECKS='success', FAKES='success',
                        GITHUB_STEP_SUMMARY=str(self.root / 'selected-summary'))
        with patch.dict(os.environ, selected, clear=True):
            exec(compile(gate, 'fake-normal-leaks-final-gate', 'exec'), {})
        for key in ('AUTHORIZED', 'CHECKS', 'FAKES'):
            for value in ('', 'skipped', 'failure', 'cancelled', 'unknown'):
                with self.subTest(control=key, value=value), patch.dict(os.environ, {**selected, key: value}, clear=True):
                    with self.assertRaises(AssertionError):
                        exec(compile(gate, 'fake-normal-leaks-final-gate', 'exec'), {})


    def test_independent_phase_memory_budget_and_image_lifecycle_refusals(self):
        for phase in ('normal', 'leaks'):
            profile = dict(build_profile='jobs1-nonbatch-v1', admission=dict(peak_per_worker=2048 if phase == 'normal' else 4096))
            row = dict(start='fake-start', command='fake phase', parent=1, group=42, state='S')
            identity = dict(phase=phase, image_sha256='a' * 64,
                image_uuid='UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (arm64) /fake/image')
            origin = dict(tested_head=HEAD, authorization=dict(role='native_phase', phase=phase, head=HEAD, workspace='/fake/source'))
            value = dict(child=dict(pid=42), terminal=dict(pid=42, exit_code=0), processes=dict(
                running=False, workspace='/fake/source', root={'pid': 42, **row}, processes={'42': row},
                observed_images={'fake': dict(sha256='a' * 64, uuid=shards.fingerprint({'arm64': 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'}))},
                resident_memory=dict(kind='sampled-owned-process-rss-v1', mode=phase, phase_profile_sha256=shards.fingerprint(profile),
                    failure=None, budget_bytes=profile['admission']['peak_per_worker'], samples=1,
                    helper_samples=1 if phase == 'normal' else 0, high_water_bytes=1024)))
            shards.validate_phase_memory(value, identity, profile, origin)
            for mutation in [lambda v: v['processes']['resident_memory'].update(mode='address'),
                             lambda v: v['processes']['resident_memory'].update(samples=0),
                             lambda v: v['processes']['resident_memory'].update(budget_bytes=1),
                             lambda v: v['processes']['resident_memory'].update(high_water_bytes=9000),
                             lambda v: v['processes']['resident_memory'].update(phase_profile_sha256='f' * 64),
                             lambda v: v['processes'].update(running=True),
                             lambda v: v['terminal'].update(exit_code=9),
                             lambda v: v['processes']['root'].update(start='different-process')]:
                changed = deepcopy(value)
                mutation(changed)
                with self.subTest(phase=phase), self.assertRaises(ValueError):
                    shards.validate_phase_memory(changed, identity, profile, origin)
            if phase == 'normal':
                for mutation in [lambda v: v['processes']['resident_memory'].update(helper_samples=0),
                                 lambda v: v['processes'].update(observed_images={})]:
                    changed = deepcopy(value)
                    mutation(changed)
                    with self.assertRaises(ValueError):
                        shards.validate_phase_memory(changed, identity, profile, origin)

    def test_each_phase_monitor_uses_only_its_explicit_budget_and_refuses_incomplete_or_over_budget_samples(self):
        fixture = self.bridge()
        authority = fixture.current
        for phase in ('normal', 'leaks'):
            attempt = self.root / ('monitor-' + phase)
            attempt.mkdir(mode=0o700)
            monitor = shards.NativeMonitor(authority, attempt, authority.root, phase=phase)
            self.assertEqual(monitor.memory['budget_bytes'], authority.config['phase_profiles'][phase]['admission']['peak_per_worker'])
            self.assertEqual(monitor.memory['phase_profile_sha256'], shards.fingerprint(authority.phase_profile(phase)))
            monitor.sample_memory({42: dict(command='fake phase', rss_bytes=monitor.memory['budget_bytes'] + 1)})
            self.assertEqual(monitor.memory['failure'], 'owned process tree exceeds budget')
            monitor = shards.NativeMonitor(authority, attempt, authority.root, phase=phase)
            monitor.sample_memory({42: dict(command='fake phase')})
            self.assertEqual(monitor.memory['failure'], 'incomplete resident sample')
        with patch.object(authority, 'phase_profile', return_value=None), self.assertRaises(ValueError):
            shards.NativeMonitor(authority, self.root, authority.root, phase='normal')
    def phase_capsule(self, fixture, phase):
        authority, runtime = fixture.current, fixture.anchor['runtime']
        authority.environment.update(GITHUB_JOB='native_phase', ELITE_RECOVERABLE_REQUEST_PHASE=phase)
        profile = authority.phase_profile(phase)
        identity = dict(schema=1, phase=phase, inputs=runtime['inputs'], swift=runtime['toolchain'],
            swift_executable='/fake/swift', sdk='fake-sdk', sdk_path='/fake/sdk', architecture=runtime['architecture'],
            os_version=dict(release='fake-os', version='fake-version'), image_sha256=shards.legacy.digest(self.image),
            image_uuid='UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (fake-arm64) /fake/image',
            phase_image=str(self.image), environment=runtime['phase_environment'],
            inventory=METHODS if phase == 'normal' else [], opt_in_policy={},
            flags=['--enable-code-coverage'] if phase == 'normal' else [], parallel=phase == 'normal',
            policy='normal-coverage-80-v1' if phase == 'normal' else 'leaks-at-exit-diagnostics-v1')
        flags = ['--jobs', '1', '-Xswiftc', '-disable-batch-mode']
        identity['build_profile'] = dict(kind='owned-phase-build-v1', phase=phase, profile=profile['build_profile'],
            policy_sha256=shards.native_runner.policy_digest(authority.policy), admission=profile['admission'], flags=flags,
            argv=['/fake/swift', 'build', *(['--build-tests'] if phase == 'normal' else []), *identity['flags'], *flags])
        attempt = self.root / ('fresh-owned-' + phase)
        attempt.mkdir(mode=0o700)
        command = (['/fake/swift', 'test', '--enable-code-coverage', '--skip-build', '--xunit-output', str(attempt / 'tests.xml')]
                   if phase == 'normal' else ['/usr/bin/leaks', '--atExit', '--', str(self.image), '--diagnostics'])
        (attempt / 'build.log').write_text('fake build completed')
        (attempt / 'phase.log').write_text('fake tests completed' if phase == 'normal' else '0 leaks for 0 total leaked bytes')
        if phase == 'normal':
            xml(attempt / 'tests-swift-testing.xml', METHODS)
            (attempt / 'coverage.xml').write_text('<coverage><file path="Sources/Game.swift">'
                + '<lineToCover covered="true"/>' * 4 + '<lineToCover covered="false"/>' + '</file></coverage>')
            (attempt / 'coverage.lcov').write_text('fake full lcov')
            (attempt / 'default.profdata').write_bytes(b'fake full coverage')
        shards.durable_json(attempt / 'start.json', dict(identity=identity, tested_head=authority.policy['approved_head'], command=command))
        result = dict(identity=identity, tested_head=authority.policy['approved_head'], command=command,
            status='passed', exit_code=0, native_exit_code=0, outputs={name: shards.legacy.digest(attempt / name)
                for name in shards.phases.phase_outputs(attempt, phase)}, validation=shards.phases.validate_outputs(attempt, identity))
        shards.durable_json(attempt / 'result.json', result)
        origin = dict(schema=1, host=runtime['host'], phase=phase, tested_head=authority.policy['approved_head'],
            receipt_sha256=shards.legacy.digest(attempt / 'result.json'), exit_code=0, authorization=authority.authorization())
        row = dict(start='fake-start', command='fake phase controller', parent=1, group=42, state='S')
        memory = dict(child=dict(pid=42), terminal=dict(pid=42, exit_code=0), processes=dict(running=False,
            workspace=str(authority.root), root={'pid': 42, **row}, processes={'42': row},
            observed_images={'fake': dict(sha256=identity['image_sha256'],
                uuid=shards.fingerprint({'fake-arm64': 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'}))},
            resident_memory=dict(kind='sampled-owned-process-rss-v1', mode=phase,
                phase_profile_sha256=shards.fingerprint(profile), failure=None, budget_bytes=profile['admission']['peak_per_worker'],
                samples=1, helper_samples=1 if phase == 'normal' else 0, high_water_bytes=1024)))
        verifier = SimpleNamespace(verify=lambda actual: self.assertEqual(actual, runtime), phase_origin=lambda a, i: origin)
        bundle = authority.cache / 'full-phases' / shards.phase_key(runtime, METHODS, phase, profile)
        bundle.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        checksum = shards.freeze_phase(attempt, identity, runtime, METHODS, verifier, bundle, profile, memory)
        shards.validate_phase(bundle, checksum, phase, runtime, METHODS, profile)
        return bundle, checksum

    def test_selected_capsules_reject_changed_profile_command_memory_and_actual_head(self):
        fixture = self.bridge()
        for phase in ('normal', 'leaks'):
            bundle, checksum = self.phase_capsule(fixture, phase)
            profile = fixture.current.phase_profile(phase)
            changed = deepcopy(profile)
            changed['admission']['peak_per_worker'] += 1
            with self.assertRaises(ValueError):
                shards.validate_phase(bundle, checksum, phase, fixture.anchor['runtime'], METHODS, changed)
            result = shards.load_json(bundle / 'attempt/result.json')
            start = shards.load_json(bundle / 'attempt/start.json')
            result['command'] = result['command'][:-1]
            start['command'] = result['command']
            with self.assertRaises(ValueError):
                shards.validate_phase_command(result, start)
            self.change(bundle / 'phase-memory.json', '{}')
            with self.assertRaises(ValueError):
                shards.validate_phase(bundle, checksum, phase, fixture.anchor['runtime'], METHODS, profile)

    def test_explicit_full_aggregate_requires_real_current_run_checks_and_both_actual_phase_capsules(self):
        from contextlib import nullcontext
        fixture = self.bridge()
        authority = fixture.current
        workflow = shards.NativeWorkflow(authority)
        authority.environment.update(GITHUB_JOB='native_checks')
        def execute(command, root, attempt, *args, **kwargs):
            (attempt / 'test.log').write_text('fake prerequisite commands completed')
            shards.durable_json(attempt / 'child-exit.json', dict(pid=42, exit_code=0))
            shards.durable_json(attempt / 'processes.json', dict(running=False))
            return 0
        with patch.object(shards.NativeBuilder, 'preparation_claim', side_effect=lambda **k: nullcontext(SimpleNamespace(fileno=lambda: 99))), \
                patch.object(shards, 'execute_process', side_effect=execute), \
                patch.object(shards.legacy, 'executable_inputs', return_value=fixture.binding['inputs']):
            workflow.checks(self.root / 'current-checks', 5)
        normal, _ = self.phase_capsule(fixture, 'normal')
        leaks, _ = self.phase_capsule(fixture, 'leaks')
        authority.environment.update(GITHUB_JOB='native_aggregate', ELITE_RECOVERABLE_REQUEST_PHASE='')
        self.assertTrue(workflow.require_prerequisites(fixture.anchor))
        with self.assertRaisesRegex(ValueError, 'explicit aggregate'):
            workflow.aggregate([fixture.anchor])
        with patch.object(shards.NativeBuilder, 'preparation_claim', side_effect=lambda: nullcontext()), \
                patch.object(shards.native_runner, 'read_local_components_binding', return_value=fixture.binding), \
                patch.object(shards.NativeExecutor, 'verify'), \
                patch.object(shards.NativeExecutor, 'unknown_live_helpers', return_value=False), \
                patch.object(shards.legacy, 'executable_inputs', return_value=fixture.binding['inputs']):
            report = workflow.aggregate_owned([fixture.anchor], self.root / 'full-report')
            self.assertEqual(report['current_ci_head'], 'b' * 40)
            self.assertEqual(report['original_sanitizer_tested_head'], HEAD)
            self.assertEqual(set(report['phases']), {'normal', 'leaks'})
            self.assertEqual((authority.root / 'coverage.lcov').read_text(), 'fake full lcov')
            self.assertIn('actual-main Sonar must also succeed', report['qualification'])
            authority.environment['GITHUB_RUN_ATTEMPT'] = '2'
            with self.assertRaises((OSError, ValueError)):
                workflow.aggregate_owned([fixture.anchor], self.root / 'wrong-attempt-report')
            self.assertEqual(shards.load_json(self.root / 'wrong-attempt-report/result.json')['status'], 'failed')
            authority.environment['GITHUB_RUN_ATTEMPT'] = '1'
            hidden = leaks.with_name('held-leaks')
            leaks.rename(hidden)
            with patch.object(workflow, 'artifacts', return_value=SimpleNamespace(artifacts=lambda prefix: [])), \
                    self.assertRaisesRegex(ValueError, 'phase is missing'):
                workflow.aggregate_owned([fixture.anchor], self.root / 'missing-phase-report')
        self.assertTrue(normal.exists())


    def test_each_phase_has_separate_admission_and_shared_lease_before_execution(self):
        fixture = self.bridge()
        authority = fixture.current
        def metadata(command):
            if command[0] == 'sysctl':
                return '4'
            if command == ['vm_stat']:
                return ('Mach Virtual Memory Statistics: (page size of 4096 bytes)\n'
                        'Pages free: 3000000.\nPages inactive: 0.\nPages speculative: 0.\n')
            raise AssertionError('Unexpected fake resource probe')
        with patch.object(authority, 'output', side_effect=metadata), \
                patch.object(shards.shutil, 'disk_usage', return_value=SimpleNamespace(free=100 * 1024**3)):
            for phase in ('normal', 'leaks'):
                observed = authority.admission(phase)
                self.assertEqual(observed['peak_per_worker'], authority.phase_profile(phase)['admission']['peak_per_worker'])
        authority.legacy_cache = Path(authority.config['legacy_cache'])
        authority.legacy_cache.mkdir(parents=True, exist_ok=True, mode=0o700)
        with patch.object(authority, 'admission', return_value={'explicit': 1}) as admission, \
                patch.object(shards.legacy, 'ensure_no_live_tests'), patch.object(authority, 'snapshot', return_value={}):
            for phase in ('normal', 'leaks'):
                with shards.NativeBuilder(authority).preparation_claim(phase=phase) as lock:
                    os.fstat(lock.fileno())
                    admission.assert_called_with(phase=phase)

    def test_outcome_closure_no_longer_requires_or_routes_local_sanitizer_proofs(self):
        source = (Path(__file__).resolve().parents[2] / '.github/workflows/recoverable-quality.yml').read_text()
        closure = self.workflow_script('Require every job outcome before authoritative main analysis')
        env = dict(AUTHORIZED='true', FAKES='success', CHECKS='success')
        with patch.dict(os.environ, env, clear=True):
            exec(compile(closure, 'fake-normal-before-sonar', 'exec'), {})
        for key in env:
            with self.subTest(job=key), patch.dict(os.environ, {**env, key: ''}, clear=True), self.assertRaises(AssertionError):
                exec(compile(closure, 'fake-normal-before-sonar', 'exec'), {})
        self.assertNotIn('needs.native_local_components', source)
        self.assertNotIn('needs.prepare_address', source)
        self.assertNotIn('needs.prepare_thread', source)
        self.assertNotIn('workflow-owned-aggregate', source)
        make = (Path(__file__).resolve().parents[2] / 'Makefile').read_text()
        self.assertNotIn('\nci-owned-local-components:', make)



    def test_phase_parent_passes_immutable_profile_policy_and_captures_monitored_real_format_capsules(self):
        from contextlib import nullcontext
        fixture = self.bridge()
        authority = fixture.current
        policy_path = Path(authority.environment['ELITE_NATIVE_POLICY'])
        self.control_write(policy_path, authority.policy)
        for phase in ('normal', 'leaks'):
            initial, _ = self.phase_capsule(fixture, phase)
            saved = self.root / ('initial-' + phase)
            initial.chmod(0o700)
            initial.rename(saved)
            shards.seal(saved)
            memory = shards.load_json(saved / 'phase-memory.json')
            def execute(command, workspace, attempt, timeout, descriptors, environment, monitor, isolate_environment):
                self.assertFalse(isolate_environment)
                self.assertEqual(command[command.index('--profile-policy') + 1], str(policy_path))
                self.assertEqual(command[command.index('--profile-policy-sha256') + 1], shards.legacy.digest(policy_path))
                self.assertEqual(monitor.memory['mode'], phase)
                self.assertEqual(monitor.memory['budget_bytes'], authority.phase_profile(phase)['admission']['peak_per_worker'])
                fresh = Path(command[command.index('--cache') + 1]) / 'phases/fake/attempt'
                fresh.parent.mkdir(parents=True, mode=0o700)
                shutil.copytree(saved / 'attempt', fresh)
                monitor.observed = memory['processes']['observed_images']
                for name, file in [('processes', 'processes.json'), ('child', 'child.json'), ('terminal', 'child-exit.json')]:
                    shards.durable_json(attempt / file, memory[name])
                return 0
            executor = FakeExecutor(authority.workers['one'], {'address': fixture.anchor['runtime']})
            with patch.object(shards.NativeBuilder, 'preparation_claim', side_effect=lambda **k: nullcontext(SimpleNamespace(fileno=lambda: 99))) as claim, \
                    patch.object(shards, 'execute_process', side_effect=execute) as execution, \
                    patch.object(authority, 'host', return_value=fixture.anchor['runtime']['host']):
                runner = shards.NativePhaseRunner(authority, executor)
                destination = self.root / ('delivered-' + phase)
                checksum = runner.run(phase, fixture.anchor, destination, 5)
                self.assertEqual(runner.run(phase, fixture.anchor, destination, 5), checksum)
                self.assertEqual(execution.call_count, 1)
                claim.assert_called_with(phase=phase)
            shards.validate_phase(destination, checksum, phase, fixture.anchor['runtime'], METHODS, authority.phase_profile(phase))


if __name__ == "__main__":
    unittest.main()
