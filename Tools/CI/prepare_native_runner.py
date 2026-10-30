"""Prepare an ephemeral physical runner with an immutable, host-owned exact-head hook."""

import argparse
from contextlib import contextmanager
from contextvars import ContextVar
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import tarfile
import time
import uuid

import native_runner

ROOT = Path(__file__).resolve().parents[2]
HOME_ROOT = native_runner.diagnostic_custody_root().parent
RUNNER = HOME_ROOT / "native-runner"
AUTHORIZATION_ROOT = Path.home() / "Library/EliteNativeAuthorization"
DEVELOPER = "/Applications/Xcode.app/Contents/Developer"


def output(*args: str, environment: dict) -> str:
    """Capture non-secret tool identities without shell interpretation."""
    _require_provisioning(executor=True)
    return subprocess.check_output(args, cwd=ROOT, env=environment, text=True,
                                   stderr=subprocess.PIPE).strip()


def ensure_owned_directory(path: Path) -> None:
    """Create private trust directories and reject writable or substituted parents."""
    if path.is_symlink():
        raise ValueError("Runner trust directory must be physical.")
    if not path.exists():
        ensure_owned_directory(path.parent)
        path.mkdir(mode=0o700)
    if (not path.is_dir() or path.stat().st_uid != os.getuid()
            or path.stat().st_mode & 0o022):
        raise ValueError("Runner trust directory must be owned and not publicly writable.")


