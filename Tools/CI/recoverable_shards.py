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
ASAN_PACKED_ID_TARGET = 16
LOCAL_PACKED_ID_TARGET = 16
MODES = ("thread", "address")
AUTHORIZATION_CONTROLS = (
    "ELITE_RECOVERABLE_PLAN_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_PATH",
    "ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
    "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE",
    "ELITE_RECOVERABLE_POLICY_SHA256", "ELITE_RECOVERABLE_WORKFLOW_SHA256",
    "ELITE_RECOVERABLE_ACTIVATION_SHA256", "ELITE_RECOVERABLE_CODE_ENABLED")


def execution_policy_digest(config):
    """Shared execution limits matter; planning hints and physical worker assignment do not."""
    value = {"schema": SCHEMA, "policy": POLICY, "host": config["host"], "admission": config["admission"]}
    if "phase_profiles" in config:
        value["phase_profiles"] = config["phase_profiles"]
    if "vmmap_diagnostic" in config:
        value["vmmap_diagnostic"] = config["vmmap_diagnostic"]
    return fingerprint(value)


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
    if isinstance(record, dict) and record.get("kind") == "validated-local-sanitizer-v1":
        return validate_local_authorization(record, runtime)
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


def physical_tree(root, read_only=False):
    """Inspect every child, including directories, without following links."""
    if read_only:
        owned_bridge_path(root)
        if not root.is_dir():
            raise ValueError("Original evidence directory is missing")
    else:
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
def claim(root, name, shared=False, wait_seconds=0, diagnostic_role=None):
    legacy.owned_directory(root)
    path = root / (fingerprint(name) + ".lock")
    with file_claim(path, shared, wait_seconds, diagnostic_role=diagnostic_role) as lock:
        yield lock


@contextmanager
def file_claim(path, shared=False, wait_seconds=0, diagnostic_role=None):
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
        if diagnostic_role is None:
            yield lock
        else:
            with native_runner._diagnostic_lease_context(lock, diagnostic_role) as witness:
                lock._diagnostic_lease = witness
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
    if runtime["mode"] == "address":
        max_methods = min(max_methods, ASAN_PACKED_ID_TARGET) if max_methods is not None else ASAN_PACKED_ID_TARGET
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
        if (plan["runtime"]["mode"] == "address" and len(shard["methods"]) > ASAN_PACKED_ID_TARGET
                and len(shard["atoms"]) != 1):
            raise ValueError("ASAN packing exceeds the process memory profile")
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


def evidence_outputs(attempt, runtime, methods, read_only=False):
    """Reuse strict native XML and opt-in validation, without promoting old schemas."""
    entries = physical_tree(attempt, read_only=read_only)
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
        if authorization["kind"] == "validated-local-sanitizer-v1" and not (
                authorization["authorized_at"] <= child["started"] < authorization["session"]["expires_at"]):
            raise ValueError("Native child started outside its local authorization window")
        if (authorization["kind"] == "validated-local-sanitizer-v1"
                and fingerprint(load_json(attempt / "start.json")["identity"]) not in authorization["session"]["shards"]):
            raise ValueError("Native child selection is outside its exact local shard assignment")
    return {name: digest for name, digest in entries.items()
            if name not in ("result.json", "commit.json")}


def validate_success(attempt, identity, receipt_digest=None, immutable=True, read_only=False):
    if VM_DIAGNOSTIC_ENV in identity.get("runtime", {}).get("environment", {}):
        raise ValueError("Diagnostic evidence can never become ordinary PASS")
    if (attempt / "diagnostic.json").exists():
        raise ValueError("Diagnostic artifacts are not ordinary shard evidence")
    require_fields(identity, ("schema", "policy", "runtime", "methods", "atoms", "claims",
                              "audited", "resource_audits"))
    validate_runtime(identity["runtime"])
    if type(identity["schema"]) is not int or identity["schema"] != SCHEMA or identity["policy"] != POLICY:
        raise ValueError("Unknown shard identity protocol")
    physical_tree(attempt, read_only=read_only)
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
    if result["outputs"] != evidence_outputs(attempt, identity["runtime"], identity["methods"], read_only=read_only):
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
    def __init__(self, root, read_only=False):
        self.root, self.read_only = Path(root), read_only
        if read_only:
            owned_bridge_path(self.root)
            if not self.root.is_dir():
                raise ValueError("Original read-only store is missing")
        else:
            legacy.owned_directory(self.root)

    def matching(self, identity):
        parent = self.root / "attempts" / fingerprint(identity)
        if not parent.exists():
            return None
        if self.read_only:
            owned_bridge_path(parent)
        else:
            legacy.owned_directory(parent)
        for attempt in sorted(parent.iterdir()):
            if attempt.is_symlink() or not attempt.is_dir():
                raise ValueError("Unexpected attempt storage entry")
            if attempt.is_dir() and (attempt / "result.json").exists():
                try:
                    return attempt, validate_success(attempt, identity, read_only=self.read_only)
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
    if isinstance(observer, VmmapDiagnostic):
        return observer.execute(command, timeout, descriptors, environment, progress)
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


def reservation_update(store, reservation, *, wait_seconds=30, **changes):
    with claim(store.root / "claims", "admission", wait_seconds=wait_seconds):
        current = load_json(reservation["path"])
        if current["nonce"] != reservation["nonce"]:
            raise ValueError("Reservation generation changed")
        if current["state"] == "released":
            return
        current.update(changes)
        durable_json(reservation["path"], current)


@contextmanager
def reserve_worker(store, executor, runtime, admission, timeout):
    native_runner.require_diagnostic_custody_clear()
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
                diagnostic = getattr(getattr(executor, "authority", None), "config", {}).get("vmmap_diagnostic")
                context = claim(store.root / "claims", "worker:" + str(slot),
                                diagnostic_role="reservation" if diagnostic is not None else None)
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
        diagnostic = getattr(getattr(executor, "authority", None), "config", {}).get("vmmap_diagnostic")
        found = None if diagnostic is not None else store.matching(identity)
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
        owner = executor.owner_identity()
        durable_json(attempt / "start.json", {"identity": identity, "tested_head": current_head, "timeout_seconds": timeout,
                                             "owner": owner,
                                             "paths": {"proof": str(attempt), "temporary": str(
                                                 store.root / "temporary" / attempt.name)}})
        if hasattr(executor, "authority"):
            durable_json(attempt / "authorization.json", executor.authority.authorization())
        reservation_update(store, reservation, attempt=str(attempt))
        fault("before-execution")
        started = time.monotonic()
        reservation_update(store, reservation, state="launching")
        executor.reservation_callback = lambda: reservation_update(
            store, reservation, wait_seconds=0 if diagnostic is not None else 30, state="running")
        if diagnostic is not None:
            executor.diagnostic_leases = [getattr(executor.authority, "controller_lease", None)] + [
                getattr(lock, "_diagnostic_lease", None) for lock in locks
                if getattr(lock, "_diagnostic_lease", None) is not None]
            executor.owner_binding = owner
        # The executor must retain inherited claim descriptors in its owned child.
        exit_code = executor.execute(shard, attempt, timeout, [lock.fileno() for lock in locks])
        fault("after-exit")
        if getattr(executor, "diagnostic_attempt", None) == attempt:
            return validate_vmmap_evidence(attempt, identity)
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


def phase_matches_runtime(identity, runtime, inventory, phase_profile=None):
    if (identity["phase"] not in ("normal", "leaks")
            or canonical_inputs(identity["inputs"]) != canonical_inputs(runtime["inputs"])
            or identity["swift"] != runtime["toolchain"]
            or fingerprint({"version": identity["sdk"], "path": identity["sdk_path"]}) != runtime["sdk"]
            or fingerprint(identity["os_version"]) != runtime["os"]
            or identity["architecture"] != runtime["architecture"]
            or identity["environment"] != runtime["phase_environment"]):
        raise ValueError("Full phase belongs to different executable inputs or runtime")
    build = identity.get("build_profile")
    if phase_profile is None:
        if build is not None:
            raise ValueError("A phase build profile was not independently approved")
    else:
        require_fields(build, ("kind", "phase", "profile", "policy_sha256", "admission", "flags", "argv"))
        expected_flags = ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
        expected = [identity["swift_executable"], "build", *(["--build-tests"] if identity["phase"] == "normal" else []),
                    *identity["flags"], *expected_flags]
        if (build["kind"] != "owned-phase-build-v1" or build["phase"] != identity["phase"]
                or build["profile"] != phase_profile["build_profile"] or build["admission"] != phase_profile["admission"]
                or build["flags"] != expected_flags or build["argv"] != expected
                or not re.fullmatch(r"[0-9a-f]{64}", build["policy_sha256"])):
            raise ValueError("Actual phase build argv/profile/allocation differs")
    if identity["phase"] == "normal":
        if (identity["inventory"] != inventory or identity["opt_in_policy"] != runtime["opt_in_policy"]
                or identity["policy"] != "normal-coverage-80-v1"
                or identity["flags"] != ["--enable-code-coverage"] or identity["parallel"] is not True):
            raise ValueError("Full normal phase/coverage policy was weakened")
    elif (identity["inventory"] or identity["policy"] != "leaks-at-exit-diagnostics-v1"
          or identity["flags"] or identity["parallel"] is not False):
        raise ValueError("Full leak phase policy was weakened")


def freeze_phase(attempt, identity, runtime, inventory, verifier, destination, phase_profile=None, phase_memory=None):
    """An authorized adapter must verify the actual host at capture, never infer it from old receipts."""
    verifier.verify(runtime)
    origin = verifier.phase_origin(Path(attempt), identity)
    phase_matches_runtime(identity, runtime, inventory, phase_profile)
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
    if phase_profile is not None:
        if identity["build_profile"]["policy_sha256"] != origin["authorization"]["policy_sha256"]:
            raise ValueError("Phase build policy differs from actual parent authorization")
        validate_phase_command(result, load_json(Path(attempt) / "start.json"))
        validate_phase_memory(phase_memory, identity, phase_profile, origin)
        durable_json(destination / "phase-memory.json", phase_memory)
        manifest["phase_memory_sha256"] = legacy.digest(destination / "phase-memory.json")
    durable_json(destination / "index.json", manifest)
    checksum = legacy.digest(destination / "index.json")
    durable_json(destination / "commit.json", {"sha256": checksum})
    seal(destination)
    return checksum


def validate_phase(bundle, trusted_digest, phase, runtime, inventory, phase_profile=None):
    bundle = Path(bundle)
    if phase_profile is not None:
        require_sealed(bundle)
    physical_tree(bundle)
    if (legacy.digest(bundle / "index.json") != trusted_digest
            or {item.name for item in bundle.iterdir()} != ({"index.json", "attempt", "commit.json"}
                | ({"phase-memory.json"} if phase_profile is not None else set()))
            or load_json(bundle / "commit.json") != {"sha256": trusted_digest}):
        raise ValueError("Phase index differs from trusted host capture")
    manifest = load_json(bundle / "index.json")
    require_fields(manifest, {"schema", "host", "identity", "origin", "receipt_sha256"}
                   | ({"phase_memory_sha256"} if phase_profile is not None else set()))
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
    phase_matches_runtime(identity, runtime, inventory, phase_profile)
    if phase_profile is not None:
        if (identity["build_profile"]["policy_sha256"] != origin["authorization"]["policy_sha256"]
                or legacy.digest(bundle / "phase-memory.json") != manifest["phase_memory_sha256"]):
            raise ValueError("Phase profile policy or captured memory hash changed")
        validate_phase_memory(load_json(bundle / "phase-memory.json"), identity, phase_profile, origin)
    if not phases.successful_phase(bundle / "attempt", identity):
        raise ValueError("Full normal/zero-leak proof is missing or changed")
    result = load_json(bundle / "attempt" / "result.json")
    if phase_profile is not None:
        if "build.log" not in result["outputs"]:
            raise ValueError("The selected phase profile requires its actual build log")
        validate_phase_command(result, load_json(bundle / "attempt" / "start.json"))
    if (type(result["exit_code"]) is not int or result["exit_code"] != 0
            or type(result.get("native_exit_code")) is not int or result["native_exit_code"] != 0
            or origin["tested_head"] != result["tested_head"]):
        raise ValueError("Phase needs explicit successful native and overall exits")


def validate_phase_command(result, start):
    identity, command = result["identity"], result["command"]
    if start["identity"] != identity or start["command"] != command or start["tested_head"] != result["tested_head"]:
        raise ValueError("Actual phase command/source provenance changed")
    image = Path(identity["phase_image"])
    if not image.is_absolute() or image != image.resolve():
        raise ValueError("Actual phase image must be a physical absolute path")
    if identity["phase"] == "leaks":
        expected = ["/usr/bin/leaks", "--atExit", "--", str(image), "--diagnostics"]
    else:
        report = Path(command[-1])
        if not report.is_absolute() or report.name != "tests.xml" or report != report.resolve():
            raise ValueError("Actual normal phase report path changed")
        expected = [identity["swift_executable"], "test", "--enable-code-coverage", "--skip-build",
                    "--xunit-output", str(report)]
    if command != expected:
        raise ValueError("Actual native phase command or diagnostics were weakened")


