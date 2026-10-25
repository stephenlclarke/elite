"""Fake-only fault injection. No Swift, native runner, game or sanitizer is launched."""

from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
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
METHODS = ["EliteCoreTests.A/one()", "EliteCoreTests.A/two()", "EliteCoreTests.B/three()"]


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
    def test_longest_first_atomic_duration_packing_and_stable_identity(self):
        units = shards.legacy.partition(METHODS, "thread", 1)
        weights = {shards.fingerprint(unit): seconds for unit, seconds in zip(units, (5100, 70))}
        first = shards.make_plan(self.runtimes["thread"], METHODS, history=weights)
        self.assertEqual([row["estimated_seconds"] for row in first["shards"]], [5100, 70])
        self.assertTrue(first["shards"][0]["oversized"])
        self.assertEqual(first["shards"][0]["methods"], METHODS[:2])
        extra = "EliteCoreTests.Z/four()"
        second = shards.make_plan(self.runtimes["thread"], [extra, *reversed(METHODS)],
                                  history={**weights, shards.fingerprint([extra]): 700}, budget=300)
        self.assertIn(first["shards"][0]["id"], [row["id"] for row in second["shards"]])
        self.assertEqual(shards.make_plan(self.runtimes["thread"], METHODS), self.plan)

    def test_real_audited_groups_remain_whole_in_both_modes(self):
        root = Path(__file__).resolve().parents[2]
        manifest = shards.load_json(root / "Tools/CI/sanitizer_groups.json")
        self.assertEqual([(len(group["members"]), len(group["sources"]))
                          for group in manifest["groups"]], [(170, 32), (13, 2)])
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
                              '<testsuites><testcase classname="EliteCoreTests.A" name="one()" time="1"/>'
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
import recoverable_shards as shards
from test_recoverable_shards import FakeExecutor, ADMISSION, HEAD
plan = shards.load_json(pathlib.Path(sys.argv[1]))
cache, stage = pathlib.Path(sys.argv[2]), sys.argv[3]
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
            self.assertIn("HELD", result.stderr)


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
                shards.native_runner, "validate", return_value=controller) as validate:
            authority = shards.NativeAuthority(policy, {"LANG": "C"}, read)
            validate.assert_called_once()
        authority.calls = calls
        return authority

    def prepared(self):
        authority = self.authority()
        calls = []
        def build(root, swift, flags, environment, lock, report):
            mode = flags[-1].split("=")[1]
            calls.append(mode)
            image = root / flags[1] / "fake.xctest/Contents/MacOS/EliteCoreTests"
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
            def completed(*args):
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

    def test_physical_guard_requires_separate_host_hook_before_any_checkout_and_cancelled_never_passes(self):
        source = self.workflow_script("Require host hook and exact instance")
        activation = dict(schema=1, enabled=True, revoked=False, expires_at=time.time() + 60,
                          head=HEAD, ref="refs/heads/approved", workflow_sha256="a" * 64,
                          assignment_root=str(self.root / "owned-assignments"),
                          runners={"owned-one": {"workspace": "/fixture/runner/_work/elite/elite", "jobs": ["native_shards"]}})
        env = dict(ACTIVATION=json.dumps(activation), POLICY_DIGESTS=json.dumps({"owned-one": "b" * 64}),
                   REQUESTED_NATIVE="true", RUNNER_ENVIRONMENT="self-hosted", RUNNER_NAME="owned-one",
                   GITHUB_REPOSITORY="stephenlclarke/elite", GITHUB_ACTOR_ID="22142777", GITHUB_EVENT_NAME="workflow_dispatch",
                   GITHUB_SHA=HEAD, GITHUB_REF="refs/heads/approved", GITHUB_JOB="native_shards",
                   GITHUB_WORKSPACE="/fixture/runner/_work/elite/elite", GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1",
                   PLAN_DIGEST="e" * 64, ELITE_RECOVERABLE_PLAN_SHA256="e" * 64,
                   ELITE_RECOVERABLE_REQUEST_MODE="thread", ELITE_RECOVERABLE_REQUEST_SHARD="f" * 64,
                   ELITE_RECOVERABLE_REQUEST_WORKER="one",
                   GITHUB_WORKFLOW_REF="stephenlclarke/elite/.github/workflows/recoverable-quality.yml@refs/heads/approved",
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
        passed = dict(AUTHORIZED="true", PREPARE="success", PHASES="success", AGGREGATE="success", SHARDS="skipped", PENDING="false")
        with patch.dict(os.environ, passed, clear=True):
            exec(compile(gate, "fake-final-gate", "exec"), {})
        for change in ({"SHARDS": "failed"}, {"SHARDS": "cancelled"}, {"AGGREGATE": "skipped"},
                       {"AUTHORIZED": "false"}, {"PENDING": "true"}):
            with patch.dict(os.environ, {**passed, **change}, clear=True), self.assertRaises(AssertionError):
                exec(compile(gate, "fake-final-gate", "exec"), {})


if __name__ == "__main__":
    unittest.main()