def _prepare_locked(approved: str, archive: Path, archive_hash: str, reviewed_policy=None, policy_sha256=None, registered=False) -> Path:
    """Install only a verified runner archive and reviewed guard into dedicated owned paths."""
    if not re.fullmatch(r"[0-9a-f]{40}", approved):
        raise ValueError("Invalid approved source identity.")
    if not re.fullmatch(r"[0-9a-f]{64}", archive_hash):
        raise ValueError("A verified runner archive digest is required.")
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    if output("git", "rev-parse", "HEAD", environment=environment) != approved:
        raise ValueError("Prepare from the exact approved checkout.")
    if output("git", "status", "--porcelain", environment=environment):
        raise ValueError("Prepare from a clean committed checkout.")
    guard = ROOT / "Tools/CI/native_runner.py"
    archive = archive.resolve(strict=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != archive_hash:
        raise ValueError("Runner archive digest differs from the verified release asset.")
    authorization = AUTHORIZATION_ROOT / approved
    if any(character.isspace() for character in str(authorization)):
        raise ValueError("The runner dispatches its hook through a shell; its path must not contain whitespace.")
    if any(character.isspace() for character in str(RUNNER)):
        raise ValueError("The runner dispatches temporary scripts through a shell; its root must not contain whitespace.")
    guard_copy = authorization / "guard.py"
    policy = authorization / "policy.json"
    hook = authorization / "job-started.sh"
    guard_bytes = guard.read_bytes()
    expected_policy = {
        "approved_head": approved, "runner_root": str(RUNNER), "developer_dir": DEVELOPER,
        "swift": output("swift", "--version", environment=environment),
        "sdk": output("xcrun", "--sdk", "macosx", "--show-sdk-version", environment=environment),
        "guard_sha256": hashlib.sha256(guard_bytes).hexdigest(),
        "runner_archive_sha256": archive_hash,
    }
    helpers = []
    if reviewed_policy is not None:
        if guard.is_symlink():
            raise ValueError("Reviewed guard source must be a physical file.")
        expected_policy = reviewed_recoverable_policy(reviewed_policy, policy_sha256, expected_policy)
        authorization = authorization / ("recoverable-" + policy_sha256)
        guard_copy, policy, hook = (authorization / name for name in ("native_runner.py", "policy.json", "job-started.sh"))
        helpers = [(authorization / name, (ROOT / "Tools/CI" / name).read_bytes(), 0o400)
                   for name in expected_policy["recoverable_activation"]["guard_files"]]
    policy_bytes = (json.dumps(expected_policy, indent=2) + "\n").encode()
    hook_bytes = ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 "
                  + shlex.quote(str(guard_copy)) + " --policy " + shlex.quote(str(policy)) + "\n").encode()
    if reviewed_policy is not None:
        hook_bytes = session_hook(policy, guard_copy)
    ensure_owned_directory(HOME_ROOT)
    ensure_owned_directory(authorization.parent)
    if RUNNER.is_symlink():
        raise ValueError("Runner directory must be physical.")
    if RUNNER.exists():
        if (not RUNNER.is_dir() or RUNNER.stat().st_uid != os.getuid()
                or RUNNER.stat().st_mode & 0o022):
            raise ValueError("Existing runner directory is not owned by this setup.")
        marker = RUNNER / ".elite-native-owner"
        if marker.is_symlink() or not marker.is_file() or marker.read_text() != "stephenlclarke/l337\n":
            raise ValueError("Existing runner ownership marker differs.")
        if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
            if not (reviewed_policy is not None and registered):
                raise ValueError("The previous runner registration is still active.")
            require_registration(expected_policy)
    else:
        RUNNER.mkdir(mode=0o700)
        with tarfile.open(archive) as source:
            source.extractall(RUNNER, filter="data")
        (RUNNER / ".elite-native-owner").write_text("stephenlclarke/l337\n")
    verify_installed_archive(RUNNER, archive)
    installation = RUNNER / ".elite-native-installation.json"
    installation_bytes = (json.dumps({"archive_sha256": archive_hash}) + "\n").encode()
    if installation.is_symlink():
        raise ValueError("Installation provenance must be physical.")
    if installation.exists():
        if (not installation.is_file() or installation.stat().st_uid != os.getuid()
                or installation.stat().st_mode & 0o777 != 0o400
                or installation.read_bytes() != installation_bytes):
            raise ValueError("Existing immutable installation provenance differs.")
    else:
        with installation.open("xb") as destination:
            destination.write(installation_bytes)
        installation.chmod(0o400)
    files = [(guard_copy, guard_bytes, 0o500), (policy, policy_bytes, 0o400),
             (hook, hook_bytes, 0o500), *helpers]
    if authorization.is_symlink():
        raise ValueError("Authorization directory must be physical.")
    if authorization.exists():
        ensure_owned_directory(authorization)
        for path, expected, mode in files:
            if (path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid()
                    or path.stat().st_mode & 0o777 != mode or path.read_bytes() != expected):
                raise ValueError("Existing immutable authorization differs; preserving it.")
    else:
        ensure_owned_directory(authorization.parent)
        authorization.mkdir(parents=True, exist_ok=False, mode=0o700)
        for path, data, mode in files:
            with path.open("xb") as destination:
                destination.write(data)
                destination.flush()
                os.fsync(destination.fileno())
            path.chmod(mode)
    if (RUNNER / ".env").is_symlink():
        raise ValueError("Runner environment file is not physical.")
    environment_bytes = "ACTIONS_RUNNER_HOOK_JOB_STARTED=" + str(hook) + "\nDEVELOPER_DIR=" + DEVELOPER + "\n"
    if registered and (RUNNER / ".env").read_text() != environment_bytes:
        raise ValueError("An active registration uses a different hook; preserving it.")
    (RUNNER / ".env").write_text(environment_bytes)
    (RUNNER / ".env").chmod(0o600)
    return policy


def prepare(approved: str, archive: Path, archive_hash: str, reviewed_policy=None, policy_sha256=None, registered=False) -> Path:
    """Acquire common custody before the first source/tool probe or installation."""
    with recoverable_control(), quiescent_legacy():
        if registered:
            if reviewed_policy is None:
                raise ValueError("A caller flag cannot authorize an existing registration.")
            _registered_slot_proof(owned_json(reviewed_policy))
        return _prepare_locked(approved, archive, archive_hash, reviewed_policy, policy_sha256, registered)


def verify_installed_archive(root: Path, archive: Path) -> None:
    """Bind every reused archive file/link to the verified installation, not just its marker."""
    with tarfile.open(archive) as source:
        for member in source.getmembers():
            relative = Path(member.name)
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError("Runner archive has an unsafe member path.")
            installed = root / relative
            if member.isdir():
                if installed.is_symlink() or not installed.is_dir():
                    raise ValueError("Installed runner directory differs from archive.")
            elif member.issym():
                if (not installed.is_symlink() or os.readlink(installed) != member.linkname
                        or not installed.resolve().is_relative_to(root.resolve())):
                    raise ValueError("Installed runner link differs from archive.")
            elif member.isfile() or member.islnk():
                stream = source.extractfile(member)
                if (stream is None or installed.is_symlink() or not installed.is_file()
                        or hashlib.sha256(stream.read()).digest()
                        != hashlib.sha256(installed.read_bytes()).digest()):
                    raise ValueError("Installed runner bytes differ from verified archive.")
            else:
                raise ValueError("Runner archive has an unsupported member kind.")


