#!/usr/bin/env python3
"""Opt-in shard planning and recovery; the existing quality executor is unchanged."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack, contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import uuid
import xml.etree.ElementTree as ET

import quality_phase_checkpoints as phases
import sanitizer_checkpoints as legacy
from crash_artifacts import cleanup_owned_identity, image_uuids, runtime_child_environment, same_process
import native_runner

SCHEMA = 1
POLICY = "recoverable-parallel-shards-v1"
# Activation requires a separate reviewed change after the current M01 run.
PHYSICAL_EXECUTION_ENABLED = False
MODES = ("thread", "address")


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                    allow_nan=False).encode()).hexdigest()


def load_json(path):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("Duplicate JSON field: " + key)
            value[key] = item
        return value
    return json.loads(Path(path).read_text(), object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def require_fields(value, names):
    if not isinstance(value, dict) or set(value) != set(names):
        raise ValueError("Unexpected evidence fields")


def positive(value):
    if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
        raise ValueError("A finite positive resource bound is required")
    return value


def durable_json(path, value):
    """Use the existing atomic writer, then persist the containing directory."""
    temporary = path.with_name(path.name + ".pending-" + str(uuid.uuid4()))
    legacy.atomic_json(temporary, value)
    temporary.replace(path)
    sync_directory(path.parent)


def sync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def physical_tree(root):
    """Inspect every child, including directories, without following links."""
    legacy.owned_directory(root)
    result = {}
    for directory, names, files in os.walk(root, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            info = path.lstat()
            if path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
                raise ValueError("Evidence must be physical, owned and not publicly writable")
            if path.is_file():
                result[path.relative_to(root).as_posix()] = legacy.digest(path)
            elif not path.is_dir():
                raise ValueError("Unsupported evidence entry")
    return result


@contextmanager
def claim(root, name, shared=False, wait_seconds=0):
    legacy.owned_directory(root)
    path = root / (fingerprint(name) + ".lock")
    with file_claim(path, shared, wait_seconds) as lock:
        yield lock


@contextmanager
def file_claim(path, shared=False, wait_seconds=0):
    legacy.owned_directory(path.parent)
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a") as lock:
        info = os.fstat(lock.fileno())
        if info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Foreign claim lock")
        operation = fcntl.LOCK_SH if shared else fcntl.LOCK_EX
        deadline = time.monotonic() + wait_seconds
        while True:
            try:
                fcntl.flock(lock, operation | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(0.02)
        yield lock


def validate_runtime(runtime):
    """Bind actual executable facts, not a worker index or a whole-plan ordinal."""
    require_fields(runtime, ("schema", "mode", "inputs", "toolchain", "sdk", "host",
                             "os", "architecture", "image_sha256", "image_uuid",
                             "environment", "phase_environment", "flags", "policy", "opt_in_policy"))
    if (type(runtime["schema"]) is not int or runtime["schema"] != SCHEMA
            or runtime["mode"] not in MODES or runtime["policy"] != POLICY):
        raise ValueError("Unknown execution protocol; legacy receipts are not compatible")
    for key in ("toolchain", "sdk", "host", "os", "architecture", "image_uuid"):
        if not isinstance(runtime[key], str) or not runtime[key]:
            raise ValueError("Missing actual runtime identity: " + key)
    if not re.fullmatch(r"[0-9a-f]{64}", runtime["image_sha256"]):
        raise ValueError("Missing actual image hash")
    if not isinstance(runtime["inputs"], dict) or not runtime["inputs"]:
        raise ValueError("Executable source inputs are required")
    for name, digest in runtime["inputs"].items():
        if (not isinstance(name, str) or Path(name).is_absolute() or ".." in Path(name).parts
                or not re.fullmatch(r"[0-9a-f]{64}", digest)):
            raise ValueError("Invalid executable input")
    expected_flag = "--sanitize=" + runtime["mode"]
    if (not isinstance(runtime["flags"], list) or expected_flag not in runtime["flags"]
            or "--skip-build" in runtime["flags"]
            or not isinstance(runtime["environment"], dict)
            or not isinstance(runtime["phase_environment"], dict)
            or not isinstance(runtime["opt_in_policy"], dict)):
        raise ValueError("Invalid frozen runtime policy")


def shard_identity(runtime, shard):
    validate_runtime(runtime)
    return {"schema": SCHEMA, "policy": POLICY, "runtime": runtime,
            "methods": shard["methods"], "atoms": shard["atoms"],
            "claims": shard["claims"], "audited": shard["audited"],
            "resource_audits": shard["resource_audits"]}


def make_plan(runtime, methods, shared_groups=(), history=None, resources=None, budget=600):
    """Pack whole audited groups/suites by duration; timings are only planning hints."""
    validate_runtime(runtime)
    if type(budget) not in (int, float) or not 300 <= budget <= 600:
        raise ValueError("The soft duration target must be five to ten minutes")
    methods = sorted(methods)
    if not methods or len(methods) != len(set(methods)):
        raise ValueError("Inventory must be nonempty and unique")
    legacy.inventory("\n".join(methods))
    # Target one creates indivisible atoms, using the existing audited grouping rules.
    atoms = legacy.partition(methods, runtime["mode"], 1, shared_groups)
    owners = {}
    for index, atom in enumerate(atoms):
        for method in atom:
            suite = legacy.group_key(method)
            if suite in owners and owners[suite] != index:
                raise ValueError("A shared group would split a whole suite")
            owners[suite] = index
    history, resources = history or {}, resources or {}
    units = []
    known_atoms = set()
    for atom in atoms:
        atom_id = fingerprint(sorted(atom))
        known_atoms.add(atom_id)
        weight = positive(history.get(atom_id, max(60, 15 * len(atom))))
        policy = resources.get(atom_id)
        audited = policy is not None
        claims = []
        if audited:
            require_fields(policy, ("sources", "claims", "reviewed"))
            if policy["reviewed"] is not True or not policy["sources"]:
                raise ValueError("External resource independence requires an explicit audit")
            for name, digest in policy["sources"].items():
                if runtime["inputs"].get(name) != digest:
                    raise ValueError("Resource audit source changed")
            claims = policy["claims"]
            if (not isinstance(claims, list) or len(set(claims)) != len(claims)
                    or any(not isinstance(item, str) or not item for item in claims)):
                raise ValueError("Invalid external resource claims")
        units.append({"id": atom_id, "methods": sorted(atom), "seconds": weight,
                      "claims": sorted(claims), "audited": audited})
    if set(resources) - known_atoms:
        raise ValueError("Resource audit contains a foreign atomic unit")
    bins = []
    for unit in sorted(units, key=lambda row: (-row["seconds"], row["id"])):
        candidates = [row for row in bins
                      if row["seconds"] < budget and row["seconds"] + unit["seconds"] <= budget]
        if unit["seconds"] >= budget or not candidates:
            bins.append({"units": [unit], "seconds": unit["seconds"]})
        else:
            selected = min(candidates, key=lambda row: (row["seconds"], row["units"][0]["id"]))
            selected["units"].append(unit)
            selected["seconds"] += unit["seconds"]
    shards = []
    for row in bins:
        shard = {"methods": sorted(method for unit in row["units"] for method in unit["methods"]),
                 "atoms": sorted(unit["id"] for unit in row["units"]),
                 "claims": sorted({name for unit in row["units"] for name in unit["claims"]}),
                 "audited": all(unit["audited"] for unit in row["units"]),
                 "resource_audits": {unit["id"]: resources.get(unit["id"])
                                     for unit in sorted(row["units"], key=lambda unit: unit["id"])},
                 "estimated_seconds": row["seconds"], "oversized": row["seconds"] > budget}
        shard["id"] = fingerprint(shard_identity(runtime, shard))
        shards.append(shard)
    shards.sort(key=lambda row: (-row["estimated_seconds"], row["id"]))
    plan = {"schema": SCHEMA, "policy": POLICY, "runtime": runtime, "inventory": methods,
            "shared_groups": [sorted(group) for group in shared_groups],
            "budget_seconds": budget, "shards": shards}
    validate_plan(plan)
    return plan


def validate_plan(plan):
    require_fields(plan, ("schema", "policy", "runtime", "inventory", "shared_groups",
                          "budget_seconds", "shards"))
    validate_runtime(plan["runtime"])
    if (type(plan["schema"]) is not int or plan["schema"] != SCHEMA
            or plan["policy"] != POLICY or type(plan["budget_seconds"]) not in (int, float)
            or not 300 <= plan["budget_seconds"] <= 600 or not plan["shards"]):
        raise ValueError("Unknown plan schema")
    seen, ids, owners = [], set(), {}
    for index, shard in enumerate(plan["shards"]):
        require_fields(shard, ("id", "methods", "atoms", "claims", "audited",
                               "estimated_seconds", "oversized", "resource_audits"))
        if (not shard["methods"] or shard["methods"] != sorted(set(shard["methods"]))
                or shard["id"] != fingerprint(shard_identity(plan["runtime"], shard))
                or shard["id"] in ids or type(shard["audited"]) is not bool
                or type(shard["oversized"]) is not bool
                or shard["oversized"] != (shard["estimated_seconds"] > plan["budget_seconds"])):
            raise ValueError("Invalid or duplicate shard identity")
        positive(shard["estimated_seconds"])
        ids.add(shard["id"])
        seen += shard["methods"]
        for method in shard["methods"]:
            key = legacy.group_key(method)
            if key in owners and owners[key] != index:
                raise ValueError("A suite was split")
            owners[key] = index
    if (not plan["inventory"] or plan["inventory"] != sorted(set(plan["inventory"]))
            or Counter(seen) != Counter(plan["inventory"])):
        raise ValueError("Plan does not contain inventory exactly once")
    for group in plan["shared_groups"]:
        if not group or len({owners[legacy.group_key(method)] for method in group}) != 1:
            raise ValueError("An audited process group was split")
    atomic = {fingerprint(sorted(atom)): sorted(atom) for atom in legacy.partition(
        plan["inventory"], plan["runtime"]["mode"], 1, plan["shared_groups"])}
    for shard in plan["shards"]:
        if (shard["atoms"] != sorted(set(shard["atoms"]))
                or set(shard["resource_audits"]) != set(shard["atoms"])
                or any(atom not in atomic for atom in shard["atoms"])
                or sorted(method for atom in shard["atoms"] for method in atomic[atom])
                != shard["methods"]):
            raise ValueError("Shard atomic membership was changed")
        claims = set()
        for audit in shard["resource_audits"].values():
            if audit is None:
                continue
            require_fields(audit, ("sources", "claims", "reviewed"))
            if (audit["reviewed"] is not True or not audit["sources"]
                    or not isinstance(audit["claims"], list)
                    or any(not isinstance(name, str) or not name for name in audit["claims"])
                    or len(set(audit["claims"])) != len(audit["claims"])
                    or any(plan["runtime"]["inputs"].get(name) != digest
                           for name, digest in audit["sources"].items())):
                raise ValueError("Resource audit is not source-bound")
            claims.update(audit["claims"])
        if (shard["audited"] != all(value is not None
                                   for value in shard["resource_audits"].values())
                or shard["claims"] != sorted(claims)):
            raise ValueError("External resource policy was changed")
    return plan


def evidence_outputs(attempt, runtime, methods):
    """Reuse strict native XML and opt-in validation, without promoting old schemas."""
    entries = physical_tree(attempt)
    allowed = {"test.log", "tests.xml", "tests-swift-testing.xml", "start.json", "result.json",
               "commit.json", "child.json", "child-exit.json", "processes.json", "environment.json"}
    if any(name not in allowed and not name.startswith("profiles/") for name in entries):
        raise ValueError("Unaccounted evidence file")
    report = attempt / "tests-swift-testing.xml"
    if not report.is_file():
        report = attempt / "tests.xml"
    legacy.inspect_xml(report, methods, legacy.selected_opt_in_skips(runtime, methods))
    if report.name != "tests.xml" and (attempt / "tests.xml").exists():
        legacy.inspect_xml(attempt / "tests.xml", [], {})
    if any(marker in (attempt / "test.log").read_text(errors="replace") for marker in legacy.ERRORS):
        raise ValueError("Sanitizer diagnostic in raw log")
    child, terminal = load_json(attempt / "child.json"), load_json(attempt / "child-exit.json")
    require_fields(child, ("pid", "command", "started"))
    require_fields(terminal, ("pid", "exit_code"))
    if (type(child["pid"]) is not int or child["pid"] <= 0 or terminal["pid"] != child["pid"]
            or type(terminal["exit_code"]) is not int or terminal["exit_code"] != 0
            or not isinstance(child["command"], list) or not child["command"]
            or any(not isinstance(value, str) for value in child["command"])):
        raise ValueError("Native child terminal proof is incomplete or unsuccessful")
    positive(child["started"])
    record = load_json(attempt / "environment.json")
    require_fields(record, ("schema", "base", "actual", "bindings"))
    paths = load_json(attempt / "start.json")["paths"]
    expected = ephemeral_bindings(paths)
    actual = dict(runtime["environment"])
    actual.update({name: hashlib.sha256(binding["path"].encode()).hexdigest()
                   for name, binding in expected.items()})
    if (record["schema"] != SCHEMA or record["base"] != runtime["environment"]
            or record["bindings"] != expected or record["actual"] != actual):
        raise ValueError("Actual child environment or typed ephemeral binding changed")
    return {name: digest for name, digest in entries.items()
            if name not in ("result.json", "commit.json")}


def validate_success(attempt, identity, receipt_digest=None, immutable=True):
    require_fields(identity, ("schema", "policy", "runtime", "methods", "atoms", "claims",
                              "audited", "resource_audits"))
    validate_runtime(identity["runtime"])
    if type(identity["schema"]) is not int or identity["schema"] != SCHEMA or identity["policy"] != POLICY:
        raise ValueError("Unknown shard identity protocol")
    physical_tree(attempt)
    if immutable:
        for directory, names, files in os.walk(attempt):
            if Path(directory).stat().st_mode & 0o222 or any(
                    (Path(directory) / name).stat().st_mode & 0o222 for name in files):
                raise ValueError("Success checkpoint is not immutable")
    receipt_path = attempt / "result.json"
    commit = load_json(attempt / "commit.json")
    require_fields(commit, ("schema", "receipt_sha256"))
    if (type(commit["schema"]) is not int or commit["schema"] != SCHEMA
            or commit["receipt_sha256"] != legacy.digest(receipt_path)):
        raise ValueError("Terminal receipt is not committed or was tampered with")
    if receipt_digest is not None and legacy.digest(receipt_path) != receipt_digest:
        raise ValueError("Restored receipt does not match the trusted index")
    result = load_json(receipt_path)
    require_fields(result, ("schema", "status", "identity", "tested_head", "exit_code",
                           "seconds", "outputs"))
    if (type(result["schema"]) is not int or result["schema"] != SCHEMA
            or result["status"] != "passed"
            or type(result["exit_code"]) is not int or result["exit_code"] != 0
            or result["identity"] != identity
            or not re.fullmatch(r"[0-9a-f]{40}", result["tested_head"])):
        raise ValueError("Receipt is not a matching completed success")
    positive(result["seconds"])
    start = load_json(attempt / "start.json")
    if start["identity"] != identity or start["tested_head"] != result["tested_head"]:
        raise ValueError("Attempt identity differs from terminal proof")
    if result["outputs"] != evidence_outputs(attempt, identity["runtime"], identity["methods"]):
        raise ValueError("Missing, extra or tampered evidence")
    return result


def seal(attempt):
    for directory, names, files in os.walk(attempt, topdown=False):
        for name in files:
            path = Path(directory) / name
            with path.open("rb") as stream:
                os.fsync(stream.fileno())
            path.chmod(0o400)
        Path(directory).chmod(0o500)
        sync_directory(directory)
    sync_directory(attempt.parent)


class Store:
    def __init__(self, root):
        self.root = Path(root)
        legacy.owned_directory(self.root)

    def matching(self, identity):
        parent = self.root / "attempts" / fingerprint(identity)
        if not parent.exists():
            return None
        physical_tree(parent)
        for attempt in sorted(parent.iterdir()):
            if attempt.is_dir() and (attempt / "result.json").exists():
                try:
                    return attempt, validate_success(attempt, identity)
                except (ValueError, OSError, KeyError, TypeError, ET.ParseError):
                    continue
        return None

    def index(self, identities):
        """Rescan committed successes, including a success orphaned before index/upload."""
        with claim(self.root / "claims", "index", wait_seconds=30):
            entries = {}
            index_path = self.root / "index.json"
            if index_path.exists():
                prior = load_json(index_path)
                require_fields(prior, ("schema", "entries"))
                if prior["schema"] != SCHEMA:
                    raise ValueError("Unknown index schema")
                entries.update(prior["entries"])
            for identity in identities:
                found = self.matching(identity)
                if found:
                    attempt, receipt = found
                    entries[fingerprint(identity)] = {
                        "attempt": attempt.relative_to(self.root).as_posix(),
                        "receipt_sha256": legacy.digest(attempt / "result.json")}
            value = {"schema": SCHEMA, "entries": entries}
            durable_json(index_path, value)
        return value

    def restore(self, bundle, expected_digest, identity):
        """Restore from a quarantined directory only with a separately trusted receipt hash."""
        bundle = Path(bundle)
        validate_success(bundle, identity, expected_digest, immutable=False)
        parent = self.root / "attempts" / fingerprint(identity)
        legacy.owned_directory(parent)
        with claim(self.root / "claims", "shard:" + fingerprint(identity)):
            temporary = parent / (".restore-" + str(uuid.uuid4()))
            shutil.copytree(bundle, temporary)
            validate_success(temporary, identity, expected_digest, immutable=False)
            seal(temporary)
            validate_success(temporary, identity, expected_digest)
            destination = parent / str(uuid.uuid4())
            temporary.rename(destination)
            descriptor = os.open(parent, os.O_RDONLY)
            try:
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        return destination

    def export(self, identity, destination):
        """One shard artifact; its index digest must be retained outside the artifact."""
        found = self.matching(identity)
        if found is None:
            raise ValueError("No complete success to export")
        destination = Path(destination)
        if destination.exists():
            raise ValueError("Artifact destination already exists")
        legacy.owned_directory(destination)
        attempt, _ = found
        shutil.copytree(attempt, destination / "attempt")
        index = {"schema": SCHEMA, "identity": identity, "attempt": "attempt",
                 "receipt_sha256": legacy.digest(attempt / "result.json")}
        durable_json(destination / "index.json", index)
        checksum = legacy.digest(destination / "index.json")
        seal(destination)
        return checksum

    def restore_artifact(self, bundle, index_digest, identity):
        bundle = Path(bundle)
        physical_tree(bundle)
        if legacy.digest(bundle / "index.json") != index_digest:
            raise ValueError("Artifact index differs from its trusted external digest")
        index = load_json(bundle / "index.json")
        require_fields(index, ("schema", "identity", "attempt", "receipt_sha256"))
        if index["schema"] != SCHEMA or index["identity"] != identity or index["attempt"] != "attempt":
            raise ValueError("Artifact index identity/path changed")
        if {path.name for path in bundle.iterdir()} != {"attempt", "index.json"}:
            raise ValueError("Artifact contains unaccounted entries")
        return self.restore(bundle / "attempt", index["receipt_sha256"], identity)


def freeze_build(mode, builder, destination):
    """One exclusive build/discovery per mode; workers may only use its frozen manifest."""
    with builder.preparation_claim():
        return _freeze_build(mode, builder, destination)


def _freeze_build(mode, builder, destination):
    if mode not in MODES or Path(destination).exists():
        raise ValueError("Invalid or existing frozen build destination")
    runtime, methods, groups, image, head = builder.build_and_discover(mode)
    validate_runtime(runtime)
    if runtime["mode"] != mode or legacy.digest(Path(image)) != runtime["image_sha256"]:
        raise ValueError("Builder did not return the actual mode image")
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise ValueError("Frozen build must have a committed tested head")
    destination = Path(destination)
    legacy.owned_directory(destination)
    value = {"schema": SCHEMA, "runtime": runtime, "inventory": sorted(methods),
             "shared_groups": groups, "image": str(Path(image).resolve()), "tested_head": head}
    # Validate all units now; the build cannot silently remove or split a suite.
    make_plan(runtime, methods, groups)
    durable_json(destination / "build.json", value)
    seal(destination)
    return value


def ephemeral_bindings(paths):
    require_fields(paths, ("proof", "temporary"))
    proof, temporary = Path(paths["proof"]), Path(paths["temporary"])
    if (not proof.is_absolute() or not temporary.is_absolute() or proof.name != temporary.name
            or temporary.is_relative_to(proof) or proof.is_relative_to(temporary)
            or ".." in proof.parts or ".." in temporary.parts):
        raise ValueError("Invalid attempt-owned temporary path")
    return {"TMPDIR": {"kind": "owned-attempt-temporary-v1", "path": str(temporary)},
            "LLVM_PROFILE_FILE": {"kind": "owned-attempt-profile-pattern-v1",
                                  "path": str(proof / "profiles" / "%p-%m.profraw")}}


def child_environment(attempt, environment):
    paths = (load_json(attempt / "start.json")["paths"] if (attempt / "start.json").exists()
             else {"proof": str(attempt), "temporary": str(attempt.parent / "temporary" / attempt.name)})
    bindings = ephemeral_bindings(paths)
    legacy.owned_directory(Path(bindings["TMPDIR"]["path"]))
    legacy.owned_directory(attempt / "profiles")
    value = dict(environment)
    value.update({name: binding["path"] for name, binding in bindings.items()})
    durable_json(attempt / "environment.json", {"schema": SCHEMA,
                 "base": legacy.runtime_identity(environment), "actual": legacy.runtime_identity(value),
                 "bindings": bindings})
    return value


def execute_process(command, workspace, attempt, timeout, descriptors, environment, observer=None,
                    isolate_environment=True):
    """Terminate only this owned process session on timeout, never report timeout as success."""
    actual_environment = child_environment(attempt, environment) if isolate_environment else dict(environment)
    with (attempt / "test.log").open("xb") as log:
        process = subprocess.Popen(command, cwd=workspace, env=actual_environment, stdout=log,
                                   stderr=subprocess.STDOUT, pass_fds=tuple(descriptors),
                                   start_new_session=True)
        durable_json(attempt / "child.json", {"pid": process.pid,
                                             "command": command, "started": time.time()})
        try:
            if observer:
                observer.start(process.pid)
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                code = 124
            if observer and not observer.finish(code != 0):
                code = code or 125
        except BaseException:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            if observer:
                observer.finish(True)
            raise
        durable_json(attempt / "child-exit.json", {"pid": process.pid, "exit_code": code})
        if code == 0 and isolate_environment:
            # Temp is outside the sealed proof. Failed/interrupted work retains it for recovery.
            shutil.rmtree(actual_environment["TMPDIR"])
        return code


def worker_limit(explicit, cpu_budget, ram_available, ram_reserve, peak_per_worker,
                 disk_available, disk_reserve, disk_per_worker):
    if type(explicit) is not int or explicit not in (1, 2):
        raise ValueError("Reviewed initial worker cap is one or two")
    for value in (cpu_budget, ram_available, ram_reserve, peak_per_worker,
                  disk_available, disk_reserve, disk_per_worker):
        positive(value)
    result = min(explicit, int(cpu_budget),
                 int((ram_available - ram_reserve) // peak_per_worker),
                 int((disk_available - disk_reserve) // disk_per_worker))
    if result < 1:
        raise ValueError("RAM/disk admission reserve blocks a new worker")
    return result


def run_shard(plan, shard_id, store, executor, current_head, timeout, admission,
              fault=lambda stage: None):
    """The injected executor owns a private prepared workspace and verifies runtime facts."""
    validate_plan(plan)
    shard = next(row for row in plan["shards"] if row["id"] == shard_id)
    identity = shard_identity(plan["runtime"], shard)
    if not re.fullmatch(r"[0-9a-f]{40}", current_head):
        raise ValueError("A committed current head is required")
    positive(timeout)
    with ExitStack() as stack:
        locks = [stack.enter_context(claim(store.root / "claims", "shard:" + shard_id))]
        locks.append(stack.enter_context(claim(store.root / "claims", "preparation", shared=True)))
        if hasattr(executor, "legacy_claim"):
            locks.append(stack.enter_context(executor.legacy_claim()))
        locks.append(stack.enter_context(claim(store.root / "claims",
                                               "workspace:" + str(executor.workspace))))
        # An unaudited atom excludes *all* other external-state consumers, not just other unknowns.
        locks.append(stack.enter_context(claim(store.root / "claims", "external-audit",
                                               shared=shard["audited"], wait_seconds=timeout)))
        for resource in shard["claims"]:
            locks.append(stack.enter_context(claim(store.root / "claims", "resource:" + resource,
                                                   wait_seconds=timeout)))
        executor.verify(plan["runtime"])
        if executor.unknown_live_helpers():
            raise ValueError("An unknown/disconnected live helper blocks replacement")
        found = store.matching(identity)
        if found:
            store.index([identity])
            return {"id": shard_id, "reused": True, "attempt": str(found[0]),
                    "tested_head": found[1]["tested_head"], "current_head": current_head}
        cap = worker_limit(**admission)
        # Every caller and mode on this host must use this same durable cache and cap.
        with claim(store.root / "claims", "admission", wait_seconds=timeout):
            policy_path = store.root / "admission.json"
            # One conservative maximum RSS/disk policy covers *all* modes/controllers.
            policy = {"schema": SCHEMA, "host": plan["runtime"]["host"],
                      "bounds": {name: value for name, value in admission.items()
                                 if name not in ("ram_available", "disk_available")}}
            if policy_path.exists() and load_json(policy_path) != policy:
                raise ValueError("Host worker admission policy changed")
            if not policy_path.exists():
                durable_json(policy_path, policy)
        # A single slot namespace covers all modes and all controller processes.
        for slot in range(cap):
            try:
                slot_lock = stack.enter_context(claim(store.root / "claims", "worker:" + str(slot)))
                locks.append(slot_lock)
                break
            except BlockingIOError:
                continue
        else:
            raise ValueError("All bounded host worker slots are occupied")
        parent = store.root / "attempts" / shard_id
        legacy.owned_directory(parent)
        for prior in parent.iterdir():
            if prior.is_dir() and not (prior / "result.json").exists():
                if not executor.proven_exited(prior):
                    raise ValueError("Incomplete attempt still has an unproven owner")
        attempt = parent / str(uuid.uuid4())
        legacy.owned_directory(attempt)
        durable_json(attempt / "start.json", {"identity": identity, "tested_head": current_head,
                                             "owner": executor.owner_identity(),
                                             "paths": {"proof": str(attempt), "temporary": str(
                                                 store.root / "temporary" / attempt.name)}})
        fault("before-execution")
        started = time.monotonic()
        # The executor must retain inherited claim descriptors in its owned child.
        exit_code = executor.execute(shard, attempt, timeout, [lock.fileno() for lock in locks])
        fault("after-exit")
        if type(exit_code) is not int or exit_code != 0:
            durable_json(attempt / "failure.json", {"status": "failed", "exit_code": exit_code})
            raise ValueError("Shard process failed or timed out")
        executor.verify(plan["runtime"])
        validate_plan(plan)
        outputs = evidence_outputs(attempt, plan["runtime"], shard["methods"])
        fault("before-receipt")
        durable_json(attempt / "result.json", {
            "schema": SCHEMA, "status": "passed", "identity": identity,
            "tested_head": current_head, "exit_code": 0,
            "seconds": max(time.monotonic() - started, 0.000001), "outputs": outputs})
        durable_json(attempt / "commit.json", {
            "schema": SCHEMA, "receipt_sha256": legacy.digest(attempt / "result.json")})
        seal(attempt)
        sync_directory(parent.parent)
        sync_directory(store.root)
        fault("after-receipt")
        validate_success(attempt, identity)
        store.index([identity])
        fault("before-upload")
        return {"id": shard_id, "reused": False, "attempt": str(attempt),
                "tested_head": current_head, "current_head": current_head}


def run_pending(plans, store, executors, current_head, timeout, admission):
    """One bounded pool, not one independent unbounded pool per sanitizer mode."""
    if not executors or len(executors) > 2 or len({str(x.workspace) for x in executors}) != len(executors):
        raise ValueError("One or two distinct owned worker workspaces are required")
    if len(executors) > worker_limit(**admission):
        raise ValueError("Requested pool exceeds CPU/RAM/disk admission")
    if len({plan["runtime"]["host"] for plan in plans}) != 1:
        raise ValueError("One pool cannot promote receipts across hosts")
    for plan in plans:
        validate_plan(plan)
    results = []
    # One task per worker; each owns its own SwiftPM scratch/database for its whole queue.
    pending = sorted(((plan, row) for plan in plans for row in plan["shards"]),
                     key=lambda pair: (-pair[1]["estimated_seconds"], pair[1]["id"]))
    queues = [pending[index::len(executors)] for index in range(len(executors))]
    def work(executor, queue):
        output = []
        for plan, shard in queue:
            try:
                output.append(run_shard(plan, shard["id"], store, executor, current_head, timeout,
                                        admission))
            except (OSError, ValueError, ET.ParseError) as error:
                output.append({"id": shard["id"], "failed": str(error)})
        return output
    with ThreadPoolExecutor(max_workers=len(executors)) as pool:
        futures = [pool.submit(work, executor, queue) for executor, queue in zip(executors, queues)]
        for future in futures:
            results.extend(future.result())
    store.index([shard_identity(plan["runtime"], row) for plan in plans for row in plan["shards"]])
    return results


def canonical_inputs(inputs):
    """Only scratch checkout prefixes vary; dependency names/contents never do."""
    result = {}
    for name, digest in inputs.items():
        key = ("dependencies/" + name.split("/checkouts/", 1)[1]
               if name.startswith(".build/") and "/checkouts/" in name else name)
        if key in result:
            raise ValueError("Ambiguous dependency input")
        result[key] = digest
    return result


def phase_matches_runtime(identity, runtime, inventory):
    if (identity["phase"] not in ("normal", "leaks")
            or canonical_inputs(identity["inputs"]) != canonical_inputs(runtime["inputs"])
            or identity["swift"] != runtime["toolchain"]
            or fingerprint({"version": identity["sdk"], "path": identity["sdk_path"]}) != runtime["sdk"]
            or fingerprint(identity["os_version"]) != runtime["os"]
            or identity["architecture"] != runtime["architecture"]
            or identity["environment"] != runtime["phase_environment"]):
        raise ValueError("Full phase belongs to different executable inputs or runtime")
    if identity["phase"] == "normal":
        if (identity["inventory"] != inventory or identity["opt_in_policy"] != runtime["opt_in_policy"]
                or identity["policy"] != "normal-coverage-80-v1"
                or identity["flags"] != ["--enable-code-coverage"] or identity["parallel"] is not True):
            raise ValueError("Full normal phase/coverage policy was weakened")
    elif (identity["inventory"] or identity["policy"] != "leaks-at-exit-diagnostics-v1"
          or identity["flags"] or identity["parallel"] is not False):
        raise ValueError("Full leak phase policy was weakened")


def freeze_phase(attempt, identity, runtime, inventory, verifier, destination):
    """An authorized adapter must verify the actual host at capture, never infer it from old receipts."""
    verifier.verify(runtime)
    origin = verifier.phase_origin(Path(attempt), identity)
    phase_matches_runtime(identity, runtime, inventory)
    if not phases.successful_phase(Path(attempt), identity):
        raise ValueError("Full phase proof is incomplete")
    physical_tree(Path(attempt))
    result = load_json(Path(attempt) / "result.json")
    if (type(result["exit_code"]) is not int or result["exit_code"] != 0
            or type(result.get("native_exit_code")) is not int or result["native_exit_code"] != 0):
        raise ValueError("Phase needs explicit successful native and overall exits")
    destination = Path(destination)
    if destination.exists():
        raise ValueError("Phase proof destination exists")
    legacy.owned_directory(destination)
    shutil.copytree(attempt, destination / "attempt")
    manifest = {"schema": SCHEMA, "host": runtime["host"], "identity": identity, "origin": origin,
                "receipt_sha256": legacy.digest(destination / "attempt" / "result.json")}
    durable_json(destination / "index.json", manifest)
    checksum = legacy.digest(destination / "index.json")
    seal(destination)
    return checksum


def validate_phase(bundle, trusted_digest, phase, runtime, inventory):
    bundle = Path(bundle)
    physical_tree(bundle)
    if (legacy.digest(bundle / "index.json") != trusted_digest
            or {item.name for item in bundle.iterdir()} != {"index.json", "attempt"}):
        raise ValueError("Phase index differs from trusted host capture")
    manifest = load_json(bundle / "index.json")
    require_fields(manifest, ("schema", "host", "identity", "origin", "receipt_sha256"))
    identity = manifest["identity"]
    origin = manifest["origin"]
    require_fields(origin, ("schema", "host", "phase", "tested_head", "receipt_sha256", "exit_code"))
    if (manifest["schema"] != SCHEMA or manifest["host"] != runtime["host"]
            or identity["phase"] != phase
            or origin["schema"] != SCHEMA or origin["host"] != runtime["host"] or origin["phase"] != phase
            or type(origin["exit_code"]) is not int or origin["exit_code"] != 0
            or origin["receipt_sha256"] != manifest["receipt_sha256"]
            or legacy.digest(bundle / "attempt" / "result.json") != manifest["receipt_sha256"]):
        raise ValueError("Phase host, identity or receipt changed")
    phase_matches_runtime(identity, runtime, inventory)
    if not phases.successful_phase(bundle / "attempt", identity):
        raise ValueError("Full normal/zero-leak proof is missing or changed")
    result = load_json(bundle / "attempt" / "result.json")
    if (type(result["exit_code"]) is not int or result["exit_code"] != 0
            or type(result.get("native_exit_code")) is not int or result["native_exit_code"] != 0
            or origin["tested_head"] != result["tested_head"]):
        raise ValueError("Phase needs explicit successful native and overall exits")


def aggregate(plans, store, normal_bundle, normal_digest, leaks_bundle, leaks_digest):
    """No aggregate success without exact per-mode inventory, coverage and zero leaks."""
    if len(plans) != 2 or {plan["runtime"]["mode"] for plan in plans} != set(MODES):
        raise ValueError("Both sanitizer modes are mandatory exactly once")
    summaries = {}
    for plan in plans:
        validate_plan(plan)
        identities = [shard_identity(plan["runtime"], row) for row in plan["shards"]]
        receipts = [store.matching(identity) for identity in identities]
        if any(result is None for result in receipts):
            raise ValueError("A required shard is missing, failed or incomplete")
        actual = [method for _, result in receipts for method in result["identity"]["methods"]]
        if Counter(actual) != Counter(plan["inventory"]):
            raise ValueError("Aggregate inventory is not exactly once")
        summaries[plan["runtime"]["mode"]] = len(actual)
    if plans[0]["inventory"] != plans[1]["inventory"]:
        raise ValueError("Sanitizer mode inventories differ")
    for plan in plans:
        validate_phase(normal_bundle, normal_digest, "normal", plan["runtime"], plan["inventory"])
        validate_phase(leaks_bundle, leaks_digest, "leaks", plan["runtime"], plan["inventory"])
    return {"status": "passed", "modes": summaries,
            "qualification": "Component execution only; review/protection/release gates remain."}


def require_physical_activation():
    if not PHYSICAL_EXECUTION_ENABLED:
        raise ValueError("Physical execution HELD until G1 terminal and separately reviewed activation")


def native_output(command, workspace, environment, descriptors=()):
    return subprocess.check_output(command, cwd=workspace, env=environment,
                                   pass_fds=tuple(descriptors), stderr=subprocess.PIPE,
                                   text=True).strip()


def process_rows(raw):
    """Use the existing capture-quality ps format and PID/start/command ownership rules."""
    rows = {}
    for line in raw.splitlines():
        fields = line.split(None, 9)
        if len(fields) == 10:
            rows[int(fields[0])] = {"parent": int(fields[1]), "group": int(fields[2]),
                                   "state": fields[3], "start": " ".join(fields[4:9]),
                                   "command": fields[9]}
    return rows


def descendants(identities, rows):
    selected = {pid: row for pid, row in rows.items()
                if pid in identities and same_process(identities[pid], row)}
    while True:
        children = {pid: row for pid, row in rows.items() if row["parent"] in selected}
        if set(children) <= set(selected):
            return selected
        selected.update(children)


class NativeAuthority:
    """Host-owned activation extends workspace authorization; repository data cannot grant it."""
    def __init__(self, policy_path, environment=None, read=native_output):
        # This must precede even file inspection, git, ps, SDK or hardware probes.
        require_physical_activation()
        self.environment = dict(os.environ if environment is None else environment)
        self.read = read
        policy_path = Path(policy_path)
        if not policy_path.is_absolute() or policy_path != policy_path.resolve():
            raise ValueError("Host policy path must be absolute and physical")
        legacy.owned_directory(policy_path.parent)
        info = policy_path.lstat()
        if policy_path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Native activation policy must be host-owned")
        self.policy = load_json(policy_path)
        self.root = native_runner.validate(self.policy, self.environment)
        if policy_path.is_relative_to(self.root):
            raise ValueError("Repository content cannot authorize native execution")
        self.config = self.policy["recoverable_shards"]
        require_fields(self.config, ("schema", "host", "cache", "legacy_cache", "workers", "admission"))
        if type(self.config["schema"]) is not int or self.config["schema"] != SCHEMA or not self.config["workers"]:
            raise ValueError("Reviewed native workspace activation is required")
        self.cache = Path(self.config["cache"])
        self.legacy_cache = Path(self.config["legacy_cache"])
        self.workers = {name: Path(path) for name, path in self.config["workers"].items()}
        paths = [self.cache, self.legacy_cache, *self.workers.values()]
        if any(not path.is_absolute() or path != path.resolve() for path in paths):
            raise ValueError("Native paths must be absolute and physical")
        for path in paths:
            if path.is_relative_to(self.root) or self.root.is_relative_to(path):
                raise ValueError("Durable cache and private workers must be outside checkout")
        if any(one.is_relative_to(two) or two.is_relative_to(one)
               for index, one in enumerate(paths) for two in paths[index + 1:]):
            raise ValueError("Native cache/workspace reservations overlap")
        if len(self.workers) > 2 or self.config["admission"]["explicit"] > len(self.workers):
            raise ValueError("Unreserved worker capacity")
        for path in paths:
            legacy.owned_directory(path)
        if self.output(["git", "rev-parse", "HEAD"]) != self.policy["approved_head"]:
            raise ValueError("Controller source differs from the host-approved head")
        if self.output(["git", "status", "--porcelain"]):
            raise ValueError("Native preparation requires a clean committed controller")

    def output(self, command, workspace=None, environment=None, descriptors=()):
        return self.read(command, workspace or self.root, environment or self.environment, descriptors)

    def snapshot(self):
        return process_rows(self.output(["ps", "-axo", "pid=,ppid=,pgid=,stat=,lstart=,command="]))

    def host(self):
        raw = self.output(["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"])
        matches = re.findall(r'"IOPlatformUUID"\s*=\s*"([0-9A-Fa-f-]{36})"', raw)
        if len(matches) != 1 or matches[0].upper() != self.config["host"]:
            raise ValueError("Physical hardware identity differs from host activation")
        return matches[0].upper()

    def admission(self):
        bounds = dict(self.config["admission"])
        require_fields(bounds, ("explicit", "cpu_budget", "ram_reserve", "peak_per_worker",
                                "disk_reserve", "disk_per_worker"))
        cpus = int(self.output(["sysctl", "-n", "hw.logicalcpu"]))
        memory = self.output(["vm_stat"])
        size = re.search(r"page size of (\d+) bytes", memory)
        if not size:
            raise ValueError("Available memory evidence is missing")
        pages = []
        for name in ("Pages free", "Pages inactive", "Pages speculative"):
            match = re.search(re.escape(name) + r":\s*(\d+)\.", memory)
            if not match:
                raise ValueError("Available memory evidence is incomplete")
            pages.append(int(match[1]))
        bounds.update(cpu_budget=min(positive(bounds["cpu_budget"]), cpus),
                      ram_available=sum(pages) * int(size[1]),
                      disk_available=shutil.disk_usage(self.cache).free)
        worker_limit(**bounds)
        return bounds

    def environment_for(self, mode):
        value = runtime_child_environment(self.environment)
        if mode == "address":
            value["ASAN_OPTIONS"] = "detect_leaks=0"
        return value

    def runtime(self, workspace, mode, image, flags):
        environment = self.environment_for(mode)
        swift = shutil.which("swift", path=environment.get("PATH"))
        if not swift:
            raise ValueError("Approved Swift compiler is unavailable")
        uuids = image_uuids(image)
        if not uuids["uuids"]:
            raise ValueError("Actual test image UUID is unavailable")
        return {"schema": SCHEMA, "mode": mode,
                "inputs": legacy.executable_inputs(workspace, flags[1]),
                "toolchain": self.output([swift, "--version"], workspace, environment),
                "sdk": fingerprint({"version": self.output(["xcrun", "--show-sdk-version"]),
                                    "path": self.output(["xcrun", "--show-sdk-path"])}),
                "host": self.host(), "os": fingerprint({"release": os.uname().release,
                                                         "version": os.uname().version}),
                "architecture": platform.machine(), "image_sha256": legacy.digest(image),
                "image_uuid": fingerprint(uuids["uuids"]),
                "environment": legacy.runtime_identity(environment), "flags": flags,
                "phase_environment": legacy.runtime_identity(runtime_child_environment(self.environment)),
                "policy": POLICY, "opt_in_policy": legacy.opt_in_policy(workspace, environment)}


def copy_build_tree(source, destination):
    """SwiftPM's internal relative links are allowed; links escaping the frozen tree are not."""
    for directory, names, files in os.walk(source, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            info = path.lstat()
            if info.st_uid != os.getuid() or (not path.is_symlink() and info.st_mode & 0o022):
                raise ValueError("Build tree is foreign or publicly writable")
            if path.is_symlink() and (Path(os.readlink(path)).is_absolute()
                                      or not path.resolve().is_relative_to(source.resolve())):
                raise ValueError("Build link escapes the frozen scratch tree")
    shutil.copytree(source, destination, symlinks=True)


class NativeBuilder:
    def __init__(self, authority):
        self.authority, self.lock = authority, None

    @contextmanager
    def preparation_claim(self):
        with file_claim(self.authority.legacy_cache / "executor.lock") as lock, claim(
                self.authority.cache / "claims", "preparation"):
            self.lock = lock
            try:
                # Legacy workers cannot overlap this build, even after a future activation.
                legacy.ensure_no_live_tests()
                if any("swiftpm-testing-helper" in row["command"]
                       or ".xctest/Contents/MacOS/Elite" in row["command"]
                       for row in self.authority.snapshot().values()):
                    raise ValueError("A live test helper blocks exclusive preparation")
                self.authority.admission()
                yield lock
            finally:
                self.lock = None

    def build_and_discover(self, mode):
        if self.lock is None:
            raise ValueError("Native build requires exclusive preparation ownership")
        root, env = self.authority.root, self.authority.environment_for(mode)
        swift = shutil.which("swift", path=env.get("PATH"))
        if swift is None:
            raise ValueError("Approved Swift compiler is unavailable")
        flags = ["--scratch-path", ".build/tsan" if mode == "thread" else ".build/asan",
                 "--sanitize=" + mode]
        report = self.authority.cache / "preparation" / str(uuid.uuid4())
        legacy.owned_directory(report)
        before = legacy.executable_inputs(root, flags[1])
        image, methods, _ = legacy.build_and_discover(root, swift, flags, env, self.lock, report)
        runtime = self.authority.runtime(root, mode, image, flags)
        if any(runtime["inputs"].get(name) != digest for name, digest in before.items()):
            raise ValueError("Executable inputs changed during preparation")
        # Preserve both reviewed process groups in ASAN too; do not infer external independence.
        groups = legacy.grouping_policy(root, methods, "thread", 1)["shared_groups"]
        head = self.authority.output(["git", "rev-parse", "HEAD"])
        if head != self.authority.policy["approved_head"] or self.authority.output(
                ["git", "status", "--porcelain"]):
            raise ValueError("Controller checkout changed during preparation")
        return runtime, methods, groups, image, head

    def prepare(self, mode, destination):
        with self.preparation_claim():
            destination = Path(destination)
            if destination.exists():
                physical_tree(destination)
                build = load_json(destination / "build.json")
                actual = self.authority.runtime(self.authority.root, mode, Path(build["image"]),
                                                build["runtime"]["flags"])
                if build["runtime"] != actual or build["tested_head"] != self.authority.policy["approved_head"]:
                    raise ValueError("Frozen build differs from current preparation")
            else:
                build = _freeze_build(mode, self, destination)
            for base in self.authority.workers.values():
                with claim(self.authority.cache / "claims", "workspace:" + str(base)):
                    self.prepare_worker(build, base)
            return build

    def prepare_worker(self, build, base):
        mode = build["runtime"]["mode"]
        workspace, marker = base / mode, base / (mode + "-build.json")
        if marker.exists():
            if load_json(marker) != build:
                raise ValueError("Worker contains another build; reserve a new workspace")
            image = workspace / Path(build["image"]).relative_to(self.authority.root)
            if self.authority.runtime(workspace, mode, image, build["runtime"]["flags"]) != build["runtime"]:
                raise ValueError("Existing private worker changed")
            return
        if workspace.exists():
            raise ValueError("Uncommitted private worker preparation requires inspection")
        self.authority.output(["git", "clone", "--no-hardlinks", "--no-checkout",
                               str(self.authority.root), str(workspace)])
        self.authority.output(["git", "checkout", "--detach", build["tested_head"]], workspace)
        scratch = Path(build["runtime"]["flags"][1])
        legacy.owned_directory((workspace / scratch).parent)
        copy_build_tree(self.authority.root / scratch, workspace / scratch)
        image = workspace / Path(build["image"]).relative_to(self.authority.root)
        if self.authority.runtime(workspace, mode, image, build["runtime"]["flags"]) != build["runtime"]:
            raise ValueError("Copied private image/source/runtime differs from frozen build")
        durable_json(marker, build)
        marker.chmod(0o400)


class NativeMonitor:
    """Persist verified descendants; reuse capture-quality cleanup's fresh identity checks."""
    def __init__(self, authority, attempt, workspace):
        self.authority, self.attempt, self.workspace = authority, attempt, workspace
        self.known, self.errors = {}, []
        self.controller, self.root_identity = None, None
        self.stop, self.thread = threading.Event(), None

    def observe(self):
        rows = self.authority.snapshot()
        live = descendants(self.known, rows)
        self.known.update(live)
        durable_json(self.attempt / "processes.json", {"schema": SCHEMA, "workspace": str(self.workspace),
                                                      "controller": self.controller,
                                                      "root": self.root_identity,
                                                      "running": not self.stop.is_set(),
                                                      "processes": {str(pid): row for pid, row in self.known.items()}})
        return live

    def start(self, pid):
        rows = self.authority.snapshot()
        row, controller = rows.get(pid), rows.get(os.getpid())
        if row is None or controller is None:
            raise ValueError("Native child has no verified launch identity")
        self.controller = {"pid": os.getpid(), **controller}
        self.root_identity = {"pid": pid, **row}
        self.known[pid] = row
        self.observe()
        def watch():
            try:
                while not self.stop.wait(0.1):
                    self.observe()
            except Exception as error:
                self.errors.append(type(error).__name__)
        self.thread = threading.Thread(target=watch)
        self.thread.start()

    def finish(self, failed):
        self.stop.set()
        if self.thread:
            self.thread.join(timeout=5)
        if self.thread and self.thread.is_alive():
            self.errors.append("monitor did not stop")
            return False
        deadline = time.monotonic() + (0 if failed else 2)
        live = self.observe()
        while live and time.monotonic() < deadline:
            time.sleep(0.05)
            live = self.observe()
        clean = not live and not self.errors
        for pid, row in live.items():
            cleanup_owned_identity({"pid": pid, **row}, self.authority.snapshot)
        if self.observe():
            return False
        return clean


class NativeExecutor:
    def __init__(self, authority, worker):
        if worker not in authority.workers:
            raise ValueError("Worker is outside the host-owned reservation")
        self.authority, self.workspace = authority, authority.workers[worker]
        self.active_workspace, self.runtime = None, None

    def legacy_claim(self):
        return file_claim(self.authority.legacy_cache / "executor.lock", shared=True)

    def verify(self, runtime):
        mode = runtime["mode"]
        build = load_json(self.workspace / (mode + "-build.json"))
        workspace = self.workspace / mode
        image = workspace / Path(build["image"]).relative_to(self.authority.root)
        actual = self.authority.runtime(workspace, mode, image, runtime["flags"])
        if (actual != runtime or build["runtime"] != runtime
                or legacy.executable_inputs(self.authority.root, runtime["flags"][1]) != runtime["inputs"]
                or self.authority.output(["git", "rev-parse", "HEAD"], workspace) != build["tested_head"]
                or self.authority.output(["git", "status", "--porcelain"], workspace)):
            raise ValueError("Private source, image, environment or toolchain changed")
        self.active_workspace, self.runtime = workspace, runtime

    def registered_processes(self, rows):
        known = {}
        attempts = self.authority.cache / "attempts"
        if attempts.exists():
            for path in attempts.glob("*/*/processes.json"):
                legacy.owned_directory(path.parent)
                info = path.lstat()
                if path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
                    raise ValueError("Process registration is not owned")
                record = load_json(path)
                if record["schema"] != SCHEMA or Path(record["workspace"]).parent not in self.authority.workers.values():
                    raise ValueError("Unknown worker process registration")
                # A saved ledger alone cannot authorize a disconnected/reparented helper.
                if (record["running"] is not True or not record["controller"] or not record["root"]
                        or not same_process(record["controller"], rows.get(record["controller"]["pid"]))
                        or not same_process(record["root"], rows.get(record["root"]["pid"]))):
                    continue
                known.update({int(pid): row for pid, row in record["processes"].items()})
        return known

    def unknown_live_helpers(self):
        rows = self.authority.snapshot()
        owned = descendants(self.registered_processes(rows), rows)
        return any(("swiftpm-testing-helper" in row["command"] or ".xctest/Contents/MacOS/Elite" in row["command"])
                   and pid not in owned for pid, row in rows.items())

    def owner_identity(self):
        row = self.authority.snapshot().get(os.getpid())
        if row is None:
            raise ValueError("Controller has no verified process identity")
        return {"pid": os.getpid(), **row, "image_sha256": legacy.digest(Path(sys.executable))}

    def proven_exited(self, attempt):
        start = load_json(attempt / "start.json")
        rows = self.authority.snapshot()
        path = attempt / "processes.json"
        known = {int(pid): row for pid, row in load_json(path)["processes"].items()} if path.exists() else {}
        if descendants(known, rows):
            return False
        if (attempt / "child-exit.json").exists():
            terminal, child = load_json(attempt / "child-exit.json"), load_json(attempt / "child.json")
            if (type(terminal["exit_code"]) is not int or terminal["pid"] != child["pid"]
                    or (path.exists() and load_json(path)["running"] is not False)):
                return False
            return True
        return not same_process(start["owner"], rows.get(start["owner"]["pid"]))

    def execute(self, shard, attempt, timeout, descriptors):
        swift = shutil.which("swift", path=self.authority.environment_for(self.runtime["mode"]).get("PATH"))
        command = legacy.batch_command(swift, self.runtime["flags"], self.runtime["mode"],
                                       attempt, shard["methods"])
        monitor = NativeMonitor(self.authority, attempt, self.active_workspace)
        code = execute_process(command, self.active_workspace, attempt, timeout, descriptors,
                               self.authority.environment_for(self.runtime["mode"]), monitor)
        if self.unknown_live_helpers():
            return code or 126
        return code


class NativePhaseRunner:
    """Capture host provenance before a fresh full phase, never relabel an imported legacy receipt."""
    def __init__(self, authority, executor):
        self.authority, self.executor = authority, executor
        self.origin, self.attempt = None, None

    def verify(self, runtime):
        self.executor.verify(runtime)

    def phase_origin(self, attempt, identity):
        if (attempt != self.attempt or self.origin is None
                or self.origin["phase"] != identity["phase"]
                or self.origin["receipt_sha256"] != legacy.digest(attempt / "result.json")):
            raise ValueError("No host-bound fresh phase execution origin")
        return self.origin

    def run(self, phase, plan, destination, timeout):
        validate_plan(plan)
        with NativeBuilder(self.authority).preparation_claim() as lock:
            self.verify(plan["runtime"])
            execution = self.authority.cache / "phase-runs" / str(uuid.uuid4())
            legacy.owned_directory(execution)
            head, host = self.authority.policy["approved_head"], self.authority.host()
            durable_json(execution / "launch.json", {"host": host, "phase": phase, "head": head})
            fresh_cache = execution / "fresh-cache"
            command = [sys.executable, str(self.authority.root / "Tools/CI/quality_phase_checkpoints.py"),
                       phase, "--cache", str(fresh_cache)]
            monitor = NativeMonitor(self.authority, execution, self.authority.root)
            code = execute_process(command, self.authority.root, execution, timeout, [lock.fileno()],
                                   runtime_child_environment(self.authority.environment), monitor,
                                   isolate_environment=False)
            if code or self.executor.unknown_live_helpers():
                raise ValueError("Full phase process/descendants failed")
            receipts = list(fresh_cache.glob("phases/*/*/result.json"))
            if len(receipts) != 1:
                raise ValueError("Expected exactly one fresh full phase outcome")
            self.attempt = receipts[0].parent
            result = load_json(receipts[0])
            if result["tested_head"] != head or self.authority.host() != host:
                raise ValueError("Full phase did not execute on this approved host/head")
            self.origin = {"schema": SCHEMA, "host": host, "phase": phase,
                           "tested_head": head, "receipt_sha256": legacy.digest(receipts[0]), "exit_code": code}
            return freeze_phase(self.attempt, result["identity"], plan["runtime"], plan["inventory"],
                                self, destination)


def trusted_json(path, checksum):
    if not checksum or not re.fullmatch(r"[0-9a-f]{64}", checksum) or legacy.digest(path) != checksum:
        raise ValueError("A separately trusted manifest digest is required")
    if path.is_symlink() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o022:
        raise ValueError("Manifest must be physical, owned and not publicly writable")
    return load_json(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "prepare", "worker", "pool", "export", "restore",
                                             "phase", "aggregate"))
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--digest")
    parser.add_argument("--policy", type=Path, default=os.environ.get("ELITE_NATIVE_POLICY"))
    parser.add_argument("--mode", choices=MODES)
    parser.add_argument("--worker")
    parser.add_argument("--shard")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--artifact-digest")
    parser.add_argument("--phase", choices=("normal", "leaks"))
    args = parser.parse_args()
    if args.command == "plan":
        if args.input is None or args.output is None:
            parser.error("plan requires --input and --output")
        source = load_json(args.input)
        plan = make_plan(source["runtime"], source["inventory"], source.get("shared_groups", []),
                         source.get("history"), source.get("resources"), source.get("budget_seconds", 600))
        durable_json(args.output, plan)
        return
    # Every native operation, including restoration/qualification, is held before any probe.
    require_physical_activation()
    if args.policy is None:
        parser.error("a host-owned activation policy is required")
    authority = NativeAuthority(args.policy)
    store = Store(authority.cache)
    positive(args.timeout)
    if args.command == "prepare":
        if args.mode is None or args.output is None:
            parser.error("prepare requires --mode and --output")
        hints = load_json(args.input) if args.input else {}
        destination = authority.cache / "builds" / authority.policy["approved_head"] / args.mode
        build = NativeBuilder(authority).prepare(args.mode, destination)
        plan = make_plan(build["runtime"], build["inventory"], build["shared_groups"], hints.get("history"),
                         hints.get("resources"), hints.get("budget_seconds", 600))
        durable_json(args.output, plan)
        legacy.progress(json.dumps({"plan_sha256": legacy.digest(args.output)}))
        return
    if args.input is None:
        parser.error("a manifest --input and separately trusted --digest are required")
    source = trusted_json(args.input, args.digest)
    if args.command in ("pool", "aggregate"):
        plans = [validate_plan(trusted_json(Path(item["path"]), item["sha256"])) for item in source["plans"]]
    else:
        plans = [validate_plan(source)]
    if args.command == "aggregate":
        for plan in plans:
            NativeExecutor(authority, sorted(authority.workers)[0]).verify(plan["runtime"])
        result = aggregate(plans, store, source["normal"]["path"], source["normal"]["sha256"],
                           source["leaks"]["path"], source["leaks"]["sha256"])
    elif args.command == "pool":
        admission = authority.admission()
        executors = [NativeExecutor(authority, name) for name in sorted(authority.workers)][:worker_limit(**admission)]
        result = run_pending(plans, store, executors, authority.policy["approved_head"], args.timeout, admission)
        if any("failed" in row for row in result):
            raise ValueError("Pool has failed/missing shard outcomes; retained evidence must be retried")
    elif args.command == "phase":
        if args.phase is None or args.output is None or args.worker is None:
            parser.error("phase requires --phase, --worker and --output")
        checksum = NativePhaseRunner(authority, NativeExecutor(authority, args.worker)).run(
            args.phase, plans[0], args.output, args.timeout)
        result = {"phase_sha256": checksum}
    else:
        shard = next((row for row in plans[0]["shards"] if row["id"] == args.shard), None)
        if shard is None:
            parser.error("an exact planned --shard is required")
        identity = shard_identity(plans[0]["runtime"], shard)
        if args.command == "worker":
            result = run_shard(plans[0], args.shard, store, NativeExecutor(authority, args.worker),
                               authority.policy["approved_head"], args.timeout, authority.admission())
        elif args.command == "export":
            if args.output is None:
                parser.error("export requires --output")
            result = {"index_sha256": store.export(identity, args.output)}
        else:
            if args.artifact is None or args.artifact_digest is None:
                parser.error("restore requires --artifact and trusted --artifact-digest")
            result = {"restored": str(store.restore_artifact(args.artifact, args.artifact_digest, identity))}
    legacy.progress(json.dumps(result))


if __name__ == "__main__":
    main()
