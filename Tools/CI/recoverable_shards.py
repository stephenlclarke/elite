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
import re
import shutil
import signal
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

import quality_phase_checkpoints as phases
import sanitizer_checkpoints as legacy

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
                             "environment", "flags", "policy", "opt_in_policy"))
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
               "commit.json", "child.json", "child-exit.json"}
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


def execute_process(command, workspace, attempt, timeout, descriptors, environment):
    """Terminate only this owned process session on timeout, never report timeout as success."""
    legacy.owned_directory(attempt / "tmp")
    legacy.owned_directory(attempt / "profiles")
    child_environment = dict(environment)
    child_environment.update(TMPDIR=str(attempt / "tmp"),
                             LLVM_PROFILE_FILE=str(attempt / "profiles" / "%p-%m.profraw"))
    with (attempt / "test.log").open("xb") as log:
        process = subprocess.Popen(command, cwd=workspace, env=child_environment, stdout=log,
                                   stderr=subprocess.STDOUT, pass_fds=tuple(descriptors),
                                   start_new_session=True)
        durable_json(attempt / "child.json", {"pid": process.pid,
                                             "command": command, "started": time.time()})
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
        durable_json(attempt / "child-exit.json", {"pid": process.pid, "exit_code": code})
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
            policy = {"schema": SCHEMA, "host": plan["runtime"]["host"], "cap": admission["explicit"]}
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
                                             "owner": executor.owner_identity()})
        fault("before-execution")
        started = time.monotonic()
        # The executor must retain inherited claim descriptors in its owned child.
        exit_code = executor.execute(shard, attempt, timeout, [lock.fileno() for lock in locks])
        fault("after-exit")
        if type(exit_code) is not int or exit_code != 0:
            durable_json(attempt / "failure.json", {"status": "failed", "exit_code": exit_code})
            raise ValueError("Shard process failed or timed out")
        executor.verify(plan["runtime"])
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
            or identity["environment"] != runtime["environment"]):
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
    manifest = {"schema": SCHEMA, "host": runtime["host"], "identity": identity,
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
    require_fields(manifest, ("schema", "host", "identity", "receipt_sha256"))
    identity = manifest["identity"]
    if (manifest["schema"] != SCHEMA or manifest["host"] != runtime["host"]
            or identity["phase"] != phase
            or legacy.digest(bundle / "attempt" / "result.json") != manifest["receipt_sha256"]):
        raise ValueError("Phase host, identity or receipt changed")
    phase_matches_runtime(identity, runtime, inventory)
    if not phases.successful_phase(bundle / "attempt", identity):
        raise ValueError("Full normal/zero-leak proof is missing or changed")
    result = load_json(bundle / "attempt" / "result.json")
    if (type(result["exit_code"]) is not int or result["exit_code"] != 0
            or type(result.get("native_exit_code")) is not int or result["native_exit_code"] != 0):
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "prepare", "worker"))
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.command != "plan":
        require_physical_activation()
        raise ValueError("Authorized independent worker-workspace adapter is not activated")
    if args.input is None or args.output is None:
        parser.error("plan requires --input and --output")
    source = load_json(args.input)
    plan = make_plan(source["runtime"], source["inventory"], source.get("shared_groups", []),
                     source.get("history"), source.get("resources"), source.get("budget_seconds", 600))
    durable_json(args.output, plan)


if __name__ == "__main__":
    main()