def _register_locked(runner_name="elite-mbp-native", deadline=None, descriptors=()) -> None:
    """Use one repository registration token without printing or persisting it ourselves."""
    _require_provisioning(executor=True)
    def bounds():
        if deadline is None:
            return {}
        remaining = deadline - time.time()
        if remaining <= 0:
            raise ValueError("Registration deadline expired.")
        return {"timeout": min(60, remaining), "pass_fds": tuple(descriptors)}
    result = subprocess.run(
        ["gh", "api", "--method", "POST", "repos/stephenlclarke/l337/actions/runners/registration-token"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **bounds())
    if result.returncode:
        raise ValueError("Repository runner registration token was unavailable.")
    token = json.loads(result.stdout)["token"]
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    configured = subprocess.run(
        [str(RUNNER / "config.sh"), "--url", "https://github.com/stephenlclarke/l337",
         "--token", token, "--name", runner_name, "--labels", "elite-native",
         "--work", "_work", "--unattended", "--ephemeral", "--disableupdate"],
        cwd=RUNNER, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **bounds())
    if configured.returncode:
        raise ValueError("Ephemeral runner registration failed.")
    print("Ephemeral native runner registered with its host-owned exact-head hook.")


def register_and_run(run: bool, runner_name="elite-mbp-native", deadline=None, descriptors=()) -> None:
    """Configure under both leases, then release executor custody before listening."""
    with recoverable_control() as control:
        if run and _require_provisioning().executor is not None:
            raise ValueError("A listener cannot inherit a parent-held executor lease.")
        with quiescent_legacy():
            _register_locked(runner_name, deadline, (*descriptors, control.fileno()))
        if run:
            _require_provisioning()
            remaining = None if deadline is None else deadline - time.time()
            if remaining is not None and remaining <= 0:
                raise ValueError("Registration deadline expired before listening.")
            completed = subprocess.run([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER,
                env={**{key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")},
                     "DEVELOPER_DIR": DEVELOPER}, pass_fds=(control.fileno(),), timeout=remaining)
            if completed.returncode:
                raise ValueError("Ephemeral runner process failed.")



RECOVERABLE_ROLES = {"native_checks", "prepare_thread", "prepare_address", "native_phase",
                     "thread_shards", "address_shards", "native_aggregate"}
ASAN_RECOVERABLE_ROLES = {"native_checks", "prepare_address", "address_shards"}
NORMAL_CI_ROLES = {"native_checks"}
MAX_SESSION_SECONDS = 7 * 86400


def owned_json(path):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve():
        raise ValueError("Owned input must be an absolute physical path.")
    from native_runner import require_owned_activation_file
    require_owned_activation_file(path)
    if path.stat().st_mode & 0o777 != 0o400:
        raise ValueError("Reviewed/session input must be immutable and owned.")
    return json.loads(path.read_text())


def publish_json(path, value, immutable=False):
    """Keep budget/session state durable before any registration can occur."""
    ensure_owned_directory(path.parent)
    if path.is_symlink():
        raise ValueError("Session state must be physical.")
    temporary = path.with_name(path.name + ".pending-" + str(uuid.uuid4()))
    with temporary.open("x") as destination:
        json.dump(value, destination, sort_keys=True, allow_nan=False)
        destination.write("\n")
        destination.flush()
        os.fsync(destination.fileno())
    temporary.chmod(0o400 if immutable else 0o600)
    temporary.replace(path)
    descriptor = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def reviewed_recoverable_policy(path, checksum, base):
    """Install an explicitly reviewed contract; never synthesize a broader authorization."""
    from native_runner import policy_digest, backend_descriptor, read_local_components_binding, LOCAL_COMPONENTS_BACKEND, LOCAL_COMPONENT_ROLES
    path = Path(path)
    if path.is_relative_to(ROOT) or path.is_relative_to(RUNNER):
        raise ValueError("Reviewed policy must be outside checkout and runner data.")
    value = owned_json(path)
    if (not re.fullmatch(r"[0-9a-f]{64}", checksum or "")
            or hashlib.sha256(path.read_bytes()).hexdigest() != checksum
            or set(value) != set(base) | {"recoverable_activation", "recoverable_shards"}
            or any(value[name] != expected for name, expected in base.items())):
        raise ValueError("Reviewed recoverable policy differs from source/archive/toolchain.")
    activation, config = value["recoverable_activation"], value["recoverable_shards"]
    required = {"schema", "enabled", "revoked", "expires_at", "head", "workflow_ref", "workflow_sha256",
                "reusable_workflow_sha256", "manifest_sha256", "runners", "assignment_root", "guard_files"}
    if (not required <= set(activation) or set(activation) - required - {"pr_head", "sanitizer_backend", "local_components"}
            or type(activation["schema"]) is not int or activation["schema"] != 1
            or activation["enabled"] is not True or activation["revoked"] is not False
            or type(activation["expires_at"]) not in (int, float) or not math.isfinite(activation["expires_at"])
            or not time.time() < activation["expires_at"] <= time.time() + MAX_SESSION_SECONDS
            or activation["head"] != base["approved_head"]):
        raise ValueError("Recoverable activation is missing, expired or outside its finite bound.")
    prefix = "stephenlclarke/l337/.github/workflows/ci.yml@"
    if not activation["workflow_ref"].startswith(prefix):
        raise ValueError("Installer supports only the actual required CI caller.")
    ref = activation["workflow_ref"].removeprefix(prefix)
    if ref != "refs/heads/main" and not re.fullmatch(r"refs/pull/[1-9][0-9]*/merge", ref):
        raise ValueError("Recoverable CI ref is outside main/internal PR execution.")
    if ref == "refs/heads/main" and "pr_head" in activation:
        raise ValueError("Main approval must not substitute a PR source identity.")
    if ref.startswith("refs/pull/") and not re.fullmatch(r"[0-9a-f]{40}", activation.get("pr_head", "")):
        raise ValueError("PR source and execution heads must be separately approved.")
    for name, field in (("ci.yml", "workflow_sha256"), ("recoverable-quality.yml", "reusable_workflow_sha256")):
        source = ROOT / ".github/workflows" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != activation[field]:
            raise ValueError("Reviewed caller/called workflow bytes changed.")
    helpers = {"recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"}
    if set(activation["guard_files"]) != helpers:
        raise ValueError("Recoverable installation requires all five pinned Python files.")
    for name, digest in activation["guard_files"].items():
        source = ROOT / "Tools/CI" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise ValueError("Reviewed helper source bytes changed.")
    if len(activation["runners"]) != 1:
        raise ValueError("This installer reserves exactly one physical runner.")
    runner_name, instance = next(iter(activation["runners"].items()))
    backend, _ = backend_descriptor(value)
    allowed_roles = (LOCAL_COMPONENT_ROLES,) if backend == LOCAL_COMPONENTS_BACKEND else (RECOVERABLE_ROLES, ASAN_RECOVERABLE_ROLES, NORMAL_CI_ROLES)
    if (not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", runner_name)
            or set(instance) != {"workspace", "jobs"}
            or instance["workspace"] != str(RUNNER / "_work/l337/l337")
            or set(instance["jobs"]) not in allowed_roles
            or len(instance["jobs"]) != len(set(instance["jobs"]))):
        raise ValueError("Recoverable runner/workspace/role reservation differs.")
    if backend == native_runner.GITHUB_BACKEND and set(instance['jobs']) == NORMAL_CI_ROLES:
        if native_runner.phase_profile(value, 'normal') is None:
            raise ValueError('Current CI role reservation requires both normal/leaks phase profiles')
    if (type(config.get("schema")) is not int or config.get("schema") != 1 or set(config) - {"schema", "host", "cache", "legacy_cache", "workers", "admission", "planning", "phase_profiles"}
            or set(config.get("workers", {})) != {"one"}
            or config.get("admission", {}).get("explicit") != 1
            or not re.fullmatch(r"[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}", config.get("host", ""))):
        raise ValueError("Recoverable execution needs one approved physical worker and static admission.")
    bounds = config["admission"]
    if (set(bounds) != {"explicit", "cpu_budget", "ram_capacity", "ram_reserve", "peak_per_worker", "disk_capacity", "disk_reserve", "disk_per_worker"}
            or any(type(n) not in (int, float) or not math.isfinite(n) or n <= 0 for n in bounds.values())):
        raise ValueError("Reviewed static admission fields are incomplete.")
    spaces = [Path(config[name]) for name in ("cache", "legacy_cache")]
    spaces += [Path(config["workers"]["one"]), Path(activation["assignment_root"])]
    protected = [ROOT, RUNNER, AUTHORIZATION_ROOT, HOME_ROOT / "recoverable-sessions"]
    if (any(not path.is_absolute() or path != path.resolve() for path in spaces)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for a in spaces for b in protected)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for i, a in enumerate(spaces) for b in spaces[i + 1:])):
        raise ValueError("Reviewed execution/assignment paths overlap mutable or authorization data.")
    manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256",
                "reusable_workflow_sha256", "runners", "assignment_root")}
    manifest.update(ref=ref, workflow_file="ci.yml")
    if "pr_head" in activation:
        manifest["pr_head"] = activation["pr_head"]
    for name in ("sanitizer_backend", "local_components"):
        if name in activation:
            manifest[name] = activation[name]
    if policy_digest(manifest) != activation["manifest_sha256"]:
        raise ValueError("Reviewed published activation manifest is inconsistent.")
    if backend == LOCAL_COMPONENTS_BACKEND:
        read_local_components_binding(value)
    return value