def validate_phase_memory(value, identity, profile, origin):
    require_fields(value, ("processes", "child", "terminal"))
    record, child, terminal = value["processes"], value["child"], value["terminal"]
    memory = record.get("resident_memory", {})
    if (origin["authorization"]["role"] != "native_phase" or origin["authorization"]["phase"] != identity["phase"]
            or origin["authorization"]["head"] != origin["tested_head"]
            or record.get("running") is not False or record.get("workspace") != origin["authorization"]["workspace"]
            or type(child.get("pid")) is not int or child["pid"] <= 0 or terminal.get("pid") != child["pid"]
            or type(terminal.get("exit_code")) is not int or terminal["exit_code"] != 0
            or record.get("root", {}).get("pid") != child["pid"] or not record["root"].get("start")
            or not same_process(record["root"], record.get("processes", {}).get(str(child["pid"])))
            or memory.get("kind") != "sampled-owned-process-rss-v1" or memory.get("mode") != identity["phase"]
            or memory.get("phase_profile_sha256") != fingerprint(profile) or memory.get("failure") is not None
            or memory.get("budget_bytes") != profile["admission"]["peak_per_worker"]
            or type(memory.get("samples")) is not int or memory["samples"] < 1
            or type(memory.get("high_water_bytes")) is not int or not 0 <= memory["high_water_bytes"] <= memory["budget_bytes"]
            or type(memory.get("helper_samples")) is not int or not 0 <= memory["helper_samples"] <= memory["samples"]
            or (identity["phase"] == "normal" and memory["helper_samples"] < 1)):
        raise ValueError("Phase process/image lifecycle or independent RSS budget proof is incomplete")
    if identity["phase"] == "normal":
        parsed = {}
        for uuid_value, architecture in re.findall(r"UUID: ([0-9A-Fa-f-]{36}) \(([^)]+)\)", identity["image_uuid"]):
            if architecture in parsed:
                raise ValueError("Duplicate normal image architecture")
            parsed[architecture] = uuid_value.upper()
        if not parsed or {"sha256": identity["image_sha256"], "uuid": fingerprint(parsed)} not in record["observed_images"].values():
            raise ValueError("Normal memory capture did not observe its exact native helper image")


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


def process_rows(raw, resident=False):
    """Use the existing capture-quality ps format and PID/start/command ownership rules."""
    rows = {}
    for line in raw.splitlines():
        fields = line.split(None, 10 if resident else 9)
        if resident:
            if (len(fields) != 11 or not all(value.isdecimal() for value in (fields[0], fields[9]))
                    or int(fields[0]) in rows):
                raise ValueError("Incomplete resident process snapshot")
            rss = int(fields.pop(9)) * 1024  # Darwin ps reports resident size in KiB, not bytes.
        if len(fields) == 10:
            rows[int(fields[0])] = {"parent": int(fields[1]), "group": int(fields[2]),
                                   "state": fields[3], "start": " ".join(fields[4:9]),
                                   "command": fields[9]}
            if resident:
                rows[int(fields[0])]["rss_bytes"] = rss
    if resident and not rows:
        raise ValueError("Empty resident process snapshot")
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
        native_runner.require_diagnostic_custody_clear()
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
        self.configure_storage()

    def configure_storage(self):
        """Retain the same disjoint owned storage and committed controller checks."""
        self.config = self.policy["recoverable_shards"]
        required = {"schema", "host", "cache", "legacy_cache", "workers", "admission"}
        if not required <= set(self.config) or set(self.config) - required - {"planning", "phase_profiles", "vmmap_diagnostic"}:
            raise ValueError("Unexpected native activation fields")
        if "vmmap_diagnostic" in self.config and not isinstance(self, LocalAuthority):
            raise ValueError("The diagnostic is restricted to its owned local session")
        native_runner.backend_descriptor(self.policy)
        if self.backend() == native_runner.LOCAL_COMPONENTS_BACKEND or "phase_profiles" in self.config:
            native_runner.phase_profile(self.policy, "normal")
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

    def snapshot(self, resident=False):
        fields = "pid=,ppid=,pgid=,stat=,lstart=," + ("rss=," if resident else "") + "command="
        return process_rows(self.output(["ps", "-axo", fields]), resident=resident)

    def host(self):
        raw = self.output(["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"])
        matches = re.findall(r'"IOPlatformUUID"\s*=\s*"([0-9A-Fa-f-]{36})"', raw)
        if len(matches) != 1 or matches[0].upper() != self.config["host"]:
            raise ValueError("Physical hardware identity differs from host activation")
        return matches[0].upper()

    def backend(self):
        return native_runner.backend_descriptor(self.policy)[0]

    def phase_profile(self, phase):
        return native_runner.phase_profile(self.policy, phase)

    def admission(self, phase=None):
        native_runner.require_diagnostic_custody_clear()
        if phase is not None and self.phase_profile(phase) is None:
            raise ValueError("Independent phase admission was not approved")
        bounds = dict(self.config["admission"] if phase is None else self.phase_profile(phase)["admission"])
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
            if phase is not None:
                record["phase"] = phase
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

    def build_flags(self, mode):
        return sanitizer_build_flags(mode)

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
                "sdk": fingerprint({"version": self.output(["xcrun", "--sdk", "macosx", "--show-sdk-version"]),
                                    "path": self.output(["xcrun", "--sdk", "macosx", "--show-sdk-path"])}),
                "host": self.host(), "os": fingerprint({"release": os.uname().release,
                                                         "version": os.uname().version}),
                "architecture": platform.machine(), "image_sha256": legacy.digest(image),
                "image_uuid": fingerprint(uuids["uuids"]),
                "environment": legacy.runtime_identity(environment), "flags": flags,
                "phase_environment": legacy.runtime_identity(self.execution_environment()),
                "policy": POLICY, "opt_in_policy": legacy.opt_in_policy(workspace, environment)}


LOCAL_POLICY_ENV = "ELITE_RECOVERABLE_LOCAL_POLICY_SHA256"
VM_DIAGNOSTIC_ENV = "ELITE_RECOVERABLE_DIAGNOSTIC_KIND"
VM_DIAGNOSTIC_KIND = "owned-vmmap-summary-v1"
VM_SESSION_KIND = "local-vmmap-diagnostic-session-v1"
LOCAL_SESSION_FIELDS = {"schema", "kind", "id", "head", "policy_sha256", "mode", "worker", "stage", "shards",
                        "expires_at", "plan_sha256", "max_launches"}



def validate_vmmap_policy(config):
    value = config.get("vmmap_diagnostic")
    if "vmmap_diagnostic" not in config:
        return None
    require_fields(value, ("kind", "tool", "argv", "target_binding", "trigger_worker_rss_bytes", "max_captures",
                           "capture_seconds", "cleanup_seconds", "output_limit_bytes", "accounting",
                           "cohort_count", "cohort_methods_sha256", "game_test_inputs_sha256", "deployment"))
    require_fields(value["tool"], ("path", "sha256"))
    require_fields(value["deployment"], ("path", "sha256"))
    if (value["kind"] != VM_DIAGNOSTIC_KIND or value["tool"]["path"] != "/usr/bin/vmmap"
            or value["argv"] != ["/usr/bin/vmmap", "-summary", "-w", "{helper_pid}"]
            or value["target_binding"] != "single-owned-prepared-image-v1"
            or value["accounting"] != "controller-worker-vmmap-support-union-v1"
            or any(type(value[key]) is not int or value[key] != expected for key, expected in (
                ("trigger_worker_rss_bytes", 1879048192), ("max_captures", 1), ("capture_seconds", 10),
                ("cleanup_seconds", 2), ("output_limit_bytes", 4 * 1024 * 1024), ("cohort_count", 16)))
            or any(not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) for digest in (
                value["tool"]["sha256"], value["deployment"]["sha256"], value["cohort_methods_sha256"],
                value["game_test_inputs_sha256"]))
            or not Path(value["deployment"]["path"]).is_absolute()
            or type(config["admission"]["peak_per_worker"]) is not int
            or type(config["admission"]["ram_reserve"]) is not int
            or config["admission"]["peak_per_worker"] != 2415919104
            or config["admission"]["ram_reserve"] != 2147483648):
        raise ValueError("Unknown or weakened vmmap diagnostic contract")
    return value


def validate_vmmap_deployment(authority, runtime):
    """Actual installed bytes and an independently approved closed launch surface are mandatory."""
    descriptor = authority.config["vmmap_diagnostic"]["deployment"]
    value = native_runner._custody_json(Path(descriptor["path"]), immutable=True)
    if legacy.digest(Path(descriptor["path"])) != descriptor["sha256"]:
        raise ValueError("Guard deployment proof changed")
    require_fields(value, ("schema", "kind", "head", "entries", "supported_jobs", "controller_needing_jobs",
                           "old_paths_quiesced", "review"))
    if (value["schema"] != 1 or value["kind"] != "reviewed-diagnostic-launch-surface-v1"
            or value["head"] != authority.policy["approved_head"]
            or value["supported_jobs"] != sorted(native_runner.RECOVERABLE_JOBS)
            or value["controller_needing_jobs"] != [] or value["old_paths_quiesced"] is not True):
        raise ValueError("Unreviewed, old or controller-needing listener matrix is ineligible")
    names = {"controller": "recoverable_shards.py", "guard": "native_runner.py",
             "legacy": "sanitizer_checkpoints.py", "quality": "quality_phase_checkpoints.py",
             "provisioner": "prepare_native_runner.py"}
    roles = set()
    for entry in value["entries"]:
        require_fields(entry, ("role", "path", "sha256"))
        role, path = entry["role"], Path(entry["path"])
        if role in roles or not path.is_absolute() or path != path.resolve() or path.is_symlink():
            raise ValueError("Duplicate or nonphysical guard deployment")
        roles.add(role)
        native_runner.require_owned_activation_file(path)
        if legacy.digest(path) != entry["sha256"]:
            raise ValueError("Configured entrypoint bytes changed")
        prefix, _, component = role.partition("-")
        if prefix not in ("source", "installed") or component not in {*names, "hook"}:
            raise ValueError("Unknown deployed entrypoint role")
        if component != "hook":
            source = authority.root / "Tools/CI" / names[component]
            if entry["sha256"] != legacy.digest(source) or (prefix == "source" and path != source):
                raise ValueError("Old copied controller/guard remains configured")
    required = {"source-" + name for name in names} | {
        "installed-guard", "installed-controller", "installed-legacy", "installed-quality", "installed-hook"}
    if not required <= roles:
        raise ValueError("Shared admission deployment coverage is incomplete")
    review = value["review"]
    require_fields(review, ("path", "sha256"))
    approved = native_runner._custody_json(Path(review["path"]), immutable=True)
    if (legacy.digest(Path(review["path"])) != review["sha256"] or approved != {
            "schema": 1, "kind": "diagnostic-launch-surface-review-v1", "head": value["head"],
            "entries_sha256": fingerprint(value["entries"]), "matrix_sha256": fingerprint(value["supported_jobs"]),
            "old_paths_quiesced": True}):
        raise ValueError("Missing independent launch-surface review")
    inputs = {name: digest for name, digest in runtime["inputs"].items() if name.startswith(("Sources/", "Tests/"))}
    if fingerprint(inputs) != authority.config["vmmap_diagnostic"]["game_test_inputs_sha256"]:
        raise ValueError("The approved game/test bytes changed")


class _VmmapCapability:
    """One consumed attempt, minted only inside the three real acquisition contexts."""
    def __init__(self, authority, attempt, controller, leases, deadline, clock):
        if (not isinstance(authority, LocalAuthority) or authority.session["kind"] != VM_SESSION_KIND
                or authority.session["stage"] != "execute" or authority.session["max_launches"] != 1):
            raise ValueError("No diagnostic attempt capability")
        if (len(leases) != 3 or any(not isinstance(lease, native_runner._DiagnosticLease) for lease in leases)
                or {lease.role for lease in leases} != {"controller", "executor", "reservation"}):
            raise ValueError("All three witnessed lease lifetimes are required")
        self.authority, self.attempt, self.leases = authority, attempt, tuple(leases)
        self.controller = dict(controller)
        self.deadline, self.clock, self.phase = deadline, clock, "timed"
        self.nonce, self.active_sha = str(uuid.uuid4()), None
        self.head, self.policy, self.session = authority.policy["approved_head"], authority.policy_sha256, authority.session_digest
        self.source = authority.root / "Tools/CI/recoverable_shards.py"
        self.source_sha = legacy.digest(self.source)
        self.lease_bindings = tuple((lease.role, lease.fd, lease.identity.st_dev, lease.identity.st_ino) for lease in leases)
        self.check_static()

    def check_static(self):
        if self.phase != "timed" or self.clock() >= self.deadline:
            raise ValueError("Diagnostic capability expired or entered custody-only phase")
        if (os.getpid() != self.controller["pid"] or str(Path(sys.executable).resolve()) != self.controller["image"]
                or legacy.digest(Path(self.controller["image"])) != self.controller["image_sha256"]
                or legacy.digest(self.source) != self.source_sha or self.source_sha != self.controller["source_sha256"]
                or self.authority.policy["approved_head"] != self.head
                or self.authority.policy_sha256 != self.policy or self.authority.session_digest != self.session):
            raise ValueError("Controller PID/image/source/session capability drift")
        for lease, binding in zip(self.leases, self.lease_bindings):
            if (lease.role, lease.fd, lease.identity.st_dev, lease.identity.st_ino) != binding:
                raise ValueError("Lease capability binding changed")
            lease.verify()
        self.authority.check_session("execute")
        if self.authority.budget_state()[1]["used"] != 1:
            raise ValueError("Capability cannot consume or replace a launch allowance")
        if self.clock() >= self.deadline:
            raise ValueError("Capability validation exhausted the original deadline")

    def require_current(self):
        self.check_static()
        registry = native_runner.diagnostic_custody_registry()
        record = registry["records"].get(self.nonce)
        if (record is None or record["state"] != "ACTIVE" or record["phase"] != "timed"
                or record["attempt"] != str(self.attempt) or record["controller"] != self.controller
                or native_runner.custody_digest(record) != self.active_sha):
            raise ValueError("Wrong/stale attempt, nonce or ACTIVE digest")
        return registry

    def publish(self, record):
        if self.active_sha is None:
            self.check_static()
            native_runner.require_diagnostic_custody_clear()
            registry = native_runner.diagnostic_custody_registry()
            if self.nonce in registry["records"]:
                raise ValueError("Duplicate diagnostic attempt nonce")
        else:
            registry = self.require_current()
        registry["records"][self.nonce] = record
        registry["generation"] += 1
        if len(json.dumps(registry, indent=2, allow_nan=False).encode()) + 1 > 900000:
            raise ValueError("Shared custody registry capacity reached")
        durable_json(native_runner.diagnostic_custody_root() / "registry.json", registry)
        self.active_sha = native_runner.custody_digest(record)

    def unknown(self, record):
        # Safety persistence is not reentry/admission and must still work at the deadline.
        registry = native_runner.diagnostic_custody_registry()
        prior = registry["records"].get(self.nonce)
        if prior is None or native_runner.custody_digest(prior) != self.active_sha:
            raise ValueError("Custody record changed before UNKNOWN persistence")
        record.update(state="UNKNOWN", phase="custody-only", terminal=None)
        registry["records"][self.nonce] = record
        registry["generation"] += 1
        durable_json(native_runner.diagnostic_custody_root() / "registry.json", registry)
        self.active_sha, self.phase = native_runner.custody_digest(record), "custody-only"


