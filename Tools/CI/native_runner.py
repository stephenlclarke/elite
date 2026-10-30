"""Authorize one reviewed Elite quality job on the physical Mac before checkout."""

import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import time

REPOSITORY = "stephenlclarke/l337"
ACTOR = "22142777"
RECOVERABLE_JOBS = {"prepare_native", "prepare_thread", "prepare_address", "native_checks", "native_phase",
                    "native_shards", "thread_shards", "address_shards", "native_aggregate", "native_local_components"}
PREPARE_JOBS = {"prepare_native", "prepare_thread", "prepare_address", "native_checks"}
SHARD_JOBS = {"native_shards", "thread_shards", "address_shards"}
LOCAL_COMPONENTS_BACKEND = "owned-local-components-v1"
GITHUB_BACKEND = "github-artifacts-v1"
LOCAL_COMPONENT_ROLES = {"native_checks", "prepare_address", "native_local_components", "native_phase", "native_aggregate"}
PHASE_BUILD_PROFILE = "jobs1-nonbatch-v1"

CUSTODY_KIND = "owned-diagnostic-custody-v1"
_CUSTODY_SEAL = object()


def diagnostic_custody_root():
    """No environment variable or checkout can redirect the physical shared guard."""
    import pwd
    return Path(pwd.getpwuid(os.getuid()).pw_dir) / "Library/EliteNativeCI/diagnostic-custody"