_PROVISIONING = ContextVar("native_provisioning_custody", default=None)
_PROVISIONING_SEAL = object()


class _ProvisioningCustody:
    def __init__(self, lock, witness, seal):
        if seal is not _PROVISIONING_SEAL:
            raise ValueError("Untrusted provisioning custody.")
        self.lock, self.controller = lock, witness
        self.executor, self.executor_path = None, None


def _require_provisioning(executor=False):
    custody = _PROVISIONING.get()
    if not isinstance(custody, _ProvisioningCustody):
        raise ValueError("Provisioning requires witnessed controller custody.")
    custody.controller.verify()
    if executor:
        if custody.executor is None:
            raise ValueError("Provisioning requires witnessed executor custody.")
        custody.executor.verify()
    native_runner.require_diagnostic_custody_clear()
    return custody


def _operator_only():
    # These entrypoints take controller custody. Actual NativeAuthority jobs do not.
    job_keys = {"GITHUB_JOB", "GITHUB_RUN_ID", "GITHUB_WORKFLOW_REF"}
    if (os.environ.get("GITHUB_ACTIONS") == "true" or job_keys.intersection(os.environ)
            or any(key.startswith("RUNNER_") for key in os.environ)):
        raise ValueError("Controller-needing provisioning is ineligible inside a listener job.")