def diagnostic_cleanup_proved(attempt):
    try:
        records = [record for record in native_runner.diagnostic_custody_registry()["records"].values()
                   if record["attempt"] == str(attempt)]
        return (len(records) == 1 and (records[0]["state"] == "CLEAN"
                                      or native_runner.diagnostic_resolution(records[0])))
    except (ValueError, OSError, KeyError, TypeError):
        return False


def validate_vmmap_evidence(attempt, identity):
    """A capture receipt is never a quality receipt, even when both commands exit zero."""
    value = load_json(attempt / "diagnostic.json")
    authorization = load_json(attempt / "authorization.json")
    record = native_runner.diagnostic_custody_registry()["records"][value["custody_nonce"]]
    if (record["attempt"] != str(attempt) or record["source_head"] != authorization.get("head")
            or record["policy_sha256"] != authorization.get("policy_sha256")
            or record["policy_sha256"] != authorization["session"].get("policy_sha256")
            or VM_DIAGNOSTIC_ENV not in identity["runtime"]["environment"]
            or authorization["session"]["kind"] != VM_SESSION_KIND
            or value.get("kind") != VM_DIAGNOSTIC_KIND or value.get("ordinary_pass") is not False
            or value.get("residency") != "UNAVAILABLE" or value.get("format") != "UNQUALIFIED"
            or not diagnostic_cleanup_proved(attempt)):
        raise ValueError("Incomplete or mismatched diagnostic evidence; not ordinary PASS")
    if (attempt / "result.json").exists() or (attempt / "commit.json").exists():
        raise ValueError("Diagnostic cannot carry an ordinary success receipt")
    for name in ("vmmap.stdout", "vmmap.stderr"):
        if name in value.get("outputs", {}):
            path = attempt / name
            if path.is_symlink() or path.stat().st_mode & 0o777 != 0o600 or legacy.digest(path) != value["outputs"][name]:
                raise ValueError("Diagnostic raw output changed")
    return {"id": fingerprint(identity), "attempt": str(attempt), "diagnostic_only": True,
            "ordinary_pass": False, "status": value["status"], "residency": "UNAVAILABLE"}

def local_control(path):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve():
        raise ValueError("Local control must be an absolute physical path")
    native_runner.require_owned_activation_file(path)
    if path.stat().st_mode & 0o777 != 0o400:
        raise ValueError("Local control must be immutable and owned")
    return load_json(path)


def validate_local_session(session):
    diagnostic = isinstance(session, dict) and session.get("kind") == VM_SESSION_KIND
    require_fields(session, LOCAL_SESSION_FIELDS | ({"diagnostic_sha256"} if diagnostic else set()))
    if (type(session["schema"]) is not int or session["schema"] != SCHEMA
            or session["kind"] not in ("local-sanitizer-session-v1", VM_SESSION_KIND)
            or not isinstance(session["id"], str)
            or str(uuid.UUID(session["id"])) != session["id"]
            or not re.fullmatch(r"[0-9a-f]{40}", session["head"])
            or not re.fullmatch(r"[0-9a-f]{64}", session["policy_sha256"])
            or session["mode"] not in MODES or session["worker"] != "one"
            or session["stage"] not in ("prepare", "execute", "validate")
            or type(session["max_launches"]) is not int
            or not 0 <= session["max_launches"] <= 256):
        raise ValueError("Invalid local sanitizer session")
    if diagnostic and (session["mode"] != "address" or session["stage"] == "validate"
            or session["max_launches"] != 1
            or not re.fullmatch(r"[0-9a-f]{64}", session["diagnostic_sha256"])
            or (session["stage"] == "execute" and len(session["shards"] or []) != 1)):
        raise ValueError("Diagnostic sessions authorize one exact nonpromotable attempt")
    positive(session["expires_at"])
    if session["stage"] == "prepare":
        if session["plan_sha256"] is not None or session["max_launches"] != 1 or session["shards"] is not None:
            raise ValueError("Local preparation requires one bounded unplanned session")
    elif (not re.fullmatch(r"[0-9a-f]{64}", session["plan_sha256"] or "")
          or (session["stage"] == "execute" and session["max_launches"] < 1)
          or (session["stage"] == "validate" and session["max_launches"] != 0)):
        raise ValueError("Local execution/validation requires its exact plan and launch budget")
    if session["stage"] == "execute":
        if (not isinstance(session["shards"], list) or not 1 <= len(session["shards"]) <= 256
                or any(not isinstance(shard, str) or not re.fullmatch(r"[0-9a-f]{64}", shard) for shard in session["shards"])
                or len(set(session["shards"])) != len(session["shards"])):
            raise ValueError("Local execution requires an exact unique shard assignment")
    elif session["shards"] is not None:
        raise ValueError("Preparation/validation cannot carry a partial shard assignment")


def validate_local_authorization(record, runtime):
    require_fields(record, ("schema", "kind", "head", "host", "mode", "workspace", "policy_sha256",
                            "execution_policy_sha256", "authorized_at", "session", "session_content_sha256"))
    session = record["session"]
    if session.get("kind") == VM_SESSION_KIND or VM_DIAGNOSTIC_ENV in runtime["environment"]:
        raise ValueError("Diagnostic authorization cannot qualify ordinary evidence")
    validate_local_session(session)
    positive(record["authorized_at"])
    if any(not re.fullmatch(r"[0-9a-f]{64}", record[name] or "")
           for name in ("policy_sha256", "execution_policy_sha256", "session_content_sha256")):
        raise ValueError("Local authorization hashes are incomplete")
    if (type(record["schema"]) is not int or record["schema"] != SCHEMA
            or record["kind"] != "validated-local-sanitizer-v1"
            or record["host"] != runtime["host"] or record["mode"] != runtime["mode"]
            or session["mode"] != record["mode"] or session["head"] != record["head"]
            or session["stage"] != "execute" or session["policy_sha256"] != record["policy_sha256"]
            or fingerprint(session) != record["session_content_sha256"]
            or hashlib.sha256(record["policy_sha256"].encode()).hexdigest() != runtime["environment"].get(LOCAL_POLICY_ENV)
            or hashlib.sha256(record["execution_policy_sha256"].encode()).hexdigest() != runtime["environment"].get(
                "ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256")
            or not Path(record["workspace"]).is_absolute()
            or not 0 < record["authorized_at"] < session["expires_at"]):
        raise ValueError("Local authorization differs from the actual source/mode/profile")


def local_environment(environment=None):
    value = dict(os.environ if environment is None else environment)
    if any(name.startswith(("GITHUB_", "RUNNER_")) or name in AUTHORIZATION_CONTROLS
           or name in ("ELITE_NATIVE_POLICY", "ELITE_NATIVE_APPROVED_HEAD", VM_DIAGNOSTIC_ENV, LOCAL_POLICY_ENV,
                       "ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256") for name in value):
        raise ValueError("Local sanitizer execution refuses GitHub or supplied authorization identities")
    return value


