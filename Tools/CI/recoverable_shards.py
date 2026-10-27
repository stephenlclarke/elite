#!/usr/bin/env python3
"""Opt-in shard planning and recovery; the existing quality executor is unchanged."""

import argparse
import codecs
import errno
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
import select
import shutil
import signal
import subprocess
import sys
import threading
import time
import tty
import uuid
import xml.etree.ElementTree as ET
import zipfile

import quality_phase_checkpoints as phases
import sanitizer_checkpoints as legacy
from crash_artifacts import (arguments, cleanup_owned_identity, confined, image_uuids,
                             runtime_child_environment, same_process)
import native_runner

SCHEMA = 1
POLICY = "recoverable-parallel-shards-v1"
# Execution is available only with the separately installed exact-head owned authorization.
PHYSICAL_EXECUTION_ENABLED = True
SHARD_MAX_SECONDS = 7200
PACKED_ID_TARGET = 64
MODES = ("thread", "address")
AUTHORIZATION_CONTROLS = (
    "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_PATH",
    "ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
    "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE",
    "ELITE_RECOVERABLE_POLICY_SHA256", "ELITE_RECOVERABLE_WORKFLOW_SHA256",
    "ELITE_RECOVERABLE_ACTIVATION_SHA256", "ELITE_RECOVERABLE_CODE_ENABLED")


def execution_policy_digest(config):
    """Shared execution limits matter; planning hints and physical worker assignment do not."""
    return fingerprint({"schema": SCHEMA, "policy": POLICY, "host": config["host"], "admission": config["admission"]})


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


def validate_authorization(record, runtime):
    require_fields(record, ("schema", "kind", "head", "host", "role", "run_id", "run_attempt", "mode", "shard",
                            "worker", "phase", "workflow_sha256", "plan_sha256", "instance", "workspace",
                            "policy_sha256", "execution_policy_sha256", "controls"))
    expected = runtime["environment"].get("ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256")
    if (type(record["schema"]) is not int or record["schema"] != SCHEMA or record["kind"] != "validated-control-plane-v1"
            or set(record["controls"]) != set(AUTHORIZATION_CONTROLS)
            or record["host"] != runtime["host"]
            or record["role"] not in native_runner.RECOVERABLE_JOBS
            or not re.fullmatch(r"[0-9a-f]{40}", record["head"])
            or any(not re.fullmatch(r"[1-9][0-9]*", record[name]) for name in ("run_id", "run_attempt"))
            or any(not re.fullmatch(r"[0-9a-f]{64}", record[name]) for name in (
                "policy_sha256", "execution_policy_sha256", "workflow_sha256"))
            or any(value is not None and not re.fullmatch(r"[0-9a-f]{64}", value) for value in record["controls"].values())
            or hashlib.sha256(record["execution_policy_sha256"].encode()).hexdigest() != expected):
        raise ValueError("Authorization and actual child execution policy differ")
    for field, name in (("policy_sha256", "ELITE_RECOVERABLE_POLICY_SHA256"),
                        ("workflow_sha256", "ELITE_RECOVERABLE_WORKFLOW_SHA256")):
        if record["controls"][name] != hashlib.sha256(record[field].encode()).hexdigest():
            raise ValueError("Typed authorization controls differ from admitted facts")
    if record["controls"]["ELITE_RECOVERABLE_CODE_ENABLED"] != hashlib.sha256(b"true").hexdigest():
        raise ValueError("Parent activation was not validated")


def positive(value):
    if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
        raise ValueError("A finite positive resource bound is required")
    return value


def durable_json(path, value):
    """Use the existing atomic writer, then persist the containing directory."""
    temporary = path.with_name(path.name + ".pending-" + str(uuid.uuid4()))
    legacy.atomic_json(temporary, value)
    temporary.chmod(0o600)
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


def make_plan(runtime, methods, shared_groups=(), history=None, resources=None, budget=600, pack=True, max_methods=None):
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
                      if pack and row["seconds"] < budget and row["seconds"] + unit["seconds"] <= budget
                      and (max_methods is None or sum(len(item["methods"]) for item in row["units"])
                           + len(unit["methods"]) <= max_methods)]
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
               "commit.json", "child.json", "child-exit.json", "processes.json", "environment.json", "authorization.json",
               "test-events.jsonl", "test-progress.json"}
    if any(name not in allowed and not name.startswith("profiles/") for name in entries):
        raise ValueError("Unaccounted evidence file")
    progress_files = {"test-events.jsonl", "test-progress.json"}
    if progress_files & set(entries):
        if not progress_files <= set(entries):
            raise ValueError("Incomplete observational progress files")
        observation = load_json(attempt / "test-progress.json")
        required = {"schema", "kind", "mode", "shard", "selected_method_count", "state", "exit_code",
                    "elapsed_seconds", "observed_counts", "observed_active", "partial_line", "stream_eof",
                    "transport_error", "authority"}
        if (not required <= set(observation) or set(observation) - required - {"validated_shards_completed", "shards_total"}
                or observation["schema"] != SCHEMA or observation["kind"] != "observed-test-progress-v1"
                or observation["mode"] != runtime["mode"] or observation["selected_method_count"] != len(methods)
                or observation["shard"] != fingerprint(load_json(attempt / "start.json")["identity"])
                or observation["state"] != "exited" or observation["exit_code"] != 0
                or observation["stream_eof"] is not True or observation["transport_error"] is not None
                or type(observation["elapsed_seconds"]) not in (int, float)
                or not math.isfinite(observation["elapsed_seconds"]) or observation["elapsed_seconds"] < 0):
            raise ValueError("Observational progress differs from its actual terminal shard")
        sequence = 0
        for line in (attempt / "test-events.jsonl").read_text().splitlines():
            event = json.loads(line)
            if (event.get("schema") != SCHEMA or event.get("mode") != runtime["mode"]
                    or event.get("shard") != observation["shard"] or type(event.get("sequence")) is not int
                    or event["sequence"] <= sequence or not isinstance(event.get("name"), str)
                    or event.get("kind") not in ("started", "passed", "failed", "skipped", "cancelled", "recorded an issue")):
                raise ValueError("Malformed observational test event")
            sequence = event["sequence"]
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
    if "ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256" in runtime["environment"]:
        authorization = load_json(attempt / "authorization.json")
        validate_authorization(authorization, runtime)
        if authorization["head"] != load_json(attempt / "start.json")["tested_head"]:
            raise ValueError("Authorized source and actual attempt head differ")
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
        require_sealed(attempt)
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
            if path.is_symlink():
                continue
            with path.open("rb") as stream:
                os.fsync(stream.fileno())
            path.chmod(0o500 if path.stat().st_mode & 0o111 else 0o400)
        Path(directory).chmod(0o500)
        sync_directory(directory)
    sync_directory(attempt.parent)


def require_sealed(root):
    for directory, names, files in os.walk(root, followlinks=False):
        if Path(directory).stat().st_mode & 0o222 or any(
                not (Path(directory) / name).is_symlink() and (Path(directory) / name).stat().st_mode & 0o222
                for name in files):
            raise ValueError("Committed checkpoint is not immutable")


def atomic_copy(source, destination):
    legacy.owned_directory(destination.parent)
    stage = destination.with_name(destination.name + ".pending-" + str(uuid.uuid4()))
    shutil.copytree(source, stage)
    seal(stage)
    stage.rename(destination)
    sync_directory(destination.parent)


class Store:
    def __init__(self, root):
        self.root = Path(root)
        legacy.owned_directory(self.root)

    def matching(self, identity):
        parent = self.root / "attempts" / fingerprint(identity)
        if not parent.exists():
            return None
        legacy.owned_directory(parent)
        for attempt in sorted(parent.iterdir()):
            if attempt.is_symlink() or not attempt.is_dir():
                raise ValueError("Unexpected attempt storage entry")
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

    def restore_failure(self, bundle, identity):
        """Called only after external archive authentication; retain exact timeout stops."""
        files = physical_tree(bundle)
        failure = load_json(bundle / "failure.json")
        require_fields(failure, ("schema", "status", "identity", "outputs"))
        if (failure["schema"] != SCHEMA or failure["identity"] != identity
                or failure["status"] not in ("failed", "missing")
                or failure["outputs"] != {name: digest for name, digest in files.items() if name != "failure.json"}
                or set(path.name for path in bundle.iterdir()) - {"failure.json", "last-attempt"}):
            raise ValueError("Authenticated failure bundle has changed identity/outputs")
        attempt = bundle / "last-attempt"
        if not attempt.is_dir() or not proved_timeout(attempt, identity):
            return False
        root = self.root / "timeout-blockers" / fingerprint(identity)
        legacy.owned_directory(root)
        with claim(self.root / "claims", "shard:" + fingerprint(identity)):
            destination = root / fingerprint(physical_tree(attempt))
            if not destination.exists():
                atomic_copy(attempt, destination)
            require_sealed(destination)
            if physical_tree(destination) != physical_tree(attempt) or not proved_timeout(destination, identity):
                raise ValueError("Restored timeout evidence changed")
        return True

    def export_outcome(self, identity, destination):
        if self.matching(identity):
            return {"status": "passed", "index_sha256": self.export(identity, destination)}
        destination = Path(destination)
        if destination.exists():
            raise ValueError("Outcome artifact already exists")
        legacy.owned_directory(destination)
        parent = self.root / "attempts" / fingerprint(identity)
        attempts = sorted(parent.iterdir(), key=lambda path: path.stat().st_mtime_ns) if parent.exists() else []
        if not attempts:
            attempts = [path for path in sorted((self.root / "timeout-blockers" / fingerprint(identity)).glob("*"))
                        if path.is_dir() and proved_timeout(path, identity)]
        if attempts:
            physical_tree(attempts[-1])
            shutil.copytree(attempts[-1], destination / "last-attempt")
        files = physical_tree(destination)
        durable_json(destination / "failure.json", {"schema": SCHEMA, "status": "failed" if attempts else "missing",
                                                   "identity": identity, "outputs": files})
        checksum = legacy.digest(destination / "failure.json")
        seal(destination)
        return {"status": "failed" if attempts else "missing", "index_sha256": checksum}


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
    if hasattr(builder, "image_relative"):
        value["image_relative"] = builder.image_relative(image)
        value["scratch"] = builder.freeze_scratch(runtime, destination)
    # Validate all units now; the build cannot silently remove or split a suite.
    make_plan(runtime, methods, groups)
    durable_json(destination / "build.json", value)
    durable_json(destination / "build-commit.json", {"sha256": legacy.digest(destination / "build.json")})
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


PROGRESS_HEARTBEAT_SECONDS = 30