@contextmanager
def recoverable_control():
    """Reuse only a live in-process acquisition; the listener retains controller custody."""
    _operator_only()
    if _PROVISIONING.get() is not None:
        yield _require_provisioning().lock
        return
    ensure_owned_directory(HOME_ROOT)
    path = HOME_ROOT / "recoverable-control.lock"
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a") as lock:
        info = os.fstat(lock.fileno())
        if path != path.resolve() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Recoverable control lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with native_runner._diagnostic_lease_context(lock, "controller") as witness:
            token = _PROVISIONING.set(_ProvisioningCustody(lock, witness, _PROVISIONING_SEAL))
            try:
                _require_provisioning()
                yield lock
            finally:
                _PROVISIONING.reset(token)


@contextmanager
def quiescent_legacy(policy=None):
    """Use the existing physical shared executor, always after controller acquisition."""
    custody = _require_provisioning()
    path = HOME_ROOT / "sanitizer-checkpoints/executor.lock"
    if policy is not None and Path(policy["recoverable_shards"]["legacy_cache"]) / "executor.lock" != path:
        raise ValueError("Reviewed provisioning must use the common physical executor lease.")
    if custody.executor is not None:
        if custody.executor_path != path:
            raise ValueError("Nested executor custody differs.")
        _require_provisioning(executor=True)
        yield
        return
    descriptor = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "a") as lock:
        info = os.fstat(lock.fileno())
        if path != path.resolve() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Existing physical executor lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with native_runner._diagnostic_lease_context(lock, "executor") as witness:
            custody.executor, custody.executor_path = witness, path
            try:
                _require_provisioning(executor=True)
                yield
            finally:
                custody.executor = custody.executor_path = None