def _custody_json(path, immutable=False):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve() or path.is_symlink():
        raise ValueError("Diagnostic custody path is not physical")
    require_owned_activation_file(path)
    info = path.lstat()
    if (not path.is_file() or info.st_uid != os.getuid()
            or info.st_mode & 0o777 != (0o400 if immutable else 0o600)
            or info.st_size > 1024 * 1024):
        raise ValueError("Diagnostic custody material is missing, foreign or malformed")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate custody field")
            result[key] = value
        return result
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "r") as stream:
        opened = os.fstat(stream.fileno())
        if (opened.st_dev, opened.st_ino, opened.st_uid, opened.st_mode, opened.st_size) != (
                info.st_dev, info.st_ino, info.st_uid, info.st_mode, info.st_size):
            raise ValueError("Diagnostic custody file changed while opening")
        return json.load(stream, object_pairs_hook=unique,
                         parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def custody_digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def diagnostic_custody_registry():
    """Missing state is not an empty registry; bootstrap is a separate reviewed operation."""
    root = diagnostic_custody_root()
    if (root != root.resolve() or root.is_symlink() or not root.is_dir()
            or root.stat().st_uid != os.getuid() or root.stat().st_mode & 0o777 != 0o700):
        raise ValueError("Shared diagnostic custody registry requires reviewed initialization")
    value = _custody_json(root / "registry.json")
    if (not isinstance(value, dict) or set(value) != {"schema", "kind", "generation", "records"}
            or value["schema"] != 1 or type(value["schema"]) is not int or value["kind"] != CUSTODY_KIND
            or type(value["generation"]) is not int or value["generation"] < 0
            or not isinstance(value["records"], dict)):
        raise ValueError("Invalid diagnostic custody registry")
    fields = {"nonce", "attempt", "source_head", "policy_sha256", "session_sha256", "controller",
              "identities", "state", "phase", "launches", "deadline", "last_verified", "terminal", "intents", "target"}
    for nonce, record in value["records"].items():
        if (not isinstance(record, dict) or set(record) != fields or record["nonce"] != nonce
                or not isinstance(nonce, str) or not re.fullmatch(r"[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}", nonce)
                or record["state"] not in ("ACTIVE", "UNKNOWN", "CLEAN")
                or record["phase"] not in ("timed", "custody-only", "terminal")
                or record["launches"] != 1 or type(record["launches"]) is not int
                or not isinstance(record["source_head"], str) or not re.fullmatch(r"[0-9a-f]{40}", record["source_head"])
                or any(not isinstance(record[key], str) or not re.fullmatch(r"[0-9a-f]{64}", record[key])
                       for key in ("policy_sha256", "session_sha256"))
                or not isinstance(record["attempt"], str) or not Path(record["attempt"]).is_absolute()
                or type(record["deadline"]) not in (int, float) or not math.isfinite(record["deadline"])
                or record["deadline"] <= 0 or not isinstance(record["controller"], dict)
                or not isinstance(record["identities"], list) or not isinstance(record["intents"], list)):
            raise ValueError("Invalid registered diagnostic custody record")
        controller = record["controller"]
        if (set(controller) != {"pid", "start", "command", "image", "image_sha256", "source_sha256"}
                or type(controller["pid"]) is not int or controller["pid"] <= 0
                or any(not isinstance(controller[key], str) or not controller[key]
                       for key in ("start", "command", "image"))
                or any(not isinstance(controller[key], str) or not re.fullmatch(r"[0-9a-f]{64}", controller[key])
                       for key in ("image_sha256", "source_sha256"))):
            raise ValueError("Invalid custody controller binding")
        seen = set()
        for identity in record["identities"]:
            if (not isinstance(identity, dict)
                    or set(identity) != {"pid", "parent", "group", "start", "command", "role"}
                    or type(identity["pid"]) is not int or identity["pid"] <= 0 or identity["pid"] in seen
                    or any(type(identity[key]) is not int or identity[key] < 0 for key in ("parent", "group"))
                    or any(not isinstance(identity[key], str) or not identity[key] for key in ("start", "command"))
                    or identity["role"] not in ("controller", "worker", "vmmap", "support")):
                raise ValueError("Invalid or duplicate custody identity")
            seen.add(identity["pid"])
        roots = [row for row in record["identities"] if row["role"] == "controller"]
        if (len(roots) != 1 or any(roots[0][key] != controller[key] for key in ("pid", "start", "command"))
                or not Path(controller["image"]).is_absolute()):
            raise ValueError("Custody lacks its exact sole controller identity")
        target = record["target"]
        if target is not None and (not isinstance(target, dict)
                or set(target) != {"pid", "parent", "group", "start", "command", "role", "image", "image_sha256", "image_uuid"}
                or target["role"] != "worker" or not isinstance(target["image"], str)
                or not Path(target["image"]).is_absolute()
                or any(not isinstance(target[key], str) or not re.fullmatch(r"[0-9a-f]{64}", target[key])
                       for key in ("image_sha256", "image_uuid"))
                or not any(all(target[key] == row[key] for key in ("pid", "start", "command", "role"))
                           for row in record["identities"])):
            raise ValueError("Invalid captured helper image/UUID identity binding")
        if record["state"] == "CLEAN":
            terminal = record["terminal"]
            expected = [row for row in record["identities"] if row["role"] != "controller"]
            if (record["phase"] != "terminal" or not isinstance(terminal, dict)
                    or set(terminal) != {"absent", "reaped", "time"}
                    or terminal["absent"] != expected or terminal["reaped"] is not True
                    or type(terminal["time"]) not in (int, float) or not math.isfinite(terminal["time"])
                    or not 0 <= terminal["time"] <= record["deadline"]
                    or any(not isinstance(intent, dict) or intent.get("state") not in ("reaped", "not-launched")
                           for intent in record["intents"])):
                raise ValueError("Diagnostic CLEAN lacks bounded terminal proof")
        elif record["terminal"] is not None:
            raise ValueError("Unresolved diagnostic cannot claim terminal cleanup")
        if record["state"] == "UNKNOWN" and record["phase"] != "custody-only":
            raise ValueError("UNKNOWN cannot claim continued timed monitoring")
        if record["state"] == "ACTIVE" and record["phase"] != "timed":
            raise ValueError("ACTIVE requires its original timed phase")
        sample = record["last_verified"]
        if sample is not None and (not isinstance(sample, dict)
                or set(sample) != {"time", "worker_bytes", "union_bytes", "roles", "status"}
                or sample["status"] != "last-verified"
                or type(sample["time"]) not in (int, float) or not math.isfinite(sample["time"])
                or any(type(sample[key]) is not int or sample[key] < 0 for key in ("worker_bytes", "union_bytes"))
                or not isinstance(sample["roles"], dict)
                or set(sample["roles"]) != {"controller", "worker", "vmmap", "support"}
                or any(type(n) is not int or n < 0 for n in sample["roles"].values())
                or sample["union_bytes"] != sum(sample["roles"].values())
                or sample["worker_bytes"] != sample["roles"]["worker"]
                or not 0 <= sample["time"] <= record["deadline"]):
            raise ValueError("Invalid last-verified diagnostic sample")
        for intent in record["intents"]:
            if (not isinstance(intent, dict) or set(intent) != {"role", "argv", "pid", "state"}
                    or intent["role"] not in ("worker", "vmmap", "support")
                    or intent["state"] not in ("planned", "spawned", "reaped", "not-launched")
                    or not isinstance(intent["argv"], list) or not intent["argv"]
                    or any(not isinstance(arg, str) or not arg for arg in intent["argv"])
                    or (intent["pid"] is not None and (type(intent["pid"]) is not int or intent["pid"] <= 0))
                    or (intent["state"] in ("spawned", "reaped")) != (intent["pid"] is not None)):
                raise ValueError("Invalid registered diagnostic spawn intent")
    return value


def diagnostic_resolution(record):
    """Only immutable, reviewed, exact terminal material resolves a persistent record."""
    root = diagnostic_custody_root()
    path = root / "resolutions" / (record["nonce"] + ".json")
    if not path.exists() and not path.is_symlink():
        return False
    value = _custody_json(path, immutable=True)
    keys = {"schema", "kind", "nonce", "attempt", "record_sha256", "source_head", "policy_sha256",
            "session_sha256", "controller", "identities", "target", "evidence", "review"}
    if (not isinstance(value, dict) or set(value) != keys or value["schema"] != 1
            or type(value["schema"]) is not int
            or value["kind"] != "reviewed-diagnostic-custody-resolution-v1"
            or value["record_sha256"] != custody_digest(record)
            or any(value[key] != record[key] for key in ("nonce", "attempt", "source_head", "policy_sha256",
                                                        "session_sha256", "controller", "identities", "target"))):
        raise ValueError("Resolution does not bind the current exact custody record")
    materials = {}
    for key in ("evidence", "review"):
        descriptor = value[key]
        if (not isinstance(descriptor, dict) or set(descriptor) != {"path", "sha256"}
                or not isinstance(descriptor["path"], str)
                or not Path(descriptor["path"]).is_absolute()
                or not isinstance(descriptor["sha256"], str)
                or not re.fullmatch(r"[0-9a-f]{64}", descriptor["sha256"])):
            raise ValueError("Resolution requires separately bound reviewed material")
        materials[key] = _custody_json(Path(descriptor["path"]), immutable=True)
        if hashlib.sha256(Path(descriptor["path"]).read_bytes()).hexdigest() != descriptor["sha256"]:
            raise ValueError("Resolution material changed")
    evidence, review = materials["evidence"], materials["review"]
    if not isinstance(evidence, dict) or not isinstance(review, dict):
        raise ValueError("Malformed resolution evidence/review")
    absent = [row for row in record["identities"] if row["role"] != "controller"]
    expected_evidence = {"schema": 1, "kind": "diagnostic-terminal-absence-v1", "nonce": record["nonce"],
                     "record_sha256": custody_digest(record), "identities": record["identities"],
                     "absent": absent, "target": record["target"], "intents": record["intents"], "unobserved_spawns_resolved": True,
                     "direct_children_reaped": True, "controller_absent": evidence.get("controller_absent")}
    if (type(evidence.get("schema")) is not int or type(review.get("schema")) is not int
            or not isinstance(evidence.get("controller_absent"), bool)
            or (record["state"] == "ACTIVE" and evidence["controller_absent"] is not True)
            or evidence != expected_evidence
            or review != {"schema": 1, "kind": "diagnostic-custody-resolution-review-v1",
                          "nonce": record["nonce"], "record_sha256": custody_digest(record),
                          "evidence_sha256": value["evidence"]["sha256"], "approved": True}):
        raise ValueError("Missing exact reviewed terminal/absence evidence")
    return True


def require_diagnostic_custody_clear():
    """Every ordinary admission refuses unresolved custody, including a dead owner."""
    registry = diagnostic_custody_registry()
    for record in registry["records"].values():
        if record["state"] != "CLEAN" and not diagnostic_resolution(record):
            raise ValueError("INCOMPLETE/UNKNOWN diagnostic custody blocks admission")


class _DiagnosticLease:
    """Minted by the actual lock-acquisition context, never by a supplied fd number."""
    def __init__(self, lock, role, seal):
        if seal is not _CUSTODY_SEAL or role not in ("controller", "executor", "reservation"):
            raise ValueError("Untrusted lease witness")
        self.lock, self.role, self.fd = lock, role, lock.fileno()
        self.duplicate = os.dup(self.fd)
        self.identity = os.fstat(self.fd)
        self.active, self.owner = True, os.getpid()

    def verify(self):
        if not self.active or self.owner != os.getpid() or self.lock.closed or self.lock.fileno() != self.fd:
            raise ValueError("Lease lifetime ended")
        info = os.fstat(self.fd)
        if (info.st_dev, info.st_ino) != (self.identity.st_dev, self.identity.st_ino):
            raise ValueError("Lease descriptor was replaced")
        # A reopened same-inode fd is not the original open file description.
        position = os.lseek(self.duplicate, 0, os.SEEK_CUR)
        challenge = (time.monotonic_ns() & 0x3fffffff) + 1
        try:
            os.lseek(self.duplicate, challenge, os.SEEK_SET)
            if os.lseek(self.fd, 0, os.SEEK_CUR) != challenge:
                raise ValueError("Lease descriptor was closed/reused")
        finally:
            os.lseek(self.duplicate, position, os.SEEK_SET)

    def revoke(self):
        self.active = False
        os.close(self.duplicate)


@contextmanager
def _diagnostic_lease_context(lock, role):
    witness = _DiagnosticLease(lock, role, _CUSTODY_SEAL)
    try:
        yield witness
    finally:
        witness.revoke()


def workflow_path(environment: dict) -> str:
    """The reusable workflow's caller is the actual CI event/workflow authority."""
    return (".github/workflows/recoverable-quality.yml" if environment.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
            and "/recoverable-quality.yml@" in environment.get("GITHUB_WORKFLOW_REF", "")
            else ".github/workflows/ci.yml")


def require_recoverable_event(activation: dict, environment: dict, event: dict) -> None:
    """Approve the exact execution commit, including a separately pinned internal PR merge."""
    name, ref, head = (environment.get(key, "") for key in ("GITHUB_EVENT_NAME", "GITHUB_REF", "GITHUB_SHA"))
    if name == "pull_request":
        pull = event.get("pull_request", {})
        source, base = pull.get("head", {}), pull.get("base", {})
        # The immutable GitHub execution context is authoritative, not webhook merge metadata.
        valid = (head == activation.get("head")
                 and re.fullmatch(r"[0-9a-f]{40}", head)
                 and activation.get("workflow_ref") == environment.get("GITHUB_WORKFLOW_REF")
                 and activation.get("workflow_ref") == REPOSITORY + "/.github/workflows/ci.yml@" + ref
                 and source.get("sha") == activation.get("pr_head")
                 and re.fullmatch(r"[0-9a-f]{40}", activation.get("pr_head", ""))
                 and source.get("repo", {}).get("full_name") == REPOSITORY
                 and source.get("repo", {}).get("fork") is False
                 and base.get("repo", {}).get("full_name") == REPOSITORY and base.get("ref") == "main"
                 and str(pull.get("user", {}).get("id")) == ACTOR
                 and ref == "refs/pull/" + str(event.get("number")) + "/merge")
    elif name == "push":
        valid = (ref == "refs/heads/main" and event.get("ref") == ref and event.get("after") == head
                 and event.get("deleted") is False and event.get("forced") is False)
    elif name == "workflow_dispatch":
        valid = ref.startswith("refs/heads/")
    else:
        valid = False
    if not valid:
        raise ValueError("Recoverable execution/source/ref is not approved: execution=" + head
                         + ", approved_execution=" + str(activation.get("head"))
                         + ", ref=" + ref)


def assignment_digest(environment: dict) -> str:
    return policy_digest({name: environment.get(name, "") for name in (
        "GITHUB_JOB", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_SHA", "RUNNER_NAME",
        "ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
        "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE")})


def assignment_payload(policy: dict, environment: dict) -> dict:
    activation = policy["recoverable_activation"]
    payload = {"schema": 1, "head": policy["approved_head"], "workflow_sha256": activation["workflow_sha256"],
            "activation_sha256": activation["manifest_sha256"], "policy_sha256": policy_digest(policy),
            "run_id": environment["GITHUB_RUN_ID"], "run_attempt": environment["GITHUB_RUN_ATTEMPT"],
            "job": environment["GITHUB_JOB"], "runner": environment["RUNNER_NAME"],
            "workspace": environment["GITHUB_WORKSPACE"], "policy_path": environment["ELITE_NATIVE_POLICY"],
            "mode": environment.get("ELITE_RECOVERABLE_REQUEST_MODE", ""),
            "shard": environment.get("ELITE_RECOVERABLE_REQUEST_SHARD", ""),
            "worker": environment.get("ELITE_RECOVERABLE_REQUEST_WORKER", ""),
            "phase": environment.get("ELITE_RECOVERABLE_REQUEST_PHASE", ""),
            "plan_sha256": environment.get("PLAN_DIGEST") or None}
    backend, descriptor = backend_descriptor(policy)
    if backend == LOCAL_COMPONENTS_BACKEND:
        payload.update(sanitizer_backend=backend, local_components=descriptor)
    if environment.get("GITHUB_JOB") == "native_aggregate" and backend == GITHUB_BACKEND:
        payload["other_plan_sha256"] = environment.get("OTHER_PLAN_DIGEST") or None
    return payload


def require_owned_assignment(policy: dict, environment: dict, current: float) -> None:
    activation = policy["recoverable_activation"]
    root = Path(activation["assignment_root"])
    spaces = [Path(instance["workspace"]) for instance in activation["runners"].values()]
    config = policy.get("recoverable_shards", {})
    spaces.extend(Path(path) for path in config.get("workers", {}).values())
    spaces.extend(Path(config[name]) for name in ("cache", "legacy_cache") if name in config)
    if any(root.is_relative_to(path) or path.is_relative_to(root) for path in spaces):
        raise ValueError("Owned assignment storage overlaps mutable execution data.")
    expected = root / (assignment_digest(environment) + ".json")
    if (not root.is_absolute() or root != root.resolve()
            or environment.get("ELITE_RECOVERABLE_ASSIGNMENT_PATH") != str(expected)):
        raise ValueError("Assignment is outside host-owned authorization storage.")
    require_owned_activation_file(expected)
    binding = json.loads(expected.read_text())
    payload = assignment_payload(policy, environment)
    if (not isinstance(binding, dict) or set(binding) != set(payload) | {"expires_at", "revoked"}
            or type(binding["schema"]) is not int or type(binding["expires_at"]) not in (int, float)
            or not math.isfinite(binding["expires_at"])
            or {name: binding[name] for name in payload} != payload
            or binding["revoked"] is not False or not current < binding["expires_at"] <= activation["expires_at"]
            or environment.get("ELITE_RECOVERABLE_ASSIGNMENT_SHA256") != policy_digest(binding)):
        raise ValueError("Owned assignment is stale, revoked or differs from this exact job.")


def policy_digest(policy: dict) -> str:
    return hashlib.sha256(json.dumps(policy, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def backend_descriptor(policy):
    """Only an installed immutable approval selects the alternate full-quality backend."""
    import pwd
    activation = policy.get("recoverable_activation", {})
    backend = activation.get("sanitizer_backend", GITHUB_BACKEND)
    descriptor = activation.get("local_components")
    if backend == GITHUB_BACKEND:
        if "local_components" in activation:
            raise ValueError("Default backend cannot carry local sanitizer proof")
        return backend, None
    if backend != LOCAL_COMPONENTS_BACKEND or not isinstance(descriptor, dict) or set(descriptor) != {"path", "sha256"}:
        raise ValueError("Unknown or incomplete sanitizer backend")
    root = Path(pwd.getpwuid(os.getuid()).pw_dir) / "Library/EliteNativeAuthorization/local-quality-bindings"
    expected = root / policy["approved_head"] / "binding.json"
    if (Path(descriptor["path"]) != expected or expected != expected.resolve()
            or not re.fullmatch(r"[0-9a-f]{64}", descriptor["sha256"])):
        raise ValueError("Local components binding is outside its exact owned target namespace")
    return backend, descriptor


def phase_profile(policy, phase):
    backend, _ = backend_descriptor(policy)
    profiles = policy.get("recoverable_shards", {}).get("phase_profiles", {})
    if backend != LOCAL_COMPONENTS_BACKEND and "phase_profiles" not in policy.get("recoverable_shards", {}):
        return None
    if not isinstance(profiles, dict) or set(profiles) != {"normal", "leaks"} or phase not in profiles:
        raise ValueError("Both independent phase profiles are mandatory")
    for value in profiles.values():
        if (not isinstance(value, dict) or set(value) != {"build_profile", "admission"}
                or value["build_profile"] != PHASE_BUILD_PROFILE):
            raise ValueError("Unknown phase build profile")
        bounds = value["admission"]
        if (not isinstance(bounds, dict) or set(bounds) != {"explicit", "cpu_budget", "ram_capacity", "ram_reserve", "peak_per_worker",
                           "disk_capacity", "disk_reserve", "disk_per_worker"}
                or any(type(n) not in (int, float) or not math.isfinite(n) or n <= 0 for n in bounds.values())
                or bounds["explicit"] != 1 or bounds["cpu_budget"] != 1
                or bounds["ram_capacity"] < bounds["ram_reserve"] + bounds["peak_per_worker"]
                or bounds["disk_capacity"] < bounds["disk_reserve"] + bounds["disk_per_worker"]):
            raise ValueError("Each phase requires its own complete serial resource allocation")
    return profiles[phase]


def read_local_components_binding(policy, now=None):
    backend, descriptor = backend_descriptor(policy)
    if backend != LOCAL_COMPONENTS_BACKEND:
        raise ValueError("The local-components backend is not authorized")
    path = Path(descriptor["path"])
    require_owned_activation_file(path)
    if path.stat().st_mode & 0o777 != 0o400 or hashlib.sha256(path.read_bytes()).hexdigest() != descriptor["sha256"]:
        raise ValueError("Local components binding bytes or ownership changed")
    config = policy["recoverable_shards"]
    import pwd
    physical_lease = Path(pwd.getpwuid(os.getuid()).pw_dir) / "Library/EliteNativeCI/sanitizer-checkpoints"
    if config.get("legacy_cache") != str(physical_lease):
        raise ValueError("The selected backend must share the existing physical executor lease")
    spaces = [Path(config[name]) for name in ("cache", "legacy_cache") if name in config]
    spaces += [Path(item) for item in config.get("workers", {}).values()]
    spaces += [Path(item["workspace"]) for item in policy["recoverable_activation"].get("runners", {}).values()]
    if any(path.is_relative_to(space) or space.is_relative_to(path.parent) for space in spaces):
        raise ValueError("Local components binding overlaps mutable CI execution storage")
    value = json.loads(path.read_text())
    required = {"schema", "kind", "expires_at", "target", "original", "inputs", "semantic_environment",
                "ci_admission", "phase_profiles", "modes"}
    current = time.time() if now is None else now
    activation = policy["recoverable_activation"]
    if (not isinstance(value, dict) or set(value) != required or type(value["schema"]) is not int or value["schema"] != 1
            or value["kind"] != LOCAL_COMPONENTS_BACKEND
            or type(value["expires_at"]) not in (int, float) or not math.isfinite(value["expires_at"])
            or not current < value["expires_at"] <= activation["expires_at"]
            or set(value["target"]) != {"head", "ref", "tree"} or set(value["original"]) != {"head", "tree"}
            or value["target"]["head"] != policy["approved_head"]
            or value["target"]["ref"] != activation["workflow_ref"].split("@", 1)[1]
            or value["target"]["tree"] != value["original"]["tree"]
            or any(not re.fullmatch(r"[0-9a-f]{40}", v) for v in (
                value["target"]["head"], value["original"]["head"], value["target"]["tree"]))
            or set(value["modes"]) != {"address", "thread"}
            or value["ci_admission"] != policy["recoverable_shards"]["admission"]
            or value["phase_profiles"] != policy["recoverable_shards"].get("phase_profiles")):
        raise ValueError("Local components binding is stale or differs from the exact CI target/profile")
    phase_profile(policy, "normal")
    return value


def require_recoverable_identity(policy: dict, environment: dict, event: dict, now=None) -> dict:
    """Admit only the exact approved execution, role, runner and workspace without a job request."""
    activation = policy.get("recoverable_activation", {})
    approved = policy.get("approved_head", "")
    workflow = REPOSITORY + "/" + workflow_path(environment) + "@" + environment.get("GITHUB_REF", "")
    current = time.time() if now is None else now
    if (type(activation.get("schema")) is not int or activation.get("schema") != 1 or activation.get("enabled") is not True
            or activation.get("revoked") is not False
            or type(activation.get("expires_at")) not in (int, float)
            or not math.isfinite(activation["expires_at"])
            or not current < activation["expires_at"]
            or not re.fullmatch(r"[0-9a-f]{40}", approved)
            or activation.get("head") != approved
            or environment.get("GITHUB_SHA") != approved
            or activation.get("workflow_ref") != workflow
            or environment.get("GITHUB_WORKFLOW_REF") != workflow
            or environment.get("GITHUB_REPOSITORY") != REPOSITORY
            or environment.get("GITHUB_ACTOR_ID") != ACTOR
            or event.get("repository", {}).get("full_name") != REPOSITORY
            or event.get("repository", {}).get("fork") is not False
            or str(event.get("sender", {}).get("id")) != ACTOR
            or environment.get("GITHUB_JOB") not in RECOVERABLE_JOBS):
        raise ValueError("Recoverable native job is not explicitly activated.")
    require_recoverable_event(activation, environment, event)
    backend, _ = backend_descriptor(policy)
    if ((backend == LOCAL_COMPONENTS_BACKEND and environment["GITHUB_JOB"] not in LOCAL_COMPONENT_ROLES)
            or (backend == GITHUB_BACKEND and environment["GITHUB_JOB"] == "native_local_components")):
        raise ValueError("Native role is outside the explicitly reviewed backend")
    if backend == LOCAL_COMPONENTS_BACKEND:
        read_local_components_binding(policy, current)
    elif "phase_profiles" in policy.get("recoverable_shards", {}):
        phase_profile(policy, "normal")
    for name, field in (("ELITE_RECOVERABLE_WORKFLOW_SHA256", "workflow_sha256"),
                        ("ELITE_RECOVERABLE_ACTIVATION_SHA256", "manifest_sha256")):
        expected = activation.get(field, "")
        if not re.fullmatch(r"[0-9a-f]{64}", expected) or environment.get(name) != expected:
            raise ValueError("Recoverable native workflow/manifest attestation changed.")
    if environment.get("ELITE_RECOVERABLE_POLICY_SHA256") != policy_digest(policy):
        raise ValueError("Recoverable native policy identity changed.")
    if (environment.get("ELITE_NATIVE_APPROVED_HEAD") != approved
            or not Path(environment.get("ELITE_NATIVE_POLICY", "")).is_absolute()):
        raise ValueError("Legacy native approval/policy controls are missing or inconsistent.")
    instance = activation.get("runners", {}).get(environment.get("RUNNER_NAME"), {})
    workspace = Path(environment.get("GITHUB_WORKSPACE", ""))
    if (environment.get("GITHUB_JOB") not in instance.get("jobs", [])
            or not set(instance.get("jobs", [])) <= RECOVERABLE_JOBS
            or not workspace.is_absolute() or str(workspace) != instance.get("workspace")
            or workspace.parts[-3:] != ("_work", "l337", "l337")
            or workspace != workspace.resolve()):
        raise ValueError("Recoverable native runner/workspace is not reserved.")
    if not all(re.fullmatch(r"[1-9][0-9]*", environment.get(name, "")) for name in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")):
        raise ValueError("Recoverable job has no exact run attempt identity.")
    return activation


def require_recoverable_job(policy: dict, environment: dict, event: dict, now=None, verify_assignment=True) -> dict:
    """Require the complete request and owned assignment before any checkout or native work."""
    current = time.time() if now is None else now
    activation = require_recoverable_identity(policy, environment, event, current)
    if verify_assignment and environment.get("ELITE_RECOVERABLE_CODE_ENABLED") != "true":
        raise ValueError("Installed recoverable code was not activated by the owned hook.")
    mode, shard, worker, phase = (environment.get("ELITE_RECOVERABLE_REQUEST_" + name, "")
                                  for name in ("MODE", "SHARD", "WORKER", "PHASE"))
    job = environment["GITHUB_JOB"]
    backend, _ = backend_descriptor(policy)
    if job == "native_aggregate" and backend == GITHUB_BACKEND and not re.fullmatch(r"[0-9a-f]{64}", environment.get("OTHER_PLAN_DIGEST", "")):
        raise ValueError("The independently prepared address plan is mandatory")
    if ((job in ("prepare_native", "native_aggregate", "native_checks", "native_local_components") and any((mode, shard, worker, phase)))
            or (job == "native_phase" and (phase not in ("normal", "leaks") or any((mode, shard, worker))))
            or (job in ("prepare_thread", "prepare_address") and (mode != job.removeprefix("prepare_") or any((shard, worker, phase))))
            or (job in SHARD_JOBS and (mode not in ("thread", "address")
                or not re.fullmatch(r"[0-9a-f]{64}", shard) or worker not in ("one", "two") or phase
                or (job == "thread_shards" and mode != "thread") or (job == "address_shards" and mode != "address")))):
        raise ValueError("Recoverable role does not match its exact request type.")
    if environment["GITHUB_JOB"] not in PREPARE_JOBS:
        plan = environment.get("PLAN_DIGEST", "")
        if (not re.fullmatch(r"[0-9a-f]{64}", plan)
                or (verify_assignment and (environment.get("ELITE_RECOVERABLE_PLAN_SHA256") != plan
                    or not re.fullmatch(r"[0-9a-f]{64}", environment.get("ELITE_RECOVERABLE_ASSIGNMENT_SHA256", ""))))):
            raise ValueError("Recoverable frozen plan/assignment attestation changed.")
    elif environment.get("PLAN_DIGEST") or environment.get("ELITE_RECOVERABLE_PLAN_SHA256"):
        raise ValueError("Preparation cannot claim a preexisting frozen plan.")
    if verify_assignment:
        require_owned_assignment(policy, environment, current)
    return activation


def load_recoverable_guard(policy: dict):
    """Only the separately installed, hash-pinned host package may authorize before checkout."""
    import importlib
    directory = Path(__file__).resolve().parent
    spaces = [Path(instance["workspace"]) for instance in policy["recoverable_activation"]["runners"].values()]
    config = policy["recoverable_shards"]
    spaces.extend(Path(path) for path in config["workers"].values())
    spaces.extend(Path(config[name]) for name in ("cache", "legacy_cache"))
    if any(directory.is_relative_to(path) or path.is_relative_to(directory) for path in spaces):
        raise ValueError("Installed guard overlaps mutable checkouts/cache.")
    require_owned_activation_file(Path(__file__))
    if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != policy["guard_sha256"]:
        raise ValueError("Installed native guard bytes changed.")
    required = {"recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"}
    hashes = policy["recoverable_activation"]["guard_files"]
    if set(hashes) != required:
        raise ValueError("Installed recoverable guard package is incomplete.")
    for name, digest in hashes.items():
        path = directory / name
        require_owned_activation_file(path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError("Installed recoverable guard dependency changed.")
    module = importlib.import_module("recoverable_shards")
    if Path(module.__file__).resolve() != directory / "recoverable_shards.py":
        raise ValueError("Recoverable guard was imported from outside the owned package.")
    return module


def authorize_recoverable(policy: dict, environment: dict, event: dict, api=None, guard=None, now=None) -> dict:
    """Pre-job hook: authenticate GitHub source/plan, then issue one owned run-attempt assignment."""
    require_diagnostic_custody_clear()
    current = time.time() if now is None else now
    activation, value = policy["recoverable_activation"], dict(environment)
    value.update(ELITE_RECOVERABLE_POLICY_SHA256=policy_digest(policy),
                 ELITE_RECOVERABLE_WORKFLOW_SHA256=activation["workflow_sha256"],
                 ELITE_RECOVERABLE_ACTIVATION_SHA256=activation["manifest_sha256"])
    require_recoverable_job(policy, value, event, current, verify_assignment=False)
    manifest = json.loads(value["ACTIVATION"])
    policies = json.loads(value["POLICY_DIGESTS"])
    if (policy_digest(manifest) != activation["manifest_sha256"]
            or set(policies) != set(activation["runners"])
            or set(policies.values()) != {policy_digest(policy)}
            or policies.get(value["RUNNER_NAME"]) != policy_digest(policy)
            or manifest["ref"] != value["GITHUB_REF"]
            or any(manifest[name] != activation[name] for name in (
                "schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256", "runners", "assignment_root"))):
        raise ValueError("Job activation variables differ from the host-owned approval.")
    for name in ("pr_head", "reusable_workflow_sha256", "sanitizer_backend", "local_components"):
        if manifest.get(name) != activation.get(name):
            raise ValueError("Owned caller/PR activation facts differ.")
    guard = load_recoverable_guard(policy) if guard is None else guard
    if not guard.PHYSICAL_EXECUTION_ENABLED:
        raise ValueError("Recoverable native execution HELD by the installed guard.")
    backend, _ = backend_descriptor(policy)
    if backend == LOCAL_COMPONENTS_BACKEND:
        read_local_components_binding(policy, current)
    token = value.get("GITHUB_TOKEN") or value.get("GH_TOKEN")
    if not token:
        raise ValueError("Pre-job artifact read credentials are unavailable.")
    value["GITHUB_TOKEN"], value["GH_TOKEN"] = token, token
    api = api or (lambda path: json.loads(subprocess.check_output(
        ["gh", "api", path], env=value, stderr=subprocess.PIPE, timeout=60)))
    source = api(f"repos/{REPOSITORY}/contents/{workflow_path(value)}?ref={policy['approved_head']}")
    if (source["encoding"] != "base64" or hashlib.sha256(base64.b64decode(source["content"])).hexdigest()
            != activation["workflow_sha256"]):
        raise ValueError("GitHub workflow bytes differ from host approval.")
    if workflow_path(value).endswith("ci.yml"):
        called = api(f"repos/{REPOSITORY}/contents/.github/workflows/recoverable-quality.yml?ref={policy['approved_head']}")
        if hashlib.sha256(base64.b64decode(called["content"])).hexdigest() != activation.get("reusable_workflow_sha256"):
            raise ValueError("Called quality workflow differs from host approval.")
    entries = api(f"repos/{REPOSITORY}/contents/Tools/CI?ref={policy['approved_head']}")
    blobs = {entry["name"]: entry["sha"] for entry in entries if entry["type"] == "file"}
    for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                 "quality_phase_checkpoints.py", "crash_artifacts.py"):
        raw = (Path(__file__).resolve().parent / name).read_bytes()
        # Git's blob format is SHA-1; the installed package also has independent SHA-256 pins.
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw, usedforsecurity=False).hexdigest()
        if blobs.get(name) != blob:
            raise ValueError("Installed authorizer package differs from the approved commit.")
    from types import SimpleNamespace
    config = policy["recoverable_shards"]
    authority = SimpleNamespace(environment=value, policy=policy, config=config, cache=Path(config["cache"]),
                                workers={name: Path(path) for name, path in config["workers"].items()})
    remote = guard.GitHubArtifacts(authority, api=api)
    if value["GITHUB_JOB"] not in PREPARE_JOBS:
        artifact_id = value.get("PLAN_ID", "")
        if not re.fullmatch(r"[1-9][0-9]*", artifact_id):
            raise ValueError("No trusted prepared artifact identity.")
        artifact = api(f"repos/{REPOSITORY}/actions/artifacts/{artifact_id}")
        if not artifact["name"].startswith("native-plan-"):
            raise ValueError("Pre-job artifact is not an owned prepared plan.")
        bundle = remote.fetch(artifact, value.get("PLAN_ARCHIVE"))
        plans, manifest = guard.NativeWorkflow(authority, remote).plans(bundle, value["PLAN_DIGEST"])
        if manifest["host"] != config["host"]:
            raise ValueError("Prepared plan belongs to another physical host.")
        if backend == LOCAL_COMPONENTS_BACKEND and {p["runtime"]["mode"] for p in plans} != {"address"}:
            raise ValueError("Local-components CI phases require their actual address anchor")
        if value["GITHUB_JOB"] in SHARD_JOBS:
            assignment = {"mode": value.get("ELITE_RECOVERABLE_REQUEST_MODE"),
                          "shard": value.get("ELITE_RECOVERABLE_REQUEST_SHARD"),
                          "worker": value.get("ELITE_RECOVERABLE_REQUEST_WORKER")}
            if assignment not in manifest["expected"]:
                raise ValueError("This worker/shard is not in the authenticated frozen plan.")
        if value["GITHUB_JOB"] == "native_phase" and value.get("ELITE_RECOVERABLE_REQUEST_PHASE") not in manifest["phases"]:
            raise ValueError("This phase is not in the authenticated frozen plan.")
        if value["GITHUB_JOB"] == "native_aggregate" and backend == GITHUB_BACKEND:
            other_id = value.get("OTHER_PLAN_ID", "")
            if not re.fullmatch(r"[1-9][0-9]*", other_id):
                raise ValueError("Aggregate requires the independent address plan artifact.")
            other_artifact = api(f"repos/{REPOSITORY}/actions/artifacts/{other_id}")
            if not other_artifact["name"].startswith("native-plan-"):
                raise ValueError("Aggregate second artifact is not a mode plan.")
            other_bundle = remote.fetch(other_artifact, value.get("OTHER_PLAN_ARCHIVE"))
            other_plans, _ = guard.NativeWorkflow(authority, remote).plans(other_bundle, value["OTHER_PLAN_DIGEST"])
            if ({p["runtime"]["mode"] for p in plans} != {"thread"}
                    or {p["runtime"]["mode"] for p in other_plans} != {"address"}):
                raise ValueError("Aggregate mode prerequisites differ.")
        value["ELITE_RECOVERABLE_PLAN_SHA256"] = value["PLAN_DIGEST"]
    root = Path(activation["assignment_root"])
    workspace = Path(value["GITHUB_WORKSPACE"])
    if root.is_relative_to(workspace) or workspace.is_relative_to(root):
        raise ValueError("Owned assignment storage overlaps the job checkout.")
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    binding = {**assignment_payload(policy, value), "expires_at": min(activation["expires_at"], current + 28800),
               "revoked": False}
    path = root / (assignment_digest(value) + ".json")
    if path.exists():
        require_owned_activation_file(path)
        prior = json.loads(path.read_text())
        payload = assignment_payload(policy, value)
        if ({name: prior[name] for name in payload} != payload or prior["revoked"] is not False
                or not current < prior["expires_at"] <= activation["expires_at"]):
            raise ValueError("An existing assignment cannot be overwritten.")
        binding = prior
    else:
        temporary = path.with_suffix(".pending")
        with temporary.open("x") as output:
            json.dump(binding, output, sort_keys=True)
            output.flush()
            os.fsync(output.fileno())
        temporary.chmod(0o400)
        temporary.replace(path)
        descriptor = os.open(root, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    value.update(ELITE_RECOVERABLE_ASSIGNMENT_PATH=str(path),
                 ELITE_RECOVERABLE_ASSIGNMENT_SHA256=policy_digest(binding), ELITE_RECOVERABLE_CODE_ENABLED="true")
    require_recoverable_job(policy, value, event, current)
    return value


def require_owned_activation_file(path: Path) -> None:
    """The optional extension cannot come from a linked or writable policy ancestry."""
    for node in (path, *path.parents):
        info = node.lstat()
        sticky_system_parent = node != path and info.st_uid == 0 and info.st_mode & 0o1000
        if node.is_symlink() or info.st_uid not in (0, os.getuid()) or (info.st_mode & 0o022 and not sticky_system_parent):
            raise ValueError("Activation policy ancestry is not immutable and owned.")
    if path.stat().st_uid != os.getuid():
        raise ValueError("Activation policy must belong to the runner owner.")


def require_recoverable_session(policy: dict, environment: dict, now=None) -> None:
    """Recheck the existing immutable session ticket in both admission and authorization."""
    import pwd
    current = time.time() if now is None else now
    root = Path(pwd.getpwuid(os.getuid()).pw_dir) / "Library/EliteNativeCI/recoverable-sessions"

    def read(path):
        require_owned_activation_file(path)
        if path.stat().st_mode & 0o777 != 0o400:
            raise ValueError("Session evidence is not immutable.")
        return json.loads(path.read_text())

    ticket = read(root / "ticket.json")
    if (not isinstance(ticket, dict)
            or set(ticket) != {"binding", "binding_sha256", "ordinal", "policy_sha256"}
            or not isinstance(ticket["binding"], str)
            or ticket["policy_sha256"] != policy_digest(policy)):
        raise ValueError("Session ticket differs from the installed policy.")
    path = Path(ticket["binding"])
    if path.parent != root or path.suffix != ".json":
        raise ValueError("Session binding is outside owned storage.")
    binding = read(path)
    if (not isinstance(binding, dict)
            or hashlib.sha256(path.read_bytes()).hexdigest() != ticket["binding_sha256"]
            or set(binding) != {"schema", "policy_sha256", "head", "run_id", "run_attempt", "max_jobs", "expires_at"}
            or type(binding["schema"]) is not int or binding["schema"] != 1
            or binding["policy_sha256"] != policy_digest(policy) or binding["head"] != policy["approved_head"]
            or type(ticket["ordinal"]) is not int or type(binding["max_jobs"]) is not int
            or not 1 <= ticket["ordinal"] <= binding["max_jobs"] <= 256
            or type(binding["expires_at"]) not in (int, float) or not math.isfinite(binding["expires_at"])
            or not current < binding["expires_at"] <= policy["recoverable_activation"]["expires_at"]
            or environment.get("GITHUB_RUN_ID") != binding["run_id"]
            or environment.get("GITHUB_RUN_ATTEMPT") != binding["run_attempt"]):
        raise ValueError("Session run, attempt, budget or expiry is not authorized.")


def admit_recoverable(policy: dict, environment: dict, event: dict, now=None) -> Path:
    """Check the installed session and host; never infer or authorize a job request."""
    require_diagnostic_custody_clear()
    activation = policy["recoverable_activation"]
    environment.update(ELITE_RECOVERABLE_POLICY_SHA256=policy_digest(policy),
                       ELITE_RECOVERABLE_WORKFLOW_SHA256=activation["workflow_sha256"],
                       ELITE_RECOVERABLE_ACTIVATION_SHA256=activation["manifest_sha256"])
    require_recoverable_session(policy, environment, now)
    require_recoverable_identity(policy, environment, event, now)
    guard = load_recoverable_guard(policy)
    if not guard.PHYSICAL_EXECUTION_ENABLED:
        raise ValueError("Recoverable native execution HELD by the installed guard.")
    return require_recoverable_host(policy, environment)


def require_trusted_job(environment: dict, event: dict, approved_head: str) -> None:
    """Reject all other repositories, actors, workflows, forks and source revisions."""
    if not re.fullmatch(r"[0-9a-f]{40}", approved_head):
        raise ValueError("Invalid approved source identity.")
    repository = event.get("repository", {})
    if not (environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_ACTOR_ID") == ACTOR
            and environment.get("GITHUB_JOB") == "quality"
            and repository.get("full_name") == REPOSITORY
            and repository.get("fork") is False
            and str(event.get("sender", {}).get("id")) == ACTOR):
        raise ValueError("Native quality accepts only the approved internal job.")
    workflow = environment.get("GITHUB_WORKFLOW_REF", "")
    if not workflow.startswith(REPOSITORY + "/.github/workflows/ci.yml@refs/"):
        raise ValueError("Native quality requires its reviewed CI workflow.")
    name = environment.get("GITHUB_EVENT_NAME")
    if name == "pull_request":
        pull = event.get("pull_request", {})
        head = pull.get("head", {})
        base = pull.get("base", {})
        valid = (head.get("sha") == approved_head
                 and head.get("repo", {}).get("full_name") == REPOSITORY
                 and head.get("repo", {}).get("fork") is False
                 and base.get("repo", {}).get("full_name") == REPOSITORY
                 and base.get("ref") == "main"
                 and str(pull.get("user", {}).get("id")) == ACTOR)
    elif name == "push":
        valid = (environment.get("GITHUB_REF") == "refs/heads/main"
                 and event.get("ref") == "refs/heads/main"
                 and event.get("after") == approved_head
                 and environment.get("GITHUB_SHA") == approved_head
                 and event.get("deleted") is False
                 and event.get("forced") is False)
    elif name == "workflow_dispatch":
        valid = (environment.get("GITHUB_SHA") == approved_head
                 and environment.get("GITHUB_REF", "").startswith("refs/heads/"))
    else:
        valid = False
    if not valid:
        raise ValueError("Native quality source or event is not approved.")


def output(*args: str) -> str:
    """Read a tool identity without shell interpolation."""
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def require_physical_host(policy: dict, environment: dict) -> Path:
    """Keep this runner separate from the VM and confined to its owned checkout."""
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("Native quality requires the physical Apple Silicon Mac.")
    if output("sysctl", "-n", "hw.model").startswith("VirtualMac"):
        raise ValueError("The isolated VM is not the native quality runner.")
    root = Path(policy["runner_root"]).resolve()
    workspace = Path(environment["GITHUB_WORKSPACE"]).resolve()
    if workspace != root / "_work" / "l337" / "l337":
        raise ValueError("Native quality requires its dedicated owned checkout.")
    if environment.get("DEVELOPER_DIR") != policy["developer_dir"]:
        raise ValueError("Native quality developer directory changed.")
    if output("swift", "--version") != policy["swift"]:
        raise ValueError("Native quality compiler changed.")
    if output("xcrun", "--sdk", "macosx", "--show-sdk-version") != policy["sdk"]:
        raise ValueError("Native quality SDK changed.")
    return workspace


def require_recoverable_host(policy: dict, environment: dict) -> Path:
    """Check the reserved physical host without granting a request or assignment."""
    activation = policy["recoverable_activation"]
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("Recoverable native jobs require physical Apple Silicon.")
    hardware = output("ioreg", "-rd1", "-c", "IOPlatformExpertDevice")
    uuids = re.findall(r'"IOPlatformUUID"\s*=\s*"([0-9A-Fa-f-]{36})"', hardware)
    if len(uuids) != 1 or uuids[0].upper() != policy["recoverable_shards"]["host"]:
        raise ValueError("Recoverable job is assigned to another physical host.")
    # One shared host-owned policy may name multiple exact runner instances.
    instance = activation["runners"][environment["RUNNER_NAME"]]
    root = Path(instance["workspace"]).parents[2]
    return require_physical_host(dict(policy, runner_root=str(root)), environment)


def validate(policy: dict, environment: dict) -> Path:
    """Validate the immutable pre-job metadata before any workflow checkout or action."""
    require_diagnostic_custody_clear()
    event = json.loads(Path(environment["GITHUB_EVENT_PATH"]).read_text())
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        require_recoverable_job(policy, environment, event)
        return require_recoverable_host(policy, environment)
    else:
        require_trusted_job(environment, event, policy["approved_head"])
    return require_physical_host(policy, environment)


def require_recoverable_checkout(policy: dict, environment: dict, workspace: Path) -> None:
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        path = workspace / workflow_path(environment)
        if (path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()
                != policy["recoverable_activation"]["workflow_sha256"]):
            raise ValueError("Checked-out recoverable workflow bytes changed.")
        if workflow_path(environment).endswith("ci.yml"):
            called = workspace / ".github/workflows/recoverable-quality.yml"
            if called.is_symlink() or hashlib.sha256(called.read_bytes()).hexdigest() != policy["recoverable_activation"].get("reusable_workflow_sha256"):
                raise ValueError("Checked-out called quality workflow bytes changed.")


def main() -> None:
    """Admit in the hook, authorize with step env, or recheck the exact checkout."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", default=os.environ.get("ELITE_NATIVE_POLICY"))
    stage = parser.add_mutually_exclusive_group()
    stage.add_argument("--checkout", action="store_true")
    stage.add_argument("--admit", action="store_true")
    stage.add_argument("--authorize", action="store_true")
    args = parser.parse_args()
    if not args.policy:
        raise ValueError("A host-owned native policy is required.")
    policy_path = Path(args.policy)
    if policy_path.is_symlink() or policy_path.stat().st_uid != os.getuid() or policy_path.stat().st_mode & 0o022:
        raise ValueError("Native policy must be an owned physical file.")
    policy = json.loads(policy_path.read_text())
    if "recoverable_activation" in policy:
        require_owned_activation_file(policy_path)
    environment = dict(os.environ)
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        if (environment.get("ELITE_NATIVE_POLICY", str(policy_path.resolve())) != str(policy_path.resolve())
                or environment.get("ELITE_NATIVE_APPROVED_HEAD", policy["approved_head"]) != policy["approved_head"]):
            raise ValueError("Hook arguments differ from the native approval environment.")
        environment.update(ELITE_NATIVE_POLICY=str(policy_path.resolve()), ELITE_NATIVE_APPROVED_HEAD=policy["approved_head"])
    recoverable = environment.get("GITHUB_JOB") in RECOVERABLE_JOBS
    if (args.admit or args.authorize) and not recoverable:
        raise ValueError("Only reviewed recoverable jobs use split authorization.")
    if not args.checkout and recoverable:
        event = json.loads(Path(environment["GITHUB_EVENT_PATH"]).read_text())
        workspace = admit_recoverable(policy, environment, event)
        if not args.admit:
            environment = authorize_recoverable(policy, environment, event)
    else:
        workspace = validate(policy, environment)
    if args.checkout:
        if Path.cwd().resolve() != workspace:
            raise ValueError("Native quality checkout location changed.")
        if output("git", "rev-parse", "HEAD") != environment.get("GITHUB_SHA"):
            raise ValueError("Native checkout does not match the assigned revision.")
        require_recoverable_checkout(policy, environment, workspace)
        from local_runner import cache_key, clean_checkout, prepare_build_cache
        prepare_build_cache(workspace, cache_key(workspace, policy["swift"], policy["sdk"]))
        clean_checkout(workspace)
    else:
        # The hook is installed outside the runner/checkout and executes before workflow steps.
        with Path(environment["GITHUB_ENV"]).open("a") as destination:
            destination.write("ELITE_NATIVE_APPROVED_HEAD=" + policy["approved_head"] + "\n")
            destination.write("ELITE_NATIVE_POLICY=" + str(policy_path.resolve()) + "\n")
            if recoverable:
                names = ("ELITE_RECOVERABLE_POLICY_SHA256", "ELITE_RECOVERABLE_WORKFLOW_SHA256",
                         "ELITE_RECOVERABLE_ACTIVATION_SHA256")
                if not args.admit:
                    names += ("ELITE_RECOVERABLE_ASSIGNMENT_PATH", "ELITE_RECOVERABLE_ASSIGNMENT_SHA256",
                              "ELITE_RECOVERABLE_CODE_ENABLED", "ELITE_RECOVERABLE_PLAN_SHA256")
                for name in names:
                    if name in environment:
                        destination.write(name + "=" + environment[name] + "\n")
    print(json.dumps({"approvedHead": policy["approved_head"], "physicalHost": True,
                      "swift": policy["swift"], "sdk": policy["sdk"]}))


_AUTHORIZATION_FAILURE_SITES = {
    "main": ("hook", "policy-environment-or-publication"),
    "authorize_recoverable": ("pre-job", "source-plan-assignment"),
    "require_recoverable_job": ("pre-job", "exact-job-contract"),
    "require_recoverable_identity": ("pre-job", "exact-job-contract"),
    "require_recoverable_session": ("admission", "exact-session"),
    "admit_recoverable": ("admission", "installed-package-and-host"),
    "require_recoverable_event": ("pre-job", "execution-source-ref"),
    "require_owned_assignment": ("pre-job", "owned-assignment"),
    "load_recoverable_guard": ("pre-job", "installed-package"),
    "require_owned_activation_file": ("policy", "owned-file"),
    "validate": ("host", "platform-hardware-validation"),
    "require_recoverable_host": ("host", "platform-hardware-validation"),
    "require_physical_host": ("host", "physical-runner-contract"),
    "output": ("host", "external-tool"),
    "require_recoverable_checkout": ("checkout", "workflow-source"),
    "require_trusted_job": ("legacy", "trusted-job-identity"),
}


def authorization_failure(error: BaseException) -> dict:
    """Emit only fixed code-site/category labels, never exception or context contents."""
    import sys
    # The already loaded helper is hash-pinned by load_recoverable_guard. Do not import here.
    helper = sys.modules.get("recoverable_shards")
    function = getattr(helper, "require_artifact_run_provenance", None)
    helper_code = getattr(function, "__code__", None)
    helper_path = str(Path(__file__).with_name("recoverable_shards.py"))
    stage, predicate, line = "unknown", "unknown", None
    frame = error.__traceback__
    while frame is not None:
        # Only code metadata is inspected. Never access frame locals or format a traceback.
        code = frame.tb_frame.f_code
        if code.co_filename == __file__:
            line = frame.tb_lineno
            site = _AUTHORIZATION_FAILURE_SITES.get(code.co_name)
            if site is not None:
                stage, predicate = site
        elif code is helper_code and code.co_filename == helper_path:
            stage, predicate, line = "artifact", "run-provenance", frame.tb_lineno
        frame = frame.tb_next
    category = "unknown"
    for kind, label in ((KeyError, "KeyError"), (OSError, "OSError"),
                        (ValueError, "ValueError"), (subprocess.SubprocessError, "SubprocessError")):
        if isinstance(error, kind):
            category = label
            break
    return {"stage": stage, "predicate": predicate, "category": category, "owned_line": line}


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        # Do not print event payloads, commands or registration credentials on a public job.
        raise SystemExit("Native quality authorization failed: "
                         + json.dumps(authorization_failure(error), sort_keys=True)) from None