class LocalAuthority(NativeAuthority):
    """A genuine local, finite sanitizer approval; never a simulated Actions job."""
    def __init__(self, policy_path, session_path, session_digest, mode, stage, environment=None, read=native_output,
                 control_descriptors=()):
        import pwd
        require_physical_activation()  # Before control-file reads or any native/resource probe.
        native_runner.require_diagnostic_custody_clear()
        self.environment = local_environment(environment)
        self.control_descriptors = tuple(control_descriptors)
        self.read, self.policy_path, self.session_path = read, Path(policy_path), Path(session_path)
        self.policy = local_control(self.policy_path)
        require_fields(self.policy, ("approved_head", "developer_dir", "swift", "sdk", "recoverable_shards", "local_activation"))
        self.policy_sha256, self.session_digest = legacy.digest(self.policy_path), session_digest
        self.activation = self.policy["local_activation"]
        require_fields(self.activation, ("schema", "kind", "mode", "workspace", "sources", "expires_at",
                                        "inventory_sha256", "inventory_count", "shard_count", "environment"))
        current = time.time()
        if (type(self.activation["schema"]) is not int or self.activation["schema"] != SCHEMA
                or self.activation["kind"] != "local-sanitizer-activation-v1"
                or mode not in MODES or self.activation["mode"] != mode
                or not re.fullmatch(r"[0-9a-f]{40}", self.policy["approved_head"])
                or not re.fullmatch(r"[0-9a-f]{64}", self.activation["inventory_sha256"])
                or type(self.activation["inventory_count"]) is not int or self.activation["inventory_count"] < 1
                or type(self.activation["shard_count"]) is not int or not 1 <= self.activation["shard_count"] <= 256
                or type(self.activation["expires_at"]) not in (int, float)
                or not current < self.activation["expires_at"] <= current + 7*86400):
            raise ValueError("Local mode/source/inventory/finite activation differs")
        if (self.activation["environment"] != legacy.runtime_identity(runtime_child_environment(self.environment))
                or (mode == "thread" and "ASAN_OPTIONS" in self.environment)
                or (mode == "address" and "TSAN_OPTIONS" in self.environment)):
            raise ValueError("Local mode environment differs from its independently reviewed profile")
        self.root = Path(self.activation["workspace"])
        if (not self.root.is_absolute() or self.root != self.root.resolve()
                or Path(__file__).resolve() != self.root / "Tools/CI/recoverable_shards.py"):
            raise ValueError("Local controller must execute its exact reviewed physical source")
        self.config = self.policy["recoverable_shards"]
        self.vmmap_policy = validate_vmmap_policy(self.config)
        self.physical_home = Path(pwd.getpwuid(os.getuid()).pw_dir)
        if self.config.get("legacy_cache") != str(self.physical_home / "Library/EliteNativeCI/sanitizer-checkpoints"):
            raise ValueError("Local modes must share the existing physical executor lease")
        if (set(self.config.get("workers", {})) != {"one"}
                or self.config.get("admission", {}).get("explicit") != 1
                or self.config.get("admission", {}).get("cpu_budget") != 1):
            raise ValueError("Local sanitizers reserve exactly one serial worker")
        bounds = self.config["admission"]
        require_fields(bounds, ("explicit", "cpu_budget", "ram_capacity", "ram_reserve", "peak_per_worker",
                                "disk_capacity", "disk_reserve", "disk_per_worker"))
        worker_limit(**bounds, ram_available=bounds["ram_capacity"], disk_available=bounds["disk_capacity"])
        spaces = [self.root, *(Path(self.config[k]) for k in ("cache", "legacy_cache")),
                  *(Path(p) for p in self.config["workers"].values())]
        if any(control.is_relative_to(space) or space.is_relative_to(control.parent)
               for control in (self.policy_path, self.session_path) for space in spaces):
            raise ValueError("Local controls overlap mutable execution data")
        helpers = {"native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                   "quality_phase_checkpoints.py", "crash_artifacts.py"}
        if set(self.activation["sources"]) != helpers:
            raise ValueError("Local approval requires all five source pins")
        for name, digest in self.activation["sources"].items():
            source = self.root / "Tools/CI" / name
            native_runner.require_owned_activation_file(source)
            if source.is_symlink() or legacy.digest(source) != digest:
                raise ValueError("Local approved helper source changed")
        self.check_session(stage)
        self.budget_state()  # A missing counter cannot silently create a fresh launch allowance.
        if (platform.system() != "Darwin" or platform.machine() != "arm64"
                or self.environment.get("DEVELOPER_DIR") != self.policy["developer_dir"]):
            raise ValueError("Local sanitizers require the reviewed physical Apple Silicon toolchain")
        if self.output(["sysctl", "-n", "hw.model"]).startswith("VirtualMac"):
            raise ValueError("Local sanitizers cannot execute on a VM")
        self.host()
        swift = shutil.which("swift", path=self.environment.get("PATH"))
        if (not swift or self.output([swift, "--version"]) != self.policy["swift"]
                or self.output(["xcrun", "--sdk", "macosx", "--show-sdk-version"]) != self.policy["sdk"]):
            raise ValueError("Local compiler/SDK differs from the reviewed profile")
        self.configure_storage()

    def check_session(self, stage=None):
        local_control(self.policy_path)
        session = local_control(self.session_path)
        validate_local_session(session)
        if (not re.fullmatch(r"[0-9a-f]{64}", self.session_digest or "")
                or legacy.digest(self.session_path) != self.session_digest
                or legacy.digest(self.policy_path) != self.policy_sha256
                or session["policy_sha256"] != self.policy_sha256
                or session["head"] != self.policy["approved_head"] or session["mode"] != self.activation["mode"]
                or (stage is not None and session["stage"] != stage)
                or not time.time() < session["expires_at"] <= self.activation["expires_at"]):
            raise ValueError("Local source/mode/policy/session stage or expiry changed")
        self.session = session
        if (bool(self.config.get("vmmap_diagnostic")) != (session["kind"] == VM_SESSION_KIND)
                or (session["kind"] == VM_SESSION_KIND
                    and session["diagnostic_sha256"] != fingerprint(self.config["vmmap_diagnostic"]))):
            raise ValueError("Policy/session diagnostic binding differs")
        return session

    def budget_state(self):
        path = self.session_path.with_name(self.session_path.name + ".state.json")
        native_runner.require_owned_activation_file(path)
        if path.stat().st_mode & 0o777 != 0o600:
            raise ValueError("Local session budget must be an owned mutable file")
        state = load_json(path)
        require_fields(state, ("schema", "session_sha256", "used"))
        if (type(state["schema"]) is not int or state["schema"] != SCHEMA
                or state["session_sha256"] != self.session_digest or type(state["used"]) is not int
                or not 0 <= state["used"] <= self.session["max_launches"]):
            raise ValueError("Local session launch budget changed")
        return path, state

    def consume_launch(self):
        with claim(self.session_path.parent / "claims", "local-session:" + self.session_digest):
            self.check_session()
            path, state = self.budget_state()
            if state["used"] >= self.session["max_launches"]:
                raise ValueError("Local session launch budget exhausted")
            durable_json(path, {**state, "used": state["used"] + 1})

    def execution_environment(self):
        value = super().execution_environment()
        value[LOCAL_POLICY_ENV] = self.policy_sha256
        if self.config.get("vmmap_diagnostic") is not None:
            value[VM_DIAGNOSTIC_ENV] = VM_DIAGNOSTIC_KIND
        return value

    def build_flags(self, mode):
        if mode != self.activation["mode"]:
            raise ValueError("Local build mode differs from its reviewed profile")
        return local_sanitizer_flags(mode)

    def output(self, command, workspace=None, environment=None, descriptors=()):
        return super().output(command, workspace, environment,
                              (*descriptors, *getattr(self, "control_descriptors", ())))

    def authorization(self):
        self.check_session()
        return {"schema": SCHEMA, "kind": "validated-local-sanitizer-v1", "head": self.policy["approved_head"],
                "host": self.config["host"], "mode": self.activation["mode"], "workspace": str(self.root),
                "policy_sha256": self.policy_sha256, "execution_policy_sha256": execution_policy_digest(self.config),
                "authorized_at": time.time(), "session": self.session,
                "session_content_sha256": fingerprint(self.session)}

    def runtime(self, workspace, mode, image, flags, inputs=None):
        self.check_session()
        if mode != self.activation["mode"] or flags != self.build_flags(mode):
            raise ValueError("Local runtime mode/flags differ from its independently reviewed profile")
        return super().runtime(workspace, mode, image, flags, inputs)

    def admission(self):
        self.check_session()
        return super().admission()


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


def build_entries(root, read_only=False):
    """Hash complete SwiftPM layout, including confined relative links and executable bits."""
    if read_only:
        owned_bridge_path(root)
        if not root.is_dir():
            raise ValueError("Original frozen scratch is missing")
    else:
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


def sanitizer_build_flags(mode):
    """Keep ASAN compilation to one build job without combining frontend batches."""
    flags = ["--scratch-path", ".build/tsan" if mode == "thread" else ".build/asan", "--sanitize=" + mode]
    if mode == "address":
        flags += ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
    return flags


def local_sanitizer_flags(mode):
    flags = sanitizer_build_flags(mode)
    if mode == "thread":
        flags += ["--jobs", "1", "-Xswiftc", "-disable-batch-mode"]
    return flags


def frozen_build_content(build, destination):
    """Check original immutable build bytes without constructing another authority/runtime."""
    validate_runtime(build["runtime"])
    require_sealed(destination)
    if (load_json(destination / "build-commit.json") != {"sha256": legacy.digest(destination / "build.json")}
            or build_entries(destination / "scratch", read_only=True) != build["scratch"]):
        raise ValueError("Original frozen build manifest/layout changed")
    runtime, scratch = build["runtime"], Path(build["runtime"]["flags"][1])
    relative = Path(build["image_relative"])
    if relative.is_absolute() or ".." in relative.parts or not relative.is_relative_to(scratch):
        raise ValueError("Original frozen image escaped its scratch")
    image = destination / "scratch" / relative.relative_to(scratch)
    if image != image.resolve() or image.is_symlink() or legacy.digest(image) != runtime["image_sha256"]:
        raise ValueError("Original frozen image bytes changed")
    for name, digest in runtime["inputs"].items():
        if name.startswith(".build/") and legacy.digest(destination / "scratch" / Path(name).relative_to(scratch)) != digest:
            raise ValueError("Original frozen dependency input changed")
    return image


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
    def preparation_claim(self, phase=None):
        with file_claim(self.authority.legacy_cache / "executor.lock") as lock, claim(
                self.authority.cache / "claims", "preparation"):
            self.lock = lock
            try:
                # Legacy workers cannot overlap this build, even after a future activation.
                legacy.ensure_no_live_tests()
                if any("swiftpm-testing-helper" in row["command"]
                       or any(name in row["command"] for name in (".xctest/Contents/MacOS/Elite", ".xctest/Contents/MacOS/L337"))
                       for row in self.authority.snapshot().values()):
                    raise ValueError("A live test helper blocks exclusive preparation")
                self.authority.admission() if phase is None else self.authority.admission(phase=phase)
                yield lock
            finally:
                self.lock = None

    def build_only(self, mode, timeout):
        """A separate GitHub step records an owned build checkpoint before discovery."""
        if timeout > SHARD_MAX_SECONDS:
            raise ValueError("Preparation exceeds the reviewed two-hour bound")
        destination = self.authority.cache / "build-stage" / self.authority.policy["approved_head"] / mode
        flags = self.authority.build_flags(mode)
        with self.preparation_claim():
            if destination.exists():
                ready = load_json(destination / "ready.json")
                image = self.authority.root / ready["image_relative"]
                if (ready["head"] != self.authority.policy["approved_head"] or ready["runtime"] != self.authority.runtime(
                        self.authority.root, mode, image, flags)):
                    raise ValueError("Prepared controller build changed before discovery")
                return {"reused": True, "stage": str(destination)}
            root, env = self.authority.root, self.authority.environment_for(mode)
            swift = shutil.which("swift", path=env.get("PATH"))
            if swift is None:
                raise ValueError("Approved Swift compiler is unavailable")
            report = self.authority.cache / "preparation" / str(uuid.uuid4())
            legacy.owned_directory(report)
            inputs = legacy.executable_inputs(root, flags[1])
            command = [swift, "build", "--build-tests", *flags]
            durable_json(report / "launch.json", {"head": self.authority.policy["approved_head"], "mode": mode,
                                                  "command": command, "authorization": self.authority.authorization()})
            code = execute_process(command, root, report, timeout,
                                   [self.lock.fileno(), *getattr(self.authority, "control_descriptors", ())], env,
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
        flags = self.authority.build_flags(mode)
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
                                   [self.lock.fileno(), *getattr(self.authority, "control_descriptors", ())], env,
                                   NativeMonitor(self.authority, report, root),
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



class _VmmapOwners:
    """Explicit child roots plus verified descendants; names never grant ownership."""
    def __init__(self, controller):
        self.known = {controller["pid"]: dict(controller)}
        self.pending, self.children = {}, {}
        self.ambiguous = False

    def spawned(self, child):
        if child.pid in self.known or child.pid in self.pending:
            self.ambiguous = True
            raise ValueError("Owned PID reused before identity registration")
        self.pending[child.pid] = child
        self.children[child.pid] = child

    def observe(self, rows):
        selected = {}
        for pid, known in self.known.items():
            row = rows.get(pid)
            if row is not None:
                if not same_process(known, row):
                    self.ambiguous = True
                    raise ValueError("Owned PID/start/command drift")
                selected[pid] = {**row, "role": known["role"]}
        controller = next(pid for pid, row in self.known.items() if row["role"] == "controller")
        if controller not in selected:
            raise ValueError("Controller custody disappeared")
        for pid, child in list(self.pending.items()):
            row = rows.get(pid)
            if row is None:
                if child.code is not None:
                    del self.pending[pid]
                    continue
                self.ambiguous = True
                raise ValueError("Spawned child has no verified identity")
            if row["parent"] != controller or row["group"] != pid:
                self.ambiguous = True
                raise ValueError("Spawned child is outside its owned session")
            if child.role != "worker" and arguments(row) != child.argv:
                self.ambiguous = True
                raise ValueError("Spawned utility/support argv changed")
            selected[pid] = {**row, "role": child.role}
            del self.pending[pid]
        while True:
            added = False
            for pid, row in rows.items():
                if pid in selected:
                    continue
                parent = selected.get(row["parent"])
                if parent is None:
                    continue
                if parent["role"] == "controller":
                    self.ambiguous = True
                    raise ValueError("Unregistered direct controller child")
                if pid in self.known and not same_process(self.known[pid], row):
                    self.ambiguous = True
                    raise ValueError("Descendant PID reused")
                selected[pid] = {**row, "role": parent["role"]}
                added = True
            if not added:
                break
        groups = set(self.children)  # A reaped root does not release unseen members of its original session.
        if any(pid not in selected and row["group"] in groups for pid, row in rows.items()):
            self.ambiguous = True
            raise ValueError("Unverifiable/reparented unregistered session member")
        for pid, row in selected.items():
            self.known[pid] = {key: row[key] for key in ("parent", "group", "start", "command", "role")}
            self.known[pid]["pid"] = pid
        if any(type(row.get("rss_bytes")) is not int or row["rss_bytes"] < 0 for row in selected.values()):
            raise ValueError("Incomplete diagnostic resident sample")
        roles = {role: sum(row["rss_bytes"] for row in selected.values() if row["role"] == role)
                 for role in ("controller", "worker", "vmmap", "support")}
        return selected, roles, sum(row["rss_bytes"] for row in selected.values())

    def active(self, live):
        return {pid: row for pid, row in live.items() if row["role"] != "controller"
                and not (pid in self.children and self.children[pid].code is not None)}


class _VmmapChild:
    """Two fair bounded pipe reads per tick; no communicate/wait or unbounded buffer."""
    def __init__(self, role, argv, workspace, environment, descriptors, output, limit):
        self.role, self.argv, self.output, self.limit = role, list(argv), output, limit
        self.total, self.buffers, self.streams = 0, {}, {}
        self.pty, self.code, self.closed = None, None, False
        self.clock, self.deadline = time.monotonic, float("inf")
        if role == "worker":
            master, slave = os.openpty()
            tty.setraw(slave)
            try:
                self.process = subprocess.Popen(argv, cwd=workspace, env=environment, stdout=slave,
                    stderr=subprocess.STDOUT, pass_fds=tuple(descriptors), start_new_session=True, umask=0o077)
            except BaseException:
                os.close(master)
                raise
            finally:
                os.close(slave)
            self.streams["stdout"] = master
            self.pty = master
        else:
            self.process = subprocess.Popen(argv, cwd=workspace, env=environment, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, pass_fds=tuple(descriptors), start_new_session=True, umask=0o077)
            self.streams = {"stdout": self.process.stdout.fileno(), "stderr": self.process.stderr.fileno()}
        self.pid = self.process.pid
        for fd in self.streams.values():
            os.set_blocking(fd, False)
        self.open_streams = set(self.streams)
        self.buffers = {name: bytearray() for name in self.streams}

    def poll(self):
        if self.code is None and self.clock() < self.deadline:
            self.code = self.process.poll()  # WNOHANG reaps only this direct child.
        return self.code

    def drain(self):
        if not self.open_streams or self.clock() >= self.deadline:
            return
        ready, _, _ = select.select([self.streams[key] for key in self.open_streams], [], [], 0)
        for name in list(self.open_streams):
            fd = self.streams[name]
            if fd not in ready or self.clock() >= self.deadline:
                continue
            try:
                data = os.read(fd, 16384)
            except BlockingIOError:
                continue
            except OSError as error:
                if self.role == "worker" and error.errno == errno.EIO:
                    data = b""
                else:
                    raise
            if not data:
                self.open_streams.remove(name)
                continue
            self.total += len(data)
            if self.limit is not None and self.total > self.limit:
                available = max(0, len(data) - (self.total - self.limit))
                if self.output is not None:
                    self.output[name].write(data[:available])
                    self.output[name].flush()
                raise ValueError("Diagnostic combined output cap")
            if self.output is None:
                self.buffers[name].extend(data)
            else:
                self.output[name].write(data)
                self.output[name].flush()

    def close(self):
        if self.closed:
            return
        self.closed = True
        if self.pty is not None:
            os.close(self.pty)
            self.pty = None
        else:
            self.process.stdout.close()
            self.process.stderr.close()


class VmmapDiagnostic:
    """One diagnostic attempt with inert same-controller custody on uncertain cleanup."""
    def __init__(self, authority, attempt, workspace, runtime, image, leases, owner,
                 clock=time.monotonic, sleep=time.sleep, spawn=_VmmapChild, send_signal=os.kill):
        self.authority, self.attempt, self.workspace = authority, attempt, workspace
        self.runtime, self.image, self.leases, self.owner = runtime, image, leases, owner
        self.clock, self.sleep, self.spawn, self.send_signal = clock, sleep, spawn, send_signal
        self.spec = validate_vmmap_policy(authority.config)
        self.cap, self.record = None, None
        self.children, self.live, self.rows = [], {}, {}
        self.worker = self.utility = self.sampler = None
        self.triggered, self.capture_complete, self.target = False, False, None
        self.cancelled, self.errors, self.events = False, [], []
        self.sample_due, self.bound_callback = 0, None
        self.last_sample_started, self.utility_finished = None, None
        self.outputs, self.handlers = {}, {}
        self.failed_output = set()
        self.memory = {"kind": "sampled-owned-diagnostic-rss-v1", "budget_bytes": 2415919104,
                       "worker_trigger_bytes": 1879048192, "poll_wait_seconds": 0.1, "samples": 0,
                       "high_water_bytes": 0, "last_bytes": None, "roles": None, "failure": None}

    def persist(self, critical=False):
        self.record["identities"] = [dict(self.owners.known[pid]) for pid in sorted(self.owners.known)]
        # Leave bounded space for UNKNOWN and doubled terminal identities before any new spawn.
        size = len(json.dumps(self.record, indent=2, allow_nan=False).encode()) + 1
        if size > (700000 if critical else 250000):
            raise ValueError("Diagnostic custody evidence capacity reached")
        self.cap.publish(self.record)
        durable_json(self.attempt / "processes.json", {"schema": SCHEMA, "workspace": str(self.workspace),
            "controller": self.owner, "root": None if self.worker is None else {"pid": self.worker.pid},
            "running": self.record["state"] == "ACTIVE", "diagnostic_only": True,
            "resident_memory": self.memory, "processes": {str(pid): row for pid, row in self.owners.known.items()}})

    def launch(self, role, argv, output=None, critical=False):
        self.cap.require_current()
        if self.clock() >= self.deadline - (0 if critical else 2):
            raise ValueError("No time remains for bounded capture and cleanup")
        intent = {"role": role, "argv": list(argv), "pid": None, "state": "planned"}
        self.record["intents"].append(intent)
        self.persist(critical)
        try:
            child = self.spawn(role, argv, self.workspace, self.environment, self.descriptors, output,
                               None if role == "worker" else self.spec["output_limit_bytes"])
        except OSError:
            # A constructor may fail after spawning. Keep its planned intent unresolved.
            self.persist(critical)
            raise
        intent.update(pid=child.pid, state="spawned")
        child.intent = intent
        child.clock, child.deadline = self.clock, self.deadline
        child.started_at = self.clock()
        self.children.append(child)
        self.owners.spawned(child)
        self.persist(critical)
        self.events.append({"event": "spawn", "role": role, "pid": child.pid, "argv": list(argv), "time": self.clock()})
        return child

    def drain(self, cleanup=False):
        for child in self.children:
            if self.clock() >= self.deadline:
                return
            if child.pid not in self.failed_output:
                try:
                    child.drain()
                except Exception as error:
                    if child.role == "support":
                        raise  # Failed identity acquisition cannot authorize cleanup signals.
                    self.failed_output.add(child.pid)
                    if not cleanup:
                        raise
                    self.errors.append("cleanup output: " + type(error).__name__ + ": " + str(error))
            # Failed output acquisition does not prevent nonblocking reap or fresh identity sampling.
            if child.poll() is not None:
                child.intent["state"] = "reaped"

    def sample(self, critical=False):
        now = self.clock()
        if now >= self.deadline:
            return False
        if self.sampler is None and now >= self.sample_due:
            self.sampler = self.launch("support", ["/bin/ps", "-axo", "pid=,ppid=,pgid=,stat=,lstart=,rss=,command="],
                                       critical=critical)
        if self.sampler is None or self.sampler.poll() is None or self.sampler.open_streams:
            return False
        sampler, self.sampler = self.sampler, None
        if sampler.poll() != 0 or sampler.buffers.get("stderr"):
            raise ValueError("Diagnostic identity/RSS snapshot failed")
        self.rows = process_rows(bytes(sampler.buffers["stdout"]).decode("utf-8", "strict"), resident=True)
        self.last_sample_started = sampler.started_at
        sampler.buffers.clear()
        sampler.close()
        self.live, roles, total = self.owners.observe(self.rows)
        self.memory.update(samples=self.memory["samples"] + 1, last_bytes=total, roles=roles,
                           high_water_bytes=max(self.memory["high_water_bytes"], total))
        self.record["last_verified"] = {"time": self.clock(), "worker_bytes": roles["worker"],
            "union_bytes": total, "roles": roles, "status": "last-verified"}
        self.sample_due = self.clock() + 0.1
        self.persist(critical)
        if total > self.memory["budget_bytes"]:
            self.memory["failure"] = "owned diagnostic union exceeds budget"
            if not critical:
                raise ValueError(self.memory["failure"])
        return True

    def tool_identity(self):
        path = Path(self.spec["tool"]["path"])
        info = path.lstat()
        if (path.is_symlink() or path != path.resolve() or not path.is_file() or info.st_uid != 0
                or info.st_mode & 0o777 != 0o755 or legacy.digest(path) != self.spec["tool"]["sha256"]):
            raise ValueError("Diagnostic utility identity drift")

    def target_identity(self, expected=None):
        launch = self.worker.argv if self.worker is not None else []
        flags = self.runtime["flags"]
        prefix = [launch[0], "test", *flags, "--skip-build", "--no-parallel",
                  "--xunit-output", str(self.attempt / "tests.xml"), "--filter"] if launch else []
        if (not launch or len(launch) != len(prefix) + 1 or launch[:-1] != prefix
                or any(not arg or any(character.isspace() for character in arg)
                       for arg in [*launch, str(self.image)])):
            raise ValueError("Unsupported diagnostic worker command/report shape")
        # SwiftPM forwards these exact options, moves filter before xunit, and names its own report.
        forwarded = [*flags, "--skip-build", "--no-parallel", "--filter", launch[-1],
                     "--xunit-output", str(self.attempt / "tests-swift-testing.xml")]
        candidates = []
        for pid, row in self.live.items():
            if row["role"] != "worker":
                continue
            executable, separator, _ = row["command"].partition(" ")
            command = " ".join([executable, "--test-bundle-path", str(self.image), *forwarded,
                                str(self.image), "--testing-library", "swift-testing"])
            # ps text is not shell-quoted: preserve regex backslashes instead of using shlex equivalence.
            if (separator and not any(character.isspace() for character in executable)
                    and Path(executable).is_absolute() and Path(executable).name == "swiftpm-testing-helper"
                    and row["command"] == command):
                candidates.append({"pid": pid, **{key: row[key] for key in ("parent", "group", "start", "command", "role")}})
        if len(candidates) != 1:
            raise ValueError("Missing/ambiguous verified prepared helper")
        target = candidates[0]
        if expected is not None and (target["pid"] != expected["pid"] or not same_process(expected, target)):
            raise ValueError("Diagnostic target PID/start drift")
        if self.image != self.image.resolve() or self.image.is_symlink():
            raise ValueError("Prepared target image is not physical")
        confined(self.image, self.workspace / ".build")
        if legacy.digest(self.image) != self.runtime["image_sha256"]:
            raise ValueError("Prepared target image changed")
        # Exact prepared bytes bind their already verified UUID; no unowned dwarfdump subprocess.
        target.update(image=str(self.image), image_sha256=self.runtime["image_sha256"],
                      image_uuid=self.runtime["image_uuid"])
        if self.bound_callback is not None:
            self.bound_callback()
            self.bound_callback = None
        return target

    def begin_capture(self):
        self.triggered = True  # No retry, including a failed binding/spawn.
        if self.clock() >= self.deadline - 2:
            raise ValueError("Capture cannot reserve cleanup within original deadline")
        self.target = self.target_identity()
        self.record["target"] = dict(self.target)
        self.tool_identity()
        for name in ("stdout", "stderr"):
            fd = os.open(self.attempt / ("vmmap." + name), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            self.outputs[name] = os.fdopen(fd, "wb")
        argv = ["/usr/bin/vmmap", "-summary", "-w", str(self.target["pid"])]
        self.capture_deadline = min(self.clock() + 10, self.deadline - 2)
        self.utility = self.launch("vmmap", argv, self.outputs)
        self.events.append({"event": "target-before", "identity": self.target, "time": self.clock()})

    def cleanup(self):
        """All observations/signals/reaps end at the original cohort deadline."""
        end = min(self.deadline, self.clock() + 2)
        term_end = min(end, self.clock() + 1)
        sent = set()
        while self.clock() < end:
            self.drain(cleanup=True)
            fresh = self.sample(critical=True)
            if fresh:
                active = self.owners.active(self.live)
                if (not active and not self.owners.pending
                        and all(child.poll() is not None for child in self.children)
                        and all(intent["state"] in ("reaped", "not-launched") for intent in self.record["intents"])):
                    return not self.owners.ambiguous
                signum = signal.SIGTERM if self.clock() < term_end else signal.SIGKILL
                for pid, row in active.items():
                    key = (pid, row["start"], signum)
                    if key in sent or self.clock() >= end:
                        continue
                    # Only a just-observed exact identity authorizes a signal, never a group/name.
                    self.cap.require_current()
                    if self.clock() >= end:
                        break
                    if not same_process(self.owners.known[pid], self.rows.get(pid)):
                        raise ValueError("Cleanup identity changed")
                    self.send_signal(pid, signum)
                    sent.add(key)
                    self.events.append({"event": "signal", "pid": pid, "signal": int(signum), "time": self.clock()})
            self.sleep(min(0.01, max(0, end - self.clock())))
        return False

    def custody_hold(self):
        self.record.update(state="UNKNOWN", phase="custody-only", terminal=None)
        try:
            self.cap.unknown(self.record)
        except BaseException as error:
            self.errors.append("UNKNOWN persistence: " + type(error).__name__)
            # ACTIVE/missing/malformed state still refuses subsequent admission.
            self.cap.phase = "custody-only"
        try:
            self.write_result("INCOMPLETE/UNKNOWN", None, post_deadline=True)
        except BaseException:
            # Failed evidence I/O cannot release live custody. The registry still blocks admission.
            pass
        while True:
            try:
                # Only immutable, exact reviewed operator files are read in this inert phase.
                current = native_runner.diagnostic_custody_registry()["records"].get(self.cap.nonce)
                if (current is not None and current["attempt"] == str(self.attempt)
                        and current["controller"] == self.cap.controller
                        and current["source_head"] == self.cap.head
                        and current["policy_sha256"] == self.cap.policy
                        and current["session_sha256"] == self.cap.session
                        and native_runner.diagnostic_resolution(current)):
                    return
            except BaseException:
                # SIGINT/SystemExit/exception is not permission to unwind live lease custody.
                pass
            # Every failed check waits too. An interrupted wait must finish before another read.
            while True:
                try:
                    self.sleep(0.1)
                    break
                except BaseException:
                    continue

    def write_result(self, status, code, post_deadline=False):
        outputs = {}
        for name, stream in self.outputs.items():
            stream.flush()
            outputs["vmmap." + name] = legacy.digest(self.attempt / ("vmmap." + name))
        durable_json(self.attempt / "diagnostic.json", {"schema": SCHEMA, "kind": VM_DIAGNOSTIC_KIND,
            "status": status, "ordinary_pass": False, "capture_complete": self.capture_complete,
            "residency": "UNAVAILABLE", "format": "UNQUALIFIED", "custody_nonce": self.cap.nonce,
            "worker_exit": code, "last_verified": self.record["last_verified"], "memory": self.memory,
            "post_deadline": {"rss": "UNKNOWN", "identity": "UNKNOWN"} if post_deadline else None,
            "target_before": self.target, "events": self.events, "errors": self.errors, "outputs": outputs})

    def execute(self, command, timeout, descriptors, environment, progress=None):
        validate_vmmap_deployment(self.authority, self.runtime)
        self.environment = child_environment(self.attempt, environment)
        self.descriptors = tuple(descriptors)
        self.deadline = self.clock() + timeout
        controller = {"pid": self.owner["pid"], "start": self.owner["start"], "command": self.owner["command"],
            "image": str(Path(sys.executable).resolve()), "image_sha256": self.owner["image_sha256"],
            "source_sha256": legacy.digest(self.authority.root / "Tools/CI/recoverable_shards.py")}
        self.cap = _VmmapCapability(self.authority, self.attempt, controller, self.leases, self.deadline, self.clock)
        seed = {"pid": controller["pid"], "parent": self.owner["parent"], "group": self.owner["group"],
                "start": controller["start"], "command": controller["command"], "role": "controller"}
        self.owners = _VmmapOwners(seed)
        self.record = {"nonce": self.cap.nonce, "attempt": str(self.attempt), "source_head": self.cap.head,
            "policy_sha256": self.cap.policy, "session_sha256": self.cap.session, "controller": controller,
            "identities": [seed], "state": "ACTIVE", "phase": "timed", "launches": 1, "deadline": self.deadline,
            "last_verified": None, "terminal": None, "intents": [], "target": None}
        self.persist()  # Durable ACTIVE precedes every diagnostic worker/support spawn.
        log, clean, code = None, False, None
        try:
            log = os.fdopen(os.open(self.attempt / "test.log", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600), "wb")
            for signum in (signal.SIGINT, signal.SIGTERM):
                self.handlers[signum] = signal.getsignal(signum)
                signal.signal(signum, lambda number, frame: setattr(self, "cancelled", True))
            self.worker = self.launch("worker", command, {"stdout": log})
            durable_json(self.attempt / "child.json", {"pid": self.worker.pid, "command": command})
            while self.clock() < self.deadline - 2:
                if self.cancelled:
                    raise ValueError("Diagnostic cancelled; bounded cleanup required")
                self.drain()
                fresh = self.sample()
                if fresh and not self.triggered and self.record["last_verified"]["worker_bytes"] >= 1879048192:
                    self.begin_capture()
                if self.utility is not None and not self.capture_complete:
                    if self.clock() >= self.capture_deadline:
                        raise ValueError("Diagnostic capture deadline")
                    if self.utility.poll() is not None and not self.utility.open_streams:
                        if (self.utility.poll() != 0 or self.utility.total == 0
                                or (self.attempt / "vmmap.stdout").stat().st_size == 0):
                            raise ValueError("Diagnostic capture/permission/output failure")
                        if self.utility_finished is None:
                            self.utility_finished = self.clock()
                        if not fresh or self.last_sample_started < self.utility_finished:
                            self.sample_due = 0
                        else:
                            after = self.target_identity(self.target)
                            self.tool_identity()
                            (self.attempt / "vmmap.stdout").read_bytes().decode("utf-8", "strict")
                            self.capture_complete = True
                            self.events.append({"event": "target-after", "identity": after, "time": self.clock()})
                if self.worker.poll() is not None:
                    code = self.worker.poll()
                    if not self.capture_complete:
                        raise ValueError("Cohort ended without a complete verified capture")
                    break
                self.sleep(0.01)
        except BaseException as error:
            self.errors.append(type(error).__name__ + ": " + str(error))
        # One cleanup budget only, including after capture, cancellation or sampling failure.
        try:
            if self.clock() < self.deadline:
                clean = self.cleanup()
        except BaseException as cleanup_error:
            self.errors.append("cleanup: " + type(cleanup_error).__name__)
        if clean:
            try:
                self.cap.require_current()
                self.record.update(state="CLEAN", phase="terminal", terminal={
                    "absent": [dict(self.owners.known[pid]) for pid in sorted(self.owners.known)
                               if self.owners.known[pid]["role"] != "controller"],
                    "reaped": all(child.code is not None for child in self.children), "time": self.clock()})
                self.persist(critical=True)
                self.cap.phase = "terminal"
            except BaseException as error:
                clean = False
                self.errors.append("terminal persistence: " + type(error).__name__)
        if not clean:
            self.custody_hold()  # Does not unwind any enclosing lease context.
        else:
            self.write_result("capture-complete/question-unanswered" if self.capture_complete and not self.errors and code == 0
                              else "diagnostic-incomplete", code)
        # Only verified cleanup or an exact operator resolution permits these contexts to close.
        for signum, previous in self.handlers.items():
            signal.signal(signum, previous)
        for child in self.children:
            child.close()
        for stream in self.outputs.values():
            stream.close()
        if log is not None:
            log.close()
        durable_json(self.attempt / "child-exit.json", {"pid": self.worker.pid if self.worker else None,
                                                       "exit_code": code if code is not None else 125})
        return 0 if clean and self.capture_complete and not self.errors and code == 0 else 125

class NativeMonitor:
    """Persist verified descendants; reuse capture-quality cleanup's fresh identity checks."""
    def __init__(self, authority, attempt, workspace, expected_runtime=None, expected_image=None, phase=None):
        self.authority, self.attempt, self.workspace = authority, attempt, workspace
        self.known, self.errors = {}, []
        self.controller, self.root_identity = None, None
        self.expected_runtime, self.expected_image = expected_runtime, expected_image
        self.observed = {}
        self.bound_callback = None
        self.stop, self.thread = threading.Event(), None
        self.memory = None
        profile = authority.phase_profile(phase) if phase is not None else None
        if phase is not None and profile is None:
            raise ValueError("Phase RSS monitoring requires its own approved profile")
        if profile is not None or (expected_runtime is not None and (expected_runtime["mode"] == "address" or (
                expected_runtime["mode"] == "thread" and isinstance(authority, LocalAuthority)
                and expected_runtime["environment"].get(LOCAL_POLICY_ENV) == hashlib.sha256(
                    authority.policy_sha256.encode()).hexdigest()))):
            budget = (profile["admission"] if profile is not None else authority.config["admission"])["peak_per_worker"]
            if type(budget) is not int or budget <= 0:
                raise ValueError("Sanitizer resident budget must be positive integer bytes")
            self.memory = {"kind": "sampled-owned-process-rss-v1", "budget_bytes": budget,
                           "mode": phase if profile is not None else expected_runtime["mode"],
                           "poll_wait_seconds": 0.1, "samples": 0, "helper_samples": 0,
                           "last_bytes": 0, "high_water_bytes": 0, "failure": None,
                           "authority": "sampled RSS sum; not physical footprint or an OS hard limit"}
            if profile is not None:
                self.memory["phase_profile_sha256"] = fingerprint(profile)

    def persist(self):
        record = {"schema": SCHEMA, "workspace": str(self.workspace), "controller": self.controller,
                  "root": self.root_identity, "running": not self.stop.is_set(),
                  "observed_images": self.observed,
                  "processes": {str(pid): row for pid, row in self.known.items()}}
        if self.memory is not None:
            record["resident_memory"] = dict(self.memory)
        durable_json(self.attempt / "processes.json", record)

    def memory_failure(self, reason):
        if self.memory["failure"] is None:
            self.memory["failure"] = reason
            label = {"address": "ASAN", "thread": "TSAN", "normal": "NORMAL", "leaks": "LEAKS"}[self.memory["mode"]]
            self.errors.append(label + " resident memory: " + reason)
            self.persist()
            legacy.progress(json.dumps({label.lower() + "_resident_memory_refused": self.memory}, sort_keys=True))

    def sample_memory(self, live):
        if self.memory is None or not live:
            return
        if any(type(row.get("rss_bytes")) is not int or row["rss_bytes"] < 0 for row in live.values()):
            self.memory_failure("incomplete resident sample")
            return
        total = sum(row["rss_bytes"] for row in live.values())
        self.memory["samples"] += 1
        self.memory["helper_samples"] += int(any(
            "swiftpm-testing-helper" in row["command"] for row in live.values()))
        self.memory["last_bytes"] = total
        self.memory["high_water_bytes"] = max(self.memory["high_water_bytes"], total)
        if total > self.memory["budget_bytes"]:
            self.memory_failure("owned process tree exceeds budget")

    def cleanup_memory_failure(self, live):
        if self.memory is not None and self.memory["failure"] is not None:
            for pid, row in live.items():
                cleanup_owned_identity({"pid": pid, **row}, self.authority.snapshot)
            return True
        return False

    def observe(self):
        try:
            rows = self.authority.snapshot(resident=True) if self.memory is not None else self.authority.snapshot()
        except Exception as error:
            if self.memory is not None:
                self.memory_failure("snapshot " + type(error).__name__)
            raise
        live = descendants(self.known, rows)
        self.known.update(live)
        self.sample_memory(live)
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
        self.persist()
        return live

    def start(self, pid):
        rows = self.authority.snapshot()
        row, controller = rows.get(pid), rows.get(os.getpid())
        if row is None or controller is None:
            raise ValueError("Native child has no verified launch identity")
        self.controller = {"pid": os.getpid(), **controller}
        self.root_identity = {"pid": pid, **row}
        self.known[pid] = row
        if self.cleanup_memory_failure(self.observe()):
            return
        def watch():
            try:
                while not self.stop.wait(0.1):
                    if self.cleanup_memory_failure(self.observe()):
                        return
            except Exception as error:
                self.errors.append(type(error).__name__)
                self.cleanup_memory_failure(self.known)
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
        if self.memory is not None and self.memory["mode"] != "leaks" and not self.memory["helper_samples"]:
            self.memory_failure("no resident helper sample")
        if self.memory is not None and not self.memory["samples"]:
            self.memory_failure("no resident process sample")
        self.persist()
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
        return file_claim(self.authority.legacy_cache / "executor.lock", shared=True,
                          diagnostic_role="executor" if self.authority.config.get("vmmap_diagnostic") else None)

    def observe_admission(self):
        return self.authority.admission()

    def reclaimable(self, reservation):
        native_runner.require_diagnostic_custody_clear()
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
        return any(("swiftpm-testing-helper" in row["command"] or any(name in row["command"] for name in (".xctest/Contents/MacOS/Elite", ".xctest/Contents/MacOS/L337"))
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
        if ((attempt / "diagnostic.json").exists()
                or VM_DIAGNOSTIC_ENV in start.get("identity", {}).get("runtime", {}).get("environment", {})):
            return diagnostic_cleanup_proved(attempt)
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
        if self.authority.config.get("vmmap_diagnostic") is not None:
            if (len(shard["methods"]) != 16
                    or fingerprint(shard["methods"]) != self.authority.config["vmmap_diagnostic"]["cohort_methods_sha256"]):
                raise ValueError("Diagnostic requires the complete approved Panel16 cohort")
            self.diagnostic_attempt = attempt
            monitor = VmmapDiagnostic(self.authority, attempt, self.active_workspace, self.runtime, image,
                                      self.diagnostic_leases, self.owner_binding)
            monitor.bound_callback = getattr(self, "reservation_callback", None)
            context = {"mode": self.runtime["mode"], "shard": shard["id"],
                       "selected_method_count": len(shard["methods"]), **getattr(self, "progress_context", {})}
            return execute_process(command, self.active_workspace, attempt, timeout, descriptors,
                                   self.authority.environment_for(self.runtime["mode"]), monitor, progress=context)
        monitor = NativeMonitor(self.authority, attempt, self.active_workspace, self.runtime, image)
        monitor.bound_callback = getattr(self, "reservation_callback", None)
        context = {"mode": self.runtime["mode"], "shard": shard["id"],
                   "selected_method_count": len(shard["methods"]), **getattr(self, "progress_context", {})}
        code = execute_process(command, self.active_workspace, attempt, timeout, descriptors,
                               self.authority.environment_for(self.runtime["mode"]), monitor, progress=context)
        if self.unknown_live_helpers() or not monitor.observed or monitor.errors:
            return code or 126
        return code


class LocalExecutor(NativeExecutor):
    def execute(self, shard, attempt, timeout, descriptors):
        self.authority.check_session("execute")
        self.authority.consume_launch()  # Never refund a failed/uncertain spawn or reset a missing counter.
        return super().execute(shard, attempt, timeout,
                               [*descriptors, *self.authority.control_descriptors])


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
        profile = self.authority.phase_profile(phase)
        with NativeBuilder(self.authority).preparation_claim(**({"phase": phase} if profile is not None else {})) as lock:
            self.verify(plan["runtime"])
            runtime = plan["runtime"]
            durable = self.authority.cache / "full-phases" / phase_key(runtime, plan["inventory"], phase, profile)
            legacy.owned_directory(durable.parent)
            def deliver():
                require_sealed(durable)
                checksum = load_json(durable / "commit.json")["sha256"]
                validate_phase(durable, checksum, phase, runtime, plan["inventory"], profile)
                target = Path(destination)
                if target.exists():
                    validate_phase(target, checksum, phase, runtime, plan["inventory"], profile)
                else:
                    atomic_copy(durable, target)
                return checksum
            if not durable.exists():
                for stage in sorted(durable.parent.glob(durable.name + ".pending-*")):
                    try:
                        checksum = load_json(stage / "commit.json")["sha256"]
                        validate_phase(stage, checksum, phase, runtime, plan["inventory"], profile)
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
            if profile is not None:
                path = Path(self.authority.environment["ELITE_NATIVE_POLICY"])
                native_runner.require_owned_activation_file(path)
                command += ["--profile-policy", str(path), "--profile-policy-sha256", legacy.digest(path)]
            monitor = NativeMonitor(self.authority, execution, self.authority.root, phase=phase if profile is not None else None)
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
            memory = ({name: load_json(execution / file) for name, file in (
                ("processes", "processes.json"), ("child", "child.json"), ("terminal", "child-exit.json"))}
                if profile is not None else None)
            pending = durable.with_name(durable.name + ".pending-" + str(uuid.uuid4()))
            freeze_phase(self.attempt, result["identity"], runtime, plan["inventory"], self, pending, profile, memory)
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
            or instance.get("workspace") != str(root / "_work/l337/l337")
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



def report_progress(plan, store, state, current=None, packed_target=None):
    """A progress count is validated durable proof, never the last line of a running log."""
    complete = sum(store.matching(shard_identity(plan["runtime"], row)) is not None for row in plan["shards"])
    suites = sorted({".".join(legacy.group_key(method)) for method in current["methods"]}) if current else []
    record = {"mode": plan["runtime"]["mode"], "completed": complete, "total": len(plan["shards"]),
              "state": state, "current": current["id"] if current else None,
              "suites": suites, "max_runtime_seconds": SHARD_MAX_SECONDS,
              "indivisible_over_target_ids": bool(current and len(current["methods"]) > (
                  packed_target if packed_target is not None else
                  ASAN_PACKED_ID_TARGET if plan["runtime"]["mode"] == "address" else PACKED_ID_TARGET))}
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

def phase_key(runtime, inventory, phase, phase_profile=None):
    common = {key: runtime[key] for key in ("toolchain", "sdk", "host", "os", "architecture",
                                           "phase_environment", "opt_in_policy", "policy")}
    common.update(inputs=canonical_inputs(runtime["inputs"]), inventory=inventory, phase=phase)
    if phase_profile is not None:
        common["phase_profile"] = phase_profile
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


BRIDGE_AUTHORITY_ENV = {"ELITE_NATIVE_POLICY", "ELITE_NATIVE_APPROVED_HEAD",
                        "ELITE_RECOVERABLE_LOCAL_POLICY_SHA256", "ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"}


def bridge_semantics(environment):
    """Only these independently verified identity fields vary; unknown controls remain exact."""
    return {name: value for name, value in environment.items() if name not in BRIDGE_AUTHORITY_ENV}


def owned_bridge_path(path):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve():
        raise ValueError("Original bridge data must be an absolute physical path")
    native_runner.require_owned_activation_file(path)
    return path


def pinned_bridge_json(entry, filename=None):
    require_fields(entry, ("path", "sha256"))
    path = owned_bridge_path(entry["path"])
    file = path / filename if filename else path
    owned_bridge_path(file)
    if file.stat().st_mode & 0o777 != 0o400:
        raise ValueError("Original bridge JSON must be immutable")
    return path, trusted_json(file, entry["sha256"])


def verify_owned_local_components(authority, anchor):
    """Read original H evidence in place under current M authority, never relabel/import it."""
    binding = native_runner.read_local_components_binding(authority.policy)
    if authority.environment.get("GITHUB_JOB") not in ("native_local_components", "native_aggregate"):
        raise ValueError("This role cannot verify local components for CI")
    validate_plan(anchor)
    if anchor["runtime"]["mode"] != "address":
        raise ValueError("A real current-CI address anchor is required")
    executor = NativeExecutor(authority, "one")
    executor.verify(anchor["runtime"])
    if executor.unknown_live_helpers():
        raise ValueError("Live native helpers block bridge verification")
    current_authorization = authority.authorization()
    validate_authorization(current_authorization, anchor["runtime"])
    if current_authorization["head"] != binding["target"]["head"]:
        raise ValueError("Current bridge authority is for another target")
    if authority.output(["git", "rev-parse", binding["target"]["head"] + "^{tree}"]) != binding["target"]["tree"]:
        raise ValueError("Current bridge tree differs from the exact reviewed target object")
    if (authority.output(["git", "rev-parse", "HEAD"]) != binding["target"]["head"]
            or authority.output(["git", "status", "--porcelain"])):
        raise ValueError("Current bridge checkout is not the clean committed target")
    if (canonical_inputs(anchor["runtime"]["inputs"]) != binding["inputs"]
            or canonical_inputs(legacy.executable_inputs(authority.root, anchor["runtime"]["flags"][1])) != binding["inputs"]
            or bridge_semantics(anchor["runtime"]["phase_environment"]) != binding["semantic_environment"]):
        raise ValueError("Current source/dependency blobs or semantic environment drifted")
    ci_spaces = [authority.root, authority.cache, *authority.workers.values()]
    original_spaces, verified = [], {}
    for mode in MODES:
        entry = binding["modes"][mode]
        require_fields(entry, ("policy", "plan", "component", "build", "cache", "worker", "runtime_sha256", "admission"))
        policy_path, original_policy = pinned_bridge_json(entry["policy"])
        require_fields(original_policy, ("approved_head", "developer_dir", "swift", "sdk", "recoverable_shards", "local_activation"))
        config, activation = original_policy["recoverable_shards"], original_policy["local_activation"]
        require_fields(activation, ("schema", "kind", "mode", "workspace", "sources", "expires_at",
                                    "inventory_sha256", "inventory_count", "shard_count", "environment"))
        if (original_policy["approved_head"] != binding["original"]["head"]
                or any(original_policy[name] != authority.policy[name] for name in ("developer_dir", "swift", "sdk"))
                or activation.get("kind") != "local-sanitizer-activation-v1" or activation.get("mode") != mode
                or activation.get("schema") != SCHEMA or type(activation.get("schema")) is not int
                or config["host"] != authority.config["host"] or config["admission"] != entry["admission"]
                or config["legacy_cache"] != authority.config["legacy_cache"]
                or set(config["workers"]) != {"one"} or config["admission"]["explicit"] != 1
                or config["admission"]["cpu_budget"] != 1):
            raise ValueError("Original local policy/source/mode/allocation differs")
        if set(config) - {"schema", "host", "cache", "legacy_cache", "workers", "admission", "planning"}:
            raise ValueError("Original local profile has unknown controls")
        worker_limit(**config["admission"], ram_available=config["admission"]["ram_capacity"],
                     disk_available=config["admission"]["disk_capacity"])
        positive(activation["expires_at"])
        for name, digest in activation["sources"].items():
            if name not in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                            "quality_phase_checkpoints.py", "crash_artifacts.py"):
                raise ValueError("Unknown original helper source pin")
            current = authority.root / "Tools/CI" / name
            if current.is_symlink() or legacy.digest(current) != digest:
                raise ValueError("Current helper differs from original local source")
        if set(activation["sources"]) != {"native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                                         "quality_phase_checkpoints.py", "crash_artifacts.py"}:
            raise ValueError("Original local source pins are incomplete")
        source_root = owned_bridge_path(activation["workspace"])
        if (authority.output(["git", "rev-parse", "HEAD"], source_root) != binding["original"]["head"]
                or authority.output(["git", "status", "--porcelain"], source_root)
                or authority.output(["git", "rev-parse", binding["original"]["head"] + "^{tree}"], source_root) != binding["original"]["tree"]):
            raise ValueError("Original source checkout/tree is no longer clean committed H")
        cache, worker = owned_bridge_path(entry["cache"]), owned_bridge_path(entry["worker"])
        if (str(cache) != config["cache"] or str(worker) != config["workers"]["one"] or not cache.is_dir()
                or any(a.is_relative_to(b) or b.is_relative_to(a)
                       for a in (source_root, cache, worker) for b in ci_spaces)
                or any(a.is_relative_to(b) or b.is_relative_to(a) for a in (cache, worker) for b in original_spaces)):
            raise ValueError("Original local data overlaps current or another mode's mutable execution storage")
        original_spaces += [cache, worker]
        plan_path, plan = pinned_bridge_json(entry["plan"])
        validate_plan(plan)
        runtime = plan["runtime"]
        if (runtime["mode"] != mode or runtime["flags"] != local_sanitizer_flags(mode)
                or fingerprint(runtime) != entry["runtime_sha256"]
                or canonical_inputs(runtime["inputs"]) != binding["inputs"]
                or plan["inventory"] != anchor["inventory"] or plan["shared_groups"] != anchor["shared_groups"]
                or fingerprint(plan["inventory"]) != activation["inventory_sha256"]
                or len(plan["inventory"]) != activation["inventory_count"]
                or len(plan["shards"]) != activation["shard_count"]
                or any(len(row["methods"]) > LOCAL_PACKED_ID_TARGET and len(row["atoms"]) != 1 for row in plan["shards"])
                or any(runtime[key] != anchor["runtime"][key] for key in ("toolchain", "sdk", "host", "os", "architecture", "opt_in_policy"))):
            raise ValueError("Original mode's full source/dependency/inventory/profile/runtime changed")
        parent = dict(activation["environment"])
        parent["ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256"] = hashlib.sha256(execution_policy_digest(config).encode()).hexdigest()
        parent[LOCAL_POLICY_ENV] = hashlib.sha256(entry["policy"]["sha256"].encode()).hexdigest()
        expected_environment = dict(parent)
        if mode == "address":
            expected_environment["ASAN_OPTIONS"] = hashlib.sha256(b"detect_leaks=0").hexdigest()
        if (runtime["phase_environment"] != parent or runtime["environment"] != expected_environment
                or bridge_semantics(parent) != binding["semantic_environment"]):
            raise ValueError("Original semantic controls or independently validated authority identities changed")
        build_path, build = pinned_bridge_json(entry["build"], "build.json")
        if build_path != cache / "builds" / binding["original"]["head"] / mode or build["runtime"] != runtime:
            raise ValueError("Original frozen build/profile is not the declared local build")
        frozen_build_content(build, build_path)
        marker = worker / (mode + "-build.json")
        if (local_control(marker) != build or build["tested_head"] != binding["original"]["head"]
                or build["inventory"] != plan["inventory"] or build["shared_groups"] != plan["shared_groups"]):
            raise ValueError("Original private build marker or frozen full inventory changed")
        private = owned_bridge_path(worker / mode)
        image = owned_bridge_path(private / build["image_relative"])
        if (legacy.digest(image) != runtime["image_sha256"]
                or canonical_inputs(legacy.executable_inputs(private, runtime["flags"][1])) != binding["inputs"]
                or authority.output(["git", "rev-parse", "HEAD"], private) != binding["original"]["head"]
                or authority.output(["git", "status", "--porcelain"], private)):
            raise ValueError("Original private source/image/dependencies changed")
        component_path, component = pinned_bridge_json(entry["component"], "component.json")
        if any(a.is_relative_to(b) or b.is_relative_to(a)
               for a in (policy_path, plan_path, component_path, build_path) for b in ci_spaces):
            raise ValueError("Current CI mutable storage overlaps original bound proof")
        require_sealed(component_path)
        if ({p.name for p in component_path.iterdir()} != {"component.json", "commit.json"}
                or load_json(component_path / "commit.json") != {"sha256": entry["component"]["sha256"]}):
            raise ValueError("Original component commit is incomplete")
        computed = local_component_content(plan, entry["plan"]["sha256"], Store(cache, read_only=True), binding["original"]["head"],
                                           entry["policy"]["sha256"], config["admission"], worker)
        if component != computed:
            raise ValueError("Original component metadata differs from fully reverified content")
        for shard in plan["shards"]:
            reference = computed["receipts"][shard["id"]]
            attempt = Path(reference["path"])
            receipt = trusted_json(attempt / "result.json", reference["sha256"])
            authorization = trusted_json(attempt / "authorization.json", receipt["outputs"]["authorization.json"])
            if (authorization["session"]["expires_at"] > activation["expires_at"]
                    or authorization["workspace"] != str(source_root)
                    or authorization["execution_policy_sha256"] != execution_policy_digest(config)
                    or authorization["authorized_at"] >= activation["expires_at"]):
                raise ValueError("Original historical local authority was invalid at native execution")
        verified[mode] = {"original_tested_head": binding["original"]["head"], "component_sha256": entry["component"]["sha256"],
                          "plan_sha256": entry["plan"]["sha256"], "runtime_sha256": fingerprint(runtime),
                          "inventory_count": component["inventory_count"], "admission": config["admission"],
                          "sampled_rss_high_water_bytes": component["sampled_rss_high_water_bytes"]}
    return {"schema": SCHEMA, "kind": "owned-local-components-verification-v1", "status": "qualified",
            "target_ci_head": binding["target"]["head"], "original_tested_head": binding["original"]["head"],
            "exact_source_tree": binding["target"]["tree"], "binding_sha256": native_runner.backend_descriptor(authority.policy)[1]["sha256"],
            "modes": verified, "qualification": "Original H sanitizer execution, exact-source-equivalent to M; not sanitizer execution at M"}


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
        local_backend = native_runner.backend_descriptor(self.authority.policy)[0] == native_runner.LOCAL_COMPONENTS_BACKEND
        if ((local_backend and (set(manifest["plans"]) != {"address"} or manifest.get("anchor_only") is not True))
                or (not local_backend and "anchor_only" in manifest)):
            raise ValueError("Current-CI anchor/backend declaration differs")
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
            result = {"head": self.authority.policy["approved_head"], "exit_code": code,
                      "inputs": before, "command": command}
            local_backend = self.authority.backend() == native_runner.LOCAL_COMPONENTS_BACKEND
            if local_backend:
                result["outputs"] = physical_tree(output)
            durable_json(output / "result.json", result)
            if local_backend:
                durable_json(output / "commit.json", {"sha256": legacy.digest(output / "result.json")})
            seal(output)
            if code != 0:
                raise ValueError("Required make-ci prerequisite failed; raw output retained")
            if local_backend:
                if self.authority.environment.get("GITHUB_JOB") != "native_checks":
                    raise ValueError("Only the actual checks job can capture prerequisite origin")
                target = self.prerequisites_path()
                if target.exists():
                    if physical_tree(target) != physical_tree(output):
                        raise ValueError("Existing current-run prerequisite proof differs")
                else:
                    atomic_copy(output, target)
        return {"checks_exit_code": code}

    def prerequisites_path(self):
        e = self.authority.environment
        return self.authority.cache / "ci-prerequisites" / self.authority.policy["approved_head"] / e["GITHUB_RUN_ID"] / e["GITHUB_RUN_ATTEMPT"]

    def require_prerequisites(self, anchor):
        path = self.prerequisites_path()
        require_sealed(path)
        result = trusted_json(path / "result.json", load_json(path / "commit.json")["sha256"])
        launch = load_json(path / "launch.json")
        authorization = launch["authorization"]
        validate_authorization(authorization, anchor["runtime"])
        expected = ["make", "native-runner-check", "instance-equality-check", "ci-capture-check", "flight-controls-check",
                    "homebrew-cask-check", "ships-check", "showroom-check", "mission-packs-check", "sanitizer-checkpoints-check"]
        outputs = physical_tree(path)
        if (result["head"] != self.authority.policy["approved_head"] or result["command"] != expected
                or launch["command"] != expected or type(result["exit_code"]) is not int or result["exit_code"] != 0
                or authorization["role"] != "native_checks" or authorization["head"] != result["head"]
                or authorization["policy_sha256"] != native_runner.policy_digest(self.authority.policy)
                or any(authorization[name] != self.authority.environment[key] for name, key in (
                    ("run_id", "GITHUB_RUN_ID"), ("run_attempt", "GITHUB_RUN_ATTEMPT")))
                or result["outputs"] != {k: v for k, v in outputs.items() if k not in ("result.json", "commit.json")}
                or {k: v for k, v in result["inputs"].items() if not k.startswith(".build/")}
                   != {k: v for k, v in anchor["runtime"]["inputs"].items() if not k.startswith(".build/")}
                or load_json(path / "child-exit.json")["exit_code"] != 0
                or load_json(path / "processes.json")["running"] is not False):
            raise ValueError("Real current-run make-ci prerequisite proof is missing or changed")
        return legacy.digest(path / "result.json")

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
        if self.authority.backend() == native_runner.LOCAL_COMPONENTS_BACKEND:
            if modes != ("address",):
                raise ValueError("Owned local-components backend prepares only its actual CI address anchor")
            manifest["anchor_only"] = True
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
        profile = self.authority.phase_profile(phase)
        target = self.authority.cache / "full-phases" / phase_key(plan["runtime"], plan["inventory"], phase, profile)
        if target.exists():
            require_sealed(target)
            validate_phase(target, load_json(target / "commit.json")["sha256"], phase,
                           plan["runtime"], plan["inventory"], profile)
            return target
        for artifact in self.artifacts().artifacts("native-phase-" + phase + "-"):
            bundle = self.artifacts().fetch(artifact)
            if (bundle / "failure.json").exists():
                continue
            checksum = legacy.digest(bundle / "index.json")
            validate_phase(bundle, checksum, phase, plan["runtime"], plan["inventory"], profile)
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

    def owned_components(self, plans, output):
        if self.authority.backend() != native_runner.LOCAL_COMPONENTS_BACKEND or len(plans) != 1:
            raise ValueError("Owned local verification requires its explicit backend and one real CI anchor")
        if output.exists():
            raise ValueError("Bridge verification output already exists")
        legacy.owned_directory(output)
        try:
            with NativeBuilder(self.authority).preparation_claim():
                result = verify_owned_local_components(self.authority, plans[0])
        except BaseException as error:
            durable_json(output / "result.json", {"status": "failed", "failure": type(error).__name__,
                                                  "target_ci_head": self.authority.policy["approved_head"]})
            seal(output)
            raise
        durable_json(output / "result.json", result)
        durable_json(output / "commit.json", {"sha256": legacy.digest(output / "result.json")})
        seal(output)
        return result

    def aggregate_owned(self, plans, output):
        if (self.authority.backend() != native_runner.LOCAL_COMPONENTS_BACKEND or len(plans) != 1
                or self.authority.environment.get("GITHUB_JOB") != "native_aggregate"):
            raise ValueError("Only the real current-CI aggregate uses the owned full-quality backend")
        if output.exists():
            raise ValueError("Full-quality bridge output already exists")
        legacy.owned_directory(output)
        try:
            with NativeBuilder(self.authority).preparation_claim():
                anchor = plans[0]
                components = verify_owned_local_components(self.authority, anchor)
                prerequisites = self.require_prerequisites(anchor)
                phases_verified = {}
                for phase in ("normal", "leaks"):
                    bundle = self.restore_phase(anchor, phase)
                    if bundle is None:
                        raise ValueError("Actual current-CI normal/coverage or leak phase is missing")
                    checksum = legacy.digest(bundle / "index.json")
                    validate_phase(bundle, checksum, phase, anchor["runtime"], anchor["inventory"], self.authority.phase_profile(phase))
                    origin = load_json(bundle / "index.json")["origin"]
                    if (origin["tested_head"] != self.authority.policy["approved_head"]
                            or origin["authorization"]["policy_sha256"] != native_runner.policy_digest(self.authority.policy)):
                        raise ValueError("Full-quality phases are not actual current-target/current-policy execution")
                    phases_verified[phase] = {"path": str(bundle), "sha256": checksum, "actual_tested_head": origin["tested_head"]}
                    if phase == "normal":
                        for name in ("coverage.xml", "coverage.lcov"):
                            shutil.copyfile(bundle / "attempt" / name, self.authority.root / name)
                result = {"status": "components-prerequisites-and-phases-qualified", "current_ci_head": self.authority.policy["approved_head"],
                          "original_sanitizer_tested_head": components["original_tested_head"], "components": components,
                          "prerequisites_sha256": prerequisites, "phases": phases_verified,
                          "qualification": "Full content verified; real job/fake outcomes and actual-main Sonar must also succeed before quality passes"}
                durable_json(output / "result.json", result)
                seal(output)
                return result
        except BaseException as error:
            durable_json(output / "result.json", {"status": "failed", "current_ci_head": self.authority.policy["approved_head"],
                                                  "failure": type(error).__name__})
            seal(output)
            raise

    def aggregate(self, plans):
        if self.authority.backend() == native_runner.LOCAL_COMPONENTS_BACKEND:
            raise ValueError("Local components require their explicit aggregate, not invented GitHub mode plans")
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
            validate_phase(output, legacy.digest(complete / "index.json"), phase, plan["runtime"], plan["inventory"],
                           self.authority.phase_profile(phase))
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


def verify_local_plan(authority, plan, digest=None):
    validate_plan(plan)
    activation = authority.activation
    if (plan["runtime"]["mode"] != activation["mode"]
            or plan["runtime"]["flags"] != authority.build_flags(activation["mode"])
            or fingerprint(plan["inventory"]) != activation["inventory_sha256"]
            or len(plan["inventory"]) != activation["inventory_count"]
            or len(plan["shards"]) != activation["shard_count"]
            or plan["runtime"]["environment"].get(LOCAL_POLICY_ENV) != hashlib.sha256(
                authority.policy_sha256.encode()).hexdigest()
            or (digest is not None and digest != authority.session["plan_sha256"])):
        raise ValueError("Local plan differs from its mode/source/profile/full-inventory approval")
    if any(len(row["methods"]) > LOCAL_PACKED_ID_TARGET and len(row["atoms"]) != 1 for row in plan["shards"]):
        raise ValueError("Local sanitizer packing exceeds its process memory profile")
    if authority.session["stage"] == "execute" and not set(authority.session["shards"]) <= {row["id"] for row in plan["shards"]}:
        raise ValueError("Local assigned shards are outside the exact full plan")


def local_component_content(plan, digest, store, head, policy_sha256, admission, worker):
    """Rehash original sealed content in place; no execution, copied receipts or changed identities."""
    receipts, actual, maxima = {}, [], []
    for shard in plan["shards"]:
        found = store.matching(shard_identity(plan["runtime"], shard))
        if found is None:
            raise ValueError("Local component has a missing/failed/incomplete shard: " + shard["id"])
        attempt, receipt = found
        authorization = load_json(attempt / "authorization.json")
        if (authorization["kind"] != "validated-local-sanitizer-v1"
                or authorization["session"]["plan_sha256"] != digest
                or authorization["policy_sha256"] != policy_sha256
                or receipt["tested_head"] != head):
            raise ValueError("Local component contains proof from another plan/source/profile")
        processes = load_json(attempt / "processes.json")
        expected_image = {"sha256": plan["runtime"]["image_sha256"], "uuid": plan["runtime"]["image_uuid"]}
        child = load_json(attempt / "child.json")
        if (processes.get("running") is not False
                or expected_image not in processes.get("observed_images", {}).values()
                or processes.get("workspace") != str(worker / plan["runtime"]["mode"])
                or processes.get("root", {}).get("pid") != child["pid"]
                or not processes.get("root", {}).get("start")):
            raise ValueError("Local component process/image terminal proof is incomplete")
        memory = processes.get("resident_memory", {})
        if (memory.get("kind") != "sampled-owned-process-rss-v1" or memory.get("failure") is not None
                or memory.get("mode") != plan["runtime"]["mode"]
                or type(memory.get("helper_samples")) is not int or memory["helper_samples"] < 1
                or type(memory.get("samples")) is not int or memory["samples"] < memory["helper_samples"]
                or type(memory.get("high_water_bytes")) is not int or memory["high_water_bytes"] < 0
                or memory.get("budget_bytes") != admission["peak_per_worker"]
                or memory["high_water_bytes"] > memory["budget_bytes"]):
            raise ValueError("Local sanitizer component lacks successful mode-specific resident-budget evidence")
        maxima.append(memory["high_water_bytes"])
        receipts[shard["id"]] = {"path": str(attempt), "sha256": legacy.digest(attempt / "result.json")}
        actual.extend(receipt["identity"]["methods"])
    if Counter(actual) != Counter(plan["inventory"]):
        raise ValueError("Local sanitizer component inventory is not exactly once")
    result = {"schema": SCHEMA, "kind": "local-sanitizer-component-v1", "status": "qualified",
              "head": head, "mode": plan["runtime"]["mode"],
              "plan_sha256": digest, "policy_sha256": policy_sha256,
              "runtime_sha256": fingerprint(plan["runtime"]), "inventory_sha256": fingerprint(sorted(actual)),
              "inventory_count": len(actual), "receipts": receipts,
              "sampled_rss_high_water_bytes": max(maxima) if maxima else None,
              "release_status": "pending full quality, coverage, leaks, other mode, main analysis and release gates"}
    return result


def local_component(authority, plan, digest, store, output):
    """Validate a full local sanitizer component; never manufacture a full quality/release pass."""
    authority.check_session("validate")
    if not output.is_absolute() or output != output.resolve() or output.is_relative_to(authority.root) or output.exists():
        raise ValueError("Local component output must be fresh, physical and outside source")
    verify_local_plan(authority, plan, digest)
    executor = NativeExecutor(authority, "one")
    executor.verify(plan["runtime"])
    if executor.unknown_live_helpers():
        raise ValueError("Unknown live native helpers block local component qualification")
    result = local_component_content(plan, digest, store, authority.policy["approved_head"],
                                     authority.policy_sha256, authority.config["admission"], authority.workers["one"])
    authority.check_session("validate")
    if output.exists():
        raise ValueError("Local component output already exists")
    legacy.owned_directory(output)
    durable_json(output / "component.json", result)
    durable_json(output / "commit.json", {"sha256": legacy.digest(output / "component.json")})
    seal(output)
    return result


def local_command(args):
    import pwd
    stage = {"local-prepare": "prepare", "local-run": "execute", "local-validate": "validate"}[args.command]
    if not args.policy or not args.local_session or not args.local_session_digest or args.mode not in MODES:
        raise ValueError("Local operations require an owned policy/session, separate digest and exact mode")
    if not 0 < positive(args.timeout) <= SHARD_MAX_SECONDS:
        raise ValueError("Local sanitizer operations retain the two-hour shard bound")
    require_physical_activation()
    native_runner.require_diagnostic_custody_clear()
    environment = local_environment()
    # Fixed physical-owner storage, shared by both modes regardless of their separate policy/cache paths.
    serial_root = Path(pwd.getpwuid(os.getuid()).pw_dir) / "Library/EliteNativeCI"
    candidate = local_control(args.policy)
    diagnostic = candidate.get("recoverable_shards", {}).get("vmmap_diagnostic") is not None
    with file_claim(serial_root / "recoverable-control.lock",
                    diagnostic_role="controller" if diagnostic else None) as control:
        authority = LocalAuthority(args.policy, args.local_session, args.local_session_digest, args.mode, stage,
                                   environment=environment, control_descriptors=(control.fileno(),))
        authority.control_descriptors = (control.fileno(),)
        if authority.config.get("vmmap_diagnostic") is not None:
            authority.controller_lease = getattr(control, "_diagnostic_lease", None)
        authority.check_session(stage)
        if stage == "prepare":
            if (args.output is None or not args.output.is_absolute() or args.output != args.output.resolve()
                    or args.output.is_relative_to(authority.root) or args.output.exists()):
                raise ValueError("Local preparation requires a fresh physical plan output outside source")
            legacy.owned_directory(args.output.parent)
            authority.consume_launch()
            destination = authority.cache / "builds" / authority.policy["approved_head"] / args.mode
            builder = NativeBuilder(authority)
            builder.build_only(args.mode, args.timeout)
            build = builder.prepare(args.mode, destination)
            hints = authority.config.get("planning", {}).get(args.mode, {})
            plan = make_plan(build["runtime"], build["inventory"], build["shared_groups"],
                workflow_history(build["inventory"], args.mode, build["shared_groups"], hints.get("history")),
                hints.get("resources"), hints.get("budget_seconds", 600), max_methods=LOCAL_PACKED_ID_TARGET)
            verify_local_plan(authority, plan)
            authority.check_session("prepare")
            durable_json(args.output, plan)
            return {"plan_sha256": legacy.digest(args.output)}
        if args.input is None or not args.digest:
            raise ValueError("Local execution/validation requires its separately approved plan and digest")
        plan = trusted_json(args.input, args.digest)
        verify_local_plan(authority, plan, args.digest)
        store = Store(authority.cache)
        if stage == "validate":
            if authority.config.get("vmmap_diagnostic") is not None:
                raise ValueError("Diagnostic execution cannot create a local quality component")
            if args.output is None:
                raise ValueError("Local validation requires a fresh component output")
            return local_component(authority, plan, args.digest, store, args.output)
        executor = LocalExecutor(authority, "one")
        results = []
        for shard in plan["shards"]:
            if shard["id"] not in authority.session["shards"]:
                continue
            observation = report_progress(plan, store, "starting local shard", shard, packed_target=LOCAL_PACKED_ID_TARGET)
            executor.progress_context = {"validated_shards_completed": observation["completed"],
                                         "shards_total": observation["total"]}
            try:
                results.append(run_shard(plan, shard["id"], store, executor, authority.policy["approved_head"],
                                         args.timeout, authority.admission()))
                if authority.config.get("vmmap_diagnostic") is not None:
                    return {"status": "diagnostic-only; stop after one attempt", "results": results}
            except BaseException:
                report_progress(plan, store, "local shard failed or interrupted", shard, packed_target=LOCAL_PACKED_ID_TARGET)
                raise
            report_progress(plan, store, "local shard completed or reused", shard, packed_target=LOCAL_PACKED_ID_TARGET)
        return {"status": "assigned shards executed; explicit full local validation still required", "results": results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "prepare", "worker", "pool", "export", "restore",
                                             "phase", "aggregate", "workflow-prepare", "workflow-load",
                                             "workflow-run", "workflow-build", "workflow-build-export", "workflow-checks", "workflow-checks-export", "workflow-phase", "workflow-export",
                                             "workflow-phase-export", "workflow-aggregate",
                                             "local-prepare", "local-run", "local-validate",
                                             "workflow-verify-local-components", "workflow-owned-aggregate"))
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
    parser.add_argument("--local-session", type=Path)
    parser.add_argument("--local-session-digest")
    args = parser.parse_args()
    if args.command.startswith("local-"):
        legacy.progress(json.dumps(local_command(args)))
        return
    if args.local_session is not None or args.local_session_digest is not None:
        parser.error("Local sessions cannot authorize GitHub or legacy commands")
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
            if args.command == "workflow-verify-local-components":
                if args.output is None:
                    parser.error("Owned component verification requires output")
                result = workflow.owned_components(plans, args.output)
            elif args.command == "workflow-owned-aggregate":
                if args.output is None:
                    parser.error("Owned full-quality aggregate requires output")
                result = workflow.aggregate_owned(plans, args.output)
            elif args.command == "workflow-aggregate":
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