def session_hook(policy_path, guard_path):
    """Admit the exact session and host without requiring unavailable job-level env."""
    return ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 -E -s -B "
            + shlex.quote(str(guard_path)) + " --policy " + shlex.quote(str(policy_path)) + " --admit\n").encode()


def require_registration(policy):
    registration = RUNNER / ".runner"
    from native_runner import require_owned_activation_file
    require_owned_activation_file(registration)
    value = json.loads(registration.read_text(encoding="utf-8-sig"))
    name = next(iter(policy["recoverable_activation"]["runners"]))
    if value.get("agentName") != name or value.get("gitHubUrl") != "https://github.com/stephenlclarke/l337" or value.get("workFolder") != "_work":
        raise ValueError("Existing registration is not this approved repository/runner.")


def session_run_active(policy, binding):
    """Read only this exact approved run; a new attempt requires a new session."""
    _require_provisioning()
    result = subprocess.run(["gh", "api", "repos/stephenlclarke/l337/actions/runs/" + binding["run_id"]],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            timeout=min(60, max(1, binding["expires_at"] - time.time())))
    if result.returncode:
        raise ValueError("Workflow run metadata is unavailable; renewal stopped.")
    run = json.loads(result.stdout)
    activation = policy["recoverable_activation"]
    expected = activation.get("pr_head", policy["approved_head"])
    workflow = ".github/workflows/ci.yml"
    ref = activation["workflow_ref"].split("@", 1)[1]
    paths = {workflow, workflow + "@" + ref, workflow + "@" + str(run.get("head_branch")), workflow + "@" + expected}
    if (str(run["id"]) != binding["run_id"] or str(run["run_attempt"]) != binding["run_attempt"]
            or run.get("path") not in paths or run.get("event") not in (("pull_request",) if "pr_head" in activation else ("push", "workflow_dispatch"))
            or run["head_sha"] != expected or run["repository"]["full_name"] != "stephenlclarke/l337"
            or str(run["actor"]["id"]) != "22142777" or str(run["triggering_actor"]["id"]) != "22142777"):
        raise ValueError("Workflow run/attempt/source differs; renewal stopped.")
    if run["status"] == "completed":
        return False
    if run["status"] not in ("queued", "in_progress", "waiting"):
        raise ValueError("Workflow run is not active; renewal stopped.")
    return True