class ObservedTestProgress:
    """Live output observations only; XML and sealed receipts remain the pass authority."""
    ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
    test_line = re.compile(r"^\S+ Test (.+) (started|passed|failed|skipped|cancelled|recorded an issue)([ .].*)$")

    def __init__(self, attempt, raw, context, clock=time.monotonic):
        self.attempt, self.raw, self.context, self.clock = attempt, raw, dict(context), clock
        if self.context.get("mode") not in MODES:
            raise ValueError("Progress mode is outside the actual sanitizer selection")
        required = {"mode", "shard", "selected_method_count"}
        if (not required <= set(self.context) or set(self.context) - required - {"validated_shards_completed", "shards_total"}
                or not re.fullmatch(r"[0-9a-f]{64}", self.context["shard"])
                or type(self.context["selected_method_count"]) is not int or self.context["selected_method_count"] < 1):
            raise ValueError("Progress requires the actual selected shard and method count")
        self.started, self.last_heartbeat = clock(), clock()
        self.sequence, self.active, self.counts = 0, {}, dict(started=0, completed=0, failed=0, skipped=0, cancelled=0, issues=0)
        self.pending, self.discard_line, self.partial = "", False, False
        self.decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        self.master = self.slave = None
        self.reader, self.events = None, None
        self.finishing, self.halt = threading.Event(), threading.Event()
        self.drain_deadline, self.eof, self.error = None, False, None

    def __enter__(self):
        try:
            self.master, self.slave = os.openpty()
            tty.setraw(self.slave)
            os.set_blocking(self.master, False)
            descriptor = os.open(self.attempt / "test-events.jsonl", os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
            self.events = os.fdopen(descriptor, "w", encoding="utf-8")
            self.publish("waiting-for-child", force=True)
            return self
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise

    def start(self):
        os.close(self.slave)
        self.slave = None
        self.reader = threading.Thread(target=self.drain, daemon=True)
        self.reader.start()

    def feed(self, block):
        self.raw.write(block)
        self.raw.flush()
        self.pending += self.decoder.decode(block)
        while "\n" in self.pending:
            line, self.pending = self.pending.split("\n", 1)
            if not self.discard_line:
                self.observe(line.rstrip("\r"))
            self.discard_line = False
        if len(self.pending) > 65536:
            # Preserve every raw byte, but never manufacture a truncated test name.
            self.pending, self.discard_line, self.partial = "", True, True

    def observe(self, line):
        match = self.test_line.match(self.ansi.sub("", line))
        if match is None or match[1] == "run" or match[1].startswith("run "):
            return
        name, action, tail = match.groups()
        now = self.clock()
        self.sequence += 1
        record = {"schema": SCHEMA, "kind": action, "sequence": self.sequence,
                  "mode": self.context["mode"], "shard": self.context["shard"], "name": name,
                  "line": line, "observed_elapsed_seconds": max(0, now - self.started)}
        duration = re.search(r" after ([0-9]+(?:\.[0-9]+)?) seconds?", tail)
        if duration is not None and math.isfinite(float(duration[1])):
            record["reported_seconds"] = float(duration[1])
        if action == "started":
            self.active[self.sequence] = {"name": name, "started": now}
            self.counts["started"] += 1
        elif action == "recorded an issue":
            self.counts["issues"] += 1
        else:
            matches = [key for key, item in self.active.items() if item["name"] == name]
            record["ambiguous_same_name"] = len(matches) > 1
            if len(matches) > 1:
                for key in matches:
                    self.active[key]["ambiguous"] = True
            if len(matches) == 1:
                record["observed_test_seconds"] = max(0, now - self.active.pop(matches[0])["started"])
            # Concurrent identical display names cannot be paired without an event ID.
            self.counts["completed" if action in ("passed", "failed") else action] += 1
            if action == "failed":
                self.counts["failed"] += 1
        self.events.write(json.dumps(record, sort_keys=True, allow_nan=False) + "\n")
        self.events.flush()
        legacy.progress(json.dumps({"observed_test_event": record}, sort_keys=True))
        self.publish("running")

    def publish(self, state, force=False, exit_code=None):
        now = self.clock()
        value = {"schema": SCHEMA, "kind": "observed-test-progress-v1", **self.context,
                 "state": state, "exit_code": exit_code, "elapsed_seconds": max(0, now - self.started),
                 "observed_counts": dict(self.counts),
                 "observed_active": [{"sequence": key, "name": item["name"],
                                      "age_seconds": max(0, now - item["started"]),
                                      "ambiguous": item.get("ambiguous", False)}
                                     for key, item in self.active.items()],
                 "partial_line": bool(self.pending) or self.discard_line or self.partial,
                 "stream_eof": self.eof, "transport_error": self.error,
                 "authority": "observations only; not XML, completed inventory or a pass receipt"}
        self.raw.flush()
        self.events.flush()
        os.fsync(self.raw.fileno())
        os.fsync(self.events.fileno())
        durable_json(self.attempt / "test-progress.json", value)
        if force or now - self.last_heartbeat >= PROGRESS_HEARTBEAT_SECONDS:
            self.last_heartbeat = now
            legacy.progress(json.dumps({"test_progress_heartbeat": value}, sort_keys=True))
            summary = os.environ.get("GITHUB_STEP_SUMMARY")
            if summary:
                names = "; ".join(item["name"] + " (" + str(round(item["age_seconds"], 1)) + "s observed age)"
                                  for item in value["observed_active"][:5]) or "none observed"
                with open(summary, "a", encoding="utf-8") as output:
                    output.write("\n- " + self.context["mode"] + " shard `" + self.context["shard"] + "`: " + state
                                 + "; " + str(round(value["elapsed_seconds"], 1)) + "s elapsed; validated shards "
                                 + str(value.get("validated_shards_completed", "unknown")) + "/"
                                 + str(value.get("shards_total", "unknown")) + "; observed test events "
                                 + str(self.counts) + "; selected method IDs " + str(value["selected_method_count"])
                                 + "; active: " + names.replace("\n", " ") + ". Observations are not PASS.\n")
                    output.flush()
        return value

    def drain(self):
        try:
            while not self.halt.is_set():
                ready, _, _ = select.select([self.master], [], [], 0.1)
                if ready:
                    try:
                        block = os.read(self.master, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        block = b""  # POSIX PTYs may report EOF as EIO.
                    if not block:
                        self.eof = True
                        return
                    self.feed(block)
                if self.clock() - self.last_heartbeat >= PROGRESS_HEARTBEAT_SECONDS:
                    self.publish("running", force=True)
                if self.finishing.is_set() and time.monotonic() >= self.drain_deadline:
                    self.error = "output drain deadline"
                    return
        except Exception as error:
            self.error = type(error).__name__

    def finish(self, state, exit_code=None):
        self.drain_deadline = time.monotonic() + 2
        self.finishing.set()
        if self.reader:
            self.reader.join(timeout=3)
            if self.reader.is_alive():
                self.error = "output reader did not stop"
                self.halt.set()
                self.reader.join(timeout=1)
        self.publish(state, force=True, exit_code=exit_code)
        return self.error is None and self.eof

    def __exit__(self, kind, value, traceback):
        self.halt.set()
        try:
            if self.reader and self.reader.is_alive():
                self.reader.join(timeout=1)
            if self.events:
                self.events.close()
        finally:
            for name in ("master", "slave"):
                descriptor = getattr(self, name)
                if descriptor is not None:
                    os.close(descriptor)
                    setattr(self, name, None)


def execute_process(command, workspace, attempt, timeout, descriptors, environment, observer=None,
                    isolate_environment=True, progress=None):
    """Terminate only this owned process session on timeout, never report timeout as success."""
    actual_environment = child_environment(attempt, environment) if isolate_environment else dict(environment)
    descriptor = os.open(attempt / "test.log", os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "wb") as log, ExitStack() as stack:
        capture = stack.enter_context(ObservedTestProgress(attempt, log, progress)) if progress is not None else None
        try:
            process = subprocess.Popen(command, cwd=workspace, env=actual_environment, stdout=capture.slave if capture else log,
                                       stderr=subprocess.STDOUT, pass_fds=tuple(descriptors),
                                       start_new_session=True, umask=0o077)
        except OSError as error:
            durable_json(attempt / "launch-failure.json", {"schema": SCHEMA, "status": "not-launched",
                                                           "error": type(error).__name__})
            if capture:
                capture.finish("not-launched")
            raise
        try:
            durable_json(attempt / "child.json", {"pid": process.pid,
                                                 "command": command, "started": time.time()})
            if capture:
                capture.start()
            if observer:
                observer.start(process.pid)
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                durable_json(attempt / "timeout.json", {"schema": SCHEMA, "seconds": timeout, "reason": "process wait deadline"})
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
            if capture:
                capture.finish("interrupted", process.returncode)
            raise
        if capture and not capture.finish("exited" if code == 0 else "timed-out" if code == 124 else "failed", code):
            code = code or 125
        durable_json(attempt / "child-exit.json", {"pid": process.pid, "exit_code": code})
        if code == 0 and isolate_environment:
            # Temp is outside the sealed proof. Failed/interrupted work retains it for recovery.
            shutil.rmtree(actual_environment["TMPDIR"])
        return code


def worker_limit(explicit, cpu_budget, ram_available, ram_reserve, peak_per_worker,
                 disk_available, disk_reserve, disk_per_worker, ram_capacity=None, disk_capacity=None):
    if type(explicit) is not int or explicit not in (1, 2):
        raise ValueError("Reviewed initial worker cap is one or two")
    for value in (cpu_budget, ram_available, ram_reserve, peak_per_worker,
                  disk_available, disk_reserve, disk_per_worker):
        positive(value)
    for capacity in (ram_capacity, disk_capacity):
        if capacity is not None:
            positive(capacity)
    result = min(explicit, int(cpu_budget),
                 int((ram_available - ram_reserve) // peak_per_worker),
                 int((disk_available - disk_reserve) // disk_per_worker))
    if result < 1:
        raise ValueError("RAM/disk admission reserve blocks a new worker")
    return result


def admission_refusal(bounds, configured_cpu, observed_cpu, stage, error):
    """Describe only measured numbers and fixed refusal codes, without sampling or error text."""
    stage = stage if type(stage) is str and stage in ("configuration", "cpu", "ram", "bounds", "disk", "decision") else "unknown"
    def number(value):
        return value if type(value) is int or (type(value) is float and math.isfinite(value)) else None

    sample = {name: number(bounds.get(name)) for name in (
        "explicit", "cpu_budget", "ram_available", "ram_reserve", "peak_per_worker", "ram_capacity",
        "disk_available", "disk_reserve", "disk_per_worker", "disk_capacity")}
    sample.update(cpu_observed=number(observed_cpu), cpu_budget_configured=number(configured_cpu), cpu_required=1)
    for prefix, per_worker in (("ram", "peak_per_worker"), ("disk", "disk_per_worker")):
        reserve, peak = sample[prefix + "_reserve"], sample[per_worker]
        sample[prefix + "_required"] = number(reserve + peak) if reserve is not None and peak is not None else None
    reasons = []
    if stage == "decision":
        if sample["cpu_budget"] is not None and sample["cpu_budget"] < 1:
            reasons.append("cpu")
        for prefix in ("ram", "disk"):
            available, required = sample[prefix + "_available"], sample[prefix + "_required"]
            if available is not None and required is not None and available < required:
                reasons.append(prefix)
    if not reasons:
        reasons.append("invalid-bound" if stage == "decision" else "sample-" + stage)
    category = next((label for kind, label in ((ValueError, "ValueError"), (OSError, "OSError"),
                    (KeyError, "KeyError"), (TypeError, "TypeError"), (subprocess.SubprocessError, "SubprocessError"))
                    if isinstance(error, kind)), "unknown")
    return {"schema": SCHEMA, "status": "refused", "stage": stage, "reasons": reasons,
            "category": category, "sample": sample}


def reservation_update(store, reservation, **changes):
    with claim(store.root / "claims", "admission", wait_seconds=30):
        current = load_json(reservation["path"])
        if current["nonce"] != reservation["nonce"]:
            raise ValueError("Reservation generation changed")
        if current["state"] == "released":
            return
        current.update(changes)
        durable_json(reservation["path"], current)


@contextmanager
def reserve_worker(store, executor, runtime, admission, timeout):
    chosen, reservation = None, None
    with ExitStack() as held:
        with claim(store.root / "claims", "admission", wait_seconds=timeout):
            if hasattr(executor, "observe_admission"):
                admission = executor.observe_admission()
            worker_limit(**admission)
            static = {name: value for name, value in admission.items()
                      if name not in ("ram_available", "disk_available")}
            policy = {"schema": SCHEMA, "host": runtime["host"], "bounds": static}
            policy_path = store.root / "admission.json"
            if policy_path.exists() and load_json(policy_path) != policy:
                raise ValueError("Host worker admission policy changed")
            if not policy_path.exists():
                durable_json(policy_path, policy)
            # Namespace depends on reviewed capacity, never the current remaining free capacity.
            cap = worker_limit(**{**admission, "ram_available": admission["ram_capacity"],
                                   "disk_available": admission["disk_capacity"]})
            active, candidates = 0, []
            legacy.owned_directory(store.root / "reservations")
            for slot in range(cap):
                context = claim(store.root / "claims", "worker:" + str(slot))
                try:
                    lock = context.__enter__()
                except BlockingIOError:
                    active += 1
                    continue
                path = store.root / "reservations" / (str(slot) + ".json")
                prior = load_json(path) if path.exists() else None
                if prior and prior["state"] != "released" and not executor.reclaimable(prior):
                    active += 1
                    context.__exit__(None, None, None)
                else:
                    candidates.append((context, lock, path))
            try:
                # Charge full running headroom if no trustworthy actual-use binding exists.
                # This deliberately double-charges current use and may admit fewer workers.
                if (not candidates or admission["ram_available"] - admission["ram_reserve"]
                        < (active + 1) * admission["peak_per_worker"]
                        or admission["disk_available"] - admission["disk_reserve"]
                        < (active + 1) * admission["disk_per_worker"]):
                    raise ValueError("Occupied slots or conservative RAM/disk headroom blocks admission")
                chosen, lock, path = candidates.pop(0)
                held.callback(chosen.__exit__, None, None, None)
                record = {"schema": SCHEMA, "nonce": str(uuid.uuid4()), "state": "pending",
                          "owner": executor.owner_identity(), "attempt": None}
                durable_json(path, record)
                reservation = {"path": path, "nonce": record["nonce"], "lock": lock}
            finally:
                for context, lock, path in candidates:
                    context.__exit__(None, None, None)
        try:
            yield reservation
        finally:
            current = load_json(reservation["path"])
            safe = current["state"] == "pending" or (current["attempt"] is not None
                                                      and executor.proven_exited(Path(current["attempt"])))
            reservation_update(store, reservation, state="released" if safe else "unknown")



def proved_timeout(attempt, identity, bound=None):
    """A failed artifact may preserve a stop condition, never a successful outcome."""
    physical_tree(attempt)
    required = ("start.json", "failure.json", "timeout.json", "child.json", "child-exit.json")
    if any(not (attempt / name).is_file() for name in required):
        return False
    start, failure, timeout, child, terminal = (load_json(attempt / name) for name in required)
    seconds = start.get("timeout_seconds")
    return (start.get("identity") == identity and type(seconds) in (int, float) and math.isfinite(seconds) and seconds > 0
            and (bound is None or seconds == bound) and type(failure.get("exit_code")) is int
            and failure == {"status": "failed", "exit_code": 124}
            and timeout == {"schema": SCHEMA, "seconds": seconds, "reason": "process wait deadline"}
            and type(child.get("pid")) is int and child["pid"] > 0
            and type(terminal.get("exit_code")) is int and terminal == {"pid": child["pid"], "exit_code": 124})

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
        parent = store.root / "attempts" / shard_id
        if len(shard["atoms"]) == 1:
            candidates = list(parent.glob("*")) if parent.exists() else []
            candidates += list((store.root / "timeout-blockers" / shard_id).glob("*"))
            for attempt in candidates:
                if attempt.is_dir() and proved_timeout(attempt, identity, timeout):
                    cohorts = sorted({".".join(legacy.group_key(method)) for method in shard["methods"]})
                    raise ValueError("Indivisible cohort hit its hard runtime bound; no automatic replay: "
                                     + ", ".join(cohorts) + ". Review shared-state/test decomposition or the execution bound; retained "
                                     + str(attempt))
        reservation = stack.enter_context(reserve_worker(store, executor, plan["runtime"], admission, timeout))
        locks.append(reservation["lock"])
        parent = store.root / "attempts" / shard_id
        legacy.owned_directory(parent)
        for prior in parent.iterdir():
            if prior.name.startswith(".restore-"):
                continue
            if prior.is_dir() and not (prior / "result.json").exists():
                if not executor.proven_exited(prior):
                    raise ValueError("Incomplete attempt still has an unproven owner")
        attempt = parent / str(uuid.uuid4())
        legacy.owned_directory(attempt)
        durable_json(attempt / "start.json", {"identity": identity, "tested_head": current_head, "timeout_seconds": timeout,
                                             "owner": executor.owner_identity(),
                                             "paths": {"proof": str(attempt), "temporary": str(
                                                 store.root / "temporary" / attempt.name)}})
        if hasattr(executor, "authority"):
            durable_json(attempt / "authorization.json", executor.authority.authorization())
        reservation_update(store, reservation, attempt=str(attempt))
        fault("before-execution")
        started = time.monotonic()
        reservation_update(store, reservation, state="launching")
        executor.reservation_callback = lambda: reservation_update(store, reservation, state="running")
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
    durable_json(destination / "commit.json", {"sha256": checksum})
    seal(destination)
    return checksum


def validate_phase(bundle, trusted_digest, phase, runtime, inventory):
    bundle = Path(bundle)
    physical_tree(bundle)
    if (legacy.digest(bundle / "index.json") != trusted_digest
            or {item.name for item in bundle.iterdir()} != {"index.json", "attempt", "commit.json"}
            or load_json(bundle / "commit.json") != {"sha256": trusted_digest}):
        raise ValueError("Phase index differs from trusted host capture")
    manifest = load_json(bundle / "index.json")
    require_fields(manifest, ("schema", "host", "identity", "origin", "receipt_sha256"))
    identity = manifest["identity"]
    origin = manifest["origin"]
    require_fields(origin, ("schema", "host", "phase", "tested_head", "receipt_sha256", "exit_code", "authorization"))
    if "ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256" in runtime["environment"]:
        validate_authorization(origin["authorization"], runtime)
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
    require_sealed(Path(normal_bundle))
    require_sealed(Path(leaks_bundle))
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
                                   text=True, timeout=900 if command[:2] == ["git", "clone"] else 60,
                                   umask=0o077).strip()


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
        if (self.environment.get("GITHUB_JOB") not in native_runner.RECOVERABLE_JOBS
                or self.environment.get("ELITE_RECOVERABLE_CODE_ENABLED") != "true"):
            raise ValueError("HELD: the owned exact-job authorization hook is required")
        self.read = read
        policy_path = Path(policy_path)
        if not policy_path.is_absolute() or policy_path != policy_path.resolve():
            raise ValueError("Host policy path must be absolute and physical")
        legacy.owned_directory(policy_path.parent)
        info = policy_path.lstat()
        if policy_path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Native activation policy must be host-owned")
        self.policy = load_json(policy_path)
        if self.environment.get("GITHUB_JOB") in native_runner.RECOVERABLE_JOBS and (
                self.environment.get("ELITE_NATIVE_POLICY") != str(policy_path)
                or self.environment.get("ELITE_NATIVE_APPROVED_HEAD") != self.policy["approved_head"]):
            raise ValueError("CLI policy/source differs from the owned native approval")
        if "recoverable_activation" in self.policy:
            native_runner.require_owned_activation_file(policy_path)
        self.root = native_runner.validate(self.policy, self.environment)
        native_runner.require_recoverable_checkout(self.policy, self.environment, self.root)
        if policy_path.is_relative_to(self.root):
            raise ValueError("Repository content cannot authorize native execution")
        self.config = self.policy["recoverable_shards"]
        required = {"schema", "host", "cache", "legacy_cache", "workers", "admission"}
        if not required <= set(self.config) or set(self.config) - required - {"planning"}:
            raise ValueError("Unexpected native activation fields")
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
        return self.read(command, self.root if workspace is None else workspace,
                         self.execution_environment() if environment is None else environment, descriptors)

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
        configured_cpu, cpus, stage = bounds.get("cpu_budget"), None, "configuration"
        observed = {}
        try:
            require_fields(bounds, ("explicit", "cpu_budget", "ram_reserve", "peak_per_worker",
                                    "disk_reserve", "disk_per_worker", "ram_capacity", "disk_capacity"))
            stage = "cpu"
            cpus = int(self.output(["sysctl", "-n", "hw.logicalcpu"]))
            stage = "ram"
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
            stage = "bounds"
            observed["cpu_budget"] = min(positive(bounds["cpu_budget"]), cpus)
            stage = "ram"
            observed["ram_available"] = sum(pages) * int(size[1])
            stage = "disk"
            observed["disk_available"] = shutil.disk_usage(self.cache).free
            bounds.update(observed)
            stage = "decision"
            worker_limit(**bounds)
        except (KeyError, OSError, TypeError, ValueError, subprocess.SubprocessError) as error:
            sample = {**bounds, **{name: observed.get(name) for name in ("cpu_budget", "ram_available", "disk_available")}}
            record = admission_refusal(sample, configured_cpu, cpus, stage, error)
            retained = False
            try:
                report = self.cache / "preparation" / str(uuid.uuid4())
                legacy.owned_directory(report)
                durable_json(report / "resource-admission.json", record)
                mode = self.environment.get("ELITE_RECOVERABLE_REQUEST_MODE")
                durable_json(report / "launch.json", {"head": self.policy["approved_head"],
                    "mode": mode if mode in MODES else None,
                    "stage": "admission", "status": "not-launched", "authorization": self.authorization()})
                retained = True
            except (KeyError, OSError, TypeError, ValueError):
                pass  # Retention failure cannot replace the original admission refusal.
            try:
                message = json.dumps({"resource_admission": record, "raw_attempt_retained": retained}, sort_keys=True)
                legacy.progress(message)
                if self.environment.get("GITHUB_STEP_SUMMARY"):
                    with Path(self.environment["GITHUB_STEP_SUMMARY"]).open("a") as summary:
                        summary.write("## Resource admission refused\n\n```json\n" + message + "\n```\n")
            except (OSError, ValueError):
                pass  # A disconnected report must not change the refusal or trigger another sample.
            raise
        return bounds

    def environment_for(self, mode):
        value = self.execution_environment()
        if mode == "address":
            value["ASAN_OPTIONS"] = "detect_leaks=0"
        return value

    def execution_environment(self):
        value = runtime_child_environment(self.environment)
        # These exact authorization controls never enter the native process. Unknown ELITE_ keys remain bound.
        for name in AUTHORIZATION_CONTROLS:
            value.pop(name, None)
        value["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"] = execution_policy_digest(self.config)
        return value

    def authorization(self):
        return {"schema": SCHEMA, "kind": "validated-control-plane-v1", "head": self.policy["approved_head"],
                "host": self.config["host"], "role": self.environment.get("GITHUB_JOB", ""),
                "run_id": self.environment.get("GITHUB_RUN_ID", ""),
                "run_attempt": self.environment.get("GITHUB_RUN_ATTEMPT", ""),
                "mode": self.environment.get("ELITE_RECOVERABLE_REQUEST_MODE", ""),
                "shard": self.environment.get("ELITE_RECOVERABLE_REQUEST_SHARD", ""),
                "worker": self.environment.get("ELITE_RECOVERABLE_REQUEST_WORKER", ""),
                "phase": self.environment.get("ELITE_RECOVERABLE_REQUEST_PHASE", ""),
                "workflow_sha256": self.policy.get("recoverable_activation", {}).get("workflow_sha256"),
                "plan_sha256": self.environment.get("PLAN_DIGEST"),
                "instance": self.environment.get("RUNNER_NAME", ""), "workspace": str(self.root),
                "policy_sha256": native_runner.policy_digest(self.policy),
                "execution_policy_sha256": execution_policy_digest(self.config),
                "controls": {name: hashlib.sha256(self.environment[name].encode()).hexdigest()
                             if name in self.environment else None for name in AUTHORIZATION_CONTROLS}}

    def verify_request(self, mode=None, shard=None, worker=None, phase=None):
        if self.environment.get("GITHUB_JOB") in native_runner.RECOVERABLE_JOBS:
            for name, value in (("MODE", mode), ("SHARD", shard), ("WORKER", worker), ("PHASE", phase)):
                if value is not None and self.environment.get("ELITE_RECOVERABLE_REQUEST_" + name, "") != value:
                    raise ValueError("CLI request differs from host-owned job assignment")

    def runtime(self, workspace, mode, image, flags, inputs=None):
        environment = self.environment_for(mode)
        swift = shutil.which("swift", path=environment.get("PATH"))
        if not swift:
            raise ValueError("Approved Swift compiler is unavailable")
        uuids = image_uuids(image)
        if not uuids["uuids"]:
            raise ValueError("Actual test image UUID is unavailable")
        return {"schema": SCHEMA, "mode": mode,
                "inputs": legacy.executable_inputs(workspace, flags[1]) if inputs is None else inputs,
                "toolchain": self.output([swift, "--version"], workspace, environment),
                "sdk": fingerprint({"version": self.output(["xcrun", "--show-sdk-version"]),
                                    "path": self.output(["xcrun", "--show-sdk-path"])}),
                "host": self.host(), "os": fingerprint({"release": os.uname().release,
                                                         "version": os.uname().version}),
                "architecture": platform.machine(), "image_sha256": legacy.digest(image),
                "image_uuid": fingerprint(uuids["uuids"]),
                "environment": legacy.runtime_identity(environment), "flags": flags,
                "phase_environment": legacy.runtime_identity(self.execution_environment()),
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


def build_entries(root):
    """Hash complete SwiftPM layout, including confined relative links and executable bits."""
    legacy.owned_directory(root)
    entries = {}
    for directory, names, files in os.walk(root, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            info = path.lstat()
            if info.st_uid != os.getuid() or (not path.is_symlink() and info.st_mode & 0o022):
                raise ValueError("Frozen build ownership changed")
            key = path.relative_to(root).as_posix()
            if path.is_symlink():
                if Path(os.readlink(path)).is_absolute() or not path.resolve().is_relative_to(root.resolve()):
                    raise ValueError("Frozen build link escaped")
                entries[key] = {"link": os.readlink(path)}
            elif path.is_file():
                entries[key] = {"sha256": legacy.digest(path), "executable": bool(info.st_mode & 0o111)}
            elif path.is_dir():
                entries[key] = {"directory": True}
            else:
                raise ValueError("Unsupported frozen build node")
    return entries


def writable_private_tree(root):
    for directory, names, files in os.walk(root, followlinks=False):
        Path(directory).chmod(0o700)
        for name in files:
            path = Path(directory) / name
            if not path.is_symlink():
                path.chmod(0o700 if path.stat().st_mode & 0o111 else 0o600)


class NativeBuilder:
    def __init__(self, authority):
        self.authority, self.lock = authority, None

    def image_relative(self, image):
        return str(Path(image).resolve().relative_to(self.authority.root))

    def freeze_scratch(self, runtime, destination):
        source = self.authority.root / runtime["flags"][1]
        entries = build_entries(source)
        size = sum((source / name).stat().st_size for name, entry in entries.items() if "sha256" in entry)
        budget = self.authority.admission()
        if budget["disk_available"] - budget["disk_reserve"] < size:
            raise ValueError("Disk reserve blocks durable build capture")
        copy_build_tree(source, destination / "scratch")
        if build_entries(destination / "scratch") != entries:
            raise ValueError("Durable scratch copy changed")
        return entries

    def validate_frozen(self, build, destination, immutable=True):
        validate_runtime(build["runtime"])
        if immutable:
            require_sealed(destination)
        if load_json(destination / "build-commit.json") != {"sha256": legacy.digest(destination / "build.json")}:
            raise ValueError("Frozen build manifest was not committed or changed")
        if build_entries(destination / "scratch") != build["scratch"]:
            raise ValueError("Durable scratch is missing or tampered")
        runtime, flags = build["runtime"], build["runtime"]["flags"]
        current = legacy.executable_inputs(self.authority.root, flags[1])
        if ({name: digest for name, digest in current.items() if not name.startswith(".build/")}
                != {name: digest for name, digest in runtime["inputs"].items() if not name.startswith(".build/")}):
            raise ValueError("Controller source changed since durable build")
        scratch = Path(flags[1])
        for name, digest in runtime["inputs"].items():
            if name.startswith(".build/"):
                if legacy.digest(destination / "scratch" / Path(name).relative_to(scratch)) != digest:
                    raise ValueError("Durable dependency inputs changed")
        relative = Path(build["image_relative"])
        if relative.is_absolute() or ".." in relative.parts or not relative.is_relative_to(scratch):
            raise ValueError("Frozen image path escaped scratch")
        image = destination / "scratch" / relative.relative_to(scratch)
        if self.authority.runtime(self.authority.root, runtime["mode"], image, flags,
                                  inputs=runtime["inputs"]) != runtime:
            raise ValueError("Durable image/toolchain/host/environment changed")

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

    def build_only(self, mode, timeout):
        """A separate GitHub step records an owned build checkpoint before discovery."""
        if timeout > SHARD_MAX_SECONDS:
            raise ValueError("Preparation exceeds the reviewed two-hour bound")
        destination = self.authority.cache / "build-stage" / self.authority.policy["approved_head"] / mode
        with self.preparation_claim():
            if destination.exists():
                ready = load_json(destination / "ready.json")
                image = self.authority.root / ready["image_relative"]
                if (ready["head"] != self.authority.policy["approved_head"] or ready["runtime"] != self.authority.runtime(
                        self.authority.root, mode, image, ready["runtime"]["flags"])):
                    raise ValueError("Prepared controller build changed before discovery")
                return {"reused": True, "stage": str(destination)}
            root, env = self.authority.root, self.authority.environment_for(mode)
            swift = shutil.which("swift", path=env.get("PATH"))
            if swift is None:
                raise ValueError("Approved Swift compiler is unavailable")
            flags = ["--scratch-path", ".build/tsan" if mode == "thread" else ".build/asan", "--sanitize=" + mode]
            report = self.authority.cache / "preparation" / str(uuid.uuid4())
            legacy.owned_directory(report)
            inputs = legacy.executable_inputs(root, flags[1])
            command = [swift, "build", "--build-tests", *flags]
            durable_json(report / "launch.json", {"head": self.authority.policy["approved_head"], "mode": mode,
                                                  "command": command, "authorization": self.authority.authorization()})
            code = execute_process(command, root, report, timeout, [self.lock.fileno()], env,
                                   NativeMonitor(self.authority, report, root), isolate_environment=False)
            if code != 0:
                raise ValueError("Mode build failed or timed out; raw attempt retained: " + str(report))
            bins = Path(self.authority.output([swift, "build", *flags, "--show-bin-path"]))
            images = [image for image in sorted(bins.glob("*.xctest/Contents/MacOS/*")) if image.is_file()]
            if len(images) != 1:
                raise ValueError("Expected one actual prepared image")
            runtime = self.authority.runtime(root, mode, images[0], flags)
            if any(runtime["inputs"].get(name) != value for name, value in inputs.items()):
                raise ValueError("Mode build changed executable inputs")
            legacy.owned_directory(destination)
            durable_json(destination / "ready.json", {"head": self.authority.policy["approved_head"], "runtime": runtime,
                                                     "image_relative": self.image_relative(images[0]), "attempt": str(report)})
            seal(destination)
            return {"reused": False, "stage": str(destination)}

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
        durable_json(report / "launch.json", {"head": self.authority.policy["approved_head"], "mode": mode,
                                              "stage": "discovery", "authorization": self.authority.authorization()})
        before = legacy.executable_inputs(root, flags[1])
        ready = self.authority.cache / "build-stage" / self.authority.policy["approved_head"] / mode / "ready.json"
        if ready.exists():
            checkpoint = load_json(ready)
            require_sealed(ready.parent)
            image = root / checkpoint["image_relative"]
            if (checkpoint["head"] != self.authority.policy["approved_head"]
                    or checkpoint["runtime"] != self.authority.runtime(root, mode, image, flags)):
                raise ValueError("Build/discovery checkpoint runtime changed")
            # Discovery cannot compile; the completed build step owns that execution.
            code = execute_process([swift, "test", *flags, "list", "--skip-build"], root, report, 300,
                                   [self.lock.fileno()], env, NativeMonitor(self.authority, report, root),
                                   isolate_environment=False)
            if code != 0:
                raise ValueError("Discovery failed or exceeded five minutes; raw attempt retained")
            listing = (report / "test.log").read_text()
            (report / "discovery.log").write_text(listing + "\n")
            methods = legacy.inventory(listing)
        else:
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
            if not destination.exists() and destination.parent.exists():
                for stage in sorted(destination.parent.glob(destination.name + ".pending-*")):
                    try:
                        candidate = load_json(stage / "build.json")
                        self.validate_frozen(candidate, stage, immutable=False)
                        if candidate["runtime"]["mode"] != mode or candidate["tested_head"] != self.authority.policy["approved_head"]:
                            raise ValueError("Orphaned build is for another mode/head")
                        seal(stage)
                        stage.rename(destination)
                        sync_directory(destination.parent)
                        break
                    except (OSError, ValueError, KeyError):
                        continue
            if destination.exists():
                build = load_json(destination / "build.json")
                self.validate_frozen(build, destination)
                if build["tested_head"] != self.authority.policy["approved_head"] or build["runtime"]["mode"] != mode:
                    raise ValueError("Frozen build differs from current preparation")
            else:
                if any((base / (mode + "-build.json")).exists() for base in self.authority.workers.values()):
                    raise ValueError("Known durable mode bundle is missing; verified restoration is required")
                legacy.owned_directory(destination.parent)
                pending = destination.with_name(destination.name + ".pending-" + str(uuid.uuid4()))
                build = _freeze_build(mode, self, pending)
                self.validate_frozen(build, pending)
                pending.rename(destination)
                sync_directory(destination.parent)
            for base in self.authority.workers.values():
                with claim(self.authority.cache / "claims", "workspace:" + str(base)):
                    self.prepare_worker(build, base, destination)
            return build

    def prepare_worker(self, build, base, bundle):
        mode = build["runtime"]["mode"]
        workspace, marker = base / mode, base / (mode + "-build.json")
        if marker.exists():
            if load_json(marker) != build:
                raise ValueError("Worker contains another build; reserve a new workspace")
            if workspace.exists():
                image = workspace / build["image_relative"]
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
        budget = self.authority.admission()
        size = sum((bundle / "scratch" / name).stat().st_size for name, entry in build["scratch"].items()
                   if "sha256" in entry)
        if budget["disk_available"] - budget["disk_reserve"] < size:
            raise ValueError("Disk reserve blocks private scratch restoration")
        copy_build_tree(bundle / "scratch", workspace / scratch)
        writable_private_tree(workspace / scratch)
        image = workspace / build["image_relative"]
        if self.authority.runtime(workspace, mode, image, build["runtime"]["flags"]) != build["runtime"]:
            raise ValueError("Copied private image/source/runtime differs from frozen build")
        durable_json(marker, build)
        marker.chmod(0o400)


class NativeMonitor:
    """Persist verified descendants; reuse capture-quality cleanup's fresh identity checks."""
    def __init__(self, authority, attempt, workspace, expected_runtime=None, expected_image=None):
        self.authority, self.attempt, self.workspace = authority, attempt, workspace
        self.known, self.errors = {}, []
        self.controller, self.root_identity = None, None
        self.expected_runtime, self.expected_image = expected_runtime, expected_image
        self.observed = {}
        self.bound_callback = None
        self.stop, self.thread = threading.Event(), None

    def observe(self):
        rows = self.authority.snapshot()
        live = descendants(self.known, rows)
        self.known.update(live)
        for row in live.values():
            argv = arguments(row)
            if "swiftpm-testing-helper" not in row["command"]:
                continue
            try:
                if not argv or Path(argv[0]).name != "swiftpm-testing-helper" or "--test-bundle-path" not in argv:
                    raise ValueError("Unrecognized native helper invocation")
                image = Path(argv[argv.index("--test-bundle-path") + 1])
                if not image.is_absolute() or image != image.resolve():
                    raise ValueError("Observed helper image is not a canonical physical path")
                confined(image, self.workspace / ".build")
                if self.expected_image is not None and image != self.expected_image:
                    raise ValueError("Helper executed a different private image")
                if str(image) not in self.observed:
                    uuids = image_uuids(image)["uuids"]
                    if not uuids:
                        raise ValueError("Observed helper image UUID missing")
                    observed = {"sha256": legacy.digest(image), "uuid": fingerprint(uuids)}
                    if self.expected_runtime is not None and observed != {
                            "sha256": self.expected_runtime["image_sha256"],
                            "uuid": self.expected_runtime["image_uuid"]}:
                        raise ValueError("Observed helper image hash or UUID differs")
                    self.observed[str(image)] = observed
                    if self.bound_callback is not None:
                        self.bound_callback()
                        self.bound_callback = None
            except (OSError, ValueError, IndexError):
                self.errors.append("helper image binding failed")
        durable_json(self.attempt / "processes.json", {"schema": SCHEMA, "workspace": str(self.workspace),
                                                      "controller": self.controller,
                                                      "root": self.root_identity,
                                                      "running": not self.stop.is_set(),
                                                      "observed_images": self.observed,
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
        clean = not live and not self.errors and (self.expected_runtime is None or bool(self.observed))
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

    def observe_admission(self):
        return self.authority.admission()

    def reclaimable(self, reservation):
        rows = self.authority.snapshot()
        if same_process(reservation["owner"], rows.get(reservation["owner"]["pid"])):
            return False
        return (not self.unknown_live_helpers() and (reservation["attempt"] is None
                or self.proven_exited(Path(reservation["attempt"]))))

    def verify(self, runtime):
        mode = runtime["mode"]
        build = load_json(self.workspace / (mode + "-build.json"))
        workspace = self.workspace / mode
        relative = Path(build["image_relative"])
        if relative.is_absolute() or ".." in relative.parts or relative.parts[:1] != (".build",):
            raise ValueError("Private test image escaped its prepared scratch")
        image = workspace / relative
        if image != image.resolve() or image.is_symlink():
            raise ValueError("Private test image is not canonical and physical")
        actual = self.authority.runtime(workspace, mode, image, runtime["flags"])
        if (actual != runtime or build["runtime"] != runtime
                or {name: digest for name, digest in legacy.executable_inputs(
                    self.authority.root, runtime["flags"][1]).items() if not name.startswith(".build/")}
                != {name: digest for name, digest in runtime["inputs"].items() if not name.startswith(".build/")}
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
        return any(("swiftpm-testing-helper" in row["command"] or ".xctest/Contents/MacOS/Elite" in row["command"]
                   or (arguments(row) and Path(arguments(row)[0]).name in ("swift", "swift-test")
                       and "test" in arguments(row)))
                   and pid not in owned for pid, row in rows.items())

    def owner_identity(self):
        row = self.authority.snapshot().get(os.getpid())
        if row is None:
            raise ValueError("Controller has no verified process identity")
        return {"pid": os.getpid(), **row, "image_sha256": legacy.digest(Path(sys.executable))}

    def proven_exited(self, attempt):
        start = load_json(attempt / "start.json")
        rows = self.authority.snapshot()
        if self.unknown_live_helpers():
            return False
        path = attempt / "processes.json"
        known = {int(pid): row for pid, row in load_json(path)["processes"].items()} if path.exists() else {}
        if descendants(known, rows):
            return False
        if (attempt / "launch-failure.json").exists() and not (attempt / "child.json").exists():
            record = load_json(attempt / "launch-failure.json")
            return (record["schema"] == SCHEMA and record["status"] == "not-launched"
                    and not self.unknown_live_helpers())
        if (attempt / "child-exit.json").exists():
            terminal, child = load_json(attempt / "child-exit.json"), load_json(attempt / "child.json")
            if (type(terminal["exit_code"]) is not int or terminal["pid"] != child["pid"]
                    or (path.exists() and load_json(path)["running"] is not False
                        and same_process(start["owner"], rows.get(start["owner"]["pid"])))):
                return False
            return True
        return not same_process(start["owner"], rows.get(start["owner"]["pid"]))

    def execute(self, shard, attempt, timeout, descriptors):
        swift = shutil.which("swift", path=self.authority.environment_for(self.runtime["mode"]).get("PATH"))
        command = legacy.batch_command(swift, self.runtime["flags"], self.runtime["mode"],
                                       attempt, shard["methods"])
        build = load_json(self.workspace / (self.runtime["mode"] + "-build.json"))
        image = self.active_workspace / build["image_relative"]
        monitor = NativeMonitor(self.authority, attempt, self.active_workspace, self.runtime, image)
        monitor.bound_callback = getattr(self, "reservation_callback", None)
        context = {"mode": self.runtime["mode"], "shard": shard["id"],
                   "selected_method_count": len(shard["methods"]), **getattr(self, "progress_context", {})}
        code = execute_process(command, self.active_workspace, attempt, timeout, descriptors,
                               self.authority.environment_for(self.runtime["mode"]), monitor, progress=context)
        if self.unknown_live_helpers() or not monitor.observed or monitor.errors:
            return code or 126
        return code


class NativePhaseRunner:
    """Capture host provenance before a fresh full phase, never relabel an imported legacy receipt."""
    def __init__(self, authority, executor):
        self.authority, self.executor = authority, executor
        self.origin, self.attempt = None, None
        self.reused = False

    def verify(self, runtime):
        self.executor.verify(runtime)

    def phase_origin(self, attempt, identity):
        if (attempt != self.attempt or self.origin is None
                or self.origin["phase"] != identity["phase"]
                or self.origin["receipt_sha256"] != legacy.digest(attempt / "result.json")):
            raise ValueError("No host-bound fresh phase execution origin")
        return self.origin

    def run(self, phase, plan, destination, timeout, fault=lambda stage: None):
        validate_plan(plan)
        with NativeBuilder(self.authority).preparation_claim() as lock:
            self.verify(plan["runtime"])
            runtime = plan["runtime"]
            durable = self.authority.cache / "full-phases" / phase_key(runtime, plan["inventory"], phase)
            legacy.owned_directory(durable.parent)
            def deliver():
                require_sealed(durable)
                checksum = load_json(durable / "commit.json")["sha256"]
                validate_phase(durable, checksum, phase, runtime, plan["inventory"])
                target = Path(destination)
                if target.exists():
                    validate_phase(target, checksum, phase, runtime, plan["inventory"])
                else:
                    atomic_copy(durable, target)
                return checksum
            if not durable.exists():
                for stage in sorted(durable.parent.glob(durable.name + ".pending-*")):
                    try:
                        checksum = load_json(stage / "commit.json")["sha256"]
                        validate_phase(stage, checksum, phase, runtime, plan["inventory"])
                        seal(stage)
                        stage.rename(durable)
                        sync_directory(durable.parent)
                        break
                    except (OSError, ValueError, KeyError):
                        continue
            if durable.exists():
                self.reused = True
                return deliver()
            policy_path = self.authority.environment.get("ELITE_NATIVE_POLICY")
            if phase == "normal" and policy_path and (Path(policy_path).parent / "m01-normal-attestation.json").exists():
                raise ValueError("New full normal execution requires separate authorization without the M01 attestation")
            execution = self.authority.cache / "phase-runs" / str(uuid.uuid4())
            legacy.owned_directory(execution)
            head, host = self.authority.policy["approved_head"], self.authority.host()
            durable_json(execution / "launch.json", {"host": host, "phase": phase, "head": head})
            fresh_cache = execution / "fresh-cache"
            command = [sys.executable, str(self.authority.root / "Tools/CI/quality_phase_checkpoints.py"),
                       phase, "--cache", str(fresh_cache)]
            monitor = NativeMonitor(self.authority, execution, self.authority.root)
            code = execute_process(command, self.authority.root, execution, timeout, [lock.fileno()],
                                   self.authority.execution_environment(), monitor,
                                   isolate_environment=False)
            if code or self.executor.unknown_live_helpers():
                raise ValueError("Full phase process/descendants failed")
            receipts = list(fresh_cache.glob("phases/*/*/result.json"))
            if len(receipts) != 1:
                raise ValueError("Expected exactly one fresh full phase outcome")
            self.attempt = receipts[0].parent
            result = load_json(receipts[0])
            if phase == "normal":
                parsed = {}
                for uuid_value, architecture in re.findall(r"UUID: ([0-9A-Fa-f-]{36}) \(([^)]+)\)",
                                                          result["identity"]["image_uuid"]):
                    if architecture in parsed:
                        raise ValueError("Duplicate full normal image UUID")
                    parsed[architecture] = uuid_value.upper()
                expected = {"sha256": result["identity"]["image_sha256"], "uuid": fingerprint(parsed)}
                if not parsed or expected not in monitor.observed.values() or monitor.errors:
                    raise ValueError("Full normal helper did not execute the recorded image")
            if result["tested_head"] != head or self.authority.host() != host:
                raise ValueError("Full phase did not execute on this approved host/head")
            self.origin = {"schema": SCHEMA, "host": host, "phase": phase,
                           "tested_head": head, "receipt_sha256": legacy.digest(receipts[0]), "exit_code": code,
                           "authorization": self.authority.authorization()}
            pending = durable.with_name(durable.name + ".pending-" + str(uuid.uuid4()))
            freeze_phase(self.attempt, result["identity"], runtime, plan["inventory"], self, pending)
            pending.rename(durable)
            sync_directory(durable.parent)
            fault("after-capture")
            return deliver()


def trusted_json(path, checksum):
    if not checksum or not re.fullmatch(r"[0-9a-f]{64}", checksum) or legacy.digest(path) != checksum:
        raise ValueError("A separately trusted manifest digest is required")
    if path.is_symlink() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o022:
        raise ValueError("Manifest must be physical, owned and not publicly writable")
    return load_json(path)


def owned_active_artifact_job(authority, run, expected_run, api):
    """Corroborate activity from this physical registration and exact attempt, never a name alone."""
    environment, policy = authority.environment, authority.policy
    root = Path(policy.get("runner_root", ""))
    name, attempt = environment.get("RUNNER_NAME"), environment.get("GITHUB_RUN_ATTEMPT", "")
    instance = policy.get("recoverable_activation", {}).get("runners", {}).get(name, {})
    if (not root.is_absolute() or root != root.resolve()
            or instance.get("workspace") != str(root / "_work/elite/elite")
            or not re.fullmatch(r"[1-9][0-9]*", attempt)):
        return False
    registration = root / ".runner"
    native_runner.require_owned_activation_file(registration)
    raw = registration.read_bytes()
    agent = json.loads(raw.decode("utf-8-sig"))
    if (not isinstance(agent, dict) or type(agent.get("agentId")) is not int or agent["agentId"] <= 0
            or agent.get("agentName") != name or agent.get("workFolder") != "_work"
            or agent.get("gitHubUrl") != "https://github.com/" + native_runner.REPOSITORY):
        return False
    # The existing callback bounds each request to 60s. Refuse a page arriving after this window.
    deadline, total, seen, active = time.monotonic() + 120, None, set(), []
    for page in range(1, 17):
        if time.monotonic() >= deadline:
            return False
        result = api(f"repos/{native_runner.REPOSITORY}/actions/runs/{expected_run}/attempts/{attempt}/jobs?per_page=100&page={page}")
        if time.monotonic() >= deadline or not isinstance(result, dict):
            return False
        count, jobs = result.get("total_count"), result.get("jobs")
        if (type(count) is not int or not 0 <= count <= 1600 or not isinstance(jobs, list)
                or (total is not None and count != total)):
            return False
        total = count
        if len(jobs) != min(100, total - len(seen)):
            return False
        for job in jobs:
            if not isinstance(job, dict) or type(job.get("id")) is not int or job["id"] <= 0 or job["id"] in seen:
                return False
            seen.add(job["id"])
            if type(job.get("runner_id")) is not int or job["runner_id"] != agent["agentId"]:
                continue
            if job.get("status") != "in_progress":
                continue
            if ("conclusion" not in job or job["conclusion"] is not None
                    or job.get("runner_name") != name or type(job.get("run_id")) is not int
                    or str(job["run_id"]) != expected_run or job.get("head_sha") != run["head_sha"]
                    or ("run_attempt" in job and str(job["run_attempt"]) != attempt)):
                return False
            active.append(job["id"])
        if len(seen) == total:
            native_runner.require_owned_activation_file(registration)
            return len(active) == 1 and registration.read_bytes() == raw
    return False


def artifact_run_active(authority, run, expected_run, api):
    """Keep the original running path; queued/waiting need fresh owned job corroboration."""
    if run.get("status") == "in_progress":
        return True
    if (run.get("status") not in ("queued", "waiting") or "conclusion" not in run
            or run["conclusion"] is not None or api is None):
        return False
    try:
        return owned_active_artifact_job(authority, run, expected_run, api)
    except (KeyError, OSError, TypeError, ValueError, subprocess.SubprocessError):
        return False


def require_artifact_run_provenance(authority, run, expected_run, api=None):
    """Retain each exact run guard separately so a safe owned line identifies refusal."""
    ref = authority.environment.get("GITHUB_REF", "")
    branch = ref.removeprefix("refs/heads/")
    workflow = native_runner.workflow_path(authority.environment)
    event = authority.environment.get("GITHUB_EVENT_NAME")
    run_head = (authority.policy.get("recoverable_activation", {}).get("pr_head")
                if event == "pull_request" else authority.policy["approved_head"])
    paths = {workflow, workflow + "@" + branch, workflow + "@" + ref,
             workflow + "@" + authority.policy["approved_head"]}
    if str(run["id"]) != expected_run:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if run["head_sha"] != run_head:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if str(run.get("run_attempt")) != authority.environment.get("GITHUB_RUN_ATTEMPT"):
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if not artifact_run_active(authority, run, expected_run, api):
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if run["event"] != event:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if run["repository"]["full_name"] != native_runner.REPOSITORY:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if str(run["actor"]["id"]) != native_runner.ACTOR:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if str(run["triggering_actor"]["id"]) != native_runner.ACTOR:
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if event != "pull_request" and (not ref.startswith("refs/heads/") or run["head_branch"] != branch):
        raise ValueError("Artifact run provenance differs from the approved workflow")
    if run["path"] not in paths:
        raise ValueError("Artifact run provenance differs from the approved workflow")


class GitHubArtifacts:
    """Authenticate the complete archive against GitHub's run-bound digest before extraction."""
    def __init__(self, authority, api=None, download=None):
        self.authority = authority
        self.run = authority.environment.get("GITHUB_RUN_ID", "")
        if not re.fullmatch(r"[1-9][0-9]*", self.run):
            raise ValueError("A trusted workflow run is required")
        self.api = api or (lambda path: json.loads(subprocess.check_output(
            ["gh", "api", path], env=self.gh_environment(), stderr=subprocess.PIPE, timeout=60)))
        self.download = download or self.download_archive
        run = self.api(f"repos/{native_runner.REPOSITORY}/actions/runs/{self.run}")
        require_artifact_run_provenance(authority, run, self.run, self.api)

    def gh_environment(self):
        environment = dict(self.authority.environment)
        environment["GH_TOKEN"] = environment.get("GITHUB_TOKEN", "")
        if not environment["GH_TOKEN"]:
            raise ValueError("Scoped artifact read token is unavailable")
        return environment

    def download_archive(self, artifact, path):
        with path.open("xb") as stream:
            subprocess.run(["gh", "api", f"repos/{native_runner.REPOSITORY}/actions/artifacts/{artifact['id']}/zip"],
                           env=self.gh_environment(), stdout=stream, stderr=subprocess.PIPE, check=True, timeout=900)
            stream.flush()
            os.fsync(stream.fileno())

    def artifacts(self, prefix):
        if not re.fullmatch(r"[A-Za-z0-9._-]+", prefix):
            raise ValueError("Unsafe artifact selector")
        found, page = [], 1
        while True:
            result = self.api(f"repos/{native_runner.REPOSITORY}/actions/runs/{self.run}/artifacts?per_page=100&page={page}")
            for artifact in result["artifacts"]:
                if artifact["name"].startswith(prefix) and not artifact["expired"]:
                    found.append(artifact)
            if len(result["artifacts"]) < 100:
                return sorted(found, key=lambda item: item["id"], reverse=True)
            page += 1

    def fetch(self, artifact, expected_digest=None):
        checksum = artifact.get("digest", "")
        if (type(artifact["id"]) is not int or artifact["id"] <= 0
                or not re.fullmatch(r"sha256:[0-9a-f]{64}", checksum)
                or artifact["workflow_run"]["head_sha"] != (
                    self.authority.policy.get("recoverable_activation", {}).get("pr_head")
                    if self.authority.environment.get("GITHUB_EVENT_NAME") == "pull_request"
                    else self.authority.policy["approved_head"])
                or str(artifact["workflow_run"]["id"]) != self.run
                or (expected_digest is not None and expected_digest != checksum[7:])):
            raise ValueError("Artifact digest/run/head does not match trusted metadata")
        root = self.authority.cache / "quarantine" / str(uuid.uuid4())
        legacy.owned_directory(root)
        archive, destination = root / "download.zip", root / "bundle"
        size = artifact.get("size_in_bytes")
        reserve = self.authority.config["admission"]["disk_reserve"]
        if type(size) is not int or size <= 0 or shutil.disk_usage(self.authority.cache).free - reserve < size:
            raise ValueError("Disk reserve blocks artifact download")
        self.download(artifact, archive)
        limit = self.authority.config["admission"]["disk_per_worker"]
        if archive.stat().st_size > limit or legacy.digest(archive) != checksum[7:]:
            raise ValueError("Artifact archive differs from external GitHub digest or disk budget")
        legacy.owned_directory(destination)
        with zipfile.ZipFile(archive) as zipped:
            members, names = zipped.infolist(), set()
            expanded = sum(member.file_size for member in members)
            if expanded > limit or shutil.disk_usage(self.authority.cache).free - reserve < expanded:
                raise ValueError("Artifact expansion exceeds reserved disk budget")
            for member in members:
                path = Path(member.filename)
                key = member.filename.rstrip("/").casefold()
                kind = (member.external_attr >> 16) & 0o170000
                if (not key or key in names or path.is_absolute() or ".." in path.parts
                        or "\\" in member.filename or kind not in (0, 0o040000, 0o100000)):
                    raise ValueError("Artifact has duplicate/escaping/nonphysical paths")
                names.add(key)
                target = destination / path
                legacy.owned_directory(target if member.is_dir() else target.parent)
                if not member.is_dir():
                    with zipped.open(member) as source, target.open("xb") as output:
                        shutil.copyfileobj(source, output)
                    target.chmod(0o600)
        physical_tree(destination)
        return destination

    def restore_shard(self, plan, shard, store):
        identity = shard_identity(plan["runtime"], shard)
        if store.matching(identity):
            return True
        prefix = "native-shard-" + plan["runtime"]["mode"] + "-" + shard["id"] + "-"
        for artifact in self.artifacts(prefix):
            bundle = self.fetch(artifact)
            if (bundle / "failure.json").exists():
                store.restore_failure(bundle, identity)
                continue
            # The index is trusted only after the entire archive matched an external API digest.
            store.restore_artifact(bundle, legacy.digest(bundle / "index.json"), identity)
            return True
        return False




def workflow_history(methods, mode, groups, measured=None):
    """Count-based fallback is only a packing hint, not a measured runtime estimate."""
    estimates = {fingerprint(sorted(atom)): 8 * len(atom) for atom in legacy.partition(methods, mode, 1, groups)}
    estimates.update(measured or {})
    return estimates

def workflow_matrix(items, plans):
    by_id = {row["id"]: row for plan in plans for row in plan["shards"]}
    entries = []
    for item in items:
        shard = by_id[item["shard"]]
        suites = sorted({legacy.group_key(method)[1] for method in shard["methods"]})
        label = suites[0] + (" +" + str(len(suites) - 1) + " cohorts" if len(suites) > 1 else "")
        entries.append({**item, "label": label + " (" + str(len(shard["methods"])) + " IDs) " + item["shard"][:8]})
    return {"include": entries or [{"mode": plans[0]["runtime"]["mode"], "shard": "HELD", "worker": "one", "label": "All complete"}]}

def workflow_manifest(plans, workers, store, head):
    if not plans or len(plans) > 2 or len({plan["runtime"]["mode"] for plan in plans}) != len(plans):
        raise ValueError("Workflow requires unique nonempty mode plans")
    if (not workers or not set(workers) <= {"one", "two"} or len(set(workers)) != len(workers)
            or not re.fullmatch(r"[0-9a-f]{40}", head)):
        raise ValueError("Workflow uses only reviewed worker instances")
    pending, expected, inventories, hosts, units = [], [], [], set(), []
    for plan in plans:
        validate_plan(plan)
        inventories.append(plan["inventory"])
        hosts.add(plan["runtime"]["host"])
        for shard in plan["shards"]:
            units.append((plan, shard))
    for plan, shard in sorted(units, key=lambda unit: (-unit[1]["estimated_seconds"], unit[1]["id"])):
        item = {"mode": plan["runtime"]["mode"], "shard": shard["id"],
                "worker": workers[len(expected) % len(workers)]}
        expected.append(item)
        if store.matching(shard_identity(plan["runtime"], shard)) is None:
            pending.append(item)
    if len(hosts) != 1 or any(inventory != inventories[0] for inventory in inventories[1:]) or not expected or len(pending) > 256:
        raise ValueError("Invalid/empty/oversized workflow inventory or cross-host plans")
    return {"schema": SCHEMA, "head": head, "host": next(iter(hosts)), "expected": expected,
            "pending": pending, "phases": ["normal", "leaks"],
            "matrix": workflow_matrix(pending, plans),
            "has_pending": bool(pending)}



def report_progress(plan, store, state, current=None):
    """A progress count is validated durable proof, never the last line of a running log."""
    complete = sum(store.matching(shard_identity(plan["runtime"], row)) is not None for row in plan["shards"])
    suites = sorted({".".join(legacy.group_key(method)) for method in current["methods"]}) if current else []
    record = {"mode": plan["runtime"]["mode"], "completed": complete, "total": len(plan["shards"]),
              "state": state, "current": current["id"] if current else None,
              "suites": suites, "max_runtime_seconds": SHARD_MAX_SECONDS,
              "indivisible_over_target_ids": bool(current and len(current["methods"]) > PACKED_ID_TARGET)}
    legacy.progress(json.dumps(record, sort_keys=True))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
            summary.write("## " + record["mode"] + ": " + str(complete) + "/" + str(record["total"]) + " complete\n\n")
            summary.write(state + "; current " + (record["current"] or "none") + ". Maximum native execution: 7200 seconds.\n\n")
            if suites:
                summary.write("Whole cohorts: " + ", ".join(suites) + ".\n")
            if record["indivisible_over_target_ids"]:
                summary.write("Indivisible suite/shared-process cohort exceeds 64 IDs. No method split or internal checkpoint is claimed. Timeout retains raw failure and blocks quality.\n")
    return record


def report_phase_progress(phase, state):
    legacy.progress(json.dumps({"phase": phase, "state": state}))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
            summary.write("## " + phase + "\n\n" + state + ". Full phase; partial XML is never qualified.\n")

def phase_key(runtime, inventory, phase):
    common = {key: runtime[key] for key in ("toolchain", "sdk", "host", "os", "architecture",
                                           "phase_environment", "opt_in_policy", "policy")}
    common.update(inputs=canonical_inputs(runtime["inputs"]), inventory=inventory, phase=phase)
    return fingerprint(common)


def portable_build(source, destination):
    legacy.owned_directory(destination)
    for directory, names, files in os.walk(source, followlinks=False):
        target = destination / Path(directory).relative_to(source)
        legacy.owned_directory(target)
        names[:] = [name for name in names if not (Path(directory) / name).is_symlink()]
        for name in files:
            path = Path(directory) / name
            if not path.is_symlink():
                shutil.copy2(path, target / name)


class NativeWorkflow:
    def __init__(self, authority, remote=None):
        self.authority, self.store, self.remote = authority, Store(authority.cache), remote

    def artifacts(self):
        if self.remote is None:
            self.remote = GitHubArtifacts(self.authority)
        return self.remote

    def plans(self, bundle, digest):
        manifest = trusted_json(bundle / "workflow-plan.json", digest)
        plans = []
        if manifest["schema"] != SCHEMA or manifest["head"] != self.authority.policy["approved_head"]:
            raise ValueError("Workflow plan is not this approved source")
        if not manifest["plans"] or not set(manifest["plans"]) <= set(MODES):
            raise ValueError("Invalid workflow modes")
        for mode in MODES:
            if mode not in manifest["plans"]:
                continue
            item = manifest["plans"][mode]
            if item["path"] != mode + ".json":
                raise ValueError("Workflow plan path changed")
            plan = validate_plan(trusted_json(bundle / item["path"], item["sha256"]))
            if plan["runtime"]["mode"] != mode:
                raise ValueError("Workflow plan mode changed")
            if any(len(row["methods"]) > PACKED_ID_TARGET and len(row["atoms"]) != 1 for row in plan["shards"]):
                raise ValueError("Workflow shard packed more than sixty-four IDs across atomic units")
            plans.append(plan)
        expected = workflow_manifest(plans, sorted(self.authority.workers), self.store,
                                     self.authority.policy["approved_head"])
        if (manifest["host"] != expected["host"] or manifest["expected"] != expected["expected"]
                or len({fingerprint(item) for item in manifest["pending"]}) != len(manifest["pending"])
                or any(item not in expected["expected"] for item in manifest["pending"])
                or manifest["has_pending"] != bool(manifest["pending"])
                or manifest["matrix"] != workflow_matrix(manifest["pending"], plans)):
            raise ValueError("Workflow expected/pending inventory changed")
        return plans, manifest

    def restore_builds(self, bundle, only_mode=None):
        builder = NativeBuilder(self.authority)
        for mode in (only_mode,) if only_mode else MODES:
            source = bundle if only_mode else bundle / "builds" / mode
            destination = self.authority.cache / "builds" / self.authority.policy["approved_head"] / mode
            if destination.exists() or not (source / "build.json").exists():
                continue
            legacy.owned_directory(destination.parent)
            size = sum(path.stat().st_size for path in source.rglob("*") if path.is_file())
            budget = self.authority.admission()
            if budget["disk_available"] - budget["disk_reserve"] < size:
                raise ValueError("Disk reserve blocks frozen mode restoration")
            stage = destination.with_name(mode + ".restore-" + str(uuid.uuid4()))
            shutil.copytree(source, stage)
            writable_private_tree(stage)
            build = load_json(stage / "build.json")
            if build["runtime"]["mode"] != mode:
                raise ValueError("Portable build mode does not match its destination")
            for name, entry in build["scratch"].items():
                if Path(name).is_absolute() or ".." in Path(name).parts or Path(name).as_posix() != name:
                    raise ValueError("Portable build path escaped scratch")
                path = stage / "scratch" / name
                if "sha256" in entry:
                    path.chmod(0o700 if entry["executable"] else 0o600)
                elif "link" in entry:
                    if Path(entry["link"]).is_absolute():
                        raise ValueError("Portable build has an absolute link")
                    path.symlink_to(entry["link"])
            builder.validate_frozen(build, stage, immutable=False)
            seal(stage)
            require_sealed(stage)
            stage.rename(destination)
            sync_directory(destination.parent)

    def checks(self, output, timeout):
        """Run every original non-phase make-ci prerequisite under the same physical lease."""
        targets = ["native-runner-check", "instance-equality-check", "ci-capture-check", "flight-controls-check",
                   "homebrew-cask-check", "ships-check", "showroom-check", "mission-packs-check", "sanitizer-checkpoints-check"]
        legacy.owned_directory(output)
        with NativeBuilder(self.authority).preparation_claim() as lock:
            before = legacy.executable_inputs(self.authority.root, ".build")
            command = ["make", *targets]
            durable_json(output / "launch.json", {"head": self.authority.policy["approved_head"], "command": command,
                                                  "authorization": self.authority.authorization()})
            code = execute_process(command, self.authority.root, output, timeout, [lock.fileno()],
                                   self.authority.execution_environment(),
                                   NativeMonitor(self.authority, output, self.authority.root), isolate_environment=False)
            after = legacy.executable_inputs(self.authority.root, ".build")
            if any(after.get(name) != value for name, value in before.items()):
                code = code or 126
            durable_json(output / "result.json", {"head": self.authority.policy["approved_head"], "exit_code": code,
                                                  "inputs": before, "command": command})
            seal(output)
            if code != 0:
                raise ValueError("Required make-ci prerequisite failed; raw output retained")
        return {"checks_exit_code": code}

    def export_preparation(self, mode, output):
        legacy.owned_directory(output)
        for path in sorted((self.authority.cache / "preparation").glob("*/launch.json")):
            record = load_json(path)
            if record.get("head") == self.authority.policy["approved_head"] and record.get("mode") == mode:
                physical_tree(path.parent)
                shutil.copytree(path.parent, output / path.parent.name)
        durable_json(output / "export.json", {"head": self.authority.policy["approved_head"], "mode": mode,
                                              "outputs": physical_tree(output)})
        seal(output)
        return {"raw_preparation_retained": True}

    def export_checks(self, source, output):
        """Retain bound raw evidence even when prerequisites never created a result."""
        environment = self.authority.environment
        expected = {"head": self.authority.policy["approved_head"], "role": "native_checks",
                    "run_id": environment["GITHUB_RUN_ID"], "run_attempt": environment["GITHUB_RUN_ATTEMPT"]}
        if environment.get("GITHUB_JOB") != "native_checks":
            raise ValueError("Raw prerequisite export requires the exact checks role")
        if (not source.is_absolute() or not output.is_absolute() or source != source.resolve() or output != output.resolve() or source == output
                or source.is_relative_to(output) or output.is_relative_to(source) or output.exists()):
            raise ValueError("Raw prerequisite export requires separate new physical output")

        def bound(record):
            if not isinstance(record, dict):
                return False
            authorization = record.get("authorization", {})
            return (isinstance(authorization, dict) and record.get("head") == expected["head"]
                    and all(authorization.get(name) == value for name, value in expected.items()))

        def copy_raw(path, destination):
            entries = physical_tree(path)
            legacy.owned_directory(destination.parent)
            shutil.copytree(path, destination)
            if physical_tree(destination) != entries:
                raise ValueError("Raw prerequisite evidence changed during export")

        legacy.owned_directory(output)
        checks_state, checks_binding = "missing", "absent"
        if source.exists() or source.is_symlink():
            entries = physical_tree(source)
            if entries:
                checks_state, checks_binding = "incomplete", "unbound"
                launch = source / "launch.json"
                if launch.is_file() and bound(load_json(launch)):
                    copy_raw(source, output / "checks")
                    checks_binding = "matched"
                    if "result.json" in entries:
                        checks_state = "result-recorded"
        for launch in sorted((self.authority.cache / "preparation").glob("*/launch.json")):
            native_runner.require_owned_activation_file(launch)
            if bound(load_json(launch)):
                copy_raw(launch.parent, output / "preparation" / launch.parent.name)
        durable_json(output / "export.json", {"schema": SCHEMA, "kind": "raw-prerequisites",
            "status": "unqualified", **expected, "checks_state": checks_state,
            "checks_binding": checks_binding, "outputs": physical_tree(output)})
        seal(output)
        return {"raw_prerequisites_retained": True, "checks_state": checks_state, "status": "unqualified"}

    def restore_preparation(self, modes):
        # Restore a prior attempt only after archive authentication; retain failed local stages.
        for mode in modes:
            if (self.authority.cache / "builds" / self.authority.policy["approved_head"] / mode).exists():
                continue
            for artifact in self.artifacts().artifacts("native-build-" + mode + "-"):
                try:
                    bundle = self.artifacts().fetch(artifact)
                    with NativeBuilder(self.authority).preparation_claim():
                        self.restore_builds(bundle, mode)
                    break
                except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
                    legacy.progress(json.dumps({"rejected_prepare_artifact": artifact["id"],
                                                "reason": type(error).__name__}))

    def prepare(self, output, modes=MODES):
        if output.exists():
            raise ValueError("Workflow output bundle exists")
        self.restore_preparation(modes)
        legacy.owned_directory(output)
        plans, builder = [], NativeBuilder(self.authority)
        for mode in modes:
            frozen = self.authority.cache / "builds" / self.authority.policy["approved_head"] / mode
            build = builder.prepare(mode, frozen)
            hints = self.authority.config.get("planning", {}).get(mode, {})
            plan = make_plan(build["runtime"], build["inventory"], build["shared_groups"],
                             workflow_history(build["inventory"], mode, build["shared_groups"], hints.get("history")),
                             hints.get("resources"), hints.get("budget_seconds", 600), max_methods=PACKED_ID_TARGET)
            plans.append(plan)
            durable_json(output / (mode + ".json"), plan)
            portable_build(frozen, output / "builds" / mode)
        manifest = workflow_manifest(plans, sorted(self.authority.workers), self.store,
                                     self.authority.policy["approved_head"])
        manifest["plans"] = {mode: {"path": mode + ".json", "sha256": legacy.digest(output / (mode + ".json"))}
                             for mode in modes}
        durable_json(output / "workflow-plan.json", manifest)
        checksum = legacy.digest(output / "workflow-plan.json")
        metadata = output / "plan"
        legacy.owned_directory(metadata)
        for name in ("workflow-plan.json", *(mode + ".json" for mode in modes)):
            shutil.copyfile(output / name, metadata / name)
        cached = self.authority.cache / "workflow-plans" / checksum
        legacy.owned_directory(cached.parent)
        if not cached.exists():
            atomic_copy(metadata, cached)
        for plan in plans:
            report_progress(plan, self.store, "prepared")
        return {"manifest_sha256": checksum, "matrix": manifest["matrix"], "has_pending": manifest["has_pending"]}

    def load(self, artifact_id, archive_digest, digest, output):
        cached = self.authority.cache / "workflow-plans" / digest
        if cached.exists():
            source = cached
        else:
            artifact = self.artifacts().api(f"repos/{native_runner.REPOSITORY}/actions/artifacts/{artifact_id}")
            if not artifact["name"].startswith("native-plan-"):
                raise ValueError("Wrong workflow plan artifact")
            source = self.artifacts().fetch(artifact, archive_digest)
        self.plans(source, digest)
        if output.exists():
            self.plans(output, digest)
        else:
            atomic_copy(source, output)

    def restore_phase(self, plan, phase):
        target = self.authority.cache / "full-phases" / phase_key(plan["runtime"], plan["inventory"], phase)
        if target.exists():
            require_sealed(target)
            validate_phase(target, load_json(target / "commit.json")["sha256"], phase,
                           plan["runtime"], plan["inventory"])
            return target
        for artifact in self.artifacts().artifacts("native-phase-" + phase + "-"):
            bundle = self.artifacts().fetch(artifact)
            if (bundle / "failure.json").exists():
                continue
            checksum = legacy.digest(bundle / "index.json")
            validate_phase(bundle, checksum, phase, plan["runtime"], plan["inventory"])
            legacy.owned_directory(target.parent)
            atomic_copy(bundle, target)
            return target
        return None

    def aggregate_report(self, plans, output):
        legacy.owned_directory(output)
        try:
            result = self.aggregate(plans)
        except BaseException as error:
            durable_json(output / "result.json", {"head": self.authority.policy["approved_head"],
                         "status": "failed", "failure": type(error).__name__,
                         "plan_sha256": [fingerprint(plan) for plan in plans]})
            seal(output)
            raise
        durable_json(output / "result.json", {"head": self.authority.policy["approved_head"],
                     "result": result, "plan_sha256": [fingerprint(plan) for plan in plans]})
        seal(output)
        return result

    def aggregate(self, plans):
        if len(plans) != 2 or {plan["runtime"]["mode"] for plan in plans} != set(MODES):
            raise ValueError("Both independent sanitizer plans are required")
        for plan in plans:
            NativeExecutor(self.authority, sorted(self.authority.workers)[0]).verify(plan["runtime"])
            for shard in plan["shards"]:
                if self.store.matching(shard_identity(plan["runtime"], shard)) is None:
                    self.artifacts().restore_shard(plan, shard, self.store)
        phases = [self.restore_phase(plans[0], phase) for phase in ("normal", "leaks")]
        if any(path is None for path in phases):
            raise ValueError("A full normal/leak proof is missing")
        result = aggregate(plans, self.store, phases[0], legacy.digest(phases[0] / "index.json"),
                           phases[1], legacy.digest(phases[1] / "index.json"))
        # validate_phase has rehashed this capsule against both mode runtime identities.
        for name in ("coverage.xml", "coverage.lcov"):
            source = phases[0] / "attempt" / name
            shutil.copyfile(source, self.authority.root / name)
        return result

    def export_phase(self, plan, phase, output):
        complete = self.restore_phase(plan, phase)
        if complete is not None:
            if not output.exists():
                atomic_copy(complete, output)
            validate_phase(output, legacy.digest(complete / "index.json"), phase, plan["runtime"], plan["inventory"])
            return {"status": "passed"}
        legacy.owned_directory(output)
        if (output / "failure.json").exists():
            return {"status": "failed", "retained": True}
        candidates = []
        for launch in (self.authority.cache / "phase-runs").glob("*/launch.json"):
            physical_tree(launch.parent)
            record = load_json(launch)
            if (record["phase"] == phase and record["head"] == self.authority.policy["approved_head"]
                    and record["host"] == plan["runtime"]["host"]):
                candidates.append(launch.parent)
        if candidates:
            latest = max(candidates, key=lambda path: path.stat().st_mtime_ns)
            shutil.copytree(latest, output / "last-attempt")
        durable_json(output / "failure.json", {"schema": SCHEMA, "status": "failed" if candidates else "missing",
                                               "phase": phase, "head": self.authority.policy["approved_head"],
                                               "outputs": physical_tree(output)})
        seal(output)
        return {"status": "failed" if candidates else "missing"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "prepare", "worker", "pool", "export", "restore",
                                             "phase", "aggregate", "workflow-prepare", "workflow-load",
                                             "workflow-run", "workflow-build", "workflow-build-export", "workflow-checks", "workflow-checks-export", "workflow-phase", "workflow-export",
                                             "workflow-phase-export", "workflow-aggregate"))
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--digest")
    parser.add_argument("--other-input", type=Path)
    parser.add_argument("--other-digest")
    parser.add_argument("--policy", type=Path, default=os.environ.get("ELITE_NATIVE_POLICY"))
    parser.add_argument("--mode", choices=MODES)
    parser.add_argument("--worker")
    parser.add_argument("--shard")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--artifact-digest")
    parser.add_argument("--phase", choices=("normal", "leaks"))
    parser.add_argument("--artifact-id", type=int)
    parser.add_argument("--archive-digest")
    parser.add_argument("--include-failures", action="store_true")
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
    authority.verify_request(args.mode, args.shard, args.worker, args.phase)
    store = Store(authority.cache)
    positive(args.timeout)
    if args.command.startswith("workflow-"):
        workflow = NativeWorkflow(authority)
        if args.command == "workflow-checks":
            if args.output is None:
                parser.error("workflow-checks requires --output")
            result = workflow.checks(args.output, args.timeout)
        elif args.command == "workflow-checks-export":
            if args.input is None or args.output is None:
                parser.error("workflow-checks-export requires --input and --output")
            result = workflow.export_checks(args.input, args.output)
        elif args.command == "workflow-build-export":
            if args.mode is None or args.output is None:
                parser.error("workflow-build-export requires --mode and --output")
            result = workflow.export_preparation(args.mode, args.output)
        elif args.command == "workflow-build":
            if args.mode is None:
                parser.error("workflow-build requires --mode")
            workflow.restore_preparation((args.mode,))
            frozen = authority.cache / "builds" / authority.policy["approved_head"] / args.mode
            if frozen.exists():
                NativeBuilder(authority).prepare(args.mode, frozen)
                result = {"reused": True, "durable_build": str(frozen)}
            else:
                result = NativeBuilder(authority).build_only(args.mode, args.timeout)
        elif args.command == "workflow-prepare":
            if args.output is None:
                parser.error("workflow-prepare requires --output")
            result = workflow.prepare(args.output, (args.mode,) if args.mode else MODES)
            with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
                for name, value in result.items():
                    output.write(name + "=" + json.dumps(value, separators=(",", ":")) + "\n"
                                 if not isinstance(value, str) else name + "=" + value + "\n")
        elif args.command == "workflow-load":
            if not args.digest or not args.archive_digest or not args.artifact_id or args.output is None:
                parser.error("workflow-load requires trusted artifact ID/archive digest/manifest digest and output")
            workflow.load(args.artifact_id, args.archive_digest, args.digest, args.output)
            result = {"loaded": True}
        else:
            if args.input is None or not args.digest:
                parser.error("workflow operation requires plan bundle --input and trusted --digest")
            plans, manifest = workflow.plans(args.input, args.digest)
            if args.command == "workflow-aggregate":
                if authority.environment.get("GITHUB_JOB") == "native_aggregate" and (
                        not args.other_input or args.other_digest != authority.environment.get("OTHER_PLAN_DIGEST")):
                    raise ValueError("Second aggregate plan differs from the owned assignment")
                if args.other_input is not None and args.other_digest:
                    other, _ = workflow.plans(args.other_input, args.other_digest)
                    plans += other
                result = workflow.aggregate_report(plans, args.output) if args.output else workflow.aggregate(plans)
            elif args.command in ("workflow-phase", "workflow-phase-export"):
                if args.phase is None or args.output is None:
                    parser.error("workflow phase requires --phase and --output")
                if args.command == "workflow-phase":
                    report_phase_progress(args.phase, "starting or restoring exact durable proof")
                    workflow.restore_phase(plans[0], args.phase)
                    checksum = NativePhaseRunner(authority, NativeExecutor(authority, "one")).run(
                        args.phase, plans[0], args.output, args.timeout)
                    result = {"phase_sha256": checksum}
                else:
                    result = workflow.export_phase(plans[0], args.phase, args.output)
                    report_phase_progress(args.phase, result["status"])
            else:
                plan = next((plan for plan in plans if plan["runtime"]["mode"] == args.mode), None)
                shard = next((row for row in plan["shards"] if row["id"] == args.shard), None) if plan else None
                if shard is None:
                    parser.error("exact workflow --mode and --shard are required")
                assignment = {"mode": args.mode, "shard": args.shard, "worker": args.worker}
                if assignment not in manifest["expected"]:
                    parser.error("worker is outside trusted planned assignment")
                if args.command == "workflow-export":
                    if args.output is None:
                        parser.error("workflow-export requires --output")
                    result = store.export_outcome(shard_identity(plan["runtime"], shard), args.output)
                    report_progress(plan, store, result.get("status", "exported"), shard)
                else:
                    if store.matching(shard_identity(plan["runtime"], shard)) is None:
                        workflow.artifacts().restore_shard(plan, shard, store)
                    if args.timeout > SHARD_MAX_SECONDS:
                        raise ValueError("Native shards have a hard two-hour execution bound")
                    observation = report_progress(plan, store, "starting", shard)
                    executor = NativeExecutor(authority, args.worker)
                    executor.progress_context = {"validated_shards_completed": observation["completed"],
                                                 "shards_total": observation["total"]}
                    try:
                        result = run_shard(plan, shard["id"], store, executor,
                                           authority.policy["approved_head"], args.timeout, authority.admission())
                    except BaseException:
                        report_progress(plan, store, "failed or interrupted", shard)
                        raise
                    report_progress(plan, store, "reused" if result["reused"] else "completed", shard)
        legacy.progress(json.dumps(result))
        return
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
        runner = NativePhaseRunner(authority, NativeExecutor(authority, args.worker))
        checksum = runner.run(args.phase, plans[0], args.output, args.timeout)
        result = {"phase_sha256": checksum, "reused": runner.reused,
                  "tested_head": load_json(args.output / "index.json")["origin"]["tested_head"],
                  "current_head": authority.policy["approved_head"]}
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
            result = (store.export_outcome(identity, args.output) if args.include_failures else
                      {"index_sha256": store.export(identity, args.output)})
        else:
            if args.artifact is None or args.artifact_digest is None:
                parser.error("restore requires --artifact and trusted --artifact-digest")
            result = {"restored": str(store.restore_artifact(args.artifact, args.artifact_digest, identity))}
    legacy.progress(json.dumps(result))


if __name__ == "__main__":
    main()