def _renew_locked(policy_path, run_id, attempt, maximum, expires, register, listen, lock):
    """Consume a finite durable slot before registration; preserve ambiguous listeners."""
    from native_runner import policy_digest
    policy = owned_json(policy_path)
    if (not re.fullmatch(r"[1-9][0-9]*", run_id or "") or not re.fullmatch(r"[1-9][0-9]*", attempt or "")
            or type(maximum) is not int or not 1 <= maximum <= 256 or type(expires) not in (int, float)
            or not math.isfinite(expires) or not time.time() < expires <= policy["recoverable_activation"]["expires_at"]):
        raise ValueError("A finite exact-run/attempt/job/expiry session is required.")
    root = HOME_ROOT / "recoverable-sessions"
    ensure_owned_directory(root)
    binding_path = root / (policy_digest(policy) + "-" + run_id + "-" + attempt + ".json")
    binding = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"], run_id=run_id,
                   run_attempt=attempt, max_jobs=maximum, expires_at=expires)
    if binding_path.exists():
        if owned_json(binding_path) != binding:
            raise ValueError("Existing immutable session bounds differ; preserving them.")
    else:
        publish_json(binding_path, binding, immutable=True)
    state_path = binding_path.with_suffix(".state")
    if state_path.exists():
        from native_runner import require_owned_activation_file
        require_owned_activation_file(state_path)
        state = json.loads(state_path.read_text())
        if (set(state) != {"used", "phase"} or type(state["used"]) is not int or not 0 <= state["used"] <= maximum
                or state["phase"] not in ("idle", "registered", "running", "stopped")):
            raise ValueError("Session budget state is invalid.")
    else:
        state = {"used": 0, "phase": "idle"}
    if state["phase"] == "running":
        raise ValueError("Listener outcome is unresolved; preserve it and do not renew.")
    while time.time() < expires:
        with quiescent_legacy(policy):
            active = session_run_active(policy, binding)
        if not active:
            return {"used": state["used"], "reason": "workflow completed"}
        if state["phase"] != "registered":
            if not register or state["used"] >= maximum:
                return {"used": state["used"], "reason": "registration budget exhausted"}
            if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
                raise ValueError("An existing registration must finish before renewal.")
            state.update(used=state["used"] + 1, phase="stopped")
            publish_json(state_path, state)
            publish_json(root / "ticket.json", {"binding": str(binding_path), "binding_sha256": hashlib.sha256(binding_path.read_bytes()).hexdigest(),
                         "ordinal": state["used"], "policy_sha256": policy_digest(policy)}, immutable=True)
            with quiescent_legacy(policy):
                try:
                    register_and_run(False, next(iter(policy["recoverable_activation"]["runners"])),
                                     deadline=expires, descriptors=(lock.fileno(),))
                except subprocess.TimeoutExpired:
                    state["phase"] = "running"
                    publish_json(state_path, state)
                    raise ValueError("Registration outcome is unresolved; no renewal authorized.") from None
            state["phase"] = "registered"
            publish_json(state_path, state)
        with quiescent_legacy(policy):
            _registered_slot_proof(policy)
        if not listen:
            return {"used": state["used"], "reason": "registered only"}
        state["phase"] = "running"
        publish_json(state_path, state)
        try:
            process = subprocess.Popen([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER,
                                      env={**{key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")},
                                           "DEVELOPER_DIR": DEVELOPER}, pass_fds=(lock.fileno(),), start_new_session=True)
        except OSError:
            state["phase"] = "registered"
            publish_json(state_path, state)
            raise ValueError("Listener did not launch; registered slot retained.") from None
        while True:
            remaining = expires - time.time()
            if remaining <= 0:
                raise ValueError("Session expired with unresolved listener; no signals or renewal sent.")
            try:
                code = process.wait(timeout=min(30, remaining))
                break
            except subprocess.TimeoutExpired:
                if not session_run_active(policy, binding):
                    # Signal only our unreaped listener, within this session, never a native helper/group.
                    remaining = expires - time.time()
                    if remaining <= 0:
                        raise ValueError("Session expired with unresolved listener; no signal authorized.")
                    process.send_signal(signal.SIGINT)
                    try:
                        process.wait(timeout=min(30, remaining))
                    except subprocess.TimeoutExpired:
                        raise ValueError("Completed-run listener did not stop; no renewal authorized.") from None
                    state["phase"] = "stopped"
                    publish_json(state_path, state)
                    return {"used": state["used"], "reason": "workflow completed"}
        state["phase"] = "idle" if code == 0 else "stopped"
        publish_json(state_path, state)
        if code != 0:
            raise ValueError("Listener failed; raw runner logs and consumed budget retained.")
        if not register:
            return {"used": state["used"], "reason": "registered slot completed"}
    return {"used": state["used"], "reason": "session expired"}


def renew_recoverable(policy_path, run_id, attempt, maximum, expires, register, listen, lock=None):
    """Direct and nested renewal share the same actual controller acquisition."""
    with recoverable_control() as held:
        if lock is not None and lock is not held:
            raise ValueError("A supplied descriptor is not controller custody.")
        return _renew_locked(policy_path, run_id, attempt, maximum, expires, register, listen, held)


def _registered_slot_proof(policy):
    """Bind existing registration to the current immutable ticket and finite consumed slot."""
    from native_runner import policy_digest, require_owned_activation_file
    root = HOME_ROOT / "recoverable-sessions"
    ticket = owned_json(root / "ticket.json")
    if set(ticket) != {"binding", "binding_sha256", "ordinal", "policy_sha256"}:
        raise ValueError("Existing registration lacks an exact issued ticket.")
    path = Path(ticket["binding"])
    binding = owned_json(path)
    state_path = path.with_suffix(".state")
    require_owned_activation_file(state_path)
    state = json.loads(state_path.read_text())
    if (set(binding) != {"schema", "policy_sha256", "head", "run_id", "run_attempt", "max_jobs", "expires_at"}
            or type(binding["schema"]) is not int or binding["schema"] != 1
            or type(ticket["ordinal"]) is not int or binding["policy_sha256"] != policy_digest(policy)
            or binding["head"] != policy["approved_head"] or path.parent != root
            or path.name != policy_digest(policy) + "-" + binding["run_id"] + "-" + binding["run_attempt"] + ".json"
            or not re.fullmatch(r"[1-9][0-9]*", binding["run_id"])
            or not re.fullmatch(r"[1-9][0-9]*", binding["run_attempt"])
            or type(binding["max_jobs"]) is not int or not 1 <= binding["max_jobs"] <= 256
            or type(binding["expires_at"]) not in (int, float) or not math.isfinite(binding["expires_at"])
            or not time.time() < binding["expires_at"] <= policy["recoverable_activation"]["expires_at"]
            or set(state) != {"used", "phase"} or state["phase"] != "registered"
            or type(state["used"]) is not int or not 1 <= state["used"] <= binding["max_jobs"]
            or state_path.stat().st_mode & 0o777 != 0o600
            or ticket != {"binding": str(path), "binding_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "ordinal": state["used"], "policy_sha256": policy_digest(policy)}):
        raise ValueError("Existing registration/session/budget is not the current issued slot.")
    require_registration(policy)


def registered_session_slot(policy, args):
    """An existing registration is resumable only with its exact durable issued ticket."""
    from native_runner import policy_digest, require_owned_activation_file
    if not args.run:
        raise ValueError("Existing registration requires explicit --run of its issued session slot.")
    root = HOME_ROOT / "recoverable-sessions"
    path = root / (policy_digest(policy) + "-" + str(args.session_run_id) + "-" + str(args.session_run_attempt) + ".json")
    binding = owned_json(path)
    expected = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"],
                    run_id=args.session_run_id, run_attempt=args.session_run_attempt,
                    max_jobs=args.max_jobs, expires_at=args.session_expires_at)
    state_path = path.with_suffix(".state")
    require_owned_activation_file(state_path)
    state = json.loads(state_path.read_text())
    ticket = owned_json(root / "ticket.json")
    if (binding != expected or state.get("phase") != "registered"
            or ticket != {"binding": str(path), "binding_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "ordinal": state.get("used"), "policy_sha256": policy_digest(policy)}):
        raise ValueError("Existing registration is not this exact issued session; preserving it.")
    return True

def main() -> None:
    """Prepare first; registration and listening require explicit operator flags."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved-head", required=True)
    parser.add_argument("--runner-archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--recoverable-policy", type=Path)
    parser.add_argument("--recoverable-policy-sha256")
    parser.add_argument("--session-run-id")
    parser.add_argument("--session-run-attempt")
    parser.add_argument("--max-jobs", type=int)
    parser.add_argument("--session-expires-at", type=float)
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    if args.recoverable_policy is not None:
        with recoverable_control() as lock:
            # Reading a reviewed policy is allowed; the old executor lease must be quiescent before installation.
            reviewed = owned_json(args.recoverable_policy)
            if (not re.fullmatch(r"[0-9a-f]{64}", args.recoverable_policy_sha256 or "")
                    or hashlib.sha256(args.recoverable_policy.read_bytes()).hexdigest() != args.recoverable_policy_sha256):
                raise ValueError("Reviewed input policy hash differs; no installation attempted.")
            existing = RUNNER / ".runner"
            if existing.is_symlink():
                raise ValueError("Existing registration is not physical.")
            registered = registered_session_slot(reviewed, args) if existing.exists() else False
            with quiescent_legacy(reviewed):
                policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256,
                                 args.recoverable_policy, args.recoverable_policy_sha256, registered=registered)
            print("Prepared recoverable policy: " + str(policy))
            if args.register or args.run:
                result = renew_recoverable(policy, args.session_run_id, args.session_run_attempt, args.max_jobs,
                                          args.session_expires_at, args.register, args.run, lock)
                print(json.dumps(result))
        return
    if any(value is not None for value in (args.recoverable_policy_sha256, args.session_run_id, args.session_run_attempt,
                                           args.max_jobs, args.session_expires_at)):
        raise ValueError("Session flags require explicit recoverable mode.")
    if args.run and not args.register:
        raise ValueError("Listening requires explicit ephemeral registration.")
    policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256)
    print("Prepared host-owned source policy: " + str(policy))
    if args.register:
        register_and_run(args.run)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit("Native runner preparation failed: " + type(error).__name__) from None
